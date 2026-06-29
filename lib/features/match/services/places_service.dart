import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/services/places_api_version_service.dart';
import 'package:meetit/features/match/services/venue_photo_cache_service.dart';
import 'package:meetit/features/match/services/venue_search_cache_service.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// Google Places Nearby Search API wrapper.
///
/// İki kişinin kişilik profiline ve seçili aktivitelere göre mekan arar.
/// Sonuçları kişilik uyumuna + rating'e göre ağırlıklandırıp, kalite
/// havuzu içinden AĞIRLIKLI RASTGELE seçim yapar. Bu sayede:
///   - Aynı kişi aynı aramayı 3 kez yapınca hep aynı ilk sonuçlar çıkmaz
///     (ama düşük kaliteli/garip yerler asla öne çıkmaz — havuz zaten
///     kalite + isim filtresinden geçmiş yerlerden oluşur).
///   - Sonuç sayısı `AppConfig.maxVenueResults` (5) ile sınırlandırılır —
///     sayfalama yok, kullanıcı talebi üzerine tek seferde en fazla 5 mekan.
///   - Aynı tür mekanlardan (pizza, burger, kebap vb.) birden fazlası
///     final listede yan yana/aynı anda çıkmaz — çeşitlilik korunur.
class PlacesService {
  const PlacesService._();

  /// Döndürülecek maksimum mekan sayısı — `AppConfig.maxVenueResults`'a
  /// eşit tutuluyor (tek kaynak) — filtreleme/skorlama sonrası kullanıcıya
  /// gösterilecek NİHAİ mekan sayısı bu sabitle sınırlanıyor.
  ///
  /// 📍 API ÇAĞRI TASARRUFU (2026-06-28): Önceden 20'ye kadar çekilip
  /// sayfalama ile 4 sayfaya bölünüyordu ("10 bile çok fazla, 5 mekan
  /// göster" talebi üzerine sıkıştırıldı).
  static const int _maxResultCount = AppConfig.maxVenueResults;

  /// Google'a atılan TEK istekteki `maxResultCount` alanı — yani Google'dan
  /// istenen HAM (filtrelenmemiş) sonuç sayısı. Bu, [_maxResultCount]'tan
  /// (nihai gösterim sayısı, 5) BİLE BİLE AYRI ve daha YÜKSEK tutuluyor.
  ///
  /// 📍 NEDEN AYRI (2026-06-28): Artık tüm tip'ler (`includedTypes`) TEK bir
  /// istekte birleştiriliyor (bkz. `searchVenues()`), yani örn. kişilik
  /// modunda 6 farklı tipin sonuçları artık TEK bir `maxResultCount`
  /// havuzunu paylaşıyor — önceden her tip kendi 5'lik payını alıyordu.
  /// Eğer bu sayıyı 5'te bıraksaydık, 6 tipe bölüşülen sadece 5 ham sonuç
  /// sonradan uygulanan ağır filtreleme/skorlama zincirinden (yorum sayısı,
  /// kara liste, kişilik eşleşmesi vb.) geçtikten sonra muhtemelen BOŞ ya da
  /// çok seyrek bir liste üretirdi. Google'ın `searchNearby` (New) endpoint'i
  /// tek istekte en fazla 20 ham sonuç dönebiliyor — o tavanı kullanıyoruz,
  /// ekstra bir API ÇAĞRISI eklemeden (hâlâ tek çağrı), sadece o tek
  /// çağrının döndürdüğü ham sonuç sayısını artırarak.
  static const int _rawFetchCount = 20;

  /// Bir mekanın gösterilebilmesi için sahip olması gereken minimum
  /// yorum (review) sayısı. Az yorumlu yerler genelde yanlış
  /// kategorize edilmiş, hiç işlemeyen/kapanmış ya da güvenilir bir
  /// kalite sinyali vermeyen yerler oluyor — bu yüzden gösterilmiyor.
  static const int _minReviewCount = 20;

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
    // Çocuk parkları / oyun alanları — bir buluşma/randevu mekanı değil,
    // genelde küçük, oturacak/sosyalleşilecek bir alanı olmayan belediye
    // oyun parkları (örn. "İBB ... Çocuk Parkı"). "park" type'ı çıkmaması
    // için isim bazlı eleniyor; gerçek gezi/yürüyüş parkları (Emirgan
    // Korusu, Seka Park vb.) bu kelimeleri içermediğinden etkilenmiyor.
    'çocuk parkı', 'çocuk oyun', 'oyun parkı', 'oyun grubu',
    'çocuk oyun alanı', 'çocuk oyun grubu',
    // Mezarlık — `_alwaysExcluded` zaten 'cemetery' type'ını eliyor, ama
    // Google Places bazı tarihi/şehir mezarlıklarını 'park', 'tourist_
    // attraction' ya da 'natural_feature' gibi alakasız type'larla
    // etiketleyebiliyor (type filtresi bunları yakalayamıyor). Bu yüzden
    // isim bazlı ek bir güvenlik ağı da gerekiyor — bir buluşma mekanı
    // olarak hiçbir koşulda mezarlık önerilmemeli.
    'mezarlık', 'mezarlığı', 'şehitlik', 'şehitliği', 'kabristan',
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

  // ── Üniversite kütüphaneleri filtresi ─────────────────────────────────────
  //
  // Örnek: "Bahçeşehir Üniversitesi Kütüphanesi" sonuçlarda çıkıyordu. Bir
  // üniversitenin kütüphanesi, halk kütüphanesi gibi herkese açık bir mekan
  // DEĞİL — genelde sadece o üniversitenin öğrenci/personel kartı olanlar
  // girebiliyor. "library" type'ı Google Places'te hem halka açık halk
  // kütüphanelerini hem de üniversite kütüphanelerini aynı şekilde
  // etiketlediğinden, type filtresi bunları ayıramıyor. Bu yüzden isim bazlı
  // ek bir kontrol: ismi "üniversite(si)" + "kütüphane(si)" kombinasyonunu
  // (veya "üni kütüphanesi" gibi kısaltmasını) içeren bir mekan, type'ı
  // "library" olsa bile elenir — gerçek halk kütüphaneleri (örn. "Beşiktaş
  // Belediyesi Kütüphanesi", "Atatürk Kitaplığı") bu kelimeleri içermediği
  // için etkilenmez.
  static const List<String> _universityKeywords = [
    'üniversite', 'üniv ', 'üniv.', 'university',
  ];

  static bool _isUniversityLibrary(PlaceResult place) {
    if (!place.types.contains('library')) return false;
    final lower = place.name.toLowerCase();
    final mentionsUniversity = _universityKeywords.any(lower.contains);
    final mentionsLibrary =
        lower.contains('kütüphane') || lower.contains('library');
    return mentionsUniversity && mentionsLibrary;
  }

