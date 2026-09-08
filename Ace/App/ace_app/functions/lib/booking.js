const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { APP_TIMEZONE, dateKeyInTimeZone, zonedTimeToUtc } = require("./time");

/** Throws an `HttpsError` carrying a machine-readable `reason` in its
 * `details`, so the Dart client can map it back to the same typed
 * exceptions `BookingRepository.create` threw when it validated locally. */
function fail(reason, message) {
  throw new HttpsError("failed-precondition", message, { reason });
}

function toDateKey(isoDate) {
  return isoDate.slice(0, 10);
}

function dateKeyToUtcDate(dateKey) {
  const [y, m, d] = dateKey.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function daysBetween(fromKey, toKey) {
  return Math.round(
    (dateKeyToUtcDate(toKey) - dateKeyToUtcDate(fromKey)) / MS_PER_DAY,
  );
}

/** Same field defaults as `BookingPolicy.fromJson` on the Dart side, so a
 * court document saved before this feature existed still behaves exactly
 * like the old hard-coded 1-peak/2-off-peak cap. */
function resolvePolicyFromMap(policyMap) {
  const p = policyMap || {};
  return {
    bookingWindowDays:
      typeof p.bookingWindowDays === "number" ? p.bookingWindowDays : 10,
    peakHoursEnabled: p.peakHoursEnabled !== false,
    peakHourLimit: p.peakHourLimit === undefined ? 1 : p.peakHourLimit,
    offPeakHourLimit: p.offPeakHourLimit === undefined ? 2 : p.offPeakHourLimit,
    maxSlotsPerDay: p.maxSlotsPerDay ?? null,
    maxSlotsPerWeek: p.maxSlotsPerWeek ?? null,
    weekPeriod: p.weekPeriod === "rolling" ? "rolling" : "calendar",
  };
}

/**
 * A court's rules come from its assigned scenario (`bookingScenarios/{id}`,
 * the single source of truth so editing a scenario updates every court
 * using it instantly) — falling back to a pre-scenario court's own
 * embedded `policy`, then to defaults, exactly mirroring
 * `CourtsViewModel._resolvePolicy` on the Dart side.
 */
async function resolvePolicyForCourt(db, court) {
  if (court.scenarioId) {
    const scenarioSnap = await db
      .collection("bookingScenarios")
      .doc(court.scenarioId)
      .get();
    if (scenarioSnap.exists) {
      return resolvePolicyFromMap(scenarioSnap.data().policy);
    }
  }
  return resolvePolicyFromMap(court.policy);
}

function isPeakSlot(court, policy, startTime) {
  return policy.peakHoursEnabled && (court.peakHours || []).includes(startTime);
}

function periodCoversDateKey(period, dateKey) {
  return toDateKey(period.startDate) <= dateKey && dateKey <= toDateKey(period.endDate);
}

function overrideAllowsTime(override, time) {
  return time >= override.openFrom && time < override.openTo;
}

/** [weekStartKey, weekEndKey] (both inclusive) the given date falls in. */
function weekRangeFor(dateKey, weekPeriod) {
  if (weekPeriod === "rolling") {
    const end = dateKeyToUtcDate(dateKey);
    const start = new Date(end.getTime() - 6 * MS_PER_DAY);
    return [dateKeyInTimeZone(start, "UTC"), dateKeyInTimeZone(end, "UTC")];
  }
  // Calendar week: Monday..Sunday.
  const d = dateKeyToUtcDate(dateKey);
  const weekday = d.getUTCDay(); // 0 = Sunday .. 6 = Saturday
  const sinceMonday = (weekday + 6) % 7;
  const start = new Date(d.getTime() - sinceMonday * MS_PER_DAY);
  const end = new Date(start.getTime() + 6 * MS_PER_DAY);
  return [dateKeyInTimeZone(start, "UTC"), dateKeyInTimeZone(end, "UTC")];
}

/**
 * Creates a booking with every business rule enforced server-side — the
 * counterpart of what `BookingRepository.create` used to validate
 * client-only. `bookings/{bookingId} allow create` is `false` in
 * firestore.rules, so this callable (running with Admin SDK privileges) is
 * the only way a booking document comes into existence.
 */
exports.createBooking = onCall({ region: "europe-west9" }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Connecte-toi pour réserver.");
  }

  const data = request.data || {};
  const { courtId, userId, partnerId, startTime, isEventBlock, hasExternalPlayer } = data;
  const dateIso = data.date;
  if (!courtId || !userId || !startTime || !dateIso) {
    throw new HttpsError("invalid-argument", "Requête de réservation incomplète.");
  }
  const dateKey = toDateKey(dateIso);

  const db = admin.firestore();
  const courtRef = db.collection("courts").doc(courtId);
  const bookingsCollection = db.collection("bookings");

  const [courtSnap, isAdmin] = await Promise.all([
    courtRef.get(),
    db.collection("admin").doc(uid).get().then((d) => d.exists),
  ]);
  if (!courtSnap.exists) {
    throw new HttpsError("not-found", "Ce terrain n'existe plus.");
  }
  const court = courtSnap.data();
  const policy = await resolvePolicyForCourt(db, court);

  // Club membership — mirrors the check that used to live only in
  // firestore.rules: a regular booking always takes two players (even on a
  // club-less/legacy court) and must stay within the court's club; an
  // admin only needs to be in it themselves (or the court has no club at
  // all, the legacy/unset case). An external guest isn't an app user at
  // all, so there's no partner account to require or club-check — the
  // booker's own membership is still enforced below either way.
  const clubId = court.clubId || "";
  if (!isAdmin && !isEventBlock && !hasExternalPlayer && !partnerId) {
    throw new HttpsError("invalid-argument", "Un partenaire est requis pour cette réservation.");
  }
  if (clubId) {
    const [bookerSnap, partnerSnap] = await Promise.all([
      db.collection("users").doc(userId).get(),
      partnerId ? db.collection("users").doc(partnerId).get() : Promise.resolve(null),
    ]);
    const bookerClubs = (bookerSnap.data() || {}).clubIds || [];
    if (!bookerClubs.includes(clubId)) {
      fail("club_mismatch", "Vous devez être membre du club de ce terrain pour le réserver.");
    }
    if (!isAdmin && partnerId) {
      const partnerClubs = (partnerSnap.data() || {}).clubIds || [];
      if (!partnerClubs.includes(clubId)) {
        fail("club_mismatch", "Vous devez être membre du club de ce terrain pour le réserver.");
      }
    }
  }

  const isPeak = isPeakSlot(court, policy, startTime);

  // Admins are exempt from every rule below — a fairness/capacity policy
  // for regular players, not a hard limit on what the club itself can do.
  if (!isEventBlock && !isAdmin) {
    const todayKey = dateKeyInTimeZone(new Date(), APP_TIMEZONE);
    const offset = daysBetween(todayKey, dateKey);
    if (offset < 0 || offset >= policy.bookingWindowDays) {
      fail(
        "window_exceeded",
        `Ce terrain n'ouvre les réservations que ${policy.bookingWindowDays} jour(s) à l'avance.`,
      );
    }

    // Every non-cancelled, non-event-block booking this user holds or is
    // invited to, fetched once and filtered in memory for each rule below —
    // same trade-off `_checkHourLimit` made client-side: Firestore can't
    // combine an OR filter with a range query, and this is a soft fairness
    // rule, not the hard per-slot uniqueness the transaction below still
    // guarantees atomically.
    const [asBooker, asPartner] = await Promise.all([
      bookingsCollection.where("userId", "==", userId).get(),
      bookingsCollection.where("partnerId", "==", userId).get(),
    ]);
    const seen = new Set();
    const mine = [];
    for (const doc of [...asBooker.docs, ...asPartner.docs]) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      const b = doc.data();
      if (b.status === "cancelled" || b.isEventBlock) continue;
      mine.push(b);
    }

    if (policy.peakHoursEnabled) {
      const limit = isPeak ? policy.peakHourLimit : policy.offPeakHourLimit;
      if (limit !== null) {
        const now = Date.now();
        const outstanding = mine.filter((b) => {
          if (Boolean(b.isPeakHour) !== isPeak) return false;
          const endAt = zonedTimeToUtc(toDateKey(b.date), b.endTime, APP_TIMEZONE);
          return endAt.getTime() > now;
        }).length;
        if (outstanding + 1 > limit) {
          fail(
            isPeak ? "peak_limit" : "off_peak_limit",
            isPeak
              ? "Tu as déjà une réservation en heure pleine en cours. Attends qu'elle soit passée pour en reprendre une."
              : "Tu as déjà 2h de réservations en heure creuse en cours. Attends qu'une d'elles soit passée pour en reprendre une autre.",
          );
        }
      }
    }

    if (policy.maxSlotsPerDay !== null) {
      const sameDayOnCourt = mine.filter(
        (b) => b.courtId === courtId && toDateKey(b.date) === dateKey,
      ).length;
      if (sameDayOnCourt + 1 > policy.maxSlotsPerDay) {
        fail(
          "daily_limit",
          `Tu as atteint la limite de ${policy.maxSlotsPerDay} créneau(x) par jour sur ce terrain.`,
        );
      }
    }

    if (policy.maxSlotsPerWeek !== null) {
      const [weekStart, weekEnd] = weekRangeFor(dateKey, policy.weekPeriod);
      const inWeekOnCourt = mine.filter((b) => {
        if (b.courtId !== courtId) return false;
        const bKey = toDateKey(b.date);
        return bKey >= weekStart && bKey <= weekEnd;
      }).length;
      if (inWeekOnCourt + 1 > policy.maxSlotsPerWeek) {
        fail(
          "weekly_limit",
          `Tu as atteint la limite de ${policy.maxSlotsPerWeek} créneau(x) par semaine sur ce terrain.`,
        );
      }
    }
  }

  const bookingId = `${courtId}_${dateKey}_${startTime}`;
  const docRef = bookingsCollection.doc(bookingId);

  await db.runTransaction(async (tx) => {
    const freshCourtSnap = await tx.get(courtRef);
    const freshCourt = freshCourtSnap.data() || {};

    const periods = freshCourt.unavailablePeriods || [];
    if (periods.some((p) => periodCoversDateKey(p, dateKey))) {
      fail("court_closed", "Ce terrain est fermé à cette date.");
    }

    const overrides = freshCourt.availabilityOverrides || [];
    const activeOverride = overrides.find((o) => periodCoversDateKey(o, dateKey));
    if (activeOverride && !overrideAllowsTime(activeOverride, startTime)) {
      fail("outside_hours", "Ce terrain n'est pas ouvert à cette heure ce jour-là.");
    }

    const existing = await tx.get(docRef);
    if (existing.exists && existing.data().status !== "cancelled") {
      fail("slot_taken", "Ce créneau vient d'être réservé par quelqu'un d'autre.");
    }

    tx.set(docRef, {
      ...data,
      id: bookingId,
      isPeakHour: isPeak,
      dateKey,
    });

    tx.update(db.collection("users").doc(userId), {
      bookingIds: admin.firestore.FieldValue.arrayUnion(bookingId),
    });
    if (partnerId) {
      tx.update(db.collection("users").doc(partnerId), {
        bookingIds: admin.firestore.FieldValue.arrayUnion(bookingId),
      });
    }
  });

  return { id: bookingId };
});
