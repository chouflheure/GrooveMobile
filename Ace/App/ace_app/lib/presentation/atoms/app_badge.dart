import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

enum BadgeVariant { ranking, win, loss, surface, courtType, custom }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.custom,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  factory AppBadge.ranking(String ranking) =>
      AppBadge(label: ranking, variant: BadgeVariant.ranking);

  factory AppBadge.win() =>
      const AppBadge(label: 'V', variant: BadgeVariant.win);

  factory AppBadge.loss() =>
      const AppBadge(label: 'D', variant: BadgeVariant.loss);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors() {
    switch (variant) {
      case BadgeVariant.ranking:
        return (const Color(0xFFFFF3CD), const Color(0xFF856404));
      case BadgeVariant.win:
        return (AppColors.winBadge.withValues(alpha: 0.15), AppColors.winBadge);
      case BadgeVariant.loss:
        return (
          AppColors.lossBadge.withValues(alpha: 0.15),
          AppColors.lossBadge,
        );
      case BadgeVariant.surface:
        return (AppColors.primaryContainer, AppColors.primary);
      case BadgeVariant.courtType:
        return (AppColors.primaryContainer, AppColors.primary);
      case BadgeVariant.custom:
        return (
          backgroundColor ?? AppColors.surfaceVariant,
          textColor ?? AppColors.textPrimary,
        );
    }
  }
}
