import Flutter
import UIKit
import GoogleMaps
import UserNotifications

// iOS 27 SDK (Xcode 27) ile derlenen uygulamalar UIScene yaşam döngüsünü
// benimsemek ZORUNDA — aksi hâlde açılışta çöker (App Review 2.1 reddi).
// Bu yüzden eklentiler artık didFinishLaunching'de değil,
// didInitializeImplicitFlutterEngine'de kaydediliyor; sahne ayarı
// Info.plist → UIApplicationSceneManifest (FlutterSceneDelegate).
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps anahtarı koda yazılmaz: ios/Flutter/Secrets.xcconfig
    // (git'e girmez) → GOOGLE_MAPS_API_KEY → Info.plist "GMSApiKey".
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    }

    // FCM + flutter_local_notifications için iOS bildirim delegate ayarı.
    // Uygulama açılışı bitmeden atanmalı (UIScene'de de burada kalır).
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
