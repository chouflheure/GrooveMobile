import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

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
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
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
    return PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
  }

  /// Signs in with a verified phone credential — resolves to the same
  /// account the number was linked to, if any.
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) {
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
}
