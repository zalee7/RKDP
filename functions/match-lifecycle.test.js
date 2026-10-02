/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createMatchLifecycle, privatePath} = require("./match-lifecycle");
const {createMatchRewards, matchPath} = require("./match-rewards");
const {verifyResult, limits} = require("./match-evidence");
const {presets, onlineDifficulty, resolveMatch, rankDelta} = require("./match-reward-policy");
const {readFileSync} = require("node:fs");

function fixture(mode = "wordle", kind = "casual") {
  const db = new MemoryDB(); let now = Date.UTC(2026, 8, 30, 12); let next = 0;
  const clock = () => now;
  db.set("economyPrivate/control", {walletMigrationReady: true, matchRewardsEnabled: true, matchLifecycleEnabled: true});
  for (const uid of ["a", "b", "c"]) {
    db.set(`users/${uid}`, {id: uid, username: uid, coins: 500, ranks: {wordle: {points: 999999}}});
    db.set(`coinWallets/${uid}`, {version: 1, matchEconomyVersion: 1, migratedAtMs: now - 100000, balance: 500, revision: 0,
      matchRanks: {}, rankedAccess: {}, casualRewards: {dayKey: "", count: 0}, rewardedBotWins: {dayKey: "", count: 0}});
  }
  const puzzle = {mode, difficulty: presets[mode], protocolVersion: "match-v1", seed: 1, puzzleData: "{}",
    targets: ["APPLE", "BRICK", "CROWN"], target: "APPLE", validGuesses: ["APPLE", "BRICK", "CROWN"]};
  db.set(`economyPrivate/matchCatalog/modes/${mode}`, {version: 1, puzzleIDs: ["p"]});
  db.set("economyPrivate/matchPuzzles/records/p", puzzle);
  const api = createMatchLifecycle({db, clock, choose: () => 0, uuid: () => String(++next)});
  const join = (uid, extra = {}) => api.queue(uid, {requestID: `request_${uid}`, mode, matchKind: kind, ...extra});
  async function paired() {
    await join("a"); const {sessionID} = await join("b");
    await api.ready("a", {sessionID}); await api.ready("b", {sessionID});
    return sessionID;
  }
  return {db, api, join, paired, puzzle, clock, advance: (ms) => {
    now += ms;
  }};
}

function enableV2(f, mode, kind, points = 0) {
  const control = f.db.snapshot("economyPrivate/control").data();
  f.db.set("economyPrivate/control", {...control, onlineRulesVersion: 2});
  for (const uid of ["a", "b"]) {
    const wallet = f.db.snapshot(`coinWallets/${uid}`).data();
    f.db.set(`coinWallets/${uid}`, {...wallet, matchRanks: {[mode]: {points, wins: 0, losses: 0}}});
  }
  const difficulty = onlineDifficulty(mode, kind, points);
  f.db.set(`economyPrivate/matchCatalog/modes/${mode}_${difficulty}`, {version: 1, puzzleIDs: ["p"]});
  f.db.set("economyPrivate/matchPuzzles/records/p", {...f.puzzle, difficulty});
}

test("v2 presets promote at Platinum only for ranked", async () => {
  for (const [mode, lower, upper] of [["sudoku", "easy", "medium"], ["minesweeper", "easy", "medium"],
    ["colorLink", "hard", "expert"], ["wordle", "medium", "hard"]]) {
    assert.equal(onlineDifficulty(mode, "ranked", 3599), lower);
    assert.equal(onlineDifficulty(mode, "ranked", 3600), upper);
    assert.equal(onlineDifficulty(mode, "casual", 12000), lower);
    for (const points of [0, 3600]) {
      const f = fixture(mode, "ranked"); enableV2(f, mode, "ranked", points);
      const id = await f.paired(); const match = f.db.snapshot(privatePath(id)).data();
      assert.equal(match.rulesVersion, 2);
      assert.equal(match.difficulty, points ? upper : lower);
    }
  }
});

