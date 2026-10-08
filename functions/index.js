/* eslint require-jsdoc: "off" */

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} =
  require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString, defineInt} =
  require("firebase-functions/params");
const appleKey = defineSecret("APPLE_IAP_SIGNING_KEY");
const appleKeyID = defineString("APPLE_IAP_KEY_ID", {default: ""});
const appleIssuerID = defineString("APPLE_IAP_ISSUER_ID", {default: ""});
const appleEnvironment = defineString("APPLE_IAP_ENVIRONMENT",
    {default: "Production"});
const appleAppID = defineInt("APPLE_APP_ID", {default: 0});
const appleMaxInstances = defineInt("APPLE_IAP_MAX_INSTANCES", {default: 5});
let applePurchases;
function getApplePurchases() {
  if (!applePurchases) {
    const environment = appleEnvironment.value();
    const apple = require("./apple-verifier").createAppleVerifier({
      environment, appAppleId: appleAppID.value(), keyID: appleKeyID.value(),
      issuerID: appleIssuerID.value(), signingKey: appleKey.value(),
    });
    applePurchases = require("./apple-purchases").createApplePurchases({
      db, apple, environment,
    });
  }
  return applePurchases;
}
const purchaseOptions = {
  secrets: [appleKey], minInstances: 0,
  maxInstances: appleMaxInstances, timeoutSeconds: 30,
};
for (const [name, method] of Object.entries({
  prepareWalletPurchase: "prepare", claimWalletPurchase: "claim",
})) {
  exports[name] = onCall(purchaseOptions, async (request) => {
    if (!request.auth ||
        request.auth.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to deliver purchases.");
    }
    try {
      return await getApplePurchases()[method](request.auth.uid,
          request.data || {});
    } catch (error) {
      // Never log signed transactions, account tokens or signing credentials.
      console.warn("Apple purchase delivery deferred", {reason: error.message});
      throw new HttpsError("failed-precondition",
          "Purchase delivery could not be verified. Keep your purchase " +
          "on this account and retry. Older purchases may need support.");
    }
  });
}
exports.applePurchaseNotifications = onRequest(purchaseOptions,
    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).end(); return;
      }
      try {
        await getApplePurchases().notify(request.body?.signedPayload);
        response.status(200).json({accepted: true});
      } catch (error) {
        console.warn("Apple notification deferred", {reason: error.message});
        // Apple retries failures, including a pause or missing binding.
        response.status(503).json({accepted: false});
      }
    });
const soloRewards = require("./solo-rewards").createSoloRewards({db});
const dailyChallenges = require("./daily-challenges").createDailyChallenges({
  db, timestamp: (ms) => Timestamp.fromMillis(ms),
});
const walletShop = require("./wallet-shop").createWalletShop({db});
const matchRewards = require("./match-rewards").createMatchRewards({db});
const matchLifecycle = require("./match-lifecycle").createMatchLifecycle({
  db, timestamp: (ms) => Timestamp.fromMillis(ms),
});
const socialLifecycle = require("./social-lifecycle").createSocialLifecycle({
  db, timestamp: (ms) => Timestamp.fromMillis(ms),
});
const socialMaxInstances = defineInt("SOCIAL_MAX_INSTANCES", {default: 5});
for (const method of ["create", "join", "accept", "decline", "ready", "start",
  "advance", "forfeit", "submit", "tick"]) {
  exports[`socialGame_${method}`] = onCall({
    minInstances: 0, maxInstances: socialMaxInstances, timeoutSeconds: 30,
  }, async (request) => {
    if (!request.auth ||
        request.auth.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated",
          "Sign in to play with friends.");
    }
    try {
      return await socialLifecycle[method](request.auth.uid,
          request.data || {});
    } catch (error) {
      console.warn("Social game deferred", {method,
        uid: request.auth.uid, reason: error.message});
      throw new HttpsError("failed-precondition", error.message);
    }
  });
}

const matchMethods = [
  "queue", "cancel", "wordGuessTestTarget", "ready", "progress", "submit",
  "forfeit",
  "tick",
];
for (const method of matchMethods) {
  exports[`officialMatch_${method}`] = onCall({
    maxInstances: 5, timeoutSeconds: 30,
  }, async (request) => {
    if (!request.auth ||
        request.auth.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to play online.");
    }
    try {
      const reply = await matchLifecycle[method](
          request.auth.uid, request.data || {});
      if (reply.status === "finished") {
        // The immutable verification record already exists. A failed payment
        // stays retryable via its trigger or the result-screen refresh.
        await matchRewards.settle(request.auth.uid, {
          sessionID: request.data.sessionID,
        });
      }
      return reply;
    } catch (error) {
      console.warn("Official match operation failed", {method,
        uid: request.auth.uid, reason: error.message});
      const message = error.message === "No ranked entry available" ?
        "No ranked entry is available for this mode today." :
        "Could not confirm this match action. Please retry.";
      throw new HttpsError("failed-precondition", message);
    }
  });
}

