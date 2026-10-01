/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createSocialLifecycle, path, timeLimit, compare} = require("./social-lifecycle");
const {shuffled} = require("./solo-reward-policy");
function fixture() {
  const db = new MemoryDB(); let now = Date.parse("2026-09-30T12:00:00Z"); let serial = 0;
  db.set("economyPrivate/control", {walletMigrationReady: true, socialRewardsEnabled: true});
  for (const uid of ["alice", "bob", "eve", "cara"]) {
    db.set(`coinWallets/${uid}`, {version: 1, balance: 500, revision: 0});
    db.set(`users/${uid}`, {username: uid, coins: 500});
  }
  db.set("friendships/alice_bob", {userIDs: ["alice", "bob"]});
  for (const difficulty of ["easy", "medium", "hard", "expert"]) {
    for (const mode of ["wordle", "colorLink", "anagram", "hangman"]) {
      const id = `${mode}_${difficulty}`;
      const p = {id, mode, difficulty, seed: 42, protocolVersion: "match-v1", puzzleData: ""};
      if (mode === "wordle") Object.assign(p, {targets: ["APPLE", "APPLE", "APPLE"], validGuesses: ["APPLE", "CRANE"]});
      if (mode === "colorLink") Object.assign(p, {size: 2, pairs: [{id: 0, start: 0, end: 2}]});
      if (mode === "anagram") Object.assign(p, {letters: "CAT", validWords: ["CAT", "ACT"]});
      if (mode === "hangman") Object.assign(p, {maxWrong: 6, rounds: Array.from({length: 3}, () => ({target: "APPLE", starter: "A", category: "Fruit"}))});
      db.set(`economyPrivate/matchPuzzles/records/${id}`, p);
      db.set(`economyPrivate/socialCatalog/modes/${id}`, {version: 1, puzzleIDs: [id]});
    }
  }
  const api = createSocialLifecycle({db, clock: () => now, choose: () => 0, uuid: () => String(++serial).padStart(12, "0")});
  const evidence = {wordle: {rounds: [["APPLE"], ["APPLE"]]}, colorLink: {paths: {0: [0, 1, 3, 2]}},
    anagram: {words: ["CAT"]}, hangman: {rounds: ["PLE", "PLE"]}};
  const create = async (kind = "party", modes = ["wordle"], difficulty = "medium") => (await api.create("alice", {
    requestID: `request${serial}`, kind, friendID: "bob", rounds: modes.map((mode) => ({mode, difficulty})),
  })).sessionID;
  const action = (name, sessionID, uid = "alice", extra = {}) => api[name](uid, {sessionID, ...extra});
  const start = async (id) => {
    if (id.startsWith("S1")) await action("join", id, "bob"); else await action("accept", id, "bob");
    await action("ready", id); await action("ready", id, "bob");
    if (id.startsWith("S1")) await action("start", id);
  };
  const submit = (id, uid = "alice", mode = "wordle", roundIndex = 0, proof = evidence[mode]) => action("submit", id, uid, {roundIndex, evidence: proof});
  return {db, api, create, action, start, submit, evidence, advance: (ms) => {
    now += ms;
  },
  room: (id) => db.snapshot(path(id)).data(), wallet: (uid = "alice") => db.snapshot(`coinWallets/${uid}`).data()};
}
test("creation is pinned and idempotent; seed, score and players supplied by caller are ignored", async () => {
  const f = fixture(); const data = {requestID: "same", kind: "party", rounds: [{mode: "wordle", difficulty: "expert"}], seed: 99, players: ["eve"]};
  const a = await f.api.create("alice", data); const b = await f.api.create("alice", data);
  assert.deepEqual(a, b); assert.equal(f.room(a.sessionID).rounds[0].seed, 42);
  assert.deepEqual(f.room(a.sessionID).players.map((p) => p.userID), ["alice"]);
  assert.equal(f.wallet().balance, 500);
});
test("test allowlist protects callers and invited players without changing production gates", async () => {
  const f = fixture();
  f.db.set("economyPrivate/control", {walletMigrationReady: true, socialRewardsEnabled: true, socialTestUIDs: ["alice"]});
  await assert.rejects(f.api.create("bob", {requestID: "blocked", kind: "party", rounds: [{mode: "wordle", difficulty: "medium"}]}), /not approved/);
  await assert.rejects(f.create("exhibition"), /not approved/);
  const id = await f.create();
  await assert.rejects(f.action("join", id, "bob"), /not approved/);
});
test("friend creation requires friendship and both migrated accounts", async () => {
  const f = fixture();
  await assert.rejects(f.api.create("alice", {requestID: "a", kind: "exhibition", friendID: "eve", rounds: [{mode: "wordle", difficulty: "medium"}]}), /Not friends/);
  f.db.set("coinWallets/bob", {});
  await assert.rejects(f.create("asyncExhibition"), /updated wallet/);
});
test("outsiders cannot act; only host starts and only accepted friends play", async () => {
  const f = fixture(); const id = await f.create("exhibition");
  await assert.rejects(f.action("ready", id, "bob"), /Accept/);
  await assert.rejects(f.action("accept", id, "alice"), /Invite/);
  await assert.rejects(f.action("tick", id, "eve"), /participant/);
  await assert.rejects(f.submit(id), /not started/);
  const g = fixture(); const party = await g.create(); await g.action("join", party, "bob");
  await assert.rejects(g.action("start", party, "bob"), /host/);
  await assert.rejects(g.action("start", party), /ready/);
});
test("real friend proof awards daily bonus once, duplicates and changed proof cannot overwrite it", async () => {
  const f = fixture(); const id = await f.create("exhibition"); await f.start(id); f.advance(9000);
  await Promise.all(Array.from({length: 8}, () => f.submit(id)));
  assert.equal(f.wallet().balance, 525);
  assert.equal(f.db.snapshot("users/alice").data().playProgress.totalGamesPlayed, 1);
  assert.equal(f.room(id).rounds[0].results.alice.elapsedSeconds, 9);
  await f.submit(id, "alice", "wordle", 0, {});
  assert.equal(f.wallet().balance, 525);
});
test("forged public rooms and fabricated result flags never grant rewards", async () => {
  const f = fixture(); f.db.set("sessions/sv1_forged", {status: "finished", winnerID: "alice"});
  await assert.rejects(f.submit("sv1_forged"), /not found/);
  const id = await f.create(); await f.start(id);
  await assert.rejects(f.submit(id, "alice", "wordle", 0, {completed: true, coins: 1000000}), /Incomplete/);
  assert.equal(f.wallet().balance, 500);
});
test("Play Later uses separate immutable player clocks and hides private guesses", async () => {
  const f = fixture(); const id = await f.create("asyncExhibition");
  await f.action("ready", id); f.advance(5000); await f.action("ready", id); await f.submit(id);
  assert.equal(f.room(id).rounds[0].results.alice.elapsedSeconds, 5);
  const publicData = f.db.snapshot(`sessions/${id}`).data();
  assert.ok(!JSON.stringify(publicData).includes("APPLE"));
  f.advance(3600000); await f.action("accept", id, "bob"); await f.action("ready", id, "bob");
  f.advance(2000); await f.submit(id, "bob");
  assert.equal(f.room(id).status, "finished"); assert.equal(f.room(id).winnerID, "bob");
  assert.equal(f.wallet("bob").balance, 525);
});
test("live race modes finish with first successful solver; Play Later waits for both", async () => {
  for (const kind of ["exhibition", "asyncExhibition"]) {
    const f = fixture(); const id = await f.create(kind, ["colorLink"]); await f.start(id);
    await f.submit(id, "alice", "colorLink");
    assert.equal(f.room(id).status, kind === "exhibition" ? "finished" : "inProgress");
    assert.equal(f.wallet("bob").balance, 500);
  }
});
test("first successful party solve starts one 180-second window; timeout pays nothing", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  await f.submit(id); const deadline = f.room(id).rounds[0].deadlineMs;
  f.advance(5000); await f.submit(id); assert.equal(f.room(id).rounds[0].deadlineMs, deadline);
  f.advance(175000); await Promise.all([f.action("tick", id), f.action("tick", id, "bob")]);
  assert.equal(f.room(id).status, "finished");
  assert.equal(f.room(id).rounds[0].results.bob.summary.partyTimeout, "true");
  assert.equal(f.wallet("bob").balance, 500);
  await f.submit(id, "bob"); assert.equal(f.wallet("bob").balance, 500);
});
test("losing a puzzle does not start finish window but genuine loss counts for daily play", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  await f.submit(id, "alice", "wordle", 0, {rounds: [Array(6).fill("CRANE"), Array(6).fill("CRANE")]});
  assert.equal(f.room(id).rounds[0].deadlineMs, undefined); assert.equal(f.wallet().balance, 525);
});
test("timed modes reject early submissions; empty timeout gives no reward or catch-up window", async () => {
  const f = fixture(); const id = await f.create("party", ["anagram"]); await f.start(id);
  await assert.rejects(f.submit(id, "alice", "anagram"), /not finished/);
  f.advance(60000); await f.submit(id, "alice", "anagram", 0, {words: []});
  assert.equal(f.wallet().balance, 500); assert.equal(f.room(id).rounds[0].deadlineMs, undefined);
  await f.submit(id, "bob", "anagram"); assert.equal(f.wallet("bob").balance, 525);
});
test("all-submitted party finishes early and tied placements earn equal points", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  await f.submit(id); await f.submit(id, "bob");
  const m = f.room(id); assert.equal(m.status, "finished"); assert.equal(m.winnerID, null);
  assert.deepEqual(m.rounds[0].scoreRows.map((s) => [s.placement, s.roundPoints]), [[1, 10], [1, 10]]);
});
test("three-round playlist advances only once and old retry cannot finish a new round", async () => {
  const f = fixture(); const modes = ["wordle", "colorLink", "hangman"]; const id = await f.create("party", modes); await f.start(id);
  for (const [i, mode] of modes.entries()) {
    await f.submit(id, "alice", mode, i); f.advance(1000); await f.submit(id, "bob", mode, i);
    if (i < 2) {
      await assert.rejects(f.action("advance", id, "bob", {roundIndex: i}), /host/);
      await f.action("advance", id, "alice", {roundIndex: i});
      await f.submit(id, "alice", mode, i);
      assert.deepEqual(f.room(id).rounds[i + 1].results, {});
      await assert.rejects(f.action("advance", id, "alice", {roundIndex: i}), /already advanced/);
    }
  }
  assert.equal(f.room(id).status, "finished"); assert.equal(f.room(id).winnerID, "alice");
  assert.equal(f.room(id).scores.alice, 30); assert.equal(f.room(id).scores.bob, 21);
  assert.equal(f.wallet().balance, 525); assert.equal(f.db.snapshot("users/alice").data().playProgress.totalGamesPlayed, 3);
});
test("forfeits and untouched games never count as plays", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  await f.action("forfeit", id); await f.action("forfeit", id, "bob");
  assert.equal(f.wallet().balance, 500); assert.equal(f.wallet("bob").balance, 500);
  assert.equal(f.room(id).status, "finished");
  const g = fixture(); const friend = await g.create("exhibition"); await g.start(friend);
  await g.action("forfeit", friend);
  assert.equal(g.room(friend).status, "finished"); assert.equal(g.room(friend).winnerID, "bob");
  assert.equal(g.wallet("bob").balance, 500);
});
test("joining midgame is forbidden and rejoining cannot reset start or result", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id); const before = f.room(id).rounds[0].startedAtMs;
  f.advance(10000); await f.action("join", id); await f.action("start", id);
  assert.equal(f.room(id).rounds[0].startedAtMs, before);
  await assert.rejects(f.action("join", id, "eve"), /already started/);
});
test("deadline and difficulty limits use server time, not client timestamps", async () => {
  const f = fixture(); const id = await f.create("party", ["colorLink"], "easy"); await f.start(id);
  f.advance(240000);
  await f.submit(id, "alice", "colorLink", 0, {paths: {0: [0, 1]}, elapsedSeconds: 1});
  assert.equal(f.room(id).rounds[0].results.alice.completed, false);
  assert.equal(f.room(id).rounds[0].results.alice.elapsedSeconds, 240);
  assert.equal(timeLimit("sudoku", "expert"), 1200); assert.equal(timeLimit("colorLink", "expert"), 540);
});
test("catalog mutation and disabled rollout fail closed", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  const p = f.db.snapshot("economyPrivate/matchPuzzles/records/wordle_medium").data();
  f.db.set("economyPrivate/matchPuzzles/records/wordle_medium", {...p, seed: 99});
  await assert.rejects(f.submit(id), /changed/);
  f.db.set("economyPrivate/control", {}); await assert.rejects(f.action("tick", id), /not enabled/);
  assert.equal(f.wallet().balance, 500);
});
test("refund debt and a bonus claimed elsewhere use the shared wallet ledger", async () => {
  const f = fixture(); const id = await f.create(); await f.start(id);
  f.db.set("coinWallets/alice", {...f.wallet(), purchaseRefundDebt: 10});
  f.db.set("coinWallets/bob", {...f.wallet("bob"), dailyPlayDay: "2026-09-30"});
  await f.submit(id); await f.submit(id, "bob");
  assert.equal(f.wallet().balance, 515); assert.equal(f.wallet().purchaseRefundDebt, 0);
  assert.equal(f.wallet("bob").balance, 500);
});
test("invalid paths and round indices fail before writes", async () => {
  const f = fixture();
  await assert.rejects(f.submit("sv1_/bad"), /Invalid/);
  const id = await f.create(); await f.start(id);
  for (const index of [-1, 1, 0.5, null]) await assert.rejects(f.submit(id, "alice", "wordle", index), /Invalid round/);
});
test("timeout is always below an actual result in party scoring", () => {
  const a = {completed: false, elapsedSeconds: 0, score: 0, progress: 0, summary: {partyTimeout: "true"}};
  const b = {...a, elapsedSeconds: 80, summary: {solvedRounds: "0", isFinal: "true"}};
  assert.ok(compare(a, b, "wordle") > 0);
});

