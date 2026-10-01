/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {readWallet, commitWallet, dailyPlayChange, dayKey, check, validID, validUID} = require("./wallet-ledger");
const {validateMatch, resolveMatch, rankDelta, matchCoins, onlineBest, tier, isForfeit} = require("./match-reward-policy");

// The source must be produced by a trusted match lifecycle/proof verifier, never
// copied from sessions/{id} or RTDB. No client API creates this private record.
const matchPath = (id) => `economyPrivate/verifiedMatches/records/${id}`;
function counterUsed(counter, today, maximum) {
  check(counter && typeof counter.dayKey === "string" && Number.isSafeInteger(counter.count) &&
    counter.count >= 0 && counter.count <= maximum, "Invalid reward counter");
  return counter.dayKey === today ? counter.count : 0;
}

function createMatchRewards({db, clock = Date.now}) {
  async function settle(uid, data) {
    check(validUID(uid) && validID(data.sessionID) && data.sessionID.length <= 100, "Invalid match identity");
    const id = data.sessionID;
    return db.runTransaction(async (tx) => {
      const own = await readWallet(db, tx, uid, `match_${id}`);
      if (own.existing) return {...own.existing, didApplyRewards: false};
      const control = (await tx.get(db.doc("economyPrivate/control"))).data();
      check(control?.walletMigrationReady === true && control?.matchRewardsEnabled === true, "Match rewards are paused");
      const matchRef = db.doc(matchPath(id));
      const m = (await tx.get(matchRef)).data();
      const now = clock();
      validateMatch(m, id, now);
      check(m.players.some((p) => p.userID === uid && !p.isBot), "Not a match participant");
      check(!m.settledAtMs, "Inconsistent match settlement");
      const winnerID = resolveMatch(m);
      const today = dayKey(now);
      const humans = m.players.filter((p) => !p.isBot);
      const contexts = [];
      // All player wallets/receipts are read before either is mutated. A retry
      // cannot credit just the winner or pay the loser a second time.
      for (const p of humans) {
        const context = p.userID === uid ? own : await readWallet(db, tx, p.userID, `match_${id}`);
        check(!context.existing, "Inconsistent match settlement");
        const {wallet, user} = context;
        check(wallet.matchEconomyVersion === 1 && Number.isSafeInteger(wallet.migratedAtMs) && m.startedAtMs >= wallet.migratedAtMs,
            "Match predates wallet migration");
        check(user.appliedRankedOutcomes?.[id] !== true && user.appliedCasualOutcomes?.[id] !== true,
            "Legacy match already settled");
        contexts.push({p, context});
      }

      const changes = contexts.map(({p, context}) => {
        const {wallet, user} = context;
        const botUsed = counterUsed(wallet.rewardedBotWins, today, 3);
        const casualUsed = counterUsed(wallet.casualRewards, today, 90);
        const hasBot = m.players.some((player) => player.isBot);
        const botWin = hasBot && winnerID === p.userID;
        const botAvailable = botUsed < 3;
        const requested = matchCoins(m, p.userID, winnerID, botAvailable);
        const matchReward = m.matchKind === "casual" ? Math.min(requested, 90 - casualUsed) : requested;
        const played = m.playedUserIDs.includes(p.userID) && !m.forfeitedIDs.includes(p.userID) && !isForfeit(m.playerResults[p.userID]);
        const play = played ? dailyPlayChange(wallet, user, now) : {dailyCoins: 0, walletUpdates: {}, userUpdates: {}};
        const walletUpdates = {...play.walletUpdates};
        const userUpdates = {...play.userUpdates};
        if (m.matchKind === "casual") {
          walletUpdates.casualRewards = {dayKey: today, count: casualUsed + matchReward};
          userUpdates.coinWallet = {...user.coinWallet, casualRewards: walletUpdates.casualRewards};
        }
        if (botWin && botAvailable && matchReward > 0) {
          walletUpdates.rewardedBotWins = {dayKey: today, count: botUsed + 1};
          userUpdates.botMatchProgress = {...user.botMatchProgress, rewardedBotWins: walletUpdates.rewardedBotWins};
        }
        check(wallet.matchRanks && typeof wallet.matchRanks === "object", "Rank migration required");
        const oldRank = wallet.matchRanks[m.mode] ?? {points: 0, tier: 0, wins: 0, losses: 0};
        check([oldRank.points, oldRank.wins, oldRank.losses].every((n) => Number.isSafeInteger(n) && n >= 0), "Invalid rank state");
        const delta = m.matchKind === "ranked" && !(botWin && !botAvailable) ? rankDelta(m, p.userID, winnerID) : 0;
        const newRank = {points: Math.max(0, oldRank.points + delta), wins: oldRank.wins, losses: oldRank.losses};
        newRank.tier = tier(newRank.points);
        if (m.matchKind === "ranked" && !(botWin && !botAvailable) && winnerID !== null) {
          newRank[winnerID === p.userID ? "wins" : "losses"] += 1;
        }
        check([newRank.points, newRank.wins, newRank.losses].every(Number.isSafeInteger), "Rank overflow");
        const best = onlineBest(oldRank.onlineBest, m.playerResults[p.userID], m.mode);
        if (best) newRank.onlineBest = best;
        walletUpdates.matchRanks = {...wallet.matchRanks, [m.mode]: newRank};
        // Preserve solo difficulty records, but never use public rank fields as
        // monetary authority. Match rank state is owned by the wallet server.
        userUpdates.ranks = {...user.ranks, [m.mode]: {...user.ranks?.[m.mode], ...newRank}};
        const appliedKey = m.matchKind === "ranked" ? "appliedRankedOutcomes" : "appliedCasualOutcomes";
        userUpdates[appliedKey] = {...user[appliedKey], [id]: true};
        return {p, context, walletUpdates, userUpdates, newRank, receipt: {
          sessionID: id, mode: m.mode, matchKind: m.matchKind, winnerID, matchReward,
          dailyCoins: play.dailyCoins, rankDelta: newRank.points - oldRank.points,
          outcome: winnerID === null ? "draw" : winnerID === p.userID ? "win" : "loss",
          reason: m.forfeitedIDs.includes(p.userID) || isForfeit(m.playerResults[p.userID]) ? "forfeit" :
            botWin && !botAvailable ? "botLimit" : requested > matchReward ? "casualLimit" : "settled",
        }};
      });

      let reply;
      for (const change of changes) {
        const receipt = commitWallet(tx, change.context, {
          kind: "match", now, delta: change.receipt.matchReward + change.receipt.dailyCoins,
          walletUpdates: change.walletUpdates, userUpdates: change.userUpdates, receipt: change.receipt,
        });
        if (m.matchKind === "ranked") {
          const user = change.context.user;
          const cosmetics = user.cosmetics || {};
          tx.set(db.doc(`leaderboards/${m.mode}/entries/${change.p.userID}`), {
            id: change.p.userID, username: user.username || "Player", rankTier: change.newRank.tier,
            rankPoints: change.newRank.points, wins: change.newRank.wins, mode: m.mode,
            ...(user.avatarURL ? {avatarURL: user.avatarURL} : {}),
            ...(change.newRank.onlineBest?.time !== undefined ? {bestTime: change.newRank.onlineBest.time} : {}),
            avatarStyle: {head: cosmetics.equippedAvatarHead || "avatar_head_none",
              face: cosmetics.equippedAvatarFace || "avatar_face_smile", outfit: cosmetics.equippedAvatarOutfit || "avatar_outfit_basic",
              aura: cosmetics.equippedAvatarAura || "avatar_aura_none", pose: cosmetics.equippedAvatarPose || "avatar_pose_jump",
              bodyHex: cosmetics.customAvatarBodyHex || "FF2F78"},
          }, {merge: true});
        }
        if (change.p.userID === uid) reply = {...receipt, didApplyRewards: true};
      }
      tx.update(matchRef, {settledAtMs: now, resolvedWinnerID: winnerID});
      return reply;
    });
  }
  return {settle};
}

module.exports = {createMatchRewards, matchPath};
