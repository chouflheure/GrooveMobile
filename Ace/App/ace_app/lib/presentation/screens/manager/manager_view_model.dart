import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/booking_scenario_repository.dart';
import '../../../data/repositories/club_contact_repository.dart';
import '../../../data/repositories/club_event_repository.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/court_repository.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../auth/auth_view_model.dart';
import '../courts/club_event_providers.dart';
import '../courts/courts_view_model.dart';
import '../courts/tournament_providers.dart';

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
  // Set only when this form is scheduling a tournament match (see
  // `ManagerViewModel.startTournamentMatchForm`) — `MatchFormScreen` reads
  // this to lock the player fields, restrict to a single slot, and
  // `createMatch` reads it to write the result back onto the bracket.
  final TournamentModel? tournament;
  final TournamentMatch? tournamentMatch;

  const MatchForm({
    this.courtId,
    this.playerAId,
    this.playerBId,
    this.title,
    this.slots = const [],
    this.tournament,
    this.tournamentMatch,
  });

  /// Players are optional — an admin can block off a slot with no one
  /// attached to it. If both are set they must be different people. A
  /// tournament match is always exactly one court/date/time, not a series,
  /// so it needs exactly one slot rather than just "at least one".
  bool get isValid =>
      courtId != null &&
      (tournamentMatch != null ? slots.length == 1 : slots.isNotEmpty) &&
      (playerAId == null || playerBId == null || playerAId != playerBId);

  MatchForm copyWith({
    String? courtId,
    Object? playerAId = _sentinel,
    Object? playerBId = _sentinel,
    Object? title = _sentinel,
    List<MatchSlot>? slots,
    Object? tournament = _sentinel,
    Object? tournamentMatch = _sentinel,
  }) {
    return MatchForm(
      courtId: courtId ?? this.courtId,
      playerAId: playerAId == _sentinel ? this.playerAId : playerAId as String?,
      playerBId: playerBId == _sentinel ? this.playerBId : playerBId as String?,
      title: title == _sentinel ? this.title : title as String?,
      slots: slots ?? this.slots,
      tournament: tournament == _sentinel
          ? this.tournament
          : tournament as TournamentModel?,
      tournamentMatch: tournamentMatch == _sentinel
          ? this.tournamentMatch
          : tournamentMatch as TournamentMatch?,
    );
  }
}

class ManagerState {
  final List<CourtModel> courts;
  final List<ClubModel> clubs;
  final List<BookingScenario> scenarios;
  final List<TournamentModel> tournaments;
  final List<UserModel> players;
  final List<UserModel> admins;
  final List<BookingModel> allBookings;
  final List<ClubEventModel> events;
  final List<ClubContactModel> clubContacts;
  final MatchForm form;
  final bool isLoading;
  final bool isSubmitting;
  final String? message;

  const ManagerState({
    this.courts = const [],
    this.clubs = const [],
    this.scenarios = const [],
    this.tournaments = const [],
    this.players = const [],
    this.admins = const [],
    this.allBookings = const [],
    this.events = const [],
    this.clubContacts = const [],
    this.form = const MatchForm(),
    this.isLoading = false,
    this.isSubmitting = false,
    this.message,
  });

