/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {createHash} = require("node:crypto");
const {check, validUID, readWallet, commitWallet} = require("./wallet-ledger");
const products = {
  "com.gridduel.coins.small": {coins: 1000}, "com.gridduel.coins.medium": {coins: 3300},
  "com.gridduel.coins.large": {coins: 6000}, "com.gridduel.coins.mega": {coins: 13500},
  "com.gridduel.ranked.all": {mode: "all"}, "com.gridduel.ranked.colorlink": {mode: "colorLink"},
  "com.gridduel.ranked.gridduel": {mode: "gridlock"}, "com.gridduel.ranked.sudoku": {mode: "sudoku"},
  "com.gridduel.ranked.minesweeper": {mode: "minesweeper"}, "com.gridduel.ranked.wordle": {mode: "wordle"},
  "com.gridduel.ranked.hangman": {mode: "hangman"}, "com.gridduel.ranked.wordhunt": {mode: "wordHunt"},
  "com.gridduel.ranked.anagrams": {mode: "anagram"},
};
const tokenOK = (s) => typeof s === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
const hash = (s) => createHash("sha256").update(s).digest("hex");
const bindingPath = (token) => `economyPrivate/appleAccounts/tokens/${token.toLowerCase()}`;
const purchasePath = (environment, id) => `economyPrivate/appleTransactions/records/${environment}_${id}`;

function validateTransaction(t, environment, now) {
  const p = products[t.productId];
  check(p && t.environment === environment && t.bundleId === "com.rkdp.app", "Wrong app, product or environment");
  check(typeof t.transactionId === "string" && /^\d{1,40}$/.test(t.transactionId) &&
    typeof t.originalTransactionId === "string" && /^\d{1,40}$/.test(t.originalTransactionId), "Invalid transaction identity");
  check(t.type === (p.coins ? "Consumable" : "Non-Consumable") && t.quantity === 1 &&
    t.inAppOwnershipType === "PURCHASED", "Unsupported purchase type");
  check(tokenOK(t.appAccountToken), "Purchase needs reviewed account binding");
  check(Number.isSafeInteger(t.purchaseDate) && t.purchaseDate > 0 && t.purchaseDate <= now + 60000 &&
    Number.isSafeInteger(t.signedDate) && t.signedDate >= t.purchaseDate && t.signedDate <= now + 60000, "Invalid purchase dates");
  check(t.revocationDate === undefined || (Number.isSafeInteger(t.revocationDate) && t.revocationDate > 0), "Invalid revocation");
  return p;
}

