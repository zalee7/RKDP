const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

function eventData(event) {
  if (!event.data) return null;
  return event.data.data();
}

async function getUserTokens(userID) {
  if (!userID) return [];

  const snap = await db.collection("users").doc(userID).get();
  const data = snap.data() || {};
  const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];

  return tokens.filter(function(token) {
    return typeof token === "string" && token.length > 0;
  });
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
      fcmTokens: FieldValue.arrayRemove.apply(FieldValue, uniqueTokens),
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
  const tokens = await getUserTokens(userID);
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
  response.responses.forEach(function(result, index) {
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
    async function(event) {
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
      });
    },
);

exports.notifyExhibitionInviteCreated = onDocumentCreated("exhibitionInvites/{inviteID}", async function(event) {
  const invite = eventData(event);
  if (!invite) return;

  console.log("Exhibition invite notification trigger", {
    inviteID: event.params.inviteID,
    fromID: invite.fromID,
    toID: invite.toID,
    inviteType: invite.inviteType || "playNow",
    mode: invite.mode,
  });

  const inviteType = invite.inviteType === "playLater"
    ? "Play Later challenge"
    : "Exhibition invite";

  await sendToUser(invite.toID, {
    title: inviteType,
    body: (invite.fromUsername || "Someone") + " invited you to play " + (invite.mode || "a game"),
    data: {
      type: "exhibition_invite",
      inviteID: event.params.inviteID,
    },
  });
});


exports.notifyPartyInviteCreated = onDocumentCreated("partyInvites/{inviteID}", async function(event) {
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
  });
});

exports.notifyRematchRequested = onDocumentUpdated("sessions/{sessionID}", async function(event) {
  if (!event.data) return;

  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const beforeRequests = before.rematchRequests || {};
  const afterRequests = after.rematchRequests || {};

  const requesterIDs = Object.keys(afterRequests).filter(function(userID) {
    return afterRequests[userID] === true && beforeRequests[userID] !== true;
  });

  if (!requesterIDs.length) return;

  const newRequesterID = requesterIDs[0];
  const playerIDs = Array.isArray(after.playerIDs) ? after.playerIDs : [];
  const opponentID = playerIDs.find(function(id) {
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
  });
});