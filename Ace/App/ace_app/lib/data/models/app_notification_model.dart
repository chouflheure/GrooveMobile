import 'package:equatable/equatable.dart';

/// One "bell" notification — created server-side alongside the matching
/// push (see functions/lib/notifications.js) for every event kind except
/// messages/broadcasts, which have their own unread tracking. `data`
/// mirrors exactly what the push carries, so it can be handed straight to
/// `handleNotificationTap` on tap — same routing as a tapped push.
///
/// Two independent read states: `seen` clears in bulk the moment the
/// notifications screen opens (drives the bell's counter); `clicked` only
/// clears for this one notification once it's actually tapped (drives
/// whether it's still highlighted in the list).
class AppNotificationModel extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool seen;
  final bool clicked;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    required this.seen,
    required this.clicked,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: json['data'] != null
            ? Map<String, dynamic>.from(json['data'] as Map)
            : const {},
        createdAt: DateTime.parse(json['createdAt'] as String),
        seen: json['seen'] as bool? ?? false,
        clicked: json['clicked'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, seen, clicked];
}
