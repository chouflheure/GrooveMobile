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

  /// Closes registration and draws the bracket — random seeding, byes for
  /// anyone left over once the participant count is rounded up to the next
  /// power of 2 (see `generateBracketMatches`).
  Future<void> generateBracket(TournamentModel tournament) {
    final matches = generateBracketMatches(tournament.participantIds);
    return update(
      tournament.copyWith(
        status: TournamentStatus.inProgress,
        matches: matches,
      ),
    );
  }

  /// Records who won `match` and advances them into their next-round slot
  /// (see `advanceWinner`); flips the tournament to `completed` once the
  /// final's winner is set.
  Future<void> setMatchWinner(
    TournamentModel tournament,
    TournamentMatch match,
    String winnerId,
  ) {
    final matches = advanceWinner(tournament.matches, match, winnerId);
    final isFinal = match.round == tournament.roundCount;
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
}
