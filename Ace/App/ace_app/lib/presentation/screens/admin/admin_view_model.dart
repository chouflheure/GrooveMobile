import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/court_repository.dart';
import '../courts/courts_view_model.dart';

class AdminBookingForm {
  final String? courtId;
  final DateTime? date;
  final String? startTime;
  final int durationHours;
  final List<String> invitedUserIds;

  const AdminBookingForm({
    this.courtId,
    this.date,
    this.startTime,
    this.durationHours = 1,
    this.invitedUserIds = const [],
  });

  bool get isValid =>
      courtId != null &&
      date != null &&
      startTime != null &&
      invitedUserIds.isNotEmpty;

  AdminBookingForm copyWith({
    String? courtId,
    DateTime? date,
    String? startTime,
    int? durationHours,
    List<String>? invitedUserIds,
  }) {
    return AdminBookingForm(
      courtId: courtId ?? this.courtId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      durationHours: durationHours ?? this.durationHours,
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
    );
  }
}

class AdminState {
  final List<CourtModel> courts;
  final List<UserModel> users;
  final List<BookingModel> allBookings;
  final AdminBookingForm form;
  final bool isLoading;
  final String? successMessage;

  const AdminState({
    this.courts = const [],
    this.users = const [],
    this.allBookings = const [],
    this.form = const AdminBookingForm(),
    this.isLoading = false,
    this.successMessage,
  });

  AdminState copyWith({
    List<CourtModel>? courts,
    List<UserModel>? users,
    List<BookingModel>? allBookings,
    AdminBookingForm? form,
    bool? isLoading,
    String? successMessage,
  }) {
    return AdminState(
      courts: courts ?? this.courts,
      users: users ?? this.users,
      allBookings: allBookings ?? this.allBookings,
      form: form ?? this.form,
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage,
    );
  }
}

class AdminViewModel extends StateNotifier<AdminState> {
  AdminViewModel(this._courtRepository) : super(const AdminState()) {
    _load();
  }

  final CourtRepository _courtRepository;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final courts = await _courtRepository.fetchAll();
    state = state.copyWith(
      courts: courts,
      users: MockData.allUsers.where((u) => !u.isAdmin).toList(),
      allBookings: MockData.bookings,
      isLoading: false,
    );
  }

  void setFormCourt(String courtId) {
    state = state.copyWith(form: state.form.copyWith(courtId: courtId));
  }

  void setFormDate(DateTime date) {
    state = state.copyWith(form: state.form.copyWith(date: date));
  }

  void setFormTime(String time) {
    state = state.copyWith(form: state.form.copyWith(startTime: time));
  }

  void setFormDuration(int hours) {
    state = state.copyWith(form: state.form.copyWith(durationHours: hours));
  }

  void toggleInvitedUser(String userId) {
    final ids = List<String>.from(state.form.invitedUserIds);
    if (ids.contains(userId)) {
      ids.remove(userId);
    } else {
      ids.add(userId);
    }
    state = state.copyWith(
      form: state.form.copyWith(invitedUserIds: ids),
    );
  }

  String _addHours(String startTime, int hours) {
    final parts = startTime.split(':');
    final h = int.parse(parts[0]) + hours;
    return '${h.toString().padLeft(2, '0')}:${parts[1]}';
  }

  Future<void> createBooking() async {
    if (!state.form.isValid) return;
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 600));

    final court = state.courts.firstWhere((c) => c.id == state.form.courtId);
    final endTime = _addHours(state.form.startTime!, state.form.durationHours);
    final price = court.pricePerHour * state.form.durationHours;

    final newBookings = state.form.invitedUserIds.map((userId) {
      final user = state.users.firstWhere((u) => u.id == userId);
      return BookingModel(
        id: 'admin_booking_${DateTime.now().millisecondsSinceEpoch}_$userId',
        courtId: state.form.courtId!,
        courtName: court.name,
        userId: userId,
        date: state.form.date!,
        startTime: state.form.startTime!,
        endTime: endTime,
        status: BookingStatus.confirmed,
        price: price,
        createdAt: DateTime.now(),
        isAdminBooking: true,
        partnerName: user.name,
      );
    }).toList();

    state = state.copyWith(
      allBookings: [...state.allBookings, ...newBookings],
      form: const AdminBookingForm(),
      isLoading: false,
      successMessage:
          '${newBookings.length} réservation(s) créée(s) avec succès !',
    );
  }

  void clearSuccess() {
    state = state.copyWith(successMessage: null);
  }
}

final adminViewModelProvider =
    StateNotifierProvider<AdminViewModel, AdminState>(
  (ref) => AdminViewModel(ref.watch(courtRepositoryProvider)),
);
