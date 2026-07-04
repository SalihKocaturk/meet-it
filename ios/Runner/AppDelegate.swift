import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add your Google Maps API key here (never commit the real key).
    // Same key as in dart_defines.json → googleMapsApiKey.
    GMSServices.provideAPIKey("")

    // FCM + flutter_local_notifications için iOS bildirim delegate ayarı.
    // FlutterAppDelegate zaten UNUserNotificationCenterDelegate'i uygular —
    // sadece delegate olarak atamamız yeterli.
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
