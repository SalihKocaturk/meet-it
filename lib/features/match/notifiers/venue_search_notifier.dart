import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/services/distance_matrix_service.dart';
import 'package:meetit/core/utils/travel_time_estimator.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/services/places_service.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

const _pageSize = 5;

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

  // ── Kısa süreli "az önce gösterilen mekan" hafızası ────────────────────────
  //
  // Kullanıcı şikayeti: aynı arkadaşla peş peşe 3 kez arama yapınca 1.
  // sırada hep aynı mekan çıkıyordu. Sebep: orta-nokta modunda sonuçlar
  // mesafeye göre sıralanıyor, bu da deterministik — en yakın mekan hep
  // kazanıyor. Çözüm: her arkadaş (veya tek başına mod) için son
  // gösterilen mekan ID'lerini bellekte (uygulama kapanınca silinen, kısa
  // süreli) tutup bir sonraki aramada bu mekanları havuzdan çıkarıyoruz —
  // böylece bir öncekinden farklı bir mekan 1. sıraya çıkma şansı buluyor.
  // Notifier instance app boyunca yaşadığı için bu hafıza "session" süresince
  // kalıcıdır; kalıcı depolamaya (Firestore/SharedPreferences) YAZILMAZ.
  static const int _maxHistoryPerKey = 9;
  final Map<String, List<String>> _recentlyShownIds = {};

  String _historyKey(String? friendUid) => friendUid ?? '__solo__';

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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearAll: true,
      clearDistanceWarning: true,
    );

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
    final searchRadius = maxVenueDistanceKm != null
        ? (maxVenueDistanceKm * 1000).round()
        : AppConfig.defaultSearchRadius;

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
      );

      // ── Maksimum mesafe filtresi (kullanıcı talebi) ───────────────────────
      // searchLat/searchLng zaten yukarıda hesaplanan nokta — iki kişi
      // varsa ORTA NOKTA, tek başına modda kullanıcının kendi konumu.
      // Bu sınırı aşan mekanlar TAMAMEN sonuçlardan çıkarılıyor (kullanıcı
      // tercihi: alta itmek değil, doğrudan filtrelemek).
      //
      // NOT: Kullanıcı kuş uçuşu (Haversine) mesafesinin yanlış sonuç
      // verdiğini belirtti (örn. boğaz/köprü araya girince düz çizgi
      // mesafe gerçek yol mesafesinden çok kısa kalıyordu) — bu yüzden
      // filtre artık Google Distance Matrix'in GERÇEK (driving) rota
      // mesafesini kullanıyor. Bu, ulaşım süresi chip'leri için yapılan
      // ayrı çağrıdan (myLat/myLng kaynaklı, aşağıda) BAĞIMSIZ bir istek —
      // o çağrı kullanıcının kendi konumundan, bu filtre ise arama
      // noktasından (orta nokta/kendi konum) mesafe ölçüyor. API
      // başarısız olursa otomatik olarak kuş uçuşuna düşülür (bkz.
      // `DistanceMatrixService.fetchDistancesKm` içindeki fallback).
      if (maxVenueDistanceKm != null) {
        final realDistancesKm = await DistanceMatrixService.fetchDistancesKm(
          originLat: searchLat,
          originLng: searchLng,
          destinations: results,
        );
        results = results.where((p) {
          final km = realDistancesKm[p.placeId] ??
              _haversineKm(searchLat, searchLng, p.lat, p.lng);
          return km <= maxVenueDistanceKm;
        }).toList();
      }

      if (results.isEmpty) {
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
        final sorted = List<PlaceResult>.from(results)
          ..sort((a, b) {
            final dA = _haversineKm(searchLat, searchLng, a.lat, a.lng) +
                _hangoutAdjustmentKm(a);
            final dB = _haversineKm(searchLat, searchLng, b.lat, b.lng) +
                _hangoutAdjustmentKm(b);
            return dA.compareTo(dB);
          });
        final midpoint = sorted.take(3).toList();
        final others = sorted.skip(3).toList();

        _recordShown(friendUid, midpoint);

        state = state.copyWith(
          midpointVenues: midpoint,
          allVenues: others,
          currentPage: 0,
          isLoading: false,
        );

        // Ulaşım süreleri her zaman bu kullanıcının GERÇEK konumundan
        // (myLat/myLng) hesaplanır — orta noktadan değil. Orta nokta sadece
        // mekan ARAMASI için kullanılıyor; kullanıcı "buraya kaç dakikada
        // giderim" diye sorduğunda kendi konumundan süre görmek ister.
        _fetchTravelEstimates(myLat: myLat, myLng: myLng, venues: sorted);
      } else {
        _recordShown(friendUid, results.take(3).toList());

        state = state.copyWith(
          allVenues: results,
          currentPage: 0,
          isLoading: false,
        );

        _fetchTravelEstimates(myLat: myLat, myLng: myLng, venues: results);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Mekan arama sırasında bir hata oluştu.',
      );
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

  void nextPage() {
    if (state.hasNextPage) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void prevPage() {
    if (state.hasPrevPage) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void reset() => state = const VenueSearchState();

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
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

  // ── Buluşma noktasına yakınlık önceliği: "zaman geçirilebilecek yer" mi? ────
  //
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
