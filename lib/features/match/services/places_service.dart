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

  // ── Hiçbir zaman gösterilmeyecek type'lar ────────────────────────────────
  //
  // Google Places bazen restoran/kafe aramasında otel içindeki restoranları
  // veya tamamen alakasız iş yerlerini döndürüyor. Bu liste her aramada
  // post-fetch aşamasında uygulanır.
  // İSTİSNA: Kullanıcı açıkça 'lodging' type'ı aratıyorsa bu filtre bypass edilir.
  static const Set<String> _alwaysExcluded = {
    'lodging',          // otel, motel, pansiyon
    'hospital',         // hastane
    'doctor',           // doktor muayenehanesi
    'pharmacy',         // eczane
    'bank',             // banka
    'atm',              // ATM
    'insurance_agency', // sigorta
    'real_estate_agency',// emlak
    'lawyer',           // avukat
    'accounting',       // muhasebe
    'storage',          // depo
    'car_repair',       // oto servis
    'car_dealer',       // oto galeri
    'gas_station',      // benzin istasyonu
    'funeral_home',     // cenaze evi
    'embassy',          // büyükelçilik
    'local_government_office', // devlet dairesi
  };

  /// Bir mekan listesinden `_alwaysExcluded` type içerenleri temizler.
  /// [searchingForLodging] true ise otel filtresi atlanır.
  static List<PlaceResult> _filterExcluded(
    List<PlaceResult> places, {
    bool searchingForLodging = false,
  }) {
    return places.where((p) {
      for (final t in p.types) {
        if (t == 'lodging' && searchingForLodging) continue;
        if (_alwaysExcluded.contains(t)) return false;
      }
      return true;
    }).toList();
  }

  // ── Kişilik tipi → Places API type eşlemesi ───────────────────────────────
  //
  // Google Places'te yemek yerleri çok farklı type'lara dağılır:
  //   restaurant  → resmi oturmalı restoran
  //   food        → tüm yemek yerleri (kebapçı, dönerci, fast food dahil)
  //   meal_takeaway → paket servis / ayaküstü yemek
  //   meal_delivery → eve servis odaklı
  // Geniş kapsam için hepsini birlikte arıyoruz.

  static const Map<PersonalityType, List<String>> _personalityTypes = {
    PersonalityType.sosyalKelebek: ['bar', 'night_club', 'restaurant', 'food', 'meal_takeaway'],
    PersonalityType.sakinRuh:      ['cafe', 'park', 'library', 'bakery'],
    PersonalityType.maceraperest:  ['gym', 'park', 'bowling_alley', 'amusement_park', 'stadium'],
    PersonalityType.entelektuel:   ['museum', 'art_gallery', 'library', 'movie_theater', 'tourist_attraction'],
    PersonalityType.gurme:         ['restaurant', 'food', 'meal_takeaway', 'bakery', 'cafe'],
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

  // ── Aktivite metni → Places type listesi ─────────────────────────────────
  //
  // Tek type değil, o kategorideki TÜM Google Places type'larını listele.
  // "Restoran" seçilince kebapçı, dönerci, fast-food da dahil olsun.

  static const Map<String, List<String>> _activityToTypes = {
    // Yemek — en geniş kapsam
    'restoran': ['restaurant', 'food', 'meal_takeaway', 'meal_delivery'],
    'yemek':    ['restaurant', 'food', 'meal_takeaway', 'meal_delivery'],
    // Kafe
    'kafe':     ['cafe', 'bakery'],
    'kahve':    ['cafe', 'bakery'],
    // Bar / gece
    'bar':      ['bar', 'night_club'],
    // Kültür / müze
    'müze':     ['museum', 'art_gallery', 'tourist_attraction'],
    'kültür':   ['museum', 'art_gallery', 'tourist_attraction'],
    // Galeri
    'galeri':   ['art_gallery', 'museum'],
    // Park / doğa
    'park':     ['park', 'campground', 'natural_feature'],
    'doğa':     ['park', 'campground', 'natural_feature'],
    // Spor
    'spor':     ['gym', 'stadium', 'bowling_alley', 'amusement_park'],
    // Sinema / eğlence
    'sinema':   ['movie_theater'],
    'eğlence':  ['amusement_park', 'bowling_alley', 'movie_theater'],
    // Alışveriş
    'alışveriş': ['shopping_mall', 'department_store'],
    // Diğer
    'bowling':  ['bowling_alley'],
    'kitap':    ['library', 'book_store'],
    'spa':      ['spa', 'beauty_salon'],
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

    // Kullanıcı otel mi arıyor? (lodging filtresi bypass edilsin mi?)
    final searchingForLodging = types.contains('lodging');

    // ignore: avoid_print
    print('🔍 PlacesService types: $types  lodgingSearch=$searchingForLodging');

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

    // ── Otel + alakasız type'ları temizle ─────────────────────────────────
    // Restoran/kafe ararken içinde restoran olan oteller de geliyor.
    // Post-fetch filtresiyle bunları çıkarıyoruz.
    final filtered = _filterExcluded(
      results,
      searchingForLodging: searchingForLodging,
    );

    // ignore: avoid_print
    print('🔍 PlacesService after filter: ${filtered.length}/${results.length}');

    if (filtered.isEmpty) return [];

    // ── Kişilik + rating kombinasyon skoru ─────────────────────────────────
    final scored = filtered.map((place) {
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
    final finalList = scored.take(20).map((e) => e.$1).toList();
    // ignore: avoid_print
    print('🔍 PlacesService final: ${finalList.length} mekan');
    return finalList;
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
      for (final entry in _activityToTypes.entries) {
        if (lower.contains(entry.key)) {
          // Aktiviteye karşılık gelen type'lardan herhangi biri mekanla eşleşirse bonus
          if (entry.value.any((t) => place.types.contains(t))) {
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

  static Future<List<Place