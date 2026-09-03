import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../court_detail/court_detail_screen.dart';
import 'courts_view_model.dart';

class CourtsScreen extends ConsumerWidget {
  const CourtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courtsViewModelProvider);
    final vm = ref.read(courtsViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _AppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _SearchBar(onChanged: vm.setSearch)),
          if (state.clubs.isNotEmpty)
            SliverToBoxAdapter(
              child: _ClubFilterBar(
                clubs: state.clubs,
                selectedClubId: state.selectedClubId,
                onSelect: vm.setClub,
              ),
            ),
          SliverToBoxAdapter(
            child: _FilterBar(
              selected: state.selectedFilter,
              onSelect: vm.setFilter,
            ),
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (state.filteredCourts.isEmpty)
            SliverFillRemaining(child: _EmptyState())
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.separated(
                itemCount: state.filteredCourts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (_, i) {
                  final court = state.filteredCourts[i];
                  final clubName = state.clubs
                      .where((c) => c.id == court.clubId)
                      .firstOrNull
                      ?.name;
                  return CourtCard(
                    court: court,
                    clubName: clubName,
                    onTap: () => context.push(
                      '/court/${court.id}',
                      extra: CourtDetailArgs(court: court),
                    ),
                    onSlotTap: (courtId, slot) => context.push(
                      '/court/$courtId',
                      extra: CourtDetailArgs(court: court, initialSlot: slot),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_tennis_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'CourtConnect',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }
}

class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: AppSearchField(
        controller: _controller,
        hint: 'Rechercher un terrain...',
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: AppConstants.surfaceTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final filter = AppConstants.surfaceTypes[i];
          final isSelected = selected == filter;
          return FilterChip(
            label: Text(
              filter,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelect(filter),
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
    );
  }
}


class _ClubFilterBar extends StatelessWidget {
  final List<ClubModel> clubs;
  final String? selectedClubId;
  final ValueChanged<String?> onSelect;

  const _ClubFilterBar({
    required this.clubs,
    required this.selectedClubId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: clubs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final label = i == 0 ? 'Tous les clubs' : clubs[i - 1].name;
          final clubId = i == 0 ? null : clubs[i - 1].id;
          final isSelected = selectedClubId == clubId;
          return FilterChip(
            label: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelect(clubId),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Aucun terrain trouvé', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Essayez un autre filtre ou une autre recherche.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
