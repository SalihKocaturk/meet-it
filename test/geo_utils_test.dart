import 'package:flutter_test/flutter_test.dart';
import 'package:meetit/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.haversineKm', () {
    test('aynı nokta için mesafe 0 olmalı', () {
      expect(GeoUtils.haversineKm(41.0082, 28.9784, 41.0082, 28.9784), 0);
    });

    test('1 derece enlem yaklaşık 111.19 km olmalı', () {
      final d = GeoUtils.haversineKm(0, 0, 1, 0);
      expect(d, closeTo(111.19, 0.05));
    });

    test('İstanbul - Ankara yaklaşık 349 km olmalı', () {
      final d = GeoUtils.haversineKm(41.0082, 28.9784, 39.9334, 32.8597);
      expect(d, closeTo(349.5, 3));
    });

    test('mesafe simetrik olmalı (A→B == B→A)', () {
      final ab = GeoUtils.haversineKm(41.0082, 28.9784, 39.9334, 32.8597);
      final ba = GeoUtils.haversineKm(39.9334, 32.8597, 41.0082, 28.9784);
      expect(ab, closeTo(ba, 1e-9));
    });

    test('dünyanın zıt noktaları yarım çevre kadar olmalı (~20015 km)', () {
      final d = GeoUtils.haversineKm(0, 0, 0, 180);
      expect(d, closeTo(20015.09, 0.5));
    });
  });
}
