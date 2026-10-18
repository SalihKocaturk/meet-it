import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friend_profile_page.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/home/providers/personalized_venues_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/friend_compatibility_page.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/personality_analysis_page.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:meetit/core/utils/geo_utils.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/core/widgets/network_status_banner.dart';

// ── Hibrit mekan öğeleri (Firestore yorumu + API önerisi) ─────────────────────
//
// "Yakınınızdaki Beğenilen Mekanlar" carousel'i önce kullanıcı yorumlarını,
// ardından kalan slotları kişilik tipine göre API önerileriyle doldurur.
// Tek bir listeyi taşımak için sealed class kullanılıyor.
sealed class _HybridItem {
  const _HybridItem();
}

final class _ReviewItem extends _HybridItem {
  final VenueReviewModel review;
  const _ReviewItem(this.review);
}

final class _PlaceItem extends _HybridItem {
  final PlaceResult place;
  const _PlaceItem(this.place);
}

// ── Sosyal kanıt: arkadaş önerisi + "Kullanıcı Favorisi" ─────────────────────
//
// "İyi yorum" = 4 yıldız ve üzeri.
//   • Arkadaşlarından biri bir mekana iyi yorum yaptıysa kartta
//     "Arkadaşların tarafından öneriliyor" yazar.
//   • [_kUserFavoriteMinReviewers] veya daha fazla FARKLI kullanıcı iyi yorum
//     yaptıysa fotoğrafın üstünde "Kullanıcı Favorisi" rozeti çıkar.
// Veri: `venueReviewsProvider(placeId)` — mekanın TÜM yorumları (carousel'in
// kendi 50'lik örnekleminden bağımsız, sayım doğru olsun diye).
const _kGoodReviewMinRating = 4;

// Ana sayfa vurgu yeşilleri ("Tümünü Gör", Buluş butonu, ikon kutuları).
const _kAccentGreenBase = Color(0xFF10B981);
const _kAccentGreen = Color(0xFF34D399);
const _kUserFavoriteMinReviewers = 5;

class _VenueSocialProof {
  final bool friendRecommended;
  final bool isUserFavorite;

  /// Mekana iyi yorum yapan (ilk) arkadaş — kartta mini avatar olarak.
  final UserFriendModel? recommender;

  const _VenueSocialProof({
    this.friendRecommended = false,
    this.isUserFavorite = false,
    this.recommender,
  });

  static _VenueSocialProof watch(
    WidgetRef ref,
    String placeId, {
    VenueReviewModel? seed,
  }) {
    // Tam liste henüz yüklenmediyse elimizdeki tek yorumla başla (kart
    // boş görünmesin), yüklenince kendiliğinden güncellenir.
    final reviews = ref.watch(venueReviewsProvider(placeId)).valueOrNull ??
        (seed != null ? [seed] : const <VenueReviewModel>[]);
    final myUid = ref.watch(currentUserProvider)?.uid;
    final friends = {
      for (final f in ref.watch(connectionsProvider))
        if (f.uid != myUid) f.uid: f,
    };

    final goodReviewers = <String>{
      for (final r in reviews)
        if (r.rating >= _kGoodReviewMinRating) r.authorUid,
    };
    final recommenderUid =
        goodReviewers.where(friends.containsKey).firstOrNull;
    return _VenueSocialProof(
      friendRecommended: recommenderUid != null,
      isUserFavorite: goodReviewers.length >= _kUserFavoriteMinReviewers,
      recommender: recommenderUid != null ? friends[recommenderUid] : null,
    );
  }
}

