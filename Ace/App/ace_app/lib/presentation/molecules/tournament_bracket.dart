import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';

/// Renders a single-elimination bracket, one scrollable column per round.
/// Read-only when [onTapMatch] is null (the player-facing view); passing it
/// makes every match with both players known tappable — the caller (see
/// `TournamentManageScreen`) opens one sheet from there handling both
/// scheduling and picking the winner, so any part of the bracket the admin
/// taps leads to the same "manage this match" place.
class TournamentBracket extends StatelessWidget {
  final TournamentModel tournament;
  final String Function(String playerId) playerName;
  final ValueChanged<TournamentMatch>? onTapMatch;

  const TournamentBracket({
    super.key,
    required this.tournament,
    required this.playerName,
    this.onTapMatch,
  });

  String _roundLabel(int round, int totalRounds) {
    if (round == totalRounds) return 'Finale';
    if (round == totalRounds - 1) return 'Demi-finale';
    return 'Tour $round';
  }

  @override
  Widget build(BuildContext context) {
    final totalRounds = tournament.roundCount;
    if (totalRounds == 0) {
      return Text(
        'Le bracket n\'a pas encore été tiré.',
        style: AppTypography.bodySmall,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalRounds, (i) {
          final round = i + 1;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roundLabel(round, totalRounds),
                    style: AppTypography.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...tournament.matchesInRound(round).map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MatchCard(
                        match: m,
                        playerName: playerName,
                        onTap: onTapMatch == null || !m.isReadyToPlay
                            ? null
                            : () => onTapMatch!(m),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final String Function(String playerId) playerName;
  final VoidCallback? onTap;

  const _MatchCard({
    required this.match,
    required this.playerName,
    required this.onTap,
  });

  // A bye's empty slot has no opponent coming, ever — distinct from a
  // "TBD" slot in round 2+ that's still waiting on an earlier match to be
  // played, so it gets its own label instead of the same "À déterminer".
  String _label(String? playerId) {
    if (playerId != null) return playerName(playerId);
    return match.isBye ? 'Exempt' : 'À déterminer';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: onTap != null ? AppColors.primary : AppColors.border,
            width: onTap != null ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerLine(
              label: _label(match.playerAId),
              isWinner:
                  match.winnerId != null && match.winnerId == match.playerAId,
              isBye: match.isBye && match.playerAId == null,
            ),
            const SizedBox(height: 2),
            _PlayerLine(
              label: _label(match.playerBId),
              isWinner:
                  match.winnerId != null && match.winnerId == match.playerBId,
              isBye: match.isBye && match.playerBId == null,
            ),
            if (match.isBye) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Qualifié d\'office (pas assez de joueurs pour ce tour)',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (match.isScheduled) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${match.courtName} · ${match.startTime}'
                '${match.date != null ? ' · ${match.date!.day.toString().padLeft(2, '0')}/${match.date!.month.toString().padLeft(2, '0')}' : ''}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                match.isScheduled ? 'Modifier' : 'Programmer',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  final String label;
  final bool isWinner;
  final bool isBye;

  const _PlayerLine({
    required this.label,
    required this.isWinner,
    this.isBye = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.bodyMedium.copyWith(
        color: isBye
            ? AppColors.textTertiary
            : isWinner
            ? AppColors.primary
            : AppColors.textPrimary,
        fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
        fontStyle: isBye ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}
