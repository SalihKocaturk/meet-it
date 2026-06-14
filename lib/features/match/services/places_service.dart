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
    // Konaklama
    'lodging',

    // Sağlık / optik
    'hospital',
    'doctor',
    'dentist',
    'pharmacy',
    'physiotherapist',
    'veterinary_care',
    'optician',

    // Finans / hukuk / idare
    'bank',
    'atm',
    'finance',
    'insurance_agency',
    'real_estate_agency',
    'lawyer',
    'accounting',
    'local_government_office',
    'city_hall',
    'courthouse',
    'embassy',
    'post_office',
    'police',
    'fire_station',

    // Eğitim — anaokulu → üniversite
    'school',
    'primary_school',
    'secondary_school',
    'university',

    // Araç / ulaşım
    'car_repair',
    'car_dealer',
    'car_wash',
    'car_rental',
    'parking',
    'gas_station',
    'taxi_stand',
    'bus_station',
    'train_station',
    'transit_station',
    'subway_station',
    'airport',
    'light_rail_station',

    // Perakende / mağaza — giyim, optik, elektronik vs.
    'clothing_store',
    'shoe_store',
    'jewelry_store',
    'electronics_store',
    'hardware_store',
    'home_goods_store',
    'furniture_store',
    'pet_store',
    'florist',
    'bicycle_store',
    'convenience_store',
    'supermarket',
    'grocery_or_supermarket',
    'liquor_store',
    'store',         // Google'ın genel mağaza etiketi

    // Depo / endüstri / tamirat
    'storage',
    'moving_company',
    'electrician',
    'plumber',
    'painter',
    'locksmith',
    'roofing_contractor',
    'general_contractor',

    // Cenaze / dini hizmet
    'funeral_home',
    'cemetery',
    'place_of_worship',

    // Güzellik / çamaşır / temizlik
    'hair_care',
    'laundry',
    'dry_cleaning',

    // Diğer alakasız
    'rv_park',
  };

  // ── Aktivite → izin verilen mekan type'ları (whitelist) ──────────────────
  //
  // Kullanıcı aktivite seçtiğinde, çekilen sonuçlar bu listeden EN AZ BİRİNİ
  // taşımak ZORUNDA. Bu sayede Rams Park (stadium+food), optik mağazası
  // (store+health) gibi false-positive'lar filtrelenir.
  static const Map<String, Set<String>> _activityRequiredTypes = {
    'restoran': {'restaurant', 'meal_takeaway', 'meal_delivery'},
    'yemek':    {'restaurant', 'meal_takeaway', 'meal_delivery'},
    'kafe':     {'cafe', 'bakery'},
    'kahve':    {'cafe', 'bakery'},
    'bar':      {'bar', 'night_club'},
    'müze':     {'museum', 'art_gallery', 'tourist_attraction'},
    'kültür':   {'museum', 'art_gallery', 'tourist_attraction'},
    'galeri':   {'art_gallery', 'museum'},
    'park':     {'park', 'campground', 'natural_feature'},
    'doğa':     {'park', 'campground', 'natural_feature'},
    'spor':     {'gym', 'stadium', 'bowling_alley', 'amusement_park'},
    'sinema':   {'movie_theater'},
    'eğlence':  {'amusement_park', 'bowling_alley', 'movie_theater'},
    'alışveriş':{'shopping_mall', 'department_store'},
    'bowling':  {'bowling_alley'},
    'kitap':    {'library', 'book_store'},
    'spa':      {'spa', 'beauty_salon'},
  };

  /// Aktivite seçilmişse sonuçların o aktiviteye ait type'lardan en az birini
  /// taşımasını zorunlu kılar. False-positive sonuçları eler.
  static List<PlaceResult> _filterByRequiredTypes(
    List<PlaceResult> places,
    List<String> selectedActivities,
  ) {
    if (selectedActivities.isEmpty) return places;

    // Seçili aktivitelere karşılık gelen zorunlu type'ları birleştir
    final required = <String>{};
    for (final activity in selectedActivities) {
      final lower = activity.toLowerCase();
      for (final entry in _activityRequiredTypes.entries) {
        if (lower.contains(entry.key)) {
          required.addAll(entry.value);
          break;
        }
      }
    }
    if (required.isEmpty) return places;

    return places
        .where((p) => p.types.any((t) => required.contains(t)))
        .toList();
  }

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
    PersonalityType.sosyalKelebek: ['bar', 'night_club', 'restaurant', 'meal_takeaway'],
    PersonalityType.sakinRuh:      ['cafe', 'park', 'library', 'bakery'],
    PersonalityType.maceraperest:  ['gym', 'park', 'bowling_alley', 'amusement_park', 'stadium'],
    PersonalityType.entelektuel:   ['museum', 'art_gallery', 'library', 'movie_theater', 'tourist_attraction'],
    PersonalityType.gurme:         ['restaurant', 'meal_takeaway', 'bakery', 'cafe'],
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
    // Yemek — 'food' kasıtlı çıkarıldı: çok geniş, stadyum/mağaza gibi
    // alakasız yerleri de kapsıyor. restaurant + meal_takeaway + meal_delivery
    // kombinasyonu kebapçı, dönerci, fast-food'u zaten karşılıyor.
    'restoran': ['restaurant', 'meal_takeaway', 'meal_delivery'],
    'yemek':    ['restaurant', 'meal_takeaway', 'meal_delivery'],
    // Kafe — pastane (bakery) buraya ait, restoran aramasına girmesin
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

      for (final place in