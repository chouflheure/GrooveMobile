import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';

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
  CommunityViewModel() : super(const CommunityState()) {
    _load();
  }

  void _load() {
    state = state.copyWith(isLoading: true);
    Future.delayed(const Duration(milliseconds: 200), () {
      state = state.copyWith(
        announcements: _filterExpired(MockData.announcements),
        conversations: MockData.conversations,
        isLoading: false,
      );
    });
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

  void toggleInterested(String announcementId, String userId) {
    final updated = state.announcements.map((a) {
      if (a.id != announcementId) return a;
      final ids = List<String>.from(a.interestedUserIds);
      if (ids.contains(userId)) {
        ids.remove(userId);
        return AnnouncementModel(
          id: a.id,
          userId: a.userId,
          userName: a.userName,
          userRanking: a.userRanking,
          userImageUrl: a.userImageUrl,
          courtId: a.courtId,
          courtName: a.courtName,
          date: a.date,
          time: a.time,
          message: a.message,
          matchType: a.matchType,
          level: a.level,
          responsesCount: a.responsesCount,
          interestedCount: a.interestedCount - 1,
          createdAt: a.createdAt,
          interestedUserIds: ids,
        );
      } else {
        ids.add(userId);
        return AnnouncementModel(
          id: a.id,
          userId: a.userId,
          userName: a.userName,
          userRanking: a.userRanking,
          userImageUrl: a.userImageUrl,
          courtId: a.courtId,
          courtName: a.courtName,
          date: a.date,
          time: a.time,
          message: a.message,
          matchType: a.matchType,
          level: a.level,
          responsesCount: a.responsesCount,
          interestedCount: a.interestedCount + 1,
          createdAt: a.createdAt,
          interestedUserIds: ids,
        );
      }
    }).toList();
    state = state.copyWith(announcements: updated);
  }

  void addAnnouncement(AnnouncementModel announcement) {
    state = state.copyWith(
      announcements: [announcement, ...state.announcements],
    );
  }

  void updateAnnouncement(AnnouncementModel updated) {
    state = state.copyWith(
      announcements: state.announcements
          .map((a) => a.id == updated.id ? updated : a)
          .toList(),
    );
  }

  void deleteAnnouncement(String id) {
    state = state.copyWith(
      announcements: state.announcements.where((a) => a.id != id).toList(),
    );
  }

  ConversationModel? createConversation(UserModel user, String currentUserId, String currentUserName) {
    // Vérifie si une conversation existe déjà avec cet utilisateur
    final existing = state.conversations.where((c) =>
        c.participantIds.contains(user.id) &&
        c.participantIds.contains(currentUserId)).firstOrNull;
    if (existing != null) return existing;

    final conv = ConversationModel(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      participantIds: [currentUserId, user.id],
      participantNames: [currentUserName, user.name],
      lastMessage: '',
      lastMessageAt: DateTime.now(),
    );
    state = state.copyWith(conversations: [conv, ...state.conversations]);
    return conv;
  }

  void sendMessage(String conversationId, String content, String senderId, String senderName) {
    final msg = MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: DateTime.now(),
      isRead: false,
    );

    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return ConversationModel(
        id: c.id,
        participantIds: c.participantIds,
        participantNames: c.participantNames,
        lastMessage: content,
        lastMessageAt: DateTime.now(),
        unreadCount: 0,
        messages: [...c.messages, msg],
      );
    }).toList();

    state = state.copyWith(conversations: updated);
  }
}

final communityViewModelProvider =
    StateNotifierProvider<CommunityViewModel, CommunityState>(
  (_) => CommunityViewModel(),
);
