import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/match/widgets/personality_pill.dart';
import 'package:meetit/features/match/widgets/venue_card.dart';

// ── Mekan Önerileri Ekranı ────────────────────────────────────────────────────

class VenueResultsView extends ConsumerWidget {
  final VoidCallback onBack;

  const VenueResultsView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(venueSearchProvider);
    final currentUser = ref.watch(currentUserProvider);
    final selectedFriend = ref.watch(selectedFriendProvider);
    final score = ref.watch(compatibilityScoreProvider);

    return CustomScrollView(
      slivers: [
        // Başlık
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'match.results_title'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'match.personality_selected'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Harita/liste tek butonla yönetiliyor: buradayken (liste
                // görünümü) bu buton aynı arama sonuçlarını haritada
                // (AttemptMeetPage) gösterir. Navigator KULLANILMIYOR —
                // sadece showMapViewProvider true yapılıyor; tekrar arama
                // yapılmıyor.
                if (searchState.hasResults)
                  GestureDetector(
                    onTap: () {
                      ref.read(showMapViewProvider.notifier).state = true;
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Kişilik uyumu özeti
        if (selectedFriend != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.primary.withOpacity(0.08),
                      context.colors.primary.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    PersonalityPill(
                      name:
                          currentUser?.name.split(' ').first ??
                          'match.you'.tr(),
                      type: currentUser?.personalityProfile?.dominantType,
                    ),
                    Column(
                      children: [
                        Text(
                          '%$score',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                        Text(
                          'match.compatibility'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    PersonalityPill(
                      name: selectedFriend.name.split(' ').first,
                      type: selectedFriend.personalityProfile?.dominantType,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Yükleme / Hata / Sonuç ───────────────────────────────────────────
        if (searchState.isLoading)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: context.colors.primary),
                  SizedBox(height: 16),
                  Text(
                    'match.loading_venues'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (searchState.errorMessage != null)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: context.colors.hint,
                    ),
                    SizedBox(height: 16),
                    Text(
                      searchState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(
                        'common.back'.tr(),
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // ── Mesafe uyarısı (orta nokta hesaplanamadıysa) ──────────────────
          if (searchState.distanceWarning != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFA000).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFFFA000),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          searchState.distanceWarning!,
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
              ),
            ),

          // ── Orta nokta mekanları (üstte, özel bölüm) ──────────────────────
          if (searchState.hasMidpoint && searchState.midpointVenues.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'match.midpoint_badge'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    ...searchState.midpointVenues.asMap().entries.map(
                      (e) => VenueCard(
                        place: e.value,
                        rank: e.key + 1,
                        context: context,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'match.other_venues'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Başlık satırı: mekan sayısı + sayfa bilgisi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'match.venue_count'.tr(
                        namedArgs: {
                          'count': '${searchState.venues.length}',
                          'page': '${searchState.currentPage + 1}',
                          'total': '${searchState.totalPages}',
                        },
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (searchState.hasNextPage)
                    GestureDetector(
                      onTap: () =>
                          ref.read(venueSearchProvider.notifier).nextPage(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.colors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: context.colors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'venue.change_venue'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
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

          // Mekan kartları
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => VenueCard(
                  place: searchState.venues[i],
                  rank: searchState.currentPage * 5 + i + 1,
                  context: context,
                ),
                childCount: searchState.venues.length,
              ),
            ),
          ),

          // Alt navigasyon
          if (searchState.totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Önceki
                    if (searchState.hasPrevPage)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(venueSearchProvider.notifier).prevPage(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 13,
                          color: context.colors.primary,
                        ),
                        label: Text(
                          'match.prev_page'.tr(),
                          style: TextStyle(
                            color: context.colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Sayfa dots
                    Row(
                      children: List.generate(
                        searchState.totalPages,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == searchState.currentPage ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == searchState.currentPage
                                ? context.colors.primary
                                : context.colors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Sonraki
                    if (searchState.hasNextPage)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(venueSearchProvider.notifier).nextPage(),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: context.colors.primary,
                        ),
                        label: Text(
                          'match.next_page'.tr(),
                          style: TextStyle(
                            color: context.colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ],
    );
  }
}
