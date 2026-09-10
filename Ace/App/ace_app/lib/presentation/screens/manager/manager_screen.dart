import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/booking_grouping.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../courts/courts_view_model.dart';
import '../edit_profile/edit_profile_screen.dart';
import 'admin_schedule_screen.dart';
import 'club_form_screen.dart';
import 'occupancy_stats_screen.dart';
import 'tournament_form_screen.dart';
import 'tournament_manage_screen.dart';
import 'court_form_screen.dart';
import 'event_form_screen.dart';
import 'group_chat_form_screen.dart';
import 'manager_view_model.dart';
import 'match_form_screen.dart';
import 'scenario_form_screen.dart';

class ManagerScreen extends ConsumerWidget {
  const ManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managerViewModelProvider);
    final vm = ref.read(managerViewModelProvider.notifier);

    if (state.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // `state.message` doubles as both the success confirmation and the
        // error channel across this view model — no separate flag exists,
        // so this is the only signal available to pick the right look.
        final isError = state.message!.startsWith('Erreur');
        AppSnackbar.show(
          context,
          message: state.message!,
          type: isError ? AppSnackbarType.error : AppSnackbarType.success,
        );
        vm.clearMessage();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(scrolledUnderElevation: 0, title: const Text('Manager')),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ScheduleSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const _MatchOrganizerSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _ClubsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _ScenariosManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _CourtsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _EventsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _TournamentsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _GroupChatSection(players: state.players),
                  const SizedBox(height: AppSpacing.xxl),
                  _ActiveBookingsSection(state: state, vm: vm),
                  const SizedBox(height: AppSpacing.xxl),
                  _AdminsSection(admins: state.admins),
                  const SizedBox(height: AppSpacing.xxl),
                  _ClubContactsSection(state: state, vm: vm),
                  const SizedBox(height: AppSpacing.xxl),
                  const _ContactInfoSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const _SavSection(),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Planning',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vue d'ensemble de tous les terrains, heure par heure, pour un jour donné.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const AdminScheduleScreen()),
              ),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('Voir le planning'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const OccupancyStatsScreen()),
              ),
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text("Statistiques d'occupation"),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchOrganizerSection extends StatelessWidget {
  const _MatchOrganizerSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.sports_tennis_rounded,
      title: 'Organiser un match',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bloque un terrain pour un match, avec ou sans joueurs assignés.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const MatchFormScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un match'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingsSection extends StatefulWidget {
  final ManagerState state;
  final ManagerViewModel vm;

  const _ActiveBookingsSection({required this.state, required this.vm});

  @override
  State<_ActiveBookingsSection> createState() => _ActiveBookingsSectionState();
}