const soloCallables = {
  soloRewardStatus: "enabled",
  beginSoloReward: "begin",
  completeSoloReward: "complete",
  abandonSoloReward: "abandon",
};
const soloOptions = {maxInstances: 5, timeoutSeconds: 30};
for (const method of ["today", "begin", "complete", "discard"]) {
  exports[`dailyChallenge_${method}`] = onCall(soloOptions, async (request) => {
    if (!request.auth ||
        request.auth.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to play dailies.");
    }
    try {
      return await dailyChallenges[method](request.auth.uid,
          request.data || {});
    } catch (error) {
      console.warn("Daily challenge deferred", {method,
        uid: request.auth.uid, reason: error.message});
      const messages = {
        "Verified dailies are not enabled for this account":
          "Verified Daily Challenges are not enabled yet. No coins changed.",
        "This daily has ended":
          "This daily has ended. Refresh today's puzzles.",
        "Daily already submitted or expired":
          "Daily already submitted or expired. Refresh your results.",
        "Find a word to submit this daily":
          "Find at least one word for a timed daily to count.",
      };
      throw new HttpsError("failed-precondition", messages[error.message] ||
        "Could not verify this daily result. Your submission can be retried.");
    }
  });
}
exports.settleWalletMatch = onCall(soloOptions, async (request) => {
  if (!request.auth ||
      request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated",
        "Sign in to collect match rewards.");
  }
  try {
    // Never accept outcome, rank, reward or bot flags from the caller.
    return await matchRewards.settle(request.auth.uid, {
      sessionID: request.data?.sessionID,
    });
  } catch (error) {
    console.warn("Match settlement deferred", {
      uid: request.auth.uid, message: error.message,
    });
    throw new HttpsError("failed-precondition",
        "Match rewards are awaiting verification. Please retry shortly.");
  }
});

// A trusted verifier will create these records after checking the match. This
// is deliberately NOT a trigger on the client-writable public sessions path.
exports.settleVerifiedWalletMatch = onDocumentCreated({
  document: "economyPrivate/verifiedMatches/records/{sessionID}",
  retry: true, maxInstances: 5, timeoutSeconds: 30,
}, async (event) => {
  const control = (await db.doc("economyPrivate/control").get()).data();
  if (!control?.walletMigrationReady || !control?.matchRewardsEnabled) return;
  const participant = event.data?.data()?.players?.find((p) => !p.isBot);
  if (!participant) return;
  await matchRewards.settle(participant.userID, {
    sessionID: event.params.sessionID,
  });
});

for (const [name, method] of Object.entries(soloCallables)) {
  exports[name] = onCall(soloOptions, async (request) => {
    const provider = request.auth?.token.firebase?.sign_in_provider;
    if (!request.auth || provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to earn solo rewards.");
    }
    try {
      const result = await soloRewards[method](
          request.auth.uid, request.data || {});
      return method === "enabled" ? {enabled: result} : result;
    } catch (error) {
      console.warn("Solo reward rejected", {
        method, uid: request.auth.uid, message: error.message,
      });
      throw new HttpsError("failed-precondition",
          "Could not verify this solo reward. Retry or return to Solo.");
    }
  });
}

for (const [name, method] of Object.entries({
  claimWalletDaily: "claimDaily",
  purchaseWalletCosmetic: "purchaseCosmetic",
  equipWalletCosmetics: "equip",
})) {
  exports[name] = onCall(soloOptions, async (request) => {
    if (!request.auth ||
        request.auth.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to use your wallet.");
    }
    try {
      return await walletShop[method](request.auth.uid, request.data || {});
    } catch (error) {
      console.warn("Wallet operation rejected", {
        method, uid: request.auth.uid,
      });
      const messages = {
        "Insufficient coins": "You do not have enough coins for that.",
        "Shop price changed": "The price has changed. Refresh the shop first.",
        "This item is not in today's shop":
          "The shop has rotated. Refresh to see today's items.",
      };
      throw new HttpsError("failed-precondition",
          messages[error.message] || "Could not complete this operation.");
    }
  });
}

function eventData(event) {
  if (!event.data) return null;
  return event.data.data();
}

async function getUserPushData(userID) {
  if (!userID) {
    return {
      tokens: [],
      notificationSettings: {},
    };
  }

  const snap = await db.collection("users").doc(userID).get();
  const data = snap.data() || {};
  const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];

  return {
    tokens: tokens.filter((token) => {
      return typeof token === "string" && token.length > 0;
    }),
    notificationSettings: data.notificationSettings || {},
  };
}

function notificationEnabled(settings, key) {
  if (!key) return true;
  if (!settings || !Object.prototype.hasOwnProperty.call(settings, key)) {
    return true;
  }
  return settings[key] !== false;
}

function shouldRemovePushToken(errorCode) {
  return [
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
    "messaging/third-party-auth-error",
  ].includes(errorCode);
}

