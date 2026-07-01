import 'dart:math';

/// Ortak coğrafi yardımcı fonksiyonlar.
///
/// NOT: `venue_search_notifier.dart` içinde de aynı haversine hesaplaması
/// private olarak duruyordu (sadece orta nokta aramasında kullanılıyordu).
/// Ana sayfadaki "yakınınızdaki beğenilen mekanlar" özelliği için de aynı
/// hesaplamaya ihtiyaç duyulduğunda kopyalamak yerine paylaşılan bu dosya
/// oluşturuldu — gelecekte mesafe hesabı gereken her yeni özellik buradan
/// faydalanabilir.
class GeoUtils {
  GeoUtils._();

  static double _deg2rad(double deg) => deg * pi / 180;

  /// İki koordinat arasındaki mesafeyi kilometre cinsinden döndürür
  /// (Haversine formülü, Dünya yarıçapı ~6371 km kabul edilir).
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