test("v2 Word Guess ends immediately when the first player solves", async () => {
  const f = fixture(); enableV2(f, "wordle", "casual");
  const sessionID = await f.paired();
  assert.equal(JSON.parse(f.db.snapshot(`serverMatches/${sessionID}`).data().puzzleData).matchRounds, 1);
  f.advance(20000);
  await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"]]}});
  const publicMatch = f.db.snapshot(`serverMatches/${sessionID}`).data();
  assert.equal(publicMatch.status, "finished");
  assert.equal(publicMatch.winnerID, "a");
  assert.equal(publicMatch.playerResults.b.status, "Opponent solved first");
  assert.equal(publicMatch.playerResults.b.summary.raceLoss, "true");
  const match = f.db.snapshot(matchPath(sessionID)).data();
  assert.equal(resolveMatch(match), "a");
  const receipt = await createMatchRewards({db: f.db, clock: f.clock}).settle("a", {sessionID});
  assert.equal(receipt.matchReward, 15);
  assert.equal((await createMatchRewards({db: f.db, clock: f.clock}).settle("b", {sessionID})).matchReward, 0);
});

test("Word Guess winner bonus rewards efficient verified solves without increasing losses", () => {
  const match = {
    mode: "wordle", difficulty: "medium", players: [
      {userID: "a", rankPoints: 0, isBot: false}, {userID: "b", rankPoints: 0, isBot: false},
    ],
    playerResults: {
      a: {completed: true, elapsedSeconds: 20, summary: {totalGuesses: "1"}},
      b: {elapsedSeconds: 20, summary: {totalGuesses: "0", raceLoss: "true"}},
    },
  };
  assert.equal(rankDelta(match, "a", "a"), 36, "one guess fast solve is capped at +6");
  assert.equal(rankDelta(match, "b", "a"), -15, "race loss has no added rank penalty");
  match.playerResults.a = {completed: true, elapsedSeconds: 20, summary: {totalGuesses: "2"}};
  assert.equal(rankDelta(match, "a", "a"), 35, "two guesses receives the small speed point");
  match.playerResults.a = {completed: true, elapsedSeconds: 30, summary: {totalGuesses: "3"}};
  assert.equal(rankDelta(match, "a", "a"), 32, "thirty seconds is not in the fast band");
});

test("v2 Word Guess rejects extra rounds and unfinished attempts", () => {
  const p = {...fixture().puzzle, matchRounds: 1};
  assert.throws(() => verifyResult(p, "a", {rounds: [["APPLE"], ["BRICK"]]}, 20000));
  assert.throws(() => verifyResult(p, "a", {rounds: [["BRICK"]]}, 20000));
});

test("server board snapshots retain blanks and reconstruct mines without trusting client art", () => {
  const cells = Array(81).fill(0); cells[0] = 1;
  const givens = Array(81).fill(0); givens[1] = 2;
  const sudoku = verifyResult({mode: "sudoku", givens}, "a", {cells: cells.map((value, index) => index === 1 ? 2 : value)}, 720000);
  assert.equal(sudoku.result.summary.boardRows.split("/").length, 9);
  assert.equal(sudoku.result.summary.boardRows.split("/")[0], "12.......");
  assert.equal(sudoku.result.summary.givensRows.split("/")[0], ".2.......");
  const mine = verifyResult({mode: "minesweeper", seed: 1, rows: 5, cols: 5, mines: 3}, "a",
      {firstCell: 12, revealed: [12], boardRows: "FAKE"}, 300000);
  const rows = mine.result.summary.boardRows.split("/");
  assert.equal(rows.length, 5); assert.ok(rows.every((row) => row.length === 5));
  assert.equal(rows.join("").split("M").length - 1, 3);
  assert.equal(rows[2][2], "0");
});

test("Word Hunt is Medium at every online rank; existing v2 Easy matches still settle", async () => {
  for (const kind of ["ranked", "casual"]) {
    for (const points of [0, 3599, 3600, 12000]) {
      assert.equal(onlineDifficulty("wordHunt", kind, points), "medium");
    }
  }
  const f = fixture("wordHunt", "ranked");
  const sessionID = await f.paired();
  f.db.set(privatePath(sessionID), {...f.db.snapshot(privatePath(sessionID)).data(), rulesVersion: 2});
  await f.api.forfeit("a", {sessionID});
  const receipt = await createMatchRewards({db: f.db, clock: f.clock}).settle("b", {sessionID});
  assert.ok(receipt.rankDelta > 0);
  assert.equal(receipt.matchReward, 0);
});

