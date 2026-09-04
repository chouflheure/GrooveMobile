import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../atoms/atoms.dart';
import '../screens/auth/auth_view_model.dart';

/// Renders one card per logical booking — `group` holds every hourly slot
/// that got merged into it (see `groupConsecutiveBookings`), so a match or
/// event booked across several hours shows as a single card with the
/// combined time range instead of one card per hour. Pass a single-element
/// list for an ordinary 1h booking.
class BookingHistoryItem extends ConsumerWidget {
  final List<BookingModel> group;
  final VoidCallback? onTap;
  final Color? titleColor;

  const BookingHistoryItem({
    super.key,
    required this.group,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = group.first;
    final timeRange = group.length > 1
        ? '${booking.startTime} – ${group.last.endTime}'
        : '${booking.startTime} – ${booking.endTime}';
    final dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(booking.date);
    final isWin = booking.result == BookingResult.win;
    final hasResult = booking.result != null;

    // The doc only ever stores the invited partner's name — when it's
    // viewed by that partner, "the other player" is actually the booker,
    // whose name has to be looked up instead of just reusing partnerName.
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final String? opponentName;
    if (currentUserId != null && currentUserId == booking.partnerId) {
      opponentName = ref
          .watch(allUsersProvider)
          .valueOrNull
          ?.where((u) => u.id == booking.userId)
          .firstOrNull
          ?.name;
    } else {
      opponentName = booking.partnerName;
    }

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
            else if (booking.status == BookingStatus.cancelled)
              AppBadge(
                label: '✕',
                backgroundColor: AppColors.error.withValues(alpha: 0.12),
                textColor: AppColors.error,
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
                          style: AppTypography.headlineSmall.copyWith(
                            color: titleColor,
                          ),
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
                  if (booking.title != null && booking.title!.isNotEmpty)
                    Text(
                      booking.title!,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text('$dateStr · $timeRange', style: AppTypography.bodySmall),
                  if (opponentName != null)
                    Text(
                      'vs $opponentName${booking.score != null ? ' — ${booking.score}' : ''}',
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
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'dans ${hours}h ${minutes.toString().padLeft(2, '0')}';
    }
    return 'dans ${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
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
