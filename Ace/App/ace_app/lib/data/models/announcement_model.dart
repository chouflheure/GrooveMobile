import 'package:equatable/equatable.dart';

enum MatchType { singles, doubles, mixed }

extension MatchTypeLabel on MatchType {
  String get label {
    switch (this) {
      case MatchType.singles:
        return 'Simple';
      case MatchType.doubles:
        return 'Double';
      case MatchType.mixed:
        return 'Double mixte';
    }
  }
}

extension MatchTypeJson on MatchType {
  String get jsonValue => name;

  static MatchType fromJson(String value) =>
      MatchType.values.firstWhere((t) => t.name == value);
}

class AnnouncementModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userRanking;
  final String? userImageUrl;
  final String courtId;
  final String courtName;
  final DateTime date;
  final String time;
  final String message;
  final MatchType matchType;
  final String level;
  final int responsesCount;
  final int interestedCount;
  final DateTime createdAt;
  final List<String> interestedUserIds;

  const AnnouncementModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRanking,
    this.userImageUrl,
    required this.courtId,
    required this.courtName,
    required this.date,
    required this.time,
    required this.message,
    required this.matchType,
    required this.level,
    required this.responsesCount,
    required this.interestedCount,
    required this.createdAt,
    this.interestedUserIds = const [],
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  AnnouncementModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRanking,
    Object? userImageUrl = _sentinel,
    String? courtId,
    String? courtName,
    DateTime? date,
    String? time,
    String? message,
    MatchType? matchType,
    String? level,
    int? responsesCount,
    int? interestedCount,
    DateTime? createdAt,
    List<String>? interestedUserIds,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRanking: userRanking ?? this.userRanking,
      userImageUrl: userImageUrl == _sentinel
          ? this.userImageUrl
          : userImageUrl as String?,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      date: date ?? this.date,
      time: time ?? this.time,
      message: message ?? this.message,
      matchType: matchType ?? this.matchType,
      level: level ?? this.level,
      responsesCount: responsesCount ?? this.responsesCount,
      interestedCount: interestedCount ?? this.interestedCount,
      createdAt: createdAt ?? this.createdAt,
      interestedUserIds: interestedUserIds ?? this.interestedUserIds,
    );
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final interestedUserIds = List<String>.from(
      json['interestedUserIds'] as List? ?? const [],
    );
    return AnnouncementModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userRanking: json['userRanking'] as String,
      userImageUrl: json['userImageUrl'] as String?,
      courtId: json['courtId'] as String,
      courtName: json['courtName'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      message: json['message'] as String,
      matchType: MatchTypeJson.fromJson(json['matchType'] as String),
      level: json['level'] as String,
      responsesCount: json['responsesCount'] as int? ?? 0,
      // Derived from the array itself so a concurrent toggle can never
      // desync the count from who's actually listed as interested.
      interestedCount: interestedUserIds.length,
      createdAt: DateTime.parse(json['createdAt'] as String),
      interestedUserIds: interestedUserIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userRanking': userRanking,
    'userImageUrl': userImageUrl,
    'courtId': courtId,
    'courtName': courtName,
    'date': date.toIso8601String(),
    'time': time,
    'message': message,
    'matchType': matchType.jsonValue,
    'level': level,
    'responsesCount': responsesCount,
    'createdAt': createdAt.toIso8601String(),
    'interestedUserIds': interestedUserIds,
  };

  @override
  List<Object?> get props => [id, userId, courtId, date, time];
}

const _sentinel = Object();
