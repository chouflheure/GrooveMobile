import 'package:equatable/equatable.dart';

enum UserRole { player, admin }

/// Keys of [UserModel.notifications] — one on/off switch per notification
/// kind, keyed by its display title (see `notification_settings_screen.dart`).
const List<String> kNotificationKeys = [
  'Messages',
  'Demandes de jeu',
  'Rappel de créneau',
  'Nouveaux créneaux',
];

extension UserRoleJson on UserRole {
  String get jsonValue => name;

  static UserRole fromJson(String value) =>
      UserRole.values.firstWhere((r) => r.name == value, orElse: () => UserRole.player);
}

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

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        matchesPlayed: json['matchesPlayed'] as int? ?? 0,
        wins: json['wins'] as int? ?? 0,
        hoursPlayed: json['hoursPlayed'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'matchesPlayed': matchesPlayed,
        'wins': wins,
        'hoursPlayed': hoursPlayed,
      };

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

  factory SurfacePreferences.fromJson(Map<String, dynamic> json) => SurfacePreferences(
        clay: (json['clay'] as num?)?.toDouble() ?? 0,
        hard: (json['hard'] as num?)?.toDouble() ?? 0,
        grass: (json['grass'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'clay': clay, 'hard': hard, 'grass': grass};

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
  final Map<String, bool> notifications;
  // Denormalized reference to every booking this user is part of (as
  // booker or invited partner) — the `bookings` collection (queried by
  // `userId`) stays the source of truth, this is just a link on the profile.
  final List<String> bookingIds;

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
    this.notifications = const {},
    this.bookingIds = const [],
  });

  /// Whether a given notification kind is on — defaults to off if the user
  /// (or seed data) never set it explicitly.
  bool isNotificationEnabled(String key) => notifications[key] ?? false;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  bool get isAdmin => role == UserRole.admin;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    Object? phone = _sentinel,
    Object? profileImageUrl = _sentinel,
    String? ranking,
    String? location,
    double? rating,
    DateTime? memberSince,
    int? matchesPerMonth,
    UserStats? stats,
    SurfacePreferences? surfaces,
    UserRole? role,
    Map<String, bool>? notifications,
    List<String>? bookingIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone == _sentinel ? this.phone : phone as String?,
      profileImageUrl:
          profileImageUrl == _sentinel ? this.profileImageUrl : profileImageUrl as String?,
      ranking: ranking ?? this.ranking,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      memberSince: memberSince ?? this.memberSince,
      matchesPerMonth: matchesPerMonth ?? this.matchesPerMonth,
      stats: stats ?? this.stats,
      surfaces: surfaces ?? this.surfaces,
      role: role ?? this.role,
      notifications: notifications ?? this.notifications,
      bookingIds: bookingIds ?? this.bookingIds,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
        ranking: json['ranking'] as String? ?? 'N.C.',
        location: json['location'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        memberSince: json['memberSince'] != null
            ? DateTime.parse(json['memberSince'] as String)
            : DateTime.now(),
        matchesPerMonth: json['matchesPerMonth'] as int? ?? 0,
        stats: json['stats'] != null
            ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
            : const UserStats(matchesPlayed: 0, wins: 0, hoursPlayed: 0),
        surfaces: json['surfaces'] != null
            ? SurfacePreferences.fromJson(json['surfaces'] as Map<String, dynamic>)
            : const SurfacePreferences(clay: 0, hard: 0, grass: 0),
        role: UserRoleJson.fromJson(json['role'] as String? ?? 'player'),
        notifications: json['notifications'] != null
            ? Map<String, bool>.from(json['notifications'] as Map)
            : const {},
        bookingIds: json['bookingIds'] != null
            ? List<String>.from(json['bookingIds'] as List)
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'profileImageUrl': profileImageUrl,
        'ranking': ranking,
        'location': location,
        'rating': rating,
        'memberSince': memberSince.toIso8601String(),
        'matchesPerMonth': matchesPerMonth,
        'stats': stats.toJson(),
        'surfaces': surfaces.toJson(),
        'role': role.jsonValue,
        'notifications': notifications,
        'bookingIds': bookingIds,
      };

  @override
  List<Object?> get props => [id, name, email, ranking, role];
}

const _sentinel = Object();
