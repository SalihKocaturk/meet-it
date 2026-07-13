import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/utils/travel_time_estimator.dart';
import 'package:meetit/features/match/models/place_result.dart';

/// Ulaşım süresi servisi.
///
/// ── MEVCUT DURUM ─────────────────────────────────────────────────────────────
/// Google Distance Matrix API entegre edildi ancak şu an aktif DEĞİL —
/// Cloud Console'da "Distance Matrix API" ayrıca etkinleştirilmesi gerekiyor
/// ve bu yapılmadığında her istek REQUEST_DENIED döner. Bu yüzden her zaman
/// Haversine (kuş uçuşu × 1.3 yol faktörü) tahminine düşülüyor.
///
/// Tahminler UI'da "~" önekiyle gösterilir (bkz. `TravelEstimate.isApproximate`).
///
/// ── GERÇEK ULAŞIM SÜRESİNE GEÇİŞ ────────────────────────────────────────────
/// İleride Distance Matrix veya alternatif (Mapbox Directions, HERE Routing)
/// aktif edilmek istenirse `_kUseRealApi = true` yapılmalı ve ilgili API
/// Cloud Console'dan etkinleştirilmeli.
class DistanceMatrixService {
  const DistanceMatrixService._();

  /// `true` → gerçek API çağrısı yap (Distance Matrix)
  /// `false` → doğrudan Haversine tahmine düş (mevcut default)
  static const bool _kUseRealApi = false;

  static const List<String> _modes = ['driving', 'transit', 'walking'];

  /// Tek bir orijinden (kullanıcı konumu) verilen mekanlara üç mod için
  /// süre çeker. Dönüş: placeId → [TravelEstimate].
  static Future<Map<String, TravelEstimate>> fetchTravelEstimates({
    required double originLat,
    required double originLng,
    required List<PlaceResult> destinations,
  }) async {
    if (destinations.isEmpty) return {};

    // Distance Matrix devre dışı veya API key yoksa → Haversine
    if (!_kUseRealApi || AppConfig.googleMapsApiKey.isEmpty) {
      return _fallbackAll(originLat, originLng, destinations);
    }

    final destinationsParam = destinations
        .map((d) => '${d.lat},${d.lng}')
        .join('|');

    try {
      // Üç modu PARALEL iste — her biri bağımsız bir HTTP çağrısı.
      final results = await Future.wait(
        _modes.map(
          (mode) => _fetchMode(
            mode: mode,
            originLat: originLat,
            originLng: originLng,
            destinationsParam: destinationsParam,
            destinationCount: destinations.length,
          ),
        ),
      );

      final carMinutesList = results[0];
      final transitMinutesList = results[1];
      final walkMinutesList = results[2];

      final result = <String, TravelEstimate>{};
      for (var i = 0; i < destinations.length; i++) {
        final car = carMinutesList[i];
        final transit = transitMinutesList[i];
        final walk = walkMinutesList[i];

        if (car == null && transit == null && walk == null) {
          final dest = destinations[i];
          final distanceKm = haversineKm(
            originLat,
            originLng,
            dest.lat,
            dest.lng,
          );
          result[dest.placeId] = estimateTravelTimes(distanceKm);
        } else {
          result[destinations[i].placeId] = TravelEstimate(
            carMinutes: car,
            transitMinutes: transit,
            walkMinutes: walk,
            isApproximate: false,
          );
        }
      }
      return result;
    } catch (_) {
      return _fallbackAll(originLat, originLng, destinations);
    }
  }

