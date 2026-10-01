/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createDailyChallenges, verifiedSummary, presets} = require("./daily-challenges");
const {createSoloRewards} = require("./solo-rewards");
const {shuffled} = require("./solo-reward-policy");

function fixture() {
  const db = new MemoryDB();
  let now = Date.parse("2026-09-30T12:00:00Z");
  const clock = () => now;
  db.set("economyPrivate/control", {walletMigrationReady: true, dailyChallengesEnabled: true, soloRewardsEnabled: true});
  for (const uid of ["alice", "bob"]) {
    db.set(`coinWallets/${uid}`, {version: 1, balance: 500, revision: 0});
    db.set(`users/${uid}`, {username: uid, coins: 500});
  }
  const evidence = {};
  for (const [mode, difficulty] of Object.entries(presets)) {
    const p = {id: mode, mode, difficulty, seed: 928000, protocolVersion: "solo-v1"};
    switch (mode) {
      case "wordle": Object.assign(p, {target: "APPLE", validGuesses: ["APPLE", "CRANE"]}); evidence[mode] = {guesses: ["APPLE"]}; break;
      case "hangman": Object.assign(p, {target: "APPLE", starter: "A", maxWrong: 6}); evidence[mode] = {letters: "PLE"}; break;
      case "anagram": case "wordHunt":
        Object.assign(p, {letters: "CAT", grid: ["CAT"], validWords: ["CAT", "ACT"]}); evidence[mode] = {words: ["CAT"]}; break;
      case "colorLink": Object.assign(p, {size: 2, pairs: [{id: 0, start: 0, end: 2}]}); evidence[mode] = {paths: {0: [0, 1, 3, 2]}}; break;
      case "sudoku": {
        p.givens = Array(81).fill(0);
        evidence[mode] = {cells: Array.from({length: 81}, (_, i) => (Math.floor(i / 9) * 3 + Math.floor(i / 27) + i % 9) % 9 + 1)};
        break;
      }
      case "minesweeper": {
        Object.assign(p, {rows: 9, cols: 9, mines: 10});
        const mines = shuffled(Array.from({length: 81}, (_, i) => i).filter((i) => ![0, 1, 9, 10].includes(i)), p.seed).slice(0, 10);
        evidence[mode] = {firstCell: 0, revealed: Array.from({length: 81}, (_, i) => i).filter((i) => !mines.includes(i))};
        break;
      }
      case "gridlock": {
        const ordered = Array.from({length: 52}, (_, i) => (i % 4) * 13 + Math.floor(i / 4));
        p.deck = []; const moves = []; let cursor = 0;
        for (let c = 0; c < 7; c++) {
          p.deck.push(...ordered.slice(cursor, cursor + c + 1).reverse());
          for (let i = c; i >= 0; i--) moves.push([1, c, i, -1]);
          cursor += c + 1;
        }
        p.deck.push(...ordered.slice(cursor).reverse());
        for (let i = cursor; i < 52; i++) moves.push([0], [1, -1, 0, -1]);
        evidence[mode] = {moves}; break;
      }
    }
    db.set(`soloPuzzles/${mode}`, p);
    db.set(`soloPuzzleCatalog/${mode}_${difficulty}`, {puzzleIDs: [mode]});
  }
  const api = createDailyChallenges({db, clock});
  const challengeID = (mode) => `2026-09-30_${mode}`;
  const begin = (mode = "wordle", uid = "alice") => api.begin(uid, {challengeID: challengeID(mode)});
  const complete = (mode = "wordle", uid = "alice", proof = evidence[mode]) => api.complete(uid, {challengeID: challengeID(mode), evidence: proof});
  return {db, api, begin, complete, evidence, clock, advance: (ms) => {
    now += ms;
  }};
}

test("all eight daily presets are pinned, identical for players and contain no private answers", async () => {
  const f = fixture();
  const [a, b] = await Promise.all([f.api.today("alice"), f.api.today("bob")]);
  assert.deepEqual(a, b); assert.equal(a.challenges.length, 8);
  for (const c of a.challenges) {
    assert.deepEqual(Object.keys(c).sort(), ["category", "dayKey", "difficulty", "id", "mode", "puzzleData", "seed"]);
    assert.equal(c.difficulty, presets[c.mode]); assert.equal(c.puzzleData, "");
  }
  f.db.set("soloPuzzleCatalog/wordle_medium", {puzzleIDs: ["missing"]});
  assert.deepEqual(await f.api.today("alice"), a);
});

