/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {MemoryDB} = require("./memory-firestore");
const {provisionPurchaseSandbox} = require("./provision-purchase-sandbox");
function setup(projectId = "puzzlepartytest") {
  const db = new MemoryDB(); db.projectId = projectId;
  const auth = {getUser: async () => ({email: "tester@example.invalid", providerData: [{providerId: "password"}]})};
  return {db, auth, uid: "tester", clock: () => 1700000000000};
}
test("fresh sandbox wallet is mirrored and enables purchases only", async () => {
  const s = setup(); const result = await provisionPurchaseSandbox(s);
  assert.equal(result.balance, 500);
  assert.equal(s.db.snapshot("users/tester").data().coins, 500);
  assert.equal(s.db.snapshot("coinWallets/tester").data().rankedAccess.allModesUnlocked, false);
  assert.deepEqual(s.db.snapshot("economyPrivate/control").data(), {
    purchaseSandbox: true, walletMigrationReady: true, purchasesEnabled: true, purchaseNotificationsEnabled: true,
  });
});
test("repeat provisioning never resets spent coins or account token", async () => {
  const s = setup(); await provisionPurchaseSandbox(s);
  const wallet = s.db.snapshot("coinWallets/tester").data();
  s.db.set("coinWallets/tester", {...wallet, balance: 12});
  const result = await provisionPurchaseSandbox(s);
  assert.equal(result.created, false); assert.equal(result.balance, 12);
  assert.equal(s.db.snapshot("coinWallets/tester").data().appAccountToken, wallet.appAccountToken);
});
test("production and arbitrary projects are rejected before account access", async () => {
  for (const project of ["rkpz-90484", "another-project"]) {
    const s = setup(project);
    await assert.rejects(provisionPurchaseSandbox(s), /Only puzzlepartytest/);
    assert.equal(s.db.documents.size, 0);
  }
});
test("legacy accounts, partial setup and unreviewed controls are untouched", async () => {
  for (const [path, data] of [["users/tester", {coins: 100}], ["coinWallets/tester", {version: 1}],
    ["economyPrivate/control", {walletMigrationReady: true}]]) {
    const s = setup(); s.db.set(path, data);
    await assert.rejects(provisionPurchaseSandbox(s));
    assert.equal(s.db.documents.size, 1); assert.deepEqual(s.db.snapshot(path).data(), data);
  }
});
test("disabled, missing and anonymous accounts cannot be provisioned", async () => {
  for (const account of [{disabled: true}, {providerData: []}, {email: "a@example.invalid", providerData: []}]) {
    const s = setup(); s.auth.getUser = async () => account;
    await assert.rejects(provisionPurchaseSandbox(s)); assert.equal(s.db.documents.size, 0);
  }
});
