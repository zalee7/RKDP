/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createMatchRewards, matchPath} = require("./match-rewards");
const {presets, resolveMatch, rankDelta, matchCoins, validateMatch} = require("./match-reward-policy");
const {createWalletShop} = require("./wallet-shop");
const {createSoloRewards} = require("./solo-rewards");

function result(uid, mode, seconds = 30) {
  return {userID: uid, mode, completed: true, score: 100, progress: 1, elapsedSeconds: seconds, status: "Finished",
    summary: {isFinal: "true", final: "true", solvedRounds: "2", failedRounds: "0", totalGuesses: "6", roundCount: "2",
      wordCount: "10", longestWordLength: "5", moves: "100", foundationCount: "52", solvedPairs: "6", wrongGuessCount: "1"}};
}
function fixture({mode = "sudoku", kind = "ranked", points = 0, bot = false} = {}) {
  const db = new MemoryDB();
  let now = Date.UTC(2026, 8, 29, 12);
  const clock = () => now;
  db.set("economyPrivate/control", {walletMigrationReady: true, matchRewardsEnabled: true, walletOperationsEnabled: true, soloRewardsEnabled: true});
  const users = bot ? ["a"] : ["a", "b"];
  for (const uid of users) {
    db.set(`users/${uid}`, {id: uid, username: uid, coins: 500,
      ranks: {[mode]: {points: 999999, wins: 999999, soloBestsByDifficulty: {easy: {elapsedSeconds: 20}}}}});
    db.set(`coinWallets/${uid}`, {version: 1, balance: 500, revision: 0, migratedAtMs: now - 100000,
      matchEconomyVersion: 1, matchRanks: {[mode]: {points, wins: 0, losses: 0}},
      casualRewards: {dayKey: "", count: 0}, rewardedBotWins: {dayKey: "", count: 0}});
  }
  const match = {version: 1, verifierVersion: "match-v1", sessionID: "game", status: "finished", mode, matchKind: kind,
    difficulty: presets[mode], startedAtMs: now - 60000, finishedAtMs: now - 1000,
    players: [{userID: "a", isBot: false, rankPoints: points}, {userID: "b", isBot: bot, rankPoints: points}],
    playerResults: {a: result("a", mode), b: result("b", mode, 40)}, playedUserIDs: users, forfeitedIDs: []};
  if (["anagram", "wordHunt"].includes(mode)) match.playerResults.b.score = 50;
  const save = (id = "game") => db.set(matchPath(id), {...match, sessionID: id});
  save();
  return {db, match, clock, save, service: createMatchRewards({db, clock}), advance: (ms) => {
    now += ms;
  }};
}

for (const mode of Object.keys(presets)) {
  for (const [points, win] of [[0, 20], [600, 30], [1800, 40], [3600, 50], [7200, 60], [12000, 75]]) {
    test(`${mode} ranked starting rank ${points}: win ${win}, loss 5, shared daily bonus`, async () => {
      const f = fixture({mode, points});
      const reply = await f.service.settle("a", {sessionID: "game", winnerID: "b", amount: 9999, rankPoints: 999999});
      assert.equal(reply.matchReward, win);
      assert.equal(reply.dailyCoins, 25);
      assert.equal(f.db.snapshot("coinWallets/b/receipts/match_game").data().matchReward, 5);
      assert.equal(f.db.snapshot("users/b").data().coins, 530);
      assert.deepEqual(f.db.snapshot("users/a").data().ranks[mode].soloBestsByDifficulty, {easy: {elapsedSeconds: 20}});
      assert.equal(f.db.snapshot("users/a").data().ranks[mode].wins, 1, "public forged rank is not authority");
      assert.equal(f.db.snapshot(`leaderboards/${mode}/entries/a`).data().rankPoints, points + reply.rankDelta);
    });
  }
  test(`${mode} exact draw pays 10 and applies one rank change per player`, async () => {
    const f = fixture({mode});
    f.match.playerResults.b = {...structuredClone(f.match.playerResults.a), userID: "b"}; f.save();
    const reply = await f.service.settle("a", {sessionID: "game"});
    assert.equal(reply.winnerID, null); assert.equal(reply.matchReward, 10);
    assert.equal(f.db.snapshot("coinWallets/b/receipts/match_game").data().matchReward, 10);
  });
}

test("both participants racing retries settle both wallets only once, including after pause", async () => {
  const f = fixture();
  const replies = await Promise.all(Array.from({length: 24}, (_, i) => f.service.settle(i % 2 ? "a" : "b", {sessionID: "game"})));
  assert.equal(replies.filter((r) => r.didApplyRewards).length, 1);
  for (const uid of ["a", "b"]) {
    assert.equal(f.db.snapshot(`coinWallets/${uid}`).data().revision, 1);
    assert.equal(f.db.snapshot(`users/${uid}`).data().playProgress.totalGamesPlayed, 1);
  }
  f.db.set("economyPrivate/control", {});
  assert.equal((await f.service.settle("a", {sessionID: "game"})).matchReward, 20);
});

