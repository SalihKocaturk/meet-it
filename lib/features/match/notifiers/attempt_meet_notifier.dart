import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/match/utils/map_marker_builder.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// `AttemptMeetPage` (harita görünümü) için durum.
///
/// NOT: `GoogleMapController` ve kamera animasyonu (`animateCamera`) BİLEREK
/// burada DEĞİL, `map_controller_provider.dart`da kalıyor — o bir UI/render
/// kontrolcüsü, "uygulama verisi" değil. Bu state sadece HANGİ mekanın seçili
/// olduğunu ve pinlerin ne olduğunu bilir; kamerayı nasıl hareket
/// ettireceğini bilmez (widget, selectedIndex değişimini dinleyip kendi
/// `_focusOn` metoduyla tepki verir).
///
/// `markersReady` alanı YOK — bu artık `attemptMeetProvider`ı saran
/// `AsyncValue`'nun `isLoading`/`hasValue` durumuyla ifade ediliyor (bkz.
/// aşağıdaki `AttemptMeetNotifier`).
class AttemptMeetState {
  final List<PlaceResult> venues;
  final Map<String, Marker> venueMarkers;
  final Marker? meMarker;
  final Marker? friendMarker;
  final int selectedIndex;

  const AttemptMeetState({
    this.venues = const [],
    this.venueMarkers = const {},
    this.meMarker,
    this.friendMarker,
    this.selectedIndex = 0,
  });

