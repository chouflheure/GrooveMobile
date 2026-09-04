import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';

/// Thrown when a booking is attempted on a slot another booking already holds.
class SlotAlreadyBookedException implements Exception {
  const SlotAlreadyBookedException();

  @override
  String toString() =>
      'Ce créneau vient d\'être réservé par quelqu\'un d\'autre.';
}

/// Thrown when the booker isn't a member of the club the court belongs to.
class ClubMismatchException implements Exception {
  const ClubMismatchException();

  @override
  String toString() =>
      "Vous devez être membre du club de ce terrain pour le réserver.";
}

/// Thrown when the court is closed for the whole day of the booking.
class CourtClosedException implements Exception {
  const CourtClosedException();

  @override
  String toString() => 'Ce terrain est fermé à cette date.';
}

/// Thrown when the slot's time falls outside a restricted-hours window
/// that applies to the booking's date.
class SlotOutsideHoursException implements Exception {
  const SlotOutsideHoursException();

  @override
  String toString() => 'Ce terrain n\'est pas ouvert à cette heure ce jour-là.';
}

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Creates a booking, using `${courtId}_${date}_${startTime}` as the
  /// document id so Firestore's transaction get+set gives us an atomic
  /// "only one active booking per slot" guarantee — Firestore transactions
  /// can only read a specific document, not a query, so the uniqueness key
  /// has to live in the id itself.
  Future<void> create(BookingModel booking) async {
    final docRef = _collection.doc(booking.slotKey);
    final courtRef = _firestore.collection('courts').doc(booking.courtId);
    final bookerRef = _usersCollection.doc(booking.userId);

    await _firestore.runTransaction((tx) async {
      // Firestore transactions require every read before any write, so the
      // club-membership check runs first.
      final courtSnap = await tx.get(courtRef);
      final bookerSnap = await tx.get(bookerRef);
      final clubId = courtSnap.data()?['clubId'] as String?;
      final clubIds =
          (bookerSnap.data()?['clubIds'] as List?)?.cast<String>() ?? const [];
      if (clubId != null && clubId.isNotEmpty && !clubIds.contains(clubId)) {
        throw const ClubMismatchException();
      }

      final periodsJson = courtSnap.data()?['unavailablePeriods'] as List?;
      final periods =
          periodsJson
              ?.map(
                (p) => UnavailablePeriod.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [];
      if (periods.any((p) => p.covers(booking.date))) {
        throw const CourtClosedException();
      }

      final overridesJson = courtSnap.data()?['availabilityOverrides'] as List?;
      final overrides =
          overridesJson
              ?.map(
                (p) => AvailabilityOverride.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [];
      final activeOverride = overrides
          .where((o) => o.covers(booking.date))
          .firstOrNull;
      if (activeOverride != null &&
          !activeOverride.allowsTime(booking.startTime)) {
        throw const SlotOutsideHoursException();
      }

      final existing = await tx.get(docRef);
      if (existing.exists) {
        final status = existing.data()?['status'] as String?;
        if (status != BookingStatus.cancelled.jsonValue) {
          throw const SlotAlreadyBookedException();
        }
      }
      tx.set(docRef, _withDateKey(booking.copyWith(id: docRef.id)));

      // Link the booking on both players' profiles — the `bookings`
      // collection (queried by userId) is still the source of truth, this
      // is just a reference kept on each user doc.
      tx.update(_usersCollection.doc(booking.userId), {
        'bookingIds': FieldValue.arrayUnion([docRef.id]),
      });
      if (booking.partnerId != null && booking.partnerId!.isNotEmpty) {
        tx.update(_usersCollection.doc(booking.partnerId), {
          'bookingIds': FieldValue.arrayUnion([docRef.id]),
        });
      }
    });
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
