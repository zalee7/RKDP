/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {test} = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {rates, rewardAmount, puzzleIdentity, validateCompletion, shuffled} = require("./solo-reward-policy");
const {createSoloRewards} = require("./solo-rewards");

const difficulties = ["easy", "medium", "hard", "expert"];
const wordPuzzle = {id: "word1", protocolVersion: "solo-v1", mode: "wordle", difficulty: "easy", seed: 1,
  target: "APPLE", validGuesses: ["APPLE", "CRANE", "TRAIN"]};
const win = {guesses: ["APPLE"]};

test("all 32 approved reward rates and unsupported values", () => {
  const expected = {colorLink: [3, 4, 5, 7], wordle: [4, 5, 7, 9], hangman: [4, 5, 7, 9],
    anagram: [4, 5, 6, 8], wordHunt: [4, 5, 6, 8], minesweeper: [4, 6, 9, 12],
    gridlock: [5, 7, 10, 14], sudoku: [5, 8, 12, 18]};
  assert.deepEqual(rates, expected);
  for (const [mode, values] of Object.entries(expected)) difficulties.forEach((d, i) => assert.equal(rewardAmount(mode, d), values[i]));
  for (const pair of [["toString", "easy"], ["fake", "easy"], ["sudoku", "fake"]]) assert.throws(() => rewardAmount(...pair));
});

test("Word Guess requires valid final guesses; claimed score/completion cannot grant money", () => {
  assert.equal(validateCompletion(wordPuzzle, win, 0), 4);
  assert.equal(validateCompletion(wordPuzzle, {guesses: Array(7).fill("CRANE")}, 0), 0);
  for (const evidence of [{completed: true, score: 100}, {guesses: []}, {guesses: ["XXXXX"]},
    {guesses: ["CRANE"]}, {guesses: ["APPLE", "CRANE"]}, {guesses: Array(8).fill("CRANE")}]) {
    assert.throws(() => validateCompletion(wordPuzzle, evidence, 100));
  }
  assert.throws(() => validateCompletion(wordPuzzle, win, -1));
  assert.throws(() => validateCompletion(wordPuzzle, {...win, junk: "x".repeat(100000)}, 100));
});

test("Lava rejects unfinished rounds and guesses after either terminal state", () => {
  const p = {mode: "hangman", difficulty: "hard", target: "APPLE", starter: "A", maxWrong: 6};
  assert.equal(validateCompletion(p, {letters: "PLE"}, 1000), 7);
  assert.equal(validateCompletion(p, {letters: "BCDFGH"}, 1000), 0);
  for (const letters of ["", "A", "PPLE", "P", "PLEZ", "BCDFGHP"]) assert.throws(() => validateCompletion(p, {letters}, 1000));
});

test("timed modes require full server duration, distinct valid words, and positive score for base coins", () => {
  for (const mode of ["anagram", "wordHunt"]) {
    const p = {mode, difficulty: "expert", validWords: ["CAT", "ACT"]};
    const duration = mode === "anagram" ? 60000 : 75000;
    assert.throws(() => validateCompletion(p, {words: ["CAT"]}, duration - 1));
    assert.equal(validateCompletion(p, {words: ["CAT"]}, duration), 8);
    assert.equal(validateCompletion(p, {words: []}, duration), 0);
    for (const words of [["CAT", "CAT"], ["DOG"], ["cat"], ["A"]]) assert.throws(() => validateCompletion(p, {words}, duration));
  }
});

test("Color Link requires full, non-overlapping orthogonal coverage", () => {
  const p = {mode: "colorLink", difficulty: "easy", size: 2, pairs: [{id: 7, start: 0, end: 2}]};
  assert.equal(validateCompletion(p, {paths: {7: [0, 1, 3, 2]}}, 1), 3);
  for (const paths of [{7: [0, 2]}, {7: [0, 3, 1, 2]}, {7: [0, 1, 0, 2]}, {}]) assert.throws(() => validateCompletion(p, {paths}, 1));
});

test("Minesweeper reconstructs first-tap-safe layout and distinguishes loss", () => {
  const p = {mode: "minesweeper", difficulty: "easy", rows: 9, cols: 9, mines: 10, seed: 928000};
  const candidates = Array.from({length: 81}, (_, i) => i).filter((i) => ![0, 1, 9, 10].includes(i));
  const mines = shuffled(candidates, p.seed).slice(0, 10);
  const safe = Array.from({length: 81}, (_, i) => i).filter((i) => !mines.includes(i));
  assert.equal(validateCompletion(p, {firstCell: 0, revealed: safe}, 1), 4);
  assert.equal(validateCompletion(p, {firstCell: 0, revealed: [0], explodedCell: mines[0]}, 1), 0);
  for (const e of [{firstCell: 0, revealed: [0]}, {firstCell: 0, revealed: [...safe.slice(1), mines[0]]},
    {firstCell: 0, revealed: [0, 0], explodedCell: mines[0]}, {firstCell: 0, revealed: [0], explodedCell: 1}]) {
    assert.throws(() => validateCompletion(p, e, 1));
  }
});

