import 'package:equatable/equatable.dart';
import 'booking_policy.dart';

/// A named, reusable `BookingPolicy` an admin defines once and assigns to
/// any number of courts in their club — courts hold only a reference
/// (`CourtModel.scenarioId`), so editing a scenario here instantly updates
/// every court using it.
class BookingScenario extends Equatable {
  final String id;
  final String clubId;
  final String name;
  final BookingPolicy policy;

  const BookingScenario({
    required this.id,
    required this.clubId,
    required this.name,
    this.policy = const BookingPolicy(),
  });

  factory BookingScenario.fromJson(Map<String, dynamic> json) =>
      BookingScenario(
        id: json['id'] as String,
        clubId: json['clubId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        policy: BookingPolicy.fromJson(json['policy'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'name': name,
    'policy': policy.toJson(),
  };

  @override
  List<Object?> get props => [id, clubId, name, policy];
}
