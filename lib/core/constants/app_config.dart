/// Uygulama genelinde kullanılan API anahtarları ve sabitler.
///
/// KURULUM:
/// 1. Google Cloud Console'dan API key al — şu üç servis aktif olmalı:
///    Maps SDK for Android/iOS, Places API (New), Distance Matrix API.
/// 2. Anahtarı KOD İÇİNE YAZMA — aşağıdaki [googleMapsApiKey] derleme
///    anında --dart-define ile geliyor:
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
///
/// 📍 FOURSQUARE GEÇİŞİNDEN GERİ DÖNÜŞ (2026-06-27):
/// Mekan arama bir süre Foursquare Places API kullandı (Google Places'in
/// maliyetinden kaçınmak için), ama Foursquare 2024-2025 fiyat yenilemesiyle
/// `rating`/`hours`/`photos`/`stats` alanlarını "Premium" yaptı — bu alanlarda
/// HİÇ ücretsiz kota yok, ilk çağrıdan itibaren ücretli (~$0.02/çağrı).
/// Araştırma sonucu: Yelp Fusion'da artık ücretsiz katman yok, OpenStreetMap
/// tabanlı API'lerde (Geoapify vb.) hiç puan/yorum verisi yok. Yani rating
/// verisi gerektiren HİÇBİR API tamamen bedava değil — Google'a dönmek
/// maliyeti SIFIRLAMIYOR, ama tek (zaten Maps SDK + Distance Matrix için
/// gerekli olan) API sağlayıcısına dönerek mimariyi sadeleştiriyor.
///
/// Varsayılan olarak Google'ın yeni Places API (New) endpoint'i kullanılıyor.
///
/// 📍 DÜZELTME (2026-06-28): Buradaki eski not, "Mart 2025'ten beri Legacy
/// servisler hiç ücretsiz kota almıyor" diyordu — bu artık YANLIŞ/güncel
/// değil. Google'ın canlı fiyatlandırma sayfası (developers.google.com/
/// maps/billing-and-pricing/pricing, son güncelleme 2026-05-27) Legacy
/// "Places - Nearby Search" ve "Places Photo" SKU'larının da KENDİ ayrı
/// ücretsiz aylık kotalarına sahip olduğunu gösteriyor — New API'ninkinden
/// BAĞIMSIZ bir kota. Yani Legacy ve New, iki AYRI ücretsiz kota havuzu.
///
/// 📍 DUAL API SWITCH (2026-06-28): Bu iki bağımsız kotayı birleştirmek için
/// artık Firestore'dan okunan bir alana göre New veya Legacy API arasında
/// MANUEL olarak geçiş yapılabiliyor (bkz. PlacesApiVersionService). Biri
/// aylık kotasına yaklaşınca (Google Cloud Console'dan elle takip edilip)
/// Firestore'daki `appConfig/placesApi.activeVersion` alanı `"legacy"`
/// yapılır; tekrar `"new"`ye çevrilince New API'ye dönülür. Bu alan YOKSA,
/// okunamıyorsa veya tanınmayan bir değer içeriyorsa HER ZAMAN "new"
/// kullanılır (Legacy'nin uzun vadede tamamen kapatılma riski olduğundan,
/// sessiz bir okuma hatası asla kırılgan/kapatılmış bir API'ye düşmemeli).
class AppConfig {
  AppConfig._();

  /// Google Maps SDK (harita render) + Places API (New) + Distance Matrix
  /// API ortak anahtarı — derleme zamanında inject edilir. Google Cloud
  /// Console'da bu anahtarın hem "Places API (New)" hem "Distance Matrix
  /// API" hem de "Maps SDK for Android/iOS" için etkin olduğundan emin ol.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  /// Places API (New) — Nearby Search endpoint'i (POST, JSON body).
  ///
  /// ⚠️ Bu, eski (Legacy) `maps.googleapis.com/maps/api/place/nearbysearch/
  /// json` GET endpoint'i DEĞİL — Google'ın 2024 sonrası önerdiği yeni REST
  /// API'si. İstek body'si `includedTypes`/`locationRestriction`/
  /// `maxResultCount` alanlarını taşır; hangi alanların döneceği
  /// `X-Goog-FieldMask` header'ıyla belirlenir (bkz. PlacesService).
  static const String placesNearbySearchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  /// Places API (New) — tek bir mekanın detayını (burada sadece TÜM
  /// fotoğraflarını) çekmek için kullanılan endpoint'in öneki — sonuna
  /// `/{placeId}` eklenir (bkz. PlacesService.fetchPhotoUrls).
  static const String placesDetailsUrl = 'https://places.googleapis.com/v1/places';

