/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {randomUUID} = require("node:crypto");
const {check, validUID, snapshotHash, migrationSnapshot} = require("./wallet-ledger");

function migratedMatchRanks(ranks = {}) {
  return Object.fromEntries(Object.entries(ranks).map(([mode, rank]) => {
    check([rank.points, rank.wins, rank.losses].every((n) => Number.isSafeInteger(n) && n >= 0), "Invalid source rank");
    return [mode, {points: rank.points, wins: rank.wins, losses: rank.losses,
      ...(rank.onlineBest ? {onlineBest: rank.onlineBest} : {})}];
  }));
}

// Admin-only library, deliberately NOT registered as a public callable.
// Approval must be written by a trusted operator after reviewing legacy data.
async function migrateWallet({db, uid, clock = Date.now}) {
  check(validUID(uid), "Invalid account");
  const token = randomUUID();
  return db.runTransaction(async (tx) => {
    const walletRef = db.doc(`coinWallets/${uid}`);
    const existing = (await tx.get(walletRef)).data();
    if (existing) {
      check(existing.version === 1, "Unsupported wallet version"); return existing;
    }
    const control = (await tx.get(db.doc("economyPrivate/control"))).data();
    check(control?.walletMigrationReady === true && control?.migrationsEnabled === true, "Migration is disabled");
    const approval = (await tx.get(db.doc(`economyPrivate/migrations/users/${uid}`))).data();
    const userRef = db.doc(`users/${uid}`);
    const user = (await tx.get(userRef)).data();
    check(user && !user.deletedAt && Number.isSafeInteger(user.coins) && user.coins >= 0, "Invalid source balance");
    check(approval?.version === 1 && approval.approved === true && typeof approval.approvedBy === "string" &&
      approval.approvedBy.length > 0 && approval.expectedHash === snapshotHash(user), "Reviewed snapshot approval required");
    check(Array.isArray(user.cosmetics?.purchasedIDs) && user.cosmetics.purchasedIDs.every((id) => typeof id === "string"), "Invalid inventory");
    const now = clock();
    const wallet = {version: 1, balance: user.coins, revision: 0, migratedAtMs: now,
      dailyPlayDay: user.playProgress?.lastRewardDay ?? "",
      dailyClaimDay: user.coinWallet?.claimedDailyCoinDay ?? "", appAccountToken: token,
      matchEconomyVersion: 1, matchRanks: migratedMatchRanks(user.ranks),
      rankedAccess: user.rankedAccess ?? {},
      casualRewards: user.coinWallet?.casualRewards ?? {dayKey: "", count: 0},
      rewardedBotWins: user.botMatchProgress?.rewardedBotWins ?? {dayKey: "", count: 0}};
    tx.create(walletRef, wallet);
    tx.create(db.doc(`coinWallets/${uid}/receipts/migration_v1`), {
      kind: "migration", delta: 0, balanceBefore: user.coins, balance: user.coins, revision: 0,
      settledAtMs: now, sourceHash: approval.expectedHash, approvedBy: approval.approvedBy,
    });
    tx.create(db.doc(`economyPrivate/migrationSnapshots/users/${uid}`), migrationSnapshot(user));
    tx.update(userRef, {serverWalletVersion: 1});
    return wallet;
  });
}
module.exports = {migrateWallet};
