/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createWalletShop, rotationIDs} = require("./wallet-shop");
const {createSoloRewards} = require("./solo-rewards");
const {migrateWallet} = require("./wallet-migration");
const {snapshotHash, readWallet, commitWallet} = require("./wallet-ledger");

function fixture(balance = 1000) {
  const db = new MemoryDB();
  let now = Date.UTC(2026, 8, 29, 12);
  db.set("economyPrivate/control", {walletMigrationReady: true, walletOperationsEnabled: true,
    soloRewardsEnabled: true, migrationsEnabled: true});
  db.set("users/player", {coins: balance, cosmetics: {purchasedIDs: ["head_none"], equippedAvatarHead: "head_none"}});
  db.set("coinWallets/player", {version: 1, balance, revision: 0});
  db.set("economyPrivate/cosmeticCatalog", {version: 1, defaultIDs: ["head_none"], items: [
    {id: "head_none", slot: "equippedAvatarHead", category: "Avatar Head", price: 0, rarity: "free", available: false},
    {id: "head_hat", slot: "equippedAvatarHead", category: "Avatar Head", price: 450, rarity: "common", available: true},
    {id: "head_crown", slot: "equippedAvatarHead", category: "Avatar Head", price: 900, rarity: "rare", available: true},
    {id: "head_hidden", slot: "equippedAvatarHead", category: "Avatar Head", price: 100, rarity: "common", available: false},
  ]});
  const clock = () => now;
  return {db, clock, shop: createWalletShop({db, clock}), advance: (ms) => {
    now += ms;
  }};
}

test("daily claims use server UTC day and pay once under concurrent retries", async () => {
  const {db, shop, advance} = fixture();
  const results = await Promise.all(Array.from({length: 20}, () => shop.claimDaily("player", {dayKey: "2099-01-01", amount: 9999})));
  results.forEach((r) => assert.deepEqual(r, results[0]));
  assert.equal(results[0].delta, 50);
  assert.equal(db.snapshot("users/player").data().coins, 1050);
  assert.equal(db.snapshot("coinWallets/player").data().revision, 1);
  advance(86400000);
  assert.equal((await shop.claimDaily("player")).balance, 1100);
});

test("shop price and inventory are server-owned; duplicate purchase costs once", async () => {
  const {db, shop} = fixture();
  const results = await Promise.all(Array.from({length: 12}, () => shop.purchaseCosmetic("player", {itemID: "head_hat", price: 0})));
  results.forEach((r) => assert.deepEqual(r, results[0]));
  assert.equal(results[0].coinsSpent, 450);
  assert.equal(db.snapshot("users/player").data().coins, 550);
  assert.deepEqual(db.snapshot("users/player").data().cosmetics.purchasedIDs.sort(), ["head_hat", "head_none"]);
  assert.equal(db.snapshot("users/player").data().cosmetics.equippedAvatarHead, "head_hat");
});

