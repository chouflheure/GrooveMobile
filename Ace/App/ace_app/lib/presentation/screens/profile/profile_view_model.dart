import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../auth/auth_view_model.dart';
import '../courts/courts_view_model.dart';

class ProfileState {
  final List<BookingModel> bookings;
  final bool isLoading;

  const ProfileState({this.bookings = const [], this.isLoading = false});

  // Event-driven slot blocks aren't a personal reservation — they just mark
  // a court unavailable for an event — so they're excluded from here even
  // when the admin who created the event is the one who'd otherwise see it.
  List<BookingModel> get pastBookings =>
      bookings.where((b) => b.isPast && !b.isEventBlock).toList();

  List<BookingModel> get upcomingBookings =>
      bookings.where((b) => b.isUpcoming && !b.isEventBlock).toList()
        ..sort((a, b) {
          final cmp = a.date.compareTo(b.date);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });

  ProfileState copyWith({List<BookingModel>? bookings, bool? isLoading}) {
    return ProfileState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel(this._bookingRepository, String? userId)
    : super(ProfileState(isLoading: userId != null)) {
    if (userId != null) {
      _subscription = _bookingRepository.watchByUser(userId).listen((bookings) {
        state = state.copyWith(bookings: bookings, isLoading: false);
      });
    }
  }

  final BookingRepository _bookingRepository;
  StreamSubscription<List<BookingModel>>? _subscription;

  /// Writes the booking to Firestore; the slot is claimed atomically via a
  /// transaction (see [BookingRepository.create]), so this throws
  /// [SlotAlreadyBookedException] if someone else booked it first. The
  /// bookings list above updates on its own once the write lands.
  Future<void> addBooking(BookingModel booking) {
    return _bookingRepository.create(booking);
  }

  Future<void> updateBooking(BookingModel updated) {
    return _bookingRepository.update(updated);
  }

  Future<void> cancelBooking(String id) {
    return _bookingRepository.cancel(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>((ref) {
      final userId = ref.watch(
        currentUserProvider.select((async) => async.valueOrNull?.id),
      );
      return ProfileViewModel(ref.watch(bookingRepositoryProvider), userId);
    });
