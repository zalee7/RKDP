/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {createHash} = require("node:crypto");
const {validateCompletion, validateSolitaire} = require("./solo-reward-policy");
const {readWallet, commitWallet, dailyPlayChange, check, validUID, validID, dayKey} = require("./wallet-ledger");

const presets = Object.freeze({colorLink: "expert", gridlock: "easy", sudoku: "medium", minesweeper: "medium",
  wordle: "medium", anagram: "medium", wordHunt: "easy", hangman: "medium"});
const category = (mode) => ["colorLink", "minesweeper"].includes(mode) ? "quick" :
  ["gridlock", "sudoku"].includes(mode) ? "logic" : "word";
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((k) => [k, canonical(value[k])]));
  return value;
}
const fingerprint = (p) => createHash("sha256").update(JSON.stringify(canonical(p))).digest("hex");
const schedulePath = (day) => `economyPrivate/dailySchedules/days/${day}`;
const accountPath = (uid) => `economyPrivate/dailyAccounts/users/${uid}`;
function publicChallenge(c) {
  return {id: c.id, dayKey: c.dayKey, mode: c.mode, difficulty: c.difficulty,
    seed: c.seed, category: c.category, puzzleData: ""};
}

// Only safe summary metrics leave the verifier. Guesses, targets, paths and
// private puzzle documents never enter a leaderboard or receipt.
function verifiedSummary(p, evidence, elapsedMs) {
  const completed = validateCompletion(p, evidence, elapsedMs) > 0;
  const result = {completed, elapsedSeconds: Math.floor(elapsedMs / 1000),
    score: completed ? 1 : 0, progress: completed ? 1 : 0,
    title: completed ? "Completed" : "Finished"};
  switch (p.mode) {
    case "wordle": result.guesses = evidence.guesses.length; break;
    case "hangman": {
      const letters = new Set([p.starter, ...evidence.letters]);
      result.score = new Set([...p.target].filter((c) => letters.has(c))).size;
      result.progress = [...p.target].filter((c) => letters.has(c)).length / p.target.length;
      break;
    }
    case "anagram": case "wordHunt":
      // Waiting out a timer without finding a word is not a played attempt.
      check(evidence.words.length > 0, "Find a word to submit this daily");
      result.score = evidence.words.reduce((sum, w) => sum + Math.min(5, w.length - 2), 0);
      result.wordCount = evidence.words.length;
      result.longestWord = Math.max(...evidence.words.map((w) => w.length));
      result.elapsedSeconds = p.mode === "anagram" ? 60 : 75;
      break;
    case "gridlock": {
      const game = validateSolitaire(p, evidence);
      result.moves = game.moves; result.score = game.score;
      break;
    }
    case "minesweeper": result.progress = evidence.revealed.length / (p.rows * p.cols - p.mines); break;
  }
  return result;
}

