import 'package:cached_network_image/cached_network_image.dart';
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
import '../auth/auth_view_model.dart';
import '../court_detail/court_detail_screen.dart';
import 'club_event_providers.dart';
import 'courts_view_model.dart';
import 'tournament_providers.dart';

class CourtsScreen extends ConsumerWidget {
  const CourtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courtsViewModelProvider);
    final vm = ref.read(courtsViewModelProvider.notifier);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    // Guests only browse the demo club ("MockClub", see `state.clubs`
    // scoping in CourtsViewModel); a signed-in player sees events from a
    // club they belong to.
    final allEvents = ref.watch(clubEventsProvider).valueOrNull ?? const [];
    final events = currentUser == null
        ? allEvents
              .where((e) => state.clubs.any((c) => c.id == e.clubId))
              .toList()
        : allEvents
              .where((e) => currentUser.clubIds.contains(e.clubId))
              .toList();
    final allTournaments =
        ref.watch(tournamentsProvider).valueOrNull ?? const [];
    final tournaments = currentUser == null
        ? allTournaments
              .where((t) => state.clubs.any((c) => c.id == t.clubId))
              .toList()
        : allTournaments
              .where((t) => currentUser.clubIds.contains(t.clubId))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _AppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _SearchBar(onChanged: vm.setSearch)),
          if (state.clubs.length > 1)
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
                events.isEmpty && tournaments.isEmpty
                    ? AppSpacing.lg + MediaQuery.paddingOf(context).bottom
                    : 0,
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
          if (events.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 15)),
          if (events.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _EventsSection(
                  events: events,
                  currentUserId: currentUser?.id,
                  onParticipate: (event) {
                    if (currentUser == null) {
                      context.go('/login');
                      return;
                    }
                    final isIn = event.participantIds.contains(currentUser.id);
                    ref
                        .read(clubEventRepositoryProvider)
                        .setParticipating(event.id, currentUser.id, !isIn);
                  },
                ),
              ),
            ),
          if (tournaments.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 15)),
          if (tournaments.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _TournamentsSection(
                  tournaments: tournaments,
                  onTap: (t) => context.push('/tournament/${t.id}', extra: t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentsSection extends StatelessWidget {
  final List<TournamentModel> tournaments;
  final ValueChanged<TournamentModel> onTap;

  const _TournamentsSection({required this.tournaments, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tournois internes', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        ...tournaments.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GestureDetector(
              onTap: () => onTap(t),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: AppTypography.headlineSmall),
                          Text(
                            '${t.participantIds.length} inscrit(s) · ${t.clubName}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventsSection extends StatelessWidget {
  final List<ClubEventModel> events;
  final String? currentUserId;
  final ValueChanged<ClubEventModel> onParticipate;

  const _EventsSection({
    required this.events,
    required this.currentUserId,
    required this.onParticipate,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Événements des clubs', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        ...sorted.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ClubEventCard(
              event: e,
              isParticipating:
                  currentUserId != null &&
                  e.participantIds.contains(currentUserId),
              onParticipate: () => onParticipate(e),
              onTap: () => context.push('/event/${e.id}', extra: e),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the current club's logo + name once one is unambiguous — either
/// the club picked in `_ClubFilterBar`, or the only club there is to show
/// (most players belong to just one, in which case that filter bar doesn't
/// even render — see `CourtsScreen`). Falls back to the generic app
/// branding for a guest or an unfiltered multi-club view, where there's no
/// single club to represent.
class _AppBar extends ConsumerWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courtsViewModelProvider);
    final club = state.selectedClubId != null
        ? state.clubs.where((c) => c.id == state.selectedClubId).firstOrNull
        : (state.clubs.length == 1 ? state.clubs.single : null);

    return AppBar(
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          _AppBarLogo(imageUrl: club?.imageUrl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              club?.name ?? AppConstants.appName,
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }
}

class _AppBarLogo extends StatelessWidget {
  final String? imageUrl;

  const _AppBarLogo({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return const _FallbackMark();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 44,
          height: 44,
          color: AppColors.surfaceVariant,
        ),
        errorWidget: (_, _, _) => const _FallbackMark(),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.sports_tennis_rounded,
        color: Colors.white,
        size: 24,
      ),
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
