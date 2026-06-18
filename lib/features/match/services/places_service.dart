import 'dart:convert';
import 'dart:math' as math;

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

      for (final place in batch) {
        if (!seen.contains(place.placeId)) {
          seen.add(place.placeId);
          results.add(place);
        }
      }
    }

    if (results.isEmpty) return [];

    // ── Adım 1: Kesinlikle istemediğimiz type'ları çıkar ─────────────────
    final excludeFiltered = _filterExcluded(
      results,
      searchingForLodging: searchingForLodging,
    );

    // ── Adım 2: Aktivite seçilmişse zorunlu type whitelist uygula ─────────
    // Örn: "Restoran" seçildiyse sonuç restaurant/meal_takeaway/meal_delivery
    // type'larından birini MUTLAKA taşımalı. Bu sayede stadyum, giyim
    // mağazası, optik gibi false-positive'lar elenir.
    final filtered = _filterByRequiredTypes(excludeFiltered, selectedActivities);

    // ignore: avoid_print
    print('🔍 PlacesService: raw=${results.length} '
        'excl=${excludeFiltered.length} req=${filtered.length}');

    if (filtered.isEmpty) return [];

    // ── Kişilik + rating kombinasyon skoru ─────────────────────────────────
    final scored = filtered.map((place) {
      final personalityScore = _personalityMatch(
        place, userProfile, friendProfile, selectedActivities,
      );
      final ratingScore = _qualityScore(place);
      // %60 kişilik uyumu + %40 kalite (rating + yorum sayısı)
      final total = personalityScore * 0.6 + ratingScore * 0.4;
      // Az miktarda rastgelelik ekle (±3 puan civarı) — kalitesi birbirine
      // çok yakın mekanlar her aramada birebir aynı sırada gelmesin.
      final jitter = (_rng.nextDouble() - 0.5) * 0.06;
      return (place, total + jitter);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    // Maksimum 20 mekan döner (sayfalama için)
    final finalList = scored.take(20).map((e) => e.$1).toList();
    // ignore: avoid_print
    print('🔍 PlacesService final: ${finalList.length} mekan');
    return finalList;
  }

  static final math.Random _rng = math.Random();

  // ── Kalite skoru: rating + yorum sayısı ───────────────────────────────────
  //
  // "Mümkünse çok yorum ve yüksek puan olan yeri seç, az yorumlu yüksek
  // puanlı bir yer çok yorumlu bir yerin önüne geçmemeli" isteğine göre:
  // Puan (rating) ve yorum sayısı (güven) eşit ağırlıkta ayrı ayrı
  // normalize edilip birleştirilir. Yorum sayısı logaritmik ölçekte
  // değerlendirilir (10 yorumdan 100'e çıkış, 1000'den 10000'e çıkıştan
  // daha büyük bir fark yaratır) ve 10.000 yorumda tavan yapar.
  //
  // Örnek: 40 yorum + 4.5 puan  → ratingNorm=0.90, reviewNorm≈0.40 → 0.65
  //        23.000 yorum + 4.2 puan → ratingNorm=0.84, reviewNorm=1.00 → 0.92
  // İkinci mekan haklı olarak öne çıkar.
  static double _qualityScore(PlaceResult place) {
    final v = (place.userRatingsTotal ?? 0).toDouble();
    final r = place.rating ?? 3.5;

    final ratingNorm = (r / 5.0).clamp(0.0, 1.0);

    const reviewCeiling = 10000.0;
    final reviewNorm = v <= 0
        ? 0.0
        : (math.log(v + 1) / math.log(reviewCeiling)).clamp(0.0, 1.0);

    return (ratingNorm * 0.5 + reviewNorm * 0.5).clamp(0.0, 1.0);
  }

  // ── Kişilik uyum skoru hesapla ────────────────────────────────────────────

  /// Bir mekanın iki kişilik profiline ne kadar uyduğunu 0.0–1.0 arası döner.
  ///
  /// NOT (eski hata): Önceki sürüm, eşleşen her (kişilik tipi, mekan type'ı)
  /// çiftini "matched" sayacına ekleyip toplamı bu sayaca bölüyordu. Bu,
  /// birden çok kişilik tipine hitap eden mekanları (örn. kafe — sakin ruh,
  /// gurme, entelektüel tiplerinin hepsinde geçiyor) cezalandırıyordu: çok
  /// eşleşme = düşük ortalama. Sonuçta, kullanıcının sadece zayıf bir ikincil
  /// eğilimiyle (örn. %15 maceraperest) eşleşen TEK bir mekan type'ı (gym),
  /// kafe gibi gerçekten baskın tipe uygun bir mekanla yapay olarak aynı
  /// seviyeye gelebiliyordu. Düzeltme: her profil için ağırlıklı toplam
  /// (skor × kişilik-tipi-ağırlığı) hesapla, sayıya bölme — ağırlıklar zaten
  /// 0-1 aralığında olduğu için sonuç doğal olarak sınırlı kalır ve baskın
  /// tipin gerçek üstünlüğü korunur.
  static double _personalityMatch(
    PlaceResult place,
    PersonalityProfile userProfile,
    PersonalityProfile friendProfile,
    List<String> selectedActivities,
  ) {
    double activityBonus = 0.0;

    // Seçili aktiviteler bonus — eğer mekan seçilen aktivite tipindeyse +1
    for (final activity in selectedActivities) {
      final lower = activity.toLowerCase();
      for (final entry in _activityToTypes.entries) {
        if (lower.contains(entry.key)) {
          // Aktiviteye karşılık gelen type'lardan herhangi biri mekanla eşleşirse bonus
          if (entry.value.any((t) => place.types.contains(t))) {
            activityBonus += 1.0;
          }
          break;
        }
      }
    }

    // Bir profil için ağırlıklı kişilik uyum skoru: her kişilik tipinin
    // ağırlığı × o tipin bu mekan type'larına verdiği toplam skor.
    double profileScore(PersonalityProfile profile) {
      double s = 0.0;
      for (final entry in profile.scores.entries) {
        final typeWeight = entry.value;
        if (typeWeight <= 0) continue;
        final placeScores = _personalityScores[entry.key] ?? {};
        for (final placeType in place.types) {
          final v = placeScores[placeType];
          if (v != null) s += v * typeWeight;
        }
      }
      return s;
    }

    final combined =
        (profileScore(userProfile) + profileScore(friendProfile)) / 2;

    if (combined <= 0 && activityBonus <= 0) {
      return 0.3; // eşleşme yoksa düşük ama sıfır değil
    }

    return (combined + activityBonus).clamp(0.0, 1.0);
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

      // ignore: avoid_print
      print('[PlacesService] type=$type status=$status');

      if (status == 'REQUEST_DENIED') {
        final msg = body['error_message'] ?? 'API key sorunu veya Maps/Places API etkin değil';
        // ignore: avoid_print
        print('[PlacesService] ❌ REQUEST_DENIED: $msg');
        return [];
      }
      if (status == 'OVER_QUERY_LIMIT') {
        // ignore: avoid_print
        print('[PlacesService] ❌ OVER_QUERY_LIMIT: Günlük kota dolmuş');
        return [];
      }
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        // ignore: avoid_print
        print('[PlacesService] ⚠️ status=$status body=${response.body}');
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
    // _activityToTypes bir 