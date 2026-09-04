import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';
import 'community_view_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final List<String> otherParticipantIds;
  final String title;
  final String? subtitle;
  // Null shows a generic group icon instead of initials.
  final String? avatarInitials;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantIds,
    required this.title,
    this.subtitle,
    this.avatarInitials,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  MessageModel? _editingMessage;

  bool get _isGroup => widget.otherParticipantIds.length > 1;

  @override
  void initState() {
    super.initState();
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId != null) {
      ref
          .read(messageRepositoryProvider)
          .markConversationRead(widget.conversationId, userId);
    }
  }

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
            .read(communityViewModelProvider.notifier)
            .editMessage(editing.id, content);
      }
      return;
    }

    final senderName = ref.read(currentUserProvider).valueOrNull?.name;
    if (senderName == null) return;
    _controller.clear();
    await ref
        .read(communityViewModelProvider.notifier)
        .sendMessage(
          widget.conversationId,
          widget.otherParticipantIds,
          senderName,
          content,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // The list is built `reverse: true` (newest message at the bottom,
        // which is offset 0 in a reversed list), so scrolling "to the
        // latest message" means scrolling to 0, not maxScrollExtent.
        _scrollController.animateTo(
          0,
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
    await ref
        .read(communityViewModelProvider.notifier)
        .deleteMessage(message.id);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: widget.subtitle != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subtitle!, style: AppTypography.headlineSmall),
                  Text(widget.title, style: AppTypography.bodySmall),
                ],
              )
            : Row(
                children: [
                  _isGroup || widget.avatarInitials == null
                      ? Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        )
                      : AppAvatar(initials: widget.avatarInitials!, size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, _) => Center(
                child: Text(
                  "Impossible de charger la conversation.",
                  style: AppTypography.bodySmall,
                ),
              ),
              data: (messages) => ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  // `messages` comes oldest-first; reversed indexing here
                  // (last message at index 0) is what pairs with
                  // `reverse: true` to anchor the list on the newest
                  // message instead of opening scrolled to the oldest one.
                  final message = messages[messages.length - 1 - i];
                  final isMe = message.senderId == currentUserId;
                  return _MessageBubble(
                    message: message,
                    isMe: isMe,
                    showSenderName: _isGroup && !isMe,
                    onLongPress: isMe
                        ? () => _showMessageActions(message)
                        : null,
                  );
                },
              ),
            ),
          ),
          _BookCourtBanner(
            onTap: () {
              // ChatScreen is pushed with a rootNavigator MaterialPageRoute,
              // outside go_router's tracked stack — pop back to the shell
              // first so context.go actually navigates visibly.
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route.isFirst);
              context.go('/courts');
            },
          ),
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

class _BookCourtBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _BookCourtBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_tennis_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Réserver un terrain',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showSenderName)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: 2,
                  ),
                  child: Text(
                    message.senderName,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppSpacing.radiusMd),
                    topRight: const Radius.circular(AppSpacing.radiusMd),
                    bottomLeft: Radius.circular(isMe ? AppSpacing.radiusMd : 4),
                    bottomRight: Radius.circular(
                      isMe ? 4 : AppSpacing.radiusMd,
                    ),
                  ),
                  border: isMe ? null : Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.content,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (message.edited)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'modifié',
                          style: AppTypography.labelSmall.copyWith(
                            color: isMe
                                ? Colors.white70
                                : AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
                      'Modification du message',
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTypography.bodyMedium,
                  minLines: 1,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Votre message...',
                    hintStyle: AppTypography.bodySmall,
                    filled: true,
                    fillColor: AppColors.background,
                    // The app-wide input theme sets its own enabledBorder /
                    // focusedBorder (a big pill radius, right for one-line
                    // fields) which would otherwise override `border` below
                    // once this field is focused or just enabled — so all
                    // three need to agree on the same rounded-rect radius.
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
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
