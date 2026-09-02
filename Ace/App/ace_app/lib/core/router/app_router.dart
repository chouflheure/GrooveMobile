import 'package:go_router/go_router.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/courts/courts_screen.dart';
import '../../presentation/screens/court_detail/court_detail_screen.dart';
import '../../presentation/screens/community/community_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/admin/admin_screen.dart';
import '../../presentation/templates/main_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/courts',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CourtsScreen(),
          ),
        ),
        GoRoute(
          path: '/community',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CommunityScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminScreen(),
          ),
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
  ],
);