test("starting or reopening never pays and cannot reset the clock", async () => {
  const f = fixture(); await f.begin(); f.advance(60000); await f.begin();
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 500);
  assert.equal((await f.complete()).dailyCoins, 25);
  assert.equal(f.db.snapshot("serverDailyChallenges/2026-09-30/entries/alice_2026-09-30_wordle").data().result.elapsedSeconds, 60);
});

test("concurrent duplicates and a lost acknowledgement pay and count only once", async () => {
  const f = fixture(); await f.begin();
  const receipts = await Promise.all(Array.from({length: 10}, () => f.complete()));
  for (const r of receipts) assert.deepEqual(r, receipts[0]);
  assert.deepEqual(await f.complete(), receipts[0]);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 525);
  assert.equal(f.db.snapshot("users/alice").data().playProgress.totalGamesPlayed, 1);
  await assert.rejects(f.begin(), /already submitted/);
});

test("all eight verified submissions pay 25 plus 50 total, even when submitted concurrently", async () => {
  const f = fixture();
  for (const mode of Object.keys(presets)) await f.begin(mode);
  f.advance(75000);
  const receipts = await Promise.all(Object.keys(presets).map((mode) => f.complete(mode)));
  assert.equal(receipts.reduce((n, r) => n + r.delta, 0), 75);
  assert.equal(receipts.filter((r) => r.completionCoins === 50).length, 1);
  assert.equal(f.db.snapshot("users/alice").data().playProgress.totalGamesPlayed, 8);
  assert.equal(f.db.snapshot("users/alice").data().dailyChallengeBonusDays["2026-09-30"], true);
  for (const mode of Object.keys(presets)) await f.complete(mode);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 575);
});

test("solo and daily completions share the same daily bonus", async () => {
  const f = fixture(); await f.begin();
  const solo = createSoloRewards({db: f.db, clock: f.clock, choose: () => 0});
  await solo.begin("alice", {attemptID: "solo1", mode: "wordle", difficulty: "medium", protocolVersion: "solo-v1"});
  const [daily, single] = await Promise.all([f.complete(), solo.complete("alice", {attemptID: "solo1", evidence: f.evidence.wordle})]);
  assert.equal(daily.dailyCoins + single.dailyCoins, 25);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 530);
});

test("fabricated public results, reward amounts, day claims and scores confer no authority", async () => {
  const f = fixture();
  f.db.set("dailyChallenges/2026-09-30/entries/alice_2026-09-30_wordle", {completed: true});
  await assert.rejects(f.complete(), /missing/);
  await f.begin();
  await assert.rejects(f.complete("wordle", "alice", {completed: true, score: 999999, coins: 999999}), /word list/);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 500);
  const r = await f.api.complete("alice", {challengeID: "2026-09-30_wordle", evidence: f.evidence.wordle, coins: 999999, completedModes: Object.keys(presets)});
  assert.equal(r.delta, 25); assert.equal(r.completionCoins, 0);
});

test("proof cannot be claimed by another user without their own started attempt", async () => {
  const f = fixture(); await f.begin();
  await assert.rejects(f.complete("wordle", "bob"), /missing/);
  assert.equal(f.db.snapshot("coinWallets/bob").data().balance, 500);
});

test("valid terminal losses count, unfinished Word Guess does not", async () => {
  const f = fixture(); await f.begin();
  await assert.rejects(f.complete("wordle", "alice", {guesses: ["CRANE"]}), /not finished/);
  assert.equal((await f.complete("wordle", "alice", {guesses: Array(6).fill("CRANE")})).dailyCoins, 25);
  const entry = f.db.snapshot("serverDailyChallenges/2026-09-30/entries/alice_2026-09-30_wordle").data();
  assert.equal(entry.result.completed, false); assert.equal(entry.result.guesses, 6);
  assert.ok(!JSON.stringify(entry).includes("CRANE")); assert.ok(!JSON.stringify(entry).includes("APPLE"));
});

test("timed dailies reject early and empty submissions; score matches the game", async () => {
  const f = fixture(); await f.begin("anagram");
  await assert.rejects(f.complete("anagram"), /not finished/);
  f.advance(60000);
  await assert.rejects(f.complete("anagram", "alice", {words: []}), /Find a word/);
  await f.complete("anagram");
  assert.equal(f.db.snapshot("serverDailyChallenges/2026-09-30/entries/alice_2026-09-30_anagram").data().result.score, 1);
});

