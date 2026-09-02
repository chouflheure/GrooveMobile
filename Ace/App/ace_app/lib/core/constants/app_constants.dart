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

  static const List<String> timeSlots = [
    '07:00', '07:30', '08:00', '08:30', '09:00', '09:30',
    '10:00', '10:30', '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
    '19:00', '19:30', '20:00', '20:30', '21:00',
  ];

  static const double bookingDurationHours = 1.5;

  /// How many days ahead the court detail screen's date picker shows.
  static const int bookingCalendarDays = 10;

  /// Midnight of the current day — anchors "today" across the app (home
  /// list availability, the first selectable day in the date picker).
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
