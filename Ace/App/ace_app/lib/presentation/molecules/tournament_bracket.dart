import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';

const double _cardWidth = 200;
const double _cardHeight = 92;
const double _cardGap = 16;
const double _columnGap = 32;

/// Renders a single-elimination bracket, Roland-Garos-style: a row of round
/// tabs to jump to a column, and matches laid out and connected with lines
/// exactly like a real bracket. Since each round is composed by the admin
/// one at a time (see `TournamentRepository.composeRound`) rather than a
/// fixed tree generated upfront, a round's matches can freely mix any
/// winners/byes from the previous round — so vertical centering and the
/// connector lines are derived from each match's actual `feedsPosition`
/// (written retroactively when the *next* round gets composed — see
/// `attachFeeds` in bracket_generator.dart) rather than an assumed halving
/// formula.
///
/// Read-only when [onTapMatch] is null (the player-facing view); passing it
/// makes every match with both players known tappable — the caller (see
/// `TournamentManageScreen`) opens one sheet from there handling both
/// scheduling and picking the winner, so any part of the bracket the admin
/// taps leads to the same "manage this match" place.
class TournamentBracket extends StatefulWidget {
  final TournamentModel tournament;
  final String Function(String playerId) playerName;
  final ValueChanged<TournamentMatch>? onTapMatch;

  const TournamentBracket({
    super.key,
    required this.tournament,
    required this.playerName,
    this.onTapMatch,
  });

  @override
  State<TournamentBracket> createState() => _TournamentBracketState();
}

