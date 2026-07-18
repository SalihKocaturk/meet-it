import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reklam gösterim mantığını ve AdMob SDK yaşam döngüsünü yöneten servis.
///
/// ── Kullanım:
///    1. `main.dart`'ta `WidgetsFlutterBinding.ensureInitialized()` sonrası
///       `await AdService.initialize()` çağır.
///    2. Banner göstermek istediğin yerde `AdBannerWidget` kullan.
///    3. Arama sayaç mantığı için `shouldShowAd(isPremium: ...)` kullan.
///
/// Free kullanıcılar her 2 aramadan 1'inde reklam görür.
/// Premium kullanıcılar hiç reklam görmez.
///
/// Sayaç in-memory (oturum bazlı) — MVP için yeterli.
class AdService {
  AdService._();

  static int _searchCount = 0;
  static bool _initialized = false;

  /// AdMob SDK'yı başlat. `main.dart`'ta Firebase init'ten sonra çağrılmalı.
  ///
  /// Birden fazla kez çağrılabilir — ikinci çağrılar erken döner.
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  /// Bu aramada reklam gösterilmeli mi?
  ///
  /// Her çağrıda [_searchCount] bir artar.
  /// Çift saydaki aramalarda (2., 4., 6., …) true döner.
  ///
  /// [isPremium] true ise her zaman false döner ve sayaç artmaz.
  static bool shouldShowAd({required bool isPremium}) {
    if (isPremium) return false;
    _searchCount++;
    return _searchCount % 2 == 0;
  }

  /// Test/geliştirme amaçlı sayacı sıfırla.
  static void resetCounterForTesting() => _searchCount = 0;
}
