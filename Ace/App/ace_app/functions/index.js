const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const { sendPushToUserIds } = require("./lib/push");
const { deleteAll } = require("./lib/firestore");
const {
  APP_TIMEZONE,
  dateKeyInTimeZone,
  zonedTimeToUtc,
  localMidnightIsoString,
} = require("./lib/time");

admin.initializeApp();

// Deployed in the same region as the Firestore database (europe-west9,
// Paris) — mixing regions between the functions and the Firestore trigger
// they listen to is what caused the Eventarc "permission denied" errors on
// first deploy. `maxInstances` is a per-function cap for cost control;
// override it on an individual function if it needs a different one.
setGlobalOptions({ region: "europe-west9", maxInstances: 10 });

/**
 * A 1:1 or group chat message was sent — notify every other participant
 * (the club broadcast channel writes here too, but with an empty
 * `participantIds`, so it's a no-op here by construction).
 */
exports.onMessageCreated = onDocumentCreated("messages/{messageId}", async (event) => {
  const message = event.data && event.data.data();
  if (!message) return;

  const recipientIds = (message.participantIds || []).filter(
    (id) => id && id !== message.senderId,
  );
  if (recipientIds.length === 0) return;

  await sendPushToUserIds(
    recipientIds,
    {
      title: message.senderName || "Nouveau message",
      body: message.content || "",
    },
    { type: "message", conversationId: message.conversationId },
    { prefKey: "Messages" },
  );
});

/**
 * A new match-request ("annonce"/broadcast) was posted — notify every
 * player who opted into "Demandes de jeu", except its author.
 */
exports.onBroadcastCreated = onDocumentCreated("broadcasts/{broadcastId}", async (event) => {
  const broadcast = event.data && event.data.data();
  if (!broadcast) return;

  const db = admin.firestore();
  const snapshot = await db
    .collection("users")
    .where("notifications.Demandes de jeu", "==", true)
    .get();

  const recipientIds = snapshot.docs
    .map((doc) => doc.id)
    .filter((id) => id !== broadcast.userId);
  if (recipientIds.length === 0) return;

  await sendPushToUserIds(recipientIds, {
    title: "Nouvelle demande de jeu",
    body: `${broadcast.userName} cherche un partenaire sur ${broadcast.courtName}.`,
  }, {
    type: "broadcast",
    broadcastId: event.params.broadcastId,
  });
});

/**
 * A club created a new event — notify every member of that club.
 */
exports.onClubEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const clubEvent = event.data && event.data.data();
  if (!clubEvent || !clubEvent.clubId) return;

  const db = admin.firestore();
  const snapshot = await db
    .collection("users")
    .where("clubIds", "array-contains", clubEvent.clubId)
    .get();

  const recipientIds = snapshot.docs.map((doc) => doc.id);
  if (recipientIds.length === 0) return;

  await sendPushToUserIds(recipientIds, {
    title: "Nouvel événement au club",
    body: clubEvent.title || "Un nouvel événement a été créé.",
  }, {
    type: "club_event",
    eventId: event.params.eventId,
    clubId: clubEvent.clubId,
  });
});

/**
 * A booking was created — notify whoever was put on it without being the
 * one who booked it: the invited partner always, and (for a booking an
 * admin made on someone's behalf, `isAdminBooking`) the player themselves
 * too, since neither of them initiated it. A player booking their own
 * slot solo doesn't need telling. Internal event-blocking bookings
 * (`isEventBlock`) aren't a real reservation and are skipped.
 */
exports.onBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const booking = event.data && event.data.data();
  if (!booking || booking.isEventBlock) return;

  const recipientIds = booking.isAdminBooking
    ? [booking.userId, booking.partnerId].filter(Boolean)
    : [booking.partnerId].filter(Boolean);
  if (recipientIds.length === 0) return;

  await sendPushToUserIds(recipientIds, {
    title: "Nouveau match",
    body: `Tu as été ajouté à un match le ${booking.startTime} sur ${booking.courtName}.`,
  }, {
    type: "booking_created",
    bookingId: event.params.bookingId,
  });
});

/**
 * A booking flipped to "cancelled" — notify whoever had the slot (the
 * booker and their partner, if any). Internal event-blocking bookings
 * (`isEventBlock`) don't belong to a real reservation and are skipped.
 */
