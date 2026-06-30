import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/attempt_meet_provider.dart';
import 'package:meetit/features/match/providers/map_controller_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/match/widgets/venue_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notifiers/attempt_meet_notifier.dart';
import 'providers/saved_venues_provider.dart';

// Bu dosya artık SADECE `AttemptMeetPage`'i içeriyor — pin/marker üretim
// mantığı ve alt bilgi çubuğu widget'ı sayfa view dosyasının kendisinden
// ayrı dosyalara taşındı:
//   utils/map_marker_builder.dart        → MapMarkerBuilder (pin/avatar bitmap)
//   widgets/venue_bottom_bar.dart        → VenueBottomBar
//
// AYRICA: bu sayfa artık HİÇ `StatefulWidget`/`initState` KULLANMIYOR.
// Tamamen `ConsumerWidget` (stateless) — Riverpod'un state yönetimi
// dışına çıkmamak için iki ayrı yerde tutuluyor:
//   notifiers/attempt_meet_notifier.dart + providers/attempt_meet_provider.dart
//     → `AttemptMeetState` (mekanlar, pinler, seçili index). `AsyncNotifier`
//       olduğu için `build()` provider İLK İZLENDİĞİNDE (sayfa açıldığında)
//       KENDİLİĞİNDEN çalışır — eski `initState`'in yaptığı işi
//       Riverpod'un kendi yaşam döngüsü üstleniyor. İzlediği
//       `venueSearchProvider`/`selectedFriendProvider` değiştiğinde de
//       KENDİLİĞİNDEN yeniden çalışır — eski elle-`reset()` çağrısına da
//       gerek kalmadı (match_page.dart'ta artık bu provider için hiçbir
//       şey çağrılmıyor).
//   notifiers/map_controller_notifier.dart + providers/map_controller_provider.dart
//     → SADECE `GoogleMapController` referansı. Bu "uygulama verisi" değil,
//       render'a özgü bir kontrolcü; ama widget'ın kendi `State`'inde
//       tutulmaması için (StatefulWidget'tan tamamen kurtulmak için) ayrı,
//       basit bir Notifier'a alındı.
//
/// Mekan önerilerini harita üzerinde pinlerle gösteren alternatif görünüm.
///
/// ÖNEMLİ: Bu sayfa mevcut liste tabanlı `VenueResultsView` akışına HİÇ
/// dokunmaz — `match_page.dart`'taki "Mekan Önerilerini Gör" butonu ve
/// onun mantığı tamamen olduğu gibi kalıyor. Bu, "Haritada Göster" adında
/// AYRI bir butonla açılan, ek bir görünüm. Bir sorun çıkarsa eski akış
/// sapasağlam çalışmaya devam eder.
///
/// Kurgu:
///   - Mekan arama sonucundaki TÜM mekanlar (sayfalama olmadan) haritada
///     pin olarak gösterilir. 1. sıradaki mekan ekrana ilk geldiğinde
///     kamera otomatik o pine odaklanır.
///   - Alt bilgi çubuğunda seçili mekanın kart bilgileri (foto, isim, tip,
///     puan, fiyat, kaydet/git butonları) gösterilir; ok tuşlarıyla diğer
///     mekanlara geçilebilir, pin'e dokununca da o mekan seçilir.
///   - Kendi konumum, mekan pinlerinden tamamen farklı/daha büyük, dairesel
///     bir pin ile gösterilir: fotoğrafım varsa yuvarlak halde o, yoksa
///     diğer yerlerde kullandığımız baş harfli avatar mantığıyla aynı.
///   - Eşleştiğim arkadaşımın konumu Firestore'da girilmişse, aynı mantıkla
///     onun da (kendi foto/avatarıyla) bir pin'i çıkar.
class AttemptMeetPage extends ConsumerWidget {
  const AttemptMeetPage({super.key});

