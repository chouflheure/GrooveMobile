const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const { sendPushToUserIds } = require("./lib/push");
const { createNotifications } = require("./lib/notifications");
const { deleteAll } = require("./lib/firestore");
const { createBooking } = require("./lib/booking");
const { sendPasswordResetEmail } = require("./lib/password_reset");
const {
  APP_TIMEZONE,
  dateKeyInTimeZone,
  zonedTimeToUtc,
  localMidnightIsoString,
  formatDateFr,
} = require("./lib/time");

admin.initializeApp();

// The only way a `bookings` document is created — `firestore.rules` denies
// writing to that collection directly from the client, so every rule the
// court's `BookingPolicy` defines is enforced here with Admin SDK
// privileges instead of trusting the app.
exports.createBooking = createBooking;

// Sends the reset email ourselves via Mailgun, with our own design, instead
// of Firebase Auth's automatic one (unstyled, easily flagged as spam) — see
// AuthRepository.sendPasswordResetEmail on the client.
exports.sendPasswordResetEmail = sendPasswordResetEmail;

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

  const title = "Nouvel événement au club";
  const body = clubEvent.title || "Un nouvel événement a été créé.";
  const data = {
    type: "club_event",
    eventId: event.params.eventId,
    clubId: clubEvent.clubId,
  };
  await Promise.all([
    sendPushToUserIds(recipientIds, { title, body }, data),
    createNotifications(recipientIds, { type: data.type, title, body, data }),
  ]);
});

/**
 * A club created a new internal tournament — notify every member of that
 * club, same as `onClubEventCreated`. Skipped when the admin already
 * pre-selected a roster at creation (`participantIds` non-empty) — that's
 * the whole point of picking players up front instead of opening
 * registration, so blasting the entire club would defeat it. Later
 * tournament lifecycle (bracket drawn, match scheduled) needs no push code
 * of its own either: match scheduling creates a real two-player booking,
 * which `onBookingCreated` below already notifies both players about.
 */
exports.onTournamentCreated = onDocumentCreated("tournaments/{tournamentId}", async (event) => {
  const tournament = event.data && event.data.data();
  if (!tournament || !tournament.clubId) return;
  if ((tournament.participantIds || []).length > 0) return;

  const db = admin.firestore();
  const snapshot = await db
    .collection("users")
    .where("clubIds", "array-contains", tournament.clubId)
    .get();

  const recipientIds = snapshot.docs.map((doc) => doc.id);
  if (recipientIds.length === 0) return;

  const title = "Nouveau tournoi au club";
  const body = tournament.title || "Un nouveau tournoi a été créé.";
  const data = {
    type: "tournament",
    tournamentId: event.params.tournamentId,
    clubId: tournament.clubId,
  };
  await Promise.all([
    sendPushToUserIds(recipientIds, { title, body }, data),
    createNotifications(recipientIds, { type: data.type, title, body, data }),
  ]);
});

/**
 * A booking was created — notify whoever was put on it without being the
 * one who booked it: the invited partner always, and (for a booking an
 * admin made on someone's behalf, `isAdminBooking`) the player themselves
 * too, since neither of them initiated it. Whoever actually called
 * `createBooking` (`createdByUserId`) never gets notified about their own
 * action — for a normal booking that's already just `userId`, but an admin
 * scheduling a match they're also playing in (`userId`/`partnerId` is one
 * of the two players, not necessarily the admin) needs this too. A player
 * booking their own slot solo doesn't need telling. Internal
 * event-blocking bookings (`isEventBlock`) aren't a real reservation and
 * are skipped.
 */
exports.onBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const booking = event.data && event.data.data();
  if (!booking || booking.isEventBlock) return;

  const candidateIds = booking.isAdminBooking
    ? [booking.userId, booking.partnerId]
    : [booking.partnerId];
  const recipientIds = candidateIds.filter(
    (id) => id && id !== booking.createdByUserId,
  );
  if (recipientIds.length === 0) return;

  // The title names the opponent, which depends on who's receiving it — the
  // booking doc only carries the booker's id (not their name), so it's
  // looked up once, only if someone other than the booker actually needs it.
  let bookerName = null;
  if (recipientIds.includes(booking.partnerId)) {
    const bookerDoc = await admin.firestore().collection("users").doc(booking.userId).get();
    bookerName = bookerDoc.exists ? bookerDoc.get("name") : null;
  }

  const dateStr = formatDateFr(booking.date);
  const titleFor = (recipientId) => {
    const opponentName =
      (recipientId === booking.partnerId ? bookerName : booking.partnerName) ||
      "un partenaire";
    return `Match contre ${opponentName} le ${dateStr} à ${booking.startTime} sur le terrain ${booking.courtName}`;
  };

  await Promise.all(
    recipientIds.map((recipientId) => {
      const title = titleFor(recipientId);
      const body = "Tu as été ajouté à ce match.";
      const data = { type: "booking_created", bookingId: event.params.bookingId };
      return Promise.all([
        sendPushToUserIds([recipientId], { title, body }, data),
        createNotifications([recipientId], { type: data.type, title, body, data }),
      ]);
    }),
  );
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

  const title = "Créneau annulé";
  const body = `Ta réservation du ${after.startTime} sur ${after.courtName} a été annulée.`;
  const data = { type: "booking_cancelled", bookingId: event.params.bookingId };
  await Promise.all([
    sendPushToUserIds(recipientIds, { title, body }, data),
    createNotifications(recipientIds, { type: data.type, title, body, data }),
  ]);
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
        const title = "Rappel de match";
        const body = `Ton match sur ${booking.courtName} commence à ${booking.startTime}.`;
        const data = { type: "booking_reminder", bookingId: ref.id };
        await Promise.all([
          sendPushToUserIds(recipientIds, { title, body }, data, { prefKey: "Rappel de créneau" }),
          createNotifications(recipientIds, { type: data.type, title, body, data }),
        ]);
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