function solitaireFixture() {
  const ordered = Array.from({length: 52}, (_, i) => (i % 4) * 13 + Math.floor(i / 4));
  const deck = [];
  const moves = [];
  let cursor = 0;
  for (let c = 0; c < 7; c++) {
    deck.push(...ordered.slice(cursor, cursor + c + 1).reverse());
    for (let i = c; i >= 0; i--) moves.push([1, c, i, -1]);
    cursor += c + 1;
  }
  deck.push(...ordered.slice(cursor).reverse());
  for (let i = cursor; i < 52; i++) moves.push([0], [1, -1, 0, -1]);
  return {p: {mode: "gridlock", difficulty: "easy", deck}, e: {moves}};
}

test("Solitaire replays a complete legal game and rejects forged shortcuts", () => {
  const {p, e} = solitaireFixture();
  assert.equal(validateCompletion(p, e, 1), 5);
  assert.throws(() => validateCompletion(p, {moves: []}, 1));
  assert.throws(() => validateCompletion(p, {moves: [[1, 6, 0, -1]]}, 1));
  assert.throws(() => validateCompletion(p, {moves: e.moves.slice(0, -1)}, 1));
  assert.throws(() => validateCompletion(p, {moves: [[0], [1, -1, 0, -1], ...e.moves]}, 1));
  assert.throws(() => validateCompletion(p, {moves: [[1, 0, 0, 0]]}, 1));
});

test("puzzle identity survives difficulty/version/seed changes and cosmetic pair IDs", () => {
  assert.equal(puzzleIdentity(wordPuzzle), puzzleIdentity({...wordPuzzle, difficulty: "expert", seed: 100, protocolVersion: "future"}));
  assert.notEqual(puzzleIdentity(wordPuzzle), puzzleIdentity({...wordPuzzle, target: "CRANE"}));
  const p = {mode: "colorLink", size: 2, pairs: [{id: 0, start: 0, end: 1}, {id: 1, start: 2, end: 3}]};
  assert.equal(puzzleIdentity(p), puzzleIdentity({...p, pairs: [{id: 7, start: 3, end: 2}, {id: 8, start: 1, end: 0}]}));
});

const {MemoryDB} = require("./test-support/memory-firestore");

function setup() {
  const db = new MemoryDB();
  let now = Date.UTC(2026, 8, 29, 12);
  db.set("economyPrivate/control", {soloRewardsEnabled: true, walletMigrationReady: true});
  db.set("coinWallets/player", {version: 1, balance: 500});
  db.set("users/player", {coins: 500});
  for (const p of [wordPuzzle, {...wordPuzzle, id: "word2", seed: 2, target: "CRANE"}]) db.set(`soloPuzzles/${p.id}`, p);
  db.set("soloPuzzleCatalog/wordle_easy", {puzzleIDs: ["word1", "word2"]});
  const api = createSoloRewards({db, clock: () => now, choose: () => 0});
  const begin = (id) => api.begin("player", {attemptID: id, mode: "wordle", difficulty: "easy", protocolVersion: "solo-v1"});
  return {db, api, begin, advance: (ms) => {
    now += ms;
  }};
}

test("default-off gate requires both flags and a provisioned wallet", async () => {
  const {db, api, begin} = setup();
  for (const control of [{}, {soloRewardsEnabled: true}, {walletMigrationReady: true}]) {
    db.set("economyPrivate/control", control);
    assert.equal(await api.enabled("player"), false);
    await assert.rejects(begin("attempt"));
  }
  db.set("economyPrivate/control", {soloRewardsEnabled: true, walletMigrationReady: true});
  db.documents.delete("coinWallets/player");
  await assert.rejects(begin("attempt"));
});

test("duplicate starts/claims are idempotent; active attempt excludes a second device", async () => {
  const {db, api, begin} = setup();
  const [a, b] = await Promise.all([begin("same"), begin("same")]);
  assert.deepEqual(a, b);
  assert.deepEqual(Object.keys(a).sort(), ["id", "mode", "difficulty", "seed", "reward", "expiresAtMs", "protocolVersion"].sort());
  assert.deepEqual(await begin("other"), a); // Reinstall/second device resumes the same clock.
  const claims = await Promise.all(Array.from({length: 12}, () => api.complete("player", {attemptID: "same", evidence: win})));
  claims.forEach((r) => assert.deepEqual(r, claims[0]));
  assert.equal(claims[0].balance, 529);
  assert.equal(db.snapshot("users/player").data().coins, 529);
  assert.equal(db.snapshot("users/player").data().playProgress.totalGamesPlayed, 1);
  await assert.rejects(begin("same"));
});

