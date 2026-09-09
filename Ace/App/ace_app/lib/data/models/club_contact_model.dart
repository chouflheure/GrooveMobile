import 'package:equatable/equatable.dart';

/// A non-admin (or admin) person the club's admin has chosen to surface in
/// "Contacts du club" on a player's profile — e.g. a treasurer or coach who
/// isn't an app admin but players should still be able to reach. `roleLabel`
/// is free text set by the admin (e.g. "Trésorier", "Coach").
class ClubContactModel extends Equatable {
  final String id;
  final String clubId;
  final String userId;
  final String roleLabel;
  final DateTime createdAt;

  const ClubContactModel({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.roleLabel,
    required this.createdAt,
  });

  factory ClubContactModel.fromJson(Map<String, dynamic> json) =>
      ClubContactModel(
        id: json['id'] as String,
        clubId: json['clubId'] as String,
        userId: json['userId'] as String,
        roleLabel: json['roleLabel'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'userId': userId,
    'roleLabel': roleLabel,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, clubId, userId, roleLabel];
}
