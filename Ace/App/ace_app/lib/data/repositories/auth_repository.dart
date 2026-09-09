import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown by [AuthRepository.sendPasswordResetEmail] when no account
/// matches the given email — mirrors the `not-found` `HttpsError` the
/// `sendPasswordResetEmail` Cloud Function reports for that case.
class UserNotFoundException implements Exception {
  const UserNotFoundException();

  @override
  String toString() => 'Aucun compte associé à cet email.';
}

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west9');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Sends the reset email ourselves via a Cloud Function (Mailgun) instead
  /// of Firebase Auth's own automatic email — see `functions/lib/password_reset.js`.
  /// The reset link itself is still a real Firebase Auth action link;
  /// only who sends the email, and its design, changes.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _functions
          .httpsCallable('sendPasswordResetEmail')
          .call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') throw const UserNotFoundException();
      rethrow;
    }
  }

  /// Starts Firebase's phone verification flow. `onCodeSent` fires once the
  /// SMS goes out (carries the `verificationId` needed to confirm the code);
  /// `onVerificationFailed` covers bad number / quota / reCAPTCHA issues.
  /// Android may auto-resolve without user input via `onAutoVerified` — the
  /// caller decides what to do with the credential in that case (sign in vs
  /// link, same as `confirmCode` below).
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onVerificationFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  PhoneAuthCredential phoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  /// Signs in with a verified phone credential — resolves to the same
  /// account the number was linked to, if any.
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) {
    return _auth.signInWithCredential(credential);
  }

  /// Attaches a verified phone number to the currently signed-in account,
  /// so it can be used to sign in going forward alongside email/password.
  Future<UserCredential> linkPhoneCredential(PhoneAuthCredential credential) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('linkPhoneCredential called with no signed-in user.');
    }
    return user.linkWithCredential(credential);
  }

  /// Rolls back a phone link — used when the Firestore-side write that's
  /// supposed to follow a successful [linkPhoneCredential] fails, so the
  /// account doesn't end up with a phone credential Firebase will accept
  /// for sign-in but no matching `phone` field on its profile.
  Future<void> unlinkPhoneCredential() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return user.unlink(PhoneAuthProvider.PROVIDER_ID).then((_) {});
  }
}
