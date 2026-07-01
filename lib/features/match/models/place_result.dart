import 'package:easy_localization/easy_localization.dart';
import 'package:meetit/core/constants/app_config.dart';

/// Google Places API (New) `searchNearby` / Place Details yanıtından dönen
/// tek bir mekan sonucu.
///
/// NOT (Foursquare'den geri dönüş, 2026-06-27): Bu sınıf bir süre Foursquare
/// JSON şeklini ayrıştırıyordu. Artık tekrar Google Places kullanılıyor —
/// ama eski Legacy API DEĞİL, yeni (New) `places.googleapis.com/v1` API'si.
/// Alan adları (placeId, types, photoReference vb.) BİLEREK değiştirilmedi
/// — uygulamanın geri kalanı (filtreleme, skorlama, harita pin'leri,
/// kaydetme, yorumlar) bu alan adlarına göre yazıldı. New API'nin `types`
/// alanı zaten Legacy ile AYNI taksonomiyi kullanıyor (örn. 'restaurant',
/// 'cafe', 'museum'), bu yüzden Foursquare döneminde gerekli olan
/// kategori-adı→içsel-tip çevirme katmanı artık YOK — types doğrudan
/// API'den geldiği gibi kullanılıyor.
class PlaceResult {
  final String placeId;
  final String name;
  final String? vicinity; // kısa adres
  final double? rating;
  final int? userRatingsTotal;
  final List<String> types; // ['restaurant', 'cafe', ...] (Google taksonomisi)
  final String? photoReference; // galerideki İLK foto için "photos/{id}" adı
  // Google Places (New) `photos[]` öğelerinin "name" alanları (örn.
  // "places/ChIJ.../photos/AUf1Q.."). Her biri doğrudan media endpoint'ine
  // verilip görsel URL'sine çevrilebilir (bkz. buildPhotoUrl).
  final List<String> photoReferences;
  final double lat;
  final double lng;
  final bool isOpenNow;
  final int? priceLevel; // 0=ücretsiz, 1=₺, 2=₺₺, 3=₺₺₺, 4=₺₺₺₺

  const PlaceResult({
    required this.placeId,
    required this.name,
    this.vicinity,
    this.rating,
    this.userRatingsTotal,
    this.types = const [],
    this.photoReference,
    this.photoReferences = const [],
    required this.lat,
    required this.lng,
    this.isOpenNow = false,
    this.priceLevel,
  });

  /// Çoğunlukla `photoReference`/`photoReferences` alanlarını ham Google
  /// foto referansından, ÖNBELLEKLENMİŞ (Firebase Storage) URL'ine
  /// değiştirmek için kullanılır (bkz. VenuePhotoCacheService) — immutable
  /// sınıfı bozmadan tek/birkaç alanı güncellemeyi sağlar.
  PlaceResult copyWith({
    String? placeId,
    String? name,
    String? vicinity,
    double? rating,
    int? userRatingsTotal,
    List<String>? types,
    String? photoReference,
    List<String>? photoReferences,
    double? lat,
    double? lng,
    bool? isOpenNow,
    int? priceLevel,
  }) {
    return PlaceResult(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      vicinity: vicinity ?? this.vicinity,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      types: types ?? this.types,
      photoReference: photoReference ?? this.photoReference,
      photoReferences: photoReferences ?? this.photoReferences,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      priceLevel: priceLevel ?? this.priceLevel,
    );
  }

  /// Fotoğraf URL'si — null ise mekanın fotoğrafı yok (geriye dönük uyum
  /// için ilk fotoğrafı döner; galeri için [photoUrls] kullanılmalı).
  ///
  /// 📍 KOTA HATASI AYRIMI (2026-06-29): `photoReference` boş string ('')
  /// olabilir — `PlacesService.searchVenues` foto kotası dolduğunda mekanı
  /// kasıtlı olarak `photoReference: ''` ile işaretliyor (bkz. yorum
  /// orada). Boş string'i de `null` gibi ele alıyoruz, aksi halde
  /// `buildPhotoUrl('')` geçersiz bir URL üretip UI'da kırık resim
  /// denemesine yol açardı.
  String? get photoUrl {
    if (photoReference == null || photoReference!.isEmpty) return null;
    return buildPhotoUrl(photoReference!);
  }

