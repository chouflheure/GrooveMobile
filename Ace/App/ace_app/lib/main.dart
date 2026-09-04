import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'data/providers/app_startup_provider.dart';
import 'data/providers/push_notification_provider.dart';
import 'presentation/screens/auth/auth_view_model.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
    // One-time setup: ask the OS for notification permission, and keep the
    // device's FCM token in sync on whichever user is signed in whenever it
    // rotates (Firebase can reissue it at any time, not just on first run).
    ref.read(pushNotificationRepositoryProvider).requestPermission();
    ref.read(pushNotificationRepositoryProvider).onTokenRefresh.listen((
      token,
    ) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref
            .read(pushNotificationRepositoryProvider)
            .saveTokenForUser(user.id, token);
      }
    });
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            [
              notification.title,
              notification.body,
            ].whereType<String>().join(' — '),
          ),
        ),
      );
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

    // Registers this device's FCM token on the user's Firestore doc the
    // moment they're identified (app launch with a persisted session, or
    // right after signing in) so Cloud Functions have somewhere to push to.
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
      final user = next.value;
      if (user == null) return;
      final repository = ref.read(pushNotificationRepositoryProvider);
      repository.getToken().then((token) {
        if (token != null) repository.saveTokenForUser(user.id, token);
      });
    });

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
