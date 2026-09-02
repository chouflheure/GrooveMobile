import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import 'time_slot_chip.dart';

class CourtCard extends StatelessWidget {
  final CourtModel court;
  final VoidCallback? onTap;
  final Function(String courtId, String slot)? onSlotTap;

  const CourtCard({
    super.key,
    required this.court,
    this.onTap,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final freeSlots = court.freeSlots;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourtImage(court: court),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SlotsHeader(count: freeSlots.length),
                  if (freeSlots.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _SlotsList(
                      slots: freeSlots,
                      onTapSlot: (slot) => onSlotTap?.call(court.id, slot),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtImage extends StatelessWidget {
  final CourtModel court;

  const _CourtImage({required this.court});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.network(
            court.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.sports_tennis, size: 48, color: AppColors.textTertiary),
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourtTypeBadge(court: court),
              const SizedBox(height: 4),
              _SurfaceBadge(court: court),
            ],
          ),
        ),
        if (court.pricePerHour > 0)
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: _PriceBadge(price: court.pricePerHour),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CourtInfo(court: court),
        ),
      ],
    );
  }
}

class _CourtTypeBadge extends StatelessWidget {
  final CourtModel court;

  const _CourtTypeBadge({required this.court});

  @override
  Widget build(BuildContext context) {
    final isIndoor = court.type == CourtType.indoor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isIndoor ? AppColors.indoorBadge : AppColors.outdoorBadge,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIndoor ? Icons.home_rounded : Icons.wb_sunny_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            court.type.label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceBadge extends StatelessWidget {
  final CourtModel court;

  const _SurfaceBadge({required this.court});

  Color get _color => switch (court.surface) {
        CourtSurface.clay => AppColors.clay,
        CourtSurface.grass => AppColors.grass,
        CourtSurface.hard => AppColors.hard,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_on_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            court.surface.label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final double price;

  const _PriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        '${price.toInt()}€/h',
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CourtInfo extends StatelessWidget {
  final CourtModel court;

  const _CourtInfo({required this.court});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            court.name,
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  court.location.trim().isEmpty
                      ? 'Pas renseigné'
                      : court.location,
                  style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotsHeader extends StatelessWidget {
  final int count;

  const _SlotsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final title = switch (count) {
      0 => "Aucun créneau de disponible aujourd'hui",
      1 => "Créneau disponible aujourd'hui",
      _ => "Créneaux disponibles aujourd'hui",
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            count == 1 ? '1 dispo' : '$count dispos',
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
        ],
      ],
    );
  }
}

class _SlotsList extends StatelessWidget {
  final List<TimeSlot> slots;
  final ValueChanged<String> onTapSlot;

  const _SlotsList({
    required this.slots,
    required this.onTapSlot,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final slot = slots[i];
          return TimeSlotChip(
            slot: slot,
            onTap: () => onTapSlot(slot.time),
          );
        },
      ),
    );
  }
}