  static List<PlaceResult> _filterUniversityLibraries(
    List<PlaceResult> places,
  ) {
    return places.where((p) => !_isUniversityLibrary(p)).toList();
  }

  // ── Genel "giriş kısıtlı" mekan filtresi (isim bazlı) ─────────────────────
  //
  // Üniversite kütüphanesi sorununun genel hali: Google Places type sistemi
  // SADECE mekanın KATEGORİSİNİ bilir ("park", "restaurant", "gym"...), kime
  // AÇIK olduğunu bilmez. Bir mekanın type'ı "park" olsa da, ismi "... Sitesi
  // Yeşil Alanı" ise bu site sakinleri dışında kimsenin giremeyeceği özel bir
  // alandır — type filtresi bunu hiçbir zaman yakalayamaz, çünkü Google'a
  // göre ikisi de aynı kategoridedir. Bu yüzden isim bazlı, type'tan bağımsız
  // (her type'a uygulanan) bir kontrol katmanı: isimde aşağıdaki kalıplardan
  // biri geçiyorsa mekan, type'ı ne olursa olsun elenir.
  //
  // ÖNEMLİ TASARIM PRENSİBİ: isimden veya type'tan kesin bir "kısıtlı erişim"
  // sinyali çıkaramıyorsak hiçbir şey yapmıyoruz — yani şüphe durumunda
  // Google'ın verdiği type'a güvenip mekanı göstermeye devam ediyoruz. Bu
  // yüzden buradaki kelimeler kasıtlı olarak DAR ve net tutuldu (örn. sadece
  // "kulüp" değil, "üyelere özel" gibi gerçekten kısıtlı erişimi ifade eden
  // ifadeler) — aksi halde gerçekten herkese açık, halka açık mekanları da
  // yanlışlıkla eleme riski olurdu.
  static const List<String> _restrictedAccessNameKeywords = [
    // Öğrenci yurtları — sadece o yurtta kalan öğrenciler girebilir.
    // " yurdu " kelime sınırlarıyla aranır (bkz. _hasRestrictedAccessName'in
    // isme boşluk eklemesi) — bu sayede "Anayurt Restaurant" gibi içinde
    // "yurt" geçen ama alakasız isimler yanlışlıkla elenmez.
    ' yurdu ', 'lojman',
    // Askeri / polis sosyal tesisleri — sadece personel + yakınları.
    'orduevi', 'ordu evi', 'polisevi', 'polis evi', 'kışla',
    'askeri tesis', 'garnizon',
    // Açıkça "üyelere özel" / "özel üyelik" belirtilen sosyal tesisler.
    'üyelere özel', 'özel üyelik', 'sadece üyeler',
    // Fabrika/şirket personeline özel sosyal tesisler.
    'personel lokali', 'personele özel', 'fabrika sosyal tesisi',
    // Üniversiteye özel (kütüphane dışındaki) tesisler — kantin/yemekhane/
    // sosyal tesis. Halka açık restoranlar bu kombinasyonu içermez.
    'üniversite kantini', 'üniversite yemekhanesi',
    'fakülte kantini', 'kampüs içi',
    // Site / apartman sakinlerine özel ortak alanlar.
    'site sakinlerine özel', 'sitesi yeşil alanı', 'sitesi sosyal tesisi',
  ];

  static bool _hasRestrictedAccessName(String name) {
    // Baş/son boşluk eklenerek " yurdu " gibi kelime-sınırlı kalıpların
    // ismin başında/sonunda olsa bile eşleşmesi sağlanıyor.
    final lower = ' ${name.toLowerCase()} ';
    return _restrictedAccessNameKeywords.any(lower.contains);
  }

  static List<PlaceResult> _filterRestrictedAccessVenues(
    List<PlaceResult> places,
  ) {
    return places.where((p) => !_hasRestrictedAccessName(p.name)).toList();
  }

  // ── Gece hayatı / kişilik uyumsuzluğu filtresi ────────────────────────────
  //
  // Kök sebep: Google Places, "lounge" gibi hibrit mekanları genelde aynı
  // anda birden fazla type ile etiketler (örn. ['bar','cafe','restaurant']).
  // _personalityMatch eşleşen HER type için ayrı ayrı puan topladığından,
  // sosyalKelebek/gurme eğilimi olmayan bir kullanıcı çifti (örn.
  // maceraperest + entelektüel + sakin ruh) için bile 'bar'/'night_club'
  // etiketli bir mekan, yüksek rating/yorum sayısıyla birleşince toplam
  // skorda öne çıkabiliyordu — _personalityScores tablosundaki düzeltme
  // (maceraperest'ten bar/night_club ağırlığının kaldırılması) tek başına
  // yeterli değil, çünkü Google bazen bir mekanı GERÇEKTEN sadece
  // 'bar'/'night_club' olarak etiketleyip kalan type listesi boş bırakabilir.
  // Bu yüzden ikinci, bağımsız bir güvenlik ağı: ikisinden BİRİ bile gece
  // hayatına anlamlı bir eğilim (sosyalKelebek veya gurme oranı ≥ %25)
  // taşımıyorsa, ne kişilik skoruna ne de Google'ın type etiketine güvenip
  // doğrudan bar/night_club karakterli (kafe/restoran gibi sakin bir type'ı
  // OLMAYAN) ve/veya ismi gece hayatı kelimeleri içeren mekanları eler.
  static const double _nightlifeIntentThreshold = 0.25;

  static const Set<String> _nightlifeOnlyTypes = {'bar', 'night_club'};

  // Bir mekan bar/night_club olsa da BU type'lardan birini de taşıyorsa
  // (örn. gerçekten bir "cafe-bar" hibrit), tamamen elenmez — sadece skor
  // hâlâ kişilik tablosundan geliyor, burada yalnızca SAF gece hayatı
  // mekanları (başka hiçbir sakin/nötr type'ı olmayanlar) hedefleniyor.
  static const Set<String> _calmCoTypes = {
    'cafe', 'restaurant', 'bakery', 'library', 'museum', 'art_gallery',
    'park', 'movie_theater', 'tourist_attraction', 'bowling_alley',
    'amusement_park', 'gym',
  };

  static const List<String> _nightlifeNameKeywords = [
    'lounge', 'pub', 'meyhane', 'gece kulübü', 'night club', 'disko',
    ' club', 'kulüp',
  ];

