import 'package:app_badge_control_flutter/app_badge_control_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/notifications/notification_navigation.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'data/providers/app_startup_provider.dart';
import 'data/providers/push_notification_provider.dart';
import 'presentation/screens/auth/auth_view_model.dart';
import 'presentation/screens/community/community_view_model.dart';
import 'firebase_options.dart';
import 'presentation/molecules/update_required_dialog.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Runs in a separate isolate when a push arrives while the app is
/// backgrounded/terminated — Firebase needs its own initialized instance
/// there, since nothing from `main()` is shared with it.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Web background push is handled by a service worker instead — nothing
  // to register here, and notifications are off entirely on web for now
  // (see `_CourtConnectAppState.initState`).
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await initializeDateFormatting('fr_FR');
  runApp(const ProviderScope(child: CourtConnectApp()));
}

class CourtConnectApp extends ConsumerStatefulWidget {
  const CourtConnectApp({super.key});

  @override
  ConsumerState<CourtConnectApp> createState() => _CourtConnectAppState();
}

class _CourtConnectAppState extends ConsumerState<CourtConnectApp> {
  @override
  void initState() {
    super.initState();
    // Notifications are off entirely on web for now: `firebase_messaging`
    // web push needs its own VAPID key + service worker setup we haven't
    // done, and `flutter_local_notifications` has no web implementation at
    // all (calling it would throw `MissingPluginException`). Mobile and
    // tablet (same OS, same plugin support either way) are unaffected.
    if (kIsWeb) return;

    // One-time setup: ask the OS for notification permission, and keep the
    // device's FCM token in sync on whichever user is signed in whenever it
    // rotates (Firebase can reissue it at any time, not just on first run).
    ref.read(pushNotificationRepositoryProvider).requestPermission();
    // Android-only: this plugin claims `UNUserNotificationCenter`'s
    // delegate on iOS the moment it's initialized, which hijacks Firebase
    // Messaging's own delegate and silently breaks its notification-tap
    // detection (`onMessageOpenedApp` / `getInitialMessage` never fire
    // again). iOS doesn't need it anyway — it already shows a foreground
    // banner natively via `setForegroundNotificationPresentationOptions`.
    if (defaultTargetPlatform == TargetPlatform.android) {
      ref
          .read(localNotificationRepositoryProvider)
          .initialize(onTap: (data) => handleNotificationTap(ref, data));
    }

    // A push tapped while the app was backgrounded (not terminated) resumes
    // it and fires here.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification: onMessageOpenedApp data=${message.data}');
      handleNotificationTap(ref, message.data);
    });
    // A push tapped while the app was fully terminated launches it fresh —
    // that tap is instead handed back the first time this is read, so it's
    // checked once at startup rather than via a stream.
    debugPrint('Notification: requesting getInitialMessage...');
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          debugPrint('Notification: getInitialMessage data=${message?.data}');
          if (message != null) handleNotificationTap(ref, message.data);
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('Notification: getInitialMessage FAILED: $e');
          debugPrint('$st');
        });

    ref.read(pushNotificationRepositoryProvider).onTokenRefresh.listen((
      token,
    ) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;
      ref
          .read(pushNotificationRepositoryProvider)
          .saveTokenForUser(user.id, token)
          .catchError((Object e) {
            debugPrint('PushNotification: failed to save refreshed token: $e');
          });
    });
    FirebaseMessaging.onMessage.listen((message) {
      // iOS already shows its own native banner (with sound) for a
      // foreground push, since `requestPermission` enabled that via
      // `setForegroundNotificationPresentationOptions` — showing a second,
      // local one on top would just duplicate it. Android has no such
      // built-in foreground display, so it needs one built manually.
      if (defaultTargetPlatform == TargetPlatform.android) {
        ref.read(localNotificationRepositoryProvider).showForMessage(message);
      }
    });

    // `ref.listen` in build() below only fires on a *future* change, not
    // the value a provider already holds — on a cold launch with a
    // persisted session, `currentUserProvider` can already have resolved
    // to a non-null user before that listener is even registered, so the
    // already-current value is also checked once here.
    _registerTokenFor(ref.read(currentUserProvider).valueOrNull);
  }

  void _registerTokenFor(UserModel? user) {
    if (kIsWeb) return;
    debugPrint('PushNotification: _registerTokenFor user=${user?.id}');
    if (user == null) return;
    final repository = ref.read(pushNotificationRepositoryProvider);
    repository
        .getToken()
        .then((token) async {
          debugPrint('PushNotification: getToken() -> $token');
          if (token == null) return;
          await repository.saveTokenForUser(user.id, token);
          debugPrint('PushNotification: token saved for user ${user.id}');
        })
        .catchError((Object e) {
          debugPrint('PushNotification: failed to save FCM token: $e');
        });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppStartupResult>>(appStartupProvider, (
      previous,
      next,
    ) {
      final result = next.value;
      if (result == null) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      if (result.wasSignedOut) {
        GoRouter.of(context).go('/login');
      }
      if (result.updateAvailable) {
        UpdateRequiredDialog.show(context, mandatory: result.updateMandatory);
      }
    });

    // Registers this device's FCM token on the user's Firestore doc right
    // after signing in (the already-signed-in-at-launch case is handled
    // once in initState above).
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
      _registerTokenFor(next.value);
    });

    // App icon badge (outside the app) — bell notifications not yet seen +
    // unread messages + unseen announcements. Best-effort, updated whenever
    // the app is running; not attempted on web (no notification system
    // there — see `_CourtConnectAppState.initState`). iOS shows the real
    // number; the plugin is a no-op for `updateBadgeCount` on Android
    // (badge there follows the system notification tray instead).
    if (!kIsWeb) {
      ref.listen<int>(appIconBadgeCountProvider, (previous, count) {
        if (count <= 0) {
          AppBadgeControlFlutter.removeBadge();
        } else {
          AppBadgeControlFlutter.updateBadgeCount(count);
        }
      });
    }

    return MaterialApp.router(
      title: 'CourtConnect',
      theme: AppTheme.light,
      routerConfig: appRouter,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
    );
  }
}