/// Ana Sayfa (eski Feed sekmesinin yerine geçti).
///
/// Üstte arkadaşların yatay listesi (Buluş butonuyla Match sekmesine geçiş),
/// altta hibrit bir mekan carousel'i var: önce Firestore yorumları, kalan
/// slotlar (_kMaxHybridVenues kadar) kişiliğe göre API önerileriyle dolar.
/// Timer + ScrollController kullanıldığı için bu widget bir
/// ConsumerStatefulWidget olmak zorunda (dispose lifecycle'ı gerekiyor).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _carouselController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _resumeTimer;
  static const _scrollStep = 1.2;
  static const _tickDuration = Duration(milliseconds: 16);

  // Hızlı kategori kapsülleri: (emoji, çeviri anahtarı, aktivite seçimi)
  static const _quickActions = <(String, String, Set<String>)>[
    ('🎲', 'home.quick_random', <String>{}),
    ('☕', 'home.quick_cafe', {'Kafe'}),
    ('🍔', 'home.quick_restaurant', {'Restoran'}),
    ('🎭', 'home.quick_culture', {'Kültür/Müze'}),
  ];

  // Yakınızdaki beğenilen mekanlar carousel'inde gösterilecek max öğe sayısı.
  // Eğer Firestore'dan N yorum gelirse, (kMax - N) kadar API önerisi eklenir.
  static const _kMaxHybridVenues = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _resumeTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_tickDuration, (_) {
      if (!_carouselController.hasClients) return;
      final max = _carouselController.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _carouselController.offset + _scrollStep;
      if (next >= max) {
        _carouselController.jumpTo(0);
      } else {
        _carouselController.jumpTo(next);
      }
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
    _resumeTimer?.cancel();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), _startAutoScroll);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    // personalizedVenuesProvider her ikisi de izleniyor — carousel hybrid
    // mantığı için topReviews yüklendiğinde anında, api önerileri gelince
    // de sessizce güncelleniyor (spinner gerekmez).
    final topReviewsAsync = ref.watch(topReviewsProvider);
    final personalizedAsync = ref.watch(personalizedVenuesProvider);
    final connections = ref.watch(connectionsProvider);
    // autoDispose aktivite seçimini canlı tut: hızlı kapsülle yapılan seçim,
    // Buluşma ekranı yeniden çizilene kadar düşmesin.
    ref.listen(selectedActivitiesProvider, (_, _) {});
    final sortedConnections = [...connections]
      ..sort((a, b) => b.meetCount.compareTo(a.meetCount));

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const NetworkStatusBanner(),
            Expanded(
              child: RefreshIndicator(
                color: context.colors.primary,
                backgroundColor: context.colors.card,
                onRefresh: () async {
                  final uid = ref.read(currentUserProvider)?.uid ?? '';
                  await Future.wait([
                    if (uid.isNotEmpty)
                      ref.read(friendsProvider.notifier).loadAll(uid),
                    Future(() => ref.invalidate(topReviewsProvider)),
                    Future(() => ref.invalidate(venueReviewsProvider)),
                    Future(() => ref.invalidate(personalizedVenuesProvider)),
                    Future.delayed(const Duration(milliseconds: 700)),
                  ]);
                },
                child: CustomScrollView(
                  slivers: [
                    // ── Üst bar: başlık + profil avatarı ────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'home.greeting'.tr(
                                      namedArgs: {
                                        'name': titleCaseName(
                                          currentUser?.name.split(' ').first ??
                                              '',
                                          turkish:
                                              context.locale.languageCode ==
                                                  'tr',
                                        ),
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'home.subtitle'.tr(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white60
                                          : context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  ref.read(mainTabIndexProvider.notifier).state =
                                      3,
                              child: CircularAvatar(
                                name: currentUser?.name ?? '',
                                photoUrl: currentUser?.photoUrl,
                                radius: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Hızlı kategori kapsülleri → Buluşma sekmesi ────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              for (final q in _quickActions) ...[
                                _QuickChip(
                                  emoji: q.$1,
                                  label: q.$2.tr(),
                                  onTap: () {
                                    // Seçili aktivite Buluşma ekranına hazır
                                    // gelir; "Rastgele" filtreyi temizler.
                                    // Sonuç ekranı açıksa forma dönülür.
                                    ref.read(showVenuesProvider.notifier).state =
                                        false;
                                    ref
                                        .read(
                                          selectedActivitiesProvider.notifier,
                                        )
                                        .state = q.$3;
                                    ref
                                        .read(mainTabIndexProvider.notifier)
                                        .state = 1;
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Arkadaşların ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 12, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'home.friends_section'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                            if (connections.isNotEmpty)
                              TextButton(
                                onPressed: () => ref
                                    .read(mainTabIndexProvider.notifier)
                                    .state = 2,
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? _kAccentGreen
                                          : const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'home.see_all'.tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: connections.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _NoFriendsCard(
                                onAddFriend: () => ref
                                    .read(mainTabIndexProvider.notifier)
                                    .state = 2,
                              ),
                            )
                          : SizedBox(
                              height: 158,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: sortedConnections.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) =>
                                    _HomeFriendCard(friend: sortedConnections[i]),
                              ),
                            ),
                    ),

                    // ── Yakınınızdaki Beğenilen Mekanlar (Hibrit) ─────────────
                    // Önce Firestore yorumları gösterilir. Yorum sayısı
                    // _kMaxHybridVenues'dan azsa, kalan slotlar kişilik tipine
                    // göre 4+ puanlı yakın mekanlarla (API) sessizce doldurulur.
                    // "Sana Özel" diye ayrı bir bölüm yok — tek carousel.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'home.featured_section'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          // Yorumlar hâlâ yükleniyorsa spinner göster.
                          if (topReviewsAsync.isLoading) {
                            return SizedBox(
                              height: 196,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: context.colors.primary,
                                ),
                              ),
                            );
                          }

                          // Hibrit liste: yorumlar önce, ardından API önerileri.
                          // Aynı mekana birden fazla yorum varsa carousel'de
                          // mekan tek kart olarak görünür (en yüksek puanlı
                          // yorum — liste zaten puana göre sıralı).
                          final seenPlaces = <String>{};
                          final reviews = (topReviewsAsync.valueOrNull ?? [])
                              .where((r) => seenPlaces.add(r.placeId))
                              .toList();
                          final apiVenues = personalizedAsync.valueOrNull ?? [];
                          final reviewIds =
                              reviews.map((r) => r.placeId).toSet();
                          final List<_HybridItem> items = [
                            ...reviews.map((r) => _ReviewItem(r)),
                            if (reviews.length < _kMaxHybridVenues)
                              ...apiVenues
                                  .where(
                                    (p) => !reviewIds.contains(p.placeId),
                                  )
                                  .take(_kMaxHybridVenues - reviews.length)
                                  .map((p) => _PlaceItem(p)),
                          ];

                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                'home.no_reviews_hint'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            );
                          }

                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is UserScrollNotification) {
                                if (notification.direction !=
                                    ScrollDirection.idle) {
                                  _pauseAutoScroll();
                                } else {
                                  _scheduleResume();
                                }
                              }
                              return false;
                            },
                            child: SizedBox(
                              height: 196,
                              child: ListView.separated(
                                controller: _carouselController,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                // Sonsuz döngü hissi için 3 kat tekrarla.
                                itemCount: items.length * 3,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (_, i) {
                                  final item = items[i % items.length];
                                  return switch (item) {
                                    _ReviewItem(:final review) =>
                                      _ReviewCarouselCard(review: review),
                                    _PlaceItem(:final place) =>
                                      _PlaceCarouselCard(venue: place),
                                  };
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Kişiliğini Yönet ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'home.personality_section'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // İki kart yan yana, birebir aynı genişlik ve yükseklikte.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          height: 138,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _FriendCompatActionCard(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FriendCompatibilityPage(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PersonalityActionCard(
                                  icon: Iconsax.chart_2,
                                  title: 'home.view_analysis'.tr(),
                                  subtitle: 'home.view_analysis_desc'.tr(),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PersonalityAnalysisPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hızlı kategori kapsülü ───────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : context.colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : context.colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Arkadaşlarla Uyum Aksiyon Kartı (dinamik subtitle) ────────────────────────

class _FriendCompatActionCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _FriendCompatActionCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final myProfile = me?.personalityProfile;
    // Kullanıcının kendisi listede olsa bile asla "kendinle uyum" gösterme.
    final friends = ref
        .watch(connectionsProvider)
        .where((f) => f.uid != me?.uid)
        .toList();

    String subtitle = 'home.friend_compat_desc'.tr();

    if (myProfile != null && friends.isNotEmpty) {
      UserFriendModel? bestFriend;
      int bestCompat = 0;
      for (final f in friends) {
        final fp = f.personalityProfile;
        if (fp != null) {
          final c = myProfile.compatibilityWith(fp);
          if (c > bestCompat) {
            bestCompat = c;
            bestFriend = f;
          }
        }
      }
      if (bestFriend != null) {
        final firstName = titleCaseName(
          bestFriend.name.split(' ').first,
          turkish: context.locale.languageCode == 'tr',
        );
        subtitle = 'home.friend_compat_value'.tr(
          namedArgs: {'name': firstName, 'value': '$bestCompat'},
        );
      }
    }

    return _PersonalityActionCard(
      icon: Iconsax.people,
      title: 'home.friend_compat'.tr(),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

// ── Kişilik Eylem Kartı ────────────────────────────────────────────────────────

class _PersonalityActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PersonalityActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        // Başlıklar iki kartta birebir aynı hizada: üstte sabit yükseklikli
        // ikon satırı, altında sabit boşluk, sonra başlık + açıklama.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kAccentGreenBase.withOpacity(isDark ? 0.20 : 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: isDark ? _kAccentGreen : const Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : context.colors.hint,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arkadaş Yok Kartı (boş durum + CTA) ───────────────────────────────────────

class _NoFriendsCard extends StatelessWidget {
  final VoidCallback onAddFriend;
  const _NoFriendsCard({required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.people,
              color: context.colors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'home.no_friends_hint'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'home.no_friends_cta'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAddFriend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'home.add_friend_button'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arkadaş Kartı (Buluş butonlu) ─────────────────────────────────────────────

class _HomeFriendCard extends ConsumerWidget {
  final UserFriendModel friend;
  const _HomeFriendCard({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FriendProfilePage(friend: friend),
              ),
            ),
            child: Column(
              children: [
                CircularAvatar(
                  name: friend.name,
                  photoUrl: friend.photoUrl,
                  radius: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  titleCaseName(
                    friend.name.split(' ').first,
                    turkish: context.locale.languageCode == 'tr',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                // Uyum yüzdesi (iki profil de varsa) ya da kişilik tipi
                Builder(builder: (context) {
                  final mine =
                      ref.watch(currentUserProvider)?.personalityProfile;
                  final theirs = friend.personalityProfile;
                  final String? info = theirs == null
                      ? null
                      : mine != null
                          ? 'home.compat_short'.tr(namedArgs: {
                              'value': '${mine.compatibilityWith(theirs)}',
                            })
                          : theirs.dominantType.displayName;
                  return SizedBox(
                    height: 15,
                    child: info == null
                        ? null
                        : Text(
                            info,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white54
                                  : context.colors.textSecondary,
                            ),
                          ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
              ref.read(mainTabIndexProvider.notifier).state = 1;
              ref
                  .read(friendsProvider.notifier)
                  .incrementMeetCount(friend.uid);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: _kAccentGreenBase.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _kAccentGreenBase.withOpacity(0.45),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'friends.meet'.tr(),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    // Açık temada açık yeşil okunmaz → koyu zümrüt
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF047857),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carousel Kartları ─────────────────────────────────────────────────────────
//
// Yorum kartı ve API öneri kartı aynı _VenueCarouselCard iskeletini kullanır:
//   • Fotoğraf: sol üstte beğenen arkadaşın mini avatarı, sağ üstte mesafe
//     rozeti, sol altta (varsa) "Kullanıcı Favorisi", alt kenarda kart
//     rengine yumuşak geçiş.
//   • Altında yalnızca: mekan adı + "★ 4.8 (1816)  •  Restoran" satırı.

/// Kullanıcı konumundan mekana mesafe etiketi ("850 m" / "1.9 km").
String? _distanceLabel(WidgetRef ref, double? lat, double? lng) {
  final user = ref.watch(currentUserProvider);
  if (lat == null || lng == null || user?.lat == null || user?.lng == null) {
    return null;
  }
  final km = GeoUtils.haversineKm(user!.lat!, user.lng!, lat, lng);
  return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

class _ReviewCarouselCard extends ConsumerWidget {
  final VenueReviewModel review;
  const _ReviewCarouselCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fetchedPhotos = ref.watch(venuePhotosProvider(review.placeId));
    final freshPhotoUrl =
        fetchedPhotos.value?.isNotEmpty == true
            ? fetchedPhotos.value!.first
            : null;
    final displayUrl = freshPhotoUrl ?? review.displayPhotoUrl;
    final social = _VenueSocialProof.watch(ref, review.placeId, seed: review);
    // Mekanın GOOGLE puanı: yeni yorumlar bunu kendi dokümanında taşıyor;
    // eski yorumlarda paylaşımlı önbellekten / tek seferlik Google
    // isteğinden tamamlanıyor (bkz. venueGoogleRatingProvider).
    final fallbackRating = review.googleRating == null
        ? ref.watch(venueGoogleRatingProvider(review.placeId)).valueOrNull
        : null;
    final googleRating = review.googleRating ?? fallbackRating?.rating;
    final googleRatingCount =
        review.googleRatingCount ?? fallbackRating?.count;

    // Mini avatar: mekanı beğenen arkadaş; yoksa yorumu yazan kişi.
    final liker = social.recommender;
    return _VenueCarouselCard(
      photoUrl: displayUrl,
      isUserFavorite: social.isUserFavorite,
      name: review.venueName,
      rating: googleRating,
      ratingCount: googleRatingCount,
      distance: _distanceLabel(ref, review.lat, review.lng),
      category: review.venueType != null ? review.typeLabel : 'Mekan',
      likerName: liker?.name ?? review.authorName,
      likerPhotoUrl: liker != null ? liker.photoUrl : review.authorPhotoUrl,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VenueDetailPage(
            placeId: review.placeId,
            venueName: review.venueName,
            venueAddress: review.venueAddress,
            venuePhotoUrl: displayUrl,
            googleRating: googleRating,
            googleRatingCount: googleRatingCount,
            lat: review.lat,
            lng: review.lng,
          ),
        ),
      ),
    );
  }
}

class _PlaceCarouselCard extends ConsumerWidget {
  final PlaceResult venue;
  const _PlaceCarouselCard({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fetchedPhotos = ref.watch(venuePhotosProvider(venue.placeId));
    final photoUrl =
        fetchedPhotos.value?.isNotEmpty == true
            ? fetchedPhotos.value!.first
            : venue.photoUrl;
    final social = _VenueSocialProof.watch(ref, venue.placeId);

    // Kategori bilinmiyorsa fiyat seviyesi (₺₺), o da yoksa "Mekan".
    final typeLabel = venue.primaryTypeLabel;
    final level = venue.priceLevel;
    final category = typeLabel != 'Mekan'
        ? typeLabel
        : (level != null && level > 0)
            ? '₺' * level
            : 'Mekan';

    return _VenueCarouselCard(
      photoUrl: photoUrl,
      isUserFavorite: social.isUserFavorite,
      name: venue.name,
      rating: venue.rating,
      ratingCount: venue.userRatingsTotal,
      distance: _distanceLabel(ref, venue.lat, venue.lng),
      category: category,
      likerName: social.recommender?.name,
      likerPhotoUrl: social.recommender?.photoUrl,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VenueDetailPage(
            placeId: venue.placeId,
            venueName: venue.name,
            venueAddress: venue.vicinity,
            venuePhotoUrl: photoUrl,
            googleRating: venue.rating,
            googleRatingCount: venue.userRatingsTotal,
            lat: venue.lat,
            lng: venue.lng,
          ),
        ),
      ),
    );
  }
}

/// Carousel kartı iskeleti — iki kart türü de bunu kullanır.
class _VenueCarouselCard extends StatelessWidget {
  final String? photoUrl;
  final bool isUserFavorite;
  final String name;
  final double? rating;
  final int? ratingCount;
  final String? distance;
  final String category;
  final String? likerName;
  final String? likerPhotoUrl;
  final VoidCallback onTap;

  static const double photoHeight = 128;

  const _VenueCarouselCard({
    required this.photoUrl,
    required this.isUserFavorite,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.distance,
    required this.category,
    required this.likerName,
    required this.likerPhotoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = context.colors.card;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: photoHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: context.colors.border),
                          errorWidget: (_, _, _) => _VenueCardFallback(),
                        )
                      : _VenueCardFallback(),
                  // Fotoğrafın alt kenarı kart rengine yumuşakça erir
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [card.withOpacity(0), card],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (likerName != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _LikerAvatar(
                        name: likerName!,
                        photoUrl: likerPhotoUrl,
                      ),
                    ),
                  if (distance != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _DistanceBadge(label: distance!),
                    ),
                  if (isUserFavorite)
                    const Positioned(
                      left: 10,
                      bottom: 8,
                      child: _UserFavoriteBadge(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // "★ 4.8 (1816)  •  Restoran" — her kartta dolu
                  SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        if (rating != null) ...[
                          _StarScore(value: rating!, count: ratingCount),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            rating != null ? '•  $category' : category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? Colors.white54
                                  : context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotoğrafın sol üstünde, mekanı beğenen kişinin 26×26 mini avatarı.
class _LikerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _LikerAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kAccentGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircularAvatar(
        name: name,
        photoUrl: photoUrl,
        radius: 13,
        outline: false,
      ),
    );
  }
}

/// Fotoğrafın sağ üstündeki koyu, yarı saydam mesafe rozeti.
class _DistanceBadge extends StatelessWidget {
  final String label;
  const _DistanceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.location, size: 11, color: _kAccentGreen),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Store tarzı puan: tek sarı yıldız + "4.8" (+ opsiyonel yorum sayısı).
class _StarScore extends StatelessWidget {
  final double value;
  final int? count;
  const _StarScore({required this.value, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB800)),
        const SizedBox(width: 3),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(fontSize: 11, color: context.colors.hint),
          ),
        ],
      ],
    );
  }
}

/// Fotoğrafın sol üstündeki altın "Kullanıcı Favorisi" rozeti.
class _UserFavoriteBadge extends StatelessWidget {
  const _UserFavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC53D), Color(0xFFFF8A00)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A00).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'home.user_favorite'.tr(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueCardFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Center(
        child: Icon(
          Iconsax.location,
          color: context.colors.primary,
          size: 28,
        ),
      ),
    );
  }
}

