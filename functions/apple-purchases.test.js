/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {generateKeyPairSync} = require("node:crypto");
const {MemoryDB} = require("./test-support/memory-firestore");
const {createApplePurchases, products, purchasePath, bindingPath} = require("./apple-purchases");
const {createAppleVerifier} = require("./apple-verifier");
const {readWallet, commitWallet} = require("./wallet-ledger");
const token = "11111111-1111-4111-8111-111111111111";
if (process.env.APPLE_PRODUCT_CATALOG) {
  test("server product amounts and ranked mappings match the production Swift catalog", () => {
    const catalog = JSON.parse(require("node:fs").readFileSync(process.env.APPLE_PRODUCT_CATALOG, "utf8"));
    assert.deepEqual(products, catalog);
  });
}
function fixture() {
  const db = new MemoryDB(); let now = 1800000000000; let appleCalls = 0;
  db.set("economyPrivate/control", {walletMigrationReady: true, purchasesEnabled: true, purchaseNotificationsEnabled: true});
  for (const uid of ["a", "b"]) {
    db.set(`coinWallets/${uid}`, {version: 1, balance: 500, revision: 0, migratedAtMs: now - 100000,
      appAccountToken: uid === "a" ? token : "22222222-2222-4222-8222-222222222222", rankedAccess: {}});
    db.set(`users/${uid}`, {coins: 500, rankedAccess: {}});
  }
  let current = {transactionId: "100", originalTransactionId: "100", productId: "com.gridduel.coins.small",
    environment: "Sandbox", bundleId: "com.rkdp.app", type: "Consumable", quantity: 1,
    inAppOwnershipType: "PURCHASED", appAccountToken: token, purchaseDate: now - 1000, signedDate: now};
  const apple = {currentTransaction: async (signed) => {
    appleCalls++; assert.equal(signed, "verified-jws"); return structuredClone(current);
  }, notification: async (signed) => {
    assert.equal(signed, "verified-notification");
    return {notificationType: "REFUND", data: {signedTransactionInfo: "verified-jws"}};
  }};
  const api = createApplePurchases({db, apple, environment: "Sandbox", clock: () => now});
  return {db, api, calls: () => appleCalls, claim: (uid = "a") => api.claim(uid, {signedTransaction: "verified-jws"}),
    set: (values) => {
      now += 1000; current = {...current, signedDate: now, ...values};
    },
    revoke: () => {
      now += 1000; current = {...current, signedDate: now, revocationDate: now};
    },
    restore: () => {
      now += 1000; delete current.revocationDate; current.signedDate = now;
    }};
}