exports.onBookingCancelled = onDocumentUpdated("bookings/{bookingId}", async (event) => {
  const before = event.data && event.data.before.data();
  const after = event.data && event.data.after.data();
  if (!before || !after) return;
  if (before.status === "cancelled" || after.status !== "cancelled") return;
  if (after.isEventBlock) return;

  const recipientIds = [after.userId, after.partnerId].filter(Boolean);
  if (recipientIds.length === 0) return;

  await sendPushToUserIds(recipientIds, {
    title: "Créneau annulé",
    body: `Ta réservation du ${after.startTime} sur ${after.courtName} a été annulée.`,
  }, {
    type: "booking_cancelled",
    bookingId: event.params.bookingId,
  });
});

/**
 * Runs every 15 minutes and pushes a reminder to anyone whose booking
 * starts in about an hour. Scans by `dateKey` (today's and, near midnight,
 * tomorrow's) rather than a Firestore-side time range, since a booking's
 * start time only exists as a separate "HH:mm" string, not a timestamp.
 * A `reminderSent` flag on the booking doc keeps a slow-running/retried
 * invocation from double-sending.
 */
exports.sendBookingReminders = onSchedule(
  { schedule: "every 15 minutes", timeZone: APP_TIMEZONE, region: "europe-west9" },
  async () => {
    const now = new Date();
    const windowStart = new Date(now.getTime() + 55 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 65 * 60 * 1000);

    const dateKeys = new Set([
      dateKeyInTimeZone(windowStart, APP_TIMEZONE),
      dateKeyInTimeZone(windowEnd, APP_TIMEZONE),
    ]);

    const db = admin.firestore();
    const snapshots = await Promise.all(
      [...dateKeys].map((dateKey) =>
        db.collection("bookings").where("dateKey", "==", dateKey).get(),
      ),
    );

    const due = [];
    for (const snapshot of snapshots) {
      for (const doc of snapshot.docs) {
        const booking = doc.data();
        if (booking.status === "cancelled") continue;
        if (booking.isEventBlock) continue;
        if (booking.reminderSent) continue;

        const startAt = zonedTimeToUtc(booking.dateKey, booking.startTime, APP_TIMEZONE);
        if (startAt >= windowStart && startAt <= windowEnd) {
          due.push({ ref: doc.ref, booking });
        }
      }
    }

    await Promise.all(
      due.map(async ({ ref, booking }) => {
        const recipientIds = [booking.userId, booking.partnerId].filter(Boolean);
        await sendPushToUserIds(
          recipientIds,
          {
            title: "Rappel de match",
            body: `Ton match sur ${booking.courtName} commence à ${booking.startTime}.`,
          },
          { type: "booking_reminder", bookingId: ref.id },
          { prefKey: "Rappel de créneau" },
        );
        await ref.update({ reminderSent: true });
      }),
    );
  },
);

/**
 * Runs daily at 23:00 (Paris) and deletes every club event whose day has
 * fully passed. `date` is stored as a plain no-offset ISO string (a day,
 * not a Firestore Timestamp), so a lexicographic comparison against
 * today's local midnight is enough to catch everything before today.
 */
exports.deletePastEvents = onSchedule(
  { schedule: "0 23 * * *", timeZone: APP_TIMEZONE, region: "europe-west9" },
  async () => {
    const todayMidnight = localMidnightIsoString(new Date(), APP_TIMEZONE);
    const snapshot = await admin
      .firestore()
      .collection("events")
      .where("date", "<", todayMidnight)
      .get();
    if (snapshot.empty) return;

    await deleteAll(snapshot.docs.map((doc) => doc.ref));
    logger.info(`deletePastEvents: removed ${snapshot.size} event(s)`);
  },
);

/**
 * Runs daily at 00:00 (Paris) and deletes every match-request ("annonce"/
 * broadcast) whose date has fully passed — same comparison as above.
 */
exports.deletePastBroadcasts = onSchedule(
  { schedule: "0 0 * * *", timeZone: APP_TIMEZONE, region: "europe-west9" },
  async () => {
    const todayMidnight = localMidnightIsoString(new Date(), APP_TIMEZONE);
    const snapshot = await admin
      .firestore()
      .collection("broadcasts")
      .where("date", "<", todayMidnight)
      .get();
    if (snapshot.empty) return;

    await deleteAll(snapshot.docs.map((doc) => doc.ref));
    logger.info(`deletePastBroadcasts: removed ${snapshot.size} broadcast(s)`);
  },
);
