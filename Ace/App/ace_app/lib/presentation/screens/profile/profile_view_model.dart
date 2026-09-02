import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../courts/courts_view_model.dart';

class ProfileState {
  final UserModel user;
  final List<BookingModel> bookings;
  final bool isLoading;

  const ProfileState({
    required this.user,
    this.bookings = const [],
    this.isLoading = false,
  });

  List<BookingModel> get pastBookings =>
      bookings.where((b) => b.isPast).toList();

  List<BookingModel> get upcomingBookings =>
      bookings.where((b) => b.isUpcoming).toList();

  ProfileState copyWith({
    UserModel? user,
    List<BookingModel>? bookings,
    bool? isLoading,
  }) {
    return ProfileState(
      user: user ?? this.user,
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel(this._bookingRepository)
      : super(ProfileState(user: MockData.currentUser)) {
    state = state.copyWith(isLoading: true);
    _subscription =
        _bookingRepository.watchByUser(MockData.currentUser.id).listen((
      bookings,
    ) {
      state = state.copyWith(bookings: bookings, isLoading: false);
    });
  }

  final BookingRepository _bookingRepository;
  late final StreamSubscription<List<BookingModel>> _subscription;

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
    _subscription.cancel();
    super.dispose();
  }
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>(
  (ref) => ProfileViewModel(ref.watch(bookingRepositoryProvider)),
);
