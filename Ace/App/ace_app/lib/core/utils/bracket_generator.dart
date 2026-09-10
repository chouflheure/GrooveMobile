import '../../data/models/tournament_model.dart';

/// Builds the matches for one freshly-composed round: one entry per pair
/// (in order), then one entry per bye player — a solo match with
/// `playerBId: null` and `winnerId` already set to `playerAId`, since a bye
/// needs no result from the admin. Positions run continuously across both
/// groups. Knows nothing about any other round — see
/// `TournamentRepository.composeRound` for how this plugs into the rest of
/// the bracket.
List<TournamentMatch> buildRoundMatches(
  int round,
  List<(String, String)> pairs,
  List<String> byePlayers,
) {
  final matches = <TournamentMatch>[];
  for (final p in pairs) {
    matches.add(
      TournamentMatch(
        round: round,
        position: matches.length,
        playerAId: p.$1,
        playerBId: p.$2,
      ),
    );
  }
  for (final playerId in byePlayers) {
    matches.add(
      TournamentMatch(
        round: round,
        position: matches.length,
        playerAId: playerId,
        winnerId: playerId,
      ),
    );
  }
  return matches;
}

/// Writes `feedsRound`/`feedsPosition`/`feedsSideA` onto whichever match in
/// `sourceRound` produced each player now appearing in `newRound` — so the
/// bracket can draw a connector line from where a player came from to where
/// they landed. Returns a full, updated match list (`allMatches`'s round
/// `sourceRound` entries replaced, everything else untouched, `newRound`
/// appended). A no-op on the source round when `sourceRound < 1` (composing
/// round 1 — nothing feeds into it).
List<TournamentMatch> attachFeeds(
  List<TournamentMatch> allMatches,
  int sourceRound,
  List<TournamentMatch> newRound,
) {
  if (sourceRound < 1) return [...allMatches, ...newRound];

  final feedsByWinner = <String, (int, bool)>{};
  for (final m in newRound) {
    if (m.playerAId != null) feedsByWinner[m.playerAId!] = (m.position, true);
    if (m.playerBId != null) {
      feedsByWinner[m.playerBId!] = (m.position, false);
    }
  }

  final updated = [
    for (final m in allMatches)
      if (m.round == sourceRound &&
          m.winnerId != null &&
          feedsByWinner.containsKey(m.winnerId))
        m.copyWith(
          feedsRound: newRound.first.round,
          feedsPosition: feedsByWinner[m.winnerId]!.$1,
          feedsSideA: feedsByWinner[m.winnerId]!.$2,
        )
      else
        m,
  ];
  return [...updated, ...newRound];
}

/// Records `winnerId` on `match`. No propagation — the next round doesn't
/// exist yet until the admin composes it (`TournamentRepository.composeRound`
/// then calls `attachFeeds` to wire this match up to it).
List<TournamentMatch> setWinner(
  List<TournamentMatch> matches,
  TournamentMatch match,
  String winnerId, {
  String? score,
}) {
  return [
    for (final m in matches)
      if (m.round == match.round && m.position == match.position)
        m.copyWith(winnerId: winnerId, score: score)
      else
        m,
  ];
}
