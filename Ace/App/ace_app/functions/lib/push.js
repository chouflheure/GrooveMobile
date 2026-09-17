const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { computeBadgeCount } = require("./badge");

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

  const stringData = Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value)]),
  );

  // Sent one recipient at a time (instead of one multicast for every token
  // across every recipient) because the iOS badge count is per-recipient —
  // `apns.payload.aps.badge` needs each person's own unseen count, not a
  // number shared across the whole batch.
  await Promise.all(
    userDocs.map(async (doc) => {
      if (!doc.exists) return;
      if (prefKey) {
        const notifications = doc.get("notifications") || {};
        if (notifications[prefKey] !== true) return;
      }
      const tokens = doc.get("fcmTokens");
      if (!Array.isArray(tokens) || tokens.length === 0) return;

      const badge = await computeBadgeCount(doc.id).catch((error) => {
        logger.warn("badge count failed", { userId: doc.id, message: error.message });
        return undefined;
      });

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification,
        data: stringData,
        // Without these, iOS/Android deliver the notification silently — no
        // sound, no vibration — since "play the default alert" isn't
        // implied, it has to be requested explicitly per platform.
        android: {
          priority: "high",
          notification: { sound: "default", defaultVibrateTimings: true },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              ...(badge === undefined ? {} : { badge }),
            },
          },
        },
      });

      const staleTokens = [];
      response.responses.forEach((result, index) => {
        if (result.success) return;
        const code = result.error && result.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          staleTokens.push(tokens[index]);
        } else {
          logger.warn("push send failed", { code, message: result.error && result.error.message });
        }
      });
      if (staleTokens.length > 0) {
        await doc.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
        });
      }
    }),
  );
}

module.exports = { sendPushToUserIds };