  /// Mekana ait TÜM fotoğrafların URL listesi.
  List<String> get photoUrls => photoReferences
      .where((r) => r.isNotEmpty)
      .map(buildPhotoUrl)
      .toList();

  /// Places API (New) foto "name" alanından (örn.
  /// "places/ChIJ.../photos/AUf1Q..") gösterilebilir bir görsel URL'si
  /// üretir. Bu URL doğrudan `Image.network`'e verilebilir — API anahtarı
  /// query parametresi olarak ekleniyor (media endpoint'i bunu bekliyor,
  /// X-Goog-Api-Key header'ı GET-ile-göster senaryosunda kullanılamaz).
  ///
  /// 💸 MALİYET DÜŞÜRME (2026-06-28): `VenuePhotoCacheService` artık ham
  /// Google foto referanslarını ÇÖZÜP Firebase Storage URL'ine çeviriyor
  /// ve bu çözümlenmiş `http(s)://` URL'i `photoReference`/`photoReferences`
  /// alanlarına GERİ yazıyor (bkz. PlacesService.searchVenues/fetchPhotoUrls).
  /// Bu fonksiyon girdinin ZATEN tam bir URL olup olmadığını kontrol eder —
  /// öyleyse AYNEN döner (yeniden Google formatına SARMAZ, aksi halde
  /// Storage URL'i bozulup geçersiz bir adrese dönüşürdü).
  static String buildPhotoUrl(String photoName) {
    if (photoName.startsWith('http://') || photoName.startsWith('https://')) {
      return photoName; // zaten çözümlenmiş (örn. Storage CDN URL'i)
    }
    // 📍 DUAL API SWITCH (2026-06-28): Legacy API'den gelen foto referansları
    // `fromLegacyJson`'da kasıtlı olarak `legacy:` öneki eklenerek saklanıyor
    // — çünkü Legacy'nin foto medya URL formatı (query param tabanlı,
    // `photo_reference=`) New API'nin (`places/{id}/photos/{id}/media`,
    // path tabanlı) formatından TAMAMEN farklı. Bu önek olmadan, ham bir
    // Legacy `photo_reference` string'i yanlışlıkla New API formatında
    // (geçersiz) bir URL'e dönüştürülürdü.
    if (photoName.startsWith('legacy:')) {
      final ref = photoName.substring('legacy:'.length);
      return '${AppConfig.placesPhotoUrlLegacy}'
          '?maxwidth=800&photo_reference=$ref&key=${AppConfig.googleMapsApiKey}';
    }
    return '${AppConfig.placesPhotoMediaBaseUrl}/$photoName/media'
        '?maxHeightPx=800&key=${AppConfig.googleMapsApiKey}';
  }

  /// Haritalar uygulamasında aç URL'si — koordinata göre açılıyor (Google
  /// Maps de Apple Maps de bu formatı destekliyor).
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  /// Google Places API (New) "PriceLevel" enum string'ini (örn.
  /// "PRICE_LEVEL_MODERATE") eski Legacy'nin 0-4 int ölçeğine çevirir.
  /// Uygulamanın TÜM fiyat gösterimi/filtrelemesi (bkz. [priceLabelText],
  /// PlacesService) bu 0-4 ölçeğine göre yazıldı.
  static int? _priceLevelFromEnum(String? value) {
    switch (value) {
      case 'PRICE_LEVEL_FREE':
        return 0;
      case 'PRICE_LEVEL_INEXPENSIVE':
        return 1;
      case 'PRICE_LEVEL_MODERATE':
        return 2;
      case 'PRICE_LEVEL_EXPENSIVE':
        return 3;
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return 4;
      default:
        return null; // PRICE_LEVEL_UNSPECIFIED veya alan hiç gelmedi
    }
  }