  List<BookingModel> get activeBookings {
    final active = allBookings.where((b) => b.isUpcoming).toList()
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
      });
    return active;
  }

  ManagerState copyWith({
    List<CourtModel>? courts,
    List<ClubModel>? clubs,
    List<BookingScenario>? scenarios,
    List<TournamentModel>? tournaments,
    List<UserModel>? players,
    List<UserModel>? admins,
    List<BookingModel>? allBookings,
    List<ClubEventModel>? events,
    List<ClubContactModel>? clubContacts,
    MatchForm? form,
    bool? isLoading,
    bool? isSubmitting,
    Object? message = _sentinel,
  }) {
    return ManagerState(
      courts: courts ?? this.courts,
      clubs: clubs ?? this.clubs,
      scenarios: scenarios ?? this.scenarios,
      tournaments: tournaments ?? this.tournaments,
      players: players ?? this.players,
      admins: admins ?? this.admins,
      allBookings: allBookings ?? this.allBookings,
      events: events ?? this.events,
      clubContacts: clubContacts ?? this.clubContacts,
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
    this._scenarioRepository,
    this._tournamentRepository,
    this._clubContactRepository,
    List<UserModel> allUsers,
    this._currentUserId,
    this._adminClubIds,
  ) : super(
        ManagerState(
          // An admin only sees/organizes for members of their own
          // club(s) — same rule applied to booking partners.
          players: allUsers
              .where((u) => u.clubIds.any(_adminClubIds.contains))
              .toList(),
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
    _scenariosSubscription = _scenarioRepository.watchAll().listen((
      scenarios,
    ) {
      state = state.copyWith(
        scenarios: scenarios
            .where((s) => _adminClubIds.contains(s.clubId))
            .toList(),
      );
    });
    _tournamentsSubscription = _tournamentRepository.watchAll().listen((
      tournaments,
    ) {
      state = state.copyWith(
        tournaments: tournaments
            .where((t) => _adminClubIds.contains(t.clubId))
            .toList(),
      );
    });
    _clubContactsSubscription = _clubContactRepository.watchAll().listen((
      contacts,
    ) {
      state = state.copyWith(
        clubContacts: contacts
            .where((c) => _adminClubIds.contains(c.clubId))
            .toList(),
      );
    });
  }

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;
  final ClubRepository _clubRepository;
  final ClubEventRepository _clubEventRepository;
  final BookingScenarioRepository _scenarioRepository;
  final TournamentRepository _tournamentRepository;
  final ClubContactRepository _clubContactRepository;
  final String? _currentUserId;
  // An admin only administers the club(s) they're a member of.
  final List<String> _adminClubIds;
  late final StreamSubscription<List<CourtModel>> _courtsSubscription;
  late final StreamSubscription<List<BookingModel>> _bookingsSubscription;
  late final StreamSubscription<List<ClubModel>> _clubsSubscription;
  late final StreamSubscription<List<ClubEventModel>> _eventsSubscription;
  late final StreamSubscription<List<BookingScenario>> _scenariosSubscription;
  late final StreamSubscription<List<TournamentModel>> _tournamentsSubscription;
  late final StreamSubscription<List<ClubContactModel>> _clubContactsSubscription;

  List<CourtModel> _rawCourts = const [];
  List<BookingModel> _rawBookings = const [];

  void _recomputeScope() {
    final scopedCourts = _rawCourts
        .where((c) => _adminClubIds.contains(c.clubId))
        .toList();
    final scopedCourtIds = scopedCourts.map((c) => c.id).toSet();
    final scopedBookings = _rawBookings
        .where((b) => scopedCourtIds.contains(b.courtId))
        .toList();
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
      form: state.form.copyWith(
        title: title == null || title.isEmpty ? null : title,
      ),
    );
  }

  void addSlot(MatchSlot slot) {
    state = state.copyWith(
      form: state.form.copyWith(slots: [...state.form.slots, slot]),
    );
  }

  /// Replaces the whole slot list with just `slot` — used in tournament
  /// mode, where a match is always exactly one court/date/time rather than
  /// a series to accumulate (see `MatchForm.isValid`).
  void setSingleSlot(MatchSlot slot) {
    state = state.copyWith(form: state.form.copyWith(slots: [slot]));
  }

  /// Loads the shared match form with a tournament match's context —
  /// `MatchFormScreen` reads `form.tournamentMatch` to lock the player
  /// fields and restrict scheduling to a single slot, and `createMatch`
  /// reads it afterward to write the result back onto the bracket. Called
  /// by `TournamentManageScreen` right before pushing that screen.
  void startTournamentMatchForm(TournamentModel tournament, TournamentMatch match) {
    state = state.copyWith(
      form: MatchForm(
        courtId: match.courtId,
        playerAId: match.playerAId,
        playerBId: match.playerBId,
        title: '${tournament.title} — Tour ${match.round}',
        slots: match.isScheduled
            ? [MatchSlot(date: match.date!, startTime: match.startTime!)]
            : const [],
        tournament: tournament,
        tournamentMatch: match,
      ),
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
    BookingModel? createdBooking;

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
        createdBooking = booking;
      } catch (e) {
        failures.add(
          '${slot.startTime} le ${slot.date.day}/${slot.date.month} : $e',
        );
      }
    }

    // Scheduling a tournament match — exactly one slot in this mode (see
    // `MatchForm.isValid`), so a lone success is *the* result. Write it back
    // onto the bracket, then cancel whatever booking it's replacing (if
    // any) only now that the new one is confirmed to exist — cancelling
    // first, like the old dedicated flow did, would leave the match with no
    // booking at all if the create above had failed.
    final tournament = form.tournament;
    final tournamentMatch = form.tournamentMatch;
    if (tournament != null && tournamentMatch != null && createdBooking != null) {
      if (tournamentMatch.bookingId != null) {
        try {
          await _bookingRepository.cancel(tournamentMatch.bookingId!);
        } catch (_) {
          // Best effort — the new booking already exists either way.
        }
      }
      await _tournamentRepository.scheduleMatch(
        tournament,
        tournamentMatch,
        courtId: court.id,
        courtName: court.name,
        date: createdBooking.date,
        startTime: createdBooking.startTime,
        bookingId: createdBooking.slotKey,
      );
    }

    // The provider can be rebuilt (e.g. `allUsersProvider` re-emitting)
    // while these awaits are in flight — writing to `state` after
    // `dispose()` ran throws, so bail out instead.
    if (!mounted) return;

    final summary = tournamentMatch != null
        ? 'Match programmé sur ${court.name}.'
        : playerA == null
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

  Future<void> cancelBookings(List<String> bookingIds) async {
    for (final id in bookingIds) {
      await _bookingRepository.cancel(id);
    }
  }

  /// Creates or updates a court — `isNew` decides which, since `court.id`
  /// is now always pre-generated (needed up front for its Storage image
  /// path) rather than empty until the first save.
  Future<bool> saveCourt(CourtModel court, {required bool isNew}) async {
    try {
      if (isNew) {
        await _courtRepository.create(court);
        if (mounted) state = state.copyWith(message: '${court.name} ajouté.');
      } else {
        await _courtRepository.update(court);
        if (mounted) {
          state = state.copyWith(message: '${court.name} mis à jour.');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          message: 'Erreur lors de l\'enregistrement : $e',
        );
      }
      return false;
    }
  }

  /// Updates a club (name/location/image) — clubs are pre-seeded, never
  /// created through the app.
  Future<bool> saveClub(ClubModel club) async {
    try {
      await _clubRepository.update(club);
      if (mounted) state = state.copyWith(message: '${club.name} mis à jour.');
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          message: 'Erreur lors de l\'enregistrement : $e',
        );
      }
      return false;
    }
  }

  Future<bool> deleteCourt(String courtId, String name) async {
    try {
      await _courtRepository.delete(courtId);
      if (mounted) state = state.copyWith(message: '$name supprimé.');
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la suppression : $e');
      }
      return false;
    }
  }

  /// Creates or updates a booking scenario — `isNew` decides which, since
  /// `scenario.id` is always pre-generated by the caller (same convention
  /// as `saveCourt`).
  Future<bool> saveScenario(BookingScenario scenario, {required bool isNew}) async {
    try {
      if (isNew) {
        await _scenarioRepository.create(scenario);
        if (mounted) {
          state = state.copyWith(message: '${scenario.name} ajouté.');
        }
      } else {
        await _scenarioRepository.update(scenario);
        if (mounted) {
          state = state.copyWith(message: '${scenario.name} mis à jour.');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          message: 'Erreur lors de l\'enregistrement : $e',
        );
      }
      return false;
    }
  }

  Future<bool> deleteScenario(String scenarioId, String name) async {
    try {
      await _scenarioRepository.delete(scenarioId);
      if (mounted) state = state.copyWith(message: '$name supprimé.');
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la suppression : $e');
      }
      return false;
    }
  }

  /// Creates or updates a tournament's own info (title/club/description) —
  /// `isNew` decides which. Participants, the bracket and match scheduling
  /// are all separate actions below, once the tournament itself exists.
  Future<bool> saveTournament(
    TournamentModel tournament, {
    required bool isNew,
  }) async {
    try {
      if (isNew) {
        await _tournamentRepository.create(tournament);
        if (mounted) {
          state = state.copyWith(message: '${tournament.title} créé.');
        }
      } else {
        await _tournamentRepository.update(tournament);
        if (mounted) {
          state = state.copyWith(message: '${tournament.title} mis à jour.');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          message: 'Erreur lors de l\'enregistrement : $e',
        );
      }
      return false;
    }
  }

  /// Deletes the tournament and cancels every court slot it had scheduled
  /// (any match with a `bookingId` — see `scheduleTournamentMatch`), so a
  /// removed tournament doesn't leave its matches sitting on the courts'
  /// calendars as phantom bookings.
  Future<bool> deleteTournament(TournamentModel tournament) async {
    try {
      final bookingIds = tournament.matches
          .map((m) => m.bookingId)
          .whereType<String>()
          .toSet();
      await Future.wait(
        bookingIds.map((id) => _bookingRepository.cancel(id)),
      );
      await _tournamentRepository.delete(tournament.id);
      if (mounted) {
        state = state.copyWith(message: '${tournament.title} supprimé.');
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la suppression : $e');
      }
      return false;
    }
  }

  /// Admin-side add/remove — separate from the player-facing self-service
  /// toggle (`TournamentRepository.setParticipating`, called directly from
  /// `TournamentDetailScreen`), both just flip the same `participantIds`.
  Future<void> setTournamentParticipant(
    TournamentModel tournament,
    String userId,
    bool participating,
  ) {
    return _tournamentRepository.setParticipating(
      tournament.id,
      userId,
      participating,
    );
  }

  /// Composes and appends the next round (1 if none exists yet) — `pairs`
  /// from the admin's manual composer or a client-side random shuffle,
  /// `byePlayers` whoever's left over. See
  /// `TournamentRepository.composeRound`.
  Future<bool> composeTournamentRound(
    TournamentModel tournament,
    List<(String, String)> pairs,
    List<String> byePlayers,
  ) async {
    try {
      await _tournamentRepository.composeRound(tournament, pairs, byePlayers);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la composition du tour : $e');
      }
      return false;
    }
  }

  Future<bool> setTournamentMatchWinner(
    TournamentModel tournament,
    TournamentMatch match,
    String winnerId, {
    String? score,
  }) async {
    try {
      await _tournamentRepository.setMatchWinner(
        tournament,
        match,
        winnerId,
        score: score,
      );
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur : $e');
      }
      return false;
    }
  }

  /// Swaps two players in the drawn bracket — only meaningful, and only
  /// offered by the UI, before any match has a winner (see
  /// `TournamentManageScreen`).
  Future<bool> swapTournamentPlayers(
    TournamentModel tournament,
    String playerAId,
    String playerBId,
  ) async {
    try {
      await _tournamentRepository.swapPlayers(tournament, playerAId, playerBId);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur : $e');
      }
      return false;
    }
  }

  /// Creates a club event on behalf of the current admin. When the event has
  /// a start/end time and courts were selected, also books every hourly
  /// slot in that range on each of those courts so they show as occupied.
  Future<bool> createEvent(
    ClubEventModel event, {
    List<CourtModel> reserveCourts = const [],
  }) async {
    try {
      await _clubEventRepository.create(event);
      String message = '${event.title} créé.';
      if (reserveCourts.isNotEmpty &&
          event.startTime.isNotEmpty &&
          event.endTime.isNotEmpty) {
        final failures = await _reserveSlots(
          courts: reserveCourts,
          date: event.date,
          startTime: event.startTime,
          endTime: event.endTime,
          title: event.title,
        );
        if (failures.isNotEmpty) {
          message =
              '${event.title} créé, mais ${failures.length} créneau(x) '
              "n'ont pas pu être réservé(s) (déjà pris).";
        }
      }
      if (mounted) state = state.copyWith(message: message);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la création : $e');
      }
      return false;
    }
  }

  /// Books one hour-long slot per court, per hour between [startTime]
  /// (inclusive) and [endTime] (exclusive) — same 1h-slot model as
  /// `createMatch`. Returns the slots that failed (already booked, etc).
  Future<List<String>> _reserveSlots({
    required List<CourtModel> courts,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String title,
  }) async {
    final bookerId = _currentUserId;
    if (bookerId == null) return const [];
    final allTimes = [...AppConstants.timeSlots, '24:00'];
    final startIdx = allTimes.indexOf(startTime);
    final endIdx = allTimes.indexOf(endTime);
    if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) return const [];
    final hourlySlots = allTimes.sublist(startIdx, endIdx);

    final failures = <String>[];
    for (final court in courts) {
      for (final slot in hourlySlots) {
        // The event is taking over this court/time — cancel whichever
        // booking already held it (this also fires the "créneau annulé"
        // push notification to whoever had it) so the event's block can
        // claim the same slot instead of failing with "already booked".
        final existing = state.allBookings
            .where(
              (b) =>
                  b.courtId == court.id &&
                  b.startTime == slot &&
                  b.status != BookingStatus.cancelled &&
                  b.date.year == date.year &&
                  b.date.month == date.month &&
                  b.date.day == date.day,
            )
            .firstOrNull;
        if (existing != null) {
          try {
            await _bookingRepository.cancel(existing.id);
          } catch (_) {
            // Fall through — the create below reports the failure if the
            // slot is somehow still taken.
          }
        }

        final booking = BookingModel(
          id: '',
          courtId: court.id,
          courtName: court.name,
          userId: bookerId,
          date: date,
          startTime: slot,
          endTime: _addHours(slot, 1),
          status: BookingStatus.confirmed,
          price: court.pricePerHour,
          createdAt: DateTime.now(),
          isAdminBooking: true,
          courtAddress: court.location,
          title: title,
          isEventBlock: true,
        );
        try {
          await _bookingRepository.create(booking);
        } catch (e) {
          failures.add('${court.name} $slot');
        }
      }
    }
    return failures;
  }

  /// Updates a club event on behalf of the current admin.
  Future<bool> updateEvent(ClubEventModel event) async {
    try {
      await _clubEventRepository.update(event);
      if (mounted) {
        state = state.copyWith(message: '${event.title} mis à jour.');
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la mise à jour : $e');
      }
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId, String title) async {
    try {
      await _clubEventRepository.delete(eventId);
      if (mounted) state = state.copyWith(message: '$title supprimé.');
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(message: 'Erreur lors de la suppression : $e');
      }
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(message: null);
  }

  /// Surfaces `userId` as a club contact with a free-text status label
  /// (e.g. "Trésorier") on players' profiles, even though they're not an
  /// app admin — see `ClubContactRepository`.
  Future<bool> addClubContact(String clubId, String userId, String roleLabel) async {
    try {
      await _clubContactRepository.create(
        ClubContactModel(
          id: '',
          clubId: clubId,
          userId: userId,
          roleLabel: roleLabel,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(message: 'Erreur : $e');
      return false;
    }
  }

  Future<bool> removeClubContact(String contactId) async {
    try {
      await _clubContactRepository.delete(contactId);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(message: 'Erreur : $e');
      return false;
    }
  }

  @override
  void dispose() {
    _courtsSubscription.cancel();
    _bookingsSubscription.cancel();
    _clubsSubscription.cancel();
    _eventsSubscription.cancel();
    _scenariosSubscription.cancel();
    _tournamentsSubscription.cancel();
    _clubContactsSubscription.cancel();
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
        ref.watch(scenarioRepositoryProvider),
        ref.watch(tournamentRepositoryProvider),
        ref.watch(clubContactRepositoryProvider),
        ref.watch(allUsersProvider).valueOrNull ?? const [],
        ref.watch(currentUserProvider).valueOrNull?.id,
        ref.watch(currentUserProvider).valueOrNull?.clubIds ?? const [],
      ),
    );
