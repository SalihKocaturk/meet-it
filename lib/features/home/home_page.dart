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
import 'package:meetit/features/personality/personality_analysis_page.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:meetit/core/utils/geo_utils.dart';
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
const _kUserFavoriteMinReviewers = 5;

class _VenueSocialProof {
  final bool friendRecommended;
  final bool isUserFavorite;

  const _VenueSocialProof({
    this.friendRecommended = false,
    this.isUserFavorite = false,
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
    final friendUids = ref
        .watch(connectionsProvider)
        .map((f) => f.uid)
        .where((uid) => uid != myUid)
        .toSet();

    final goodReviewers = <String>{
      for (final r in reviews)
        if (r.rating >= _kGoodReviewMinRating) r.authorUid,
    };
    return _VenueSocialProof(
      friendRecommended: goodReviewers.any(friendUids.contains),
      isUserFavorite: goodReviewers.length >= _kUserFavoriteMinReviewers,
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
                                        'name':
                                            currentUser?.name.split(' ').first ??
                                            '',
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.textPrimary,
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

                    // ── Arkadaşların ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'home.friends_section'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
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
                              height: 140,
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
                              height: 216,
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
                              height: 216,
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
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 124,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 2,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            switch (i) {
                              case 0:
                                return _FriendCompatActionCard(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FriendCompatibilityPage(),
                                    ),
                                  ),
                                );
                              default:
                                return _PersonalityActionCard(
                                  icon: Iconsax.chart_2,
                                  title: 'home.view_analysis'.tr(),
                                  subtitle: 'home.view_analysis_desc'.tr(),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PersonalityAnalysisPage(),
                                    ),
                                  ),
                                );
                            }
                          },
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

// ── Arkadaşlarla Uyum Aksiyon Kartı (dinamik subtitle) ────────────────────────

class _FriendCompatActionCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _FriendCompatActionCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentUserProvider)?.personalityProfile;
    final friends = ref.watch(connectionsProvider);

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
        final firstName = bestFriend.name.split(' ').first;
        subtitle = '$firstName ile %$bestCompat uyum';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: context.colors.primary, size: 20),
            ),
            const SizedBox(height: 10),
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
                  friend.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
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
                color: context.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.colors.primary.withOpacity(0.3),
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
                    color: context.colors.primary,
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

// ── Carousel Kartı: Firestore Yorumu ──────────────────────────────────────────

class _ReviewCarouselCard extends ConsumerWidget {
  final VenueReviewModel review;
  const _ReviewCarouselCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
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
    return GestureDetector(
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
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  displayUrl != null
                      ? CachedNetworkImage(
                          imageUrl: displayUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: context.colors.border),
                          errorWidget: (_, _, _) => _VenueCardFallback(),
                        )
                      : _VenueCardFallback(),
                  if (social.isUserFavorite)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _UserFavoriteBadge(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      review.venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Store tarzı tek yıldız + Google puanı (örn. ★ 4.8 (1280))
                    if (googleRating != null)
                      _StarScore(value: googleRating, count: googleRatingCount)
                    else
                      const SizedBox(height: 15),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (review.venueType != null)
                          _VenueChip(
                            icon: Iconsax.category_2,
                            label: review.typeLabel,
                          ),
                        if (review.lat != null &&
                            currentUser?.lat != null &&
                            currentUser?.lng != null) ...[
                          const SizedBox(width: 5),
                          _VenueChip(
                            icon: Iconsax.location,
                            label: () {
                              final km = GeoUtils.haversineKm(
                                currentUser!.lat!,
                                currentUser.lng!,
                                review.lat!,
                                review.lng!,
                              );
                              return km < 1
                                  ? '${(km * 1000).round()} m'
                                  : '${km.toStringAsFixed(1)} km';
                            }(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (social.friendRecommended)
                      const _FriendRecommendedLabel()
                    else
                      Text(
                        review.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
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
    );
  }
}

// ── Carousel Kartı: API Önerisi (PlaceResult) ─────────────────────────────────
//
// _ReviewCarouselCard ile aynı boyut ve düzende — kullanıcı iki türü
// aynı carousel'de tutarlı görür. Yazar adı yerine Google puanı + yorum
// sayısı gösterilir. Dokununca VenueDetailPage'e geçiş yapar.

class _PlaceCarouselCard extends ConsumerWidget {
  final PlaceResult venue;
  const _PlaceCarouselCard({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final fetchedPhotos = ref.watch(venuePhotosProvider(venue.placeId));
    final photoUrl =
        fetchedPhotos.value?.isNotEmpty == true
            ? fetchedPhotos.value!.first
            : venue.photoUrl;
    final social = _VenueSocialProof.watch(ref, venue.placeId);

    return GestureDetector(
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
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: context.colors.border),
                          errorWidget: (_, _, _) => _VenueCardFallback(),
                        )
                      : _VenueCardFallback(),
                  if (social.isUserFavorite)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _UserFavoriteBadge(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Store tarzı tek yıldız + Google puanı (örn. ★ 4.6 (1280))
                    if (venue.rating != null)
                      _StarScore(
                        value: venue.rating!,
                        count: venue.userRatingsTotal,
                      ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (venue.lat != null &&
                            currentUser?.lat != null &&
                            currentUser?.lng != null) ...[
                          const SizedBox(width: 5),
                          _VenueChip(
                            icon: Iconsax.location,
                            label: () {
                              final km = GeoUtils.haversineKm(
                                currentUser!.lat!,
                                currentUser.lng!,
                                venue.lat!,
                                venue.lng!,
                              );
                              return km < 1
                                  ? '${(km * 1000).round()} m'
                                  : '${km.toStringAsFixed(1)} km';
                            }(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // _ReviewCarouselCard'daki yazar adı satırına karşılık
                    // gelir: arkadaşlardan biri iyi yorum yaptıysa bu yazı.
                    if (social.friendRecommended)
                      const _FriendRecommendedLabel(),
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

/// "Arkadaşların tarafından öneriliyor" satırı.
class _FriendRecommendedLabel extends StatelessWidget {
  const _FriendRecommendedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Iconsax.people, size: 12, color: context.colors.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'home.recommended_by_friends'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
            ),
          ),
        ),
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

/// Ana sayfa carousel kartlarında mekan tipi ve mesafe için küçük bilgi chip'i.
class _VenueChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _VenueChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: context.colors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