  static List<PlaceResult> _filterNightlifeMismatch(
    List<PlaceResult> places,
    PersonalityProfile userProfile,
    PersonalityProfile friendProfile,
  ) {
    double nightlifeRatio(PersonalityProfile profile) {
      final total = profile.scores.values.fold<double>(0, (a, b) => a + b);
      if (total <= 0) return 0;
      final intent = (profile.scores[PersonalityType.sosyalKelebek] ?? 0) +
          (profile.scores[PersonalityType.gurme] ?? 0);
      return intent / total;
    }

    // İkisinden biri bile gece hayatına gerçekten yatkınsa (sosyalKelebek
    // veya gurme baskınsa) filtre devre dışı — o zaman bar/lounge önerisi
    // meşru bir kişilik eşleşmesi, eleme yapılmamalı.
    if (nightlifeRatio(userProfile) >= _nightlifeIntentThreshold ||
        nightlifeRatio(friendProfile) >= _nightlifeIntentThreshold) {
      return places;
    }

    return places.where((p) {
      final isNightlifeOnlyType = p.types.any(_nightlifeOnlyTypes.contains) &&
          !p.types.any(_calmCoTypes.contains);
      final lowerName = p.name.toLowerCase();
      final hasNightlifeName =
          _nightlifeNameKeywords.any((kw) => lowerName.contains(kw));
      return !(isNightlifeOnlyType || hasNightlifeName);
    }).toList();
  }

  /// Yorum sayısı `_minReviewCount`'tan az olan mekanları eler. Az yorumlu
  /// yerler genelde güvenilir bir kalite sinyali vermiyor (yanlış
  /// kategorize edilmiş, terk edilmiş, vb. olabilir).
  ///
  /// NOT (Foursquare geçişi): Google her zaman bir `user_ratings_total`
  /// değeri dönerdi (0 dahil), bu yüzden eskiden `?? 0` ile eksik veri de
  /// "az yorumlu" sayılıp elenebiliyordu. Foursquare'in ücretsiz katmanı
  /// `stats.total_ratings` alanını HER ZAMAN doldurmuyor — yani burada
  /// `null` "yorumu az" anlamına gelmiyor, "bu bilgi bu API yanıtında
  /// mevcut değildi" anlamına geliyor. Bu yüzden `null` durumunda mekan
  /// ELENMİYOR (rating/isim/type filtreleri zaten kaliteyi koruyor);
  /// sadece SAYI bilinip de `_minReviewCount`'un altındaysa elenir.
  static List<PlaceResult> _filterMinimumReviews(List<PlaceResult> places) {
    return places
        .where(
          (p) => p.userRatingsTotal == null ||
              p.userRatingsTotal! >= _minReviewCount,
        )
        .toList();
  }

  /// Verilirse, puanı [minRating]'ten az olan mekanları eler. Orta nokta
  /// aramasında dar çapta sadece kaliteli yerleri göstermek için kullanılır.
  static List<PlaceResult> _filterMinimumRating(
    List<PlaceResult> places,
    double? minRating,
  ) {
    if (minRating == null) return places;
    return places.where((p) => (p.rating ?? 0) >= minRating).toList();
  }

  // ── Spor salonu kısıtı: sadece "spor" aktivitesi seçiliyse göster ────────
  //
  // İstek: "spesifik olarak spor seçilmediği sürece gym çıkmaması daha iyi
  // olur". `_personalityTypes`'tan gym zaten çıkarıldı (MOD 2 / kişilik-
  // sadece tarama bu type'ı hiç Google'a sormuyor), ama MOD 1'de ("spor"
  // aktivitesi seçildiğinde) gym hâlâ aranıyor ve dönebiliyor — bu doğru.
  // Burada ek bir güvenlik ağı var: her ihtimale karşı (örn. Google bir
  // mekanı birden fazla type ile etiketleyip başka bir aramadan sızdırırsa)
  // 'spor' aktivitesi seçili DEĞİLSE gym type'lı sonuçlar tamamen elenir.
  static List<PlaceResult> _filterGymRequiresActivity(
    List<PlaceResult> places,
    List<String> selectedActivities,
  ) {
    final sportSelected =
        selectedActivities.any((a) => a.toLowerCase().contains('spor'));
    if (sportSelected) return places;
    return places.where((p) => !p.types.contains('gym')).toList();
  }

  // ── Gym marka bonusu: tanınmış bir zincir (Mac Fit) öne çıksın ────────────
  //
  // İstek: "gymlerde de bir tane mac fit gösterebilirsin" — spor aktivitesi
  // seçildiğinde rastgele/az tanınan bir spor salonu yerine, kullanıcının
  // bilip güvendiği büyük bir zincir öncelikli görünsün.
  static double _gymBrandBonus(PlaceResult place) {
    if (!place.types.contains('gym')) return 0.0;
    final lower = place.name.toLowerCase();
    if (lower.contains('mac fit') || lower.contains('macfit')) return 0.3;
    return 0.0;
  }

  // ── İstanbul'da yaygın bilinen / çok ziyaret edilen mekanlar ──────────────
  //
  // İstek: "yıldız parkı, maçka demokrasi parkı, emirgan korusu gibi yerleri
  // sakin ruh/maceraperest karşısına; bebek sahili/beşiktaş sahili sakin
  // ruh/sosyal kelebek karşısına; deniz müzesi/dolmabahçe sarayı/sultanahmet
  // camii entelektüel karşısına daha sık çıksın" + genel olarak "İstanbul'da
  // çok bilinen/gidilen mekanların çıkma ihtimalini artır".
  //
  // Bu harita, mekan ADINDA geçen anahtar kelimeye göre hangi kişilik
  // tiplerine ekstra bonus verileceğini tanımlar. Puanlama zaten kişilik +
  // kalite skoruna dayandığı için bu sadece KÜÇÜK bir ek ağırlık — tamamen
  // alakasız bir profile sahip kullanıcılara bu mekanlar yine de zorla
  // gösterilmez, sadece eşit/yakın skorlu adaylar arasında öne geçer.
  static const Map<String, Set<PersonalityType>> _landmarkPersonalityAffinity = {
    // Parklar / doğa — sakin ruh + maceraperest (yürüyüş/doğa = hafif aktif)
    'yıldız parkı': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'maçka demokrasi parkı': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'emirgan korusu': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'gülhane parkı': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'göztepe 60. yıl parkı': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'fethi paşa korusu': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'belgrad ormanı': {PersonalityType.sakinRuh, PersonalityType.maceraperest},
    'çamlıca': {PersonalityType.sakinRuh, PersonalityType.maceraperest},

    // Sahiller — sakin ruh + sosyal kelebek
    'bebek sahili': {PersonalityType.sakinRuh, PersonalityType.sosyalKelebek},
    'beşiktaş sahili': {PersonalityType.sakinRuh, PersonalityType.sosyalKelebek},
    'moda sahili': {PersonalityType.sakinRuh, PersonalityType.sosyalKelebek},
    'kuruçeşme': {PersonalityType.sakinRuh, PersonalityType.sosyalKelebek},
    'ortaköy': {PersonalityType.sakinRuh, PersonalityType.sosyalKelebek},

    // Müze / saray / tarihi-dini yapılar — entelektüel
    'deniz müzesi': {PersonalityType.entelektuel},
    'dolmabahçe sarayı': {PersonalityType.entelektuel},
    'sultanahmet camii': {PersonalityType.entelektuel},
    'topkapı sarayı': {PersonalityType.entelektuel},
    'ayasofya': {PersonalityType.entelektuel},
    'rahmi koç müzesi': {PersonalityType.entelektuel},
    'pera müzesi': {PersonalityType.entelektuel},
    'istanbul modern': {PersonalityType.entelektuel},
    'yerebatan sarnıcı': {PersonalityType.entelektuel},
    'süleymaniye camii': {PersonalityType.entelektuel},
    'çamlıca camii': {PersonalityType.entelektuel},
    'küçüksu kasrı': {PersonalityType.entelektuel},
    'beylerbeyi sarayı': {PersonalityType.entelektuel},

    // Genel olarak çok bilinen/turistik — herkese hafif bonus (entelektuel +
    // sosyal kelebek ağırlıklı, çünkü hem gezilecek hem sosyalleşilecek yer)
    'galata kulesi': {PersonalityType.entelektuel, PersonalityType.sosyalKelebek},
    'kız kulesi': {PersonalityType.sosyalKelebek, PersonalityType.sakinRuh},
    'istiklal caddesi': {PersonalityType.sosyalKelebek},
    'bağdat caddesi': {PersonalityType.sosyalKelebek, PersonalityType.gurme},
  };

