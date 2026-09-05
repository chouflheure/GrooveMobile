import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/storage_repository.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepository(),
);