test("optional test allowlist blocks unapproved queue and actions", async () => {
  const f = fixture();
  f.db.set("economyPrivate/control", {walletMigrationReady: true, matchRewardsEnabled: true,
    matchLifecycleEnabled: true, matchTestUIDs: ["a", "b"]});
  await assert.rejects(f.join("c"), /not approved/);
  await assert.rejects(f.api.ready("c", {sessionID: "v1_test"}), /not approved/);
  assert.equal((await f.join("a")).sessionID, null);
});

test("official pairing uses private rank and shared server puzzle, atomically once", async () => {
  const f = fixture("wordle", "ranked");
  const replies = await Promise.all([f.join("a", {seed: 999, rankPoints: 12000}), f.join("b"), f.join("a"), f.join("b")]);
  const ids = replies.map((r) => r.sessionID).filter(Boolean);
  assert.equal(new Set(ids).size, 1);
  const m = f.db.snapshot(privatePath(ids[0])).data();
  assert.equal(m.seed, 1); assert.deepEqual(m.players.map((p) => p.rankPoints), [0, 0]);
  assert.equal(f.db.snapshot(`serverMatches/${ids[0]}`).data().playerResults, undefined);
  assert.equal(f.db.snapshot(`serverMatches/${ids[0]}`).data().status, "waiting");
});

test("no human can be paired into two concurrent modes or opponents", async () => {
  const f = fixture();
  await f.join("a");
  await assert.rejects(f.api.queue("a", {requestID: "different", mode: "sudoku", matchKind: "casual"}), /another mode/);
  await Promise.all([f.join("b"), f.join("c")]);
  assert.equal([...f.db.documents.keys()].filter((key) => key.startsWith("economyPrivate/liveMatches/records/")).length, 1);
});

test("cancel tombstone prevents late queue callback resurrection", async () => {
  const f = fixture();
  await f.api.cancel("a", {requestID: "request_a"});
  await assert.rejects(f.join("a"), /cancelled/);
  assert.equal((await f.join("a", {requestID: "fresh"})).sessionID, null);
});

test("ready is authenticated, idempotent and consumes a ranked entry only at actual start", async () => {
  const f = fixture("wordle", "ranked");
  await f.join("a"); const {sessionID} = await f.join("b");
  await assert.rejects(f.api.ready("c", {sessionID}), /participant/);
  await f.api.ready("a", {sessionID});
  assert.deepEqual(f.db.snapshot("coinWallets/a").data().rankedAccess, {});
  await f.api.ready("b", {sessionID}); await f.api.ready("b", {sessionID});
  assert.equal(f.db.snapshot("coinWallets/a").data().rankedAccess.dailyFreeUses.wordle.count, 1);
  assert.equal(f.db.snapshot(privatePath(sessionID)).data().startedAtMs, f.clock());
});

test("complete verified match produces receipts, real outcome, and one shared daily reward", async () => {
  const f = fixture("wordle", "ranked"); const sessionID = await f.paired();
  f.advance(20000);
  await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}, score: 9999, elapsedSeconds: 1});
  assert.ok(!f.db.snapshot(matchPath(sessionID)).exists);
  assert.equal(f.db.snapshot(`serverMatches/${sessionID}`).data().playerResults, undefined);
  f.advance(5000);
  await f.api.submit("b", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}});
  const verified = f.db.snapshot(matchPath(sessionID)).data();
  assert.equal(verified.playerResults.a.elapsedSeconds, 20);
  assert.equal(verified.playerResults.a.score, 2);
  const reward = createMatchRewards({db: f.db, clock: f.clock});
  const receipt = await reward.settle("a", {sessionID});
  assert.equal(receipt.winnerID, "a"); assert.equal(receipt.matchReward, 20); assert.equal(receipt.dailyCoins, 25);
  await f.api.submit("b", {sessionID, evidence: {rounds: [["CROWN"]]}, score: 123});
  assert.equal((await reward.settle("b", {sessionID})).matchReward, 5);
  assert.equal(f.db.snapshot("coinWallets/a").data().revision, 1);
});

