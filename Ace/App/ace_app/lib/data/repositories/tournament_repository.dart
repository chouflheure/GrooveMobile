import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/bracket_generator.dart';
import '../models/tournament_model.dart';

class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tournaments');

  Future<TournamentModel?> getById(String tournamentId) async {
    final doc = await _collection.doc(tournamentId).get();
    if (!doc.exists) return null;
    return TournamentModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Stream<List<TournamentModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => TournamentModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
    );
  }

  Future<void> create(TournamentModel tournament) {
    final docRef = _collection.doc();
    return docRef.set({...tournament.toJson(), 'id': docRef.id});
  }

  Future<void> update(TournamentModel tournament) {
    return _collection.doc(tournament.id).set(tournament.toJson());
  }

  Future<void> delete(String tournamentId) {
    return _collection.doc(tournamentId).delete();
  }

  Future<void> setParticipating(
    String tournamentId,
    String userId,
    bool participating,
  ) {
    return _collection.doc(tournamentId).update({
      'participantIds': participating
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  /// Composes and appends the next round — `round = tournament.roundCount +
  /// 1` (1 if no round exists yet). `pairs` becomes that round's real
  /// matches, `byePlayers` its auto-resolved solo ones (see
  /// `buildRoundMatches`); whoever fed into this round from the previous one
  /// gets `feedsRound`/`feedsPosition`/`feedsSideA` written onto their match
  /// there (see `attachFeeds`) so the bracket can draw the connector. Both
  /// the admin's manual pairing and a random draw (shuffled client-side —
  /// see `TournamentManageScreen`) go through this same entry point,
  /// whatever round it's for.
  Future<void> composeRound(
    TournamentModel tournament,
    List<(String, String)> pairs,
    List<String> byePlayers,
  ) {
    final round = tournament.roundCount + 1;
    final newRound = buildRoundMatches(round, pairs, byePlayers);
    final matches = attachFeeds(tournament.matches, round - 1, newRound);
    return update(
      tournament.copyWith(
        status: TournamentStatus.inProgress,
        matches: matches,
      ),
    );
  }

  /// Records who won `match` (see `setWinner`) — no auto-propagation, since
  /// the next round only exists once the admin composes it. Flips the
  /// tournament to `completed` once this was the round's only match (i.e.
  /// its two players were the whole remaining field) and it now has a
  /// winner.
  Future<void> setMatchWinner(
    TournamentModel tournament,
    TournamentMatch match,
    String winnerId,
  ) {
    final matches = setWinner(tournament.matches, match, winnerId);
    final isFinal =
        match.round == tournament.roundCount &&
        tournament.matchesInRound(match.round).length == 1;
    return update(
      tournament.copyWith(
        matches: matches,
        status: isFinal ? TournamentStatus.completed : tournament.status,
      ),
    );
  }

  /// Attaches a court/date/time to `match` — the caller is responsible for
  /// actually creating the two-player booking first (see
  /// `ManagerViewModel.scheduleTournamentMatch`) and passing its id here.
  Future<void> scheduleMatch(
    TournamentModel tournament,
    TournamentMatch match, {
    required String courtId,
    required String courtName,
    required DateTime date,
    required String startTime,
    required String bookingId,
  }) {
    final matches = [
      for (final m in tournament.matches)
        if (m.round == match.round && m.position == match.position)
          m.copyWith(
            courtId: courtId,
            courtName: courtName,
            date: date,
            startTime: startTime,
            bookingId: bookingId,
          )
        else
          m,
    ];
    return update(tournament.copyWith(matches: matches));
  }

  /// Swaps two players wherever each currently sits in the bracket (any
  /// round, any side) — lets the admin adjust a draw without regenerating
  /// it. The caller (see `TournamentManageScreen`) only offers this while
  /// no match anywhere has a winner yet, so there's no risk of moving a
  /// player out from under a result that already happened.
  Future<void> swapPlayers(
    TournamentModel tournament,
    String playerAId,
    String playerBId,
  ) {
    String? swapped(String? current) {
      if (current == playerAId) return playerBId;
      if (current == playerBId) return playerAId;
      return current;
    }

    final matches = [
      for (final m in tournament.matches)
        m.copyWith(
          playerAId: swapped(m.playerAId),
          playerBId: swapped(m.playerBId),
        ),
    ];
    return update(tournament.copyWith(matches: matches));
  }
}
