import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../atoms/atoms.dart';

class BookingHistoryItem extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;
  final Color? titleColor;

  const BookingHistoryItem({super.key, required this.booking, this.onTap, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(booking.date);
    final isWin = booking.result == BookingResult.win;
    final hasResult = booking.result != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (hasResult)
              AppBadge(
                label: isWin ? 'V' : 'D',
                backgroundColor: isWin
                    ? AppColors.winBadge.withValues(alpha: 0.15)
                    : AppColors.lossBadge.withValues(alpha: 0.15),
                textColor: isWin ? AppColors.winBadge : AppColors.lossBadge,
              )
            else
              AppBadge(
                label: booking.status == BookingStatus.confirmed ? '✓' : '...',
                backgroundColor: booking.status == BookingStatus.confirmed
                    ? AppColors.primaryContainer
                    : AppColors.surfaceVariant,
                textColor: booking.status == BookingStatus.confirmed
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.courtName, style: AppTypography.headlineSmall.copyWith(color: titleColor)),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr · ${booking.startTime} – ${booking.endTime}',
                    style: AppTypography.bodySmall,
                  ),
                  if (booking.partnerName != null)
                    Text(
                      'vs ${booking.partnerName}${booking.score != null ? ' — ${booking.score}' : ''}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
