import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/tournament_repository.dart';

final tournamentRepositoryProvider = Provider<TournamentRepository>(
  (_) => TournamentRepository(),
);

final tournamentsProvider = StreamProvider<List<TournamentModel>>(
  (ref) => ref.watch(tournamentRepositoryProvider).watchAll(),
);
