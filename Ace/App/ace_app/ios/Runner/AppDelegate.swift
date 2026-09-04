import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Belt-and-braces: `firebase_messaging`'s `requestPermission()` is
    // supposed to trigger this itself once permission is granted, but on
    // this project's newer "implicit Flutter engine" template it wasn't
    // reaching apsd at all (confirmed via device console — no registration
    // attempt logged). Calling it directly here is the standard native
    // integration step and safe to call unconditionally; iOS just won't
    // hand back a token until the user has actually granted permission.
    application.registerForRemoteNotifications()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
