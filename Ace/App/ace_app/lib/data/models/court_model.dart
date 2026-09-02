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
  });

  List<TimeSlot> get freeSlots =>
      availableSlots.where((s) => s.isAvailable).toList();

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
      };

  @override
  List<Object?> get props => [id, name, type, surface];
}
