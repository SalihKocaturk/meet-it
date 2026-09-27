// ── Desteklenen Şehirler ──────────────────────────────────────────────────────
//
// 🗺️ KAPSAM (2026-09-27): Uygulama önceden SADECE İstanbul'da açıktı. Artık
// Türkiye'nin nüfusça en büyük 10 ilinde (TÜİK ADNKS sıralaması) açık:
// İstanbul, Ankara, İzmir, Bursa, Antalya, Konya, Adana, Şanlıurfa,
// Gaziantep, Kocaeli.
//
// Kapsam kontrolü TEK YERDEN buradan yapılır:
//   • MapLocationPickerPage → seçilen konum desteklenen bir ilde mi
//   • userLocationProvider   → DB'deki kayıtlı konum geçerli mi
// Yeni bir şehir açmak için [SupportedCities.all] listesine bir satır
// eklemek yeterli.
//
// Her şehir, ilin TÜM ilçelerini kapsayacak kadar geniş bir enlem/boylam
// kutusuyla tanımlı (il sınırının birebir poligonu değil). Kutular komşu
// illerin sınır bölgelerine biraz taşabilir — bilinçli olarak geniş
// tutuldu ki il içindeki hiçbir ilçe yanlışlıkla dışarıda kalmasın.

class SupportedCity {
  final String name;
  final double centerLat;
  final double centerLng;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const SupportedCity({
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

class SupportedCities {
  SupportedCities._();

  /// Nüfus sırasına göre (büyükten küçüğe).
  static const List<SupportedCity> all = [
    SupportedCity(
      name: 'İstanbul',
      centerLat: 41.0082,
      centerLng: 28.9784,
      minLat: 40.80,
      maxLat: 41.60,
      minLng: 27.85,
      maxLng: 29.95,
    ),
    SupportedCity(
      name: 'Ankara',
      centerLat: 39.9334,
      centerLng: 32.8597,
      minLat: 38.60,
      maxLat: 40.75,
      minLng: 30.80,
      maxLng: 34.00,
    ),
    SupportedCity(
      name: 'İzmir',
      centerLat: 38.4237,
      centerLng: 27.1428,
      minLat: 37.75,
      maxLat: 39.40,
      minLng: 26.15,
      maxLng: 28.50,
    ),
    SupportedCity(
      name: 'Bursa',
      centerLat: 40.1885,
      centerLng: 29.0610,
      minLat: 39.50,
      maxLat: 40.65,
      minLng: 28.05,
      maxLng: 30.00,
    ),
    SupportedCity(
      name: 'Antalya',
      centerLat: 36.8969,
      centerLng: 30.7133,
      minLat: 36.05,
      maxLat: 37.55,
      minLng: 29.20,
      maxLng: 32.65,
    ),
    SupportedCity(
      name: 'Konya',
      centerLat: 37.8746,
      centerLng: 32.4932,
      minLat: 36.65,
      maxLat: 39.30,
      minLng: 31.20,
      maxLng: 34.45,
    ),
    SupportedCity(
      name: 'Adana',
      centerLat: 37.0000,
      centerLng: 35.3213,
      minLat: 36.50,
      maxLat: 38.45,
      minLng: 34.75,
      maxLng: 36.30, // Tufanbeyli/Saimbeyli dahil
    ),
    SupportedCity(
      name: 'Şanlıurfa',
      centerLat: 37.1591,
      centerLng: 38.7969,
      minLat: 36.65,
      maxLat: 38.05,
      minLng: 37.85,
      maxLng: 40.25,
    ),
    SupportedCity(
      name: 'Gaziantep',
      centerLat: 37.0662,
      centerLng: 37.3833,
      minLat: 36.60,
      maxLat: 37.60,
      minLng: 36.45,
      maxLng: 38.05,
    ),
    SupportedCity(
      name: 'Kocaeli',
      centerLat: 40.7654,
      centerLng: 29.9408,
      minLat: 40.50,
      maxLat: 41.25,
      minLng: 29.30,
      maxLng: 30.40,
    ),
  ];

  /// Varsayılan şehir (konum bilinmiyorsa harita buradan açılır).
  static SupportedCity get fallback => all.first;

  /// Koordinat hangi desteklenen şehirde (yoksa null).
  static SupportedCity? cityAt(double lat, double lng) {
    for (final c in all) {
      if (c.contains(lat, lng)) return c;
    }
    return null;
  }

  static bool contains(double lat, double lng) => cityAt(lat, lng) != null;

  /// Uyarı metinleri için: "İstanbul, Ankara, İzmir, ..."
  static String get namesText => all.map((c) => c.name).join(', ');

  /// Konum seçme haritasının kaydırılabileceği alan: Türkiye geneli.
  /// (Tek tek şehir kutularıyla sınırlamak mümkün değil — CameraTargetBounds
  /// tek bir dikdörtgen alıyor; kapsam kontrolü onay anında yapılıyor.)
  static const double turkeyMinLat = 35.80;
  static const double turkeyMaxLat = 42.20;
  static const double turkeyMinLng = 25.60;
  static const double turkeyMaxLng = 44.90;
}
