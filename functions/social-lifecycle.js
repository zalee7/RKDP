/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {randomUUID, randomInt, createHash} = require("node:crypto");
const {check, validID, validUID, readWallet, commitWallet, dailyPlayChange} = require("./wallet-ledger");
const {verifyResult, limits} = require("./match-evidence");
const {resolveMatch, tier} = require("./match-reward-policy");
const path = (id) => `economyPrivate/socialRooms/records/${id}`;
const difficulties = ["easy", "medium", "hard", "expert"];
function ordered(v) {
  if (Array.isArray(v)) return v.map(ordered);
  return v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, ordered(v[k])])) : v;
}
const hash = (v) => createHash("sha256").update(JSON.stringify(ordered(v))).digest("hex");
function timeLimit(mode, difficulty) {
  const choices = {sudoku: [600, 720, 900, 1200], gridlock: [600, 720, 900, 1080],
    colorLink: [240, 300, 420, 540], minesweeper: [180, 300, 420, 600]};
  return choices[mode]?.[difficulties.indexOf(difficulty)] ?? limits[mode];
}
function compare(a, b, mode) {
  const n = (r, k) => Number(r.summary[k] || 0);
  const asc = (x, y) => x - y;
  const desc = (x, y) => y - x;
  const completed = desc(Number(a.completed), Number(b.completed));
  const elapsed = asc(a.elapsedSeconds, b.elapsedSeconds);
  const abandoned = asc(Number(a.summary.abandoned === "true" || a.summary.partyTimeout === "true"),
      Number(b.summary.abandoned === "true" || b.summary.partyTimeout === "true"));
  if (abandoned) return abandoned;
  if (a.summary.abandoned === "true" || a.summary.partyTimeout === "true") return 0;
  switch (mode) {
    case "wordle": return desc(n(a, "solvedRounds"), n(b, "solvedRounds")) ||
      (!n(a, "solvedRounds") ? 0 : asc(n(a, "totalGuesses"), n(b, "totalGuesses")) || elapsed);
    case "anagram": case "wordHunt": return desc(a.score, b.score) || desc(n(a, "wordCount"), n(b, "wordCount")) || desc(n(a, "longestWordLength"), n(b, "longestWordLength")) || elapsed;
    case "hangman": return desc(n(a, "solvedRounds"), n(b, "solvedRounds")) || completed ||
      (!a.completed ? desc(n(a, "revealedLetterCount"), n(b, "revealedLetterCount")) : 0) || asc(n(a, "wrongGuessCount"), n(b, "wrongGuessCount")) || elapsed;
    case "gridlock": return completed || (!a.completed ? desc(n(a, "foundationCount"), n(b, "foundationCount")) || desc(a.score, b.score) || desc(a.progress, b.progress) : 0) || asc(n(a, "moves"), n(b, "moves")) || elapsed;
    case "minesweeper": return asc(Number(a.summary.hitMine === "true"), Number(b.summary.hitMine === "true")) || completed || desc(a.score, b.score) || elapsed;
    default: return completed || (!a.completed ? desc(a.progress, b.progress) || desc(n(a, "solvedPairs"), n(b, "solvedPairs")) : 0) || elapsed;
  }
}
function safeResult(r) {
  const summary = Object.fromEntries(Object.entries(r.summary).filter(([key]) =>
    ["isFinal", "final", "solvedRounds", "failedRounds", "roundCount", "partyTimeout", "abandoned"].includes(key)));
  return {...r, summary, details: []};
}
function resultSummary(r) {
  if (r.summary.partyTimeout === "true") return r.status;
  const time = `${Math.floor(r.elapsedSeconds / 60)}:${String(r.elapsedSeconds % 60).padStart(2, "0")}`;
  switch (r.mode) {
    case "wordle": return `${r.summary.solvedRounds}/3 solved, ${r.summary.totalGuesses} guesses, ${time}`;
    case "hangman": return `${r.summary.solvedRounds}/3 rescued, ${r.summary.wrongGuessCount} wrong, ${time}`;
    case "anagram": case "wordHunt": return `${r.score} pts, ${r.summary.wordCount} words`;
    case "gridlock": return `${r.summary.foundationCount}/52 foundations, ${r.summary.moves} moves, ${time}`;
    case "colorLink": return `${Math.round(r.progress * 100)}% fill, ${r.summary.solvedPairs} pairs, ${time}`;
    case "minesweeper": return `${r.summary.hitMine === "true" ? "Mine hit, " : ""}${r.score} safe cells, ${time}`;
    default: return `${r.completed ? "Solved" : `${Math.round(r.progress * 100)}% complete`}, ${time}`;
  }
}

