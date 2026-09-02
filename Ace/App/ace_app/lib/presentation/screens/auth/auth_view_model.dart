import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final userRepositoryProvider = Provider<UserRepository>((_) => UserRepository());

/// Raw Firebase Auth state — null means signed out (including guest browsing).
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// The signed-in player's Firestore profile, live. Null while browsing as a
/// guest — screens that need an identity (booking, posting, profile) must
/// handle that case rather than assuming a user exists.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchById(user.uid);
});

/// The full player directory — shared across every screen that needs to
/// resolve "who is this other user" (partner pickers, chat, announcements)
/// so they don't each open their own Firestore listener.
final allUsersProvider = StreamProvider<List<UserModel>>(
  (ref) => ref.watch(userRepositoryProvider).watchAll(),
);

class AuthActionState {
  final bool isLoading;
  final String? errorMessage;

  const AuthActionState({this.isLoading = false, this.errorMessage});
}

class AuthViewModel extends StateNotifier<AuthActionState> {
  AuthViewModel(this._authRepository, this._userRepository)
      : super(const AuthActionState());

  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthActionState(isLoading: true);
    try {
      await _authRepository.signIn(email: email, password: password);
      state = const AuthActionState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthActionState(errorMessage: _messageFor(e));
      return false;
    } catch (_) {
      state = const AuthActionState(errorMessage: 'Une erreur est survenue, réessaie.');
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthActionState(isLoading: true);
    try {
      final credential = await _authRepository.signUp(email: email, password: password);
      final uid = credential.user!.uid;
      await _userRepository.create(UserModel(
        id: uid,
        name: name,
        email: email,
        ranking: 'N.C.',
        location: '',
        rating: 0,
        memberSince: DateTime.now(),
        matchesPerMonth: 0,
        stats: const UserStats(matchesPlayed: 0, wins: 0, hoursPlayed: 0),
        surfaces: const SurfacePreferences(clay: 0, hard: 0, grass: 0),
      ));
      state = const AuthActionState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthActionState(errorMessage: _messageFor(e));
      return false;
    } catch (_) {
      state = const AuthActionState(errorMessage: 'Une erreur est survenue, réessaie.');
      return false;
    }
  }

  Future<void> signOut() => _authRepository.signOut();

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'invalid-email':
        return 'Adresse email invalide.';
      default:
        return 'Une erreur est survenue, réessaie.';
    }
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthActionState>(
  (ref) => AuthViewModel(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
