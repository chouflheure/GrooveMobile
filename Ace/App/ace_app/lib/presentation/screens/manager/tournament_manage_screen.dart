import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import 'manager_view_model.dart';

/// Admin's tournament control room — registered players (while
/// `status == registration`), then the bracket once it's drawn, with
/// per-match "programmer" / "désigner le vainqueur" actions.
class TournamentManageScreen extends ConsumerStatefulWidget {
  final TournamentModel tournament;

  const TournamentManageScreen({super.key, required this.tournament});

  @override
  ConsumerState<TournamentManageScreen> createState() =>
      _TournamentManageScreenState();
}

class _TournamentManageScreenState
    extends ConsumerState<TournamentManageScreen> {
  final _searchController = TextEditingController();
  bool _isGenerating = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _playerName(ManagerState state, String playerId) =>
      state.players.where((u) => u.id == playerId).firstOrNull?.name ??
      'Joueur';

  Future<void> _generateBracket(TournamentModel tournament) async {
    setState(() => _isGenerating = true);
    // Read fresh rather than reusing a captured notifier — this can run
    // well after `build()` produced the button, and `managerViewModelProvider`
    // rebuilds (disposing the old notifier) whenever its own `ref.watch`
    // dependencies (e.g. the live user list) re-emit in the meantime.
    await ref
        .read(managerViewModelProvider.notifier)
        .generateTournamentBracket(tournament);
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _delete(TournamentModel tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce tournoi ?'),
        content: Text(
          '"${tournament.title}" sera définitivement supprimé. Les réservations déjà programmées ne seront pas annulées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    final ok = await ref
        .read(managerViewModelProvider.notifier)
        .deleteTournament(tournament.id, tournament.title);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  /// Single sheet for everything a tapped match card can need: set/change
  /// its court, date and time, and — once both players are known — declare
  /// the winner. Rescheduling cancels the previous booking (if any) before
  /// creating the new one, same as picking a slot an event is taking over.
  Future<void> _openMatchSheet(
    ManagerState state,
    TournamentModel tournament,
    TournamentMatch match,
  ) async {
    final clubCourts = state.courts
        .where((c) => c.clubId == tournament.clubId)
        .toList();
    String? courtId =
        match.courtId ?? (clubCourts.length == 1 ? clubCourts.first.id : null);
    DateTime date = match.date ?? AppConstants.today();
    String time = match.startTime ?? AppConstants.timeSlots.first;
    bool isScheduling = false;

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
                Text(
                  '${_playerName(state, match.playerAId!)} vs '
                  '${_playerName(state, match.playerBId!)}',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Terrain et horaire', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setSheetState(
                              () => date = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: time,
                        items: AppConstants.timeSlots
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (t) {
                          if (t != null) setSheetState(() => time = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CourtPicker(
                  courts: clubCourts,
                  selectedCourtId: courtId,
                  onSelect: (id) => setSheetState(() => courtId = id),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: match.isScheduled
                      ? 'Mettre à jour le créneau'
                      : 'Programmer',
                  isLoading: isScheduling,
                  onTap: courtId == null
                      ? null
                      : () async {
                          final court = clubCourts.firstWhere(
                            (c) => c.id == courtId,
                          );
                          setSheetState(() => isScheduling = true);
                          await ref
                              .read(managerViewModelProvider.notifier)
                              .scheduleTournamentMatch(
                                tournament,
                                match,
                                court: court,
                                date: date,
                                startTime: time,
                              );
                          if (sheetContext.mounted) {
                            setSheetState(() => isScheduling = false);
                          }
                        },
                ),
                if (!match.isPlayed) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Vainqueur', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ...[match.playerAId, match.playerBId].whereType<String>().map(
                    (id) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_playerName(state, id)),
                      trailing: const Icon(
                        Icons.emoji_events_outlined,
                        color: AppColors.primary,
                      ),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(managerViewModelProvider.notifier)
                            .setTournamentMatchWinner(tournament, match, id);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerViewModelProvider);
    final tournament = state.tournaments
        .where((t) => t.id == widget.tournament.id)
        .firstOrNull ?? widget.tournament;

    final clubMembers = state.players
        .where((u) => u.clubIds.contains(tournament.clubId))
        .toList();
    final registered = clubMembers
        .where((u) => tournament.participantIds.contains(u.id))
        .toList();
    final query = _searchController.text.trim().toLowerCase();
    final candidates = clubMembers
        .where((u) => !tournament.participantIds.contains(u.id))
        .where((u) => query.isEmpty || u.name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(tournament.title),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : () => _delete(tournament),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (tournament.status == TournamentStatus.registration) ...[
            Text('Inscrits', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            if (registered.isEmpty)
              Text('Aucun inscrit pour le moment.', style: AppTypography.bodySmall)
            else
              ...registered.map(
                (u) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(u.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error),
                    onPressed: () => ref
                        .read(managerViewModelProvider.notifier)
                        .setTournamentParticipant(tournament, u.id, false),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Ajouter un membre du club...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...candidates
                .take(8)
                .map(
                  (u) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(u.name),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () => ref
                          .read(managerViewModelProvider.notifier)
                          .setTournamentParticipant(tournament, u.id, true),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Clore les inscriptions et tirer le bracket',
              onTap: registered.length < 2
                  ? null
                  : () => _generateBracket(tournament),
              isLoading: _isGenerating,
            ),
          ] else ...[
            if (tournament.status == TournamentStatus.completed)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'Tournoi terminé 🏆',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TournamentBracket(
              tournament: tournament,
              playerName: (id) => _playerName(state, id),
              onTapMatch: (m) => _openMatchSheet(state, tournament, m),
            ),
          ],
        ],
      ),
    );
  }
}
