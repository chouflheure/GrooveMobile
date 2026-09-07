import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/booking_model.dart';

/// Marker for every booking-rule violation `createBooking` (the Cloud
/// Function that owns all booking creation, see `BookingRepository.create`)
/// can report back — lets UI code catch "any policy violation" at once
/// while each subtype still carries its own user-facing message.
abstract class BookingValidationException implements Exception {}

/// Thrown when a booking is attempted on a slot another booking already holds.
class SlotAlreadyBookedException implements BookingValidationException {
  const SlotAlreadyBookedException();

  @override
  String toString() =>
      'Ce créneau vient d\'être réservé par quelqu\'un d\'autre.';
}

/// Thrown when the booker isn't a member of the club the court belongs to.
class ClubMismatchException implements BookingValidationException {
  const ClubMismatchException();

  @override
  String toString() =>
      "Vous devez être membre du club de ce terrain pour le réserver.";
}

/// Thrown when the court is closed for the whole day of the booking.
class CourtClosedException implements BookingValidationException {
  const CourtClosedException();

  @override
  String toString() => 'Ce terrain est fermé à cette date.';
}

/// Thrown when the slot's time falls outside a restricted-hours window
/// that applies to the booking's date.
class SlotOutsideHoursException implements BookingValidationException {
  const SlotOutsideHoursException();

  @override
  String toString() => 'Ce terrain n\'est pas ouvert à cette heure ce jour-là.';
}

/// Thrown when the booker already holds an outstanding "heure pleine" slot
/// — capped per the court's `BookingPolicy.peakHourLimit`, across every court.
class PeakHourLimitExceededException implements BookingValidationException {
  const PeakHourLimitExceededException();

  @override
  String toString() =>
      'Tu as déjà une réservation en heure pleine en cours. Attends '
      'qu\'elle soit passée pour en reprendre une.';
}

/// Thrown when the booker already holds too many outstanding "heure
/// creuse" slots — capped per the court's `BookingPolicy.offPeakHourLimit`,
/// across every court.
class OffPeakHourLimitExceededException implements BookingValidationException {
  const OffPeakHourLimitExceededException();

  @override
  String toString() =>
      'Tu as déjà trop de réservations en heure creuse en cours. Attends '
      'qu\'une d\'elles soit passée pour en reprendre une autre.';
}

/// Thrown when the booking's date falls outside the court's
/// `BookingPolicy.bookingWindowDays`.
class BookingWindowExceededException implements BookingValidationException {
  final String message;
  const BookingWindowExceededException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the booker already has `BookingPolicy.maxSlotsPerDay` slots
/// on this same court on this same day.
class DailyLimitExceededException implements BookingValidationException {
  final String message;
  const DailyLimitExceededException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the booker already has `BookingPolicy.maxSlotsPerWeek` slots
/// on this same court within the policy's week window.
class WeeklyLimitExceededException implements BookingValidationException {
  final String message;
  const WeeklyLimitExceededException(this.message);

  @override
  String toString() => message;
}

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west9');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('bookings');

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Creates a booking via the `createBooking` Cloud Function — every
  /// business rule (club membership, court closures, the court's
  /// `BookingPolicy` limits) is enforced there with Admin SDK privileges,
  /// since `firestore.rules` denies writing to `bookings` directly. Using
  /// `${courtId}_${date}_${startTime}` as the document id is what lets that
  /// function's own transaction guarantee "only one active booking per
  /// slot" atomically.
  Future<void> create(BookingModel booking) async {
    try {
      await _functions.httpsCallable('createBooking').call(booking.toJson());
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(FirebaseFunctionsException e) {
    final reason = e.details is Map ? (e.details as Map)['reason'] : null;
    final message = e.message ?? e.toString();
    switch (reason) {
      case 'slot_taken':
        return const SlotAlreadyBookedException();
      case 'club_mismatch':
        return const ClubMismatchException();
      case 'court_closed':
        return const CourtClosedException();
      case 'outside_hours':
        return const SlotOutsideHoursException();
      case 'peak_limit':
        return const PeakHourLimitExceededException();
      case 'off_peak_limit':
        return const OffPeakHourLimitExceededException();
      case 'window_exceeded':
        return BookingWindowExceededException(message);
      case 'daily_limit':
        return DailyLimitExceededException(message);
      case 'weekly_limit':
        return WeeklyLimitExceededException(message);
      default:
        return Exception(message);
    }
  }

  /// One-shot fetch, e.g. resolving a notification tap's `bookingId` to the
  /// model `BookingDetailScreen` needs.
  Future<BookingModel?> getById(String bookingId) async {
    final doc = await _collection.doc(bookingId).get();
    if (!doc.exists) return null;
    return BookingModel.fromJson(doc.data()!);
  }

  Future<void> update(BookingModel booking) {
    return _collection.doc(booking.id).set(_withDateKey(booking));
  }

  Map<String, dynamic> _withDateKey(BookingModel booking) => {
    ...booking.toJson(),
    'dateKey': _dateKey(booking.date),
  };

  Future<void> cancel(String bookingId) {
    return _collection.doc(bookingId).update({
      'status': BookingStatus.cancelled.jsonValue,
    });
  }

  /// Every booking this user is part of — as the booker or as the invited
  /// partner, since a booking only ever lists `userId` on the doc itself.
  Stream<List<BookingModel>> watchByUser(String userId) {
    return _collection
        .where(
          Filter.or(
            Filter('userId', isEqualTo: userId),
            Filter('partnerId', isEqualTo: userId),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// All bookings across every player — admin/manager use only.
  Stream<List<BookingModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList(),
    );
  }

  /// Streams, for a given day, which `courtId + startTime` slots are held by
  /// a non-cancelled booking — used to grey out slots across all courts.
  Stream<Map<String, Set<String>>> watchBookedSlotsForDate(DateTime date) {
    return _collection
        .where('dateKey', isEqualTo: _dateKey(date))
        .snapshots()
        .map((snapshot) {
          final result = <String, Set<String>>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['status'] == BookingStatus.cancelled.jsonValue) continue;
            final courtId = data['courtId'] as String;
            final startTime = data['startTime'] as String;
            result.putIfAbsent(courtId, () => {}).add(startTime);
          }
          return result;
        });
  }
}
