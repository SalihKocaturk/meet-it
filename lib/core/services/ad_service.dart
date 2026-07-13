/// Reklam gösterim mantığını yöneten basit sayaç servisi.
///
/// Free kullanıcılar her 2 aramadan 1'inde (çift aramalarda) reklam görür.
/// Premium kullanıcılar [isPremium] = true ile hiç reklam görmez.
///
/// Sayaç uygulama oturumuna bağlı (in-memory) — uygulama yeniden açıldığında
/// sıfırlanır. MVP için bu yeterli; kalıcı hale getirmek istersen
/// SharedPreferences ile persist edilebilir.
///
/// İleride Google Mobile Ads entegrasyonu yapılacaksa bu sınıf
/// AdMob interstitial/banner hazırlık ve gösterim mantığını da üstlenecek.
class AdService {
  AdService._();

  static int _searchCount = 0;

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
  /// Üretim kodunda çağrılmamalı.
  static void resetCounterForTesting() => _searchCount = 0;
}
