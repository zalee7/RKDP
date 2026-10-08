/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {randomUUID, randomInt, createHash} = require("node:crypto");
const {check, validUID, validID, dayKey} = require("./wallet-ledger");
const {presets, onlineDifficulty, tier, resolveMatch, validateMatch} = require("./match-reward-policy");
const {verifyResult, verifyWordGuessProgress, limits} = require("./match-evidence");
const {matchPath} = require("./match-rewards");
const privatePath = (id) => `economyPrivate/liveMatches/records/${id}`;
const accountPath = (uid) => `economyPrivate/matchAccounts/players/${uid}`;
const queuePath = (key) => `economyPrivate/matchQueues/buckets/${key}`;
const idOK = (id) => validID(id) && id.startsWith("v1_") && id.length <= 100;
const preGameCountdownMilliseconds = 5_000;
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  return value;
}
const puzzleHash = (puzzle) => createHash("sha256").update(JSON.stringify(canonical(puzzle))).digest("hex");
const actionReply = (m, uid) => ({accepted: true, status: m.status,
  ownResult: m.playerResults[uid] ?? forfeitWinDisplayResult(m, uid)});
const wordGuessTestPuzzleID = (difficulty) => `wordle_test_atest_${difficulty}_v2`;
const wordGuessTestPuzzle = (difficulty) => ({
  protocolVersion: "match-v1", mode: "wordle", difficulty, seed: 1,
  target: "ATEST", targets: ["ATEST"],
  validGuesses: ["ATEST", "APPLE", "BRICK", "CRANE"],
  puzzleData: JSON.stringify({wordBankVersion: "test-atest-v2", targets: ["ATEST"]}),
});
const progressModes = new Set([
  "sudoku", "gridlock", "colorLink", "minesweeper", "wordle", "anagram", "wordHunt", "hangman",
]);
const wordGuessProgressCount = (result) => Number(result?.summary?.attemptedGuesses ?? result?.summary?.round1GuessCount ?? 0);
function wordGuessRaceLoss(uid, puzzle, elapsedSeconds, progress) {
  const target = puzzle.targets[0];
  const attempted = wordGuessProgressCount(progress);
  return {userID: uid, mode: "wordle", completed: false, elapsedSeconds, score: 0, progress: 0,
    status: "Opponent solved first", summary: {...(progress?.summary || {}), raceLoss: "true", isFinal: "true",
      round1Target: target, round1Solved: "false", round1GuessCount: String(attempted),
      round1Guesses: progress?.summary?.round1Guesses || "", round1Partial: "false",
      solvedRounds: "0", failedRounds: "1", totalGuesses: "0", attemptedGuesses: String(attempted), roundCount: "1"},
    details: [`Round 1: ${target} - opponent solved first`]};
}

function firstFinisherLoss(uid, mode, elapsedSeconds, progress, puzzle) {
  if (mode === "wordle") return wordGuessRaceLoss(uid, puzzle, elapsedSeconds, progress);
  const result = progress;
  return {userID: uid, mode, completed: false, elapsedSeconds,
    score: result?.score ?? 0, progress: result?.progress ?? 0,
    status: "Opponent finished first",
    summary: {...(result?.summary || {}), firstFinisherLoss: "true", isFinal: "true"},
    details: result?.details || []};
}

function forfeitWinDisplayResult(m, uid) {
  if (m.status !== "finished" || m.forfeitedIDs.length !== 1 || m.forfeitedIDs.includes(uid)) return null;
  const progress = m.playerProgress?.[uid];
  const elapsedSeconds = Math.max(0, Math.floor((m.finishedAtMs - m.startedAtMs) / 1000));
  return {userID: uid, mode: m.mode, completed: progress?.completed ?? false,
    elapsedSeconds, score: progress?.score ?? 0, progress: progress?.progress ?? 0,
    status: "Won by forfeit",
    summary: {...(progress?.summary || {}), forfeitWin: "true", isFinal: "true"},
    details: progress?.details || ["Opponent forfeited before the match was completed."]};
}

