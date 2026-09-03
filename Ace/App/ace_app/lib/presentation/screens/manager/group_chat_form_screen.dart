import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';
import '../community/chat_screen.dart';
import '../community/community_view_model.dart';

/// Admin-only — starts a group conversation with several players at once.
class GroupChatFormScreen extends ConsumerStatefulWidget {
  final List<UserModel> players;

  const GroupChatFormScreen({super.key, required this.players});

  @override
  ConsumerState<GroupChatFormScreen> createState() => _GroupChatFormScreenState();
}

class _GroupChatFormScreenState extends ConsumerState<GroupChatFormScreen> {
  final _messageController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isValid => _selectedIds.length >= 2 && _messageController.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_isValid) return;
    final senderName = ref.read(currentUserProvider).valueOrNull?.name;
    if (senderName == null) return;
    setState(() => _isSending = true);

    final conversationId = ref.read(messageRepositoryProvider).newConversationId();
    await ref.read(communityViewModelProvider.notifier).sendMessage(
          conversationId,
          _selectedIds.toList(),
          senderName,
          _messageController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSending = false);

    final names = widget.players
        .where((u) => _selectedIds.contains(u.id))
        .map((u) => u.name)
        .toList();

    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherParticipantIds: _selectedIds.toList(),
          title: names.join(', '),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Conversation de groupe'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Participants', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choisis au moins 2 personnes.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...widget.players.map((u) {
                  final isSelected = _selectedIds.contains(u.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedIds.remove(u.id);
                      } else {
                        _selectedIds.add(u.id);
                      }
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryContainer : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            initials: u.initials,
                            size: 36,
                            backgroundColor:
                                isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(u.name, style: AppTypography.bodyMedium)),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premier message', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Écris le message qui lance la conversation...',
                    hintStyle: AppTypography.bodySmall,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Créer la conversation',
                  onTap: _isValid ? _create : null,
                  isLoading: _isSending,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