test("remaining four modes settle real proof through the social wallet path", async () => {
  for (const mode of ["sudoku", "minesweeper", "wordHunt", "gridlock"]) {
    const f = fixture();
    const p = {id: `${mode}_easy`, mode, difficulty: "easy", seed: 42, protocolVersion: "match-v1", puzzleData: ""};
    let proof;
    if (mode === "sudoku") {
      p.givens = Array(81).fill(0);
      proof = {cells: Array.from({length: 81}, (_, i) => (Math.floor(i / 9) * 3 + Math.floor(i / 27) + i % 9) % 9 + 1)};
    } else if (mode === "minesweeper") {
      Object.assign(p, {rows: 9, cols: 9, mines: 10});
      const mines = shuffled(Array.from({length: 81}, (_, i) => i).filter((i) => ![0, 1, 9, 10].includes(i)), p.seed).slice(0, 10);
      proof = {firstCell: 0, revealed: Array.from({length: 81}, (_, i) => i).filter((i) => !mines.includes(i))};
    } else if (mode === "wordHunt") {
      Object.assign(p, {grid: ["CAT"], validWords: ["CAT"]}); proof = {words: ["CAT"]};
    } else {
      const cards = Array.from({length: 52}, (_, i) => (i % 4) * 13 + Math.floor(i / 4));
      p.deck = []; const moves = []; let cursor = 0;
      for (let c = 0; c < 7; c++) {
        p.deck.push(...cards.slice(cursor, cursor + c + 1).reverse());
        for (let i = c; i >= 0; i--) moves.push([1, c, i, -1]);
        cursor += c + 1;
      }
      p.deck.push(...cards.slice(cursor).reverse());
      for (let i = cursor; i < 52; i++) moves.push([0], [1, -1, 0, -1]);
      proof = {moves};
    }
    f.db.set(`economyPrivate/matchPuzzles/records/${p.id}`, p);
    f.db.set(`economyPrivate/socialCatalog/modes/${p.id}`, {version: 1, puzzleIDs: [p.id]});
    const id = await f.create("party", [mode], "easy"); await f.start(id); f.advance(75000);
    await f.submit(id, "alice", mode, 0, proof); await f.submit(id, "bob", mode, 0, proof);
    assert.equal(f.room(id).status, "finished", mode); assert.equal(f.wallet().balance, 525, mode);
    assert.equal(f.room(id).rounds[0].results.alice.completed, true, mode);
  }
});

