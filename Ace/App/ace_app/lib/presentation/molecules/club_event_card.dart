import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';

class ClubEventCard extends StatelessWidget {
  final ClubEventModel event;
  final bool isParticipating;
  final VoidCallback? onParticipate;

  const ClubEventCard({
    super.key,
    required this.event,
    required this.isParticipating,
    this.onParticipate,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(event.date);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  event.clubName,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${dateStr[0].toUpperCase()}${dateStr.substring(1)}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(event.title, style: AppTypography.headlineMedium),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.description,
              style: AppTypography.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (event.courtNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: event.courtNames
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          name,
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (event.address.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.address,
                    style: AppTypography.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.group_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${event.participantIds.length} participant(s)', style: AppTypography.bodySmall),
              const Spacer(),
              GestureDetector(
                onTap: onParticipate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isParticipating ? AppColors.primaryContainer : AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    isParticipating ? 'Inscrit ✓' : 'Participer',
                    style: AppTypography.labelMedium.copyWith(
                      color: isParticipating ? AppColors.primary : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
