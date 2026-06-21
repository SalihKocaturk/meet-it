import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friend_profile_page.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';

/// Ana Sayfa (eski Feed sekmesinin yerine geçti).
///
/// Üstte arkadaşların yatay listesi (Buluş butonuyla Match sekmesine geçiş),
/// altta en yüksek puanlı mekan yorumlarından oluşan, kendiliğinden kayan
/// bir carousel var. Timer + ScrollController kullanıldığı için bu widget
/// bir ConsumerStatefulWidget olmak zorunda (dispose lifecycle'ı gerekiyor).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _carouselController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _resumeTimer;
  static const _cardWidth = 240.0;
  static const _scrollStep = 1.2; // her tick'te kayma miktarı (px)
  static const _tickDuration = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    // Carousel verisi geldikten sonra otomatik kaymayı başlat.
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
        // Sona gelince başa dön — sıçramadan, görünmez bir reset.
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
    final connections = ref.watch(connectionsProvider);
    final topReviewsAsync = ref.watch(topReviewsProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Üst bar: başlık + sağ üstte profil avatarı ─────────────────
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
                                    currentUser?.name.split(' ').first ?? '',
                              },
                            ),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Önceden tanımlı ama hiçbir yerde kullanılmayan
                          // "home.subtitle" çevirisi — başlığın altındaki
                          // boşluğu dolduran kısa bir alt metin olarak eklendi.
                          Text(
                            'home.subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profil avatarı — dokununca Profil sekmesine geç
                    GestureDetector(
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).state = 3,
                      child: currentUser?.photoUrl != null
                          ? CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                currentUser!.photoUrl!,
                              ),
                            )
                          : CircularAvatar(
                              name: currentUser?.name ?? '',
                              radius: 20,
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Arkadaşların ────────────────────────────────────────────────
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _NoFriendsCard(
                        onAddFriend: () =>
                            ref.read(mainTabIndexProvider.notifier).state = 2,
                      ),
                    )
                  : SizedBox(
                      // Kart içeriği (avatar + isim + Buluş butonu) ~136px
                      // yükseklik gerektiriyor — daha kısa bir SizedBox,
                      // butonun alt kenarının kart dışına taşmasına
                      // (RenderFlex overflow) sebep oluyordu.
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: connections.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _HomeFriendCard(friend: connections[i]),
                      ),
                    ),
            ),

            // ── Öne Çıkan Mekanlar ve Yorumlar ─────────────────────────────
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
              child: topReviewsAsync.when(
                data: (reviews) {
                  if (reviews.isEmpty) {
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
                      // Kullanıcı dokunup kaydırmaya başladığında otomatik
                      // kaymayı durdur; bıraktıktan birkaç saniye sonra
                      // tekrar başlat.
                      if (notification is UserScrollNotification) {
                        if (notification.direction != ScrollDirection.idle) {
                          _pauseAutoScroll();
                        } else {
                          _scheduleResume();
                        }
                      }
                      return false;
                    },
                    child: SizedBox(
                      // 210, içerik (resim + metin bloğu) için 1px'lik bir
                      // RenderFlex overflow'una sebep oluyordu — kartın tüm
                      // içeriğine güvenli pay bırakmak için yükseklik artırıldı.
                      height: 216,
                      child: ListView.separated(
                        controller: _carouselController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        // Sonsuz döngü hissi için liste 3 kat tekrarlanıyor;
                        // otomatik kaydırma maxScrollExtent'e gelince jumpTo(0)
                        // ile sıfırlandığından kullanıcı sıçramayı fark etmez.
                        itemCount: reviews.length * 3,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => _ReviewCarouselCard(
                          review: reviews[i % reviews.length],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => SizedBox(
                  height: 210,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                    ),
                  ),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    'home.no_reviews_hint'.tr(),
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Arkadaş Yok Kartı (boş durum + CTA) ───────────────────────────────────────
//
// Önceden sadece tek satırlık küçük bir ipucu metni vardı; bu da arkadaş
// listesinin (140px) yanında ana sayfada tuhaf bir "boşluk" hissi
// yaratıyordu. Şimdi aynı yüksekliğe yakın, ikon + açıklama + "Arkadaş Ekle"
// butonu içeren bir kart gösteriliyor; buton Arkadaşlar sekmesine (index 2)
// geçiş yapıyor.
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
              Icons.people_outline,
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
      // Buton bir piksel taşsa bile kartın köşeli kenarının dışına sızmasın.
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar + isim: dokununca arkadaşın profil sayfasına geç.
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
              // friends_page.dart'taki _ConnectionTile ile aynı desen:
              // arkadaşı seç + Match sekmesine geç.
              ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
              ref.read(mainTabIndexProvider.notifier).state = 1;
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
              // Yazı tipi ölçeği büyütülmüş cihazlarda bile metin kartın
              // dışına taşmasın diye FittedBox ile sıkıştırılıyor.
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

// ── Carousel Kartı ────────────────────────────────────────────────────────────

class _ReviewCarouselCard extends StatelessWidget {
  final VenueReviewModel review;
  const _ReviewCarouselCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VenueDetailPage(
            placeId: review.placeId,
            venueName: review.venueName,
            venueAddress: review.venueAddress,
            venuePhotoUrl: review.venuePhotoUrl,
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
              child: review.venuePhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: review.venuePhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: context.colors.border),
                      errorWidget: (_, _, _) => Container(
                        color: context.colors.primary.withOpacity(0.08),
                        child: Icon(
                          Icons.location_on,
                          color: context.colors.primary,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      color: context.colors.primary.withOpacity(0.08),
                      child: Icon(
                        Icons.location_on,
                        color: context.colors.primary,
                        size: 28,
                      ),
                    ),
            ),
            // Görselin altındaki metin bloğu Expanded içine alındı —
            // kart yüksekliği ne olursa olsun (font ölçeği, küçük piksel
            // farkları vb.) Column kalan alana sığar, RenderFlex
            // overflow'u (örn. eski "1px overflow" uyarısı) imkansız hale
            // gelir.
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 12,
                            color: i < review.rating
                                ? const Color(0xFFFFB800)
                                : context.colors.hint,
                          ),
                        ),
                      ],
                    ),
                    if (review.comment != null &&
                        review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        review.comment!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
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
