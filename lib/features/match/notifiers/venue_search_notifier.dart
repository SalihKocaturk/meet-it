import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/services/distance_matrix_service.dart';
import 'package:meetit/core/services/notification_service.dart';
import 'package:meetit/core/utils/travel_time_estimator.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/history/services/meeting_history_service.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/services/places_service.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pageSize = 3;

// ── State ─────────────────────────────────────────────────────────────────────

class VenueSearchState {
  /// Orta noktaya yakın mekanlar (en üstte gösterilir)
  final List<PlaceResult> midpointVenues;

  /// Diğer mekanlar (kişiliğe göre sıralı)
  final List<PlaceResult> allVenues;

  final int currentPage;
  final bool isLoading;
  final String? errorMessage;
  final double? searchLat;
  final double? searchLng;
  final bool hasMidpoint; // iki kullanıcının konumu kullanıldı mı?

  /// Mesafe çok uzak olduğu için orta nokta hesaplanamadığında
  /// kullanıcıya gösterilecek uyarı (sonuçları engellemez).
  final String? distanceWarning;

  /// Aramada gerçekten kullanılan HAM konumlar (orta nokta DEĞİL).
  /// `searchLat`/`searchLng` orta noktaya hesaplandığında kendi/arkadaşın
  /// gerçek konumunu kaybetmiş oluyordu — haritada her iki kişinin de
  /// kendi pin'ini doğru yerde göstermek için bunlar ayrıca saklanıyor.
  final double? myLat;
  final double? myLng;
  final double? friendLat;
  final double? friendLng;

  /// Mekan kartlarında gösterilecek ulaşım süreleri — placeId → [TravelEstimate].
  ///
  /// Bu artık Google Distance Matrix API'den GERÇEK (trafik tahminli) veriyle
  /// dolduruluyor (bkz. `DistanceMatrixService`); API'ye ulaşılamazsa otomatik
  /// olarak kuş uçuşu tahminine düşer (`TravelEstimate.isApproximate == true`).
  /// Kullanıcının "kuş uçuşu mesafe saçma, API'den al" geri bildirimi üzerine
  /// eklendi.
  final Map<String, TravelEstimate> travelEstimates;

  const VenueSearchState({
    this.midpointVenues = const [],
    this.allVenues = const [],
    this.currentPage = 0,
    this.isLoading = false,
    this.errorMessage,
    this.searchLat,
    this.searchLng,
    this.hasMidpoint = false,
    this.distanceWarning,
    this.myLat,
    this.myLng,
    this.friendLat,
    this.friendLng,
    this.travelEstimates = const {},
  });

  List<PlaceResult> get venues {
    final start = currentPage * _pageSize;
    if (start >= allVenues.length) return [];
    final end = (start + _pageSize).clamp(0, allVenues.length);
    return allVenues.sublist(start, end);
  }

  bool get hasResults => allVenues.isNotEmpty || midpointVenues.isNotEmpty;
  bool get hasNextPage => (currentPage + 1) * _pageSize < allVenues.length;
  bool get hasPrevPage => currentPage > 0;
  int get totalPages => (allVenues.length / _pageSize).ceil();