test("public client-authored sessions and caller evidence cannot award coins", async () => {
  const f = fixture();
  f.db.documents.delete(matchPath("game"));
  f.db.set("sessions/game", f.match);
  await assert.rejects(f.service.settle("a", {sessionID: "game", verified: true, match: f.match}), /Verified match/);
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
});

test("outsiders, bot callers and path traversal cannot settle", async () => {
  const f = fixture({bot: true});
  f.db.set("coinWallets/outsider", f.db.snapshot("coinWallets/a").data()); f.db.set("users/outsider", {coins: 500});
  await assert.rejects(f.service.settle("outsider", {sessionID: "game"}), /participant/);
  await assert.rejects(f.service.settle("b", {sessionID: "game"}));
  await assert.rejects(f.service.settle("a", {sessionID: "../game"}));
  assert.equal(f.db.snapshot("coinWallets/a").data().revision, 0);
});

test("atomic settlement rejects missing opponent wallet, legacy payouts, and pre-migration games", async () => {
  for (const variant of ["missing", "legacy", "old", "malformedCounter"]) {
    const f = fixture();
    if (variant === "missing") f.db.documents.delete("coinWallets/b");
    if (variant === "legacy") f.db.set("users/b", {coins: 500, appliedRankedOutcomes: {game: true}});
    if (variant === "old") {
      f.match.startedAtMs = 0; f.save();
    }
    if (variant === "malformedCounter") {
      const wallet = f.db.snapshot("coinWallets/b").data(); wallet.casualRewards.count = -1; f.db.set("coinWallets/b", wallet);
    }
    await assert.rejects(f.service.settle("a", {sessionID: "game"}));
    assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
    assert.ok(!f.db.snapshot("coinWallets/a/receipts/match_game").exists);
  }
});

test("failure crediting the second wallet rolls back the first wallet and all receipts", async () => {
  const f = fixture();
  const wallet = f.db.snapshot("coinWallets/b").data();
  wallet.balance = Number.MAX_SAFE_INTEGER; f.db.set("coinWallets/b", wallet);
  await assert.rejects(f.service.settle("a", {sessionID: "game"}));
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
  assert.ok(!f.db.snapshot("coinWallets/a/receipts/match_game").exists);
  assert.equal(f.db.snapshot(matchPath("game")).data().settledAtMs, undefined);
});

test("new settlements honor both rollout gates", async () => {
  for (const flag of ["walletMigrationReady", "matchRewardsEnabled"]) {
    const f = fixture();
    const control = f.db.snapshot("economyPrivate/control").data(); control[flag] = false;
    f.db.set("economyPrivate/control", control);
    await assert.rejects(f.service.settle("a", {sessionID: "game"}), /paused/);
    assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
  }
});

test("partial word rounds and unfinished races never settle", async () => {
  for (const mode of ["wordle", "hangman", "sudoku"]) {
    const f = fixture({mode});
    if (mode === "sudoku") {
      f.match.playerResults.a.completed = false; delete f.match.playerResults.b;
    } else {
      f.match.playerResults.a.summary.isFinal = "false"; f.match.playerResults.a.summary.final = "false";
    }
    f.save(); await assert.rejects(f.service.settle("a", {sessionID: "game"}), /not finished/);
  }
});

test("first-finisher races pay normal losing player but only verified participation earns daily play", async () => {
  const f = fixture(); delete f.match.playerResults.b; f.match.playedUserIDs = ["a"]; f.save();
  await f.service.settle("a", {sessionID: "game"});
  const receipt = f.db.snapshot("coinWallets/b/receipts/match_game").data();
  assert.equal(receipt.matchReward, 5); assert.equal(receipt.dailyCoins, 0);
});

test("forfeits never produce quitter or synthetic winner coins/daily bonuses", async () => {
  for (const kind of ["ranked", "casual"]) {
    const f = fixture({kind}); f.match.forfeitedIDs = ["b"];
    f.match.playerResults.a.status = "Won by forfeit"; f.match.playerResults.b.status = "Forfeited"; f.save();
    await f.service.settle("a", {sessionID: "game"});
    for (const uid of ["a", "b"]) assert.equal(f.db.snapshot(`coinWallets/${uid}`).data().balance, 500);
  }
});

test("a genuinely completed winner retains payout when the opponent forfeits", async () => {
  const f = fixture(); f.match.forfeitedIDs = ["b"]; f.match.playerResults.b.status = "Forfeited"; f.save();
  assert.equal((await f.service.settle("a", {sessionID: "game"})).matchReward, 20);
  assert.equal(f.db.snapshot("coinWallets/b").data().balance, 500);
});