// `apple` must verify JWS certificates and fetch current state from Apple's API.
// The test double substitutes this external boundary, never a production caller.
function createApplePurchases({db, apple, environment, clock = Date.now}) {
  check(["Production", "Sandbox"].includes(environment), "Invalid Apple environment");
  async function gate(tx, notifications = false) {
    const flags = (await tx.get(db.doc("economyPrivate/control"))).data();
    check(flags?.walletMigrationReady === true &&
      flags[notifications ? "purchaseNotificationsEnabled" : "purchasesEnabled"] === true, "Purchases are not enabled");
  }
  async function prepare(uid) {
    check(validUID(uid), "Invalid account");
    return db.runTransaction(async (tx) => {
      await gate(tx);
      const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
      const user = (await tx.get(db.doc(`users/${uid}`))).data();
      check(wallet?.version === 1 && tokenOK(wallet.appAccountToken) && user && !user.deletedAt, "Wallet migration required");
      const ref = db.doc(bindingPath(wallet.appAccountToken));
      const bound = (await tx.get(ref)).data();
      check(!bound || bound.uid === uid, "Account token collision");
      if (!bound) tx.create(ref, {uid});
      return {appAccountToken: wallet.appAccountToken.toLowerCase(), environment, refundDebt: wallet.purchaseRefundDebt ?? 0};
    });
  }
  async function apply(uid, t, notifications = false) {
    const now = clock(); const product = validateTransaction(t, environment, now);
    const id = product.coins ? t.transactionId : t.originalTransactionId;
    const ref = db.doc(purchasePath(environment, id));
    return db.runTransaction(async (tx) => {
      await gate(tx, notifications);
      const old = (await tx.get(ref)).data();
      const binding = (await tx.get(db.doc(bindingPath(t.appAccountToken)))).data();
      const owner = uid ?? binding?.uid;
      check(validUID(owner) && binding?.uid === owner && (!old || old.uid === owner), "Purchase belongs to another account");
      const wallet = (await tx.get(db.doc(`coinWallets/${owner}`))).data();
      check(wallet?.appAccountToken?.toLowerCase() === t.appAccountToken.toLowerCase(), "Wrong account token");
      check(!old || old.productID === t.productId, "Purchase product changed");
      const revoked = t.revocationDate !== undefined;
      if (old && (t.signedDate < old.signedDate || (t.signedDate === old.signedDate && old.revoked && !revoked))) {
        return {accepted: true, balance: wallet.balance, revoked: old.revoked};
      }
      if (old?.revoked === revoked) {
        tx.update(ref, {signedDate: t.signedDate});
        return {accepted: true, balance: wallet.balance, revoked};
      }
      const revision = (old?.revision ?? 0) + 1;
      const receiptID = `apple_${hash(`${environment}_${id}`)}_${revision}`;
      const context = await readWallet(db, tx, owner, receiptID);
      check(!context.existing, "Inconsistent purchase receipt");
      // Unreviewed pre-migration purchases might already be in the opening balance.
      check(old || t.purchaseDate >= context.wallet.migratedAtMs, "Legacy purchase requires reviewed migration");
      let delta = 0; const walletUpdates = {}; const userUpdates = {};
      let refundDebt = context.wallet.purchaseRefundDebt ?? 0;
      check(Number.isSafeInteger(refundDebt) && refundDebt >= 0, "Invalid refund debt");
      if (product.coins) {
        if (!revoked) {
          // Reversal first cancels this refund's remaining debt. Previously
          // recovered coins are restored through the shared credit path.
          const cancelDebt = old?.revoked ? Math.min(refundDebt, old.refundShortfall ?? 0) : 0;
          walletUpdates.purchaseRefundDebt = refundDebt - cancelDebt;
          delta = product.coins - cancelDebt;
        } else if (old && !old.revoked) {
          const recovered = Math.min(context.wallet.balance, product.coins);
          delta = -recovered;
          refundDebt += product.coins - recovered;
          walletUpdates.purchaseRefundDebt = refundDebt;
        }
      } else {
        const grants = {...context.wallet.appleRankedGrants, [id]: {mode: product.mode, active: !revoked}};
        const baseline = context.wallet.rankedPurchaseBaseline ?? {
          allModesUnlocked: context.wallet.rankedAccess?.allModesUnlocked === true,
          unlockedModeIDs: context.wallet.rankedAccess?.unlockedModeIDs ?? [],
        };
        const active = Object.values(grants).filter((g) => g.active);
        const access = {...context.wallet.rankedAccess,
          allModesUnlocked: baseline.allModesUnlocked || active.some((g) => g.mode === "all"),
          unlockedModeIDs: [...new Set([...baseline.unlockedModeIDs, ...active.filter((g) => g.mode !== "all").map((g) => g.mode)])]};
        Object.assign(walletUpdates, {appleRankedGrants: grants, rankedPurchaseBaseline: baseline, rankedAccess: access});
        userUpdates.rankedAccess = access;
      }
      const receipt = commitWallet(tx, context, {kind: revoked ? "appleRefund" : "applePurchase", delta, now,
        walletUpdates, userUpdates, receipt: {productID: t.productId, transactionID: t.transactionId, environment, revoked}});
      tx.set(ref, {uid: owner, productID: t.productId, transactionID: t.transactionId, originalTransactionID: t.originalTransactionId,
        signedDate: t.signedDate, revoked, revision, environment,
        refundShortfall: revoked && old && product.coins ? Math.max(0, product.coins + delta) : 0});
      return {accepted: true, balance: receipt.balance, revoked};
    });
  }
  async function claim(uid, data) {
    check(validUID(uid) && typeof data.signedTransaction === "string" && data.signedTransaction.length <= 30000, "Invalid signed purchase");
    // Reject disabled/unmigrated requests before spending an Apple API call.
    await prepare(uid);
    return apply(uid, await apple.currentTransaction(data.signedTransaction));
  }
  async function notify(signedPayload) {
    check(typeof signedPayload === "string" && signedPayload.length <= 100000, "Invalid notification");
    const notification = await apple.notification(signedPayload);
    if (notification.notificationType === "TEST") return {accepted: true};
    const signed = notification.data?.signedTransactionInfo;
    if (!signed) return {accepted: true};
    const t = await apple.currentTransaction(signed);
    // Unknown/legacy account bindings must be retried or explicitly reviewed,
    // never acknowledged and silently lost.
    return apply(null, t, true);
  }
  return {prepare, claim, notify};
}
module.exports = {createApplePurchases, validateTransaction, products, purchasePath, bindingPath};