async function removeUserTokens(userID, tokensToRemove) {
  const uniqueTokens = Array.from(new Set(tokensToRemove.filter(Boolean)));
  if (!uniqueTokens.length) return;

  try {
    await db.collection("users").doc(userID).update({
      fcmTokens: FieldValue.arrayRemove(...uniqueTokens),
    });
    console.log("Removed stale FCM tokens", {
      userID: userID,
      removedCount: uniqueTokens.length,
    });
  } catch (error) {
    console.error("Failed to remove stale FCM tokens", {
      userID: userID,
      removedCount: uniqueTokens.length,
      code: error && error.code,
      message: error && error.message,
    });
  }
}

async function sendToUser(userID, payload) {
  const pushData = await getUserPushData(userID);
  const canSend = notificationEnabled(
      pushData.notificationSettings,
      payload.preferenceKey,
  );
  if (!canSend) {
    console.log("Push skipped by user preference", {
      userID: userID,
      preferenceKey: payload.preferenceKey,
      type: payload.data && payload.data.type,
    });
    return;
  }

  const tokens = pushData.tokens;
  if (!tokens.length) {
    console.log("No FCM tokens for user", userID, payload.data || {});
    return;
  }

  console.log("Sending push", {
    userID: userID,
    tokenCount: tokens.length,
    type: payload.data && payload.data.type,
  });

  const response = await getMessaging().sendEachForMulticast({
    tokens: tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data || {},
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  console.log("Push send result", {
    userID: userID,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });

  const tokensToRemove = [];
  response.responses.forEach((result, index) => {
    if (!result.success) {
      console.error("Push token failed", {
        userID: userID,
        tokenIndex: index,
        code: result.error && result.error.code,
        message: result.error && result.error.message,
      });
      const code = result.error && result.error.code;
      if (shouldRemovePushToken(code)) {
        tokensToRemove.push(tokens[index]);
      }
    }
  });
  await removeUserTokens(userID, tokensToRemove);
}

exports.notifyFriendRequestCreated = onDocumentWritten(
    "friendRequests/{requestID}",
    async (event) => {
      if (!event.data) return;

      const before = event.data.before.data() || null;
      const request = event.data.after.data() || null;
      if (!request || request.status !== "pending") return;
      if (before && before.status === "pending") return;

      await sendToUser(request.toID, {
        title: "New friend request",
        body: (request.fromUsername || "Someone") +
          " sent you a friend request",
        data: {
          type: "friend_request",
          requestID: event.params.requestID,
        },
        preferenceKey: "friendRequests",
      });
    },
);

exports.notifyExhibitionInviteCreated = onDocumentCreated(
    "exhibitionInvites/{inviteID}",
    async (event) => {
      const invite = eventData(event);
      if (!invite) return;

      console.log("Exhibition invite notification trigger", {
        inviteID: event.params.inviteID,
        fromID: invite.fromID,
        toID: invite.toID,
        inviteType: invite.inviteType || "playNow",
        mode: invite.mode,
      });

      const inviteType = invite.inviteType === "playLater" ?
        "Play Later challenge" :
        "Exhibition invite";

      await sendToUser(invite.toID, {
        title: inviteType,
        body: (invite.fromUsername || "Someone") +
          " invited you to play " +
          (invite.mode || "a game"),
        data: {
          type: "exhibition_invite",
          inviteID: event.params.inviteID,
        },
        preferenceKey: invite.inviteType === "playLater" ?
          "playLaterInvites" :
          "playNowInvites",
      });
    },
);


exports.notifyPartyInviteCreated = onDocumentCreated(
    "partyInvites/{inviteID}",
    async (event) => {
      const invite = eventData(event);
      if (!invite) return;

      console.log("Party invite notification trigger", {
        inviteID: event.params.inviteID,
        fromID: invite.fromID,
        toID: invite.toID,
        roomCode: invite.roomCode,
      });

      await sendToUser(invite.toID, {
        title: "Party invite",
        body: (invite.fromUsername || "Someone") +
          " invited you to room " + (invite.roomCode || ""),
        data: {
          type: "party_invite",
          inviteID: event.params.inviteID,
          roomCode: invite.roomCode || "",
        },
        preferenceKey: "partyInvites",
      });
    },
);

exports.notifyRematchRequested = onDocumentUpdated(
    "sessions/{sessionID}",
    async (event) => {
      if (!event.data) return;

      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;

      const beforeRequests = before.rematchRequests || {};
      const afterRequests = after.rematchRequests || {};

      const requesterIDs = Object.keys(afterRequests).filter((userID) => {
        return afterRequests[userID] === true &&
          beforeRequests[userID] !== true;
      });

      if (!requesterIDs.length) return;

      const newRequesterID = requesterIDs[0];
      const playerIDs = Array.isArray(after.playerIDs) ? after.playerIDs : [];
      const opponentID = playerIDs.find((id) => {
        return id !== newRequesterID;
      });

      if (!opponentID) return;

      const requesterName =
        (after.playerUsernames && after.playerUsernames[newRequesterID]) ||
        (after.playerNames && after.playerNames[newRequesterID]) ||
        "Your opponent";

      await sendToUser(opponentID, {
        title: "Rematch requested",
        body: requesterName + " wants a rematch",
        data: {
          type: "rematch_request",
          sessionID: event.params.sessionID,
        },
        preferenceKey: "rematches",
      });
    },
);
