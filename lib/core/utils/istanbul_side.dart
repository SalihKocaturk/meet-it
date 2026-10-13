/// İstanbul'da bir koordinatın Boğaz'ın hangi yakasında kaldığını bulur.
///
/// Neden: Beşiktaş'ta mekan arayan birine kuş uçuşu yakın diye Üsküdar'dan
/// mekan önermek mantıksız — arada deniz var, karşıya geçmek 30-60 dk sürer.
/// Arama yapan kişiler aynı yakadaysa önerilen mekanlar da o yakada kalır.
///
/// Yöntem: Boğaz'ın orta hattı güneyden kuzeye bir çizgi (enlem → boylam)
/// olarak tanımlı. Noktanın enlemindeki orta hat boylamı bulunur; nokta bu
/// boylamın doğusundaysa Anadolu, batısındaysa Avrupa yakasıdır. Orta hattın
/// güneyinde (Marmara) Kadıköy/Bostancı tarafı Anadolu, Fatih/Bakırköy
/// tarafı Avrupa sayılır. Adalar Anadolu yakasına düşer.
library;

enum IstanbulSide { europe, asia }

class IstanbulSides {
  IstanbulSides._();

  // İstanbul il sınırlarını kabaca kapsayan kutu. Dışındaki noktalar için
  // yaka kavramı yok (null döner → filtre uygulanmaz).
  static const double _minLat = 40.80;
  static const double _maxLat = 41.60;
  static const double _minLng = 27.95;
  static const double _maxLng = 29.95;

  // Boğaz orta hattı: (enlem, boylam), güneyden kuzeye sıralı.
  // Her nokta iki kıyıdaki karşılıklı semtlerin ortası alınarak seçildi
  // (Sarayburnu/Salacak, Beşiktaş/Üsküdar, Ortaköy/Beylerbeyi, Bebek/
  // Kandilli, Rumelihisarı/Anadoluhisarı, Emirgan/Kanlıca, Yeniköy/
  // Paşabahçe, Tarabya/Beykoz, Sarıyer/Anadolukavağı, Rumelifeneri/
  // Anadolufeneri).
  static const List<List<double>> _bosphorus = [
    [40.990, 29.000],
    [41.020, 28.996],
    [41.035, 29.010],
    [41.046, 29.035],
    [41.062, 29.052],
    [41.077, 29.053],
    [41.084, 29.062],
    [41.103, 29.061],
    [41.120, 29.080],
    [41.137, 29.078],
    [41.172, 29.072],
    [41.226, 29.130],
    [41.300, 29.130],
  ];

  /// İstanbul dışındaysa `null`.
  static IstanbulSide? of(double lat, double lng) {
    if (lat < _minLat || lat > _maxLat || lng < _minLng || lng > _maxLng) {
      return null;
    }
    return lng > _bosphorusLngAt(lat) ? IstanbulSide.asia : IstanbulSide.europe;
  }

  static double _bosphorusLngAt(double lat) {
    final first = _bosphorus.first;
    final last = _bosphorus.last;
    if (lat <= first[0]) return first[1];
    if (lat >= last[0]) return last[1];
    for (var i = 0; i < _bosphorus.length - 1; i++) {
      final a = _bosphorus[i];
      final b = _bosphorus[i + 1];
      if (lat >= a[0] && lat <= b[0]) {
        final t = (lat - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * t;
      }
    }
    return last[1];
  }
}