  AttemptMeetState copyWith({
    List<PlaceResult>? venues,
    Map<String, Marker>? venueMarkers,
    Marker? meMarker,
    Marker? friendMarker,
    int? selectedIndex,
  }) {
    return AttemptMeetState(
      venues: venues ?? this.venues,
      venueMarkers: venueMarkers ?? this.venueMarkers,
      meMarker: meMarker ?? this.meMarker,
      friendMarker: friendMarker ?? this.friendMarker,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// ÖNEMLİ MİMARİ KARAR: bu `Notifier` DEĞİL, `AsyncNotifier`.
///
/// Eskiden (`_AttemptMeetPageState.initState` döneminde) "sayfa açıldığında
/// veriyi hazırla" işi widget'ın `initState`'inde elle tetikleniyordu, ve
/// "arkadaş değişince eski veriyi temizle" işi de `match_page.dart`'tan elle
/// `reset()` çağırılarak yapılıyordu.
///
/// `AsyncNotifier` ile bu iki elle-tetikleme tamamen ortadan kalkıyor:
///   - `build()` içinde `ref.watch(...)` ile bağımlı olduğumuz provider'ları
///     izliyoruz. Riverpod, bu provider `attemptMeetProvider` üzerinden İLK
///     KEZ izlendiğinde (`AttemptMeetPage.build`'de `ref.watch` çağrıldığında)
///     `build()`'i KENDİSİ otomatik çalıştırır — bu, eski `initState`'in
///     yaptığı işi devralır.
///   - İzlenen `venueSearchProvider` veya `selectedFriendProvider` her
///     değiştiğinde (örn. arkadaş değişimi, yeni arama) Riverpod `build()`'i
///     KENDİSİ yeniden çalıştırır — bu da eski elle-`reset()`'in yaptığı işi
///     devralır. `match_page.dart`'ta artık bu provider için elle bir şey
///     çağırmaya gerek YOK.
class AttemptMeetNotifier extends AsyncNotifier<AttemptMeetState> {
  @override
  Future<AttemptMeetState> build() async {
    // `AsyncNotifier`, bir bağımlılık değiştiğinde varsayılan olarak ÖNCEKİ
    // veriyi (`AsyncValue.value`) saklayıp sadece `isLoading: true` işaretler
    // (eski pinler ekranda kalır). Burada BİLEREK önceki veriyi tamamen
    // sıfırlıyoruz — farklı bir arkadaşa geçildiğinde önceki arkadaşın
    // mekan/avatar pinleri yeni arama bitene kadar ekranda asılı kalmasın
    // diye (eski StatefulWidget'taki `initState` davranışıyla aynı: her
    // zaman sıfırdan başlar).
    state = const AsyncValue.loading();

    final searchState = ref.watch(venueSearchProvider);
    // Sıralama: önce orta noktaya yakın mekanlar, sonra diğerleri — liste
    // görünümündeki ile aynı genel sıra mantığı.
    final venues = [...searchState.midpointVenues, ...searchState.allVenues];

    final currentUser = ref.watch(currentUserProvider);
    final selectedFriend = ref.watch(selectedFriendProvider);
    final userLoc = ref.watch(userLocationProvider);

    // ── Kendi konumum ───────────────────────────────────────────────────
    //
    // ÖNEMLİ: `searchState.searchLat`/`searchLng` orta nokta hesaplandığında
    // (hasMidpoint == true) kendi gerçek konumum DEĞİL, ikimizin arasındaki
    // orta noktadır — bu yüzden kendi pinim için asla onu kullanmıyoruz.
    // Notifier, arama sırasında gerçekten kullanılan ham konumu
    // `searchState.myLat`/`myLng` içinde sakladığı için önce onu deniyoruz;
    // sonra manuel girilmiş konumu (`userLocationProvider`).
    double? myLat = searchState.myLat ?? userLoc?.lat;
    double? myLng = searchState.myLng ?? userLoc?.lng;
    if ((myLat == null || myLng == null) && !searchState.hasMidpoint) {
      // Orta nokta hesaplanmadıysa (tek başına arama) searchLat/Lng zaten
      // kendi konumumdur.
      myLat = searchState.searchLat;
      myLng = searchState.searchLng;
    }

    // ── Arkadaşımın konumu ──────────────────────────────────────────────
    // Notifier arama sırasında arkadaşın konumunu zaten Firestore'dan
    // çekip `searchState.friendLat`/`friendLng` içinde saklıyor — önce onu
    // kullanıyoruz, sadece eksikse aşağıda tekrar Firestore'a soruyoruz.
    double? friendLat = searchState.friendLat ?? selectedFriend?.lat;
    double? friendLng = searchState.friendLng ?? selectedFriend?.lng;
    if ((friendLat == null || friendLng == null) && selectedFriend != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(selectedFriend.uid)
            .get();
        if (doc.exists) {
          friendLat = (doc.data()?['lat'] as num?)?.toDouble() ?? friendLat;
          friendLng = (doc.data()?['lng'] as num?)?.toDouble() ?? friendLng;
        }
      } catch (_) {
        // Firestore'dan çekilemezse elimizdeki (varsa) eski değerle devam.
      }
    }

    // ── Mekan pinleri ────────────────────────────────────────────────────
    final venueMarkers = <String, Marker>{};
    for (var i = 0; i < venues.length; i++) {
      final place = venues[i];
      venueMarkers[place.placeId] = MapMarkerBuilder.buildVenueMarker(
        place: place,
        rankIndex: i,
        onTap: () => selectVenue(i),
      );
    }

    // ── Kişi pinleri (foto/avatar render'ı asenkron) ─────────────────────
    Marker? meMarker;
    if (myLat != null && myLng != null) {
      meMarker = await MapMarkerBuilder.buildPersonMarker(
        id: 'me',
        lat: myLat,
        lng: myLng,
        name: currentUser?.name ?? 'match.map_you'.tr(),
        photoUrl: currentUser?.photoUrl,
        borderColor: const Color(0xFF6C5CE7),
        size: 54,
      );
    }

    Marker? friendMarker;
    if (friendLat != null && friendLng != null) {
      friendMarker = await MapMarkerBuilder.buildPersonMarker(
        id: 'friend',
        lat: friendLat,
        lng: friendLng,
        name: selectedFriend?.name ?? 'match.map_friend'.tr(),
        photoUrl: selectedFriend?.photoUrl,
        borderColor: const Color(0xFFE17055),
        size: 48,
      );
    }

    return AttemptMeetState(
      venues: venues,
      venueMarkers: venueMarkers,
      meMarker: meMarker,
      friendMarker: friendMarker,
    );
  }

  /// Ok tuşları / pin'e dokunma ile mekan seçimi. `build()`'i yeniden
  /// TETİKLEMİYOR — sadece elimizdeki mevcut veriyi (`state.value`) güncelliyor.
  void selectVenue(int index) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.venues.length) return;
    state = AsyncValue.data(current.copyWith(selectedIndex: index));
  }
}