  /// Tek bir mod (driving/transit/walking) için tek istek atar, dönen
  /// süreleri (dakika, mekan sırasıyla aynı index'te) liste olarak döner.
  /// Bir mekan için veri yoksa o index `null` kalır.
  static Future<List<int?>> _fetchMode({
    required String mode,
    required double originLat,
    required double originLng,
    required String destinationsParam,
    required int destinationCount,
  }) async {
    final nullList = List<int?>.filled(destinationCount, null);

    final uri = Uri.parse(AppConfig.distanceMatrixUrl).replace(
      queryParameters: {
        'origins': '$originLat,$originLng',
        'destinations': destinationsParam,
        'mode': mode,
        'language': 'tr',
        'key': AppConfig.googleMapsApiKey,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return nullList;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    // ignore: avoid_print

    if (status != 'OK') {
      // REQUEST_DENIED (API etkin değil) / OVER_QUERY_LIMIT (kota) /
      // INVALID_REQUEST gibi durumlarda bu mod için veri yok — üst katman
      // (fetchTravelEstimates) gerekirse fallback'e düşer.
      return nullList;
    }

    final rows = body['rows'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) return nullList;
    final elements = rows.first['elements'] as List<dynamic>?;
    if (elements == null) return nullList;

    return List<int?>.generate(destinationCount, (i) {
      if (i >= elements.length) return null;
      final el = elements[i] as Map<String, dynamic>;
      if (el['status'] != 'OK') return null;
      final durationSec = (el['duration']?['value'] as num?)?.toInt();
      if (durationSec == null) return null;
      final minutes = (durationSec / 60).round();
      return minutes < 1 ? 1 : minutes;
    });
  }

  static Map<String, TravelEstimate> _fallbackAll(
    double originLat,
    double originLng,
    List<PlaceResult> destinations,
  ) {
    return {
      for (final d in destinations)
        d.placeId: estimateTravelTimes(
          haversineKm(originLat, originLng, d.lat, d.lng),
        ),
    };
  }

  // ── Gerçek rota mesafesi (km) — mesafe FİLTRESİ için ─────────────────────
  //
  // Kullanıcı geri bildirimi: "kuş uçuşu mesafe ile hesap yapma, sacma,
  // gercekligi yansitmiyor — apiden al". Mesafe filtresi artık kuş uçuşu
  // (Haversine) yerine Google Distance Matrix'in DRIVING modundaki gerçek
  // yol mesafesini (`distance.value`, metre) kullanıyor — örn. boğaz/köprü/
  // tek yönlü yol araya girince düz çizgi mesafe gerçek yol mesafesinden
  // çok kısa çıkabiliyordu, bu da filtreyi yanıltıyordu.
  //
  // Sadece TEK mod (driving) isteniyor — filtre için süre değil, sadece
  // mesafe gerekiyor; üç modu da çekmek gereksiz maliyet olurdu. API
  // devre dışı/hatalıysa otomatik olarak kuş uçuşuna düşülür (her zamanki
  // fallback deseni, bkz. `fetchTravelEstimates`).
  static Future<Map<String, double>> fetchDistancesKm({
    required double originLat,
    required double originLng,
    required List<PlaceResult> destinations,
  }) async {
    if (destinations.isEmpty) return {};

    if (AppConfig.googleMapsApiKey.isEmpty) {
      return _fallbackDistancesAll(originLat, originLng, destinations);
    }

    final destinationsParam = destinations
        .map((d) => '${d.lat},${d.lng}')
        .join('|');

    try {
      final distances = await _fetchModeDistances(
        mode: 'driving',
        originLat: originLat,
        originLng: originLng,
        destinationsParam: destinationsParam,
        destinationCount: destinations.length,
      );

      final result = <String, double>{};
      for (var i = 0; i < destinations.length; i++) {
        final dest = destinations[i];
        // Bu mekan için driving mesafesi gelmediyse (örn. ada/karşı kıyı,
        // araçla erişilemeyen bir nokta) o mekan için kuş uçuşuna düş —
        // tüm aramayı fallback'e düşürmek yerine sadece o mekanı.
        result[dest.placeId] =
            distances[i] ?? haversineKm(originLat, originLng, dest.lat, dest.lng);
      }
      return result;
    } catch (_) {
      return _fallbackDistancesAll(originLat, originLng, destinations);
    }
  }

  /// `_fetchMode`'un mesafe (km) versiyonu — süre yerine `distance.value`
  /// (metre) parse eder. Aynı endpoint/istek şekli, sadece okunan alan farklı.
  static Future<List<double?>> _fetchModeDistances({
    required String mode,
    required double originLat,
    required double originLng,
    required String destinationsParam,
    required int destinationCount,
  }) async {
    final nullList = List<double?>.filled(destinationCount, null);

    final uri = Uri.parse(AppConfig.distanceMatrixUrl).replace(
      queryParameters: {
        'origins': '$originLat,$originLng',
        'destinations': destinationsParam,
        'mode': mode,
        'language': 'tr',
        'key': AppConfig.googleMapsApiKey,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return nullList;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK') return nullList;

    final rows = body['rows'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) return nullList;
    final elements = rows.first['elements'] as List<dynamic>?;
    if (elements == null) return nullList;

    return List<double?>.generate(destinationCount, (i) {
      if (i >= elements.length) return null;
      final el = elements[i] as Map<String, dynamic>;
      if (el['status'] != 'OK') return null;
      final distanceMeters = (el['distance']?['value'] as num?)?.toDouble();
      if (distanceMeters == null) return null;
      return distanceMeters / 1000.0;
    });
  }

  static Map<String, double> _fallbackDistancesAll(
    double originLat,
    double originLng,
    List<PlaceResult> destinations,
  ) {
    return {
      for (final d in destinations)
        d.placeId: haversineKm(originLat, originLng, d.lat, d.lng),
    };
  }
}
