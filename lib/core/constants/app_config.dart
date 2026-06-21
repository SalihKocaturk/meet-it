/// Uygulama genelinde kullanılan API anahtarları ve sabitler.
///
/// KURULUM:
/// 1. Google Cloud Console'dan API key al (Maps SDK + Places API aktif olmalı)
/// 2. Anahtarı KOD İÇİNE YAZMA — aşağıdaki [googleMapsApiKey] derleme anında
///    --dart-define ile geliyor:
///      flutter run --dart-define=GOOGLE_MAPS_API_KEY=xxxxx
///    veya bir dosyadan:
///      flutter run --dart-define-from-file=dart_defines.json
///    (dart_defines.json .gitignore'da — bkz. dart_defines.example.json)
/// 3. Android tarafı için android/secrets.properties dosyasını doldur
///    (bkz. android/secrets.properties.example) — bu dosya da .gitignore'da.
///
/// ⚠️  Daha önce buraya gerçek bir anahtar hardcoded yazılmıştı ve GitHub
/// secret scanning tarafından "public leak" olarak işaretlendi. O anahtar
/// Google Cloud Console'dan iptal edilip yenisiyle değiştirilmeli. Bundan
/// sonra hiçbir API key bu dosyaya literal olarak YAZILMAYACAK.
class AppConfig {
  AppConfig._();

  /// Google Maps + Places API anahtarı — derleme zamanında inject edilir.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  /// Places Nearby Search endpoint'i
  static const String placesNearbyUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Places Photo endpoint'i
  static const String placesPhotoUrl =
      'https://maps.googleapis.com/maps/api/place/photo';

  /// Places Details endpoint'i — sadece Nearby Search'ten gelen tek bir
  /// foto referansıyla sınırlı kalmamak için, bir mekanın TÜM fotoğraflarını
  /// placeId üzerinden ayrıca çekmek amacıyla kullanılıyor (bkz.
  /// PlacesService.fetchPhotoUrls).
  static const String placesDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

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
