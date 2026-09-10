import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/version_compare.dart';
import '../repositories/auth_repository.dart';
import '../repositories/remote_config_repository.dart';

// Per-device (SharedPreferences) — the app version for which the
// `isNeededToDeconnect` kill-switch has already been complied with, so a
// launch on that same version doesn't force a sign-out again every time.
// A later version bump (with the flag still/again set) forces it once more.
const _deconnectHandledVersionKey = 'deconnectHandledForVersion';

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

  final packageInfo = await PackageInfo.fromPlatform();

  var wasSignedOut = false;
  if (remoteConfig.isNeededToDeconnect) {
    final prefs = await SharedPreferences.getInstance();
    final handledVersion = prefs.getString(_deconnectHandledVersionKey);
    if (handledVersion != packageInfo.version) {
      final auth = ref.read(authRepositoryProvider);
      if (auth.currentUser != null) {
        await auth.signOut();
        wasSignedOut = true;
      }
      // Either way, this device has now satisfied the requirement for this
      // version — nothing left to force out on it, whether or not a session
      // actually existed to sign out of.
      await prefs.setString(_deconnectHandledVersionKey, packageInfo.version);
    }
  }

  final minimumVersion = remoteConfig.minimumAppVersion;
  final updateAvailable = isVersionBelow(packageInfo.version, minimumVersion);

  return AppStartupResult(
    updateAvailable: updateAvailable,
    updateMandatory: updateAvailable && remoteConfig.isUpdateMandatory,
    wasSignedOut: wasSignedOut,
  );
});