  /// Places API (New) — fotoğraf medyasının kendisini (gerçek görsel
  /// byte'larını) döndüren endpoint'in öneki — sonuna `/{photoName}/media`
  /// eklenir. `photoName` formatı: `places/{placeId}/photos/{photoId}`.
  static const String placesPhotoMediaBaseUrl = 'https://places.googleapis.com/v1';

  /// Legacy Places API — Nearby Search endpoint'i (GET, query parametreleri).
  ///
  /// ⚠️ Sadece `PlacesApiVersionService` Firestore'dan "legacy" değeri
  /// okuduğunda kullanılır (bkz. PlacesService._fetchNearbyLegacy). Bu
  /// endpoint TEK bir `type` parametresi kabul eder — New API'nin
  /// `includedTypes` dizisi gibi birden fazla type'ı OR mantığıyla TEK
  /// istekte birleştiremez.
  static const String placesNearbySearchUrlLegacy =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Legacy Places API — fotoğraf medyası endpoint'i (GET, `photo_reference`
  /// + `key` query parametreleriyle). New API'nin `photos/{photoId}/media`
  /// yoluyla TAMAMEN farklı — bkz. `PlaceResult.buildPhotoUrl`'daki
  /// `legacy:` önekli dallanma.
  static const String placesPhotoUrlLegacy =
      'https://maps.googleapis.com/maps/api/place/photo';

  /// Distance Matrix endpoint'i — mekan kartlarındaki GERÇEK (trafik
  /// tahminli) araba/toplu taşıma/yürüme süresi için kullanılır (bkz.
  /// `distance_matrix_service.dart`).
  ///
  /// ⚠️ KURULUM: Bu API, Places/Maps API'sinden FARKLI bir servistir —
  /// Google Cloud Console'da aynı projede "Distance Matrix API"yi AYRICA
  /// etkinleştirmen gerekiyor (Maps SDK + Places API etkin olması yetmez).
  /// Etkinleştirilmemişse veya kota dolmuşsa servis otomatik olarak kuş
  /// uçuşu tahminine düşer (uygulama çökmez, sadece "~" öneki ile yaklaşık
  /// süre gösterir).
  static const String distanceMatrixUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  /// Varsayılan arama yarıçapı (metre) — kullanıcı elle bir mesafe filtresi
  /// SEÇMEDİĞİNDE hem tek başına hem de arkadaşla (orta nokta) arama
  /// modunda kullanılır.
  ///
  /// 📍 API ÇAĞRI TASARRUFU (2026-06-28): Önceden orta nokta modunda
  /// `[2500, 5000, 8000, 12000]` metrelik 4 adımlık kademeli bir arama
  /// yapılıyordu — bir adımda yeterli sonuç çıkmazsa otomatik olarak bir
  /// sonraki (daha geniş) adıma geçiliyordu. Bu, TEK bir kullanıcı
  /// aramasının arka planda 4 katına kadar Places API çağrısına (her
  /// adımda `_resolveTypes()`'ın döndürdüğü tip sayısı kadar çağrı × 4
  /// adım) yol açıyordu. Kullanıcı talebi üzerine ("tasarrufa gitmemiz
  /// lazım") kademeli deneme tamamen kaldırıldı — artık HER arama TEK bir
  /// çapta, TEK seferde yapılıyor (bkz. `venue_search_notifier.dart`).
  static const int defaultSearchRadius = 5000;

  /// Orta nokta aramasında uygulanan TABAN puan şartı — bu puanın altındaki
  /// mekanlar gösterilmez. Kademeli deneme kaldırıldığı için artık
  /// gevşetilen bir "ilk eşik" yok, tek ve sabit bir taban puan var.
  static const double midpointMinRating = 3.5;

  /// Döndürülecek maksimum mekan sayısı — kullanıcı talebi üzerine ("5
  /// mekan göster, 10 bile çok fazla") sıkı bir üst sınır. Önceden 20'ye
  /// kadar çekilip 4 sayfaya bölünüyordu; artık tek seferde en fazla bu
  /// kadar mekan gösteriliyor, sayfalama yok.
  static const int maxVenueResults = 5;

  /// Ana sayfadaki "Yakınınızdaki Beğenilen Mekanlar" carousel'inde,
  /// kullanıcının kayıtlı konumundan en fazla bu kadar km uzaktaki yorumlar
  /// gösterilir.
  ///
  /// Önceden bu bölüm ("Öne Çıkan Mekanlar ve Yorumlar") konumdan bağımsız,
  /// TÜM kullanıcıların TÜM yorumlarını puana göre sıralayıp gösteriyordu —
  /// bu da örn. İstanbul'daki bir kullanıcıya Kocaeli'deki bir mekanın
  /// yorumunu öneri olarak gösterebiliyordu (gerçekte gidemeyeceği bir yer).
  static const double nearbyLikedVenuesRadiusKm = 10.0;
}