function createSocialLifecycle({db, clock = Date.now, choose = randomInt, uuid = randomUUID, timestamp = (ms) => ms}) {
  async function gate(tx, uid) {
    check(validUID(uid), "Invalid account");
    const flags = (await tx.get(db.doc("economyPrivate/control"))).data();
    check(flags?.walletMigrationReady === true && flags?.socialRewardsEnabled === true, "Verified friend and party games are not enabled yet");
    if (flags.socialTestUIDs) check(flags.socialTestUIDs.includes(uid), "Test account is not approved");
  }
  async function player(tx, uid, mode) {
    check(validUID(uid), "Invalid player");
    const flags = (await tx.get(db.doc("economyPrivate/control"))).data();
    if (flags?.socialTestUIDs) check(flags.socialTestUIDs.includes(uid), "Test player is not approved");
    const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
    const user = (await tx.get(db.doc(`users/${uid}`))).data();
    check(wallet?.version === 1 && user && !user.deletedAt, "All players need the updated wallet");
    const c = user.cosmetics || {};
    const points = wallet.matchRanks?.[mode]?.points ?? 0;
    return {userID: uid, username: String(user.username || "Player").slice(0, 40), wager: 0, isBot: false,
      rankPoints: points, rankTier: tier(points), joinedAtMs: clock(), abandoned: false,
      avatarStyle: {head: c.equippedAvatarHead || "avatar_head_none", face: c.equippedAvatarFace || "avatar_face_smile",
        outfit: c.equippedAvatarOutfit || "avatar_outfit_basic", aura: c.equippedAvatarAura || "avatar_aura_none",
        pose: c.equippedAvatarPose || "avatar_pose_jump", bodyHex: c.customAvatarBodyHex || "FF2F78"}};
  }
  async function puzzle(tx, config, index) {
    check(config && Object.hasOwn(limits, config.mode) && difficulties.includes(config.difficulty), "Invalid game selection");
    const catalog = (await tx.get(db.doc(`economyPrivate/socialCatalog/modes/${config.mode}_${config.difficulty}`))).data();
    check(catalog?.version === 1 && Array.isArray(catalog.puzzleIDs) && catalog.puzzleIDs.length > 0 && catalog.puzzleIDs.length <= 10000, "Social puzzle catalog unavailable");
    const id = catalog.puzzleIDs[choose(catalog.puzzleIDs.length)];
    check(validID(id), "Invalid puzzle identity");
    const p = (await tx.get(db.doc(`economyPrivate/matchPuzzles/records/${id}`))).data();
    check(p?.protocolVersion === "match-v1" && p.mode === config.mode && p.difficulty === config.difficulty &&
      Number.isSafeInteger(p.seed) && p.seed >= 0 && typeof p.puzzleData === "string", "Invalid social puzzle");
    return {index, mode: p.mode, difficulty: p.difficulty, seed: p.seed, puzzleData: p.puzzleData,
      puzzleID: id, puzzleHash: hash(p), status: "waiting", results: {}, startedBy: {}};
  }
  const ids = (m) => m.players.map((p) => p.userID);
  function roundView(r) {
    return {index: r.index, mode: r.mode, difficulty: r.difficulty, seed: r.seed,
      puzzleData: r.puzzleData, status: r.status,
      results: Object.fromEntries(Object.entries(r.results).map(([uid, result]) => [uid, r.status === "finished" ? result : safeResult(result)])),
      ...(r.startedAtMs != null ? {startedAt: timestamp(r.startedAtMs)} : {}),
      ...(r.finishedAtMs != null ? {finishedAt: timestamp(r.finishedAtMs)} : {}),
      ...(r.deadlineMs ? {finishWindowStartedAt: timestamp(r.windowStartedMs), finishWindowDeadline: timestamp(r.deadlineMs), finishWindowStarterID: r.starterID} : {}),
      ...(r.scoreRows ? {scoreRows: r.scoreRows} : {})};
  }
  function projection(m) {
    const r = m.rounds[m.index]; const round = roundView(r);
    const common = {mode: r.mode, difficulty: r.difficulty, seed: r.seed, puzzleData: r.puzzleData,
      status: m.status, playerIDs: ids(m), createdAt: timestamp(m.createdAtMs),
      ...(r.startedAtMs != null ? {startedAt: timestamp(r.startedAtMs)} : {}),
      ...(m.finishedAtMs != null ? {finishedAt: timestamp(m.finishedAtMs)} : {}),
      ...(m.status === "finished" ? {winnerID: m.winnerID ?? null, winnerReason: "Verified results"} : {})};
    if (m.kind !== "party") {
      return {...common, id: m.id, matchKind: m.kind, players: m.players,
        playerResults: round.results};
    }
    return {...common, code: m.id, hostID: m.hostID, expiresAt: timestamp(m.status === "lobby" ? m.createdAtMs + 1800000 : m.expiresAtMs),
      readyPlayerIDs: m.readyIDs, maxPlayers: 8,
      players: m.players.map((p) => ({...p, joinedAt: timestamp(p.joinedAtMs), isHost: p.userID === m.hostID,
        ...(round.results[p.userID] ? {result: round.results[p.userID]} : {})})),
      ...(r.deadlineMs ? {finishWindowStartedAt: timestamp(r.windowStartedMs), finishWindowDeadline: timestamp(r.deadlineMs), finishWindowStarterID: r.starterID} : {}),
      ...(m.rounds.length > 1 ? {isStageRoom: true, stageRounds: m.rounds.map(roundView), currentStageRoundIndex: m.index, stageScores: m.scores} : {})};
  }
  function publish(tx, m) {
    tx.set(db.doc(path(m.id)), m);
    tx.set(db.doc(`${m.kind === "party" ? "partyRooms" : "sessions"}/${m.id}`), projection(m));
    if (m.invite) {
      tx.set(db.doc(`exhibitionInvites/${m.id}`), {...m.invite,
        createdAt: timestamp(m.createdAtMs), expiresAt: timestamp(m.inviteExpiresAtMs), sessionID: m.id});
    }
  }
  function reply(m, uid, index = m.index) {
    return {sessionID: m.id, accepted: true, status: m.status, ownResult: m.rounds[index]?.results[uid] ?? null};
  }
  async function create(uid, data) {
    check(validUID(uid) && validID(data.requestID), "Invalid creation request");
    check(["party", "exhibition", "asyncExhibition"].includes(data.kind), "Invalid room type");
    const configs = data.rounds;
    check(Array.isArray(configs) && (configs.length === 1 || (data.kind === "party" && configs.length === 3)) &&
      new Set(configs.map((c) => c?.mode)).size === configs.length, "Choose one game or three distinct games");
    const newID = data.kind === "party" ? `S1${uuid().replaceAll("-", "").slice(0, 10).toUpperCase()}` : `sv1_${uuid()}`;
    return db.runTransaction(async (tx) => {
      await gate(tx, uid);
      const requestRef = db.doc(`economyPrivate/socialRequests/users/${uid}/requests/${data.requestID}`);
      const previous = (await tx.get(requestRef)).data();
      if (previous) return {sessionID: previous.id};
      check(!(await tx.get(db.doc(path(newID)))).exists && !(await tx.get(db.doc(`${data.kind === "party" ? "partyRooms" : "sessions"}/${newID}`))).exists, "Room code collision; retry");
      const players = [await player(tx, uid, configs[0].mode)];
      if (data.kind !== "party") {
        check(validUID(data.friendID) && data.friendID !== uid, "Invalid friend");
        const friendship = (await tx.get(db.doc(`friendships/${[uid, data.friendID].sort().join("_")}`))).data();
        check(friendship?.userIDs?.includes(uid) && friendship.userIDs.includes(data.friendID), "Not friends");
        players.push(await player(tx, data.friendID, configs[0].mode));
      }
      const accountRef = db.doc(`economyPrivate/socialAccounts/players/${uid}`);
      const account = (await tx.get(accountRef)).data();
      const now = clock();
      check(!account || now - account.lastCreatedMs >= 3000, "Please wait before creating another room");
      const rounds = [];
      for (const [index, config] of configs.entries()) rounds.push(await puzzle(tx, config, index));
      const m = {version: 1, id: newID, hostID: uid, kind: data.kind, players, rounds, index: 0,
        readyIDs: [], acceptedIDs: [uid], scores: {}, createdAtMs: now, expiresAtMs: now + (data.kind === "asyncExhibition" ? 172800000 : 7200000),
        status: data.kind === "party" ? "lobby" : data.kind === "asyncExhibition" ? "inProgress" : "waiting"};
      if (data.kind !== "party") {
        m.inviteExpiresAtMs = now + (data.kind === "asyncExhibition" ? 172800000 : 120000);
        m.invite = {id: newID, fromID: uid, toID: data.friendID, fromUsername: players[0].username,
          toUsername: players[1].username, mode: rounds[0].mode, difficulty: rounds[0].difficulty,
          status: "pending", inviteType: data.kind === "asyncExhibition" ? "playLater" : "playNow"};
      }
      publish(tx, m); tx.create(requestRef, {id: newID}); tx.set(accountRef, {lastCreatedMs: now});
      return {sessionID: newID};
    });
  }
  function start(m, now) {
    const r = m.rounds[m.index]; r.status = "inProgress"; r.startedAtMs = now;
    for (const uid of ids(m)) r.startedBy[uid] = now;
    m.status = "inProgress";
  }
  function timeout(r, uid, now, start, abandoned = false) {
    return {userID: uid, mode: r.mode, completed: false, elapsedSeconds: Math.max(0, Math.floor((now - start) / 1000)),
      score: 0, progress: 0, status: abandoned ? "Abandoned" : "Time expired",
      summary: {partyTimeout: "true", isFinal: "true", final: "true", ...(abandoned ? {abandoned: "true"} : {})}, details: []};
  }
  function finish(m, now) {
    const r = m.rounds[m.index];
    if (r.status === "finished" || !ids(m).every((uid) => r.results[uid])) return;
    r.status = "finished"; r.finishedAtMs = now;
    if (m.kind !== "party") {
      const forfeitedIDs = ids(m).filter((uid) => r.results[uid].summary.partyTimeout === "true");
      m.winnerID = forfeitedIDs.length === 2 ? null : resolveMatch({mode: r.mode, players: m.players, playerResults: r.results, forfeitedIDs});
      m.status = "finished"; m.finishedAtMs = now; m.invite.status = "completed";
      return;
    }
    const sorted = [...m.players].sort((a, b) => compare(r.results[a.userID], r.results[b.userID], r.mode));
    let placement = 1;
    r.scoreRows = sorted.map((p, i) => {
      if (i && compare(r.results[p.userID], r.results[sorted[i - 1].userID], r.mode)) placement = i + 1;
      const points = [10, 7, 5, 3][placement - 1] ?? 1;
      m.scores[p.userID] = (m.scores[p.userID] || 0) + points;
      return {userID: p.userID, username: p.username, placement, roundPoints: points,
        cumulativePoints: m.scores[p.userID], resultSummary: resultSummary(r.results[p.userID])};
    });
    if (m.index !== m.rounds.length - 1) return;
    m.status = "finished"; m.finishedAtMs = now;
    const wins = (uid) => m.rounds.filter((r) => r.scoreRows?.some((s) => s.userID === uid && s.placement === 1)).length;
    const latest = (uid) => r.scoreRows.find((s) => s.userID === uid).placement;
    const rank = (a, b) => m.scores[b] - m.scores[a] || wins(b) - wins(a) || latest(a) - latest(b);
    const champions = ids(m).sort(rank);
    m.winnerID = champions.length > 1 && rank(champions[0], champions[1]) === 0 ? null : champions[0];
    if (m.invite) m.invite.status = "completed";
  }
  async function act(uid, data, action) {
    check(validUID(uid) && validID(data.sessionID) && /^(sv1_|S1)/.test(data.sessionID), "Invalid social room");
    return db.runTransaction(async (tx) => {
      await gate(tx, uid);
      const m = (await tx.get(db.doc(path(data.sessionID)))).data();
      check(m?.version === 1, "Room not found");
      const before = hash(m);
      const now = clock();
      if (action === "join") {
        check(m.kind === "party", "Not a party");
        if (ids(m).includes(uid)) return reply(m, uid);
        check(m.status === "lobby" && now < m.createdAtMs + 1800000 && m.players.length < 8, "Party is full or already started");
        m.players.push(await player(tx, uid, m.rounds[0].mode));
        publish(tx, m); return reply(m, uid);
      }
      check(ids(m).includes(uid), "Not a participant");
      let r = m.rounds[m.index];
      // A delayed retry must never be applied to the next playlist round.
      if (action === "submit") {
        check(Number.isInteger(data.roundIndex) && data.roundIndex >= 0 && data.roundIndex < m.rounds.length, "Invalid round");
        if (m.rounds[data.roundIndex].results[uid]) return reply(m, uid, data.roundIndex);
        check(data.roundIndex === m.index, "Round is no longer active");
      }
      if (["finished", "canceled", "expired", "abandoned"].includes(m.status)) return reply(m, uid);
      if (now >= m.expiresAtMs || (["lobby", "waiting"].includes(m.status) && now >= m.createdAtMs + (m.kind === "party" ? 1800000 : 120000))) {
        m.status = m.kind === "party" ? "expired" : "abandoned";
        if (m.invite) m.invite.status = "expired";
        publish(tx, m); return reply(m, uid);
      }
      let reward;
      if (action === "accept") {
        check(m.invite?.toID === uid && ["pending", "accepted"].includes(m.invite.status) && now < m.inviteExpiresAtMs, "Invite expired or unavailable");
        m.invite.status = "accepted";
        if (!m.acceptedIDs.includes(uid)) m.acceptedIDs.push(uid);
      } else if (action === "decline") {
        check(m.invite?.toID === uid && m.invite.status === "pending", "Cannot decline this invite");
        m.invite.status = "declined"; m.status = "abandoned";
      } else if (action === "ready") {
        check(m.kind === "party" || m.acceptedIDs.includes(uid), "Accept the invite first");
        if (m.kind === "asyncExhibition") {
          r.startedBy[uid] ??= now; r.status = "inProgress";
        } else if (["lobby", "waiting"].includes(m.status)) {
          m.readyIDs = m.readyIDs.filter((id) => id !== uid);
          if (data.isReady !== false) m.readyIDs.push(uid);
          if (m.kind === "exhibition" && ids(m).every((id) => m.readyIDs.includes(id))) start(m, now);
        }
      } else if (action === "start" || action === "advance") {
        check(m.kind === "party" && uid === m.hostID, "Only the host can start rounds");
        if (action === "start") {
          if (m.status === "inProgress") return reply(m, uid);
          check(m.status === "lobby" && m.players.length >= 2 && ids(m).every((id) => m.readyIDs.includes(id)), "Wait for everyone to be ready");
        } else {
          check(data.roundIndex === m.index, "Round already advanced");
          check(r.status === "finished" && m.index + 1 < m.rounds.length, "Finish the current round first");
          m.index++; r = m.rounds[m.index];
        }
        start(m, now);
      } else if (action === "forfeit") {
        if (m.kind === "party" && m.status === "lobby") {
          if (uid === m.hostID) m.status = "canceled";
          else {
            m.players = m.players.filter((p) => p.userID !== uid); m.readyIDs = m.readyIDs.filter((id) => id !== uid);
          }
        } else if (m.status === "waiting" || (m.invite?.status === "pending" && m.kind === "asyncExhibition")) {
          m.status = "abandoned"; m.invite.status = "canceled";
        } else if (!r.results[uid]) {
          r.results[uid] = timeout(r, uid, now, r.startedBy[uid] ?? now, true);
          if (m.kind === "exhibition") {
            m.status = "finished"; m.finishedAtMs = now;
            m.winnerID = ids(m).find((id) => id !== uid);
            r.status = "finished"; r.finishedAtMs = now; m.invite.status = "completed";
          }
        }
      } else if (action === "submit") {
        check(m.status === "inProgress" && r.status === "inProgress" && r.startedBy[uid] != null, "Round has not started");
        const elapsed = now - r.startedBy[uid];
        const limit = timeLimit(r.mode, r.difficulty);
        check((!limit || elapsed <= (limit + 20) * 1000) && (!r.deadlineMs || now < r.deadlineMs), "Submission window expired");
        const p = (await tx.get(db.doc(`economyPrivate/matchPuzzles/records/${r.puzzleID}`))).data();
        check(p && hash(p) === r.puzzleHash, "Puzzle changed");
        const verified = verifyResult(p, uid, data.evidence, elapsed, limit);
        r.results[uid] = verified.result;
        if (verified.played) {
          const context = await readWallet(db, tx, uid, `social_${m.id}_${r.index}`);
          if (!context.existing) reward = {context, play: dailyPlayChange(context.wallet, context.user, now)};
        }
        if (m.kind === "party" && verified.result.completed && !["anagram", "wordHunt"].includes(r.mode) && !r.deadlineMs) {
          r.windowStartedMs = now; r.deadlineMs = now + 180000; r.starterID = uid;
        }
      } else check(action === "tick", "Unknown social action");
      if (m.status === "inProgress" && r.status === "inProgress") {
        for (const id of ids(m)) {
          const started = r.startedBy[id];
          const limit = timeLimit(r.mode, r.difficulty);
          if (!r.results[id] && ((r.deadlineMs && now >= r.deadlineMs) ||
              (started != null && now >= started + ((limit || 86400) + 20) * 1000))) {
            r.results[id] = timeout(r, id, now, started ?? now);
          }
        }
        // Live first-finisher modes end immediately, matching existing play.
        if (m.kind === "exhibition" && ["sudoku", "gridlock", "colorLink", "minesweeper"].includes(r.mode) && Object.values(r.results).some((v) => v.completed)) {
          m.winnerID = resolveMatch({mode: r.mode, players: m.players, playerResults: r.results, forfeitedIDs: []});
          r.status = "finished"; r.finishedAtMs = now; m.status = "finished"; m.finishedAtMs = now; m.invite.status = "completed";
        } else finish(m, now);
      }
      if (reward) {
        commitWallet(tx, reward.context, {kind: "socialPlay", now, delta: reward.play.dailyCoins,
          walletUpdates: reward.play.walletUpdates, userUpdates: reward.play.userUpdates,
          receipt: {sessionID: m.id, roundIndex: r.index, dailyCoins: reward.play.dailyCoins}});
      }
      if (hash(m) !== before) publish(tx, m);
      return reply(m, uid);
    });
  }
  return {create, ...Object.fromEntries(["join", "accept", "decline", "ready", "start", "advance", "forfeit", "submit", "tick"].map((action) => [action, (uid, data) => act(uid, data, action)]))};
}
module.exports = {createSocialLifecycle, timeLimit, compare, path};
