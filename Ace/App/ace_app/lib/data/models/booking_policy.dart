import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// How a court's `maxSlotsPerWeek` cap resets.
enum WeekPeriod {
  /// Resets every Monday, regardless of when in the week a slot falls.
  calendar,

  /// A continuously sliding 7-day lookback from the slot's own date.
  rolling;

  String get jsonValue => name;

  static WeekPeriod fromJson(String? value) => WeekPeriod.values.firstWhere(
    (p) => p.jsonValue == value,
    orElse: () => WeekPeriod.calendar,
  );
}

/// Per-court booking rules — how far ahead it can be booked, whether the
/// peak/off-peak distinction applies, and how many slots a player can hold
/// at once. Every field has a default matching the app's original
/// hard-coded behavior, so a court document saved before this feature
/// existed still works unchanged.
class BookingPolicy extends Equatable {
  /// How many days ahead the court is shown/bookable — was the global
  /// `AppConstants.bookingCalendarDays` constant.
  final int bookingWindowDays;

  /// Whether the "heure creuse/pleine" distinction applies to this court at
  /// all — when false, every slot is treated as off-peak regardless of
  /// `CourtModel.peakHours`.
  final bool peakHoursEnabled;

  /// Max outstanding ("in progress or upcoming") peak-hour slots a player
  /// can hold at once — null means unlimited. Ignored if
  /// [peakHoursEnabled] is false.
  final int? peakHourLimit;

  /// Max outstanding off-peak-hour slots a player can hold at once — null
  /// means unlimited.
  final int? offPeakHourLimit;

  /// Max slots a player can book on this court on a single calendar day —
  /// null means unlimited.
  final int? maxSlotsPerDay;

  /// Max slots a player can book on this court within one [weekPeriod] —
  /// null means unlimited.
  final int? maxSlotsPerWeek;

  /// Which week definition [maxSlotsPerWeek] counts against. Meaningless
  /// when [maxSlotsPerWeek] is null.
  final WeekPeriod weekPeriod;

  const BookingPolicy({
    this.bookingWindowDays = AppConstants.bookingCalendarDays,
    this.peakHoursEnabled = true,
    this.peakHourLimit = 1,
    this.offPeakHourLimit = 2,
    this.maxSlotsPerDay,
    this.maxSlotsPerWeek,
    this.weekPeriod = WeekPeriod.calendar,
  });

  factory BookingPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BookingPolicy();
    return BookingPolicy(
      bookingWindowDays:
          json['bookingWindowDays'] as int? ?? AppConstants.bookingCalendarDays,
      peakHoursEnabled: json['peakHoursEnabled'] as bool? ?? true,
      peakHourLimit: json['peakHourLimit'] as int? ?? 1,
      offPeakHourLimit: json['offPeakHourLimit'] as int? ?? 2,
      maxSlotsPerDay: json['maxSlotsPerDay'] as int?,
      maxSlotsPerWeek: json['maxSlotsPerWeek'] as int?,
      weekPeriod: WeekPeriod.fromJson(json['weekPeriod'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingWindowDays': bookingWindowDays,
    'peakHoursEnabled': peakHoursEnabled,
    'peakHourLimit': peakHourLimit,
    'offPeakHourLimit': offPeakHourLimit,
    'maxSlotsPerDay': maxSlotsPerDay,
    'maxSlotsPerWeek': maxSlotsPerWeek,
    'weekPeriod': weekPeriod.jsonValue,
  };

  BookingPolicy copyWith({
    int? bookingWindowDays,
    bool? peakHoursEnabled,
    int? Function()? peakHourLimit,
    int? Function()? offPeakHourLimit,
    int? Function()? maxSlotsPerDay,
    int? Function()? maxSlotsPerWeek,
    WeekPeriod? weekPeriod,
  }) => BookingPolicy(
    bookingWindowDays: bookingWindowDays ?? this.bookingWindowDays,
    peakHoursEnabled: peakHoursEnabled ?? this.peakHoursEnabled,
    peakHourLimit: peakHourLimit != null ? peakHourLimit() : this.peakHourLimit,
    offPeakHourLimit: offPeakHourLimit != null
        ? offPeakHourLimit()
        : this.offPeakHourLimit,
    maxSlotsPerDay: maxSlotsPerDay != null ? maxSlotsPerDay() : this.maxSlotsPerDay,
    maxSlotsPerWeek: maxSlotsPerWeek != null
        ? maxSlotsPerWeek()
        : this.maxSlotsPerWeek,
    weekPeriod: weekPeriod ?? this.weekPeriod,
  );

  @override
  List<Object?> get props => [
    bookingWindowDays,
    peakHoursEnabled,
    peakHourLimit,
    offPeakHourLimit,
    maxSlotsPerDay,
    maxSlotsPerWeek,
    weekPeriod,
  ];
}
