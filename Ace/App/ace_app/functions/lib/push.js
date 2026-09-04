const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

/**
 * Sends a push notification to a list of user ids, pulling their FCM
 * tokens from `users/{id}.fcmTokens` (an array — the same account can be
 * signed in on several devices).
 *
 * `prefKey` optionally gates delivery on one of the toggles in
 * `users/{id}.notifications` (see `kNotificationKeys` in the Flutter app) —
 * pass it when the notification kind has a matching on/off switch in the
 * app's settings screen; omit it to always send (used by notification
 * kinds that don't have a dedicated toggle yet, e.g. event creation).
 *
 * Any token FCM reports as invalid/unregistered (uninstalled app, expired
 * token, ...) is pruned from the owning user's doc so it isn't retried.
 */
async function sendPushToUserIds(userIds, notification, data = {}, options = {}) {
  const { prefKey } = options;
  const uniqueIds = [...new Set(userIds)].filter(Boolean);
  if (uniqueIds.length === 0) return;

  const db = admin.firestore();
  const userDocs = await db.getAll(
    ...uniqueIds.map((id) => db.collection("users").doc(id)),
  );

  const tokens = [];
  const ownerByToken = new Map();

  for (const doc of userDocs) {
    if (!doc.exists) continue;
    if (prefKey) {
      const notifications = doc.get("notifications") || {};
      if (notifications[prefKey] !== true) continue;
    }
    const userTokens = doc.get("fcmTokens");
    if (!Array.isArray(userTokens)) continue;
    for (const token of userTokens) {
      tokens.push(token);
      ownerByToken.set(token, doc.ref);
    }
  }

  if (tokens.length === 0) return;

  const stringData = Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value)]),
  );

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification,
    data: stringData,
  });

  const staleTokensByOwner = new Map();
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error && result.error.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      const token = tokens[index];
      const ownerRef = ownerByToken.get(token);
      if (!staleTokensByOwner.has(ownerRef)) staleTokensByOwner.set(ownerRef, []);
      staleTokensByOwner.get(ownerRef).push(token);
    } else if (!result.success) {
      logger.warn("push send failed", { code, message: result.error && result.error.message });
    }
  });

  await Promise.all(
    [...staleTokensByOwner.entries()].map(([ref, staleTokens]) =>
      ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      }),
    ),
  );
}

module.exports = { sendPushToUserIds };