test("forged/out-of-order/incomplete results and modified catalogs never authorize money", async () => {
  const f = fixture(); await f.join("a"); const {sessionID} = await f.join("b");
  await assert.rejects(f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}}), /not started/);
  await f.api.ready("a", {sessionID}); await f.api.ready("b", {sessionID});
  for (const evidence of [{rounds: [["APPLE"]]}, {rounds: [["ZZZZZ"], ["BRICK"]]}, {rounds: [["APPLE"], ["BRICK"], ["CROWN"]]}]) {
    await assert.rejects(f.api.submit("a", {sessionID, evidence}));
  }
  await assert.rejects(f.api.submit("c", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}}), /participant/);
  f.db.set("economyPrivate/matchPuzzles/records/p", {...f.puzzle, targets: ["OTHER"]});
  await assert.rejects(f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}}), /Puzzle unavailable/);
  assert.ok(!f.db.snapshot(matchPath(sessionID)).exists);
});

test("forfeit cannot undo a submitted result; real quitter gets no coins", async () => {
  const f = fixture(); const sessionID = await f.paired(); f.advance(20000);
  await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}});
  await f.api.forfeit("a", {sessionID}); assert.equal(f.db.snapshot(privatePath(sessionID)).data().status, "inProgress");
  await f.api.forfeit("b", {sessionID});
  const reward = createMatchRewards({db: f.db, clock: f.clock});
  assert.equal((await reward.settle("a", {sessionID})).matchReward, 15);
  assert.equal(f.db.snapshot("coinWallets/b").data().balance, 500);
});

test("reconnect returns only the authenticated player's accepted final result", async () => {
  const f = fixture(); const sessionID = await f.paired(); f.advance(20000);
  await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}});
  const own = await f.api.ready("a", {sessionID});
  assert.equal(own.ownResult.userID, "a");
  assert.equal(own.ownResult.elapsedSeconds, 20);
  assert.equal((await f.api.tick("b", {sessionID})).ownResult, null);
  assert.equal(f.db.snapshot(`serverMatches/${sessionID}`).data().playerResults, undefined);
  await assert.rejects(f.api.tick("c", {sessionID}), /participant/);
  const retried = await f.api.submit("a", {sessionID, evidence: {rounds: []}});
  assert.deepEqual(retried.ownResult, own.ownResult);
});

test("canonical puzzle binding tolerates Firestore map-key reordering", async () => {
  const f = fixture(); const sessionID = await f.paired(); f.advance(20000);
  f.db.set("economyPrivate/matchPuzzles/records/p", Object.fromEntries(Object.entries(f.puzzle).reverse()));
  const reply = await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}});
  assert.equal(reply.ownResult.completed, true);
});

test("waiting cancellation and both-player expiry award nothing", async () => {
  const f = fixture(); await f.join("a"); const {sessionID} = await f.join("b");
  await f.api.forfeit("a", {sessionID});
  assert.equal(f.db.snapshot(`serverMatches/${sessionID}`).data().status, "abandoned");
  assert.ok(!f.db.snapshot(matchPath(sessionID)).exists);
  const other = fixture(); const id = await other.paired(); other.advance(86422000); await other.api.tick("a", {sessionID: id});
  assert.equal(other.db.snapshot(privatePath(id)).data().status, "abandoned");
});

test("bot fallback is server-owned, delayed and limited to eligible Bronze wallets", async () => {
  const f = fixture("wordle", "ranked"); await f.join("a"); f.advance(15000);
  const {sessionID} = await f.join("a", {isBot: false, botStrong: true});
  await f.api.ready("a", {sessionID}); f.advance(20000);
  await f.api.submit("a", {sessionID, evidence: {rounds: [["APPLE"], ["BRICK"]]}});
  assert.ok(!f.db.snapshot(matchPath(sessionID)).exists);
  f.advance(15000); await f.api.tick("a", {sessionID});
  const verified = f.db.snapshot(matchPath(sessionID)).data();
  assert.equal(verified.players[1].isBot, true);
  const receipt = await createMatchRewards({db: f.db, clock: f.clock}).settle("a", {sessionID});
  assert.equal(receipt.matchReward, 20);
  assert.equal(f.db.snapshot("coinWallets/a").data().rewardedBotWins.count, 1);
});

