import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/utils/version_compare.dart';
import '../repositories/auth_repository.dart';
import '../repositories/remote_config_repository.dart';

/// Result of the app-launch Remote Config check: whether an update should
/// be offered/enforced, and whether the current user was just signed out.
class AppStartupResult {
  const AppStartupResult({
    required this.updateAvailable,
    required this.updateMandatory,
    required this.wasSignedOut,
  });

  final bool updateAvailable;
  final bool updateMandatory;
  final bool wasSignedOut;
}

final remoteConfigRepositoryProvider = Provider<RemoteConfigRepository>(
  (ref) => RemoteConfigRepository(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// Runs once on app launch: fetches Remote Config, force-signs-out the user
/// if `isNeededToDeconnect` is set, and reports whether an update dialog is
/// needed. Kept as a [FutureProvider] (not autoDispose) so it runs exactly
/// once per app session.
final appStartupProvider = FutureProvider<AppStartupResult>((ref) async {
  final remoteConfig = ref.read(remoteConfigRepositoryProvider);
  await remoteConfig.fetchAndActivate();

  var wasSignedOut = false;
  if (remoteConfig.isNeededToDeconnect) {
    final auth = ref.read(authRepositoryProvider);
    if (auth.currentUser != null) {
      await auth.signOut();
      wasSignedOut = true;
    }
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final minimumVersion = remoteConfig.minimumAppVersion;
  final updateAvailable = isVersionBelow(packageInfo.version, minimumVersion);

  return AppStartupResult(
    updateAvailable: updateAvailable,
    updateMandatory: updateAvailable && remoteConfig.isUpdateMandatory,
    wasSignedOut: wasSignedOut,
  );
});
