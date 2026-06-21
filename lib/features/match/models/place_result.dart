import 'package:easy_localization/easy_localization.dart';
import 'package:meetit/core/constants/app_config.dart';

/// Google Places API'dan dönen tek bir mekan sonucu
class PlaceResult {
  final String placeId;
  final String name;
  final String? vicinity; // kısa adres
  final double? rating;
  final int? userRatingsTotal;
  final List<String> types; // ['restaurant', 'food', ...]
  final String? photoReference; // Places Photo API için (galerideki İLK foto)
  // Google Places Nearby Search yanıtındaki TÜM photo_reference'lar.
  // Google genelde bir mekan için birden fazla foto döndürür (genelde 1-10
  // arası); önceden sadece ilki tutulduğu için mekan detay galerisi
  // kullanıcı yorum fotoğrafı yoksa hep tek fotoğrafa düşüyordu. Artık
  // hepsi tutuluyor ki galeri gerçekten "galeri" gibi dönebilsin.
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

  /// Fotoğraf URL'si — null ise mekanın fotoğrafı yok (geriye dönük uyum
  /// için ilk fotoğrafı döner; galeri için [photoUrls] kullanılmalı).
  String? get photoUrl {
    if (photoReference == null) return null;
    return _buildPhotoUrl(photoReference!);
  }

  /// Mekana ait TÜM fotoğrafların URL listesi (Google resmi fotoğrafları).
  /// Mekan detay sayfasındaki galeri bunu kullanır — tek foto yerine
  /// gerçekten birden çok foto arasında dönebilsin diye.
  List<String> get photoUrls =>
      photoReferences.map(buildPhotoUrl).toList();

  static String _buildPhotoUrl(String reference) => buildPhotoUrl(reference);

  /// Bir `photo_reference`'tan kullanılabilir bir resim URL'si üretir.
  /// Public — PlacesService.fetchPhotoUrls gibi PlaceResult dışındaki
  /// yerlerin de aynı URL formatını üretebilmesi için.
  static String buildPhotoUrl(String reference) =>
      '${AppConfig.placesPhotoUrl}'
      '?maxwidth=800'
      '&photo_reference=$reference'
      '&key=${AppConfig.googleMapsApiKey}';

  /// Google Maps'te aç URL'si
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$placeId';

  /// JSON'dan parse et (Places API response)
  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final location = json['geometry']?['location'] ?? {};
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;

    return PlaceResult(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      vicinity: json['vicinity'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      types: (json['types'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      photoReference: photos != null && photos.isNotEmpty
          ? photos.first['photo_reference'] as String?
          : null,
      // En fazla 8 foto referansı tutuluyor — galeri için yeterli, ama
      // gereksiz yere çok sayıda Places Photo isteği yapılmasın diye sınırlı.
      photoReferences: photos == null
          ? const []
          : photos
              .map((p) => (p as Map<String, dynamic>)['photo_reference'] as String?)
              .whereType<String>()
              .take(8)
              .toList(),
      lat: (location['lat'] as num?)?.toDouble() ?? 0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0,
      isOpenNow: openingHours?['open_now'] as bool? ?? false,
      priceLevel: json['price_level'] as int?,
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