class _TournamentBracketState extends State<TournamentBracket> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Any match with at least one known player is worth tapping — even one
  // not yet "ready to play" (waiting on a previous round) still has a
  // known side the admin might want to swap out. A wholly-TBD match (both
  // sides still empty) has nothing to act on yet.
  VoidCallback? _tapHandler(TournamentMatch m) {
    if (widget.onTapMatch == null) return null;
    if (m.playerAId == null && m.playerBId == null) return null;
    return () => widget.onTapMatch!(m);
  }

  // A round's "shape" (final / semi-final / just "Tour N") is read off how
  // many matches it actually has — a real final always has exactly one (two
  // players left), a semi exactly two — rather than its position relative
  // to the latest composed round, since with rounds composed freely one at
  // a time there's no way to know in advance how many rounds there'll be
  // (round 1 with 11 players is obviously not "the final" just because
  // nothing's been composed after it yet).
  String _roundLabel(TournamentModel tournament, int round) {
    final count = tournament.matchesInRound(round).length;
    if (count == 1) return 'Finale';
    if (count == 2) return 'Demi-finale';
    return 'Tour $round';
  }

  @override
  Widget build(BuildContext context) {
    final tournament = widget.tournament;
    final totalRounds = tournament.roundCount;
    if (totalRounds == 0) {
      return Text(
        'Le bracket n\'a pas encore été tiré.',
        style: AppTypography.bodySmall,
      );
    }

    final round1Count = tournament.matchesInRound(1).length;

    // Center-Y of every match, round 1 evenly spaced, every round after
    // that centered between whichever round-N matches actually feed it
    // (via `feedsPosition` — not assumed to be a fixed `2p, 2p+1` pair,
    // since pairing is composed freely each round).
    final centerY = <String, double>{};
    for (var i = 0; i < round1Count; i++) {
      centerY['1-$i'] = i * (_cardHeight + _cardGap) + _cardHeight / 2;
    }
    for (var round = 2; round <= totalRounds; round++) {
      final sources = tournament
          .matchesInRound(round - 1)
          .where((m) => m.feedsRound == round);
      final byTarget = <int, List<double>>{};
      for (final m in sources) {
        final y = centerY['${round - 1}-${m.position}'];
        if (y == null) continue;
        byTarget.putIfAbsent(m.feedsPosition!, () => []).add(y);
      }
      byTarget.forEach((position, ys) {
        centerY['$round-$position'] =
            ys.reduce((a, b) => a + b) / ys.length;
      });
    }
    final totalHeight = round1Count * (_cardHeight + _cardGap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundTabs(
          totalRounds: totalRounds,
          label: (round, _) => _roundLabel(tournament, round),
          onSelect: (round) {
            final offset = (round - 1) * (_cardWidth + _columnGap);
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalRounds * (_cardWidth + _columnGap),
            height: totalHeight + 32,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(
                    totalRounds * (_cardWidth + _columnGap),
                    totalHeight,
                  ),
                  painter: _ConnectorPainter(
                    tournament: tournament,
                    totalRounds: totalRounds,
                    centerY: centerY,
                  ),
                ),
                for (var round = 1; round <= totalRounds; round++)
                  Positioned(
                    left: (round - 1) * (_cardWidth + _columnGap),
                    top: 0,
                    child: SizedBox(
                      width: _cardWidth,
                      child: Text(
                        _roundLabel(tournament, round),
                        style: AppTypography.labelLarge,
                      ),
                    ),
                  ),
                for (var round = 1; round <= totalRounds; round++)
                  for (final m in tournament.matchesInRound(round))
                    Positioned(
                      left: (round - 1) * (_cardWidth + _columnGap),
                      top: 32 +
                          (centerY['$round-${m.position}'] ?? 0) -
                          _cardHeight / 2,
                      width: _cardWidth,
                      height: _cardHeight,
                      child: _MatchCard(
                        match: m,
                        playerName: widget.playerName,
                        onTap: _tapHandler(m),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the classic bracket connector lines — for every round before the
/// final: groups that round's matches by the round-N+1 position they feed
/// (`feedsPosition`, always 1 or 2 matches per group — a target match's two
/// sides each trace back to exactly one round-N match), then draws a
/// horizontal stub out of each, a vertical bar joining them, and a
/// horizontal stub into the target match's left edge — using the
/// pre-computed `centerY`.
class _ConnectorPainter extends CustomPainter {
  final TournamentModel tournament;
  final int totalRounds;
  final Map<String, double> centerY;

  _ConnectorPainter({
    required this.tournament,
    required this.totalRounds,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2;

    for (var round = 1; round < totalRounds; round++) {
      final colX = (round - 1) * (_cardWidth + _columnGap);
      final rightX = colX + _cardWidth;
      final midX = rightX + _columnGap / 2;
      final nextLeftX = colX + (_cardWidth + _columnGap);

      final byTarget = <int, List<double>>{};
      for (final m in tournament.matchesInRound(round)) {
        if (m.feedsRound != round + 1) continue;
        final y = centerY['$round-${m.position}'];
        if (y == null) continue;
        byTarget.putIfAbsent(m.feedsPosition!, () => []).add(y + 32);
      }

      byTarget.forEach((position, ys) {
        for (final y in ys) {
          canvas.drawLine(Offset(rightX, y), Offset(midX, y), paint);
        }
        final parentY = ys.reduce((a, b) => a + b) / ys.length;
        if (ys.length > 1) {
          canvas.drawLine(
            Offset(midX, ys.reduce((a, b) => a < b ? a : b)),
            Offset(midX, ys.reduce((a, b) => a > b ? a : b)),
            paint,
          );
        }
        canvas.drawLine(Offset(midX, parentY), Offset(nextLeftX, parentY), paint);
      });
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.tournament != tournament;
}

class _RoundTabs extends StatelessWidget {
  final int totalRounds;
  final String Function(int round, int totalRounds) label;
  final ValueChanged<int> onSelect;

  const _RoundTabs({
    required this.totalRounds,
    required this.label,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalRounds,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final round = i + 1;
          return GestureDetector(
            onTap: () => onSelect(round),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                label(round, totalRounds),
                style: AppTypography.labelMedium,
              ),
            ),
          );
        },
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

  bool get _isBye => match.playerBId == null && match.winnerId == match.playerAId;

  String _label(String? playerId) =>
      playerId == null ? 'À déterminer' : playerName(playerId);

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlayerLine(
              label: _label(match.playerAId),
              isWinner:
                  match.winnerId != null && match.winnerId == match.playerAId,
            ),
            const SizedBox(height: 2),
            _PlayerLine(
              label: _isBye ? 'Exempté' : _label(match.playerBId),
              isWinner:
                  match.winnerId != null && match.winnerId == match.playerBId,
            ),
            if (match.isScheduled)
              Text(
                '${match.courtName} · ${match.startTime}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else if (onTap != null && match.isReadyToPlay)
              Text(
                'Programmer',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  final String label;
  final bool isWinner;

  const _PlayerLine({required this.label, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMedium.copyWith(
        color: isWinner ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}
