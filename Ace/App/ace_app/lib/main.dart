import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_startup_provider.dart';
import 'firebase_options.dart';
import 'presentation/molecules/update_required_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

    return MaterialApp.router(
      title: 'CourtConnect',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
    );
  }
}
