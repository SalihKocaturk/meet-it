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

  /// İki kullanıcı arasında (orta nokta) arama yapılırken kullanılan
  /// kademeli yarıçap adımları (metre). Önce dar bir çapta, sadece kaliteli
  /// (4.0+ puan) mekanlar aranır — böylece ikisinin arasında GERÇEKTEN
  /// yakın bir yer bulunabilir. Yeterli sonuç çıkmazsa çap kademeli
  /// büyütülür; son adımda puan şartı da gevşetilir ki hiçbir sonuç
  /// dönmesin diye boş kalınmasın.
  static const List<int> midpointSearchRadiusSteps = [2500, 5000, 8000, 12000];

  /// Orta nokta aramasında bir adımın "yeterli" sayılması için gereken
  /// minimum sonuç sayısı — bu sayıya ulaşılırsa çap büyütülmeden durulur.
  static const int midpointMinResultsPerStep = 5;

  /// Orta nokta aramasında ilk adımlarda zorunlu kılınan minimum puan.
  static const double midpointMinRating = 4.0;

  /// Döndürülecek maksimum mekan sayısı
  static const int maxVenueResults = 5;
}
