/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {randomUUID} = require("node:crypto");
const {check, validUID} = require("../wallet-ledger");

// Operator-only, never exported as a Cloud Function. Fresh test users only;
// this is NOT the reviewed legacy-wallet migration and cannot target production.
async function provisionPurchaseSandbox({db, auth, uid, clock = Date.now}) {
  check(db.projectId === "puzzlepartytest", "Only puzzlepartytest is allowed");
  check(validUID(uid), "Invalid test UID");
  const account = await auth.getUser(uid);
  check(!account.disabled && account.email && account.providerData.some((p) => p.providerId === "password"),
      "Create an email/password test account first");
  const now = clock();
  const token = randomUUID();
  return db.runTransaction(async (tx) => {
    const userRef = db.doc(`users/${uid}`);
    const walletRef = db.doc(`coinWallets/${uid}`);
    const user = (await tx.get(userRef)).data();
    const wallet = (await tx.get(walletRef)).data();
    const controlRef = db.doc("economyPrivate/control");
    const control = (await tx.get(controlRef)).data();
    if (user || wallet) {
      check(user?.purchaseSandbox === true && wallet?.purchaseSandbox === true && wallet.version === 1,
          "Refusing to overwrite an existing or partial account");
      return {created: false, uid, balance: wallet.balance};
    }
    check(!control || control.purchaseSandbox === true, "Unreviewed test control document");
    const rankedAccess = {allModesUnlocked: false, unlockedModeIDs: []};
    tx.create(userRef, {id: uid, username: "Purchase Tester", email: account.email,
      coins: 500, createdAt: new Date(now), ranks: {}, cosmetics: {purchasedIDs: []},
      rankedAccess, serverWalletVersion: 1, purchaseSandbox: true});
    tx.create(walletRef, {version: 1, balance: 500, revision: 0, migratedAtMs: now,
      appAccountToken: token, purchaseRefundDebt: 0, rankedAccess,
      purchaseSandbox: true});
    tx.create(db.doc(`coinWallets/${uid}/receipts/sandbox_bootstrap`), {
      kind: "sandboxBootstrap", delta: 500, balanceBefore: 0, balance: 500, revision: 0, settledAtMs: now,
    });
    // No solo, match, ad, shop, migration, or other reward gates are enabled.
    tx.set(controlRef, {purchaseSandbox: true, walletMigrationReady: true,
      purchasesEnabled: true, purchaseNotificationsEnabled: true});
    return {created: true, uid, balance: 500};
  });
}
module.exports = {provisionPurchaseSandbox};
