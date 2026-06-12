import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// Google Places Nearby Search API wrapper.
///
/// İki kişinin kişilik profiline ve seçili aktivitelere göre mekan arar.
/// Sonuçları kişilik uyumuna + rating'e göre sıralar, sayfalama için
/// tüm havuzu döner (max 20 mekan).
class PlacesService {
  const PlacesService._();

  // ── Kişilik tipi → Places API type eşlemesi ───────────────────────────────

  static const Map<PersonalityType, List<String>> _personalityTypes = {
    PersonalityType.sosyalKelebek: ['bar', 'night_club', 'restaurant'],
    PersonalityType.sakinRuh: ['cafe', 'park', 'library'],
    PersonalityType.maceraperest: ['gym', 'park', 'bowling_alley', 'amusement_park'],
    PersonalityType.entelektuel: ['museum', 'art_gallery', 'library', 'movie_theater'],
    PersonalityType.gurme: ['restaurant', 'bakery', 'cafe'],
  };

  // ── Kişilik tipi → mekan tipi AĞIRLIK skoru ──────────────────────────────
  // Her mekan kendi types listesiyle bu skorla eşleştirilir.
  // Yüksek skor = kişiliğe çok uygun.

  static const Map<PersonalityType, Map<String, double>> _personalityScores = {
    PersonalityType.sosyalKelebek: {
      'bar': 1.0,
      'night_club': 1.0,
      'restaurant': 0.8,
      'cafe': 0.4,
      'amusement_park': 0.5,
    },
    PersonalityType.sakinRuh: {
      'cafe': 1.0,
      'park': 1.0,
      'library': 0.9,
      'bakery': 0.7,
      'museum': 0.6,
      'restaurant': 0.4,
    },
    PersonalityType.maceraperest: {
      'gym': 1.0,
      'bowling_alley': 1.0,
      'amusement_park': 1.0,
      'park': 0.9,
      'night_club': 0.5,
      'bar': 0.4,
    },
    PersonalityType.entelektuel: {
      'museum': 1.0,
      'art_gallery': 1.0,
      'library': 0.9,
      'movie_theater': 0.8,
      'cafe': 0.6,
      'park': 0.5,
    },
    PersonalityType.gurme: {
      'restaurant': 1.0,
      'bakery': 0.9,
      'cafe': 0.8,
      'bar': 0.5,
      'night_club': 0.3,
    },
  };

  // ── Aktivite metni → Places type ──────────────────────────────────────────

  static const Map<String, String> _activityToType = {
    'kafe': 'cafe',
    'kahve': 'cafe',
    'restoran': 'restaurant',
    'yemek': 'restaurant',
    'bar': 'bar',
    'müze': 'museum',
    'kültür': 'museum',
    'galeri': 'art_gallery',
    'park': 'park',
    'doğa': 'park',
    'spor': 'gym',
    'sinema': 'movie_theater',
    'alışveriş': 'shopping_mall',
    'bowling': 'bowling_alley',
    'kitap': 'library',
    'spa': 'spa',
    'eğlence': 'amusement_park',
  };

  // ── Ana Arama Metodu ───────────────────────────────────────────────────────

