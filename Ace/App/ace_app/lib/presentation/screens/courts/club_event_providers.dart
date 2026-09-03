import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/club_event_repository.dart';

final clubEventRepositoryProvider = Provider<ClubEventRepository>(
  (_) => ClubEventRepository(),
);

final clubEventsProvider = StreamProvider<List<ClubEventModel>>(
  (ref) => ref.watch(clubEventRepositoryProvider).watchAll(),
);
