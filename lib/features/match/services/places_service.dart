import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// Google Places Nearby Search API wrapper.
///
/// İki kişinin kişilik profiline ve seçili aktivitelere göre mekan arar.
/// Sonuçları kişilik uyumuna + rating'e göre ağırlıklandırıp, kalite
/// havuzu içinden AĞIRLIKLI RASTGELE seçim yapar. Bu sayede:
///   - Aynı kişi aynı aramayı 3 kez yapınca hep aynı ilk sonuçlar çıkmaz
///     (ama düşük kaliteli/garip yerler asla öne çıkmaz — havuz zaten
///     kalite + isim filtresinden geçmiş yerlerden oluşur).
///   - Sonuç sayısı sayfalama için 10 ile sınırlandırılır (5'lik
///     sayfalarla 2 sayfa).
///   - Aynı tür mekanlardan (pizza, burger, kebap vb.) birden fazlası
///     final listede yan yana/aynı anda çıkmaz — çeşitlilik korunur.
class PlacesService {
  const PlacesService._();

  /// Sayfalama için döndürülecek maksimum mekan sayısı.
  /// `venue_search_notifier.dart`'taki `_pageSize` (5) ile birlikte
  /// tam 2 sayfa oluşturur.
  static const int _maxResultCount = 10;

  /// Bir mekanın gösterilebilmesi için sahip olması gereken minimum
  /// yorum (review) sayısı. 0 veya 1 yorumlu yerler genelde yanlış
  /// kategorize edilmiş ya da hiç işlemeyen/kapanmış yerler oluyor —
  /// bu yüzden gösterilmiyor.
  static const int _minReviewCount = 5;

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
    // NOT: 'stadium' kasıtlı çıkarıldı — stadyum izleyici/etkinlik mekanıdır,
    // birlikte spor YAPILACAK bir yer değil. "Spor" aktivitesi seçildiğinde
    // futbol stadyumu önermek anlamsız (sadece statik veri görüntüleniyor).
    // NOT: 'amusement_park' de buradan çıkarıldı — aquapark/lunapark
    // egzersiz değil, dinlence/eğlence amaçlıdır. Google Places'te aquapark
    // için ayrı bir type olmadığından (legacy API'de en yakın karşılığı
    // 'amusement_park'), bu type sadece 'eğlence' kategorisinde tutuluyor.
    'spor':     {'gym', 'bowling_alley'},
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

  // ── Şüpheli / garip isim filtresi ─────────────────────────────────────────
  //
  // Google Places type'ı "restaurant" dese de, bazen isminden anlaşılan
  // tamamen alakasız bir iş yeri (eczane, market, oto tamirci, emlakçı vb.)
  // sonuç olarak dönebiliyor. Type filtresi bunu her zaman yakalayamıyor,
  // çünkü Google bazı yerlere birden fazla/yanlış type atayabiliyor.
  // Bu yüzden isimde geçen anahtar kelimelere göre ek bir güvenlik filtresi.
  static const List<String> _suspiciousNameKeywords = [
    'eczane', 'ecza ', 'market', 'süpermarket', 'şarküteri', 'bakkal',
    'oto ', 'otomotiv', 'tamir', 'yedek parça', 'lastikçi', 'lastik ',
    'emlak', 'inşaat', 'mobilya', 'nakliyat', 'taşımacılık',
    'avukat', 'hukuk bürosu', 'noter', 'muhasebe', 'mali müşavir',
    'doktor', 'klinik', 'hastane', 'diş hekimi', 'eczacı', 'veteriner',
    'banka', 'şube', 'sigorta', 'finans',
    'kuran kursu', 'dini ',
    'anaokulu', 'kreş', 'dershane', 'etüt merkezi',
    'kuaför', 'berber',
    'tekstil', 'toptan ', 'perakende',
  ];
  // NOT: 'güzellik merkezi' / 'spa' bilerek listede YOK — 'spa' aktivitesi
  // seçildiğinde beauty_salon type'ı kasıtlı olarak whitelist'te (bkz.
  // _activityRequiredTypes), bu yüzden isim filtresi gerçek spa sonuçlarını
  // elemesin diye buraya eklenmedi.

