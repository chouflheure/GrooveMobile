import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../atoms/atoms.dart';

/// Bottom sheet used to pick a single player from a searchable list — same
/// visual language as the booking flow's partner picker. Resolves to the
/// picked [UserModel], to [clearSelection] if "Aucun" was tapped, or to
/// `null` if the sheet was simply dismissed without a choice.
class PlayerPickerSheet extends StatefulWidget {
  final List<UserModel> players;
  final String? selectedPlayerId;
  final String title;

  const PlayerPickerSheet({
    super.key,
    required this.players,
    required this.selectedPlayerId,
    required this.title,
  });

  /// Sentinel returned when the user explicitly clears the selection —
  /// distinct from `null`, which means the sheet was dismissed as-is.
  static const Object clearSelection = _ClearSelection();

  static Future<Object?> show(
    BuildContext context, {
    required List<UserModel> players,
    required String? selectedPlayerId,
    required String title,
  }) {
    return showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetContext) {
        final keyboardHeight = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: FractionallySizedBox(
            heightFactor: keyboardHeight > 0 ? 0.85 : 0.7,
            child: PlayerPickerSheet(
              players: players,
              selectedPlayerId: selectedPlayerId,
              title: title,
            ),
          ),
        );
      },
    );
  }

  @override
  State<PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _ClearSelection {
  const _ClearSelection();
}

class _PlayerPickerSheetState extends State<PlayerPickerSheet> {
  String _query = '';
  final _searchController = TextEditingController();

  List<UserModel> get _filtered {
    final query = _query.toLowerCase().trim();
    if (query.isEmpty) return widget.players;
    return widget.players
        .where(
          (u) =>
              u.name.toLowerCase().contains(query) ||
              u.location.toLowerCase().contains(query) ||
              u.ranking.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!keyboardOpen) ...[
                  Text(widget.title, style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextField(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _query = q),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un joueur…',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              children: [
                _PlayerTile(
                  name: 'Aucun',
                  subtitle: 'Ne pas assigner ce joueur',
                  isSelected: widget.selectedPlayerId == null,
                  onTap: () =>
                      Navigator.of(context).pop(PlayerPickerSheet.clearSelection),
                ),
                ..._filtered.map(
                  (user) => _PlayerTile(
                    name: user.name,
                    subtitle: '${user.location} · ${user.ranking}',
                    isSelected: widget.selectedPlayerId == user.id,
                    initials: user.initials,
                    imageUrl: user.profileImageUrl,
                    onTap: () => Navigator.of(context).pop(user),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isSelected;
  final String? initials;
  final String? imageUrl;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.initials,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (initials != null)
              AppAvatar(
                initials: initials!,
                imageUrl: imageUrl,
                size: 40,
                backgroundColor: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                textColor: isSelected ? Colors.white : AppColors.textPrimary,
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.headlineSmall),
                  Text(subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