test("daily +25 paid only once; next day advances streak", async () => {
  const {db, api, begin, advance} = setup();
  await begin("a");
  await api.complete("player", {attemptID: "a", evidence: win});
  await begin("b");
  const second = await api.complete("player", {attemptID: "b", evidence: {guesses: ["CRANE"]}});
  assert.equal(second.dailyCoins, 0);
  assert.equal(second.balance, 533);
  const third = {...wordPuzzle, id: "word3", seed: 3, target: "TRAIN"};
  db.set("soloPuzzles/word3", third);
  db.set("soloPuzzleCatalog/wordle_easy", {puzzleIDs: ["word3"]});
  advance(86400000);
  await begin("c");
  const receipt = await api.complete("player", {attemptID: "c", evidence: {guesses: ["TRAIN"]}});
  assert.equal(receipt.dailyCoins, 25);
  assert.equal(db.snapshot("users/player").data().playProgress.currentStreak, 2);
});

test("valid failed attempt pays no puzzle reward; quitting and forged results pay nothing", async () => {
  const {db, api, begin} = setup();
  await begin("a");
  await assert.rejects(api.complete("player", {attemptID: "a", evidence: {completed: true}}));
  assert.equal(db.snapshot("coinWallets/player").data().balance, 500);
  const loss = await api.complete("player", {attemptID: "a", evidence: {guesses: Array(7).fill("CRANE")}});
  assert.equal(loss.puzzleCoins, 0);
  assert.equal(loss.dailyCoins, 25);
  await begin("b");
  await api.abandon("player", {attemptID: "b"});
  await assert.rejects(api.complete("player", {attemptID: "b", evidence: {guesses: ["CRANE"]}}));
  await assert.rejects(begin("c")); // Both puzzle identities remain reserved.
  assert.equal(db.snapshot("coinWallets/player").data().balance, 525);
});

test("expiry, ownership, catalog changes and kill switch fail closed", async () => {
  const {db, api, begin, advance} = setup();
  await begin("a");
  await assert.rejects(api.complete("intruder", {attemptID: "a", evidence: win}));
  db.set("soloPuzzles/word1", {...wordPuzzle, target: "TRAIN"});
  await assert.rejects(api.complete("player", {attemptID: "a", evidence: win}));
  db.set("soloPuzzles/word1", wordPuzzle);
  db.set("economyPrivate/control", {});
  await assert.rejects(api.complete("player", {attemptID: "a", evidence: win}));
  db.set("economyPrivate/control", {soloRewardsEnabled: true, walletMigrationReady: true});
  advance(86400000);
  await assert.rejects(api.complete("player", {attemptID: "a", evidence: win}));
  assert.equal(db.snapshot("coinWallets/player").data().balance, 500);
});

test("settlement versus abandonment cannot double grant or undo credited coins", async () => {
  for (const settleFirst of [true, false]) {
    const {db, api, begin} = setup();
    await begin("a");
    const settle = () => api.complete("player", {attemptID: "a", evidence: win});
    const abandon = () => api.abandon("player", {attemptID: "a"});
    await Promise.allSettled(settleFirst ? [settle(), abandon()] : [abandon(), settle()]);
    assert.equal(db.snapshot("coinWallets/player").data().balance, settleFirst ? 529 : 500);
  }
});

test("receipt recovery works even after payouts are paused", async () => {
  const {db, api, begin} = setup();
  await begin("a");
  const receipt = await api.complete("player", {attemptID: "a", evidence: win});
  db.set("economyPrivate/control", {});
  assert.deepEqual(await api.complete("player", {attemptID: "a", evidence: win}), receipt);
});

test("explicit discard can close an old-device attempt without its local request ID", async () => {
  const {api, begin} = setup();
  await begin("old-device");
  await api.abandon("player", {allPending: true});
  const fresh = await begin("new-device");
  assert.equal(fresh.seed, 2);
  await assert.rejects(api.complete("player", {attemptID: "old-device", evidence: win}));
});

if (process.env.SOLO_REWARD_CATALOG) {
  const catalog = JSON.parse(readFileSync(process.env.SOLO_REWARD_CATALOG, "utf8"));
  for (const p of catalog) {
    test(`Swift generator compatibility: ${p.id}`, () => {
      if (p.mode === "gridlock") assert.deepEqual(p.deck, shuffled(Array.from({length: 52}, (_, i) => i), p.seed));
      else assert.equal(validateCompletion(p, p.testEvidence, 90000), rewardAmount(p.mode, p.difficulty));
    });
  }
}
