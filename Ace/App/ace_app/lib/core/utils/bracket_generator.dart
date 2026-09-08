import 'dart:math';

import '../../data/models/tournament_model.dart';

/// Smallest power of 2 that is `>= n` (bracket sizes only ever come in
/// powers of 2 — byes fill the gap when the real participant count isn't
/// one already).
int _bracketSizeFor(int n) {
  var size = 1;
  while (size < n) {
    size *= 2;
  }
  return size;
}

/// Builds every round of a single-elimination bracket for `participantIds`,
/// pre-populated with `TBD` (both players null) beyond round 1. Byes are
/// resolved immediately: a round-1 match with only one real player already
/// carries its `winnerId` and that winner is placed straight into their
/// round-2 slot, so the admin never has to "play" a bye.
///
/// A `random` can be injected for deterministic tests; production calls
/// leave it null and get a real shuffle.
List<TournamentMatch> generateBracketMatches(
  List<String> participantIds, {
  Random? random,
}) {
  final rng = random ?? Random();
  final shuffled = List<String>.of(participantIds)..shuffle(rng);

  final size = _bracketSizeFor(shuffled.length);
  final byes = size - shuffled.length;

  // Deal `byes` matches a single real player + an empty slot, and the rest
  // two real players each — never two empty slots in the same match, which
  // a naive "shuffle everyone (including nulls) then pair up" risks
  // whenever `byes >= 2` (an unplayable, unwinnable match). `byes` is
  // always `< size / 2` (the match count) by definition of "smallest power
  // of 2 >= n", so there's always enough real matches to hold the rest.
  final pairs = <List<String?>>[];
  var idx = 0;
  for (var i = 0; i < byes; i++) {
    pairs.add([shuffled[idx], null]);
    idx++;
  }
  while (idx < shuffled.length) {
    pairs.add([shuffled[idx], shuffled[idx + 1]]);
    idx += 2;
  }
  pairs.shuffle(rng); // randomize which bracket position gets a bye

  var round1 = <TournamentMatch>[];
  for (var i = 0; i < pairs.length; i++) {
    final a = pairs[i][0];
    final b = pairs[i][1];
    round1.add(
      TournamentMatch(
        round: 1,
        position: i,
        playerAId: a,
        playerBId: b,
        // Exactly one side empty -> the other side auto-wins the bye.
        winnerId: (a == null) != (b == null) ? (a ?? b) : null,
      ),
    );
  }

  final matches = <TournamentMatch>[...round1];
  var roundMatches = round1;
  var round = 2;
  while (roundMatches.length > 1) {
    final nextCount = roundMatches.length ~/ 2;
    final nextRound = List.generate(
      nextCount,
      (i) => TournamentMatch(round: round, position: i),
    );
    matches.addAll(nextRound);
    roundMatches = nextRound;
    round++;
  }

  // Propagate round-1 byes into round 2 immediately. This never cascades
  // further: byes are always fewer than half the bracket size (by
  // definition of "smallest power of 2 >= n"), so even in the unlikely case
  // two byes feed the same round-2 slot, that slot ends up with two real
  // (bye-winning) players — a normal match, not a further bye.
  var result = matches;
  for (final m in round1) {
    if (m.winnerId != null) {
      result = advanceWinner(result, m, m.winnerId!);
    }
  }
  return result;
}

/// Records `winnerId` on `match` and, unless it was the final, places that
/// winner into their slot (`position ~/ 2`, side A if `position` was even
/// else B) in the next round. Returns a new list; doesn't mutate `matches`.
List<TournamentMatch> advanceWinner(
  List<TournamentMatch> matches,
  TournamentMatch match,
  String winnerId,
) {
  final maxRound = matches.map((m) => m.round).reduce((a, b) => a > b ? a : b);
  var updated = [
    for (final m in matches)
      if (m.round == match.round && m.position == match.position)
        m.copyWith(winnerId: winnerId)
      else
        m,
  ];
  if (match.round == maxRound) return updated;

  final nextRound = match.round + 1;
  final nextPosition = match.position ~/ 2;
  final nextIndex = updated.indexWhere(
    (m) => m.round == nextRound && m.position == nextPosition,
  );
  if (nextIndex == -1) return updated;

  final next = updated[nextIndex];
  final placedOnA = match.position.isEven;
  final updatedNext = placedOnA
      ? next.copyWith(playerAId: winnerId)
      : next.copyWith(playerBId: winnerId);
  updated = [
    for (var i = 0; i < updated.length; i++)
      if (i == nextIndex) updatedNext else updated[i],
  ];

  return updated;
}
