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
    GMSServices.provideAPIKey("AIzaSyCgBS_e0-68R6gupfroHXmySdb_PtBWDtg")

    // FCM + flutter_local_notifications için iOS bildirim delegate ayarı.
    // FlutterAppDelegate zaten UNUserNotificationCenterDelegate'i uygular —
    // sadece delegate olarak atamamız yeterli.
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
