import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';

import '../personality/models/personality_model.dart';

/// Bir arkadaşın profilini gösteren sayfa.
///
/// Kendi Profil sekmesiyle (bkz. profile_page.dart) BİREBİR aynı düzeni
/// kullanır — avatar + istatistikler + bio (konum/kişilik) ve altında
/// yorum gridi. Tek fark: bu sayfa salt görüntüleme amaçlı olduğu için
/// ayarlar/menü butonu yok, ve "Kaydedilenler" / "Tarifi Alınanlar"
/// sekmeleri burada gösterilmiyor — çünkü bu ikisi cihaza özel
/// (SharedPreferences) veriler ve başka bir kullanıcı için anlamlı/erişilir
/// değil. Kişilik dağılımı kartı ve "Buluşma Mekanı Bul" butonu da kasıtlı
/// olarak burada YOK (bu sayfa salt profil görüntüleme; buluşma akışı zaten
/// Ana Sayfa/Arkadaşlar sayfasındaki "Buluş" butonundan başlatılıyor).
class FriendProfilePage extends ConsumerWidget {
  final UserFriendModel friend;

  const FriendProfilePage({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = friend.personalityProfile;
    final reviewsAsync = ref.watch(myReviewsProvider(friend.uid));
    final reviews = reviewsAsync.value ?? const <VenueReviewModel>[];
    final totalLikes = reviews.fold(0, (sum, r) => sum + r.likeCount);
    final friendsCount =
        ref.watch(friendFriendsCountProvider(friend.uid)).value ?? 0;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Üst bar: geri butonu + isim (Profil sayfasındaki ayarlar/menü
            // butonunun karşılığı burada yok — bu sadece görüntüleme sayfası).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: context.colors.textPrimary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        friend.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Avatar + istatistikler + bio (konum/kişilik) — Profil
            // sayfasındaki _ProfileHeader ile aynı desen ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircularAvatar(
                          name: friend.name,
                          photoUrl: friend.photoUrl,
                          radius: 40,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _Stat(
                                label: 'profile.stat_posts'.tr(),
                                value: reviews.length,
                              ),
                              _Stat(
                                label: 'profile.stat_friends'.tr(),
                                value: friendsCount,
                              ),
                              _Stat(
                                label: 'profile.stat_likes'.tr(),
                                value: totalLikes,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: context.colors.hint,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'friend_profile.friends_since'.tr(
                                  namedArgs: {
                                    'date': _formatDate(friend.addedAt),
                                  },
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (profile != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  profile.dominantType.emoji,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.dominantType.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Tab bar (Profil sayfasındaki _TabBarDelegate ile aynı görsel
            // desen) — burada sadece "Yorumlar" sekmesi var; "Kaydedilenler"
            // ve "Tarifi Alınanlar" sekmeleri cihaza özel veri olduğu için
            // başka bir kullanıcı için gösterilemiyor, bu yüzden bilerek yok.
            SliverPersistentHeader(
              pinned: true,
              delegate: _FriendTabBarDelegate(),
            ),
            reviewsAsync.when(
              data: (data) => _FriendReviewsGrid(reviews: data),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: _FriendReviewsGrid(reviews: reviews),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── İstatistik (Profil sayfasındaki _Stat ile aynı desen) ───────────────────
class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

// ── Tab Bar (Profil sayfasındaki _TabBarDelegate/_Tab ile aynı görsel desen
// — burada sadece tek, hep seçili bir "Yorumlar" sekmesi var) ───────────────
class _FriendTabBarDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: context.colors.scaffold,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.primary, width: 2),
                ),
              ),
              child: Icon(
                Icons.grid_on,
                size: 22,
                color: context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FriendTabBarDelegate old) => false;
}

// ── Yorumlar Grid (Profil sayfasındaki _ReviewsGrid ile aynı desen — private
// olduğu için burada ufak bir kopyası tutuluyor) ─────────────────────────────
class _FriendReviewsGrid extends StatelessWidget {
  final List<VenueReviewModel> reviews;

  const _FriendReviewsGrid({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 40,
                  color: context.colors.hint,
                ),
                const SizedBox(height: 10),
                Text(
                  'profile.no_reviews'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final review = reviews[i];
          // Sadece kullanıcının kendi eklediği fotoğraf gösterilir, mekanın
          // stok fotoğrafı fallback olarak kullanılmaz (bkz. profile_page.dart).
          final imgUrl = review.photoUrl;
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
            child: imgUrl != null
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: context.colors.border),
                    errorWidget: (_, _, _) =>
                        _FriendReviewPlaceholderTile(review: review),
                  )
                : _FriendReviewPlaceholderTile(review: review),
          );
        }, childCount: reviews.length),
      ),
    );
  }
}

class _FriendReviewPlaceholderTile extends StatelessWidget {
  final VenueReviewModel review;
  const _FriendReviewPlaceholderTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: context.colors.primary, size: 22),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              review.venueName,
              style: TextStyle(fontSize: 9, color: context.colors.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
