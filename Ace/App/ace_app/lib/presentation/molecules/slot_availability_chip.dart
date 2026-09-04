import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Unlike [TimeSlotChip] (which just hides booked slots), this shows every
/// slot so an admin can see what's taken at a glance, not only what's free.
class SlotAvailabilityChip extends StatelessWidget {
  final String time;
  final bool isBooked;
  final bool isSelected;
  final VoidCallback? onTap;

  const SlotAvailabilityChip({
    super.key,
    required this.time,
    required this.isBooked,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBooked
        ? AppColors.error
        : isSelected
        ? Colors.white
        : AppColors.success;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isBooked
              ? AppColors.error.withValues(alpha: 0.1)
              : isSelected
              ? AppColors.success
              : AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isBooked
                ? AppColors.error.withValues(alpha: 0.5)
                : isSelected
                ? AppColors.success
                : AppColors.success.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          time,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            decoration: isBooked ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
