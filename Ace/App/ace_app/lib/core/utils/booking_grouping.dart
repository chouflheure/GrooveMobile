import 'package:flutter/widgets.dart';
import '../../data/models/models.dart';

/// One row in a "Réservations" feed — a booking group or a club event,
/// carried together with the date/time to sort them by so the two kinds can
/// be merged into a single chronological list.
class ProfileEntry {
  final DateTime date;
  final String startTime;
  final Widget child;

  const ProfileEntry({
    required this.date,
    required this.startTime,
    required this.child,
  });
}

/// Merges consecutive hourly bookings that share the same court, day, title
/// and players — an event or a multi-slot match booked across several
/// hours — into a single group, so the UI can show one card per logical
/// booking instead of one per hour. Group order follows each bucket's first
/// appearance in [bookings]; slots within a group are chronological.
List<List<BookingModel>> groupConsecutiveBookings(List<BookingModel> bookings) {
  final buckets = <String, List<BookingModel>>{};
  final order = <String>[];
  for (final b in bookings) {
    final key =
        '${b.courtId}_${b.date.year}-${b.date.month}-${b.date.day}'
        '_${b.title ?? ''}_${b.userId}_${b.partnerId ?? ''}';
    if (!buckets.containsKey(key)) order.add(key);
    buckets.putIfAbsent(key, () => []).add(b);
  }

  final groups = <List<BookingModel>>[];
  for (final key in order) {
    final bucket = buckets[key]!
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    List<BookingModel>? current;
    for (final b in bucket) {
      if (current != null && current.last.endTime == b.startTime) {
        current.add(b);
      } else {
        current = [b];
        groups.add(current);
      }
    }
  }
  return groups;
}
