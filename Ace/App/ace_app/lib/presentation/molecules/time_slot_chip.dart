import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';

class TimeSlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  // Purely a visual accent (blue = heure creuse, green = heure pleine) so
  // players can see which price/demand band a slot falls into before
  // picking it — set by the court's `peakHours`.
  final bool isPeak;
  final VoidCallback? onTap;

  const TimeSlotChip({
    super.key,
    required this.slot,
    this.isSelected = false,
    this.isPeak = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!slot.isAvailable) return const SizedBox.shrink();

    final accent = isPeak ? AppColors.peakHour : AppColors.offPeakHour;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : accent,
            width: isSelected ? 1.5 : 1.5,
          ),
        ),
        child: Text(
          slot.time,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
