import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Remote Config for the app-launch checks: the minimum
/// version required to keep using the app, whether that update is
/// mandatory, and a kill-switch to force a sign-out (e.g. after a breaking
/// change to session/token handling on the backend).
class RemoteConfigRepository {
  RemoteConfigRepository({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  static const _appVersionKey = 'appVersion';
  static const _isNeededMAJKey = 'isNeededMAJ';
  static const _isNeededToDeconnectKey = 'isNeededToDeconnect';

  Future<void> fetchAndActivate() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // In debug builds, bypass the on-device throttle entirely so every
        // launch pulls fresh values while testing. In release, respect
        // Firebase's recommended minimum to avoid hitting fetch quotas.
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults(const {
      _appVersionKey: '',
      _isNeededMAJKey: false,
      _isNeededToDeconnectKey: false,
    });
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      if (kDebugMode) {
        debugPrint(
          'RemoteConfig: fetchAndActivate activated=$activated '
          'appVersion=$minimumAppVersion isNeededMAJ=$isUpdateMandatory '
          'isNeededToDeconnect=$isNeededToDeconnect',
        );
      }
    } catch (e) {
      // Offline or fetch failure: fall back to the last activated (or
      // default) values instead of blocking app startup.
      if (kDebugMode) debugPrint('RemoteConfig: fetchAndActivate failed: $e');
    }
  }

  /// Minimum app version required by the backend, e.g. "1.4.0".
  String get minimumAppVersion => _remoteConfig.getString(_appVersionKey);

  /// Whether the update to [minimumAppVersion] is mandatory (the update
  /// dialog cannot be dismissed) once the user is below that version.
  bool get isUpdateMandatory => _remoteConfig.getBool(_isNeededMAJKey);

  /// Kill-switch: when true, the app signs the current user out on launch.
  bool get isNeededToDeconnect => _remoteConfig.getBool(_isNeededToDeconnectKey);
}
