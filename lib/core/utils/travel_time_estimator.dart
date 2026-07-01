import 'dart:math' as math;

/// Kuş uçuşu (Haversine) mesafe + ulaşım süresi TAHMİNİ — FALLBACK katmanı.
///
/// NOT (güncelleme): Bu modül başlangıçta TEK veri kaynağıydı (kullanıcıyla
/// yapılan ilk konuşmada bilinçli olarak ek API maliyeti istenmediği için
/// seçilmişti). Kullanıcı daha sonra bunun gerçekliği yansıtmadığını
/// belirtti (örn. araya boğaz/köprü girince tahmin çok sapabiliyor) — bu
/// yüzden asıl veri kaynağı artık Google Distance Matrix API
/// (bkz. `distance_matrix_service.dart`). Bu dosyadaki Haversine + ortalama
/// hız hesaplaması SADECE şu durumlarda devreye giriyor:
///   - Distance Matrix API Cloud Console'da etkinleştirilmemişse,
///   - Kota dolmuş/ağ hatası varsa,
///   - API'den belirli bir mekan/mod için sonuç dönmemişse.
/// Bu yüzden hâlâ "~" (yaklaşık) öneki ile gösterilmeli — gerçek API
/// verisinden farklı olarak `TravelEstimate.isApproximate` burada hep
/// `true` döner.

/// İki koordinat arasındaki kuş uçuşu mesafe (km).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180);

/// Üç ulaşım modu için süre (dakika).
///
/// NOT: Üç alan da nullable — bir mod için veri yoksa (örn. bölgede toplu
/// taşıma rotası bulunamadı ya da API o mod için sonuç döndürmedi) `null`
/// kalır ve arayüzde o chip hiç gösterilmez.
class TravelEstimate {
  final int? carMinutes;
  final int? transitMinutes;
  final int? walkMinutes; // çok uzaksa/veri yoksa null

  /// `true` ⇒ bu süreler kuş uçuşu mesafeden TAHMİN edildi (Distance Matrix
  /// API'ye ulaşılamadığı için düşülen fallback) — arayüzde "~" öneki ile
  /// gösterilmeli. `false` ⇒ Google Distance Matrix API'den gelen GERÇEK
  /// (trafik tahminli) süre.
  final bool isApproximate;

  const TravelEstimate({
    required this.carMinutes,
    required this.transitMinutes,
    required this.walkMinutes,
    this.isApproximate = true,
  });
}

// Ortalama hız varsayımları (km/h) — şehir içi kısa/orta mesafe senaryosuna
// göre kabaca kalibre edildi:
// - Araba: sinyalizasyon + trafik dahil şehir içi ortalama (otoyol değil).
// - Toplu taşıma: yürüyüş + bekleme + duraklar dahil EFEKTİF ortalama hız
//   (araçtaki saatlik hızdan daha düşük tutuldu çünkü bekleme süresi de var).
// - Yürüme: ortalama yetişkin yürüme hızı.
const double _kCarAvgSpeedKmH = 24.0;
const double _kTransitAvgSpeedKmH = 16.0;
const double _kWalkAvgSpeedKmH = 4.8;

// Yürüme süresi bu eşiğin (km) üzerindeyse anlamsız kabul edilip
// gösterilmiyor (örn. 25 km'yi "yürü" demek kullanıcıya gerçekçi gelmez).
const double _kMaxWalkableKm = 6.0;

/// Verilen kuş uçuşu mesafeden (km) üç mod için tahmini süre üretir.
///
/// Kuş uçuşu mesafe gerçek yol mesafesinden kısa olduğu için, gerçekçi bir
/// "yaklaşık" değer üretmek amacıyla hafif bir yol-faktörü (1.3x) uygulanır
/// — yollar düz bir çizgi izlemez, bu sayede tahmin gerçek süreye daha
/// yakınlaşır (yine de "~" ile yaklaşık olduğu belirtilmeli).
TravelEstimate estimateTravelTimes(double straightLineDistanceKm) {
  const roadFactor = 1.3;
  final roadKm = straightLineDistanceKm * roadFactor;

  int minutesFor(double speedKmH) {
    final minutes = (roadKm / speedKmH) * 60;
    return math.max(1, minutes.round());
  }

  return TravelEstimate(
    carMinutes: minutesFor(_kCarAvgSpeedKmH),
    transitMinutes: minutesFor(_kTransitAvgSpeedKmH),
    walkMinutes: straightLineDistanceKm <= _kMaxWalkableKm
        ? minutesFor(_kWalkAvgSpeedKmH)
        : null,
  );
}

/// Dakikayı "12 dk" veya "1 sa 20 dk" gibi okunabilir bir metne çevirir.
String formatTravelMinutes(int minutes) {
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  return rem == 0 ? '$hours sa' : '$hours sa $rem dk';
}