class _ActiveBookingsSectionState extends State<_ActiveBookingsSection> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCourtId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _organizerName(BookingModel b) =>
      widget.state.players.where((u) => u.id == b.userId).firstOrNull?.name;

  bool _matches(List<BookingModel> group) {
    final first = group.first;
    if (_selectedCourtId != null && first.courtId != _selectedCourtId) {
      return false;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final courtMatch = first.courtName.toLowerCase().contains(q);
    final timeMatch = group.any(
      (b) => b.startTime.contains(q) || b.endTime.contains(q),
    );
    final organizerName = _organizerName(first) ?? '';
    final playerMatch =
        organizerName.toLowerCase().contains(q) ||
        (first.partnerName ?? '').toLowerCase().contains(q) ||
        (first.title ?? '').toLowerCase().contains(q);
    return courtMatch || timeMatch || playerMatch;
  }

  // Only courts that currently have an active booking — filtering by a
  // court with nothing to cancel would just be a dead-end chip.
  List<(String, String)> _courtsWithActiveBookings() {
    final byId = <String, String>{};
    for (final b in widget.state.activeBookings) {
      byId[b.courtId] = b.courtName;
    }
    final entries = byId.entries.map((e) => (e.key, e.value)).toList();
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupBookings(
      widget.state.activeBookings,
    ).where(_matches).toList();
    final courts = _courtsWithActiveBookings();
    return _SectionCard(
      icon: Icons.event_busy_rounded,
      title: 'Annuler une réservation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (q) => setState(() => _query = q),
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Rechercher un joueur, une heure, un terrain...',
              hintStyle: AppTypography.bodySmall,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
          if (courts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous les terrains'),
                    selected: _selectedCourtId == null,
                    onSelected: (_) =>
                        setState(() => _selectedCourtId = null),
                  ),
                  for (final court in courts) ...[
                    const SizedBox(width: AppSpacing.xs),
                    FilterChip(
                      label: Text(court.$2),
                      selected: _selectedCourtId == court.$1,
                      onSelected: (_) => setState(
                        () => _selectedCourtId =
                            _selectedCourtId == court.$1 ? null : court.$1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (groups.isEmpty)
            Text(
              widget.state.activeBookings.isEmpty
                  ? 'Aucune réservation active.'
                  : 'Aucun résultat.',
              style: AppTypography.bodySmall,
            )
          else
            Column(
              children: groups
                  .map(
                    (g) => _BookingRow(
                      group: g,
                      organizerName: _organizerName(g.first),
                      onCancel: () => _confirmCancel(context, widget.vm, g),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  // Sorted by date/time for display — groupConsecutiveBookings otherwise
  // preserves input order, which activeBookings already provides, but this
  // makes the ordering explicit and stable regardless of that.
  List<List<BookingModel>> _groupBookings(List<BookingModel> bookings) {
    final groups = groupConsecutiveBookings(bookings);
    groups.sort((a, b) {
      final cmp = a.first.date.compareTo(b.first.date);
      return cmp != 0 ? cmp : a.first.startTime.compareTo(b.first.startTime);
    });
    return groups;
  }

  void _confirmCancel(
    BuildContext context,
    ManagerViewModel vm,
    List<BookingModel> group,
  ) {
    final first = group.first;
    final rangeLabel = group.length > 1
        ? '${first.startTime}-${group.last.endTime}'
        : first.startTime;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          group.length > 1
              ? 'Annuler ces ${group.length} réservations ?'
              : 'Annuler cette réservation ?',
        ),
        content: Text(
          '${first.courtName} · ${first.date.day}/${first.date.month} · $rangeLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              vm.cancelBookings(group.map((b) => b.id).toList());
            },
            child: const Text(
              'Annuler la réservation',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final List<BookingModel> group;
  final String? organizerName;
  final VoidCallback onCancel;

  const _BookingRow({
    required this.group,
    required this.organizerName,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final first = group.first;
    final timeRange = group.length > 1
        ? '${first.startTime}-${group.last.endTime}'
        : '${first.startTime}-${first.endTime}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.courtName, style: AppTypography.headlineSmall),
                if (first.title != null && first.title!.isNotEmpty)
                  Text(
                    first.title!,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                // Both participants, not just the partner — the organizer's
                // own name was resolved but never actually shown here.
                if (first.partnerName != null)
                  Text(
                    '${organizerName ?? 'Joueur'} vs ${first.partnerName}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  '${first.date.day.toString().padLeft(2, '0')}/${first.date.month.toString().padLeft(2, '0')} · $timeRange'
                  '${first.hasExternalPlayer ? ' · joueur extérieur' : ''}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _ClubsManagementSection({required this.state});

  void _openForm(BuildContext context, ClubModel club) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ClubFormScreen(club: club)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.groups_rounded,
      title: 'Clubs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.clubs.isEmpty)
            Text(
              'Aucun club à gérer pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...state.clubs.map(
              (club) => GestureDetector(
                onTap: () => _openForm(context, club),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              style: AppTypography.headlineSmall,
                            ),
                            Text(club.location, style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScenariosManagementSection extends StatelessWidget {
  final ManagerState state;

  const _ScenariosManagementSection({required this.state});

  void _openForm(BuildContext context, {BookingScenario? scenario}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            ScenarioFormScreen(scenario: scenario, clubs: state.clubs),
      ),
    );
  }

  /// A short summary line for a scenario's list row, e.g.
  /// "10 jours · max 1/jour · heures creuses/pleines désactivées".
  String _summary(BookingScenario scenario) {
    final p = scenario.policy;
    final parts = <String>['${p.bookingWindowDays} jours'];
    if (p.maxSlotsPerDay != null) parts.add('max ${p.maxSlotsPerDay}/jour');
    if (p.maxSlotsPerWeek != null) {
      parts.add('max ${p.maxSlotsPerWeek}/semaine');
    }
    if (!p.peakHoursEnabled) parts.add('heures creuses/pleines désactivées');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.rule_rounded,
      title: 'Gérer la disponibilité',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.scenarios.isEmpty)
            Text(
              'Aucun scénario pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...state.scenarios.map((s) {
              final clubName = state.clubs
                  .where((cl) => cl.id == s.clubId)
                  .firstOrNull
                  ?.name;
              return GestureDetector(
                onTap: () => _openForm(context, scenario: s),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: AppTypography.headlineSmall),
                            Text(
                              '${_summary(s)}'
                              '${clubName != null ? ' · $clubName' : ''}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un scénario'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _TournamentsManagementSection({required this.state});

  void _openForm(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TournamentFormScreen(
          tournament: null,
          clubs: state.clubs,
          players: state.players,
        ),
      ),
    );
  }

  void _openManage(BuildContext context, TournamentModel tournament) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TournamentManageScreen(tournament: tournament),
      ),
    );
  }

  String _statusLabel(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.registration:
        return 'Inscriptions ouvertes';
      case TournamentStatus.inProgress:
        return 'En cours';
      case TournamentStatus.completed:
        return 'Terminé';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.emoji_events_rounded,
      title: 'Tournois internes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.tournaments.isEmpty)
            Text(
              'Aucun tournoi pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...state.tournaments.map((t) {
              final clubName = state.clubs
                  .where((cl) => cl.id == t.clubId)
                  .firstOrNull
                  ?.name;
              return GestureDetector(
                onTap: () => _openManage(context, t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: AppTypography.headlineSmall),
                            Text(
                              '${_statusLabel(t.status)} · '
                              '${t.participantIds.length} inscrit(s)'
                              '${clubName != null ? ' · $clubName' : ''}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un tournoi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _CourtsManagementSection({required this.state});

  void _openForm(BuildContext context, {CourtModel? court}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CourtFormScreen(
          court: court,
          clubs: state.clubs,
          scenarios: state.scenarios,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.location_on_rounded,
      title: 'Terrains',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.courts.isEmpty)
            Text(
              'Aucun terrain pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...state.courts.map((c) {
              final clubName = state.clubs
                  .where((cl) => cl.id == c.clubId)
                  .firstOrNull
                  ?.name;
              return GestureDetector(
                onTap: () => _openForm(context, court: c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: AppTypography.headlineSmall),
                            Text(
                              '${c.type.label} · ${c.surface.label}'
                              '${clubName != null ? ' · $clubName' : ''}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un terrain'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _EventsManagementSection({required this.state});

  void _openForm(BuildContext context, {ClubEventModel? event}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          event: event,
          clubs: state.clubs,
          courts: state.courts,
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.events]..sort((a, b) => a.date.compareTo(b.date));
    return _SectionCard(
      icon: Icons.event_rounded,
      title: 'Événements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sorted.isEmpty)
            Text(
              'Aucun événement pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...sorted.map(
              (e) => GestureDetector(
                onTap: () => _openForm(context, event: e),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, style: AppTypography.headlineSmall),
                            Text(
                              '${_fmt(e.date)} · ${e.clubName} · ${e.participantIds.length} participant(s)',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un événement'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatSection extends StatelessWidget {
  final List<UserModel> players;

  const _GroupChatSection({required this.players});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.groups_rounded,
      title: 'Conversation de groupe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Démarre une conversation avec plusieurs joueurs à la fois.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => GroupChatFormScreen(players: players),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer une conversation de groupe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminsSection extends StatelessWidget {
  final List<UserModel> admins;

  const _AdminsSection({required this.admins});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.shield_rounded,
      title: 'Administrateurs',
      child: admins.isEmpty
          ? Text('Aucun administrateur trouvé.', style: AppTypography.bodySmall)
          : Column(
              children: admins
                  .map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          AppAvatar(
                            initials: u.initials,
                            imageUrl: u.profileImageUrl,
                            size: 36,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: AppTypography.headlineSmall,
                                ),
                                Text(u.email, style: AppTypography.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

/// Non-admin (or admin) people the admin has chosen to surface in
/// "Contacts du club" on players' profiles — e.g. a treasurer or coach.
/// Separate from `_AdminsSection` above, which only lists real admin
/// accounts and isn't editable here.
class _ClubContactsSection extends StatelessWidget {
  final ManagerState state;
  final ManagerViewModel vm;

  const _ClubContactsSection({required this.state, required this.vm});

  String _playerName(String userId) =>
      state.players.where((u) => u.id == userId).firstOrNull?.name ??
      'Joueur';

  String _clubName(String clubId) =>
      state.clubs.where((c) => c.id == clubId).firstOrNull?.name ?? '';

  Future<void> _openAddSheet(BuildContext context) async {
    String? clubId = state.clubs.length == 1 ? state.clubs.first.id : null;
    UserModel? player;
    final roleController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ajouter un contact', style: AppTypography.headlineSmall),
                if (state.clubs.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Club', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: state.clubs
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c.name),
                            selected: clubId == c.id,
                            onSelected: (_) => setSheetState(() {
                              clubId = c.id;
                              player = null;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('Personne', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: clubId == null
                      ? null
                      : () async {
                          final roster = state.players
                              .where((u) => u.clubIds.contains(clubId))
                              .toList();
                          final picked = await PlayerPickerSheet.show(
                            sheetContext,
                            players: roster,
                            selectedPlayerId: player?.id,
                            title: 'Personne à contacter',
                          );
                          if (picked is UserModel) {
                            setSheetState(() => player = picked);
                          }
                        },
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: Text(player?.name ?? 'Choisir une personne'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Statut', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                    hintText: 'Ex : Trésorier, Coach...',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Ajouter',
                  onTap: (clubId == null ||
                          player == null ||
                          roleController.text.trim().isEmpty)
                      ? null
                      : () async {
                          final ok = await vm.addClubContact(
                            clubId!,
                            player!.id,
                            roleController.text.trim(),
                          );
                          if (ok && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.contact_page_outlined,
      title: 'Contacts du club',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personnes affichées sur le profil des joueurs, même si elles ne sont pas admin.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.clubContacts.isEmpty)
            Text('Aucun contact ajouté.', style: AppTypography.bodySmall)
          else
            Column(
              children: state.clubContacts
                  .map(
                    (contact) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _playerName(contact.userId),
                                  style: AppTypography.headlineSmall,
                                ),
                                Text(
                                  state.clubs.length > 1
                                      ? '${contact.roleLabel} · ${_clubName(contact.clubId)}'
                                      : contact.roleLabel,
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => vm.removeClubContact(contact.id),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.clubs.isEmpty
                ? null
                : () => _openAddSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter un contact'),
          ),
        ],
      ),
    );
  }
}

/// Read-only preview of what players see in "Contacter l'admin du club"
/// (see `_AdminContactSection` in `profile_screen.dart`) — the actual
/// editing happens on the existing profile-edit screen (nom/téléphone),
/// reused here rather than duplicating a form; email is locked there too,
/// same as for players.
class _ContactInfoSection extends ConsumerWidget {
  const _ContactInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.badge_outlined,
      title: 'Mes informations de contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coordonnées vues par les joueurs de ton club sur leur profil.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(user.name, style: AppTypography.headlineSmall),
          Text(user.email, style: AppTypography.bodySmall),
          Text(
            (user.phone == null || user.phone!.isEmpty)
                ? 'Téléphone non renseigné'
                : user.phone!,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Modifier'),
          ),
        ],
      ),
    );
  }
}

/// Support ("SAV") contacts — read-only, populated by hand in the Firebase
/// console (see `SavRepository`).
class _SavSection extends ConsumerWidget {
  const _SavSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(savContactsProvider);

    return _SectionCard(
      icon: Icons.support_agent_rounded,
      title: 'Contacter le SAV',
      child: contactsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) =>
            Text('Impossible de charger le SAV.', style: AppTypography.bodySmall),
        data: (contacts) => contacts.isEmpty
            ? Text('Aucun contact SAV renseigné.', style: AppTypography.bodySmall)
            : Column(
                children: contacts
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SavContactRow(contact: c),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class _SavContactRow extends StatelessWidget {
  final SavContactModel contact;

  const _SavContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${contact.prenom} ${contact.nom}'.trim(),
            style: AppTypography.headlineSmall,
          ),
          if (contact.mail != null && contact.mail!.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(
                Uri(scheme: 'mailto', path: contact.mail),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                contact.mail!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          if (contact.numero != null && contact.numero!.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(
                Uri(scheme: 'tel', path: contact.numero),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                contact.numero!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
