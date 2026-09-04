import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint(
        'PushNotification: permission status=${settings.authorizationStatus}',
      );
    }
    // Without this, iOS silently drops notifications received while the
    // app is in the foreground instead of showing a banner.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// On iOS, FCM can't hand back a token until the device has registered
  /// with APNs — which happens asynchronously right after
  /// [requestPermission] and can lag a moment behind it. Polling briefly
  /// for the APNs token avoids the `apns-token-not-set` exception; giving
  /// up after a few seconds (e.g. push declined, or a simulator without
  /// APNs support) just means no push for this device rather than a crash.
  Future<String?> getToken() async {
    if (Platform.isIOS || Platform.isMacOS) {
      var apnsToken = await _messaging.getAPNSToken();
      var attempts = 0;
      while (apnsToken == null && attempts < 10) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await _messaging.getAPNSToken();
        attempts++;
      }
      if (kDebugMode) {
        debugPrint('PushNotification: APNS token after $attempts attempt(s)=$apnsToken');
      }
      if (apnsToken == null) return null;
    }
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('PushNotification: getToken failed: $e');
      return null;
    }
  }

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
