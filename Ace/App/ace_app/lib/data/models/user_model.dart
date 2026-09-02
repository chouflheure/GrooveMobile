import 'package:equatable/equatable.dart';

enum UserRole { player, admin }

class UserStats extends Equatable {
  final int matchesPlayed;
  final int wins;
  final int hoursPlayed;

  const UserStats({
    required this.matchesPlayed,
    required this.wins,
    required this.hoursPlayed,
  });

  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;

  @override
  List<Object?> get props => [matchesPlayed, wins, hoursPlayed];
}

class SurfacePreferences extends Equatable {
  final double clay;
  final double hard;
  final double grass;

  const SurfacePreferences({
    required this.clay,
    required this.hard,
    required this.grass,
  });

  @override
  List<Object?> get props => [clay, hard, grass];
}

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final String ranking;
  final String location;
  final double rating;
  final DateTime memberSince;
  final int matchesPerMonth;
  final UserStats stats;
  final SurfacePreferences surfaces;
  final UserRole role;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profileImageUrl,
    required this.ranking,
    required this.location,
    required this.rating,
    required this.memberSince,
    required this.matchesPerMonth,
    required this.stats,
    required this.surfaces,
    this.role = UserRole.player,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  bool get isAdmin => role == UserRole.admin;

  @override
  List<Object?> get props => [id, name, email, ranking, role];
}
