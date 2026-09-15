const admin = require("firebase-admin");

/**
 * Records an in-app "bell" notification for each recipient — the data
 * behind the notifications screen and the icon badge count in the app.
 * Called alongside `sendPushToUserIds` (not instead of it) wherever a push
 * kind belongs in the bell — messages and broadcasts intentionally never
 * call this, they have their own dedicated unread tracking in their own
 * tabs already.
 *
 * `type`/`title`/`body`/`data` should mirror exactly what the matching
 * push carries, so `NotificationsScreen` can hand `data` straight to the
 * same `handleNotificationTap` the push-tap flow already uses — no
 * separate routing logic to keep in sync.
 */
async function createNotifications(userIds, { type, title, body, data = {} }) {
  const uniqueIds = [...new Set(userIds)].filter(Boolean);
  if (uniqueIds.length === 0) return;

  const db = admin.firestore();
  const collection = db.collection("notifications");
  const batch = db.batch();
  const createdAt = new Date().toISOString();

  for (const userId of uniqueIds) {
    const ref = collection.doc();
    batch.set(ref, {
      id: ref.id,
      userId,
      type,
      title,
      body,
      data,
      createdAt,
      seen: false,
      clicked: false,
    });
  }

  await batch.commit();
}

module.exports = { createNotifications };
