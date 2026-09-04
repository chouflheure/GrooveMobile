// The app has a single club timezone; bookings are stored as a plain
// "YYYY-MM-DD" dateKey + "HH:mm" startTime with no UTC offset attached, so
// Cloud Functions (which run in UTC) need to know which zone those wall-clock
// strings are meant in to compute "is this booking starting in an hour".
const APP_TIMEZONE = "Europe/Paris";

/** The "YYYY-MM-DD" dateKey `date` falls on, read in `timeZone`. */
function dateKeyInTimeZone(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const byType = Object.fromEntries(parts.map((p) => [p.type, p.value]));
  return `${byType.year}-${byType.month}-${byType.day}`;
}

/**
 * Resolves a "YYYY-MM-DD" + "HH:mm" wall-clock pair, meant in `timeZone`,
 * to the actual UTC instant it refers to (correctly handling that zone's
 * DST offset on that particular date).
 */
function zonedTimeToUtc(dateKey, hhmm, timeZone) {
  const [year, month, day] = dateKey.split("-").map(Number);
  const [hour, minute] = hhmm.split(":").map(Number);
  const asUtc = Date.UTC(year, month - 1, day, hour, minute);
  const inTimeZone = new Date(new Date(asUtc).toLocaleString("en-US", { timeZone }));
  const offset = asUtc - inTimeZone.getTime();
  return new Date(asUtc + offset);
}

/**
 * Local midnight for `date`'s day (read in `timeZone`), formatted the same
 * way Dart's `DateTime(y, m, d).toIso8601String()` does for a day-only,
 * no-offset local date — e.g. "2026-09-04T00:00:00.000". `events.date` and
 * `broadcasts.date` are stored in that exact format, so this string can be
 * compared against them directly (lexicographically, since both share the
 * same no-offset local format) to find everything before today.
 */
function localMidnightIsoString(date, timeZone) {
  return `${dateKeyInTimeZone(date, timeZone)}T00:00:00.000`;
}

/**
 * Formats a booking/event/broadcast `date` field (a plain no-offset ISO
 * string, e.g. "2026-12-10T00:00:00.000") as "10/12/2026" for display —
 * reads the "YYYY-MM-DD" straight out of the string instead of going
 * through a `Date` object, so it can't be shifted by a day depending on
 * the Cloud Function's own timezone.
 */
function formatDateFr(isoDate) {
  const [year, month, day] = isoDate.slice(0, 10).split("-");
  return `${day}/${month}/${year}`;
}

module.exports = {
  APP_TIMEZONE,
  dateKeyInTimeZone,
  zonedTimeToUtc,
  localMidnightIsoString,
  formatDateFr,
};
