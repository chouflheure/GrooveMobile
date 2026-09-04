import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Wraps FCM registration: asking the OS for permission, reading the
/// device token, and keeping it in sync on the user's Firestore doc (under
/// `fcmTokens`, an array since one account can be signed in on several
/// devices) so Cloud Functions know where to push.
class PushNotificationRepository {
  PushNotificationRepository({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // Without this, iOS silently drops notifications received while the
    // app is in the foreground instead of showing a banner.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> saveTokenForUser(String userId, String token) {
    return _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeTokenForUser(String userId, String token) {
    return _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}
