import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessageRepository {
  MessageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('messages');

  /// A fresh id for a new group conversation (3+ participants) — unlike
  /// the deterministic 1:1 id below, a group has no natural key of its
  /// own, so it just gets a normal Firestore-generated id.
  String newConversationId() => _collection.doc().id;

  /// Looks for a group conversation already made up of exactly
  /// `participantIds` (order-independent), so starting a "new" group with
  /// the same people just continues it instead of spawning a duplicate —
  /// 1:1s never need this since [conversationIdFor] already gives them a
  /// stable id.
  Future<String?> findGroupConversationId({
    required String currentUserId,
    required Set<String> participantIds,
  }) async {
    final snapshot = await _collection
        .where('participantIds', arrayContains: currentUserId)
        .get();
    final seen = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final conversationId = data['conversationId'] as String;
      if (!seen.add(conversationId)) continue;
      final ids = Set<String>.from(data['participantIds'] as List);
      if (ids.length == participantIds.length &&
          ids.containsAll(participantIds)) {
        return conversationId;
      }
    }
    return null;
  }

  /// Deterministic id for a 1:1 conversation — no separate "does this
  /// conversation exist" lookup needed, and it doubles as the value stored
  /// in every message's `conversationId` field.
  static String conversationIdFor(String userIdA, String userIdB) {
    final ids = [userIdA, userIdB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Id of a club's read-only announcement channel — prefixed so it can
  /// never collide with a 1:1 conversation id (those are two raw user ids
  /// joined by `_`).
  static String broadcastConversationIdFor(String clubId) =>
      'club_broadcast_$clubId';

  /// Posts to a club's announcement channel. Every member can read it
  /// (screen-level `isAdmin` check gates who gets the input box — Firestore
  /// rules should mirror that restriction server-side).
  Future<void> sendBroadcastMessage({
    required String clubId,
    required String senderId,
    required String senderName,
    required String content,
  }) {
    return sendMessage(
      conversationId: broadcastConversationIdFor(clubId),
      participantIds: const [],
      senderId: senderId,
      senderName: senderName,
      content: content,
    );
  }

  Future<void> sendMessage({
    required String conversationId,
    required List<String> participantIds,
    required String senderId,
    required String senderName,
    required String content,
  }) {
    final docRef = _collection.doc();
    final message = MessageModel(
      id: docRef.id,
      conversationId: conversationId,
      participantIds: participantIds,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: DateTime.now(),
    );
    return docRef.set(message.toJson());
  }

  /// Every participant id on a conversation, read off any one of its
  /// messages (they're denormalized onto each one) — used to resolve a
  /// notification tap's `conversationId` into what `ChatScreen` needs,
  /// since there's no separate `conversations` collection to look it up in.
  Future<List<String>?> participantIdsForConversation(
    String conversationId,
  ) async {
    final snapshot = await _collection
        .where('conversationId', isEqualTo: conversationId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return List<String>.from(snapshot.docs.first.data()['participantIds'] as List);
  }

  Stream<List<MessageModel>> watchMessagesForConversation(
    String conversationId,
  ) {
    return _collection
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// One listener on every message the user is part of, grouped
  /// client-side into a conversation list (last message + unread count per
  /// group) — avoids maintaining a separate `conversations` collection.
  Stream<List<ConversationModel>> watchConversationsForUser(
    String userId, {
    required String Function(String otherUserId) resolveName,
    required String? Function(String otherUserId) resolveImageUrl,
  }) {
    return _collection
        .where('participantIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final byConversation = <String, List<MessageModel>>{};
          for (final doc in snapshot.docs) {
            final message = MessageModel.fromJson(doc.data());
            byConversation
                .putIfAbsent(message.conversationId, () => [])
                .add(message);
          }

          return byConversation.entries.map((entry) {
              final messages = entry.value; // already newest-first
              final last = messages.first;
              final unread = messages
                  .where((m) => m.senderId != userId && !m.isRead)
                  .length;

              return ConversationModel(
                id: entry.key,
                participantIds: last.participantIds,
                participantNames: last.participantIds.map(resolveName).toList(),
                participantImageUrls: last.participantIds
                    .map(resolveImageUrl)
                    .toList(),
                lastMessage: last.content,
                lastMessageAt: last.createdAt,
                unreadCount: unread,
              );
            }).toList()
            ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        });
  }

  Future<void> editMessage(String messageId, String newContent) {
    return _collection.doc(messageId).update({
      'content': newContent,
      'edited': true,
    });
  }

  Future<void> deleteMessage(String messageId) {
    return _collection.doc(messageId).delete();
  }

  /// Deletes every message in a conversation — there's no separate
  /// `conversations` document to remove, the conversation *is* its
  /// messages. Batched in chunks of 500 (Firestore's per-batch write limit).
  Future<void> deleteConversation(String conversationId) async {
    final snapshot = await _collection
        .where('conversationId', isEqualTo: conversationId)
        .get();
    final docs = snapshot.docs;
    for (var i = 0; i < docs.length; i += 500) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> markConversationRead(
    String conversationId,
    String currentUserId,
  ) async {
    final snapshot = await _collection
        .where('conversationId', isEqualTo: conversationId)
        .get();
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['senderId'] != currentUserId && data['isRead'] != true;
    });
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
