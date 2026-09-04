import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_view_model.dart';

enum PhoneAuthStep { enterNumber, enterCode, done }

class PhoneAuthState {
  final PhoneAuthStep step;
  final bool isLoading;
  final String? verificationId;
  final String? phoneNumber;
  final String? errorMessage;

  const PhoneAuthState({
    this.step = PhoneAuthStep.enterNumber,
    this.isLoading = false,
    this.verificationId,
    this.phoneNumber,
    this.errorMessage,
  });

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    bool? isLoading,
    String? verificationId,
    String? phoneNumber,
    Object? errorMessage = _sentinel,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

/// Drives Firebase's phone verification flow for both use cases that need
/// it: linking a phone number onto the current (email) account, and signing
/// in directly with an already-linked number — same send-code/confirm-code
/// steps, only the last call differs (`linkWithCredential` vs
/// `signInWithCredential`).
class PhoneAuthViewModel extends StateNotifier<PhoneAuthState> {
  PhoneAuthViewModel(this._authRepository) : super(const PhoneAuthState());

  final AuthRepository _authRepository;
  // Android can resolve the SMS itself without the user typing a code —
  // kept aside so `confirmCode` can use it if the code field is empty.
  PhoneAuthCredential? _autoCredential;

  Future<void> sendCode(String rawPhoneNumber) async {
    final phoneNumber = rawPhoneNumber.trim();
    if (phoneNumber.isEmpty) return;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      phoneNumber: phoneNumber,
    );
    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          state = state.copyWith(
            isLoading: false,
            step: PhoneAuthStep.enterCode,
            verificationId: verificationId,
          );
        },
        onVerificationFailed: (e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: _messageFor(e),
          );
        },
        onAutoVerified: (credential) {
          // Silent auto-resolution — stash the credential and let the user
          // hit "Confirmer" with an empty code field to use it directly.
          _autoCredential = credential;
          state = state.copyWith(
            isLoading: false,
            step: PhoneAuthStep.enterCode,
          );
        },
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Une erreur est survenue, réessaie.',
      );
    }
  }

  Future<UserCredential?> confirmCode(
    String smsCode, {
    required bool link,
  }) async {
    final credential =
        _autoCredential ??
        (state.verificationId == null || smsCode.trim().isEmpty
            ? null
            : _authRepository.phoneCredential(
                verificationId: state.verificationId!,
                smsCode: smsCode.trim(),
              ));
    if (credential == null) return null;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = link
          ? await _authRepository.linkPhoneCredential(credential)
          : await _authRepository.signInWithPhoneCredential(credential);
      state = state.copyWith(isLoading: false, step: PhoneAuthStep.done);
      return result;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _messageFor(e));
      return null;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Une erreur est survenue, réessaie.',
      );
      return null;
    }
  }

  void reset() => state = const PhoneAuthState();

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide (format international, ex: +33612345678).';
      case 'invalid-verification-code':
        return 'Code incorrect.';
      case 'session-expired':
      case 'code-expired':
        return 'Ce code a expiré, redemande-en un.';
      case 'credential-already-in-use':
      case 'provider-already-linked':
        return 'Ce numéro est déjà lié à un autre compte.';
      case 'too-many-requests':
        return 'Trop de tentatives, réessaie plus tard.';
      default:
        return 'Une erreur est survenue, réessaie.';
    }
  }
}

final phoneAuthViewModelProvider =
    StateNotifierProvider.autoDispose<PhoneAuthViewModel, PhoneAuthState>(
      (ref) => PhoneAuthViewModel(ref.watch(authRepositoryProvider)),
    );
