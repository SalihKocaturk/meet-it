import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/match/attempt_meet_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/match/widgets/activity_grid.dart';
import 'package:meetit/features/match/widgets/compatibility_card.dart';
import 'package:meetit/features/match/widgets/distance_filter.dart';
import 'package:meetit/features/match/widgets/empty_friends_card.dart';
import 'package:meetit/features/match/widgets/find_venue_button_bar.dart';
import 'package:meetit/features/match/widgets/friend_chip.dart';
import 'package:meetit/features/match/widgets/location_field.dart';
import 'package:meetit/features/match/widgets/personality_banner.dart';
import 'package:meetit/features/match/widgets/price_filter.dart';
import 'package:meetit/features/match/widgets/venue_results_view.dart';
import 'package:meetit/core/widgets/network_status_banner.dart';

// Bu dosya artık SADECE MatchPage'i içeriyor — tüm alt widget'lar ve
// MapLocationPickerPage feature klasör yapısına bölündü:
//   pages/map_location_picker_page.dart   → MapLocationPickerPage
//   widgets/personality_banner.dart       → PersonalityBanner
//   widgets/compatibility_card.dart       → CompatibilityCard
//   widgets/location_field.dart           → LocationField
//   widgets/friend_chip.dart              → FriendChip
//   widgets/empty_friends_card.dart       → EmptyFriendsCard
//   widgets/activity_grid.dart            → ActivityGrid
//   widgets/price_filter.dart             → PriceFilter
//   widgets/distance_filter.dart          → DistanceFilter
//   widgets/find_venue_button_bar.dart    → FindVenueButtonBar
//   widgets/venue_results_view.dart       → VenueResultsView
//   widgets/personality_pill.dart         → PersonalityPill
//   widgets/venue_card.dart               → VenueCard
//   widgets/travel_chip.dart              → TravelChip
//
// Dışarıdan (main_page.dart, edit_profile_page.dart, saved_page.dart,
// sign_up_page.dart, complete_profile_page.dart) bu dosyadan sadece
// `MatchPage` ve `MapLocationPickerPage` import ediliyor — aşağıdaki
// `export` sayesinde o dosyaların import satırlarını değiştirmeye gerek
// kalmadı.
export 'package:meetit/features/match/pages/map_location_picker_page.dart';

class MatchPage extends ConsumerWidget {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final connections = ref.watch(connectionsProvider);
    final showVenues = ref.watch(showVenuesProvider);
    final showMapView = ref.watch(showMapViewProvider);

    // BUG FIX: venueSearchProvider autoDispose DEĞİL (liste/harita geçişinde
    // state korunsun diye) — ama bu yüzden önceki arkadaşla yapılan aramanın
    // sonuçları (ve haritadaki eski mekan pin'leri) bir sonraki arkadaş
    // seçiminde/yeni buluşma akışında hâlâ state'te kalıp tekrar gösteriliyordu.
    // Seçili arkadaş değiştiğinde eski arama sonuçlarını temizliyoruz.
    ref.listen(selectedFriendUidProvider, (previous, next) {
      if (previous != next) {
        ref.read(venueSearchProvider.notifier).reset();
        // Harita görünümünün pinleri (attemptMeetProvider) için burada elle
        // bir şey çağırmaya GEREK YOK: `AttemptMeetNotifier.build()` zaten
        // `venueSearchProvider`'ı ve `selectedFriendProvider`'ı izliyor, bu
        // ikisinden biri değiştiğinde Riverpod o provider'ı kendiliğinden
        // yeniden çalıştırır (bkz. notifiers/attempt_meet_notifier.dart).
      }
    });

    // Harita görünümü kendi Scaffold'unu ve SafeArea/Stack'ini zaten
    // yönetiyor (bkz. AttemptMeetPage.build) — burada doğrudan onu
    // döndürüyoruz, MatchPage'in normal Scaffold'unu SARMIYORUZ (gereksiz
    // iç içe Scaffold olmasın diye).
    if (showVenues && showMapView) {
      return const AttemptMeetPage();
    }

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const NetworkStatusBanner(),
            Expanded(
              child: showVenues
            ? VenueResultsView(
                onBack: () {
                  ref.read(showVenuesProvider.notifier).state = false;
                },
              )
            // ── "Mekan Bul" butonu SABİT (asılı) ──────────────────────────
            //
            // Kullanıcı talebi: buton liste içinde EN ALTTA bir sliver
            // olduğu için tüm filtreler eklenince ekranın çok aşağısına
            // gidiyordu, kullanıcı onu görmek için tamamen sona kadar
            // kaydırmak zorunda kalıyordu. Artık Stack ile ekranın en
            // altına SABİTLENDİ (diğer filtreler bunun ÜZERİNDEN kayar) —
            // CustomScrollView'in sonuna da bu barın yüksekliğine yakın bir
            // boşluk eklendi (bkz. aşağıdaki son SliverToBoxAdapter), yoksa
            // son filtre barın arkasında kalırdı.
            : Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      // Başlık
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.title'.tr(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'match.subtitle'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Kişilik profili banner
                      if (currentUser?.personalityProfile != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: PersonalityBanner(
                              type:
                                  currentUser!.personalityProfile!.dominantType,
                            ),
                          ),
                        ),

                      // Konumun
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.your_location'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LocationField(
                                defaultHint:
                                    currentUser?.location ??
                                    'match.location_hint'.tr(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Arkadaş seçimi
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.friend_to_meet'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (connections.isEmpty)
                                const EmptyFriendsCard()
                              else
                                SizedBox(
                                  height: 112,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: connections.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, i) {
                                      final f = connections[i];
                                      return FriendChip(friend: f);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Uyumluluk göstergesi
                      SliverToBoxAdapter(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final selectedFriend = ref.watch(
                              selectedFriendProvider,
                            );
                            if (selectedFriend == null) {
                              return const SizedBox.shrink();
                            }
                            final score = ref.watch(compatibilityScoreProvider);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: CompatibilityCard(
                                friend: selectedFriend,
                                score: score,
                              ),
                            );
                          },
                        ),
                      ),

                      // Aktivite seçimi (çoklu)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.activity_types'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              ActivityGrid(),
                            ],
                          ),
                        ),
                      ),

                      // Fiyat filtresi
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.price_level'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              PriceFilter(),
                            ],
                          ),
                        ),
                      ),

                      // Mesafe filtresi (orta noktadan / kendi konumundan km)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'match.max_distance'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              DistanceFilter(),
                            ],
                          ),
                        ),
                      ),

                      // Sabit "Mekan Bul" barının altta kapatmaması için
                      // scroll içeriğinin sonuna onun yüksekliğine yakın bir
                      // boşluk ekleniyor (bkz. FindVenueButtonBar — Stack
                      // içinde Positioned(bottom: 0) ile sabitlendi).
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                  const Positioned(
                    left: 0,
          