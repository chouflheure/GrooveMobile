import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/court_repository.dart';
import '../auth/auth_view_model.dart';
import '../courts/courts_view_model.dart';

/// One planned slot within a multi-slot match — a court + player pair is
/// picked once for the whole match, this only carries the per-occurrence
/// date/time.
class MatchSlot {
  final DateTime date;
  final String startTime;
  final int durationHours;

  const MatchSlot({
    required this.date,
    required this.startTime,
    this.durationHours = 1,
  });
}

class MatchForm {
  final String? courtId;
  final String? playerAId;
  final String? playerBId;
  final List<MatchSlot> slots;

  const MatchForm({
    this.courtId,
    this.playerAId,
    this.playerBId,
    this.slots = const [],
  });

  /// Players are optional — an admin can block off a slot with no one
  /// attached to it. If both are set they must be different people.
  bool get isValid =>
      courtId != null &&
      slots.isNotEmpty &&
      (playerAId == null || playerBId == null || playerAId != playerBId);

  MatchForm copyWith({
    String? courtId,
    Object? playerAId = _sentinel,
    Object? playerBId = _sentinel,
    List<MatchSlot>? slots,
  }) {
    return MatchForm(
      courtId: courtId ?? this.courtId,
      playerAId: playerAId == _sentinel ? this.playerAId : playerAId as String?,
      playerBId: playerBId == _sentinel ? this.playerBId : playerBId as String?,
      slots: slots ?? this.slots,
    );
  }
}

class ManagerState {
  final List<CourtModel> courts;
  final List<UserModel> players;
  final List<UserModel> admins;
  final List<BookingModel> allBookings;
  final MatchForm form;
  final bool isLoading;
  final bool isSubmitting;
  final String? message;

  const ManagerState({
    this.courts = const [],
    this.players = const [],
    this.admins = const [],
    this.allBookings = const [],
    this.form = const MatchForm(),
    this.isLoading = false,
    this.isSubmitting = false,
    this.message,
  });

  List<BookingModel> get activeBookings {
    final active =
        allBookings.where((b) => b.status != BookingStatus.cancelled).toList()
          ..sort((a, b) {
            final cmp = a.date.compareTo(b.date);
            return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
          });
    return active;
  }

  ManagerState copyWith({
    List<CourtModel>? courts,
    List<UserModel>? players,
    List<UserModel>? admins,
    List<BookingModel>? allBookings,
    MatchForm? form,
    bool? isLoading,
    bool? isSubmitting,
    Object? message = _sentinel,
  }) {
    return ManagerState(
      courts: courts ?? this.courts,
      players: players ?? this.players,
      admins: admins ?? this.admins,
      allBookings: allBookings ?? this.allBookings,
      form: form ?? this.form,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      message: message == _sentinel ? this.message : message as String?,
    );
  }
}

const _sentinel = Object();

class ManagerViewModel extends StateNotifier<ManagerState> {
  ManagerViewModel(
    this._courtRepository,
    this._bookingRepository,
    List<UserModel> allUsers,
    this._currentUserId,
  ) : super(
          ManagerState(
            players: allUsers,
            admins: allUsers.where((u) => u.isAdmin).toList(),
            isLoading: true,
          ),
        ) {
    _courtsSubscription = _courtRepository.watchAll().listen((courts) {
      state = state.copyWith(courts: courts, isLoading: false);
    });
    _bookingsSubscription = _bookingRepository.watchAll().listen((bookings) {
      state = state.copyWith(allBookings: bookings);
    });
  }

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;
  final String? _currentUserId;
  late final StreamSubscription<List<CourtModel>> _courtsSubscription;
  late final StreamSubscription<List<BookingModel>> _bookingsSubscription;

  void setCourt(String courtId) {
    state = state.copyWith(form: state.form.copyWith(courtId: courtId));
  }

