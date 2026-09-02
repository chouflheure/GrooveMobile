import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import 'community_view_model.dart';
import 'chat_screen.dart';
import 'propose_slot_modal.dart';
import '../user_profile/user_profile_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityViewModelProvider);
    final vm = ref.read(communityViewModelProvider.notifier);
    final isMessages = state.activeTab == CommunityTab.messages;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isMessages
          ? FloatingActionButton(
              onPressed: () => _showNewConversationPicker(vm),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          _TabBar(
            active: state.activeTab,
            onSelect: vm.setTab,
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.activeTab == CommunityTab.announcements
                    ? _AnnouncementsTab(
                        announcements: state.announcements,
                        onInterested: (a) => _onInterested(context, vm, a),
                        onEdit: (a) => ProposeSlotModal.show(
                          context,
                          initial: a,
                          onConfirm: vm.updateAnnouncement,
                        ),
                        onDelete: (id) => vm.deleteAnnouncement(id),
                        onPropose: () => ProposeSlotModal.show(
                          context,
                          onConfirm: vm.addAnnouncement,
                        ),
                      )
                    : _MessagesTab(
                        conversations: state.conversations,
                        onTap: (conv) => _openChat(
                          context,
                          conversationId: conv.id,
                          otherUserId: conv.participantIds
                              .firstWhere((id) => id != MockData.currentUser.id),
                          otherUserName:
                              conv.otherParticipantName(MockData.currentUser.id),
                          otherUserInitials:
                              conv.otherParticipantInitials(MockData.currentUser.id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _onInterested(
    BuildContext context,
    CommunityViewModel vm,
    AnnouncementModel announcement,
  ) {
    final alreadyInterested =
        announcement.interestedUserIds.contains(MockData.currentUser.id);
    vm.toggleInterested(announcement.id, MockData.currentUser.id);

    if (!alreadyInterested) {
      final author = MockData.allUsers
          .where((u) => u.id == announcement.userId)
          .firstOrNull;
      if (author == null) return;

      vm.setTab(CommunityTab.messages);
      _openChat(
        context,
        conversationId: vm.conversationIdWith(author.id),
        otherUserId: author.id,
        otherUserName: author.name,
        otherUserInitials: author.initials,
      );
    }
  }

  void _showNewConversationPicker(CommunityViewModel vm) {
    final candidates = MockData.allUsers
        .where((u) => u.id != MockData.currentUser.id && !u.isAdmin)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _NewConversationSheet(
        users: candidates,
        onSelect: (user) {
          Navigator.of(context, rootNavigator: true).pop();
          _openChat(
            context,
            conversationId: vm.conversationIdWith(user.id),
            otherUserId: user.id,
            otherUserName: user.name,
            otherUserInitials: user.initials,
          );
        },
      ),
    );
  }

  void _openChat(
    BuildContext context, {
    required String conversationId,
    required String otherUserId,
    required String otherUserName,
    required String otherUserInitials,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserInitials: otherUserInitials,
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final CommunityTab active;
  final ValueChanged<CommunityTab> onSelect;

  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: _Tab(
                label: 'Annonces',
                icon: Icons.campaign_rounded,
                isActive: active == CommunityTab.announcements,
                onTap: () => onSelect(CommunityTab.announcements),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _Tab(
                label: 'Messages',
                icon: Icons.chat_bubble_outline_rounded,
                isActive: active == CommunityTab.messages,
                onTap: () => onSelect(CommunityTab.messages),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final ValueChanged<AnnouncementModel> onInterested;
  final ValueChanged<AnnouncementModel> onEdit;
  final ValueChanged<String> onDelete;
  final VoidCallback onPropose;

  const _AnnouncementsTab({
    required this.announcements,
    required this.onInterested,
    required this.onEdit,
    required this.onDelete,
    required this.onPropose,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        _ProposeButton(onTap: onPropose),
        const SizedBox(height: AppSpacing.md),
        if (announcements.isEmpty)
          const _EmptyPlaceholder(
            icon: Icons.campaign_outlined,
            title: 'Aucune annonce',
            subtitle: 'Proposez un créneau aux joueurs du club',
          )
        else
          ...announcements.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AnnouncementCard(
                announcement: a,
                currentUserId: MockData.currentUser.id,
                onInterested: () => onInterested(a),
                onEdit: () => onEdit(a),
                onDelete: () => onDelete(a.id),
                onUserTap: () {
                  final user = MockData.allUsers
                      .where((u) => u.id == a.userId)
                      .firstOrNull;
                  if (user != null && user.id != MockData.currentUser.id) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
                    );
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        children: [
          Icon(icon, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProposeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProposeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.primary,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Proposer un créneau',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewConversationSheet extends StatelessWidget {
  final List<UserModel> users;
  final ValueChanged<UserModel> onSelect;

  const _NewConversationSheet({required this.users, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xxxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Row(
              children: [
                Text('Nouvelle conversation', style: AppTypography.headlineLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...users.map(
            (u) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xs,
              ),
              leading: AppAvatar(initials: u.initials, size: 44),
              title: Text(u.name, style: AppTypography.headlineSmall),
              subtitle: Text('${u.location} · ${u.ranking}',
                  style: AppTypography.bodySmall),
              onTap: () {
                Navigator.of(context).pop();
                onSelect(u);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  final List<ConversationModel> conversations;
  final ValueChanged<ConversationModel> onTap;

  const _MessagesTab({required this.conversations, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const Center(
        child: _EmptyPlaceholder(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Aucune conversation',
          subtitle: 'Discute avec un joueur depuis une annonce, ou lance une\nnouvelle conversation avec le bouton en bas à droite.',
        ),
      );
    }
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
      itemBuilder: (_, i) => ConversationItem(
        conversation: conversations[i],
        currentUserId: MockData.currentUser.id,
        onTap: () => onTap(conversations[i]),
      ),
    );
  }
}