test("rollout defaults closed; an existing receipt remains retryable after shutdown", async () => {
  const f = fixture(); await f.begin(); const receipt = await f.complete();
  f.db.set("economyPrivate/control", {});
  await assert.rejects(f.api.today("bob"), /not enabled/);
  assert.deepEqual(await f.complete(), receipt);
});

test("missing catalogs and changed canonical puzzles fail closed", async () => {
  const f = fixture(); f.db.set("soloPuzzleCatalog/wordle_medium", {puzzleIDs: []});
  await assert.rejects(f.api.today("alice"), /unavailable/);
  assert.equal(f.db.snapshot("economyPrivate/dailySchedules/days/2026-09-30").exists, false);
  const g = fixture(); await g.begin();
  g.db.set("soloPuzzles/wordle", {...g.db.snapshot("soloPuzzles/wordle").data(), target: "CRANE"});
  await assert.rejects(g.complete(), /changed/);
});

test("past/future challenges cannot start and expired results cannot pay", async () => {
  const f = fixture();
  await assert.rejects(f.api.begin("alice", {challengeID: "2026-09-29_wordle"}), /ended/);
  await f.begin(); f.advance(15 * 3600000);
  await assert.rejects(f.complete(), /expired/);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 500);
});

test("cross-midnight completion uses submission day for streak, challenge day for set bonus", async () => {
  const f = fixture(); await f.begin(); f.advance(12 * 3600000 + 1000);
  await f.complete();
  assert.equal(f.db.snapshot("coinWallets/alice").data().dailyPlayDay, "2026-10-01");
  assert.ok(f.db.snapshot("economyPrivate/dailyAccounts/users/alice/days/2026-09-30").exists);
});

test("daily rewards repay purchase refund debt through the shared ledger", async () => {
  const f = fixture(); f.db.set("coinWallets/alice", {version: 1, balance: 500, purchaseRefundDebt: 10});
  await f.begin(); const r = await f.complete();
  assert.equal(r.grossDelta, 25); assert.equal(r.delta, 15); assert.equal(r.refundDebtRecovered, 10);
});

test("a reviewed pre-migration all-dailies bonus is not paid a second time", async () => {
  const f = fixture();
  f.db.set("users/alice", {username: "alice", coins: 500, dailyChallengeBonusDays: {"2026-09-30": true}});
  for (const mode of Object.keys(presets)) await f.begin(mode);
  f.advance(75000);
  for (const mode of Object.keys(presets)) assert.equal((await f.complete(mode)).completionCoins, 0);
  assert.equal(f.db.snapshot("coinWallets/alice").data().balance, 525);
});

test("Firestore map key ordering does not invalidate a pinned puzzle", async () => {
  const f = fixture(); await f.begin();
  const p = f.db.snapshot("soloPuzzles/wordle").data();
  f.db.set("soloPuzzles/wordle", Object.fromEntries(Object.entries(p).reverse()));
  assert.equal((await f.complete()).dailyCoins, 25);
});

test("discard prevents later credit but never reverses a committed receipt", async () => {
  const f = fixture(); await f.begin();
  await f.api.discard("alice", {challengeID: "2026-09-30_wordle"});
  await assert.rejects(f.complete(), /expired or missing/);
  await assert.rejects(f.begin(), /already submitted or expired/);
  const g = fixture(); await g.begin(); const receipt = await g.complete();
  await g.api.discard("alice", {challengeID: "2026-09-30_wordle"});
  assert.deepEqual(await g.complete(), receipt);
  assert.equal(g.db.snapshot("coinWallets/alice").data().balance, 525);
});

test("invalid identifiers are rejected before constructing document paths", async () => {
  const f = fixture();
  for (const challengeID of ["../../users", "", "x".repeat(161), null]) {
    await assert.rejects(f.api.begin("alice", {challengeID}), /Invalid/);
    await assert.rejects(f.api.complete("alice", {challengeID}), /Invalid/);
  }
  await assert.rejects(f.api.today("a/b"), /Invalid/);
});

test("production Swift catalog evidence remains compatible with daily single-round verification", {
  skip: !process.env.SOLO_REWARD_CATALOG,
}, () => {
  const {readFileSync} = require("node:fs");
  const catalog = JSON.parse(readFileSync(process.env.SOLO_REWARD_CATALOG, "utf8"));
  const tested = new Set();
  for (const p of catalog) {
    if (p.difficulty !== presets[p.mode] || !p.testEvidence) continue;
    const r = verifiedSummary(p, p.testEvidence, 75000);
    assert.equal(r.completed, true); tested.add(p.mode);
  }
  assert.equal(tested.size, 7); // Solitaire replay is checked with a known winning deck above.
});