test("two purchases cannot overdraw the same wallet", async () => {
  const {db, shop} = fixture();
  const result = await Promise.allSettled([shop.purchaseCosmetic("player", {itemID: "head_hat"}),
    shop.purchaseCosmetic("player", {itemID: "head_crown"})]);
  assert.equal(result.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(db.snapshot("coinWallets/player").data().balance, 550);
  assert.ok(!db.snapshot("coinWallets/player/receipts/cosmetic_head_crown").exists);
});

test("unknown, hidden, malformed and unaffordable cosmetics do not alter the account", async () => {
  const {db, shop} = fixture(50);
  for (const itemID of ["head_hat", "head_hidden", "missing", "../../someone"]) {
    await assert.rejects(shop.purchaseCosmetic("player", {itemID}));
  }
  assert.equal(db.snapshot("users/player").data().coins, 50);
  assert.equal(db.snapshot("coinWallets/player").data().revision, 0);
});

test("stale displayed price is rejected before any charge", async () => {
  const {db, shop} = fixture();
  await assert.rejects(shop.purchaseCosmetic("player", {itemID: "head_hat", expectedPrice: 1}));
  assert.equal(db.snapshot("coinWallets/player").data().balance, 1000);
});

test("equipping validates ownership/slot and cannot overwrite inventory", async () => {
  const {db, shop} = fixture();
  await assert.rejects(shop.equip("player", {selection: {equippedAvatarHead: "head_hat"}}));
  await assert.rejects(shop.equip("player", {selection: {purchasedIDs: ["head_crown"]}}));
  await shop.purchaseCosmetic("player", {itemID: "head_hat"});
  await assert.rejects(shop.equip("player", {selection: {equippedTitle: "head_hat"}}));
  await assert.rejects(shop.equip("player", {selection: {customAvatarBodyHex: "#bad"}}));
  await shop.equip("player", {selection: {equippedAvatarHead: "head_none", customAvatarBodyHex: "aabbcc"}});
  const user = db.snapshot("users/player").data();
  assert.ok(user.cosmetics.purchasedIDs.includes("head_hat"));
  assert.equal(user.cosmetics.customAvatarBodyHex, "AABBCC");
  assert.equal(user.coins, 550);
});

test("solo, shop claim and spending share one ledger without lost updates", async () => {
  const {db, shop, clock} = fixture();
  db.set("soloPuzzleCatalog/wordle_easy", {puzzleIDs: ["puzzle"]});
  db.set("soloPuzzles/puzzle", {id: "puzzle", protocolVersion: "solo-v1", mode: "wordle", difficulty: "easy",
    seed: 1, target: "APPLE", validGuesses: ["APPLE"]});
  const solo = createSoloRewards({db, clock, choose: () => 0});
  await solo.begin("player", {attemptID: "attempt", protocolVersion: "solo-v1", mode: "wordle", difficulty: "easy"});
  await Promise.all([solo.complete("player", {attemptID: "attempt", evidence: {guesses: ["APPLE"]}}),
    shop.claimDaily("player"), shop.purchaseCosmetic("player", {itemID: "head_hat"})]);
  const wallet = db.snapshot("coinWallets/player").data();
  assert.equal(wallet.balance, 1000 + 4 + 25 + 50 - 450);
  assert.equal(wallet.revision, 3);
  assert.equal(db.snapshot("users/player").data().coins, wallet.balance);
});

test("legacy inventory purchase retries do not deduct again", async () => {
  const {db, shop} = fixture();
  const user = db.snapshot("users/player").data();
  user.cosmetics.purchasedIDs.push("head_hat");
  db.set("users/player", user);
  assert.equal((await shop.purchaseCosmetic("player", {itemID: "head_hat"})).delta, 0);
});

test("paused wallet rejects new mutations but returns existing receipts", async () => {
  const {db, shop} = fixture();
  const receipt = await shop.claimDaily("player");
  db.set("economyPrivate/control", {});
  assert.deepEqual(await shop.claimDaily("player"), receipt);
  await assert.rejects(shop.purchaseCosmetic("player", {itemID: "head_hat"}));
  await assert.rejects(shop.equip("player", {selection: {equippedAvatarHead: "head_none"}}));
});

test("migration requires reviewed snapshot, is repeat-safe, and preserves balances/caps/ownership", async () => {
  const {db, clock, shop} = fixture();
  db.documents.delete("coinWallets/player");
  const user = db.snapshot("users/player").data();
  user.coinWallet = {claimedDailyCoinDay: "2026-09-29", processedTransactions: {old: true},
    casualRewards: {dayKey: "2026-09-29", count: 85}};
  user.botMatchProgress = {rewardedBotWins: {dayKey: "2026-09-29", count: 3}};
  user.ranks = {sudoku: {points: 600, wins: 12, losses: 4, soloBestsByDifficulty: {easy: {elapsedSeconds: 20}}}};
  user.playProgress = {lastRewardDay: "2026-09-29", currentStreak: 9, totalGamesPlayed: 32};
  db.set("users/player", user);
  await assert.rejects(migrateWallet({db, uid: "player", clock}));
  db.set("economyPrivate/migrations/users/player", {version: 1, approved: true, approvedBy: "operator", expectedHash: snapshotHash(user)});
  const first = await migrateWallet({db, uid: "player", clock});
  assert.deepEqual(await migrateWallet({db, uid: "player", clock}), first);
  assert.equal(first.balance, 1000);
  assert.equal(first.dailyPlayDay, "2026-09-29");
  assert.equal(first.matchEconomyVersion, 1);
  assert.deepEqual(first.casualRewards, user.coinWallet.casualRewards);
  assert.deepEqual(first.rewardedBotWins, user.botMatchProgress.rewardedBotWins);
  assert.deepEqual(first.matchRanks, {sudoku: {points: 600, wins: 12, losses: 4}});
  assert.equal((await shop.claimDaily("player")).delta, 0);
  assert.deepEqual(db.snapshot("users/player").data().cosmetics, user.cosmetics);
  assert.deepEqual(db.snapshot("users/player").data().coinWallet.processedTransactions, {old: true});
  assert.equal(db.snapshot("economyPrivate/migrationSnapshots/users/player").data().coins, 1000);
});

test("migration aborts if user economy changed after operator approval", async () => {
  const {db, clock} = fixture();
  db.documents.delete("coinWallets/player");
  const user = db.snapshot("users/player").data();
  db.set("economyPrivate/migrations/users/player", {version: 1, approved: true, approvedBy: "operator", expectedHash: snapshotHash(user)});
  db.set("users/player", {...user, coins: 1001});
  await assert.rejects(migrateWallet({db, uid: "player", clock}));
  assert.ok(!db.snapshot("coinWallets/player").exists);
});

test("ledger rejects overflow, negative balance and nonexistent accounts", async () => {
  const {db} = fixture();
  for (const delta of [-1001, Number.MAX_SAFE_INTEGER, 0.5]) {
    await assert.rejects(db.runTransaction(async (tx) => {
      const c = await readWallet(db, tx, "player", "test");
      return commitWallet(tx, c, {kind: "test", delta, now: 1});
    }));
  }
  await assert.rejects(db.runTransaction((tx) => readWallet(db, tx, "missing", "test")));
  assert.equal(db.snapshot("coinWallets/player").data().balance, 1000);
});

if (process.env.WALLET_CATALOG) {
  test("server cosmetic rotation matches actual Swift shop catalog and prices", () => {
    const catalog = JSON.parse(readFileSync(process.env.WALLET_CATALOG, "utf8"));
    assert.equal(new Set(catalog.items.map((i) => i.id)).size, catalog.items.length);
    assert.deepEqual([...rotationIDs(catalog, catalog.testDay * 86400000)].sort(), catalog.testRotation);
    assert.ok(catalog.defaultIDs.every((id) => catalog.items.some((i) => i.id === id)));
  });
}
