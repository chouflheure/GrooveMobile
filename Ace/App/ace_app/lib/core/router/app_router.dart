import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/courts/courts_screen.dart';
import '../../presentation/screens/court_detail/court_detail_screen.dart';
import '../../presentation/screens/event_detail/event_detail_screen.dart';
import '../../presentation/screens/community/community_screen.dart';
import '../../data/models/models.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/manager/manager_screen.dart';
import '../../presentation/templates/main_scaffold.dart';

/// Bridges Firebase's auth stream to a [Listenable] so go_router re-runs
/// [redirect] the moment a persisted session is restored (or cleared),
/// instead of only on navigation.
class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  _GoRouterRefreshStream(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/courts',
  refreshListenable: _GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (context, state) {
    // Browsing is allowed as a guest; only bounce a signed-in user away
    // from the login/register screens if a persisted session already
    // covers them (the actual "keeps asking me to log in" bug).
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final onAuthPage =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    if (loggedIn && onAuthPage) return '/courts';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/courts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CourtsScreen()),
        ),
        GoRoute(
          path: '/community',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CommunityScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: '/manager',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ManagerScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/court/:id',
      builder: (context, state) {
        final args = state.extra as CourtDetailArgs;
        return CourtDetailScreen(
          court: args.court,
          initialSlot: args.initialSlot,
        );
      },
    ),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) {
        final event = state.extra as ClubEventModel;
        return EventDetailScreen(event: event);
      },
    ),
  ],
);