  void setPlayerA(String? userId) {
    state = state.copyWith(form: state.form.copyWith(playerAId: userId));
  }

  void setPlayerB(String? userId) {
    state = state.copyWith(form: state.form.copyWith(playerBId: userId));
  }

  void addSlot(MatchSlot slot) {
    state = state.copyWith(
      form: state.form.copyWith(slots: [...state.form.slots, slot]),
    );
  }

  void removeSlot(int index) {
    final slots = [...state.form.slots]..removeAt(index);
    state = state.copyWith(form: state.form.copyWith(slots: slots));
  }

  String _addHours(String startTime, int hours) {
    final parts = startTime.split(':');
    final h = int.parse(parts[0]) + hours;
    return '${h.toString().padLeft(2, '0')}:${parts[1]}';
  }

  /// Creates one booking per planned slot, all linking the same two
  /// players. Slots that fail (already booked, club mismatch) are skipped
  /// and reported — the rest still go through.
  Future<void> createMatch() async {
    final form = state.form;
    if (!form.isValid) return;

    state = state.copyWith(isSubmitting: true, message: null);

    final court = state.courts.firstWhere((c) => c.id == form.courtId);
    final playerA = form.playerAId == null
        ? null
        : state.players.where((u) => u.id == form.playerAId).firstOrNull;
    final playerB = form.playerBId == null
        ? null
        : state.players.where((u) => u.id == form.playerBId).firstOrNull;
    // No players picked at all → this just blocks the slot, booked under
    // the admin's own account.
    final bookerId = playerA?.id ?? _currentUserId;
    if (bookerId == null) return;

    var succeeded = 0;
    final failures = <String>[];

    for (final slot in form.slots) {
      final booking = BookingModel(
        id: '',
        courtId: court.id,
        courtName: court.name,
        userId: bookerId,
        partnerId: playerB?.id,
        partnerName: playerB?.name,
        date: slot.date,
        startTime: slot.startTime,
        endTime: _addHours(slot.startTime, slot.durationHours),
        status: BookingStatus.confirmed,
        price: court.pricePerHour * slot.durationHours,
        createdAt: DateTime.now(),
        isAdminBooking: true,
        courtAddress: court.location,
      );
      try {
        await _bookingRepository.create(booking);
        succeeded++;
      } catch (e) {
        failures.add('${slot.startTime} le ${slot.date.day}/${slot.date.month} : $e');
      }
    }

    // The provider can be rebuilt (e.g. `allUsersProvider` re-emitting)
    // while these awaits are in flight — writing to `state` after
    // `dispose()` ran throws, so bail out instead.
    if (!mounted) return;

    final summary = playerA == null
        ? 'Créneau(x) bloqué(s) sur ${court.name}.'
        : playerB == null
            ? '$succeeded créneau(x) programmé(s) pour ${playerA.name}.'
            : '$succeeded créneau(x) programmé(s) entre ${playerA.name} et ${playerB.name}.';

    state = state.copyWith(
      isSubmitting: false,
      form: succeeded == form.slots.length ? const MatchForm() : form,
      message: failures.isEmpty
          ? summary
          : '$succeeded réussi(s), ${failures.length} échec(s) :\n${failures.join('\n')}',
    );
  }

  Future<void> cancelBooking(String bookingId) {
    return _bookingRepository.cancel(bookingId);
  }

  void clearMessage() {
    state = state.copyWith(message: null);
  }

  @override
  void dispose() {
    _courtsSubscription.cancel();
    _bookingsSubscription.cancel();
    super.dispose();
  }
}

final managerViewModelProvider =
    StateNotifierProvider<ManagerViewModel, ManagerState>(
  (ref) => ManagerViewModel(
    ref.watch(courtRepositoryProvider),
    ref.watch(bookingRepositoryProvider),
    ref.watch(allUsersProvider).valueOrNull ?? const [],
    ref.watch(currentUserProvider).valueOrNull?.id,
  ),
);
