import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/message_repository.dart';
import '../auth/auth_view_model.dart';
import 'community_view_model.dart';

/// Read-only announcement channel for one club: any member can read every
/// message, but only an admin of that club can post — enforced here for UX
/// (hiding the input bar) and again server-side by `firestore.rules`.
class ClubBroadcastScreen extends ConsumerStatefulWidget {
  final ClubModel club;
  final bool canPost;

  const ClubBroadcastScreen({super.key, required this.club, required this.canPost});

  @override
  ConsumerState<ClubBroadcastScreen> createState() => _ClubBroadcastScreenState();
}

class _ClubBroadcastScreenState extends ConsumerState<ClubBroadcastScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    _controller.clear();
    await ref.read(messageRepositoryProvider).sendBroadcastMessage(
          clubId: widget.club.id,
          senderId: currentUser.id,
          senderName: currentUser.name,
          content: content,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = MessageRepository.broadcastConversationIdFor(widget.club.id);
    final messagesAsync = ref.watch(conversationMessagesProvider(conversationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Annonces', style: AppTypography.headlineSmall),
            Text(widget.club.name, style: AppTypography.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!widget.canPost)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              color: AppColors.surfaceVariant,
              child: Text(
                'Seuls les administrateurs du club peuvent publier ici.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, _) => Center(
                child: Text(
                  "Impossible de charger les annonces.",
                  style: AppTypography.bodySmall,
                ),
              ),
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune annonce pour le moment.',
                        style: AppTypography.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _AnnouncementBubble(message: messages[i]),
                    ),
            ),
          ),
          if (widget.canPost) _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _AnnouncementBubble extends StatelessWidget {
  final MessageModel message;

  const _AnnouncementBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                message.senderName,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.content, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Message pour tous les membres...',
                hintStyle: AppTypography.bodySmall,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