function createDailyChallenges({db, clock = Date.now, timestamp = (ms) => ms}) {
  async function gate(tx, uid) {
    check(validUID(uid), "Invalid account");
    const control = (await tx.get(db.doc("economyPrivate/control"))).data();
    const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
    check(control?.walletMigrationReady === true && control?.dailyChallengesEnabled === true && wallet?.version === 1,
        "Verified dailies are not enabled for this account");
  }

  async function today(uid) {
    return db.runTransaction(async (tx) => {
      await gate(tx, uid);
      const day = dayKey(clock());
      const ref = db.doc(schedulePath(day));
      let schedule = (await tx.get(ref)).data();
      if (!schedule) {
        const challenges = [];
        for (const [mode, difficulty] of Object.entries(presets)) {
          const catalog = (await tx.get(db.doc(`soloPuzzleCatalog/${mode}_${difficulty}`))).data();
          const ids = catalog?.puzzleIDs;
          check(Array.isArray(ids) && ids.length > 0 && ids.length <= 10000 && ids.every(validID), "Daily catalog unavailable");
          const offset = createHash("sha256").update(`daily-v1_${day}_${mode}`).digest().readUInt32BE(0) % ids.length;
          const puzzleID = ids[offset];
          const p = (await tx.get(db.doc(`soloPuzzles/${puzzleID}`))).data();
          check(p?.id === puzzleID && p.protocolVersion === "solo-v1" && p.mode === mode && p.difficulty === difficulty &&
            Number.isSafeInteger(p.seed) && p.seed >= 0, "Invalid daily puzzle");
          challenges.push({id: `${day}_${mode}`, dayKey: day, mode, difficulty, seed: p.seed,
            category: category(mode), puzzleData: "", puzzleID, fingerprint: fingerprint(p)});
        }
        schedule = {id: day, dayKey: day, challenges, createdAtMs: clock()};
        // Pin one immutable schedule: catalog changes cannot give the next player another board.
        tx.create(ref, schedule);
      }
      return {id: day, dayKey: day, createdAt: schedule.createdAtMs / 1000 - 978307200,
        challenges: schedule.challenges.map(publicChallenge)};
    });
  }

  async function begin(uid, data) {
    check(validID(data.challengeID), "Invalid challenge");
    const set = await today(uid);
    check(set.challenges.some((c) => c.id === data.challengeID), "This daily has ended");
    return db.runTransaction(async (tx) => {
      await gate(tx, uid);
      check(dayKey(clock()) === set.dayKey, "This daily has ended");
      const schedule = (await tx.get(db.doc(schedulePath(set.dayKey)))).data();
      const c = schedule.challenges.find((c) => c.id === data.challengeID);
      const ref = db.doc(`${accountPath(uid)}/attempts/${c.id}`);
      const existing = (await tx.get(ref)).data();
      if (existing) {
        check(existing.status === "active" && clock() < existing.expiresAtMs, "Daily already submitted or expired");
      } else {
        tx.create(ref, {challenge: c, startedAtMs: clock(), status: "active",
          expiresAtMs: Date.parse(`${c.dayKey}T00:00:00Z`) + 86400000 + 7200000});
      }
      // Reopening keeps the original server clock, never a fresh rewarded attempt.
      return publicChallenge(c);
    });
  }

  async function complete(uid, data) {
    check(validUID(uid) && validID(data.challengeID), "Invalid challenge");
    return db.runTransaction(async (tx) => {
      const context = await readWallet(db, tx, uid, `dailyChallenge_${data.challengeID}`);
      if (context.existing) return context.existing;
      await gate(tx, uid);
      const attemptRef = db.doc(`${accountPath(uid)}/attempts/${data.challengeID}`);
      const a = (await tx.get(attemptRef)).data();
      const now = clock();
      check(a?.status === "active" && now < a.expiresAtMs, "Daily attempt expired or missing");
      const c = a.challenge;
      const p = (await tx.get(db.doc(`soloPuzzles/${c.puzzleID}`))).data();
      check(p && fingerprint(p) === c.fingerprint, "Daily puzzle changed");
      const result = verifiedSummary(p, data.evidence, now - a.startedAtMs);
      const progressRef = db.doc(`${accountPath(uid)}/days/${c.dayKey}`);
      const progress = (await tx.get(progressRef)).data() || {modes: [], bonusPaid: false};
      const modes = [...new Set([...progress.modes, c.mode])];
      const bonusPaid = progress.bonusPaid || context.user.dailyChallengeBonusDays?.[c.dayKey] === true;
      const completionCoins = !bonusPaid && Object.keys(presets).every((m) => modes.includes(m)) ? 50 : 0;
      const play = dailyPlayChange(context.wallet, context.user, now);
      const userUpdates = {...play.userUpdates};
      if (completionCoins) userUpdates.dailyChallengeBonusDays = {...context.user.dailyChallengeBonusDays, [c.dayKey]: true};
      const cosmetics = context.user.cosmetics || {};
      const cosmetic = (key, fallback) => typeof cosmetics[key] === "string" ? cosmetics[key].slice(0, 80) : fallback;
      const entry = {id: `${uid}_${c.id}`, dayKey: c.dayKey, challengeID: c.id, category: c.category, mode: c.mode,
        difficulty: c.difficulty, userID: uid, username: String(context.user.username || "Player").slice(0, 40),
        avatarStyle: {head: cosmetic("equippedAvatarHead", "avatar_head_none"), face: cosmetic("equippedAvatarFace", "avatar_face_smile"),
          outfit: cosmetic("equippedAvatarOutfit", "avatar_outfit_basic"), aura: cosmetic("equippedAvatarAura", "avatar_aura_none"),
          pose: cosmetic("equippedAvatarPose", "avatar_pose_jump"), bodyHex: cosmetic("customAvatarBodyHex", "FF2F78")},
        submittedAt: timestamp(now), result};
      const receipt = commitWallet(tx, context, {kind: "dailyChallenge", now, delta: play.dailyCoins + completionCoins,
        walletUpdates: play.walletUpdates, userUpdates,
        receipt: {challengeID: c.id, dailyCoins: play.dailyCoins, completionCoins}});
      tx.set(progressRef, {modes, bonusPaid: bonusPaid || completionCoins > 0});
      tx.update(attemptRef, {status: "submitted"});
      tx.create(db.doc(`serverDailyChallenges/${c.dayKey}/entries/${entry.id}`), entry);
      return receipt;
    });
  }
  async function discard(uid, data) {
    check(validUID(uid) && validID(data.challengeID), "Invalid challenge");
    return db.runTransaction(async (tx) => {
      const receipt = (await tx.get(db.doc(`coinWallets/${uid}/receipts/dailyChallenge_${data.challengeID}`))).data();
      const ref = db.doc(`${accountPath(uid)}/attempts/${data.challengeID}`);
      const attempt = (await tx.get(ref)).data();
      // Discard and settlement race atomically. Never undo committed rewards.
      if (!receipt && attempt?.status === "active") tx.update(ref, {status: "abandoned"});
      return {discarded: true};
    });
  }
  return {today, begin, complete, discard};
}

module.exports = {createDailyChallenges, verifiedSummary, presets};
