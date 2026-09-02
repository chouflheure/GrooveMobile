import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  @override
  List<Object?> get props => [id, conversationId, senderId];
}

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

  String otherParticipantName(String currentUserId) {
    final idx = participantIds.indexOf(currentUserId);
    if (idx == 0) return participantNames[1];
    return participantNames[0];
  }

  String otherParticipantInitials(String currentUserId) {
    final name = otherParticipantName(currentUserId);
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  List<Object?> get props => [id, participantIds];
}
