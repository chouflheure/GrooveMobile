import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Pre-created and retained for the app's whole lifetime, instead of
  // letting Flutter create one implicitly per-scene. The implicit-engine
  // path (`FlutterImplicitEngineDelegate`) has a known Flutter engine bug
  // under UIScene where `Messaging.messaging().delegate` ends up nil after
  // plugin registration, silently breaking `onMessage`, `onMessageOpenedApp`
  // and `getInitialMessage()` — see https://github.com/flutter/flutter/issues/185048.
  // Registering plugins here instead, on an engine AppDelegate itself keeps
  // alive, is the pattern Flutter's own UIScene migration guide recommends
  // to avoid that bug.
  var flutterEngine: FlutterEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let engine = FlutterEngine(name: "main")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    flutterEngine = engine

    // Belt-and-braces: `firebase_messaging`'s `requestPermission()` is
    // supposed to trigger this itself once permission is granted; calling
    // it directly here too is the standard native integration step and
    // safe to call unconditionally — iOS just won't hand back a token
    // until the user has actually granted permission.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
