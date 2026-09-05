import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/tab_activity_provider.dart';
import '../../../data/repositories/broadcast_repository.dart';
import '../../../data/repositories/message_repository.dart';
import '../auth/auth_view_model.dart';

enum CommunityTab { announcements, messages }

class CommunityState {
  final CommunityTab activeTab;
  final List<AnnouncementModel> announcements;
  final List<ConversationModel> conversations;
  final List<UserModel> allUsers;
  final bool isLoading;

  const CommunityState({
    this.activeTab = CommunityTab.announcements,
    this.announcements = const [],
    this.conversations = const [],
    this.allUsers = const [],
    this.isLoading = false,
  });

  CommunityState copyWith({
    CommunityTab? activeTab,
    List<AnnouncementModel>? announcements,
    List<ConversationModel>? conversations,
    List<UserModel>? allUsers,
    bool? isLoading,
  }) {
    return CommunityState(
      activeTab: activeTab ?? this.activeTab,
      announcements: announcements ?? this.announcements,
      conversations: conversations ?? this.conversations,
      allUsers: allUsers ?? this.allUsers,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  DateTime? get latestAnnouncementAt => announcements.isEmpty
      ? null
      : announcements
            .map((a) => a.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

  DateTime? get latestMessageAt => conversations.isEmpty
      ? null
      : conversations
            .map((c) => c.lastMessageAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
}

class CommunityViewModel extends StateNotifier<CommunityState> {
  CommunityViewModel(
    this._broadcastRepository,
    this._messageRepository,
    List<UserModel> allUsers,
    this._currentUserId,
    this._currentUserClubIds,
  ) : super(CommunityState(allUsers: allUsers)) {
    state = state.copyWith(isLoading: true);
    _announcementsSubscription = _broadcastRepository.watchAll().listen((list) {
      state = state.copyWith(
        announcements: _filterByClub(_filterExpired(list)),
        isLoading: false,
      );
    });
    if (_currentUserId != null) {
      _conversationsSubscription = _messageRepository
          .watchConversationsForUser(
            _currentUserId,
            resolveName: _resolveName,
            resolveImageUrl: _resolveImageUrl,
          )
          .listen((conversations) {
            state = state.copyWith(conversations: conversations);
          });
    }
  }

  final BroadcastRepository _broadcastRepository;
  final MessageRepository _messageRepository;
  final String? _currentUserId;
  final List<String> _currentUserClubIds;
  late final StreamSubscription<List<AnnouncementModel>>
  _announcementsSubscription;
  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;

  String _resolveName(String userId) =>
      state.allUsers.where((u) => u.id == userId).firstOrNull?.name ??
      'Utilisateur';

  String? _resolveImageUrl(String userId) =>
      state.allUsers.where((u) => u.id == userId).firstOrNull?.profileImageUrl;

  // Only announcements posted by a member of a club the current user is
  // also in are visible — guests (no club) see everything.
  List<AnnouncementModel> _filterByClub(List<AnnouncementModel> list) {
    if (_currentUserId == null || _currentUserClubIds.isEmpty) return list;
    return list.where((a) {
      final author = state.allUsers.where((u) => u.id == a.userId).firstOrNull;
      return author != null && author.clubIds.any(_currentUserClubIds.contains);
    }).toList();
  }

  // Retire les annonces dont le créneau est passé depuis plus de 2h.
  List<AnnouncementModel> _filterExpired(List<AnnouncementModel> list) {
    final now = DateTime.now();
    return list.where((a) {
      final parts = a.time.split(':');
      final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
      // No specific time set (e.g. "À définir") — keep the announcement
      // visible until the end of its day instead of crashing on the parse.
      final matchDateTime = (hour == null || minute == null)
          ? DateTime(a.date.year, a.date.month, a.date.day, 23, 59)
          : DateTime(a.date.year, a.date.month, a.date.day, hour, minute);
      return now.isBefore(matchDateTime.add(const Duration(hours: 2)));
    }).toList();
  }

  void setTab(CommunityTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<void> toggleInterested(String announcementId, String userId) {
    final announcement = state.announcements
        .where((a) => a.id == announcementId)
        .firstOrNull;
    if (announcement == null) return Future.value();
    final isInterested = announcement.interestedUserIds.contains(userId);
    return _broadcastRepository.setInterested(
      announcementId,
      userId,
      !isInterested,
    );
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
  String? conversationIdWith(String otherUserId) => _currentUserId == null
      ? null
      : MessageRepository.conversationIdFor(_currentUserId, otherUserId);

  Future<void> sendMessage(
    String conversationId,
    List<String> otherUserIds,
    String senderName,
    String content,
  ) {
    final userId = _currentUserId;
    if (userId == null) return Future.value();
    return _messageRepository.sendMessage(
      conversationId: conversationId,
      participantIds: [userId, ...otherUserIds],
      senderId: userId,
      senderName: senderName,
      content: content,
    );
  }

  Future<void> editMessage(String messageId, String newContent) {
    return _messageRepository.editMessage(messageId, newContent);
  }

  Future<void> deleteMessage(String messageId) {
    return _messageRepository.deleteMessage(messageId);
  }

  Future<void> deleteConversation(String conversationId) {
    return _messageRepository.deleteConversation(conversationId);
  }

  @override
  void dispose() {
    _announcementsSubscription.cancel();
    _conversationsSubscription?.cancel();
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
    StateNotifierProvider<CommunityViewModel, CommunityState>((ref) {
      final userId = ref.watch(
        currentUserProvider.select((async) => async.valueOrNull?.id),
      );
      final clubIds = ref.watch(
        currentUserProvider.select(
          (async) => async.valueOrNull?.clubIds ?? const [],
        ),
      );
      final allUsers = ref.watch(allUsersProvider).valueOrNull ?? const [];
      return CommunityViewModel(
        ref.watch(broadcastRepositoryProvider),
        ref.watch(messageRepositoryProvider),
        allUsers,
        userId,
        clubIds,
      );
    });

/// Whether the Annonces tab has activity the user hasn't opened yet — shared
/// by the in-screen tab bar and the bottom nav badge so both agree.
final hasNewAnnouncementProvider = Provider<bool>((ref) {
  final latest = ref.watch(
    communityViewModelProvider.select((s) => s.latestAnnouncementAt),
  );
  final lastSeen = ref.watch(
    tabActivityProvider.select((a) => a.lastSeenAnnouncements),
  );
  return latest != null && (lastSeen == null || latest.isAfter(lastSeen));
});

/// Same idea for the Messages tab.
final hasNewMessageProvider = Provider<bool>((ref) {
  final latest = ref.watch(
    communityViewModelProvider.select((s) => s.latestMessageAt),
  );
  final lastSeen = ref.watch(
    tabActivityProvider.select((a) => a.lastSeenMessages),
  );
  return latest != null && (lastSeen == null || latest.isAfter(lastSeen));
});