function verifyProgress(puzzle, uid, evidence, elapsed, limit) {
  if (puzzle.mode === "wordle") {
    return {result: verifyWordGuessProgress({...puzzle, matchRounds: 1}, uid, evidence, elapsed), played: true};
  }
  const verified = verifyResult(puzzle, uid, evidence, elapsed, limit, true);
  check(!verified.result.completed, "Completed results must be submitted");
  return verified;
}

function entryAccess(wallet, mode, now, consume) {
  const access = structuredClone(wallet.rankedAccess || {});
  if (access.allModesUnlocked || access.unlockedModeIDs?.includes(mode)) return access;
  const tickets = access.rewardedTickets?.[mode] ?? 0;
  check(Number.isSafeInteger(tickets) && tickets >= 0, "Invalid ranked tickets");
  if (tickets > 0) {
    if (consume) access.rewardedTickets = {...access.rewardedTickets, [mode]: tickets - 1};
    return access;
  }
  const day = dayKey(now);
  const used = access.dailyFreeUses?.[mode];
  check(!used || used.dayKey !== day || used.count < 1, "No ranked entry available");
  if (consume) access.dailyFreeUses = {...access.dailyFreeUses, [mode]: {dayKey: day, count: 1}};
  return access;
}

function createMatchLifecycle({db, clock = Date.now, choose = randomInt, uuid = randomUUID, timestamp = (ms) => new Date(ms)}) {
  async function gate(tx, uid) {
    const flags = (await tx.get(db.doc("economyPrivate/control"))).data();
    check(flags?.walletMigrationReady === true && flags?.matchLifecycleEnabled === true && flags?.matchRewardsEnabled === true, "Official matches are not enabled");
    if (flags.matchTestUIDs) check(flags.matchTestUIDs.includes(uid), "Test account is not approved");
    return flags;
  }
  async function player(tx, uid) {
    const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
    const user = (await tx.get(db.doc(`users/${uid}`))).data();
    check(wallet?.version === 1 && wallet.matchEconomyVersion === 1 && user && !user.deletedAt, "Wallet migration required");
    return {wallet, user};
  }
  function publicMatch(m, puzzleData) {
    if (m.rulesVersion === 2 && m.mode === "wordle") {
      puzzleData = JSON.stringify({...JSON.parse(puzzleData), matchRounds: 1});
    }
    const displayResults = {...m.playerResults};
    if (m.status === "finished" && m.forfeitedIDs.length === 1) {
      for (const player of m.players) {
        const displayResult = forfeitWinDisplayResult(m, player.userID);
        if (!displayResults[player.userID] && displayResult) displayResults[player.userID] = displayResult;
      }
    }
    return {id: m.sessionID, mode: m.mode, difficulty: m.difficulty, matchKind: m.matchKind, seed: m.seed,
      puzzleData, status: m.status, players: m.players, playerIDs: m.players.filter((p) => !p.isBot).map((p) => p.userID),
      createdAt: timestamp(m.createdAtMs), ...(m.preGameCountdownStartedAtMs ? {preGameCountdownStartedAt: timestamp(m.preGameCountdownStartedAtMs)} : {}),
      ...(m.startedAtMs ? {startedAt: timestamp(m.startedAtMs)} : {}),
      ...(m.finishedAtMs ? {finishedAt: timestamp(m.finishedAtMs)} : {}),
      // Do not expose another player's private input/answers during the round.
      ...(m.status === "finished" ? {playerResults: displayResults, winnerID: resolveMatch(m),
        winnerReason: m.forfeitedIDs.length ? "Opponent forfeited" : "Verified result"} : {})};
  }
  function participant(uid, data, mode) {
    const points = data.wallet.matchRanks?.[mode]?.points ?? 0;
    check(Number.isSafeInteger(points) && points >= 0, "Invalid rank");
    const c = data.user.cosmetics || {};
    return {userID: uid, username: String(data.user.username || "Player").slice(0, 40), wager: 0, isBot: false,
      rankPoints: points, rankTier: tier(points), avatarStyle: {head: c.equippedAvatarHead || "avatar_head_none",
        face: c.equippedAvatarFace || "avatar_face_smile", outfit: c.equippedAvatarOutfit || "avatar_outfit_basic",
        aura: c.equippedAvatarAura || "avatar_aura_none", pose: c.equippedAvatarPose || "avatar_pose_jump", bodyHex: c.customAvatarBodyHex || "FF2F78"}};
  }

  async function startMatch(tx, m, now) {
    const humans = [];
    for (const p of m.players.filter((p) => !p.isBot)) humans.push({uid: p.userID, ...(await player(tx, p.userID))});
    const updates = humans.map((h) => ({...h, access: m.matchKind === "ranked" ? entryAccess(h.wallet, m.mode, now, true) : null}));
    m.status = "inProgress"; m.startedAtMs = now;
    for (const h of updates) {
      if (h.access) {
        tx.update(db.doc(`coinWallets/${h.uid}`), {rankedAccess: h.access});
        tx.update(db.doc(`users/${h.uid}`), {rankedAccess: {...h.user.rankedAccess, ...h.access,
          consumedSessionIDs: {...h.user.rankedAccess?.consumedSessionIDs, [m.sessionID]: true}}});
      }
    }
  }

  async function queue(uid, data) {
    check(validUID(uid) && validID(data.requestID) && data.requestID.length <= 80 && Object.hasOwn(presets, data.mode) &&
      ["ranked", "casual"].includes(data.matchKind), "Invalid queue request");
    const newID = `v1_${uuid()}`;
    return db.runTransaction(async (tx) => {
      const flags = await gate(tx, uid);
      const now = clock(); const mine = await player(tx, uid);
      const accountRef = db.doc(accountPath(uid)); const account = (await tx.get(accountRef)).data();
      let staleSessionID = null;
      if (account?.sessionID) {
        const active = (await tx.get(db.doc(privatePath(account.sessionID)))).data();
        const staleWaiting = active?.status === "waiting" && now - active.createdAtMs > 120000;
        if (staleWaiting) staleSessionID = account.sessionID;
        else if (account.requestID === data.requestID || ["waiting", "inProgress"].includes(active?.status)) return {sessionID: account.sessionID};
      }
      check(!(account?.requestID === data.requestID && account.cancelled), "Search was cancelled");
      const points = mine.wallet.matchRanks?.[data.mode]?.points ?? 0;
      const rulesVersion = flags.onlineRulesVersion === 2 ? (data.mode === "wordHunt" ? 3 : 2) : 1;
      const difficulty = rulesVersion >= 2 ? onlineDifficulty(data.mode, data.matchKind, points) : presets[data.mode];
      const key = `${data.matchKind}_${data.mode}_${data.matchKind === "ranked" ? tier(points) : "all"}${rulesVersion >= 2 ? `_v${rulesVersion}` : ""}`;
      check(!account?.queueKey || account.queueKey === key || account.expiresAtMs <= now || account.cancelled || account.sessionID, "Already searching another mode");
      if (data.matchKind === "ranked") entryAccess(mine.wallet, data.mode, now, false);
      const bucketRef = db.doc(queuePath(key));
      const bucket = (await tx.get(bucketRef)).data() || {entries: []};
      const entries = bucket.entries.filter((e) => e.expiresAtMs > now && e.uid !== uid);
      let opponent; let other;
      for (const candidate of entries.slice(0, 12)) {
        const state = (await tx.get(db.doc(accountPath(candidate.uid)))).data();
        if (state?.requestID !== candidate.requestID || state.cancelled || state.sessionID || state.queueKey !== key) continue;
        const candidatePlayer = await player(tx, candidate.uid);
        if (data.matchKind === "ranked") {
          if (tier(candidatePlayer.wallet.matchRanks?.[data.mode]?.points ?? 0) !== tier(points)) continue;
          try {
            entryAccess(candidatePlayer.wallet, data.mode, now, false);
          } catch (_) {
            continue;
          }
        }
        opponent = candidate; other = candidatePlayer; break;
      }
      const queuedAt = account?.requestID === data.requestID ? account.queuedAtMs : now;
      const botCounter = mine.wallet.rewardedBotWins;
      const bot = !opponent && data.matchKind === "ranked" && tier(points) === 0 && now - queuedAt >= 15000 &&
        (botCounter?.dayKey !== dayKey(now) || botCounter.count < 3);
      if (!opponent && !bot) {
        check(entries.length < 100, "Queue is busy; retry shortly");
        const item = {uid, requestID: data.requestID, expiresAtMs: now + 20000};
        if (staleSessionID) {
          tx.update(db.doc(privatePath(staleSessionID)), {status: "abandoned"});
          tx.update(db.doc(`serverMatches/${staleSessionID}`), {status: "abandoned"});
        }
        tx.set(bucketRef, {entries: [...entries, item]});
        tx.set(accountRef, {...item, queueKey: key, queuedAtMs: queuedAt});
        return {sessionID: null};
      }
      let puzzleID; let puzzle;
      if (data.mode === "wordle" && flags.wordGuessTestTargetEnabled === true) {
        const testPuzzleID = wordGuessTestPuzzleID(difficulty);
        const expectedPuzzle = wordGuessTestPuzzle(difficulty);
        const testRef = db.doc(`economyPrivate/matchPuzzles/records/${testPuzzleID}`);
        const existing = await tx.get(testRef);
        puzzleID = testPuzzleID;
        puzzle = existing.data() || expectedPuzzle;
        if (existing.exists) {
          check(puzzleHash(puzzle) === puzzleHash(expectedPuzzle), "Invalid Word Guess test puzzle");
        } else {
          tx.create(testRef, puzzle);
        }
      } else {
        const catalogKey = rulesVersion >= 2 ? `${data.mode}_${difficulty}` : data.mode;
        const catalog = (await tx.get(db.doc(`economyPrivate/matchCatalog/modes/${catalogKey}`))).data();
        check(catalog?.version === 1 && Array.isArray(catalog.puzzleIDs) && catalog.puzzleIDs.length > 0 && catalog.puzzleIDs.length <= 10000,
            "Verified match catalog is missing");
        puzzleID = catalog.puzzleIDs[choose(catalog.puzzleIDs.length)];
        check(validID(puzzleID), "Invalid puzzle identity");
        puzzle = (await tx.get(db.doc(`economyPrivate/matchPuzzles/records/${puzzleID}`))).data();
      }
      check(puzzle?.protocolVersion === "match-v1" && puzzle.mode === data.mode && puzzle.difficulty === difficulty &&
        Number.isSafeInteger(puzzle.seed) && puzzle.seed >= 0 && typeof puzzle.puzzleData === "string", "Invalid match catalog");
      const humans = [{uid, data: mine, requestID: data.requestID}, ...(opponent ? [{uid: opponent.uid, data: other, requestID: opponent.requestID}] : [])];
      const players = humans.map((h) => participant(h.uid, h.data, data.mode));
      if (bot) players.push({userID: `bot_${newID}`, username: "Training Bot", wager: 0, isBot: true, rankPoints: 200, rankTier: 0});
      const m = {version: 1, rulesVersion, verifierVersion: "match-v1", sessionID: newID, mode: data.mode, difficulty,
        matchKind: data.matchKind, status: "waiting", players, seed: puzzle.seed, puzzleID, puzzleHash: puzzleHash(puzzle),
        createdAtMs: now, readyIDs: [], playerResults: {}, playerProgress: {}, playedUserIDs: [], forfeitedIDs: [],
        botStrong: bot && choose(100) >= 82};
      if (staleSessionID) {
        tx.update(db.doc(privatePath(staleSessionID)), {status: "abandoned"});
        tx.update(db.doc(`serverMatches/${staleSessionID}`), {status: "abandoned"});
      }
      tx.create(db.doc(privatePath(newID)), m);
      tx.create(db.doc(`serverMatches/${newID}`), publicMatch(m, puzzle.puzzleData));
      tx.set(bucketRef, {entries: entries.filter((e) => e.uid !== opponent?.uid)});
      for (const human of humans) {
        tx.set(db.doc(accountPath(human.uid)), {sessionID: newID, requestID: human.requestID});
      }
      return {sessionID: newID};
    });
  }

  async function cancel(uid, data) {
    check(validUID(uid) && validID(data.requestID), "Invalid search");
    return db.runTransaction(async (tx) => {
      const ref = db.doc(accountPath(uid)); const current = (await tx.get(ref)).data();
      if (!current || (current.requestID === data.requestID && !current.sessionID)) {
        tx.set(ref, {...current, requestID: data.requestID, cancelled: true, expiresAtMs: 0});
      }
      // A cancellation racing pairing returns the actual session; the client
      // cancels its waiting room rather than abandoning a hidden paired player.
      return {sessionID: current?.requestID === data.requestID ? current.sessionID ?? null : null};
    });
  }

  async function act(uid, data, action) {
    check(validUID(uid) && idOK(data.sessionID), "Invalid official match");
    return db.runTransaction(async (tx) => {
      await gate(tx, uid);
      const now = clock(); const ref = db.doc(privatePath(data.sessionID));
      const m = (await tx.get(ref)).data();
      check(m?.players.some((p) => p.userID === uid && !p.isBot), "Not a participant");
      if (["finished", "abandoned"].includes(m.status) && action !== "progress") return actionReply(m, uid);
      if (action === "ready" && m.status === "inProgress") return actionReply(m, uid);
      const puzzle = (await tx.get(db.doc(`economyPrivate/matchPuzzles/records/${m.puzzleID}`))).data();
      check(puzzle?.seed === m.seed && puzzle.mode === m.mode && puzzle.protocolVersion === "match-v1" && puzzleHash(puzzle) === m.puzzleHash, "Puzzle unavailable");
      if (action === "progress") {
        check(progressModes.has(m.mode) && m.rulesVersion >= 2 && ["inProgress", "finished"].includes(m.status), "Progress is unavailable");
        const elapsed = now - m.startedAtMs;
        const verifiedProgress = verifyProgress(puzzle, uid, data.evidence, elapsed, matchTimeLimit(m));
        const progress = verifiedProgress.result;
        if (verifiedProgress.played && !m.playedUserIDs.includes(uid)) m.playedUserIDs.push(uid);
        m.playerProgress ||= {};
        const previous = m.playerProgress[uid];
        if (m.mode === "wordle") {
          if (wordGuessProgressCount(progress) > wordGuessProgressCount(previous)) m.playerProgress[uid] = progress;
        } else {
          m.playerProgress[uid] = progress;
        }
        if (m.status === "finished") {
          const result = m.playerResults[uid];
          const isForfeitWinner = m.forfeitedIDs.length === 1 && !m.forfeitedIDs.includes(uid);
          check(result?.summary?.raceLoss === "true" || result?.summary?.firstFinisherLoss === "true" || isForfeitWinner,
              "Finished progress is unavailable");
          if (!isForfeitWinner && (m.mode !== "wordle" || wordGuessProgressCount(progress) > wordGuessProgressCount(result))) {
            m.playerResults[uid] = firstFinisherLoss(uid, m.mode, result.elapsedSeconds, progress, puzzle);
          }
          tx.set(ref, m);
          tx.set(db.doc(`serverMatches/${m.sessionID}`), publicMatch(m, puzzle.puzzleData));
          return actionReply(m, uid);
        }
      } else if (action === "tick" && m.status === "waiting") {
        if (m.preGameCountdownStartedAtMs && now >= m.preGameCountdownStartedAtMs + preGameCountdownMilliseconds) {
          await startMatch(tx, m, now);
        } else if (now - m.createdAtMs > 120000) m.status = "abandoned";
      } else if (action === "ready") {
        check(m.status === "waiting", "Match already started");
        if (!m.readyIDs.includes(uid)) m.readyIDs.push(uid);
        if (now - m.createdAtMs > 120000) m.status = "abandoned";
        else if (m.players.filter((p) => !p.isBot).every((p) => m.readyIDs.includes(p.userID))) {
          // The shared timestamp starts only after both phones have reached the pre-game screen.
          // A later tick transitions everyone into the actual game together.
          m.preGameCountdownStartedAtMs ??= now;
        }
      } else if (action === "forfeit") {
        if (m.status === "waiting") m.status = "abandoned";
        else {
          // Submitting a final result cannot be undone by leaving the screen.
          if (!m.playerResults[uid]) {
            m.forfeitedIDs = [uid];
            const progress = m.playerProgress?.[uid];
            m.playerResults[uid] = {userID: uid, mode: m.mode, completed: false, elapsedSeconds: Math.floor((now - m.startedAtMs) / 1000),
              score: progress?.score ?? 0, progress: progress?.progress ?? 0, status: "Forfeited",
              summary: {...(progress?.summary || {}), forfeit: "true", isFinal: "true"}, details: progress?.details || []};
          }
        }
      } else {
        check(m.status === "inProgress", "Match has not started");
        const elapsed = now - m.startedAtMs;
        if (action === "submit" && !m.playerResults[uid]) {
          const limit = matchTimeLimit(m);
          check(!limit || elapsed <= (limit + 20) * 1000, "Submission window expired");
          const verified = verifyResult(m.rulesVersion === 2 && m.mode === "wordle" ? {...puzzle, matchRounds: 1} : puzzle, uid, data.evidence, elapsed, limit);
          m.playerResults[uid] = verified.result;
          if (verified.played && !m.playedUserIDs.includes(uid)) m.playedUserIDs.push(uid);
          if (m.rulesVersion === 2 && progressModes.has(m.mode) && verified.result.completed) {
            // First-finisher modes close immediately, but preserve every other
            // player's latest server-verified state for the result breakdown.
            for (const player of m.players) {
              if (player.userID === uid || m.playerResults[player.userID]) continue;
              m.playerResults[player.userID] = firstFinisherLoss(
                  player.userID, m.mode, Math.floor(elapsed / 1000), m.playerProgress?.[player.userID], puzzle);
            }
          }
        }
        const bot = m.players.find((p) => p.isBot);
        if (bot && !m.playerResults[bot.userID] && elapsed >= botDelay(m.mode) * 1000) m.playerResults[bot.userID] = botResult(m, puzzle, bot.userID);
        const expiry = (matchTimeLimit(m) || 86400) + 20;
        if (elapsed > expiry * 1000) {
          const missing = m.players.filter((p) => !m.playerResults[p.userID]);
          if (missing.length === 2) m.status = "abandoned";
          else if (missing.length === 1) m.forfeitedIDs = [missing[0].userID];
        }
      }
      if (m.status === "inProgress") {
        let resolved = m.forfeitedIDs.length > 0;
        if (!resolved) {
          try {
            resolveMatch(m); resolved = true;
          } catch (_) {/* Still playing. */}
        }
        if (resolved) {
          m.status = "finished"; m.finishedAtMs = now;
          const verified = {...m};
          delete verified.botStrong; delete verified.readyIDs; delete verified.playerProgress;
          validateMatch(verified, m.sessionID, now);
          tx.create(db.doc(matchPath(m.sessionID)), verified);
        }
      }
      tx.set(ref, m);
      tx.set(db.doc(`serverMatches/${m.sessionID}`), publicMatch(m, puzzle.puzzleData));
      return actionReply(m, uid);
    });
  }
  async function wordGuessTestTarget(uid, data) {
    return db.runTransaction(async (tx) => {
      const flags = await gate(tx, uid);
      // This control exists only for explicitly allowlisted sandbox testers.
      check(Array.isArray(flags.matchTestUIDs) && flags.matchTestUIDs.includes(uid), "Word Guess test target is unavailable");
      const enabled = data?.enabled;
      check(enabled === undefined || typeof enabled === "boolean", "Invalid test target setting");
      if (typeof enabled === "boolean") {
        tx.update(db.doc("economyPrivate/control"), {wordGuessTestTargetEnabled: enabled, wordHuntTestPoolEnabled: false});
        return {enabled};
      }
      return {enabled: flags.wordGuessTestTargetEnabled === true};
    });
  }
  return {queue, cancel, wordGuessTestTarget, ready: (uid, data) => act(uid, data, "ready"), progress: (uid, data) => act(uid, data, "progress"), submit: (uid, data) => act(uid, data, "submit"),
    forfeit: (uid, data) => act(uid, data, "forfeit"), tick: (uid, data) => act(uid, data, "tick")};
}

