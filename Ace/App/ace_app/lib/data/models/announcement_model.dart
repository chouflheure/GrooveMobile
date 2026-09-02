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

  @override
  List<Object?> get props => [id, userId, courtId, date, time];
}
