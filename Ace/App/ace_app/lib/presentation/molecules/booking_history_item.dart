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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          booking.courtName,
                          style: AppTypography.headlineSmall.copyWith(color: titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (booking.isUpcoming) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _CountdownPill(startDateTime: booking.startDateTime),
                      ],
                    ],
                  ),
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

class _CountdownPill extends StatelessWidget {
  final DateTime startDateTime;

  const _CountdownPill({required this.startDateTime});

  String get _label {
    final remaining = startDateTime.difference(DateTime.now());
    if (remaining.isNegative) return 'en cours';
    if (remaining.inHours > 23) return 'dans ${remaining.inDays}j';
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    return 'dans $hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        _label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
