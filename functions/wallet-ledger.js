/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {createHash} = require("node:crypto");
const dayKey = (ms) => new Date(ms).toISOString().slice(0, 10);
function check(condition, message) {
  if (!condition) throw new Error(message);
}
function validID(id) {
  return typeof id === "string" && /^[A-Za-z0-9_-]{1,160}$/.test(id);
}
function validUID(uid) {
  return typeof uid === "string" && uid.length > 0 && uid.length <= 128 && !uid.includes("/");
}

// Server-internal primitive: never expose arbitrary deltas as a callable API.
// Callers finish all transaction reads before invoking commitWallet.
async function readWallet(db, tx, uid, receiptID) {
  check(validUID(uid) && validID(receiptID), "Invalid wallet identity");
  const walletRef = db.doc(`coinWallets/${uid}`);
  const userRef = db.doc(`users/${uid}`);
  const receiptRef = db.doc(`coinWallets/${uid}/receipts/${receiptID}`);
  const existing = (await tx.get(receiptRef)).data();
  if (existing) return {existing};
  const wallet = (await tx.get(walletRef)).data();
  const user = (await tx.get(userRef)).data();
  check(wallet?.version === 1 && Number.isSafeInteger(wallet.balance) && wallet.balance >= 0 && user && !user.deletedAt,
      "Wallet migration required");
  return {walletRef, userRef, receiptRef, wallet, user};
}

function commitWallet(tx, context, {kind, delta, now, receipt = {}, walletUpdates = {}, userUpdates = {}}) {
  check(!context.existing && Number.isSafeInteger(delta) && Number.isSafeInteger(now), "Invalid wallet change");
  const grossDelta = delta;
  const debt = walletUpdates.purchaseRefundDebt ?? context.wallet.purchaseRefundDebt ?? 0;
  check(Number.isSafeInteger(debt) && debt >= 0, "Invalid refund debt");
  const refundDebtRecovered = Math.min(Math.max(0, delta), debt);
  if (refundDebtRecovered > 0) {
    delta -= refundDebtRecovered;
    walletUpdates = {...walletUpdates, purchaseRefundDebt: debt - refundDebtRecovered};
  }
  const balance = context.wallet.balance + delta;
  check(Number.isSafeInteger(balance) && balance >= 0, "Insufficient coins");
  const revision = (context.wallet.revision ?? 0) + 1;
  check(Number.isSafeInteger(revision) && revision > 0, "Invalid wallet revision");
  const result = {...receipt, kind, delta, grossDelta, refundDebtRecovered, balanceBefore: context.wallet.balance, balance, revision, settledAtMs: now};
  tx.update(context.walletRef, {...walletUpdates, balance, revision});
  tx.update(context.userRef, {...userUpdates, coins: balance});
  tx.create(context.receiptRef, result);
  return result;
}

function dailyPlayChange(wallet, user, now) {
  const today = dayKey(now);
  const yesterday = dayKey(now - 86400000);
  const old = user.playProgress || {};
  const count = (value) => Number.isSafeInteger(value) && value >= 0 ? value : 0;
  const streak = old.lastPlayedDay === today ? Math.max(1, count(old.currentStreak)) :
    old.lastPlayedDay === yesterday ? count(old.currentStreak) + 1 : 1;
  return {
    dailyCoins: wallet.dailyPlayDay === today ? 0 : 25,
    walletUpdates: {dailyPlayDay: today},
    userUpdates: {playProgress: {...old, lastPlayedDay: today, lastRewardDay: today,
      currentStreak: streak, longestStreak: Math.max(count(old.longestStreak), streak),
      totalGamesPlayed: count(old.totalGamesPlayed ?? old.totalSoloResults) + 1}},
  };
}

// Stable hashes let an operator approve a specific legacy snapshot, not whatever
// balance a client happens to send during migration.
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((k) => [k, canonical(value[k])]));
  return value;
}
function migrationSnapshot(user) {
  const keys = ["coins", "cosmetics", "coinWallet", "playProgress", "appliedRankedOutcomes", "appliedCasualOutcomes",
    "botMatchProgress", "dailyChallengeBonusDays", "rankedAccess", "earnedShowcase", "ranks", "soloCompletions"];
  return Object.fromEntries(keys.filter((k) => user[k] !== undefined).map((k) => [k, user[k]]));
}
function snapshotHash(user) {
  return createHash("sha256").update(JSON.stringify(canonical(migrationSnapshot(user)))).digest("hex");
}

module.exports = {readWallet, commitWallet, dailyPlayChange, dayKey, check, validID, validUID, snapshotHash, migrationSnapshot};