function matchTimeLimit(m) {
  if (m.rulesVersion === 2) {
    if (m.mode === "sudoku" && m.difficulty === "easy") return 600;
    if (m.mode === "minesweeper" && m.difficulty === "easy") return 180;
    if (m.mode === "colorLink" && m.difficulty === "hard") return 420;
  }
  return limits[m.mode];
}

function botDelay(mode) {
  return {wordle: 35, hangman: 91, anagram: 61, wordHunt: 76, sudoku: 55, minesweeper: 42, gridlock: 48, colorLink: 48}[mode];
}
function botResult(m, p, uid) {
  const strong = m.botStrong;
  const r = {userID: uid, mode: m.mode, completed: strong, elapsedSeconds: botDelay(m.mode),
    score: strong ? 100 : 50, progress: strong ? 1 : 0.5, status: "Training result", summary: {botResult: "true"}, details: []};
  if (["anagram", "wordHunt"].includes(m.mode)) {
    const words = p.validWords.filter((w) => w.length <= (strong ? 6 : 4)).slice(0, strong ? 5 : 2);
    r.completed = true; r.progress = 1; r.score = words.reduce((s, w) => s + Math.min(5, w.length - 2), 0);
    Object.assign(r.summary, {wordCount: String(words.length), longestWordLength: String(Math.max(0, ...words.map((w) => w.length))), foundWords: words.join("|")});
  }
  if (m.mode === "wordle") Object.assign(r.summary, {isFinal: "true", solvedRounds: strong ? "2" : "1", failedRounds: strong ? "0" : "2", totalGuesses: strong ? "7" : "5"});
  if (m.mode === "wordle" && m.rulesVersion === 2) {
    Object.assign(r.summary, {
      solvedRounds: strong ? "1" : "0", failedRounds: strong ? "0" : "1", totalGuesses: strong ? "3" : "0", roundCount: "1",
    });
  }
  if (m.mode === "hangman") Object.assign(r.summary, {final: "true", solvedRounds: strong ? "2" : "1", wrongGuessCount: strong ? "3" : "9", revealedLetterCount: strong ? "12" : "6"});
  if (m.mode === "gridlock") Object.assign(r.summary, {moves: strong ? "130" : "95", foundationCount: strong ? "52" : "26"});
  if (m.mode === "colorLink") r.summary.solvedPairs = String(strong ? p.pairs.length : Math.floor(p.pairs.length / 2));
  if (m.mode === "minesweeper") r.summary.hitMine = String(!strong);
  return r;
}
module.exports = {createMatchLifecycle, privatePath, accountPath, entryAccess};