for (const [productId, p] of Object.entries(products)) {
  test(`verified catalog product delivers once: ${productId}`, async () => {
    const f = fixture(); f.set({productId, type: p.coins ? "Consumable" : "Non-Consumable"});
    await Promise.all([f.claim(), f.claim(), f.claim()]);
    const w = f.db.snapshot("coinWallets/a").data();
    assert.equal(w.balance, 500 + (p.coins || 0)); assert.equal(w.revision, 1);
    if (p.mode === "all") assert.equal(w.rankedAccess.allModesUnlocked, true);
    else if (p.mode) assert.ok(w.rankedAccess.unlockedModeIDs.includes(p.mode));
    assert.equal(f.db.snapshot(purchasePath("Sandbox", "100")).data().uid, "a");
  });
}
test("stable server token survives new calls and cannot bind another account", async () => {
  const f = fixture(); assert.equal((await f.api.prepare("a")).appAccountToken, token);
  assert.equal((await f.api.prepare("a")).appAccountToken, token);
  await assert.rejects(f.claim("b"), /another account/);
  assert.equal(f.db.snapshot("coinWallets/b").data().balance, 500);
});
test("recovery after committed delivery with lost client acknowledgement does not grant twice", async () => {
  const f = fixture();
  await f.claim(); // Simulate termination after commit, before the app finishes StoreKit's transaction.
  const retry = await f.claim();
  assert.equal(retry.accepted, true);
  assert.equal(retry.balance, 1500);
  assert.equal(f.db.snapshot("coinWallets/a").data().revision, 1);
  assert.equal(f.db.snapshot("users/a").data().coins, 1500);
});
test("server notification delivery before client recovery credits the purchase only once", async () => {
  const f = fixture();
  await f.api.prepare("a");
  await f.api.notify("verified-notification");
  await f.claim();
  await f.api.notify("verified-notification");
  const w = f.db.snapshot("coinWallets/a").data();
  assert.equal(w.balance, 1500);
  assert.equal(w.revision, 1);
  assert.equal(f.db.snapshot("users/a").data().coins, 1500);
});
test("client amounts/product names do not authorize a credit", async () => {
  const f = fixture(); await f.api.claim("a", {signedTransaction: "verified-jws", coins: 999999, productID: "fake"});
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 1500);
});
test("wrong app/environment/type/ownership/token/product/quantity/dates fail closed", async () => {
  for (const invalid of [{bundleId: "other"}, {environment: "Production"}, {type: "Non-Consumable"},
    {inAppOwnershipType: "FAMILY_SHARED"}, {appAccountToken: undefined}, {productId: "fake"}, {quantity: 2},
    {signedDate: 1}, {transactionId: "../100"}, {purchaseDate: 1}]) {
    const f = fixture(); f.set(invalid); await assert.rejects(f.claim());
    assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
  }
});
test("disabled purchases make no Apple request; notifications have their own switch", async () => {
  const f = fixture(); f.db.set("economyPrivate/control", {walletMigrationReady: true});
  await assert.rejects(f.claim(), /not enabled/); assert.equal(f.calls(), 0);
});
test("refund removes only granted coins once, with no negative balance", async () => {
  const f = fixture(); await f.claim(); f.revoke();
  await f.api.notify("verified-notification"); await f.api.notify("verified-notification");
  const w = f.db.snapshot("coinWallets/a").data(); assert.equal(w.balance, 500); assert.equal(w.revision, 2);
});
test("spent refunds create debt; subsequent shared-wallet credits repay it", async () => {
  const f = fixture(); await f.claim();
  f.db.set("coinWallets/a", {...f.db.snapshot("coinWallets/a").data(), balance: 100});
  f.revoke(); await f.api.notify("verified-notification");
  assert.equal(f.db.snapshot("coinWallets/a").data().purchaseRefundDebt, 900);
  await f.db.runTransaction(async (tx) => {
    const context = await readWallet(f.db, tx, "a", "test_reward");
    const r = commitWallet(tx, context, {kind: "test", delta: 75, now: 1800000100000});
    assert.equal(r.grossDelta, 75); assert.equal(r.delta, 0); assert.equal(r.refundDebtRecovered, 75);
  });
  f.restore(); await f.api.notify("verified-notification");
  const w = f.db.snapshot("coinWallets/a").data();
  assert.equal(w.purchaseRefundDebt, 0); assert.equal(w.balance, 175);
});
test("refund-before-delivery grants nothing, reversal grants exactly once", async () => {
  const f = fixture(); await f.api.prepare("a"); f.revoke(); await f.api.notify("verified-notification");
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
  f.restore(); await f.claim(); await f.claim(); assert.equal(f.db.snapshot("coinWallets/a").data().balance, 1500);
});
test("ranked refund removes only the refunded grant, preserving counters and other passes", async () => {
  const f = fixture();
  f.set({productId: "com.gridduel.ranked.all", type: "Non-Consumable"}); await f.claim();
  f.set({productId: "com.gridduel.ranked.sudoku", transactionId: "200", originalTransactionId: "200"}); await f.claim();
  f.set({productId: "com.gridduel.ranked.all", transactionId: "100", originalTransactionId: "100"});
  f.revoke(); await f.api.notify("verified-notification");
  const access = f.db.snapshot("coinWallets/a").data().rankedAccess;
  assert.equal(access.allModesUnlocked, false); assert.deepEqual(access.unlockedModeIDs, ["sudoku"]);
  f.restore(); await f.claim(); assert.equal(f.db.snapshot("coinWallets/a").data().rankedAccess.allModesUnlocked, true);
});
test("stale callbacks cannot undo newer refunds", async () => {
  const f = fixture(); await f.claim(); f.revoke(); await f.api.notify("verified-notification");
  f.set({signedDate: 1800000000000, revocationDate: undefined}); await f.claim();
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
});
test("unknown token notifications fail rather than lose a refund", async () => {
  const f = fixture(); f.revoke(); await assert.rejects(f.api.notify("verified-notification"), /another account/);
  assert.equal(f.db.snapshot(bindingPath(token)).exists, false);
});
test("failed signature verification cannot mutate wallet", async () => {
  const f = fixture(); await assert.rejects(f.api.claim("a", {signedTransaction: "forged"}));
  assert.equal(f.db.snapshot("coinWallets/a").data().balance, 500);
});
test("real Apple verifier rejects malformed/unsigned data and local-test environments", async () => {
  const {privateKey} = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  const config = {environment: "Sandbox", keyID: "TEST", issuerID: token,
    signingKey: privateKey.export({type: "pkcs8", format: "pem"})};
  const verifier = createAppleVerifier(config);
  await assert.rejects(verifier.currentTransaction("not-a-jws"));
  await assert.rejects(verifier.notification("eyJhbGciOiJub25lIn0.e30."));
  assert.throws(() => createAppleVerifier({...config, environment: "Xcode"}));
  assert.throws(() => createAppleVerifier({...config, environment: "Production"}));
});
