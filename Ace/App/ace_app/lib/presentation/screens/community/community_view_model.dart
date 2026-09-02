import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/broadcast_repository.dart';
import '../../../data/repositories/message_repository.dart';

enum CommunityTab { announcements, messages }

class CommunityState {
  final CommunityTab activeTab;
  final List<AnnouncementModel> announcements;
  final List<ConversationModel> conversations;
  final bool isLoading;

  const CommunityState({
    this.activeTab = CommunityTab.announcements,
    this.announcements = const [],
    this.conversations = const [],
    this.isLoading = false,
  });

  CommunityState copyWith({
    CommunityTab? activeTab,
    List<AnnouncementModel>? announcements,
    List<ConversationModel>? conversations,
    bool? isLoading,
  }) {
    return CommunityState(
      activeTab: activeTab ?? this.activeTab,
      announcements: announcements ?? this.announcements,
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CommunityViewModel extends StateNotifier<CommunityState> {
  CommunityViewModel(this._broadcastRepository, this._messageRepository)
      : super(const CommunityState()) {
    state = state.copyWith(isLoading: true);
    _announcementsSubscription = _broadcastRepository.watchAll().listen((list) {
      state = state.copyWith(announcements: _filterExpired(list), isLoading: false);
    });
    _conversationsSubscription = _messageRepository
        .watchConversationsForUser(
      MockData.currentUser.id,
      resolveName: _resolveName,
    )
        .listen((conversations) {
      state = state.copyWith(conversations: conversations);
    });
  }

  final BroadcastRepository _broadcastRepository;
  final MessageRepository _messageRepository;
  late final StreamSubscription<List<AnnouncementModel>> _announcementsSubscription;
  late final StreamSubscription<List<ConversationModel>> _conversationsSubscription;

  String _resolveName(String userId) {
    if (userId == MockData.currentUser.id) return MockData.currentUser.name;
    return MockData.allUsers.where((u) => u.id == userId).firstOrNull?.name ??
        'Utilisateur';
  }

  // Retire les annonces dont le créneau est passé depuis plus de 2h.
  List<AnnouncementModel> _filterExpired(List<AnnouncementModel> list) {
    final now = DateTime.now();
    return list.where((a) {
      final parts = a.time.split(':');
      final matchDateTime = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return now.isBefore(matchDateTime.add(const Duration(hours: 2)));
    }).toList();
  }

  void setTab(CommunityTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<void> toggleInterested(String announcementId, String userId) {
    final announcement =
        state.announcements.where((a) => a.id == announcementId).firstOrNull;
    if (announcement == null) return Future.value();
    final isInterested = announcement.interestedUserIds.contains(userId);
    return _broadcastRepository.setInterested(announcementId, userId, !isInterested);
  }

  Future<void> addAnnouncement(AnnouncementModel announcement) {
    return _broadcastRepository.create(announcement);
  }

  Future<void> updateAnnouncement(AnnouncementModel updated) {
    return _broadcastRepository.update(updated);
  }

  Future<void> deleteAnnouncement(String id) {
    return _broadcastRepository.delete(id);
  }

  /// Deterministic id — no Firestore round-trip needed just to know which
  /// conversation two users share.
  String conversationIdWith(String otherUserId) =>
      MessageRepository.conversationIdFor(MockData.currentUser.id, otherUserId);

  Future<void> sendMessage(String conversationId, String otherUserId, String content) {
    return _messageRepository.sendMessage(
      conversationId: conversationId,
      participantIds: [MockData.currentUser.id, otherUserId],
      senderId: MockData.currentUser.id,
      senderName: MockData.currentUser.name,
      content: content,
    );
  }

  @override
  void dispose() {
    _announcementsSubscription.cancel();
    _conversationsSubscription.cancel();
    super.dispose();
  }
}

final broadcastRepositoryProvider = Provider<BroadcastRepository>(
  (_) => BroadcastRepository(),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (_) => MessageRepository(),
);

final conversationMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>(
  (ref, conversationId) => ref
      .watch(messageRepositoryProvider)
      .watchMessagesForConversation(conversationId),
);

final communityViewModelProvider =
    StateNotifierProvider<CommunityViewModel, CommunityState>(
  (ref) => CommunityViewModel(
    ref.watch(broadcastRepositoryProvider),
    ref.watch(messageRepositoryProvider),
  ),
);
