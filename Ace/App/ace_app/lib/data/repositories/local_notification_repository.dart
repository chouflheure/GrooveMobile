import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Displays a real system notification (icon, sound, vibration) for a push
/// received while the app is in the foreground. FCM only auto-displays a
/// notification like that when the app is backgrounded/killed — in the
/// foreground it's just handed to `FirebaseMessaging.onMessage` as data,
/// with nothing shown unless the app does it itself.
class LocalNotificationRepository {
  LocalNotificationRepository({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications',
    description: 'Messages, demandes de jeu, rappels de match, événements.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// `onTap` fires with the original FCM `data` map (re-decoded from the
  /// notification's payload string) when the user taps a notification this
  /// repository displayed — i.e. one shown while the app was foregrounded.
  Future<void> initialize({
    required void Function(Map<String, dynamic> data) onTap,
  }) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        onTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
      },
    );
  }

  Future<void> showForMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true, presentBanner: true),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
