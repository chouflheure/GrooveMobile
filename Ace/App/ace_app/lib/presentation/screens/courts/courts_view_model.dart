import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/court_repository.dart';

class CourtsState {
  final List<CourtModel> courts;
  final String searchQuery;
  final String selectedFilter;
  final bool isLoading;

  const CourtsState({
    this.courts = const [],
    this.searchQuery = '',
    this.selectedFilter = 'Tous',
    this.isLoading = false,
  });

  CourtsState copyWith({
    List<CourtModel>? courts,
    String? searchQuery,
    String? selectedFilter,
    bool? isLoading,
  }) {
    return CourtsState(
      courts: courts ?? this.courts,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<CourtModel> get filteredCourts {
    var result = courts;

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

class CourtsViewModel extends StateNotifier<CourtsState> {
  CourtsViewModel(this._courtRepository, this._bookingRepository)
      : super(const CourtsState()) {
    state = state.copyWith(isLoading: true);
    _courtsSubscription = _courtRepository.watchAll().listen((courts) {
      _rawCourts = courts;
      _recompute();
    });
    _bookingsSubscription = _bookingRepository
        .watchBookedSlotsForDate(AppConstants.defaultBookingDate())
        .listen((bookedSlots) {
      _bookedSlots = bookedSlots;
      _recompute();
    });
  }

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;
  late final StreamSubscription<List<CourtModel>> _courtsSubscription;
  late final StreamSubscription<Map<String, Set<String>>>
      _bookingsSubscription;

  List<CourtModel> _rawCourts = const [];
  Map<String, Set<String>> _bookedSlots = const {};

  void _recompute() {
    final courts = _rawCourts.map((court) {
      final booked = _bookedSlots[court.id];
      if (booked == null || booked.isEmpty) return court;
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
        availableSlots: court.availableSlots
            .map((s) => booked.contains(s.time)
                ? TimeSlot(time: s.time, isAvailable: false)
                : s)
            .toList(),
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

  @override
  void dispose() {
    _courtsSubscription.cancel();
    _bookingsSubscription.cancel();
    super.dispose();
  }
}

final courtRepositoryProvider = Provider<CourtRepository>(
  (_) => CourtRepository(),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (_) => BookingRepository(),
);

final courtsViewModelProvider =
    StateNotifierProvider<CourtsViewModel, CourtsState>(
  (ref) => CourtsViewModel(
    ref.watch(courtRepositoryProvider),
    ref.watch(bookingRepositoryProvider),
  ),
);
