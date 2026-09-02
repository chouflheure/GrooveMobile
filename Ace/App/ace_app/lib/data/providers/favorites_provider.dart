import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]);

  void toggle(String userId) {
    if (state.contains(userId)) {
      state = state.where((id) => id != userId).toList();
    } else {
      state = [...state, userId];
    }
  }

  bool isFavorite(String userId) => state.contains(userId);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>(
  (ref) => FavoritesNotifier(),
);
