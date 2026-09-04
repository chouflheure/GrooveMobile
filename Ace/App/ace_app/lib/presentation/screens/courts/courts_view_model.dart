import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/court_repository.dart';
import '../auth/auth_view_model.dart';

class CourtsState {
  final List<CourtModel> courts;
  final List<ClubModel> clubs;
  final String searchQuery;
  final String selectedFilter;
  final String? selectedClubId;
  final bool isLoading;

  const CourtsState({
    this.courts = const [],
    this.clubs = const [],
    this.searchQuery = '',
    this.selectedFilter = 'Tous',
    this.selectedClubId,
    this.isLoading = false,
  });

  CourtsState copyWith({
    List<CourtModel>? courts,
    List<ClubModel>? clubs,
    String? searchQuery,
    String? selectedFilter,
    Object? selectedClubId = _sentinel,
    bool? isLoading,
  }) {
    return CourtsState(
      courts: courts ?? this.courts,
      clubs: clubs ?? this.clubs,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedClubId: selectedClubId == _sentinel
          ? this.selectedClubId
          : selectedClubId as String?,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<CourtModel> get filteredCourts {
    var result = courts;

    if (selectedClubId != null) {
      result = result.where((c) => c.clubId == selectedClubId).toList();
    }

    if (selectedFilter != 'Tous') {
      result = result.where((c) {
        switch (selectedFilter) {
          case 'Extérieur':
            return c.type == CourtType.outdoor;
          case 'Intérieur':
            return c.type == CourtType.indoor;
          case 'Terre battue':
            return c.surface == CourtSurface.clay;
          case 'Dur':
            return c.surface == CourtSurface.hard;
          case 'Gazon':
            return c.surface == CourtSurface.grass;
          default:
            return true;
        }
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.location.toLowerCase().contains(q) ||
                c.surface.label.toLowerCase().contains(q),
          )
          .toList();
    }

    return result;
  }
}

const _sentinel = Object();

class CourtsViewModel extends StateNotifier<CourtsState> {
  CourtsViewModel(
    this._courtRepository,
    this._bookingRepository,
    this._clubRepository,
    this._userClubIds,
  ) : super(const CourtsState()) {
    state = state.copyWith(isLoading: true);
    _courtsSubscription = _courtRepository.watchAll().listen((courts) {
      _rawCourts = courts;
      _recompute();
    });
    _bookingsSubscription = _bookingRepository
        .watchBookedSlotsForDate(AppConstants.today())
        .listen((bookedSlots) {
          _bookedSlots = bookedSlots;
          _recompute();
        });
    _clubsSubscription = _clubRepository.watchAll().listen((clubs) {
      if (_userClubIds == null) {
        // Guests only get a browsable preview, scoped to the single demo
        // club (doc id "MockClub") rather than every real club in the
        // database.
        _mockClubId = clubs.where((c) => c.id == 'MockClub').firstOrNull?.id;
        state = state.copyWith(
          clubs: clubs.where((c) => c.id == 'MockClub').toList(),
        );
        _recompute();
      } else {
        state = state.copyWith(
          clubs: clubs.where((c) => _userClubIds.contains(c.id)).toList(),
        );
      }
    });
  }

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;
  final ClubRepository _clubRepository;
  // Null for guests (scoped to the demo club only, see `_mockClubId`); a
  // signed-in player only ever sees courts belonging to a club they're a
  // member of.
  final List<String>? _userClubIds;
  String? _mockClubId;
  late final StreamSubscription<List<CourtModel>> _courtsSubscription;
  late final StreamSubscription<Map<String, Set<String>>> _bookingsSubscription;
  late final StreamSubscription<List<ClubModel>> _clubsSubscription;

  List<CourtModel> _rawCourts = const [];
  Map<String, Set<String>> _bookedSlots = const {};

  void _recompute() {
    final today = AppConstants.today();
    final scoped = _userClubIds == null
        ? _rawCourts.where((c) => c.clubId == _mockClubId).toList()
        : _rawCourts.where((c) => _userClubIds.contains(c.clubId)).toList();
    final courts = scoped.map((court) {
      final booked = _bookedSlots[court.id] ?? const <String>{};
      return CourtModel(
        id: court.id,
        name: court.name,
        type: court.type,
        surface: court.surface,
        location: court.location,
        pricePerHour: court.pricePerHour,
        rating: court.rating,
        imageUrl: court.imageUrl,
        description: court.description,
        amenities: court.amenities,
        availableSlots: court
            .baseSlotsFor(today)
            .map(
              (s) =>
                  court.isClosedOn(today) ||
                      booked.contains(s.time) ||
                      AppConstants.isSlotPast(today, s.time)
                  ? TimeSlot(time: s.time, isAvailable: false)
                  : s,
            )
            .toList(),
        clubId: court.clubId,
        unavailablePeriods: court.unavailablePeriods,
        availabilityOverrides: court.availabilityOverrides,
        peakHours: court.peakHours,
      );
    }).toList();
    state = state.copyWith(courts: courts, isLoading: false);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setClub(String? clubId) {
    state = state.copyWith(selectedClubId: clubId);
  }

  @override
  void dispose() {
    _courtsSubscription.cancel();
    _bookingsSubscription.cancel();
    _clubsSubscription.cancel();
    super.dispose();
  }
}

final courtRepositoryProvider = Provider<CourtRepository>(
  (_) => CourtRepository(),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (_) => BookingRepository(),
);

final clubRepositoryProvider = Provider<ClubRepository>(
  (_) => ClubRepository(),
);

final courtByIdProvider = StreamProvider.family<CourtModel?, String>(
  (ref, id) => ref.watch(courtRepositoryProvider).watchById(id),
);

final clubsProvider = StreamProvider<List<ClubModel>>(
  (ref) => ref.watch(clubRepositoryProvider).watchAll(),
);

/// Which start times are already booked for a given court + day — shared by
/// any screen that needs slot availability outside of `CourtsViewModel`
/// (e.g. the admin/manager booking tools, which pick an arbitrary date).
final bookedSlotsForCourtProvider =
    StreamProvider.family<Set<String>, ({String courtId, DateTime date})>(
      (ref, args) => ref
          .watch(bookingRepositoryProvider)
          .watchBookedSlotsForDate(args.date)
          .map((byCourtId) => byCourtId[args.courtId] ?? const <String>{}),
    );

final courtsViewModelProvider =
    StateNotifierProvider<CourtsViewModel, CourtsState>(
      (ref) => CourtsViewModel(
        ref.watch(courtRepositoryProvider),
        ref.watch(bookingRepositoryProvider),
        ref.watch(clubRepositoryProvider),
        ref.watch(currentUserProvider).valueOrNull?.clubIds,
      ),
    );