  static bool _hasSuspiciousName(String name) {
    final lower = name.toLowerCase().trim();
    // Çok kısa / boş isimler de "garip" sayılır (genelde veri kalitesi düşük).
    if (lower.length < 2) return true;
    for (final kw in _suspiciousNameKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// İsmi şüpheli/garip görünen mekanları eler.
  static List<PlaceResult> _filterSuspiciousNames(List<PlaceResult> places) {
    return places.where((p) => !_hasSuspiciousName(p.name)).toList();
  }

  /// Yorum sayısı `_minReviewCount`'tan az olan (veya yorumu hiç olmayan)
  /// mekanları eler. Az yorumlu yerler genelde güvenilir bir kalite
  /// sinyali vermiyor (yanlış kategorize edilmiş, terk edilmiş, vb. olabilir).
  static List<PlaceResult> _filterMinimumReviews(List<PlaceResult> places) {
    return places
        .where((p) => (p.userRatingsTotal ?? 0) >= _minReviewCount)
        .toList();
  }

  // ── İsim bazlı çeşitlilik grupları ────────────────────────────────────────
  //
  // "2 pizzacı veya 2 burgerci aynı anda çıkmasın" isteği için: final
  // listeye eklerken aynı gruptan zaten bir mekan varsa o mekanı atla
  // (havuzda yeterli çeşit yoksa son aşamada gerekirse tekrar eklenir).
  static const Map<String, List<String>> _nameDiversityGroups = {
    'pizza': ['pizza'],
    'burger': ['burger', 'hamburger'],
    'kebap': ['kebap', 'kebab'],
    'döner': ['döner', 'dürüm'],
    'sushi_japon': ['sushi', 'japon'],
    'tatlı': ['tatlı', 'baklava', 'pastane', 'pasta '],
    'kahve': ['kahve', 'coffee'],
    'çay': ['çay bahçesi', 'çaycı'],
    'balık': ['balık', 'deniz ürün'],
    'pide_lahmacun': ['pide', 'lahmacun'],
    'tavuk': ['tavuk', 'piliç'],
    'steak_et': ['steak', 'biftek', 'et lokanta', 'ocakbaşı'],
    'çin_uzakdoğu': ['çin ', 'noodle', 'wok'],
    'meksika': ['meksika', 'taco', 'burrito'],
  };

  /// Mekan isminden çeşitlilik grubunu çıkarır; eşleşme yoksa null
  /// (gruplanamayan mekanlar çeşitlilik kısıtına girmez).
  static String? _diversityGroupOf(String name) {
    final lower = name.toLowerCase();
    for (final entry in _nameDiversityGroups.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  // ── Ağırlıklı rastgele seçim (Efraimidis–Spirakis) ────────────────────────
  //
  // Basit "skora göre sırala + ilk N'i al" yöntemi, aynı kullanıcı/arkadaş
  // çifti her arama yaptığında BİREBİR AYNI ilk sonuçları üretir (skorlar
  // sabit olduğu için). Bunun yerine: her mekana ağırlığıyla orantılı
  // rastgele bir "key" üret, en yüksek key'e sahip N mekanı seç. Yüksek
  // skorlu mekanlar yine çok daha sık öne çıkar (rastgele değil, ağırlıklı),
  // ama %100 deterministik olmadığından arama tekrarında çeşitlilik sağlar.
  // Aynı zamanda çeşitlilik grubu kısıtını da burada uyguluyoruz.
  static List<PlaceResult> _weightedDiverseSample(
    List<(PlaceResult, double)> scoredPlaces,
    int count,
  ) {
    final withKeys = scoredPlaces.map((entry) {
      final weight = entry.$2.clamp(0.05, double.infinity);
      final u = _rng.nextDouble().clamp(0.0001, 0.9999);
      final key = math.pow(u, 1 / weight).toDouble();
      return (entry.$1, key);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2)); // büyük key = öncelikli

    final result = <PlaceResult>[];
    final usedGroups = <String>{};
    final skipped = <PlaceResult>[];

    for (final entry in withKeys) {
      if (result.length >= count) break;
      final place = entry.$1;
      final group = _diversityGroupOf(place.name);
      if (group != null && usedGroups.contains(group)) {
        skipped.add(place); // çeşitlilik için bu turda atla
        continue;
      }
      result.add(place);
      if (group != null) usedGroups.add(group);
    }

    // Çeşitlilik kısıtı yüzünden yeterli sonuç bulunamadıysa (havuz küçükse)
    // atlanan mekanlarla (en yüksek key sırasıyla) tamamla.
    if (result.length < count) {
      for (final place in skipped) {
        if (result.length >= count) break;
        result.add(place);
      }
    }

    return result;
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
    PersonalityType.maceraperest:  ['gym', 'park', 'bowling_alley', 'amusement_park'],
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
    // Spor — 'stadium' ve 'amusement_park' kasıtlı çıkarıldı, bkz.
    // _activityRequiredTypes notu (ikisi de egzersiz değil).
    'spor':     ['gym', 'bowling_alley'],
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
  /// Sayfalama için en fazla [_maxResultCount] (10) mekan döner.
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

    // ── Adım 3: Garip/şüpheli isimli mekanları ele ────────────────────────
    final nameFiltered = _filterSuspiciousNames(filtered);

    // ── Adım 4: Yorum sayısı çok az olan (güvenilmez) mekanları ele ───────
    final reviewFiltered = _filterMinimumReviews(nameFiltered);

    // ignore: avoid_print
    print('🔍 PlacesService: raw=${results.length} '
        'excl=${excludeFiltered.length} req=${filtered.length} '
        'name=${nameFiltered.length} review=${reviewFiltered.length}');

    if (reviewFiltered.isEmpty) return [];

    // ── Kişilik + rating kombinasyon skoru ─────────────────────────────────
    final scored = reviewFiltered.map((place) {
      final personalityScore = _personalityMatch(
        place, userProfile, friendProfile, selectedActivities,
      );
      final ratingScore = _qualityScore(place);
      // %60 kişilik uyumu + %40 kalite (rating + yorum sayısı)
      final total = personalityScore * 0.6 + ratingScore * 0.4;
      return (place, total);
    }).toList();

    // Ağırlıklı rastgele seçim + çeşitlilik kısıtı uygulayarak nihai
    // listeyi oluştur. Kalite havuzu (nameFiltered + skor) sabit kalsa da,
    // her aramada öne çıkan mekanlar biraz farklılaşır.
    final finalList = _weightedDiverseSample(scored, _maxResultCount);

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
    // _activityToTypes bir aktivite için birden fazla type döndürür:
    //   "restoran" → ['restaurant', 'food', 'meal_takeaway', 'meal_delivery']
    // Bu sayede kebapçı, dönerci vb. de kapsama girer.
    if (selectedActivities.isNotEmpty) {
      final types = <String>{};
      for (final activity in selectedActivities) {
        final lower = activity.toLowerCase();
        for (final entry in _activityToTypes.entries) {
          if (lower.contains(entry.key)) {
            types.addAll(entry.value); // tüm type'ları ekle
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

    // Secondary tipler — daha geniş havuz.
    //
    // NOT: `secondaryType` getter'ı %10 gibi düşük bir eşikte bile ikincil
    // tip döndürüyor (UI'da "ikincil eğilim" göstermek için makul bir eşik).
    // Ama burada, arama havuzuna YENİ bir mekan kategorisi eklemek için bu
    // çok düşük: "sakin ruh" kullanıcının %12 gibi zayıf bir "maceraperest"
    // eğilimi olması, sonuçlara spor salonu/stadyum sokulmasına yol açıyordu
    // (dominant tipin 4 type'ı + bu 1 ekstra type = take(5) ile tam sınırda
    // kalıyor ve dominant tipin kendi mekanlarıyla aynı kefeye giriyordu).
    // Bu yüzden burada daha sıkı, yerel bir eşik kullanıyoruz: ikincil eğilim
    // gerçekten belirgin değilse (≥ %25) arama havuzuna katılmasın.
    const secondaryPoolThreshold = 0.25;

    void addSecondaryPool(PersonalityProfile profile) {
      final ranked = profile.rankedTypes;
      if (ranked.length < 2) return;
      final second = ranked[1];
      if (second.value >= secondaryPoolThreshold) {
        types.addAll(_personalityTypes[second.key] ?? []);
      }
    }

    addSecondaryPool(userProfile);
    addSecondaryPool(friendProfile);

    return types.take(5).toList();
  }
}
