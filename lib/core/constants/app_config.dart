/// Uygulama genelinde kullanılan API anahtarları ve sabitler.
///
/// KURULUM:
/// 1. Google Cloud Console'dan API key al (Maps SDK + Places API aktif olmalı)
/// 2. Aşağıdaki [googleMapsApiKey] değerini kendi key'inle değiştir
/// 3. android/app/src/main/AndroidManifest.xml içindeki placeholder'ı da güncelle
class AppConfig {
  AppConfig._();

  /// Google Maps + Places API anahtarı.
  /// ⚠️  BUNU GIT'E COMMIT ETME — production'da env/secrets kullan.
  static const String googleMapsApiKey =
      'AIzaSyAdmJt0XSx6AtiJLngBXhkgml7OYzUm_7Y';

  /// Places Nearby Search endpoint'i
  static const String placesNearbyUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Places Photo endpoint'i
  static const String placesPhotoUrl =
      'https://maps.googleapis.com/maps/api/place/photo';

  /// Varsayılan arama yarıçapı (metre) — tek başına arama modunda kullanılır.
  static const int defaultSearchRadius = 10000;

  /// İki kullanıcı arasında (orta nokt