test("queue and actions fail closed while disabled", async () => {
  const f = fixture(); f.db.set("economyPrivate/control", {});
  await assert.rejects(f.join("a"), /not enabled/);
});

test("timed result requires full server duration and a bounded delivery window", async () => {
  const f = fixture("anagram");
  f.db.set("economyPrivate/matchPuzzles/records/p", {...f.puzzle, letters: "CATDOG", validWords: ["CAT", "DOG"]});
  const sessionID = await f.paired();
  await assert.rejects(f.api.submit("a", {sessionID, evidence: {words: ["CAT"]}, elapsedSeconds: 60}), /not finished/);
  f.advance(60000); await f.api.submit("a", {sessionID, evidence: {words: ["CAT"]}});
  f.advance(21000); await assert.rejects(f.api.submit("b", {sessionID, evidence: {words: ["CAT", "DOG"]}}), /window expired/);
  await f.api.tick("a", {sessionID});
  assert.deepEqual(f.db.snapshot(matchPath(sessionID)).data().forfeitedIDs, ["b"]);
});

if (process.env.MATCH_CATALOG_FIXTURES) {
  const puzzles = JSON.parse(readFileSync(process.env.MATCH_CATALOG_FIXTURES, "utf8"));
  for (const p of puzzles.filter((p) => p.difficulty === presets[p.mode])) {
    test(`production puzzle/evidence verifies end-to-end: ${p.id}`, async () => {
      const f = fixture(p.mode);
      f.db.set("economyPrivate/matchPuzzles/records/p", p);
      const sessionID = await f.paired();
      f.advance((limits[p.mode] || 30) * 1000);
      const evidence = p.mode === "gridlock" ? {moves: [[0]]} : p.testEvidence;
      const verification = verifyResult(p, "a", evidence, (limits[p.mode] || 30) * 1000);
      assert.equal(verification.result.userID, "a"); assert.equal(verification.played, true);
      await f.api.submit("a", {sessionID, evidence});
      if (f.db.snapshot(privatePath(sessionID)).data().status !== "finished") await f.api.submit("b", {sessionID, evidence});
      assert.ok(f.db.snapshot(matchPath(sessionID)).exists);
      const receipt = await createMatchRewards({db: f.db, clock: f.clock}).settle("a", {sessionID});
      assert.ok(receipt.matchReward > 0);
    });
  }
  for (const p of puzzles.filter((p) => [onlineDifficulty(p.mode, "ranked", 0), onlineDifficulty(p.mode, "ranked", 3600)].includes(p.difficulty))) {
    test(`v2 generated puzzle verifies and settles: ${p.id}`, async () => {
      const f = fixture(p.mode, "ranked");
      const points = p.difficulty === onlineDifficulty(p.mode, "ranked", 0) ? 0 : 3600;
      enableV2(f, p.mode, "ranked", points);
      f.db.set("economyPrivate/matchPuzzles/records/p", p);
      const sessionID = await f.paired();
      const seconds = p.mode === "sudoku" && p.difficulty === "easy" ? 600 :
        p.mode === "minesweeper" && p.difficulty === "easy" ? 180 :
          p.mode === "colorLink" && p.difficulty === "hard" ? 420 : limits[p.mode] || 30;
      f.advance(seconds * 1000);
      const evidence = p.mode === "gridlock" ? {moves: [[0]]} : p.mode === "wordle" ?
        {rounds: p.testEvidence.rounds.slice(0, 1)} : p.testEvidence;
      await f.api.submit("a", {sessionID, evidence});
      if (f.db.snapshot(privatePath(sessionID)).data().status !== "finished") await f.api.submit("b", {sessionID, evidence});
      assert.ok(f.db.snapshot(matchPath(sessionID)).exists);
      const receipt = await createMatchRewards({db: f.db, clock: f.clock}).settle("a", {sessionID});
      assert.ok(receipt.matchReward > 0);
      assert.equal(receipt.endingRankPoints - receipt.startingRankPoints, receipt.rankDelta);
    });
  }
}
