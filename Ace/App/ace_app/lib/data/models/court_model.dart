import 'package:equatable/equatable.dart';

enum CourtType { indoor, outdoor }

enum CourtSurface { clay, hard, grass }

extension CourtTypeJson on CourtType {
  String get jsonValue => name;

  static CourtType fromJson(String value) =>
      CourtType.values.firstWhere((t) => t.name == value);
}

extension CourtSurfaceJson on CourtSurface {
  String get jsonValue => name;

  static CourtSurface fromJson(String value) =>
      CourtSurface.values.firstWhere((s) => s.name == value);
}

extension CourtTypeLabel on CourtType {
  String get label => this == CourtType.indoor ? 'Intérieur' : 'Extérieur';
}

extension CourtSurfaceLabel on CourtSurface {
  String get label {
    switch (this) {
      case CourtSurface.clay:
        return 'Terre battue';
      case CourtSurface.hard:
        return 'Dur (résine)';
      case CourtSurface.grass:
        return 'Gazon';
    }
  }
}

class TimeSlot extends Equatable {
  final String time;
  final bool isAvailable;

  const TimeSlot({required this.time, required this.isAvailable});

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    time: json['time'] as String,
    isAvailable: json['isAvailable'] as bool,
  );

  Map<String, dynamic> toJson() => {'time': time, 'isAvailable': isAvailable};

  @override
  List<Object?> get props => [time, isAvailable];
}

/// A date range during which a court is entirely closed (maintenance,
/// private event, etc.) — independent of the day's hourly `availableSlots`
/// template, and checked against on every booking attempt.
class UnavailablePeriod extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  const UnavailablePeriod({
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  bool covers(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  factory UnavailablePeriod.fromJson(Map<String, dynamic> json) =>
      UnavailablePeriod(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        reason: json['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'reason': reason,
  };

  @override
  List<Object?> get props => [startDate, endDate, reason];
}

/// A date range during which a court only opens for part of its normal
/// hours (e.g. "du 15 au 20 juin, seulement 14h-18h") — a subset of the
/// court's usual `availableSlots`, never an expansion beyond it.
class AvailabilityOverride extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final String openFrom;
  final String openTo;
  final String? note;

  const AvailabilityOverride({
    required this.startDate,
    required this.endDate,
    required this.openFrom,
    required this.openTo,
    this.note,
  });

  bool covers(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  // Zero-padded HH:mm strings compare correctly lexicographically.
  bool allowsTime(String time) =>
      time.compareTo(openFrom) >= 0 && time.compareTo(openTo) < 0;

  factory AvailabilityOverride.fromJson(Map<String, dynamic> json) =>
      AvailabilityOverride(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        openFrom: json['openFrom'] as String,
        openTo: json['openTo'] as String,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'openFrom': openFrom,
    'openTo': openTo,
    'note': note,
  };

  @override
  List<Object?> get props => [startDate, endDate, openFrom, openTo, note];
}

class CourtModel extends Equatable {
  final String id;
  final String name;
  final CourtType type;
  final CourtSurface surface;
  final String location;
  final double pricePerHour;
  final double rating;
  final String imageUrl;
  final String description;
  final List<String> amenities;
  final List<TimeSlot> availableSlots;
  final String clubId;
  final List<UnavailablePeriod> unavailablePeriods;
  final List<AvailabilityOverride> availabilityOverrides;

  const CourtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.surface,
    required this.location,
    required this.pricePerHour,
    required this.rating,
    required this.imageUrl,
    required this.description,
    required this.amenities,
    required this.availableSlots,
    required this.clubId,
    this.unavailablePeriods = const [],
    this.availabilityOverrides = const [],
  });

  List<TimeSlot> get freeSlots =>
      availableSlots.where((s) => s.isAvailable).toList();

  bool isClosedOn(DateTime date) =>
      unavailablePeriods.any((p) => p.covers(date));

  /// The hourly template for a given date — narrowed by whichever
  /// [AvailabilityOverride] covers that date, or the court's normal
  /// [availableSlots] otherwise.
  List<TimeSlot> baseSlotsFor(DateTime date) {
    final override = availabilityOverrides
        .where((o) => o.covers(date))
        .firstOrNull;
    if (override == null) return availableSlots;
    return availableSlots
        .map(
          (s) =>
              TimeSlot(time: s.time, isAvailable: override.allowsTime(s.time)),
        )
        .toList();
  }

  factory CourtModel.fromJson(Map<String, dynamic> json) => CourtModel(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CourtTypeJson.fromJson(json['type'] as String),
    surface: CourtSurfaceJson.fromJson(json['surface'] as String),
    location: json['location'] as String,
    pricePerHour: (json['pricePerHour'] as num).toDouble(),
    rating: (json['rating'] as num).toDouble(),
    imageUrl: json['imageUrl'] as String,
    description: json['description'] as String,
    amenities: List<String>.from(json['amenities'] as List),
    availableSlots: (json['availableSlots'] as List)
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList(),
    clubId: json['clubId'] as String? ?? '',
    unavailablePeriods: json['unavailablePeriods'] != null
        ? (json['unavailablePeriods'] as List)
              .map((p) => UnavailablePeriod.fromJson(p as Map<String, dynamic>))
              .toList()
        : const [],
    availabilityOverrides: json['availabilityOverrides'] != null
        ? (json['availabilityOverrides'] as List)
              .map(
                (p) => AvailabilityOverride.fromJson(p as Map<String, dynamic>),
              )
              .toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.jsonValue,
    'surface': surface.jsonValue,
    'location': location,
    'pricePerHour': pricePerHour,
    'rating': rating,
    'imageUrl': imageUrl,
    'description': description,
    'amenities': amenities,
    'availableSlots': availableSlots.map((s) => s.toJson()).toList(),
    'clubId': clubId,
    'unavailablePeriods': unavailablePeriods.map((p) => p.toJson()).toList(),
    'availabilityOverrides': availabilityOverrides
        .map((p) => p.toJson())
        .toList(),
  };

  @override
  List<Object?> get props => [id, name, type, surface, clubId];
}