  /// Yakındaki mekanları çeker, kişilik + rating skoruna göre sıralar.
  /// Sayfalama için tüm havuzu (max 20) döner.
  static Future<List<PlaceResult>> searchVenues({
    required double lat,
    required double lng,
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
    int? priceLevel,
  }) async {
    final types = _resolveTypes(
      userProfile: userProfile,
      friendProfile: friendProfile,
      selectedActivities: selectedActivities,
    );

    // ignore: avoid_print
    print('🔍 PlacesService types: $types');

    final seen = <String>{};
    final results = <PlaceResult>[];

    // Her type için fetch et — daha fazla sonuç için limit'i yükselt
    for (final type in types) {
      final batch = await _fetchNearby(
          lat: lat, lng: lng, type: type, priceLevel: priceLevel);

      for (final place in batch) {
        if (!seen.contains(place.placeId)) {
          seen.add(place.placeId);
          results.add(place);
        }
      }
    }

    if (results.isEmpty) return [];

    // ── Kişilik + rating kombinasyon skoru ─────────────────────────────────
    final scored = results.map((place) {
      final personalityScore = _personalityMatch(
        place, userProfile, friendProfile, selectedActivities,
      );
      final ratingScore = (place.rating ?? 3.0) / 5.0;
      // %60 kişilik uyumu + %40 rating
      final total = personalityScore * 0.6 + ratingScore * 0.4;
      return (place, total);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    // Maksimum 20 mekan döner (sayfalama için)
    return scored.take(20).map((e) => e.$1).toList();
  }

  // ── Kişilik uyum skoru hesapla ────────────────────────────────────────────

  /// Bir mekanın iki kişilik profiline ne kadar uyduğunu 0.0–1.0 arası döner.
  static double _personalityMatch(
    PlaceResult place,
    PersonalityProfile userProfile,
    PersonalityProfile friendProfile,
    List<String> selectedActivities,
  ) {
    double score = 0.0;
    int matched = 0;

    // Seçili aktiviteler bonus — eğer mekan seçilen aktivite tipindeyse +1
    for (final activity in selectedActivities) {
      final lower = activity.toLowerCase();
      for (final entry in _activityToType.entries) {
        if (lower.contains(entry.key)) {
          if (place.types.contains(entry.value)) {
            score += 1.0;
            matched++;
          }
          break;
        }
      }
    }

    // Her kişilik tipi için ağırlıklı skor
    void addProfileScore(PersonalityProfile profile) {
      for (final entry in profile.scores.entries) {
        final typeWeight = entry.value; // kişilik tipine verilen ağırlık
        final placeScores = _personalityScores[entry.key] ?? {};
        for (final placeType in place.types) {
          if (placeScores.containsKey(placeType)) {
            score += placeScores[placeType]! * typeWeight;
            matched++;
          }
        }
      }
    }

    addProfileScore(userProfile);
    addProfileScore(friendProfile);

    if (matched == 0) return 0.3; // eşleşme yoksa düşük ama sıfır değil
    return (score / matched).clamp(0.0, 1.0);
  }

  // ── Places Nearby Search HTTP ─────────────────────────────────────────────

  static Future<List<PlaceResult>> _fetchNearby({
    required double lat,
    required double lng,
    required String type,
    int? priceLevel,
  }) async {
    final params = <String, String>{
      'location': '$lat,$lng',
      'radius': '${AppConfig.defaultSearchRadius}',
      'type': type,
      'language': 'tr',
      'key': AppConfig.googleMapsApiKey,
    };
    if (priceLevel != null) {
      params['minprice'] = '$priceLevel';
      params['maxprice'] = '$priceLevel';
    }

    final uri = Uri.parse(AppConfig.placesNearbyUrl)
        .replace(queryParameters: params);

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        // ignore: avoid_print
        print('[PlacesService] status=$status body=${response.body}');
        return [];
      }

      final rawResults = body['results'] as List<dynamic>? ?? [];
      // API'dan gelen tüm sonuçları al (max 20)
      return rawResults
          .map((r) => PlaceResult.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[PlacesService] fetch error: $e');
      return [];
    }
  }

  // ── Type Çözümleme ─────────────────────────────────────────────────────────

  static List<String> _resolveTypes({
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
  }) {
    // ── MOD 1: Aktivite seçilmişse SADECE o tipler ───────────────────────────
    // Kullanıcı ne seçtiyse onu göster, kişilik karıştırma.
    if (selectedActivities.isNotEmpty) {
      final types = <String>{};
      for (final activity in selectedActivities) {
        final lower = activity.toLowerCase();
        for (final entry in _activityToType.entries) {
          if (lower.contains(entry.key)) {
            types.add(entry.value);
            break;
          }
        }
      }
      // Eşleşen type yoksa (tanımsız aktivite) kişiliğe geri dön
      if (types.isNotEmpty) return types.toList();
    }

    // ── MOD 2: Aktivite seçilmemişse SADECE kişiliğe göre ────────────────────
    final types = <String>{};

    final userTypes = _personalityTypes[userProfile.dominantType] ?? [];
    final friendTypes = _personalityTypes[friendProfile.dominantType] ?? [];

    // İki kişinin ortak tipleri önce (her ikisine de uygun)
    final common = userTypes.toSet().intersection(friendTypes.toSet());
    types.addAll(common);
    types.addAll(userTypes);
    types.addAll(friendTypes);

    // Secondary tipler — daha geniş havuz
    if (userProfile.secondaryType != null) {
      types.addAll(_personalityTypes[userProfile.secondaryType!] ?? []);
    }
    if (friendProfile.secondaryType != null) {
      types.addAll(_personalityTypes[friendProfile.secondaryType!] ?? []);
    }

    return types.take(5).toList();
  }
}