  /// JSON'dan parse et (Google Places API (New) `searchNearby` /
  /// Place Details yanıtındaki tek bir `places[]` öğesi).
  ///
  /// Beklenen şekil (FieldMask'e göre):
  /// {
  ///   "id": "ChIJ...",
  ///   "displayName": {"text": "...", "languageCode": "tr"},
  ///   "formattedAddress": "...",
  ///   "location": {"latitude": ..., "longitude": ...},
  ///   "types": ["restaurant", "cafe", ...],
  ///   "rating": 4.3,
  ///   "userRatingCount": 1280,
  ///   "priceLevel": "PRICE_LEVEL_MODERATE",
  ///   "regularOpeningHours": {"openNow": true},
  ///   "photos": [{"name": "places/.../photos/...", ...}, ...]
  /// }
  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;
    final regularOpeningHours =
        json['regularOpeningHours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;

    // 💸 MALİYET DÜŞÜRME (2026-06-28): Mekan başına önbelleğe alınan/
    // gösterilen galeri fotoğrafı 3 ile sınırlı (bkz. PlacesService.
    // _maxGalleryPhotos) — burada da aynı sınır kullanılıyor ki bu havuzdan
    // türetilen `photoUrls` listesi gereğinden fazla (ücretsiz olsa da
    // anlamsız) referans taşımasın.
    final photoNames = (photos ?? const [])
        .map((p) => (p as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .take(3)
        .toList();

    return PlaceResult(
      placeId: json['id'] as String? ?? '',
      name: displayName?['text'] as String? ?? json['name'] as String? ?? '',
      vicinity: json['formattedAddress'] as String? ??
          json['shortFormattedAddress'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: (json['userRatingCount'] as num?)?.toInt(),
      types: (json['types'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          const [],
      photoReference: photoNames.isNotEmpty ? photoNames.first : null,
      photoReferences: photoNames,
      lat: (location?['latitude'] as num?)?.toDouble() ?? 0,
      lng: (location?['longitude'] as num?)?.toDouble() ?? 0,
      isOpenNow: regularOpeningHours?['openNow'] as bool? ?? false,
      priceLevel: _priceLevelFromEnum(json['priceLevel'] as String?),
    );
  }

  /// JSON'dan parse et (Legacy Places API `nearbysearch` yanıtındaki tek bir
  /// `results[]` öğesi — bkz. PlacesService._fetchNearbyLegacy).
  ///
  /// 📍 DUAL API SWITCH (2026-06-28): Bu factory SADECE Firestore'daki
  /// `appConfig/placesApi.activeVersion` alanı `"legacy"` olduğunda
  /// kullanılır (bkz. PlacesApiVersionService). Legacy'nin JSON şekli New
  /// API'den TAMAMEN farklı (örn. `place_id` yerine `id`, `geometry.location`
  /// yerine düz `location`, foto referansları `photos[].photo_reference`
  /// string'i olarak gelir — `photos[].name` DEĞİL). Foto referansları
  /// burada kasıtlı olarak `legacy:` öneki eklenerek saklanıyor ki
  /// `buildPhotoUrl` hangi medya endpoint formatının kullanılacağını
  /// ayırt edebilsin.
  ///
  /// Beklenen şekil:
  /// {
  ///   "place_id": "ChIJ...",
  ///   "name": "...",
  ///   "vicinity": "...",
  ///   "geometry": {"location": {"lat": ..., "lng": ...}},
  ///   "types": ["restaurant", ...],
  ///   "rating": 4.3,
  ///   "user_ratings_total": 1280,
  ///   "price_level": 2,
  ///   "opening_hours": {"open_now": true},
  ///   "photos": [{"photo_reference": "..."}, ...]
  /// }
  factory PlaceResult.fromLegacyJson(Map<String, dynamic> json) {
    final location =
        (json['geometry'] as Map<String, dynamic>?)?['location']
                as Map<String, dynamic>? ??
            const {};
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;

    final photoNames = (photos ?? const [])
        .map((p) => (p as Map<String, dynamic>)['photo_reference'] as String?)
        .whereType<String>()
        .take(3)
        .map((ref) => 'legacy:$ref')
        .toList();

    return PlaceResult(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      vicinity: json['vicinity'] as String? ??
          json['formatted_address'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      types: (json['types'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          const [],
      photoReference: photoNames.isNotEmpty ? photoNames.first : null,
      photoReferences: photoNames,
      lat: (location['lat'] as num?)?.toDouble() ?? 0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0,
      isOpenNow: openingHours?['open_now'] as bool? ?? false,
      priceLevel: json['price_level'] as int?,
    );
  }

  /// Firestore/SharedPreferences'a KALICI olarak kaydetmek için kullanılan,
  /// hiçbir dış API'nin JSON şekline bağlı OLMAYAN düz bir map üretir.
  /// `fromJson` artık SADECE Google Places (New) yanıtını ayrıştırıyor —
  /// kaydedilen/tarif alınan mekanlar (`saved_venues_provider.dart`) gibi
  /// yerlerde KENDİ alan adlarımızı kullanan bu format ile [fromStorageMap]
  /// çifti kullanılmalı. Böylece hangi API'den geldiği (Foursquare'den
  /// kaydedilmiş eski kayıtlar dahil) önemli olmadan geriye okunabilir bir
  /// şema sabit kalır.
  Map<String, dynamic> toStorageMap() => {
        'placeId': placeId,
        'name': name,
        'vicinity': vicinity,
        'rating': rating,
        'userRatingsTotal': userRatingsTotal,
        'types': types,
        'photoReference': photoReference,
        'photoReferences': photoReferences,
        'lat': lat,
        'lng': lng,
        'isOpenNow': isOpenNow,
        'priceLevel': priceLevel,
      };

  /// [toStorageMap] ile yazılan bir map'i geri okur.
  factory PlaceResult.fromStorageMap(Map<String, dynamic> map) {
    return PlaceResult(
      placeId: map['placeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      vicinity: map['vicinity'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      userRatingsTotal: map['userRatingsTotal'] as int?,
      types: (map['types'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          const [],
      photoReference: map['photoReference'] as String?,
      photoReferences: (map['photoReferences'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          const [],
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      isOpenNow: map['isOpenNow'] as bool? ?? false,
      priceLevel: map['priceLevel'] as int?,
    );
  }

  /// Yıldız gösterimi için
  String get ratingText =>
      rating != null ? rating!.toStringAsFixed(1) : 'Yeni';

  /// Fiyat gösterimi: ₺, ₺₺, ₺₺₺, ₺₺₺₺
  String? get priceLabelText {
    if (priceLevel == null) return null;
    if (priceLevel == 0) return 'match.free'.tr();
    return '₺' * priceLevel!;
  }

  /// Tip etiketini Türkçeye çevir
  String get primaryTypeLabel {
    const typeMap = {
      'restaurant': 'Restoran',
      'cafe': 'Kafe',
      'bar': 'Bar',
      'museum': 'Müze',
      'art_gallery': 'Galeri',
      'park': 'Park',
      'gym': 'Spor Salonu',
      'movie_theater': 'Sinema',
      'bowling_alley': 'Bowling',
      'night_club': 'Gece Kulübü',
      'library': 'Kütüphane',
      'bakery': 'Pastane',
      'amusement_park': 'Eğlence Parkı',
      'shopping_mall': 'AVM',
      'spa': 'Spa',
    };
    for (final type in types) {
      if (typeMap.containsKey(type)) return typeMap[type]!;
    }
    return 'Mekan';
  }
}