test("concurrent friend and party submissions share one bonus; retry tomorrow does not pay again", async () => {
  const f = fixture(); const friend = await f.create("exhibition"); await f.start(friend);
  f.advance(3001); const party = await f.create(); await f.start(party);
  await Promise.all([f.submit(friend), f.submit(party)]);
  assert.equal(f.wallet().balance, 525); assert.equal(f.db.snapshot("users/alice").data().playProgress.totalGamesPlayed, 2);
  f.advance(86400000); await f.submit(friend); await f.submit(party);
  assert.equal(f.wallet().balance, 525);
});

test("lobby leaving removes guest, host cancellation closes room, stale invite cannot start", async () => {
  const f = fixture(); const id = await f.create(); await f.action("join", id, "bob");
  await f.action("forfeit", id, "bob"); assert.equal(f.room(id).players.length, 1);
  await assert.rejects(f.action("tick", id, "bob"), /participant/);
  await f.action("forfeit", id); assert.equal(f.room(id).status, "canceled");
  const g = fixture(); const invite = await g.create("exhibition"); g.advance(120001);
  await g.action("accept", invite, "bob"); assert.equal(g.room(invite).status, "abandoned");
  assert.equal(g.wallet().balance, 500);
});

test("Swift-generated social puzzles verify across every mode and difficulty", {skip: !process.env.SOCIAL_CATALOG_FIXTURES}, () => {
  const {readFileSync} = require("node:fs");
  const {verifyResult} = require("./match-evidence");
  const catalog = JSON.parse(readFileSync(process.env.SOCIAL_CATALOG_FIXTURES, "utf8"));
  const tested = new Set();
  for (const p of catalog) {
    if (!p.testEvidence) continue;
    const verified = verifyResult(p, "alice", p.testEvidence, 75000, timeLimit(p.mode, p.difficulty));
    assert.equal(verified.result.completed, true, `${p.mode} ${p.difficulty}`);
    assert.equal(verified.played, true); tested.add(`${p.mode}_${p.difficulty}`);
  }
  assert.equal(tested.size, 28); // Solitaire's legal move replay has separate known-deck coverage.
});
