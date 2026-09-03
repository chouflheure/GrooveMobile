import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/club_event_repository.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/court_repository.dart';
import '../auth/auth_view_model.dart';
import '../courts/club_event_providers.dart';
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
  final String? title;
  final List<MatchSlot> slots;

  const MatchForm({
    this.courtId,
    this.playerAId,
    this.playerBId,
    this.title,
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
    Object? title = _sentinel,
    List<MatchSlot>? slots,
  }) {
    return MatchForm(
      courtId: courtId ?? this.courtId,
      playerAId: playerAId == _sentinel ? this.playerAId : playerAId as String?,
      playerBId: playerBId == _sentinel ? this.playerBId : playerBId as String?,
      title: title == _sentinel ? this.title : title as String?,
      slots: slots ?? this.slots,
    );
  }
}

class ManagerState {
  final List<CourtModel> courts;
  final List<ClubModel> clubs;
  final List<UserModel> players;
  final List<UserModel> admins;
  final List<BookingModel> allBookings;
  final List<ClubEventModel> events;
  final MatchForm form;
  final bool isLoading;
  final bool isSubmitting;
  final String? message;

  const ManagerState({
    this.courts = const [],
    this.clubs = const [],
    this.players = const [],
    this.admins = const [],
    this.allBookings = const [],
    this.events = const [],
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
    List<ClubModel>? clubs,
    List<UserModel>? players,
    List<UserModel>? admins,
    List<BookingModel>? allBookings,
    List<ClubEventModel>? events,
    MatchForm? form,
    bool? isLoading,
    bool? isSubmitting,
    Object? message = _sentinel,
  }) {
    return ManagerState(
      courts: courts ?? this.courts,
      clubs: clubs ?? this.clubs,
      players: players ?? this.players,
      admins: admins ?? this.admins,
      allBookings: allBookings ?? this.allBookings,
      events: events ?? this.events,
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
    this._clubRepository,
    this._clubEventRepository,
    List<UserModel> allUsers,
    this._currentUserId,
    this._adminClubIds,
  ) : super(
          ManagerState(
            players: allUsers,
            admins: allUsers.where((u) => u.isAdmin).toList(),
            isLoading: true,
          ),
        ) {
    _courtsSubscription = _courtRepository.watchAll().listen((courts) {
      _rawCourts = courts;
      _recomputeScope();
    });
    _bookingsSubscription = _bookingRepository.watchAll().listen((bookings) {
      _rawBookings = bookings;
      _recomputeScope();
    });
    _clubsSubscription = _clubRepository.watchAll().listen((clubs) {
      state = state.copyWith(
        clubs: clubs.where((c) => _adminClubIds.contains(c.id)).toList(),
      );
    });
    _eventsSubscription = _clubEventRepository.watchAll().listen((events) {
      state = state.copyWith(
        events: events.where((e) => _adminClubIds.contains(e.clubId)).toList(),
      );
    });
  }

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;
  final ClubRepository _clubRepository;
  final ClubEventRepository _clubEventRepository;
  final String? _currentUserId;
  // An admin only administers the club(s) they're a member of.
  final List<String> _adminClubIds;
  late final StreamSubscription<List<CourtModel>> _courtsSubscription;
  late final StreamSubscription<List<BookingModel>> _bookingsSubscription;
  late final StreamSubscription<List<ClubModel>> _clubsSubscription;
  late final StreamSubscription<List<ClubEventModel>> _eventsSubscription;

  List<CourtModel> _rawCourts = const [];
  List<BookingModel> _rawBookings = const [];

  void _recomputeScope() {
    final scopedCourts =
        _rawCourts.where((c) => _adminClubIds.contains(c.clubId)).toList();
    final scopedCourtIds = scopedCourts.map((c) => c.id).toSet();
    final scopedBookings =
        _rawBookings.where((b) => scopedCourtIds.contains(b.courtId)).toList();
    state = state.copyWith(
      courts: scopedCourts,
      allBookings: scopedBookings,
      isLoading: false,
    );
  }

  void setCourt(String courtId) {
    state = state.copyWith(form: state.form.copyWith(courtId: courtId));
  }

  void setPlayerA(String? userId) {
    state = state.copyWith(form: state.form.copyWith(playerAId: userId));
  }

  void setPlayerB(String? userId) {
    state = state.copyWith(form: state.form.copyWith(playerBId: userId));
  }

  void setTitle(String? title) {
    state = state.copyWith(
      form: state.form.copyWith(title: title == null || title.isEmpty ? null : title),
    );
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
        title: form.title,
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

  /// Creates a court when `court.id` is empty, otherwise updates it.
  Future<bool> saveCourt(CourtModel court) async {
    try {
      if (court.id.isEmpty) {
        await _courtRepository.create(court);
        if (mounted) state = state.copyWith(message: '${court.name} ajouté.');
      } else {
        await _courtRepository.update(court);
        if (mounted) state = state.copyWith(message: '${court.name} mis à jour.');
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de l\'enregistrement : $e');
      }
      return false;
    }
  }

  /// Creates a club event on behalf of the current admin.
  Future<bool> createEvent(ClubEventModel event) async {
    try {
      await _clubEventRepository.create(event);
      if (mounted) state = state.copyWith(message: '${event.title} créé.');
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la création : $e');
      }
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(message: null);
  }

  @override
  void dispose() {
    _courtsSubscription.cancel();
    _bookingsSubscription.cancel();
    _clubsSubscription.cancel();
    _eventsSubscription.cancel();
    super.dispose();
  }
}

final managerViewModelProvider =
    StateNotifierProvider<ManagerViewModel, ManagerState>(
  (ref) => ManagerViewModel(
    ref.watch(courtRepositoryProvider),
    ref.watch(bookingRepositoryProvider),
    ref.watch(clubRepositoryProvider),
    ref.watch(clubEventRepositoryProvider),
    ref.watch(allUsersProvider).valueOrNull ?? const [],
    ref.watch(currentUserProvider).valueOrNull?.id,
    ref.watch(currentUserProvider).valueOrNull?.clubIds ?? const [],
  ),
);
