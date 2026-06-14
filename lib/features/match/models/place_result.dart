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
  final String? photoReference; // Places Photo API için
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
    required this.lat,
    required this.lng,
    this.isOpenNow = false,
    this.priceLevel,
  });

  /// Fotoğraf URL'si — null ise mekanın fotoğrafı yok
  String? get photoUrl {
    if (photoReference == null) return null;
    return '${AppConfig.placesPhotoUrl}'
        '?maxwidth=600'
        '&photo_reference=$photoReference'
        '&key=${AppConfig.googleMapsApiKey}';
  }

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
