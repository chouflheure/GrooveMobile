class AppConstants {
  AppConstants._();

  static const String appName = 'CourtConnect';

  static const List<String> fftRankings = [
    '40', '30/5', '30/4', '30/3', '30/2', '30/1', '30',
    '15/5', '15/4', '15/3', '15/2', '15/1', '15',
    '4/6', '3/6', '2/6', '1/6', '0', '-2/6', '-4/6',
    '-15', '-15/1', '-15/2', '-15/3', '-15/4',
    '-30', 'N.C.',
  ];

  static const List<String> surfaceTypes = [
    'Tous', 'Extérieur', 'Intérieur', 'Terre battue', 'Dur', 'Gazon',
  ];

  /// Every court is open 8h-20h with hourly slots — one booking = one hour.
  static const List<String> timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00',
    '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
  ];

  static const double bookingDurationHours = 1;

  /// How many days ahead the court detail screen's date picker shows.
  static const int bookingCalendarDays = 10;

  /// Midnight of the current day — anchors "today" across the app (home
  /// list availability, the first selectable day in the date picker).
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Grace period after a slot's start time during which it can still be
  /// booked (e.g. showing up a bit late for a 15:00 slot at 15:30 is fine).
  static const Duration slotBookingGracePeriod = Duration(minutes: 45);

  /// Whether a `HH:mm` slot on the given day is past its booking grace
  /// period — used to hide same-day slots that are truly too late to book.
  static bool isSlotPast(DateTime date, String time) {
    final parts = time.split(':');
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return start.add(slotBookingGracePeriod).isBefore(DateTime.now());
  }
}
