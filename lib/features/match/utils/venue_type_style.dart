import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/features/match/models/place_result.dart';

// ── Mekan Tipi Görsel Kimliği ─────────────────────────────────────────────────
//
// Her mekan tipinin (kafe, restoran, bar...) kendine ait ikon + renk çifti.
// Hem harita üzerindeki özel pinlerde (bkz. venue_type_pin.dart) hem de
// profildeki Kaydedilenler / Tarifi Alınanlar filtre butonlarında AYNI
// kaynaktan okunur — böylece "kahve fincanlı kahverengi pin" ile "Kafe"
// filtresi görsel olarak birebir eşleşir.
@immutable
class VenueTypeStyle {
  /// Google Places tipi (örn. 'cafe') — tanınmayan tipler için 'other'.
  final String key;
  final IconData icon;

  /// Pin gradyanının açık (üst) tonu.
  final Color color;

  /// Pin gradyanının koyu (alt) tonu.
  final Color colorDark;

  const VenueTypeStyle({
    required this.key,
    required this.icon,
    required this.color,
    required this.colorDark,
  });

  /// Yerelleştirilmiş kısa etiket (filtre butonlarında gösterilir).
  String get label => 'venue_types.$key'.tr();

  static const other = VenueTypeStyle(
    key: 'other',
    icon: Icons.place_rounded,
    color: Color(0xFF6EC99C),
    colorDark: Color(0xFF3F9A6E),
  );

  static const Map<String, VenueTypeStyle> _styles = {
    'cafe': VenueTypeStyle(
      key: 'cafe',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFFB0835F),
      colorDark: Color(0xFF7A4E2D),
    ),
    'restaurant': VenueTypeStyle(
      key: 'restaurant',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF8A65),
      colorDark: Color(0xFFE0533A),
    ),
    'bar': VenueTypeStyle(
      key: 'bar',
      icon: Icons.local_bar_rounded,
      color: Color(0xFFB388FF),
      colorDark: Color(0xFF7C4DDB),
    ),
    'night_club': VenueTypeStyle(
      key: 'night_club',
      icon: Icons.nightlife_rounded,
      color: Color(0xFFF06292),
      colorDark: Color(0xFFB0306A),
    ),
    'bakery': VenueTypeStyle(
      key: 'bakery',
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFFFFC46B),
      colorDark: Color(0xFFE09422),
    ),
    'museum': VenueTypeStyle(
      key: 'museum',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF7986CB),
      colorDark: Color(0xFF3F4FA8),
    ),
    'art_gallery': VenueTypeStyle(
      key: 'art_gallery',
      icon: Icons.palette_rounded,
      color: Color(0xFFEC7FB5),
      colorDark: Color(0xFFC2427F),
    ),
    'park': VenueTypeStyle(
      key: 'park',
      icon: Icons.park_rounded,
      color: Color(0xFF81C784),
      colorDark: Color(0xFF3E8E44),
    ),
    'gym': VenueTypeStyle(
      key: 'gym',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFFF7A7A),
      colorDark: Color(0xFFD13C3C),
    ),
    'movie_theater': VenueTypeStyle(
      key: 'movie_theater',
      icon: Icons.movie_rounded,
      color: Color(0xFF5C7CFA),
      colorDark: Color(0xFF2F4AC7),
    ),
    'bowling_alley': VenueTypeStyle(
      key: 'bowling_alley',
      icon: Icons.sports_baseball_rounded,
      color: Color(0xFF4DD0E1),
      colorDark: Color(0xFF168FA0),
    ),
    'library': VenueTypeStyle(
      key: 'library',
      icon: Icons.local_library_rounded,
      color: Color(0xFFA1887F),
      colorDark: Color(0xFF6D4C41),
    ),
    'amusement_park': VenueTypeStyle(
      key: 'amusement_park',
      icon: Icons.attractions_rounded,
      color: Color(0xFFFFB74D),
      colorDark: Color(0xFFEF6C00),
    ),
    'shopping_mall': VenueTypeStyle(
      key: 'shopping_mall',
      icon: Icons.local_mall_rounded,
      color: Color(0xFF4DB6AC),
      colorDark: Color(0xFF00796B),
    ),
    'spa': VenueTypeStyle(
      key: 'spa',
      icon: Icons.spa_rounded,
      color: Color(0xFF9FD8C8),
      colorDark: Color(0xFF4FA38C),
    ),
    'tourist_attraction': VenueTypeStyle(
      key: 'tourist_attraction',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF64B5F6),
      colorDark: Color(0xFF1E78C8),
    ),
  };

  /// Tip anahtarından stil (tanınmayan anahtar → [other]).
  static VenueTypeStyle byKey(String key) => _styles[key] ?? other;

  /// Mekanın tanınan ilk tipine göre stil. `PlaceResult.primaryType` ile
  /// aynı öncelik mantığını kullanır; bilinen hiçbir tip yoksa [other].
  static VenueTypeStyle of(PlaceResult place) {
    for (final type in place.types) {
      final style = _styles[type];
      if (style != null) return style;
    }
    return other;
  }
}
