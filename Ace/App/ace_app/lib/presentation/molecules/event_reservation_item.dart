import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../atoms/atoms.dart';

/// Card for a club event the user is participating in, styled to match
/// `BookingHistoryItem` so both can sit side by side in a "Réservations"
/// feed.
class EventReservationItem extends StatelessWidget {
  final ClubEventModel event;
  final VoidCallback onTap;
  final Color? titleColor;

  const EventReservationItem({
    super.key,
    required this.event,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}';
    final timeStr = event.startTime.isEmpty
        ? ''
        : event.endTime.isEmpty
        ? ' · ${event.startTime}'
        : ' · ${event.startTime} – ${event.endTime}';

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
            AppBadge(
              label: '🎉',
              backgroundColor: AppColors.primaryContainer,
              textColor: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.headlineSmall.copyWith(
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('$dateStr$timeStr', style: AppTypography.bodySmall),
                  Text(
                    'Événement · ${event.clubName}',
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