  VenueSearchState copyWith({
    List<PlaceResult>? midpointVenues,
    List<PlaceResult>? allVenues,
    int? currentPage,
    bool? isLoading,
    String? errorMessage,
    double? searchLat,
    double? searchLng,
    bool? hasMidpoint,
    String? distanceWarning,
    double? myLat,
    double? myLng,
    double? friendLat,
    double? friendLng,
    Map<String, TravelEstimate>? travelEstimates,
    bool clearError = false,
    bool clearAll = false,
    bool clearDistanceWarning = false,
  }) {
    return VenueSearchState(
      midpointVenues:
          clearAll ? [] : (midpointVenues ?? this.midpointVenues),
      allVenues: clearAll ? [] : (allVenues ?? this.allVenues),
      currentPage: clearAll ? 0 : (currentPage ?? this.currentPage),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchLat: searchLat ?? this.searchLat,
      searchLng: searchLng ?? this.searchLng,
      hasMidpoint: hasMidpoint ?? this.hasMidpoint,
      distanceWarning: clearDistanceWarning
          ? null
          : (distanceWarning ?? this.distanceWarning),
      myLat: myLat ?? this.myLat,
      myLng: myLng ?? this.myLng,
      friendLat: friendLat ?? this.friendLat,
      friendLng: friendLng ?? this.friendLng,
      travelEstimates: clearAll
          ? const {}
          : (travelEstimates ?? this.travelEstimates),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VenueSearchNotifier extends Notifier<VenueSearchState> {
  @override
  VenueSearchState build() => const VenueSearchState();

  /// Arama sonuçlarını ve state'i başlangıç değerine sıfırlar.
  /// Arkadaş değiştiğinde veya yeni bir akış başlatılırken çağrılır.
  void reset() => state = const VenueSearchState();

  /// Sonuçlarda bir sonraki sayfaya geç.
  void nextPage() {
    if (!state.hasNextPage) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
  }

  /// Sonuçlarda bir önceki sayfaya dön.
  void prevPage() {
    if (!state.hasPrevPage) return;
    state = state.copyWith(currentPage: state.currentPage - 1);
  }

  // ── Kısa süreli "az önce gösterilen mekan" hafızası ────────────────────────
  //
  // Kullanıcı şikayeti: aynı arkadaşla peş peşe 3 kez arama yapınca 1.
  // sırada hep aynı mekan çıkıyordu. Sebep: orta-nokta modunda sonuçlar
  // mesafeye göre sıralanıyor, bu da deterministik — en yakın mekan hep
  // kazanıyor. Çözüm: her arkadaş (veya tek başına mod) için son
  // gösterilen mekan ID'lerini bellekte (uygulama kapanınca silinen, kısa
  // süreli) tutup bir sonraki aramada bu mekanları havuzdan çıkarıyoruz —
  // böylece bir öncekinden farklı bir mekan 1. sıraya çıkma şansı buluyor.
  // Uygulama yeniden başlatılsa bile aynı arkadaşla son görülen mekanlara
  // dönmesin — SharedPreferences'a kalıcı olarak yazılıyor.
  static const int _maxHistoryPerKey = 9;
  static const String _prefKeyPrefix = 'recently_shown_v1_';
  final Map<String, List<String>> _recentlyShownIds = {};
  bool _historyLoaded = false;

  /// Arama zaman aşımı timer'ı. `searchVenues()` başlangıcında başlatılır,
  /// finally bloğunda her koşulda iptal edilir.
  Timer? _searchTimer;

  String _historyKey(String? friendUid) => friendUid ?? '__solo__';

  /// SharedPreferences'tan tüm arkadaş geçmişlerini bir kez yükler.
  Future<void> _loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        if (!k.startsWith(_prefKeyPrefix)) continue;
        final friendKey = k.substring(_prefKeyPrefix.length);
        final ids = prefs.getStringList(k) ?? [];
        if (ids.isNotEmpty) _recentlyShownIds[friendKey] = ids;
      }
    } catch (e) {
      // ignore: avoid_print
    }
  }

