/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {rewardAmount, puzzleIdentity, validateCompletion} = require("./solo-reward-policy");
const {randomInt} = require("node:crypto");
const {readWallet, commitWallet, dailyPlayChange} = require("./wallet-ledger");

const protocolVersion = "solo-v1";
function check(value, message) {
  if (!value) throw new Error(message);
}
function identifier(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,80}$/.test(value);
}
function userIdentifier(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128 && !value.includes("/");
}

// Dependencies are injected so retry/concurrency behavior can be tested without
// reaching production. The catalog and wallet are never supplied by the caller.
function createSoloRewards({db, clock = Date.now, choose = randomInt}) {
  async function requireEnabled(tx, uid) {
    const control = (await tx.get(db.doc("economyPrivate/control"))).data();
    const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
    check(control?.soloRewardsEnabled === true && control?.walletMigrationReady === true && wallet?.version === 1,
        "Solo coin rewards are not enabled for this account");
  }
  async function enabled(uid) {
    const [control, wallet] = await Promise.all([
      db.doc("economyPrivate/control").get(), db.doc(`coinWallets/${uid}`).get(),
    ]);
    return control.data()?.soloRewardsEnabled === true &&
      control.data()?.walletMigrationReady === true && wallet.data()?.version === 1;
  }

  async function begin(uid, data) {
    check(userIdentifier(uid) && identifier(data.attemptID), "Invalid attempt");
    rewardAmount(data.mode, data.difficulty);
    check(data.protocolVersion === protocolVersion, "Update required");
    check(await enabled(uid), "Solo coin rewards are not enabled for this account");
    const list = await db.doc(`soloPuzzleCatalog/${data.mode}_${data.difficulty}`).get();
    const ids = list.data()?.puzzleIDs;
    check(Array.isArray(ids) && ids.length && ids.length <= 10000 && ids.every(identifier), "No verified puzzle catalog");
    const offset = choose(ids.length);
    const attemptRef = db.doc(`soloRewardAccounts/${uid}/attempts/${data.attemptID}`);
    const activeRef = db.doc(`soloRewardAccounts/${uid}`);
    return db.runTransaction(async (tx) => {
      await requireEnabled(tx, uid);
      const previous = await tx.get(attemptRef);
      if (previous.exists) {
        const a = previous.data();
        check(a.mode === data.mode && a.difficulty === data.difficulty && a.status === "active" && a.expiresAtMs > clock(), "Attempt cannot be reused");
        return publicAttempt(a);
      }
      const active = (await tx.get(activeRef)).data();
      // One active attempt across devices. Beginning another cannot reset its clock.
      if (active?.activeAttemptID && active.expiresAtMs > clock()) {
        const current = (await tx.get(db.doc(`soloRewardAccounts/${uid}/attempts/${active.activeAttemptID}`))).data();
        check(current?.status === "active" && current.mode === data.mode && current.difficulty === data.difficulty,
            "Finish or abandon your active solo attempt first");
        return publicAttempt(current);
      }
      let puzzle;
      let identity;
      for (let i = 0; i < Math.min(ids.length, 24); i++) {
        const candidate = (await tx.get(db.doc(`soloPuzzles/${ids[(offset + i) % ids.length]}`))).data();
        check(candidate && candidate.protocolVersion === protocolVersion && candidate.mode === data.mode &&
          candidate.difficulty === data.difficulty && Number.isSafeInteger(candidate.seed) && candidate.seed >= 0, "Invalid server puzzle");
        const key = puzzleIdentity(candidate);
        if (!(await tx.get(db.doc(`soloRewardAccounts/${uid}/puzzles/${key}`))).exists) {
          puzzle = candidate; identity = key; break;
        }
      }
      check(puzzle, "No fresh rewarded puzzle available; try again later");
      const now = clock();
      const attempt = {id: data.attemptID, mode: data.mode, difficulty: data.difficulty,
        seed: puzzle.seed, puzzleID: ids.find((id) => id === puzzle.id),
        identity, protocolVersion, startedAtMs: now, expiresAtMs: now + 86400000,
        status: "active", reward: rewardAmount(data.mode, data.difficulty)};
      check(attempt.puzzleID, "Catalog identity mismatch");
      tx.create(attemptRef, attempt);
      // Reserve the puzzle even on abandonment: knowing its answer never earns a second chance.
      tx.create(db.doc(`soloRewardAccounts/${uid}/puzzles/${identity}`), {attemptID: data.attemptID, issuedAtMs: now});
      tx.set(activeRef, {activeAttemptID: data.attemptID, expiresAtMs: attempt.expiresAtMs});
      return publicAttempt(attempt);
    });
  }

  async function complete(uid, data) {
    check(userIdentifier(uid) && identifier(data.attemptID), "Invalid attempt");
    const attemptRef = db.doc(`soloRewardAccounts/${uid}/attempts/${data.attemptID}`);
    return db.runTransaction(async (tx) => {
      const context = await readWallet(db, tx, uid, `solo_${data.attemptID}`);
      if (context.existing) return context.existing;
      await requireEnabled(tx, uid);
      const a = (await tx.get(attemptRef)).data();
      check(a && a.status === "active" && a.expiresAtMs > clock(), "Attempt expired or abandoned");
      const p = (await tx.get(db.doc(`soloPuzzles/${a.puzzleID}`))).data();
      check(p && p.protocolVersion === a.protocolVersion && p.mode === a.mode && p.difficulty === a.difficulty &&
        p.seed === a.seed && puzzleIdentity(p) === a.identity, "Puzzle changed");
      const puzzleCoins = validateCompletion(p, data.evidence, clock() - a.startedAtMs);
      const now = clock();
      const play = dailyPlayChange(context.wallet, context.user, now);
      const receipt = commitWallet(tx, context, {
        kind: "solo", delta: puzzleCoins + play.dailyCoins, now,
        walletUpdates: play.walletUpdates, userUpdates: play.userUpdates,
        receipt: {attemptID: a.id, mode: a.mode, difficulty: a.difficulty, puzzleCoins, dailyCoins: play.dailyCoins},
      });
      tx.update(attemptRef, {status: "paid"});
      tx.set(db.doc(`soloRewardAccounts/${uid}`), {activeAttemptID: null, expiresAtMs: 0});
      return receipt;
    });
  }

  async function abandon(uid, data) {
    check(userIdentifier(uid) && (identifier(data.attemptID) || data.allPending === true), "Invalid attempt");
    return db.runTransaction(async (tx) => {
      const activeRef = db.doc(`soloRewardAccounts/${uid}`);
      const active = (await tx.get(activeRef)).data();
      const id = data.allPending === true ? active?.activeAttemptID : data.attemptID;
      if (!id) return {abandoned: true};
      const ref = db.doc(`soloRewardAccounts/${uid}/attempts/${id}`);
      const a = (await tx.get(ref)).data();
      if (a?.status === "active") tx.update(ref, {status: "abandoned"});
      if (active?.activeAttemptID === id) tx.set(activeRef, {activeAttemptID: null, expiresAtMs: 0});
      return {abandoned: true};
    });
  }
  return {enabled, begin, complete, abandon};
}
function publicAttempt(a) {
  return {id: a.id, mode: a.mode, difficulty: a.difficulty, seed: a.seed,
    reward: a.reward, expiresAtMs: a.expiresAtMs, protocolVersion: a.protocolVersion};
}
module.exports = {createSoloRewards, protocolVersion};
