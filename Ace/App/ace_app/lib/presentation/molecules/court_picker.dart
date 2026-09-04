import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../screens/courts/courts_view_model.dart';
import 'slot_availability_chip.dart';

/// Type/surface filter chips + a list of matching courts, each showing a
/// live preview of today's availability — used wherever an admin needs to
/// pick a court (Manager, Admin) instead of a plain name dropdown.
class CourtPicker extends StatefulWidget {
  final List<CourtModel> courts;
  final String? selectedCourtId;
  final ValueChanged<String> onSelect;

  const CourtPicker({
    super.key,
    required this.courts,
    required this.selectedCourtId,
    required this.onSelect,
  });

  @override
  State<CourtPicker> createState() => _CourtPickerState();
}

class _CourtPickerState extends State<CourtPicker> {
  String _filter = 'Tous';

  bool _matches(CourtModel c) {
    switch (_filter) {
      case 'Extérieur':
        return c.type == CourtType.outdoor;
      case 'Intérieur':
        return c.type == CourtType.indoor;
      case 'Terre battue':
        return c.surface == CourtSurface.clay;
      case 'Dur':
        return c.surface == CourtSurface.hard;
      case 'Gazon':
        return c.surface == CourtSurface.grass;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.courts.where(_matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AppConstants.surfaceTypes.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final f = AppConstants.surfaceTypes[i];
              final isSelected = _filter == f;
              return FilterChip(
                label: Text(
                  f,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: AppColors.primary,
                showCheckmark: false,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtered.isEmpty)
          Text('Aucun terrain pour ce filtre.', style: AppTypography.bodySmall)
        else
          ...filtered.map(
            (c) => _CourtOption(
              court: c,
              isSelected: widget.selectedCourtId == c.id,
              onTap: () => widget.onSelect(c.id),
            ),
          ),
      ],
    );
  }
}

class _CourtOption extends ConsumerWidget {
  final CourtModel court;
  final bool isSelected;
  final VoidCallback onTap;

  const _CourtOption({
    required this.court,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookedToday = ref
        .watch(
          bookedSlotsForCourtProvider((
            courtId: court.id,
            date: AppConstants.today(),
          )),
        )
        .valueOrNull;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(court.name, style: AppTypography.headlineSmall),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
            Text(
              '${court.type.label} · ${court.surface.label}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text("Aujourd'hui :", style: AppTypography.labelSmall),
            const SizedBox(height: 4),
            bookedToday == null
                ? const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: court
                        .baseSlotsFor(AppConstants.today())
                        .map(
                          (s) => SlotAvailabilityChip(
                            time: s.time,
                            isBooked:
                                court.isClosedOn(AppConstants.today()) ||
                                bookedToday.contains(s.time),
                          ),
                        )
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