  /// Mekan adı [_landmarkPersonalityAffinity]'deki bir anahtar kelimeyi
  /// içeriyorsa ve eşleşen kişilik tipi kullanıcı/arkadaş profilinde
  /// (her iki tarafın ortalaması olarak) belirgin bir ağırlığa sahipse küçük
  /// bir bonus döner. Hem genel "bilinen mekan" katkısı (sabit, küçük) hem
  /// de kişilik-spesifik katkı (profil ağırlığıyla orantılı) içerir.
  static double _landmarkBonus(
    PlaceResult place,
    PersonalityProfile userProfile,
    PersonalityProfile friendProfile,
  ) {
    final lowerName = place.name.toLowerCase();
    for (final entry in _landmarkPersonalityAffinity.entries) {
      if (!lowerName.contains(entry.key)) continue;

      // Genel "iyi bilinen mekan" katkısı — kişilik eşleşmesi zayıf olsa
      // bile bu mekanların gösterilme ihtimalini biraz artırır.
      double bonus = 0.1;

      for (final type in entry.value) {
        final userWeight = userProfile.scores[type] ?? 0;
        final friendWeight = friendProfile.scores[type] ?? 0;
        bonus += ((userWeight + friendWeight) / 2) * 0.3;
      }
      return bonus;
    }
    return 0.0;
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

  // NOT: 'gym' kasıtlı olarak maceraperest listesinden ÇIKARILDI. Kişilik-
  // sadece (aktivite seçilmemiş) tarama modunda (MOD 2, bkz. `_resolveTypes`)
  // bu liste doğrudan Google Places'e atılan type listesine dönüştüğü için
  // gym burada kalırsa, "spor" aktivitesi hiç seçilmemiş olsa bile sonuçlarda
  // spor salonu çıkabiliyordu. Artık gym SADECE kullanıcı açıkça "spor"
  // aktivitesini seçtiğinde aranıyor (bkz. `_activityToTypes['spor']`).
  static const Map<PersonalityType, List<String>> _personalityTypes = {
    PersonalityType.sosyalKelebek: ['bar', 'night_club', 'restaurant', 'meal_takeaway'],
    PersonalityType.sakinRuh:      ['cafe', 'park', 'library', 'bakery'],
    PersonalityType.maceraperest:  ['park', 'bowling_alley', 'amusement_park'],
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
      // NOT (bug fix): 'night_club':0.5 ve 'bar':0.4 buradan kasıtlı
      // olarak çıkarıldı. "Maceraperest" tipi fiziksel/aktif deneyimi
      // ifade ediyor (spor, bowling, lunapark) — gece hayatı/bar bununla
      // anlamsal olarak ilgisiz. Bu iki ağırlık burada dururken, maceraperest
      // + entelektüel + sakin ruh gibi sosyalKelebek/gurme'siz bir profil
      // kombinasyonunda bile bar/night_club tagli ("lounge" gibi) mekanlar
      // _personalityMatch'te küçük ama sıfırdan farklı bir puan kazanıp,
      // yüksek rating/yorum sayısıyla birleşince kaliteli ama tamamen
      // alakasız bir öneri olarak öne çıkabiliyordu. Gece hayatı sadece
      // sosyalKelebek (ve hafifçe gurme) tiplerine ait olmalı.
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
  /// En fazla [_maxResultCount] (`AppConfig.maxVenueResults`) mekan döner —
  /// sayfalama yok, tek seferde nihai liste budanır.
  static Future<List<PlaceResult>> searchVenues({
    required double lat,
    required double lng,
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
    int? priceLevel,
    int? radius,
    double? minRating,
    Set<String> excludePlaceIds = const {},
  }) async {
    final typeGroups = _resolveTypeGroups(
      userProfile: userProfile,
      friendProfile: friendProfile,
      selectedActivities: selectedActivities,
    );

    // Kullanıcı otel mi arıyor? (lodging filtresi bypass edilsin mi?)
    final allTypes = typeGroups.expand((g) => g).toSet();
    final searchingForLodging = allTypes.contains('lodging');

    final searchRadius = radius ?? AppConfig.defaultSearchRadius;

    // ignore: avoid_print
    print('🔍 PlacesService typeGroups: $typeGroups '
        'lodgingSearch=$searchingForLodging '
        'radius=$searchRadius minRating=$minRating');

    // 📍 API ÇAĞRI TASARRUFU (2026-06-28, güncelleme 2026-06-29): Her type
    // grubu için AYRI bir `searchNearby` isteği atılıyor (tek aktivite
    // seçiliyse bu hâlâ TEK çağrı — eskisiyle aynı). Google'ın
    // `includedTypes` alanı tek istekte 50'ye kadar type kabul etse de,
    // dönen ham sonuç sayısı istek başına en fazla 20 (`_rawFetchCount`) —
    // birden fazla aktivitenin type'ları AYNI isteğe gömülürse bu 20'lik
    // bütçe hepsi arasında relevansa göre paylaşılıyor ve yoğun bir
    // kategori (örn. restoran) diğerini (örn. kafe) tamamen ekarte
    // edebiliyordu — "kafe + restoran seçilince bazı bölgelerde mekan
    // çıkmıyor" hatasının kök sebebi buydu.
    //
    // 💸 MALİYET DÜŞÜRME: Aktivite başına ekstra bir HTTP çağrısı oluşsa da
    // (örn. 2 aktivite → 2 çağrı), her grup AYRICA kalıcı/TTL'siz önbelleğe
    // (VenueSearchCacheService) giriyor — yani bölge+aktivite kombinasyonu
    // başına Google'a ÖMÜR BOYU en fazla 1 kez gidiliyor, sonraki aynı
    // kombinasyonlu aramalar (tek başına ya da başka bir aktiviteyle
    // birlikte) hep önbellekten karşılanıyor.
    final rawResults = <PlaceResult>[];
    for (final group in typeGroups) {
      if (group.isEmpty) continue;
      final groupResults = await VenueSearchCacheService.getCached(
            lat: lat,
            lng: lng,
            types: group,
            radius: searchRadius,
          ) ??
          await _fetchAndCacheNearby(
            lat: lat,
            lng: lng,
            types: group,
            priceLevel: priceLevel,
            radius: searchRadius,
          );
      rawResults.addAll(groupResults);
    }

    final seen = <String>{};
    final results = <PlaceResult>[];
    for (final place in rawResults) {
      if (!seen.contains(place.placeId)) {
        seen.add(place.placeId);
        results.add(place);
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

    // ── Adım 3.2: Üniversite kütüphanelerini ele ──────────────────────────
    // Örn. "Bahçeşehir Üniversitesi Kütüphanesi" — bu mekanlara sadece o
    // üniversitenin öğrenci/personeli girebiliyor, halka açık bir buluşma
    // mekanı değil. Gerçek halk kütüphaneleri etkilenmez (bkz. yorum).
    final libraryFiltered = _filterUniversityLibraries(nameFiltered);

    // ── Adım 3.3: Genel giriş-kısıtlı mekan filtresi ────────────────────────
    // Üniversite kütüphanesi filtresinin genel hali — yurt, orduevi/polisevi,
    // "üyelere özel" tesisler gibi type'tan bağımsız, isimden anlaşılan
    // kısıtlı-erişim sinyalleri (bkz. yorum bloğu yukarıda).
    final restrictedFiltered = _filterRestrictedAccessVenues(libraryFiltered);

    // ── Adım 3.5: Gece hayatı / kişilik uyumsuzluğu filtresi ───────────────
    // Hiçbir taraf sosyalKelebek/gurme eğilimi taşımıyorsa (örn. maceraperest
    // + entelektüel + sakin ruh kombinasyonu), saf bar/night_club karakterli
    // veya ismi "lounge"/"pub" gibi gece hayatı kelimeleri içeren mekanları ele.
    final nightlifeFiltered =
        _filterNightlifeMismatch(restrictedFiltered, userProfile, friendProfile);

    // ── Adım 4: Yorum sayısı çok az olan (güvenilmez) mekanları ele ───────
    final reviewFiltered = _filterMinimumReviews(nightlifeFiltered);

    // ── Adım 5: (varsa) minimum puan şartı — orta nokta dar çap aramasında
    // sadece kaliteli (4.0+) yerleri göster.
    final ratingFiltered = _filterMinimumRating(reviewFiltered, minRating);

    // ── Adım 5.5: "spor" aktivitesi seçilmediyse gym sonuçlarını ele ───────
    final gymFiltered = _filterGymRequiresActivity(ratingFiltered, selectedActivities);

    // ignore: avoid_print
    print('🔍 PlacesService: raw=${results.length} '
        'excl=${excludeFiltered.length} req=${filtered.length} '
        'name=${nameFiltered.length} uniLib=${libraryFiltered.length} '
        'restricted=${restrictedFiltered.length} '
        'nightlife=${nightlifeFiltered.length} '
        'review=${reviewFiltered.length} rating=${ratingFiltered.length} '
        'gym=${gymFiltered.length}');

    if (gymFiltered.isEmpty) return [];

    // ── Adım 6: Az önce (aynı kişiyle) gösterilen mekanları kısa süreli
    // hariç tut ─────────────────────────────────────────────────────────────
    //
    // Sebep: aynı çift peş peşe arama yaptığında, ağırlıklı rastgele seçim
    // havuzu farklılaştırsa da, orta-nokta modunda sonuçlar mesafeye göre
    // yeniden sıralandığı için (bkz. venue_search_notifier.dart) en yakın
    // mekan HER ZAMAN 1. sırada çıkıyordu — rastgelelik mesafe sıralamasıyla
    // eziliyordu. Çözüm: çağıran taraf (VenueSearchNotifier) az önce
    // gösterilen mekan ID'lerini kısa süreli (bellekte, kalıcı olmayan)
    // tutuyor ve burada havuzdan çıkarmamızı istiyor. Havuzda yeterli
    // alternatif yoksa (örn. çok dar bir bölgede arama), sonuç sayısı
    // düşmesin diye hariç tutma uygulanmıyor.
    var pool = gymFiltered;
    if (excludePlaceIds.isNotEmpty) {
      final withoutRecent =
          gymFiltered.where((p) => !excludePlaceIds.contains(p.placeId)).toList();
      if (withoutRecent.length >= _maxResultCount) {
        pool = withoutRecent;
      }
    }

    // ── Kişilik + rating kombinasyon skoru ─────────────────────────────────
    // + İstanbul landmark bonusu (bilinen/turistik mekanlar daha sık çıksın)
    // + gym marka bonusu (Mac Fit gibi tanınmış bir zincir öne çıksın).
    final scored = pool.map((place) {
      final personalityScore = _personalityMatch(
        place, userProfile, friendProfile, selectedActivities,
      );
      final ratingScore = _qualityScore(place);
      // %60 kişilik uyumu + %40 kalite (rating + yorum sayısı)
      final total = personalityScore * 0.6 +
          ratingScore * 0.4 +
          _landmarkBonus(place, userProfile, friendProfile) +
          _gymBrandBonus(place);
      return (place, total);
    }).toList();

    // Ağırlıklı rastgele seçim + çeşitlilik kısıtı uygulayarak nihai
    // listeyi oluştur. Kalite havuzu (nameFiltered + skor) sabit kalsa da,
    // her aramada öne çıkan mekanlar biraz farklılaşır.
    final finalList = _weightedDiverseSample(scored, _maxResultCount);

    // 💸 MALİYET DÜŞÜRME (2026-06-28): Kart önizlemesi (İLK foto) VE bu
    // mekan ileride "Kaydet"/"Tarif Al" ile kalıcı listelere eklenirse
    // (bkz. saved_venues_provider.dart) galeri olarak kullanılabilecek en
    // fazla 3 fotoğrafı (bkz. _maxGalleryPhotos), Google'dan değil
    // paylaşımlı global önbellekten (VenuePhotoCacheService) çözümle — aynı
    // mekanı gören FARKLI kullanıcılar için Google'a tekrar tekrar ödeme
    // yapılmasın. Sadece nihai ≤5 sonuç için yapılıyor (havuzun tamamı için
    // DEĞİL). Böylece bu mekan daha sonra kaydedilir/tarif alınırsa kalıcı
    // kayda ZATEN çözümlenmiş URL'ler yazılır — o kullanıcı profilini her
    // açtığında Google'a tekrar gidilmez.
    // 📍 KOTA HATASI / ARAMA SONUCU KORUMA (2026-06-29): Kullanıcı talebi —
    // Photo Media API'sine günlük manuel bir kota (300/gün) koyulduğunda,
    // bu kota aşılsa bile mekan arama sonuçları (zaten bulunmuş/filtrelenmiş
    // ${_maxResultCount} mekan) HİÇBİR KOŞULDA kaybolmamalı — sadece o
    // mekanların fotoğrafı gösterilmesin (cache'de varsa cache'den
    // gösterilsin). Önceden bu blok tek bir mekanın foto çözümlemesi
    // başarısız/exception fırlatırsa TÜM `Future.wait`'i (ve dolayısıyla
    // searchVenues()'in tamamını) patlatabiliyordu — yani arama sonucu
    // komple kayboluyordu. Artık HER mekan kendi try-catch'i içinde işleniyor:
    // bir mekanın fotoları çözümlenemezse o mekan SADECE fotosuz (boş
    // photoReferences) olarak listede kalır, diğer mekanlar etkilenmez.
    final cachedList = await Future.wait(finalList.map((place) async {
      final namesToCache =
          place.photoReferences.isNotEmpty
              ? place.photoReferences.take(_maxGalleryPhotos).toList()
              : (place.photoReference != null ? [place.photoReference!] : <String>[]);
      if (namesToCache.isEmpty) return place;
      try {
        final cachedUrls = await VenuePhotoCacheService.resolvePhotoUrls(
          placeId: place.placeId,
          photoNames: namesToCache,
        );
        // Kota hatası yüzünden TÜM fotoğraflar elenmiş olabilir (bkz.
        // VenuePhotoCacheService.resolvePhotoUrl — kota hatasında '' döner,
        // resolvePhotoUrls bunları filtreler). Bu durumda mekanı fotosuz
        // bırak (UI zaten "fotoğraf yok" placeholder'ını gösteriyor),
        // ASLA `.first` ile boş listeye erişip exception fırlatma.
        if (cachedUrls.isEmpty) {
          // NOT: `copyWith` standart `?? this.field` deseni kullanıyor —
          // yani `null` geçmek eski (kotaya tabi, henüz çözümlenmemiş ham
          // Google foto adı içeren) değeri TEMİZLEMEZ. Bu yüzden burada
          // BOŞ STRING ('') geçiyoruz — `'' ?? eski` ifadesinde '' geçerli
          // bir değer olduğundan eski değerin üzerine yazılır ve gerçekten
          // temizlenir (UI artık "fotoğraf yok" durumuna düşer).
          return place.copyWith(photoReference: '', photoReferences: []);
        }
        return place.copyWith(
          photoReference: cachedUrls.first,
          photoReferences: cachedUrls,
        );
      } catch (e) {
        // ignore: avoid_print
        print(
          '[PlacesService] ⚠️ ${place.name} için foto çözümleme hatası '
          '(kota/ağ) — mekan fotosuz gösterilecek: $e',
        );
        return place.copyWith(photoReference: '', photoReferences: []);
      }
    }));

    // ignore: avoid_print
    print('🔍 PlacesService final: ${cachedList.length} mekan');
    return cachedList;
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

  // ── Google Places API (New) — Nearby Search HTTP ─────────────────────────
  //
  // NOT (Foursquare'den geri dönüş, 2026-06-27): Foursquare'in `rating`/
  // `hours`/`photos`/`stats` alanları "Premium" olup hiç ücretsiz kotası
  // olmadığından (ilk çağrıdan itibaren ücretli) geri Google'a dönüldü —
  // ama eski Legacy GET endpoint'i değil, yeni POST tabanlı `searchNearby`
  // (New API) kullanılıyor (bkz. app_config.dart'taki not). `includedTypes`
  // parametresi doğrudan bizim `type` değerlerimizi kabul ediyor — Google'ın
  // New API Place Type taksonomisi (Table A) Legacy ile AYNI string'leri
  // kullanıyor (örn. 'restaurant', 'cafe', 'museum'), bu yüzden Foursquare
  // döneminde gerekli olan kategori-adı→içsel-tip çevirme katmanı artık
  // tamamen GEREKSİZ — `types` API'den geldiği gibi kullanılabiliyor.
  static const String _searchFieldMask =
      'places.id,places.displayName,places.formattedAddress,'
      'places.location,places.types,places.rating,places.userRatingCount,'
      'places.priceLevel,places.regularOpeningHours.openNow,places.photos';

  /// 💸 MALİYET DÜŞÜRME (2026-06-28): `_fetchNearbyNew`/`_fetchNearbyLegacy`
  /// (aktif API'ye göre) ile Google'dan TAZE ham
  /// sonuç havuzunu çeker, ardından bu havuzu `VenueSearchCacheService`
  /// üzerinden 6 saatliğine önbelleğe yazar. Çağıran taraf (searchVenues)
  /// önce cache'e bakıp burayı SADECE cache miss durumunda çağırıyor —
  /// yani bu fonksiyon çalıştığında kesinlikle Google'a 1 istek gidecek,
  /// ama bir DAHAKİ aynı konum+tip aramasında (TTL içinde) hiç gidilmeyecek.
  static Future<List<PlaceResult>> _fetchAndCacheNearby({
    required double lat,
    required double lng,
    required List<String> types,
    int? priceLevel,
    required int radius,
  }) async {
    // 📍 DUAL API SWITCH (2026-06-28): Hangi API'nin kullanılacağı
    // Firestore'dan okunuyor (bkz. PlacesApiVersionService) — alan yoksa/
    // okunamazsa New API'ye düşülür. Bu sayede New ve Legacy'nin AYRI
    // ücretsiz aylık kotaları, kod değiştirip yeniden derlemeye gerek
    // kalmadan, Firestore'daki tek bir alan çevrilerek birleştirilebiliyor.
    final apiVersion = await PlacesApiVersionService.getActiveVersion();

    final fetched = apiVersion == PlacesApiVersion.legacy
        ? await _fetchNearbyLegacy(
            lat: lat,
            lng: lng,
            types: types,
            priceLevel: priceLevel,
            radius: radius,
          )
        : await _fetchNearbyNew(
            lat: lat,
            lng: lng,
            types: types,
            priceLevel: priceLevel,
            radius: radius,
          );

    // Sonucu kullanıcıya döndürmeyi bloklamamak için cache yazımı
    // beklenebilir (zaten Firestore yazımı hızlı ve hatada sessizce
    // yutuluyor) — burada await edip tutarlılığı garanti ediyoruz.
    await VenueSearchCacheService.setCached(
      lat: lat,
      lng: lng,
      types: types,
      radius: radius,
      places: fetched,
    );

    return fetched;
  }

  static Future<List<PlaceResult>> _fetchNearbyNew({
    required double lat,
    required double lng,
    required List<String> types,
    int? priceLevel,
    int? radius,
  }) async {
    final body = jsonEncode({
      'includedTypes': types,
      'maxResultCount': _rawFetchCount,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': (radius ?? AppConfig.defaultSearchRadius).toDouble(),
        },
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.placesNearbySearchUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
              'X-Goog-FieldMask': _searchFieldMask,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 || response.statusCode == 403) {
        // ignore: avoid_print
        print(
          '[PlacesService] ❌ Google Places yetkilendirme hatası '
          '(${response.statusCode}) — GOOGLE_MAPS_API_KEY doğru mu ve '
          '"Places API (New)" Cloud Console\'da aktif mi kontrol et.',
        );
        return [];
      }
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('[PlacesService] ⚠️ Google Places status=${response.statusCode} body=${response.body}');
        return [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawResults = decoded['places'] as List<dynamic>? ?? [];

      // ignore: avoid_print
      print('[PlacesService] types=$types count=${rawResults.length}');

      var places = rawResults
          .map((p) => PlaceResult.fromJson(p as Map<String, dynamic>))
          .toList();

      // ⚠️ Places API (New) `searchNearby`, Legacy'nin min_price/max_price
      // parametrelerinin karşılığını DESTEKLEMİYOR — fiyat filtresi bu
      // yüzden istek değil, yanıt üzerinde uygulanıyor.
      if (priceLevel != null) {
        places = places.where((p) => p.priceLevel == priceLevel).toList();
      }

      return places;
    } catch (e) {
      // ignore: avoid_print
      print('[PlacesService] fetch error: $e');
      return [];
    }
  }

  // ── Legacy Places API — Nearby Search HTTP ────────────────────────────────
  //
  // 📍 DUAL API SWITCH (2026-06-28): Bu metod SADECE Firestore'daki
  // `appConfig/placesApi.activeVersion` alanı `"legacy"` olduğunda
  // çağrılır (bkz. PlacesApiVersionService, _fetchAndCacheNearby). Amaç,
  // New API'nin ücretsiz aylık kotası dolmaya yaklaştığında, Legacy'nin
  // KENDİ AYRI ücretsiz kotasına manuel olarak geçip iki kotayı toplamda
  // kullanabilmek.
  //
  // ⚠️ ÖNEMLİ KISIT: Legacy `nearbysearch` endpoint'i TEK bir `type`
  // parametresi kabul eder — New API'nin `includedTypes` dizisi gibi
  // birden fazla type'ı OR mantığıyla TEK istekte birleştiremez. Burada
  // listenin EN ÖNCELİKLİ type'ı (`types.first` — `_resolveTypes`'ın zaten
  // ortak/baskın tipleri öne aldığı sıralama) kullanılıyor, böylece
  // "1 arama = 1 API çağrısı" dengesi New API ile aynı kalıyor (aksi halde
  // her type için ayrı bir çağrı yapmak, Legacy moduna geçilme amacı olan
  // kota tasarrufunu tersine çevirirdi).
  static Future<List<PlaceResult>> _fetchNearbyLegacy({
    required double lat,
    required double lng,
    required List<String> types,
    int? priceLevel,
    int? radius,
  }) async {
    if (types.isEmpty) return [];
    final primaryType = types.first;

    final params = <String, String>{
      'location': '$lat,$lng',
      'radius': '${radius ?? AppConfig.defaultSearchRadius}',
      'type': primaryType,
      'language': 'tr',
      'key': AppConfig.googleMapsApiKey,
    };
    if (priceLevel != null) {
      params['minprice'] = '$priceLevel';
      params['maxprice'] = '$priceLevel';
    }

    final uri = Uri.parse(AppConfig.placesNearbySearchUrlLegacy)
        .replace(queryParameters: params);

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
          '[PlacesService] ⚠️ Legacy status=${response.statusCode} '
          'body=${response.body}',
        );
        return [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;

      if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
        // ignore: avoid_print
        print(
          '[PlacesService] ❌ Legacy Places yetkilendirme/kota hatası '
          '(status=$status) — GOOGLE_MAPS_API_KEY için "Places API" '
          '(Legacy) Cloud Console\'da aktif mi ve kotası dolmuş mu kontrol et.',
        );
        return [];
      }
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        // ignore: avoid_print
        print('[PlacesService] ⚠️ Legacy status=$status body=${response.body}');
        return [];
      }

      final rawResults = body['results'] as List<dynamic>? ?? [];

      // ignore: avoid_print
      print(
        '[PlacesService] (Legacy) type=$primaryType '
        'count=${rawResults.length}',
      );

      var places = rawResults
          .map((r) => PlaceResult.fromLegacyJson(r as Map<String, dynamic>))
          .toList();

      if (priceLevel != null) {
        places = places.where((p) => p.priceLevel == priceLevel).toList();
      }

      return places;
    } catch (e) {
      // ignore: avoid_print
      print('[PlacesService] Legacy fetch error: $e');
      return [];
    }
  }

  // ── Mekanın TÜM fotoğraflarını placeId ile çek ───────────────────────────
  //
  // Nearby Search (New) yanıtı zaten her mekan için birden fazla foto
  // referansı döndürüyor (bkz. PlaceResult.photoReferences), ama placeId
  // başka bir yoldan (kaydedilenler, yorumlar) gelip foto listesi
  // önbelleğe alınmamış olabilir — bu durumda Place Details (New)
  // endpoint'inden SADECE `photos` alanı istenerek mekanın TÜM fotoğrafları
  // ayrıca çekilebiliyor. VenueDetailPage bu sayede gerçek galeriye
  // ulaşabiliyor.
  /// Mekan başına önbelleğe alınan/gösterilen MAKSİMUM galeri fotoğrafı.
  /// 💸 MALİYET DÜŞÜRME (2026-06-28): Önceden 8'di — "3 foto yeterli, daha
  /// fazlası gereksiz maliyet" talebi üzerine düşürüldü (her foto ayrıca
  /// faturalanan bir Google indirme/Storage yükleme işlemi yaratıyor).
  static const int _maxGalleryPhotos = 3;

  static Future<List<String>> fetchPhotoUrls(String placeId) async {
    if (placeId.isEmpty) return [];

    // 💸 MALİYET DÜŞÜRME (2026-06-28): ÖNCE sadece Firestore'a bak — bu
    // mekanın fotoları daha önce (bir yorum eklenmesi veya başka bir
    // kullanıcının ziyareti sonucu) zaten önbelleğe alınmışsa, Google'ın
    // "Place Details" endpoint'ine HİÇ gidilmez. Bu endpoint kendi başına
    // faturalanıyor — yani sadece foto indirmeyi değil, "bu mekanın foto
    // listesi ne?" sorusunun KENDİSİNİ de ücretsiz hale getiriyoruz.
    final cached =
        await VenuePhotoCacheService.getCachedPhotoUrls(placeId: placeId);
    if (cached.isNotEmpty) return cached;

    try {
      final uri = Uri.parse('${AppConfig.placesDetailsUrl}/$placeId');

      final response = await http
          .get(
            uri,
            headers: {
              'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
              'X-Goog-FieldMask': 'photos',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final photos = decoded['photos'] as List<dynamic>? ?? [];

      final photoNames = photos
          .map((p) => (p as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .take(_maxGalleryPhotos)
          .toList();

      // Galeri fotoğrafları paylaşımlı global önbellekten çözümleniyor —
      // `PlaceResult.buildPhotoUrl` ile HER kullanıcı için ayrı ayrı
      // faturalanan ham Google URL'i üretmek yerine.
      return VenuePhotoCacheService.resolvePhotoUrls(
        placeId: placeId,
        photoNames: photoNames,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[PlacesService] fetchPhotoUrls error: $e');
      return [];
    }
  }

  // ── Type Çözümleme ─────────────────────────────────────────────────────────

  /// Aramada Google'a atılacak "type grupları"nı döner — her grup KENDİ
  /// `searchNearby` isteğinde ayrı ayrı gönderilir (bkz. `searchVenues`).
  ///
  /// 🐛 BUG FİX (2026-06-29): "Kafe ve Restoran birlikte seçilince bazı
  /// bölgelerde mekan çıkmıyor" — kök sebep: önceden TÜM seçili aktivitelerin
  /// type'ları (örn. kafe: cafe/bakery + restoran: restaurant/meal_takeaway/
  /// meal_delivery) TEK bir `includedTypes` listesine birleştirilip TEK bir
  /// istekte gönderiliyordu. Google'ın `searchNearby`'ı istek başına en fazla
  /// 20 ham sonuç döndürüyor (`_rawFetchCount`) — bu 20 sonuç, OR'lanan TÜM
  /// type'lar arasında relevans sırasına göre paylaşılıyor. Yoğun restoranlı
  /// bir bölgede 20 sonucun hepsi restoran çıkabiliyor, kafe için HİÇ pay
  /// kalmıyor — sonradan uygulanan whitelist filtresi (`_filterByRequiredTypes`)
  /// kafe'yi doğru şekilde aradığı için suçlu görünmüyor, ama ham havuzda kafe
  /// hiç yoktu. Çözüm: her aktiviteye AYRI bir istek (ayrı 20'lik bütçe)
  /// ayrılıyor — birden fazla aktivite seçilince ekstra API çağrısı oluşur,
  /// ama bu çağrılar da diğerleri gibi KALICI önbelleğe (VenueSearchCacheService)
  /// giriyor, yani bölge+aktivite kombinasyonu başına ömür boyu en fazla 1 kez.
  static List<List<String>> _resolveTypeGroups({
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
  }) {
    // ── MOD 1: Aktivite seçilmişse SADECE o tipler, AKTİVİTE BAŞINA bir grup ──
    // Kullanıcı ne seçtiyse onu göster, kişilik karıştırma.
    // _activityToTypes bir aktivite için birden fazla type döndürür:
    //   "restoran" → ['restaurant', 'food', 'meal_takeaway', 'meal_delivery']
    // Bu sayede kebapçı, dönerci vb. de kapsama girer — ama bu liste KENDİ
    // aktivitesinin grubunda kalır, başka bir aktivitenin type'larıyla
    // karışıp aynı 20'lik bütçeyi paylaşmaz.
    if (selectedActivities.isNotEmpty) {
      final groups = <List<String>>[];
      // Aynı eşleşme (örn. "kahve" + "kafe" ikisi de cafe/bakery'e düşüyor)
      // iki kez ayrı istek olarak tekrarlanmasın — kanonik (sıralı) bir
      // anahtar string'i ile karşılaştırılıyor (Set/List == identity bazlı
      // olduğundan doğrudan koleksiyon karşılaştırması güvenilir değil).
      final addedKeys = <String>{};
      for (final activity in selectedActivities) {
        final lower = activity.toLowerCase();
        for (final entry in _activityToTypes.entries) {
          if (lower.contains(entry.key)) {
            final key = ([...entry.value]..sort()).join(',');
            if (addedKeys.add(key)) {
              groups.add(entry.value);
            }
            break;
          }
        }
      }
      // Eşleşen type yoksa (tanımsız aktivite) kişiliğe geri dön
      if (groups.isNotEmpty) return groups;
    }

    // ── MOD 2: Aktivite seçilmemişse SADECE kişiliğe göre, TEK grup ──────────
    return [
      _resolvePersonalityTypes(
        userProfile: userProfile,
        friendProfile: friendProfile,
      ),
    ];
  }

  static List<String> _resolvePersonalityTypes({
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
  }) {
    //
    // BUG FİX: Önceden `types.addAll(userTypes); types.addAll(friendTypes);`
    // şeklinde art arda ekleniyordu. Dart Set'i ekleme sırasını koruduğundan
    // ve sonunda `take(...)` ile kesildiğinden, baskın tipler farklı
    // olduğunda kullanıcının 4 tipi havuzu doldurup arkadaşın tipinden sadece
    // 1 tanesine yer kalıyordu — yani "iki tarafa da uygun mekan ara"
    // mantığı, ARANAN mekan kategorilerinde aslında kullanıcı tarafına ağır
    // basıyordu (skorlama iki profilin ortalamasını alsa da, havuzun kendisi
    // zaten taraflı geliyordu). Çözüm: ortak olmayan tipleri round-robin
    // (sırayla kullanıcı-arkadaş-kullanıcı-arkadaş) ekleyip her iki tarafa adil
    // temsil hakkı veriyoruz.
    final types = <String>{};

    final userTypes = _personalityTypes[userProfile.dominantType] ?? [];
    final friendTypes = _personalityTypes[friendProfile.dominantType] ?? [];

    // İki kişinin ortak tipleri önce (her ikisine de uygun, kayıpsız kazanç)
    final common = userTypes.toSet().intersection(friendTypes.toSet());
    types.addAll(common);

    final userOnly = userTypes.where((t) => !common.contains(t)).toList();
    final friendOnly = friendTypes.where((t) => !common.contains(t)).toList();
    final maxLen = userOnly.length > friendOnly.length
        ? userOnly.length
        : friendOnly.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < userOnly.length) types.add(userOnly[i]);
      if (i < friendOnly.length) types.add(friendOnly[i]);
    }

    // Secondary tipler — daha geniş havuz.
    //
    // NOT: `se