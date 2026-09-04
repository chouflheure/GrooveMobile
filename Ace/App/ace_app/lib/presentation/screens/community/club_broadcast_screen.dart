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

  const ClubBroadcastScreen({
    super.key,
    required this.club,
    required this.canPost,
  });

  @override
  ConsumerState<ClubBroadcastScreen> createState() =>
      _ClubBroadcastScreenState();
}

class _ClubBroadcastScreenState extends ConsumerState<ClubBroadcastScreen> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  MessageModel? _editingMessage;

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    final editing = _editingMessage;
    if (editing != null) {
      _controller.clear();
      setState(() => _editingMessage = null);
      if (content != editing.content) {
        await ref
            .read(messageRepositoryProvider)
            .editMessage(editing.id, content);
      }
      return;
    }

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    _controller.clear();
    await ref
        .read(messageRepositoryProvider)
        .sendBroadcastMessage(
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

  void _startEdit(MessageModel message) {
    _controller.text = message.content;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _editingMessage = message);
    _inputFocusNode.requestFocus();
  }

  void _cancelEdit() {
    _controller.clear();
    setState(() => _editingMessage = null);
  }

  void _showMessageActions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xxxl),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text('Modifier', style: AppTypography.bodyMedium),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _startEdit(message);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              title: Text(
                'Supprimer',
                style: AppTypography.bodyMedium.copyWith(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action est irréversible.'),
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
    if (confirmed != true) return;
    if (_editingMessage?.id == message.id) _cancelEdit();
    await ref.read(messageRepositoryProvider).deleteMessage(message.id);
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = MessageRepository.broadcastConversationIdFor(
      widget.club.id,
    );
    final messagesAsync = ref.watch(
      conversationMessagesProvider(conversationId),
    );
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

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
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
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
                      itemBuilder: (_, i) {
                        final message = messages[i];
                        final isMe = message.senderId == currentUserId;
                        return _AnnouncementBubble(
                          message: message,
                          onLongPress: isMe
                              ? () => _showMessageActions(message)
                              : null,
                        );
                      },
                    ),
            ),
          ),
          if (widget.canPost)
            _InputBar(
              controller: _controller,
              focusNode: _inputFocusNode,
              onSend: _send,
              editingMessage: _editingMessage,
              onCancelEdit: _cancelEdit,
            ),
        ],
      ),
    );
  }
}

class _AnnouncementBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onLongPress;

  const _AnnouncementBubble({required this.message, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
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
                const Icon(
                  Icons.campaign_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
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
            if (message.edited)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'modifié',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final MessageModel? editingMessage;
  final VoidCallback onCancelEdit;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.editingMessage,
    required this.onCancelEdit,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editingMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Modification de l'annonce",
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelEdit,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Message pour tous les membres...',
                    hintStyle: AppTypography.bodySmall,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
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
        ],
      ),
    );
  }
}
