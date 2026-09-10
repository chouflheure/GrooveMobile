import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import 'manager_view_model.dart';
import 'match_form_screen.dart';

/// Admin's tournament control room — a round is always composed the same
/// way, whether it's the very first (from the registered players) or a
/// later one (from whoever's left after the previous round: winners +
/// byes) — see `_poolForNextRound`. Once composed, the bracket below shows
/// every round played so far, with per-match "programmer" / "désigner le
/// vainqueur" actions.
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
  bool _manualMode = false;
  final List<(String, String)> _manualPairs = [];
  String? _pendingPick;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _playerName(ManagerState state, String playerId) =>
      state.players.where((u) => u.id == playerId).firstOrNull?.name ??
      'Joueur';

  /// Who's available to be paired into the next round — `null` means there's
  /// nothing to compose right now (tournament already finished, or the
  /// latest round is still waiting on results). An empty `matches` list
  /// means round 1, composed from the registered players; otherwise it's
  /// whoever came out of the latest round (winners of real matches, and
  /// byes, in position order).
  List<UserModel>? _poolForNextRound(
    ManagerState state,
    TournamentModel tournament,
    List<UserModel> registered,
  ) {
    if (tournament.status == TournamentStatus.completed) return null;
    if (tournament.matches.isEmpty) return registered;
    final latest = tournament.matchesInRound(tournament.roundCount);
    if (!latest.every((m) => m.winnerId != null)) return null;
    return latest
        .map((m) => state.players.where((u) => u.id == m.winnerId).firstOrNull)
        .whereType<UserModel>()
        .toList();
  }

  Future<void> _generateRandom(TournamentModel tournament, List<UserModel> pool) async {
    final shuffled = List<UserModel>.of(pool)..shuffle(Random());
    final pairs = <(String, String)>[];
    for (var i = 0; i + 1 < shuffled.length; i += 2) {
      pairs.add((shuffled[i].id, shuffled[i + 1].id));
    }
    final byes = shuffled.length.isOdd ? [shuffled.last.id] : <String>[];
    setState(() => _isGenerating = true);
    // Read fresh rather than reusing a captured notifier — this can run
    // well after `build()` produced the button, and `managerViewModelProvider`
    // rebuilds (disposing the old notifier) whenever its own `ref.watch`
    // dependencies (e.g. the live user list) re-emit in the meantime.
    await ref
        .read(managerViewModelProvider.notifier)
        .composeTournamentRound(tournament, pairs, byes);
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _generateManual(
    TournamentModel tournament,
    List<String> byeIds,
  ) async {
    setState(() => _isGenerating = true);
    await ref
        .read(managerViewModelProvider.notifier)
        .composeTournamentRound(tournament, _manualPairs, byeIds);
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _manualMode = false;
      _manualPairs.clear();
      _pendingPick = null;
    });
  }

  /// Lets the admin pick this round's pairs by hand — tap two players from
  /// `pool` in turn to pair them, any number of pairs from 0 up to
  /// `pool.length ~/ 2`; whoever's left unpaired becomes this round's bye
  /// list automatically once generated.
  Widget _buildRoundComposer(
    TournamentModel tournament,
    List<UserModel> pool,
    int roundNumber,
  ) {
    final pairedIds = _manualPairs.expand((p) => [p.$1, p.$2]).toSet();
    final available = pool.where((u) => !pairedIds.contains(u.id)).toList();

    void tapPlayer(String userId) {
      setState(() {
        if (_pendingPick == null) {
          _pendingPick = userId;
        } else if (_pendingPick == userId) {
          _pendingPick = null;
        } else {
          _manualPairs.add((_pendingPick!, userId));
          _pendingPick = null;
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_manualPairs.length} match(s) composé(s) pour le tour $roundNumber'
          '${available.isNotEmpty ? ' — ${available.length} joueur(s) seront exempté(s) ce tour si tu génères maintenant.' : '.'}',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_manualPairs.isNotEmpty)
          ..._manualPairs.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pool.where((u) => u.id == p.$1).firstOrNull?.name ?? '?'} '
                      'vs '
                      '${pool.where((u) => u.id == p.$2).firstOrNull?.name ?? '?'}',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _manualPairs.remove(p)),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty) ...[
          Text('Joueurs disponibles', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: available.map((u) {
              final isSelected = _pendingPick == u.id;
              return GestureDetector(
                onTap: () => tapPlayer(u.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    u.name,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _manualMode = false;
                  _manualPairs.clear();
                  _pendingPick = null;
                }),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Composer ce tour',
                isLoading: _isGenerating,
                onTap: _manualPairs.isEmpty
                    ? null
                    : () => _generateManual(
                        tournament,
                        available.map((u) => u.id).toList(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _delete(TournamentModel tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce tournoi ?'),
        content: Text(
          '"${tournament.title}" sera définitivement supprimé. Les créneaux déjà programmés pour ses matchs seront annulés.',
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
        .deleteTournament(tournament);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  /// Single sheet for everything a tapped match card can need: swap out a
  /// known player (only while this is the latest round and it hasn't been
  /// played yet — `canEditRoster`), schedule it (pushes `MatchFormScreen`,
  /// the same full-featured court/slot picker used for a regular match —
  /// see `startTournamentMatchForm`), and declare the winner.
  Future<void> _openMatchSheet(
    ManagerState state,
    TournamentModel tournament,
    TournamentMatch match,
  ) async {
    final roundMatches = tournament.matchesInRound(match.round);
    // Per-match, not per-round: a result already recorded on some other
    // match of this round shouldn't block editing the ones still unplayed.
    final canEditRoster =
        match.round == tournament.roundCount && match.winnerId == null;
    final scoreController = TextEditingController(text: match.score ?? '');

    Future<void> swapPlayer(BuildContext sheetContext, String currentId) async {
      final roster = roundMatches
          .expand((m) => [m.playerAId, m.playerBId])
          .whereType<String>()
          .where((id) => id != currentId)
          .toSet()
          .map((id) => state.players.where((u) => u.id == id).firstOrNull)
          .whereType<UserModel>()
          .toList();
      final picked = await PlayerPickerSheet.show(
        sheetContext,
        players: roster,
        selectedPlayerId: null,
        title: 'Échanger ${_playerName(state, currentId)} avec…',
      );
      if (picked is! UserModel) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      await ref
          .read(managerViewModelProvider.notifier)
          .swapTournamentPlayers(tournament, currentId, picked.id);
    }

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
                  '${match.playerAId != null ? _playerName(state, match.playerAId!) : 'À déterminer'} vs '
                  '${match.playerBId != null ? _playerName(state, match.playerBId!) : 'À déterminer'}',
                  style: AppTypography.headlineSmall,
                ),
                if (canEditRoster) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [match.playerAId, match.playerBId]
                        .whereType<String>()
                        .map(
                          (id) => OutlinedButton.icon(
                            onPressed: () => swapPlayer(sheetContext, id),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: Text('Changer ${_playerName(state, id)}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (!match.isReadyToPlay) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Ce match attend encore le résultat du tour précédent.',
                    style: AppTypography.bodySmall,
                  ),
                ],
                if (match.isReadyToPlay) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: match.isScheduled
                        ? 'Modifier la programmation'
                        : 'Programmer ce match',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(managerViewModelProvider.notifier)
                          .startTournamentMatchForm(tournament, match);
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => const MatchFormScreen(),
                        ),
                      );
                    },
                  ),
                ],
                if (match.isReadyToPlay && !match.isPlayed) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Score (optionnel)', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: scoreController,
                    decoration: const InputDecoration(
                      hintText: 'Ex : 6-4, 6-3',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                        final score = scoreController.text.trim();
                        await ref
                            .read(managerViewModelProvider.notifier)
                            .setTournamentMatchWinner(
                              tournament,
                              match,
                              id,
                              score: score.isEmpty ? null : score,
                            );
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
    final pool = _poolForNextRound(state, tournament, registered);

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
          if (tournament.matches.isEmpty) ...[
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
          ],
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
          if (pool != null && pool.length >= 2) ...[
            if (!_manualMode) ...[
              AppButton(
                label: 'Tirage aléatoire',
                onTap: () => _generateRandom(tournament, pool),
                isLoading: _isGenerating,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _manualMode = true),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(
                    'Composer le tour ${tournament.roundCount + 1} moi-même',
                  ),
                ),
              ),
            ] else
              _buildRoundComposer(tournament, pool, tournament.roundCount + 1),
            const SizedBox(height: AppSpacing.lg),
          ] else if (pool == null &&
              tournament.status != TournamentStatus.completed &&
              tournament.matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                'En attente des résultats du tour en cours.',
                style: AppTypography.bodySmall,
              ),
            ),
          if (tournament.matches.isNotEmpty)
            TournamentBracket(
              tournament: tournament,
              playerName: (id) => _playerName(state, id),
              onTapMatch: (m) => _openMatchSheet(state, tournament, m),
            ),
        ],
      ),
    );
  }
}
