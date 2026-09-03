import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String conversationId;
  // Denormalized onto every message so Firestore can answer "which
  // conversations is this user part of" with a single `array-contains`
  // query, without a separate conversations collection.
  final List<String> participantIds;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final bool edited;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.participantIds,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.edited = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        participantIds: List<String>.from(json['participantIds'] as List),
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
        edited: json['edited'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'participantIds': participantIds,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'edited': edited,
      };

  @override
  List<Object?> get props => [id, conversationId, senderId];
}

/// Derived, read-only view of a conversation — built by grouping `messages`
/// documents client-side, not stored as its own Firestore document.
class ConversationModel extends Equatable {
  final String id;
  final List<String> participantIds;
  final List<String> participantNames;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final List<MessageModel> messages;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.messages = const [],
  });

  bool get isGroup => participantIds.length > 2;

  List<String> otherParticipantNames(String currentUserId) {
    final others = <String>[];
    for (var i = 0; i < participantIds.length; i++) {
      if (participantIds[i] != currentUserId) others.add(participantNames[i]);
    }
    return others;
  }

  List<String> otherParticipantIds(String currentUserId) =>
      participantIds.where((id) => id != currentUserId).toList();

  /// The other person's name for a 1:1, or every other name joined for a
  /// group — used wherever a single display title is needed.
  String displayName(String currentUserId) {
    final others = otherParticipantNames(currentUserId);
    if (others.isEmpty) return 'Conversation';
    return others.join(', ');
  }

  /// Only meaningful for a 1:1 (a group shows a generic icon instead).
  String otherParticipantInitials(String currentUserId) {
    final others = otherParticipantNames(currentUserId);
    final name = others.isEmpty ? '?' : others.first;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  List<Object?> get props => [id, participantIds];
}