test("bot wins stop at three globally per UTC day; losses/draws never mint match coins", async () => {
  const f = fixture({bot: true});
  for (let i = 0; i < 5; i++) f.save(`bot${i}`);
  const replies = await Promise.all(Array.from({length: 5}, (_, i) => f.service.settle("a", {sessionID: `bot${i}`})));
  assert.equal(replies.reduce((sum, r) => sum + r.matchReward, 0), 60);
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 585);
  assert.equal(f.db.snapshot("users/a").data().ranks.sudoku.wins, 3);
  assert.equal(f.db.snapshot("users/a").data().ranks.sudoku.points, 45);
  f.advance(86400000); f.save("nextday");
  assert.equal((await f.service.settle("a", {sessionID: "nextday"})).matchReward, 20);
  f.match.playerResults.a.elapsedSeconds = 50; f.save("loss");
  assert.equal((await f.service.settle("a", {sessionID: "loss"})).matchReward, 0);
  f.match.playerResults.a.elapsedSeconds = 40; f.save("draw");
  assert.equal((await f.service.settle("a", {sessionID: "draw"})).matchReward, 0);
});

test("casual cap is shared across matches and only resets on server UTC day", async () => {
  const f = fixture({kind: "casual"});
  const wallet = f.db.snapshot("coinWallets/a").data(); wallet.casualRewards = {dayKey: "2026-09-29", count: 83}; f.db.set("coinWallets/a", wallet);
  const a = await f.service.settle("a", {sessionID: "game", dayKey: "2099-01-01"});
  assert.equal(a.matchReward, 7); assert.equal(a.rankDelta, 0);
  f.save("game2"); assert.equal((await f.service.settle("a", {sessionID: "game2"})).matchReward, 0);
  f.advance(86400000); f.save("game3"); assert.equal((await f.service.settle("a", {sessionID: "game3"})).matchReward, 15);
});

test("human ranked payouts have no daily cap", async () => {
  const f = fixture({points: 12000});
  for (let i = 0; i < 20; i++) f.save(`human${i}`);
  for (let i = 0; i < 20; i++) assert.equal((await f.service.settle("a", {sessionID: `human${i}`})).matchReward, 75);
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 2025);
});

test("solo and match daily bonus plus shop claim share balance without duplicate daily play", async () => {
  const f = fixture();
  f.db.set("soloPuzzleCatalog/wordle_easy", {puzzleIDs: ["puzzle"]});
  f.db.set("soloPuzzles/puzzle", {id: "puzzle", protocolVersion: "solo-v1", mode: "wordle", difficulty: "easy",
    seed: 1, target: "APPLE", validGuesses: ["APPLE"]});
  const solo = createSoloRewards({db: f.db, clock: f.clock, choose: () => 0});
  await solo.begin("a", {attemptID: "attempt", protocolVersion: "solo-v1", mode: "wordle", difficulty: "easy"});
  const shop = createWalletShop({db: f.db, clock: f.clock});
  await Promise.all([shop.claimDaily("a"), f.service.settle("a", {sessionID: "game"}),
    solo.complete("a", {attemptID: "attempt", evidence: {guesses: ["APPLE"]}})]);
  f.save("second"); await f.service.settle("a", {sessionID: "second"});
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 619);
  assert.equal(f.db.snapshot("users/a").data().playProgress.totalGamesPlayed, 3);
});

test("malformed private records fail closed", async () => {
  for (const change of [
    (m) => {
      m.status = "inProgress";
    }, (m) => {
      m.difficulty = "expert";
    },
    (m) => {
      m.players[0].rankPoints = -1;
    }, (m) => {
      m.players[1].userID = "a";
    },
    (m) => {
      m.playerResults.a.summary.totalGuesses = "NaN";
    }, (m) => {
      m.playerResults.a.progress = Infinity;
    },
    (m) => {
      m.finishedAtMs = Number.MAX_SAFE_INTEGER;
    }, (m) => {
      m.matchKind = "party";
    },
  ]) {
    const f = fixture(); change(f.match); f.save();
    await assert.rejects(f.service.settle("a", {sessionID: "game"}));
    assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
  }
});

if (process.env.MATCH_POLICY_FIXTURES) {
  const fixtures = JSON.parse(require("node:fs").readFileSync(process.env.MATCH_POLICY_FIXTURES, "utf8"));
  test("server winner, reward and rank policies match exported production Swift cases", () => {
    for (const f of fixtures) {
      validateMatch(f.match, f.match.sessionID, Date.UTC(2030, 0, 1));
      const winner = resolveMatch(f.match);
      assert.equal(winner, f.winnerID, f.label);
      for (const p of f.match.players.filter((p) => !p.isBot)) {
        assert.equal(matchCoins(f.match, p.userID, winner, true), f.coins[p.userID], f.label);
        assert.equal(rankDelta(f.match, p.userID, winner), f.rankDeltas[p.userID], f.label);
      }
    }
  });
}
