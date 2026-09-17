const admin = require("firebase-admin");

/**
 * The number this user's push should carry in `apns.payload.aps.badge` so
 * the home-screen icon reflects reality even while the app isn't running to
 * compute it itself (see `appIconBadgeCountProvider` on the Flutter side).
 * Mirrors that same formula as closely as a server can: unseen bell
 * notifications + unread messages, both tracked precisely in Firestore.
 * Unseen announcements are left out here — "seen" for those only exists as
 * a per-device timestamp (SharedPreferences), so the server has nothing to
 * compare against; the client corrects the badge for that component the
 * next time the app is foregrounded.
 */
async function computeBadgeCount(userId) {
  const db = admin.firestore();
  const [notifSnap, unreadMessagesSnap] = await Promise.all([
    db
      .collection("notifications")
      .where("userId", "==", userId)
      .where("seen", "==", false)
      .count()
      .get(),
    db
      .collection("messages")
      .where("participantIds", "array-contains", userId)
      .where("isRead", "==", false)
      .get(),
  ]);

  const unseenNotifications = notifSnap.data().count;
  const unreadMessages = unreadMessagesSnap.docs.filter(
    (doc) => doc.get("senderId") !== userId,
  ).length;
  return unseenNotifications + unreadMessages;
}

module.exports = { computeBadgeCount };