  /// Tek bir arkadaş kaydını SharedPreferences'a yazar (fire-and-forget).
  Future<void> _saveHistory(String friendKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _recentlyShownIds[friendKey] ?? [];
      if (ids.isEmpty) {
        await prefs.remove('\$_prefKeyPrefix\$friendKey');
      } else {
        await prefs.setStringList('\$_prefKeyPrefix\$friendKey', ids);
      }
    } catch (e) {
      // ignore: avoid_print
    }
  }


  /// Firestore `venue_reviews` koleksiyonundan bu mekanlara ait
  /// toplam beğeni sayısını çekip PlaceResult.communityLikes alanını doldurur.
  /// Hata durumunda orijinal liste döner (beğeni verisi olmadan).
  Future<List<PlaceResult>> _enrichWithCommunityLikes(
    List<PlaceResult> venues,
  ) async {
    if (venues.isEmpty) return venues;
    final placeIds = venues.map((v) => v.placeId).toList();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('venue_reviews')
          .where('placeId', whereIn: placeIds)
          .get();

      // placeId → toplam beğeni
      final likes = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final pid = data['placeId'] as String? ?? '';
        final likedBy = (data['likedBy'] as List?)?.length ?? 0;
        likes[pid] = (likes[pid] ?? 0) + likedBy;
      }

      return venues
          .map((v) => v.copyWith(communityLikes: likes[v.placeId] ?? 0))
          .toList();
    } catch (_) {
      return venues; // sessizce devam — beğeni verisi olmadan göster
    }
  }

  void _recordShown(String? friendUid, List<PlaceResult> shown) {
    if (shown.isEmpty) return;
    final key = _historyKey(friendUid);
    final history = _recentlyShownIds.putIfAbsent(key, () => []);
    for (final p in shown) {
      history.remove(p.placeId);
      history.add(p.placeId);
    }
    while (history.length > _maxHistoryPerKey) {
      history.removeAt(0);
    }
    // Kalıcı olarak sakla (fire-and-forget — arama akışını bloklamaz)
    _saveHistory(key).ignore();
  }

  // ── Davranışsal type boost haritası ──────────────────────────────────────
  //
  // Kullanıcının kaydettiği (ağırlık 1) ve tarif aldığı (ağırlık 2, daha güçlü
  // sinyal — kullanıcı gerçekten gitti) mekanların Google Places type'larını
  // sayarak, her type için [0.0, 0.15] aralığında normalize edilmiş bir boost
  // değeri üretir. Bu değer PlacesService.searchVenues'a geçilir ve ortak
  // type'a sahip mekanların toplam skoruna küçük bir katkı eklenir.
  //
  // Boost kasıtlı olarak küçük tutulmuştur — kişilik uyumu ve kalite skoru
  // her zaman belirleyici olmaya devam eder.
  Map<String, double> _buildBehavioralBoosts() {
    final saved = ref.read(savedVenuesProvider);
    final navigated = ref.read(navigatedVenuesProvider);

    final counts = <String, int>{};
    for (final p in navigated) {
      for (final t in p.types) counts[t] = (counts[t] ?? 0) + 2;
    }
    for (final p in saved) {
      for (final t in p.types) counts[t] = (counts[t] ?? 0) + 1;
    }

    if (counts.isEmpty) return const {};
    final maxCount = counts.values.reduce(max).toDouble();
    return counts.map((k, v) => MapEntry(k, (v / maxCount) * 0.15));
  }

  Future<void> searchVenues({
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
    required String? friendUid, // Firestore'dan konumu çekmek için
    int? priceLevel,
    double? userLat,
    double? userLng,
    // Kullanıcının "en fazla bu kadar uzağa giderim" filtresi (km).
    // null = sınırsız. Orta nokta varsa ORTA NOKTADAN, yoksa kullanıcının
    // kendi konumundan kuş uçuşu mesafeye bakılır (bkz. aşağıdaki filtre
    // bloğu) — arkadaşın ayrı bir mesafe sınırı YOKTUR, kullanıcının
    // talebi üzerine bilinçli olarak basit tutuldu.
    double? maxVenueDistanceKm,
  }) async {
    // Önceki bekleyen timer varsa iptal et (peş peşe arama senaryosu)
    _searchTimer?.cancel();
    // 1 dakika içinde sonuç gelmezse "uygun mekan bulunamadı" göster.
    // Finally bloğu her koşulda (başarı / hata / erken return) timer'ı temizler.
    _searchTimer = Timer(const Duration(minutes: 1), () {
      if (state.isLoading) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Uygun mekan bulunamadı.',
        );
      }
    });

    try {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearAll: true,
      clearDistanceWarning: true,
    );

    // Uygulama yeniden başlatılmışsa geçmiş gösterilen mekanları yükle
    await _loadHistory();

    // ── Kullanıcı konumu ───────────────────────────────────────────────────
    double myLat;
    double myLng;

    if (userLat != null && userLng != null) {
      myLat = userLat;
      myLng = userLng;
    } else {
      final position = await _getLocation();
      if (position == null) return;
      myLat = position.latitude;
      myLng = position.longitude;
    }

    // ── Arkadaşın konumunu Firestore'dan çek ──────────────────────────────
    double? friendLat;
    double? friendLng;
    if (friendUid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .get();
        if (doc.exists) {
          friendLat = (doc.data()?['lat'] as num?)?.toDouble();
          friendLng = (doc.data()?['lng'] as num?)?.toDouble();
        }
      } catch (_) {}
    }

    // ── Orta nokta hesapla ────────────────────────────────────────────────
    bool usingMidpoint = false;
    double searchLat = myLat;
    double searchLng = myLng;
    String? distanceWarning;

    const maxDistanceKm = 200.0;

    if (friendUid != null) {
      if (friendLat != null && friendLng != null) {
        final dist = _haversineKm(myLat, myLng, friendLat, friendLng);
        if (dist < maxDistanceKm) {
          searchLat = (myLat + friendLat) / 2;
          searchLng = (myLng + friendLng) / 2;
          usingMidpoint = true;
        } else {
          // İki kişi arasındaki mesafe çok uzun — ortak bir mekan
          // bulmak gerçekçi değil. Kullanıcıyı uyar, kendi konumuna
          // göre aramaya devam et.
          distanceWarning =
              'Buluşmak istediğiniz arkadaşınız size çok uzak '
              '(~${dist.round()} km). Bu yüzden ortak bir mekan '
              'önerilemiyor, bunun yerine sana yakın mekanlar '
              'gösteriliyor.';
        }
      } else {
        // Arkadaşın konum bilgisi yok — orta nokta hesaplanamıyor.
        distanceWarning =
            'Arkadaşınızın konum bilgisi bulunamadığı için ortak bir '
            'buluşma noktası hesaplanamadı. Bunun yerine sana yakın '
            'mekanlar gösteriliyor.';
      }
    }

    state = state.copyWith(
      searchLat: searchLat,
      searchLng: searchLng,
      hasMidpoint: usingMidpoint,
      distanceWarning: distanceWarning,
      myLat: myLat,
      myLng: myLng,
      friendLat: friendLat,
      friendLng: friendLng,
    );

    // Arkadaşla buluşma araması yapıldığında bildirim MEKAN BULUNUNCA gönderilir
    // (aşağıdaki _saveMeetingHistory içinde — burada artık gönderilmiyor).

    // ── Places API ────────────────────────────────────────────────────────
    final excludeIds =
        (_recentlyShownIds[_historyKey(friendUid)] ?? const <String>[])
            .toSet();

    // Arama yarıçapı: kullanıcı bir mesafe filtresi seçtiyse onu (km→m)
    // kullan, seçmediyse `AppConfig.defaultSearchRadius` (5km) varsayılan
    // olarak uygulanır.
    //
    // 📍 API ÇAĞRI TASARRUFU (2026-06-28): Önceden orta nokta modunda
    // `[2500, 5000, 8000, 12000]` adımlarında kademeli olarak TEKRAR TEKRAR
    // arama yapılıyordu (yeterli sonuç çıkmazsa otomatik daha geniş çapa
    // geçiliyordu) — bu, tek bir kullanıcı aramasının arka planda 4 katına
    // kadar Places API çağrısına yol açıyordu. Kullanıcı talebi üzerine
    // ("tek arama yap") bu tamamen kaldırıldı: artık HER arama TEK bir
    // çapta, TEK seferde yapılıyor.
    // NOT: `var` — aşağıdaki Boğaz istisnası gerekirse bu çapı 3 km'ye
    // genişletiyor (fallback arama da genişletilmiş çapı kullansın diye).
    var searchRadius = maxVenueDistanceKm != null
        ? (maxVenueDistanceKm * 1000).round()
        : AppConfig.defaultSearchRadius;

    // Kullanıcının geçmiş tercihlerinden type→boost haritasını inşa et.
    // Boş döner → PlacesService davranışsal boost uygulamaz (ilk kullanım /
    // hiç kayıt/tarif yoksa), herhangi bir hata riski yok.
    final behavioralBoosts = _buildBehavioralBoosts();

    try {
      // Orta nokta modunda (arkadaşla buluşma), ikisinin GERÇEKTEN arasında
      // kaliteli bir yer bulma şansını artırmak için taban bir puan şartı
      // (`AppConfig.midpointMinRating`) uygulanıyor; solo modda şart yok.
      var results = await PlacesService.searchVenues(
        lat: searchLat,
        lng: searchLng,
        userProfile: userProfile,
        friendProfile: friendProfile,
        selectedActivities: selectedActivities,
        priceLevel: priceLevel,
        radius: searchRadius,
        minRating: usingMidpoint ? AppConfig.midpointMinRating : null,
        excludePlaceIds: excludeIds,
        behavioralTypeBoosts: behavioralBoosts,
        // Fotolar burada ÇÖZÜMLENMEZ — aşağıdaki rota mesafesi filtresi
        // bazı mekanları eleyebiliyor; gösterilmeyecek mekan için Photo API
        // kotası harcamamak adına çözümleme, gösterilecek liste
        // kesinleştikten sonra yapılır (bkz. resolvePhotosFor çağrıları).
        resolvePhotos: false,
        // Kullanıcı mesafe filtresi seçtiyse kuş uçuşu kırpması gevşetilmesin:
        // sınır dışı adaylar zaten aşağıdaki rota filtresinde elenecek,
        // örnekleme hakkını onlara harcamak sonuç sayısını düşürüyordu.
        strictRadius: maxVenueDistanceKm != null,
      );

      // ── Maksimum mesafe: KUŞ UÇUŞU ile, PlacesService içinde ─────────────
      // Mesafe sınırı artık tamamen PlacesService'e geçilen `radius` +
      // `strictRadius: true` ile, KUŞ UÇUŞU (Haversine) mesafeyle
      // uygulanıyor — yani "1 km" seçildiyse örnekleme zaten sadece kuş
      // uçuşu 1 km içindeki mekanlardan yapılıyor.
      //
      // NOT (2026-07-05, kullanıcı kararı): Önceden burada seçilen mekanlar
      // Google Distance Matrix'in GERÇEK rota mesafesiyle bir kez daha sert
      // filtreleniyordu. Rota mesafesi kuş uçuşundan her zaman uzun olduğu
      // için bu ikinci eleme sonuç sayısını sürekli 1-2'ye düşürüyordu
      // ("1 km seçtim, 1 mekan çıkıyor"). Kullanıcı talebi üzerine bu rota
      // filtresi TAMAMEN kaldırıldı: kuş uçuşu 1 km içindeyse mekan
      // gösterilir, yol 1.4 km tutsa da sorun değil. Distance Matrix artık
      // yalnızca ulaşım süresi chip'leri için kullanılıyor (bkz.
      // _fetchTravelEstimates) — mekan ELEMEK için değil.

      // ── BOĞAZ İSTİSNASI / deniz problemi (kullanıcı talebi) ──────────────
      // İstanbul'da iki kişinin orta noktası Boğaz'ın (ya da Haliç/Marmara')
      // ORTASINA düşebiliyor. Kullanıcı 1 km gibi dar bir mesafe seçtiyse
      // çapın neredeyse tamamı suda kalıyor ve tek mekan bile çıkmıyor.
      // Koordinatın gerçekten suda olduğunu soracak ücretsiz bir servis yok;
      // ama "orta nokta modu + dar filtre + SIFIR sonuç" bunun güvenilir bir
      // sinyali (denizde mekan olmaz). Bu durumda çap 3 km'ye genişletilip
      // BİR kez daha aranıyor — kıyıdaki mekanlar bulunabilsin. Havuz kalıcı
      // cache'ten geldiği için bu genelde Google'a yeni bir çağrı değildir.
      // Kullanıcıya da mevcut uyarı mekanizmasıyla (distanceWarning) haber
      // veriliyor. Aynı genişletilmiş çap, gerekirse aşağıdaki fallback
      // aramada da kullanılır (searchRadius güncellenir).
      if (results.isEmpty &&
          usingMidpoint &&
          maxVenueDistanceKm != null &&
          maxVenueDistanceKm < 3.0) {
        // ignore: avoid_print
        searchRadius = 3000;
        results = await PlacesService.searchVenues(
          lat: searchLat,
          lng: searchLng,
          userProfile: userProfile,
          friendProfile: friendProfile,
          selectedActivities: selectedActivities,
          priceLevel: priceLevel,
          radius: searchRadius,
          minRating: AppConfig.midpointMinRating,
          excludePlaceIds: excludeIds,
          behavioralTypeBoosts: behavioralBoosts,
          resolvePhotos: false,
          strictRadius: true,
        );
        if (results.isNotEmpty) {
          state = state.copyWith(
            distanceWarning:
                'Buluşma noktanız çevresinde seçtiğin mesafede mekan '
                'bulunamadı (orta nokta denize denk gelmiş olabilir) — '
                'arama çapı 3 km\'ye genişletildi.',
          );
        }
      }

      if (results.isEmpty) {
        // ── FALLBACK ARAMA: kişilik tipi kısıtlamalarını kaldır ──────────────
        // İlk aramada hiç sonuç çıkmadıysa (düşük mesafe, nadir aktivite,
        // vs.) kişilik/aktivite bazlı dar tip filtresini tamamen sallayıp
        // genel popüler mekan tiplerini kullanan geniş bir arama daha yap.
        // Fiyat ve puan şartları da kaldırılır, geçmiş hariç tutma listesi
        // de sıfırlanır — bu sayede en kısıtlayıcı filtreler gevşetilmiş olur.
        // ignore: avoid_print

        var fallbackResults = await PlacesService.searchVenues(
          lat: searchLat,
          lng: searchLng,
          userProfile: userProfile,
          friendProfile: friendProfile,
          selectedActivities: selectedActivities,
          priceLevel: null,      // fiyat şartı yok
          radius: searchRadius,
          minRating: null,       // puan şartı yok
          excludePlaceIds: {},   // geçmiş hariç tutma yok
          fallback: true,        // kişilik tiplerini sallayıp generic ara
          behavioralTypeBoosts: behavioralBoosts,
          resolvePhotos: false,  // fotolar gösterim listesi kesinleşince
          strictRadius: maxVenueDistanceKm != null,
        );

        // Mesafe sınırı fallback aramada da PlacesService içinde kuş uçuşu
        // ile uygulanıyor (radius + strictRadius) — burada ekstra rota
        // filtresi YOK (bkz. yukarıdaki 2026-07-05 notu).
        if (fallbackResults.isNotEmpty) {
          results = fallbackResults;
          // ignore: avoid_print
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: maxVenueDistanceKm != null
                ? 'Seçtiğin mesafe aralığında uygun mekan bulunamadı. '
                    'Mesafe sınırını artırmayı veya farklı aktivite/fiyat '
                    'seçmeyi deneyebilirsin.'
                : 'Yakında uygun mekan bulunamadı. Farklı aktivite veya fiyat seç.',
          );
          return;
        }
      }

      if (usingMidpoint) {
        // Orta noktaya en yakın 3 mekan ayrı gösterilir.
        //
        // Sadece HAM mesafeye göre sıralamak, orta noktaya en yakın yerin
        // (örn. Beşiktaş/Kadıköy'de tonla bulunan genel bir burgerci/
        // lahmacuncu zinciri) gerçekte birlikte zaman geçirilebilecek bir
        // yer olup olmadığını hiç dikkate almıyordu. Bunu düzeltmek için
        // gerçek mesafeye küçük bir "uygunluk ayarı" (km) ekliyoruz: kafe/
        // restoran/park/müze gibi oturup zaman geçirilebilecek type'lar
        // sanki biraz daha yakınmış gibi öne çekiliyor, isminden anlaşılan
        // hızlı/ayaküstü tüketim yerleri (büfe, fast food, lahmacuncu vb.)
        // sanki biraz daha uzakmış gibi geriye itiliyor. Mesafe hâlâ ana
        // belirleyici — bu sadece eşit/yakın mesafelerdeki sıralamayı
        // mantıklı hale getiren küçük bir düzeltme.
        var sorted = List<PlaceResult>.from(results)
          ..sort((a, b) {
            final dA = _haversineKm(searchLat, searchLng, a.lat, a.lng) +
                _hangoutAdjustmentKm(a);
            final dB = _haversineKm(searchLat, searchLng, b.lat, b.lng) +
                _hangoutAdjustmentKm(b);
            return dA.compareTo(dB);
          });
        // Fotoğrafları SADECE gösterilecek nihai liste için çözümle
        // (arama sırasında resolvePhotos: false ile ertelendi — mesafe
        // filtresiyle elenen mekanlar için Photo API kotası harcanmadı).
        sorted = await PlacesService.resolvePhotosFor(sorted);
        sorted = await _enrichWithCommunityLikes(sorted);
        final midpoint = sorted.take(3).toList();
        final others = sorted.skip(3).toList();

        _recordShown(friendUid, midpoint);

        state = state.copyWith(
          midpointVenues: midpoint,
          allVenues: others,
          currentPage: 0,
          isLoading: false,
        );

        // Geçmiş kaydet + arkadaşa bildirim gönder (arka planda)
        _saveMeetingHistory(
          allVenues: sorted,
          friendUid: friendUid,
          selectedActivities: selectedActivities,
          searchLat: searchLat,
          searchLng: searchLng,
          hasMidpoint: usingMidpoint,
        );

        // Ulaşım süreleri her zaman bu kullanıcının GERÇEK konumundan
        // (myLat/myLng) hesaplanır — orta noktadan değil. Orta nokta sadece
        // mekan ARAMASI için kullanılıyor; kullanıcı "buraya kaç dakikada
        // giderim" diye sorduğunda kendi konumundan süre görmek ister.
        _fetchTravelEstimates(myLat: myLat, myLng: myLng, venues: sorted);
      } else {
        // Fotoğraflar gösterilecek liste kesinleşince çözümlenir (aramada
        // resolvePhotos: false ile ertelendi). PlacesService en fazla
        // AppConfig.maxVenueResults (3) mekan döndürür; take(3) güvenlik ağı.
        var shown =
            await PlacesService.resolvePhotosFor(results.take(3).toList());
        shown = await _enrichWithCommunityLikes(shown);

        _recordShown(friendUid, shown);

        state = state.copyWith(
          allVenues: shown,
          currentPage: 0,
          isLoading: false,
        );

        // Geçmiş kaydet (tek başına modda bildirim atlanır)
        _saveMeetingHistory(
          allVenues: shown,
          friendUid: friendUid,
          selectedActivities: selectedActivities,
          searchLat: searchLat,
          searchLng: searchLng,
          hasMidpoint: usingMidpoint,
        );

        _fetchTravelEstimates(myLat: myLat, myLng: myLng, venues: shown);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Mekan arama sırasında bir hata oluştu.',
      );
    }
    } finally {
      // Başarı, hata veya erken return — her koşulda timer'ı durdur
      _searchTimer?.cancel();
      _searchTimer = null;
    }
  }

  /// Mekan listesi ekrana çıktıktan SONRA ulaşım sürelerini arka planda
  /// çeker (`await` EDİLMİYOR — kullanıcı mekanları hemen görsün, süreler
  /// Distance Matrix API'den (veya fallback'ten) gelince kartlara eklenir).
  ///
  /// Bilinçli olarak `searchVenues()` akışını bloklamıyor: API isteği
  /// birkaç yüz ms sürebilir, mekan listesini bu kadar geciktirmenin
  /// kullanıcı deneyimine bir faydası yok.
  Future<void> _fetchTravelEstimates({
    required double myLat,
    required double myLng,
    required List<PlaceResult> venues,
  }) async {
    if (venues.isEmpty) return;
    try {
      final estimates = await DistanceMatrixService.fetchTravelEstimates(
        originLat: myLat,
        originLng: myLng,
        destinations: venues,
      );
      state = state.copyWith(travelEstimates: estimates);
    } catch (_) {
      // Sessizce yut — ulaşım süresi gösterilmemesi kritik bir hata değil,
      // mekan kartları her hâlükârda görünür kalmalı.
    }
  }

  /// Başarılı aramanın ardından Firestore'a buluşma kaydı yazar.
  ///
  /// `await` EDİLMİYOR — ana akışı bloklamaz. Yazma hatası sessizce yutulur
  /// (geçmiş kayıt başarısız olsa bile kullanıcı mekan sonuçlarını görür).
  /// Arkadaşla arama yapıldıysa `venue_found` tipiyle push bildirimi gönderilir.
  Future<void> _saveMeetingHistory({
    required List<PlaceResult> allVenues,
    required String? friendUid,
    required List<String> selectedActivities,
    required double searchLat,
    required double searchLng,
    required bool hasMidpoint,
  }) async {
    try {
      final me = ref.read(currentUserProvider);
      if (me == null) return;
      final myUid = ref.read(authProvider).user?.uid;
      if (myUid == null) return;

      // Arkadaşın adını ve fotoğrafını Firestore'dan çek
      String? friendName;
      String? friendPhotoUrl;
      if (friendUid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendUid)
              .get();
          if (doc.exists) {
            friendName = doc.data()?['name'] as String?;
            friendPhotoUrl = doc.data()?['photoUrl'] as String?;
          }
        } catch (_) {}
      }

      // PlaceResult → VenueSnapshot dönüşümü (max 3 mekan kaydedilir)
      final snapshots = allVenues.take(3).map((p) {
        final cachedUrls = p.photoReferences
            .where((r) => r.startsWith('https://'))
            .take(3)
            .toList();
        return VenueSnapshot(
          placeId: p.placeId,
          name: p.name,
          vicinity: p.vicinity,
          lat: p.lat,
          lng: p.lng,
          rating: p.rating,
          photoUrls: cachedUrls,
          types: p.types,
          priceLevel: p.priceLevel,
        );
      }).toList();

      final participantUids = [
        myUid,
        if (friendUid != null) friendUid,
      ];

      final record = MeetingRecord(
        id: '', // Firestore otomatik üretir
        initiatorUid: myUid,
        initiatorName: me.name,
        initiatorPhotoUrl: me.photoUrl,
        friendUid: friendUid,
        friendName: friendName,
        friendPhotoUrl: friendPhotoUrl,
        activities: selectedActivities,
        venues: snapshots,
        searchLat: searchLat,
        searchLng: searchLng,
        hasMidpoint: hasMidpoint,
        createdAt: DateTime.now(),
        participantUids: participantUids,
      );

      await MeetingHistoryService.save(record);

      // Arkadaşa bildirim gönder
      if (friendUid != null) {
        NotificationService.sendNotification(
          toUid: friendUid,
          type: 'meetup_invite',
          fromName: me.name,
          fromUid: myUid,
        ).ignore();
      }
    } catch (_) {
      // Geçmiş kayıt başarısız olsa bile sessizce yut — kullanıcı
      // mekan sonuçlarını görmeye devam eder.
    }
  }

  // ── Haversine mesafe hesabı ───────────────────────────────────────────────

  /// İki koordinat arasındaki kuş uçuşu mesafeyi kilometre cinsinden döner.
  /// Orta nokta hesabı, mesafe filtresi ve mekan sıralama skorlamasında
  /// kullanılır.
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Dünya yarıçapı (km)
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // ── Hangout uyumu yardımcıları ────────────────────────────────────────────

  // Oturup sohbet edilebilecek/zaman geçirilebilecek type'lar — bunlar orta
  // nokta sıralamasında hafifçe öne çekilir.
  static const Set<String> _hangoutFriendlyTypes = {
    'cafe', 'restaurant', 'park', 'museum', 'art_gallery', 'library',
    'bar', 'night_club', 'movie_theater', 'tourist_attraction', 'bakery',
  };

  // İsminden anlaşılan hızlı/ayaküstü tüketim yerleri — "cafe"/"restaurant"
  // gibi oturmaya uygun bir type'ı da YOKSA hafifçe geriye itilir (tamamen
  // elenmez, sadece eşit mesafede gerçek bir "mekan"ın önüne geçmesin).
  static const List<String> _quickServiceNameKeywords = [
    'büfe', 'fast food', 'lahmacun', 'dürüm', 'kebapçı', 'tost ', 'çorbacı',
    'döner ',
  ];

  double _hangoutAdjustmentKm(PlaceResult place) {
    final lowerName = place.name.toLowerCase();
    final isQuickServiceName =
        _quickServiceNameKeywords.any(lowerName.contains) &&
            !place.types.contains('cafe') &&
            !place.types.contains('restaurant');
    if (isQuickServiceName) return 0.35; // ~350m geriye it

    final isHangoutFriendly =
        place.types.any(_hangoutFriendlyTypes.contains);
    if (isHangoutFriendly) return -0.2; // ~200m öne çek
    return 0.0;
  }

  Future<Position?> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
          isLoading: false,
          errorMessage: 'Konum servisi kapalı. Lütfen açın.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
            isLoading: false, errorMessage: 'Konum izni verilmedi.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
          isLoading: false,
          errorMessage: 'Konum izni kalıcı reddedildi.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }
}
