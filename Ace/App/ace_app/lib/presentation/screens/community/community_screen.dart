import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/tab_activity_provider.dart';
import '../../../data/repositories/message_repository.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../courts/courts_view_model.dart';
import 'community_view_model.dart';
import 'chat_screen.dart';
import 'club_broadcast_screen.dart';
import 'propose_slot_modal.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    // Whichever tab is showing on arrival counts as "seen" — only tabs the
    // user never actually looked at should carry the new-activity dot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markSeen(ref.read(communityViewModelProvider).activeTab);
    });
  }

  void _markSeen(CommunityTab tab) {
    final activityVm = ref.read(tabActivityProvider.notifier);
    if (tab == CommunityTab.announcements) {
      activityVm.markAnnouncementsSeen();
    } else {
      activityVm.markMessagesSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityViewModelProvider);
    final vm = ref.read(communityViewModelProvider.notifier);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final hasNewAnnouncement = ref.watch(hasNewAnnouncementProvider);
    final hasNewMessage = ref.watch(hasNewMessageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TabBar(
            active: state.activeTab,
            hasNewAnnouncement: hasNewAnnouncement,
            hasNewMessage: hasNewMessage,
            onSelect: (tab) {
              vm.setTab(tab);
              _markSeen(tab);
            },
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.activeTab == CommunityTab.announcements
                ? _AnnouncementsTab(
                    announcements: state.announcements,
                    allUsers: state.allUsers,
                    currentUserId: currentUser?.id,
                    onInterested: (a) => _requireAuth(
                      currentUser,
                      () => _onInterested(vm, currentUser!, state.allUsers, a),
                    ),
                    onEdit: (a) => ProposeSlotModal.show(
                      context,
                      initial: a,
                      onConfirm: vm.updateAnnouncement,
                    ),
                    onDelete: (id) => vm.deleteAnnouncement(id),
                    onPropose: () => _requireAuth(
                      currentUser,
                      () => ProposeSlotModal.show(
                        context,
                        onConfirm: vm.addAnnouncement,
                      ),
                    ),
                  )
                : currentUser == null
                ? const _EmptyPlaceholder(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Connecte-toi pour discuter',
                    subtitle:
                        'La messagerie est réservée aux joueurs connectés.',
                  )
                : _MessagesTab(
                    conversations: state.conversations,
                    currentUser: currentUser,
                    onTap: (conv) => _openChat(
                      context,
                      conversationId: conv.id,
                      otherParticipantIds: conv.otherParticipantIds(
                        currentUser.id,
                      ),
                      title: conv.displayName(currentUser.id),
                      avatarInitials: conv.isGroup
                          ? null
                          : conv.otherParticipantInitials(currentUser.id),
                      avatarImageUrl: conv.isGroup
                          ? null
                          : conv.otherParticipantImageUrl(currentUser.id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Guards an action behind login — guests get sent to `/login` instead.
  void _requireAuth(UserModel? currentUser, VoidCallback action) {
    if (currentUser == null) {
      context.go('/login');
    } else {
      action();
    }
  }

  void _onInterested(
    CommunityViewModel vm,
    UserModel currentUser,
    List<UserModel> allUsers,
    AnnouncementModel announcement,
  ) {
    final alreadyInterested = announcement.interestedUserIds.contains(
      currentUser.id,
    );
    vm.toggleInterested(announcement.id, currentUser.id);

    if (!alreadyInterested) {
      final author = allUsers
          .where((u) => u.id == announcement.userId)
          .firstOrNull;
      if (author == null) return;

      vm.setTab(CommunityTab.messages);
      final conversationId = vm.conversationIdWith(author.id);
      if (conversationId == null) return;
      _openChat(
        context,
        conversationId: conversationId,
        otherParticipantIds: [author.id],
        title: author.name,
        avatarInitials: author.initials,
        avatarImageUrl: author.profileImageUrl,
        subtitle: 'Proposition de match',
      );
    }
  }

  void _openChat(
    BuildContext context, {
    required String conversationId,
    required List<String> otherParticipantIds,
    required String title,
    String? avatarInitials,
    String? avatarImageUrl,
    String? subtitle,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherParticipantIds: otherParticipantIds,
          title: title,
          avatarInitials: avatarInitials,
          avatarImageUrl: avatarImageUrl,
          subtitle: subtitle,
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final CommunityTab active;
  final bool hasNewAnnouncement;
  final bool hasNewMessage;
  final ValueChanged<CommunityTab> onSelect;

  const _TabBar({
    required this.active,
    required this.hasNewAnnouncement,
    required this.hasNewMessage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Tab(
                label: 'Messages',
                icon: Icons.chat_bubble_outline_rounded,
                isActive: active == CommunityTab.messages,
                showBadge: hasNewMessage,
                onTap: () => onSelect(CommunityTab.messages),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _Tab(
                label: 'Annonces',
                icon: Icons.campaign_rounded,
                isActive: active == CommunityTab.announcements,
                showBadge: hasNewAnnouncement,
                onTap: () => onSelect(CommunityTab.announcements),
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
  final bool showBadge;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
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
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final List<UserModel> allUsers;
  final String? currentUserId;
  final ValueChanged<AnnouncementModel> onInterested;
  final ValueChanged<AnnouncementModel> onEdit;
  final ValueChanged<String> onDelete;
  final VoidCallback onPropose;

  const _AnnouncementsTab({
    required this.announcements,
    required this.allUsers,
    required this.currentUserId,
    required this.onInterested,
    required this.onEdit,
    required this.onDelete,
    required this.onPropose,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
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
                currentUserId: currentUserId ?? '',
                userImageUrl: allUsers
                    .where((u) => u.id == a.userId)
                    .firstOrNull
                    ?.profileImageUrl,
                onInterested: () => onInterested(a),
                onEdit: () => onEdit(a),
                onDelete: () => onDelete(a.id),
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

class _MessagesTab extends ConsumerWidget {
  final List<ConversationModel> conversations;
  final UserModel currentUser;
  final ValueChanged<ConversationModel> onTap;

  const _MessagesTab({
    required this.conversations,
    required this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myClubs =
        ref
            .watch(clubsProvider)
            .valueOrNull
            ?.where((c) => currentUser.clubIds.contains(c.id))
            .toList() ??
        const <ClubModel>[];

    if (conversations.isEmpty && myClubs.isEmpty) {
      // Top-anchored (not centered) so the tab doesn't show a big empty
      // gap above it — matches the Annonces tab's layout.
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: const [
          _EmptyPlaceholder(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Aucune conversation',
            subtitle:
                'Discute avec un joueur depuis une annonce ou son profil.',
          ),
        ],
      );
    }
    return ListView(
      children: [
        ...myClubs.map(
          (club) =>
              _ClubBroadcastTile(club: club, canPost: currentUser.isAdmin),
        ),
        if (myClubs.isNotEmpty && conversations.isNotEmpty)
          const Divider(height: 1, indent: 80),
        ...conversations.map(
          (conv) => Dismissible(
            key: ValueKey(conv.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              color: AppColors.error,
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDeleteConversation(context),
            onDismissed: (_) => ref
                .read(communityViewModelProvider.notifier)
                .deleteConversation(conv.id),
            child: ConversationItem(
              conversation: conv,
              currentUserId: currentUser.id,
              onTap: () => onTap(conv),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmDeleteConversation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette conversation ?'),
        content: const Text(
          'Tous les messages seront supprimés. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _ClubBroadcastTile extends ConsumerWidget {
  final ClubModel club;
  final bool canPost;

  const _ClubBroadcastTile({required this.club, required this.canPost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = MessageRepository.broadcastConversationIdFor(
      club.id,
    );
    final messages =
        ref.watch(conversationMessagesProvider(conversationId)).valueOrNull ??
        const [];
    final last = messages.isNotEmpty ? messages.last : null;

    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 0,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.campaign_rounded, color: AppColors.primary),
      ),
      title: Text(
        'Annonces · ${club.name}',
        style: AppTypography.headlineSmall,
      ),
      subtitle: Text(
        last?.content ??
            (canPost
                ? 'Publiez une information pour tous les membres'
                : 'Aucune annonce pour le moment'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall,
      ),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ClubBroadcastScreen(club: club, canPost: canPost),
        ),
      ),
    );
  }
}