  void _focusOn(WidgetRef ref, PlaceResult place) {
    ref
        .read(mapControllerProvider)
        ?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(place.lat, place.lng), 15.5),
        );
  }

  Future<void> _openInMaps(WidgetRef ref, PlaceResult place) async {
    // 📍 GECİKME DÜZELTMESİ (2026-06-28): "tarifi alınan mekanlara ekleme"
    // (Firestore/Storage yazımı içerebilir — bkz. NavigatedVenuesNotifier.add)
    // artık AWAIT EDİLMİYOR. Eskiden harita uygulaması bu kayıt bitene kadar
    // açılmıyordu; artık kayıt arka planda devam ederken harita ANINDA açılır.
    unawaited(ref.read(navigatedVenuesProvider.notifier).add(place));
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(attemptMeetProvider);
    final mapState = mapAsync.valueOrNull ?? const AttemptMeetState();
    final venues = mapState.venues;
    final selectedIndex = mapState.selectedIndex;
    // Pinler "hazır" mı — artık ayrı bir bool alan yerine, notifier'ı saran
    // `AsyncValue`'nun kendi yükleniyor/veri-var durumundan okunuyor.
    final markersReady = !mapAsync.isLoading && mapAsync.hasValue;

    // Seçili mekan değiştiğinde (pin'e dokunma / ok tuşları) kamerayı oraya
    // odakla. Kamera kontrolü `mapControllerProvider`'a bağlı olduğu için
    // (widget'a özgü değil, ama "uygulama state'i" de değil) `ref.read` ile
    // taze veri okunuyor.
    ref.listen(
      attemptMeetProvider.select((s) => s.valueOrNull?.selectedIndex),
      (previous, next) {
        if (next == null) return;
        final currentVenues =
            ref.read(attemptMeetProvider).valueOrNull?.venues ?? const [];
        if (currentVenues.isNotEmpty && next < currentVenues.length) {
          _focusOn(ref, currentVenues[next]);
        }
      },
    );

    // Pinler hazır olduğunda (arama + avatar render bitince) ilk sıradaki
    // mekana otomatik odaklan. `previous`'un loading'den data'ya geçişini
    // izliyoruz — bu, eski `markersReady` bool'unun false→true geçişiyle
    // birebir aynı tetiklenme noktası.
    ref.listen(attemptMeetProvider, (previous, next) {
      final wasReady =
          previous != null && !previous.isLoading && previous.hasValue;
      final isReadyNow = !next.isLoading && next.hasValue;
      if (!wasReady && isReadyNow) {
        final currentVenues = next.valueOrNull?.venues ?? const [];
        if (currentVenues.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 350), () {
            _focusOn(ref, currentVenues.first);
          });
        }
      }
    });

    final initialTarget = venues.isNotEmpty
        ? LatLng(venues.first.lat, venues.first.lng)
        : const LatLng(41.0082, 28.9784); // İstanbul varsayılan
    // `ThemeMode.system` durumunda gerçek koyu/açık bilgisini almak için
    // doğrudan == ThemeMode.dark karşılaştırması yerine isEffectivelyDark
    // kullanılıyor — aksi halde sistem koyu modundayken harita yanlışlıkla
    // açık stille açılırdı.
    final isDark = isEffectivelyDark(ref.watch(themeModeProvider));
    final distanceWarning = ref.watch(venueSearchProvider).distanceWarning;

    // Bu sayfa artık kendi route'u olarak PUSH EDİLMİYOR — match_page.dart'ın
    // gövdesine doğrudan gömülüyor. Yani sistem/donanım "geri" tuşuna
    // basıldığında kapatılacak bir Navigator route'u YOK; PopScope ile bunu
    // yakalayıp aynı sayfadaki yazılım geri butonuyla AYNI davranışı (forma
    // dön) uyguluyoruz. Bu olmadan donanım geri tuşu MatchPage'in ALTINDAKİ
    // (yanlış) bir route'u kapatmaya çalışırdı.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(showVenuesProvider.notifier).state = false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 14,
              ),
              // Uygulama teması koyu ise haritayı da koyu stille aç.
              style: isDark ? darkMapStyle : null,
              onMapCreated: (ctrl) {
                ref.read(mapControllerProvider.notifier).set(ctrl);
                // `style` parametresi ilk render'da uygulanır; ama tema
                // çalışma zamanında değişirse (didUpdateWidget yok) burada
                // da set ediyoruz ki tutarlı kalsın.
                ctrl.setMapStyle(isDark ? darkMapStyle : null);
                if (venues.isNotEmpty) {
                  Future.delayed(const Duration(milliseconds: 200), () {
                    _focusOn(ref, venues.first);
                  });
                }
              },
              // SADECE şu an alt çubukta gösterilen (seçili) mekanın pini
              // çıkar — tüm mekanları aynı anda göstermek kalabalık ve
              // kafa karıştırıcı oluyordu. Sırada ilerlerken (ok tuşları)
              // her adımda haritada da tek bir pin görünür.
              markers: {
                if (venues.isNotEmpty &&
                    mapState.venueMarkers[venues[selectedIndex].placeId] !=
                        null)
                  mapState.venueMarkers[venues[selectedIndex].placeId]!,
                if (mapState.meMarker != null) mapState.meMarker!,
                if (mapState.friendMarker != null) mapState.friendMarker!,
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            if (!markersReady || distanceWarning != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 64,
                      left: 12,
                      right: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!markersReady)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.card,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('match.map_loading_venues'.tr()),
                              ],
                            ),
                          ),
                        if (!markersReady && distanceWarning != null)
                          const SizedBox(height: 10),
                        // ── Mesafe uyarısı (liste görünümündekiyle aynı) ──
                        // Liste görünümünde gösterilen uyarı haritada da
                        // gösterilmiyordu — kullanıcı orta noktanın neden
                        // hesaplanamadığını burada da görebilmeli.
                        if (distanceWarning != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA000).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Color(0xFFFFA000),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    distanceWarning,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.colors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Üst: geri butonu + liste görünümüne geçiş ────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ARTIK Navigator.pop YOK: bu sayfa kendi route'u
                    // olarak push EDİLMİYOR, match_page.dart'ın gövdesine
                    // doğrudan gömülüyor (bkz. match_page.dart
                    // showMapViewProvider). Bu yüzden "geri" tek başına
                    // forma dönmek için sadece showVenuesProvider'ı false
                    // yapıyor — eskiden burada Navigator.pop kullanılıyordu,
                    // bu da YANLIŞ bir route'u (MatchPage'in altındaki
                    // sayfayı) kapatmaya çalışıyordu.
                    GestureDetector(
                      onTap: () {
                        ref.read(showVenuesProvider.notifier).state = false;
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: Theme.of(context).brightness != Brightness.dark
                              ? Colors.black87
                              : Colors.white70,
                        ),
                      ),
                    ),
                    // Harita/liste görünümü TEK butonla yönetiliyor: burada
                    // (haritadayken) sağ üstteki bu buton, aynı arama
                    // sonuçlarını liste şeklinde gösteren
                    // `VenueResultsView`'a geçer. Navigator KULLANILMIYOR —
                    // sadece showMapViewProvider false yapılıyor
                    // (showVenuesProvider zaten true, results modundan
                    // çıkılmıyor, sadece alt görünüm değişiyor). Sonuçlar
                    // zaten venueSearchProvider'da duruyor, tekrar arama
                    // yapılmıyor.
                    GestureDetector(
                      onTap: () {
                        ref.read(showMapViewProvider.notifier).state = false;
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_list_outlined,
                              size: 18,
                              color: context.colors.textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'match.list_view'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Alt: seçili mekan kartı + gezinme ────────────────────────
            if (venues.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Kullanıcı haritayı yakınlaştırıp/uzaklaştırıp pini
                      // gözden kaybetmiş olsa bile, bu butonla seçili
                      // mekanın pinine her zaman geri dönülebilir.
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 10),
                        child: GestureDetector(
                          onTap: () => _focusOn(ref, venues[selectedIndex]),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.colors.card,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.center_focus_strong),
                          ),
                        ),
                      ),
                      VenueBottomBar(
                        place: venues[selectedIndex],
                        index: selectedIndex,
                        total: venues.length,
                        onPrev: selectedIndex > 0
                            ? () => ref
                                  .read(attemptMeetProvider.notifier)
                                  .selectVenue(selectedIndex - 1)
                            : null,
                        onNext: selectedIndex < venues.length - 1
                            ? () => ref
                                  .read(attemptMeetProvider.notifier)
                                  .selectVenue(selectedIndex + 1)
                            : null,
                        onOpenMaps: () =>
                            _openInMaps(ref, venues[selectedIndex]),
                      ),
                    ],
                  ),
                ),
              )
            else if (markersReady)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'match.no_venues_found'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
