import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/main/main_page.dart' show mainTabIndexProvider;
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/profile/saved_page.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/network_status_banner.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kaydedilen/tarif alınan mekanlar listesinde "tekrar tarif al" butonuna
/// basılınca Google Maps'i mekanın konumuyla açar.
Future<void> _reopenDirections(PlaceResult place) async {
  final uri = Uri.parse(place.googleMapsUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// Profil tab index
final profileTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final myReviewsAsync = ref.watch(myReviewsProvider(user?.uid ?? ''));
    final tabIndex = ref.watch(profileTabProvider);
    final connections = ref.watch(connectionsProvider);

    // Kendi yorumları — PostModel/feedProvider yerine VenueReviewModel/myReviewsProvider
    final myReviews = myReviewsAsync.value ?? const <VenueReviewModel>[];

    // Toplam alınan beğeni
    final totalLikes = myReviews.fold(0, (sum, r) => sum + r.likeCount);

    final savedVenues     = ref.watch(savedVenuesProvider);
    final navigatedVenues = ref.watch(navigatedVenuesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const NetworkStatusBanner(),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      user: user,
                      postsCount: myReviews.length,
                      friendsCount: connections.length,
                      totalLikes: totalLikes,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      tabIndex: tabIndex,
                      onTabChanged: (i) =>
                          ref.read(profileTabProvider.notifier).state = i,
                    ),
                  ),
                ],
                body: switch (tabIndex) {
                  0 => _ReviewsGrid(reviews: myReviews),
                  1 => _SavedVenuesList(venues: savedVenues),
                  _ => _NavigatedVenuesList(venues: navigatedVenues),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final UserModel? user;
  final int postsCount;
  final int friendsCount;
  final int totalLikes;

  const _ProfileHeader({
    required this.user,
    required this.postsCount,
    required this.friendsCount,
    required this.totalLikes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          // Üst bar: boş + Ayarlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user?.name ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: context.colors.textPrimary,
                  size: 26,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileMenuPage()),
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Avatar + istatistikler
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => context.push(AppRoutes.editProfile),
                child: Stack(
                  children: [
                    user?.photoUrl != null
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(user!.photoUrl!),
                          )
                        : CircularAvatar(name: user?.name ?? '', radius: 40),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.card, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // İstatistikler
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: 'profile.stat_posts'.tr(), value: postsCount),
                    _Stat(
                      label: 'profile.stat_friends'.tr(),
                      value: friendsCount,
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).state = 2,
                    ),
                    _Stat(label: 'profile.stat_likes'.tr(), value: totalLikes),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // NOT: Profil sekmesinde konum ve kişilik (dominant tip) satırı
          // kaldırıldı — kullanıcı isteği: bu bilgilerin profil tab'ında
          // gösterilmesi şart değil. Konum bilgisi zaten Edit Profile
          // sayfasında harita üzerinden seçilip saklanıyor; kişilik tipi
          // de "Kişilik Analizim" ve "Arkadaşlarla Uyum" kartlarından
          // görülebiliyor — burada tekrar göstermeye gerek yok.
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _Stat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
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

    if (onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const _TabBarDelegate({required this.tabIndex, required this.onTabChanged});

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
    return Row(
      children: [
        _Tab(
          icon: Icons.grid_on,
          isSelected: tabIndex == 0,
          onTap: () => onTabChanged(0),
        ),
        _Tab(
          icon: Icons.bookmark_border_outlined,
          isSelected: tabIndex == 1,
          onTap: () => onTabChanged(1),
        ),
        _Tab(
          icon: Icons.navigation_outlined,
          isSelected: tabIndex == 2,
          onTap: () => onTabChanged(2),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabIndex != tabIndex;
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? context.colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? context.colors.primary : context.colors.hint,
          ),
        ),
      ),
    );
  }
}

// ── Yorumlar Grid ────────────────────────────────────────────────────────────
//
// Eski _PostsGrid'in yerine geçti: feedProvider/PostModel yerine
// myReviewsProvider/VenueReviewModel kullanıyor. Görsel stil aynı kaldı.

class _ReviewsGrid extends ConsumerWidget {
  final List<VenueReviewModel> reviews;

  const _ReviewsGrid({required this.reviews});

  void _confirmDelete(BuildContext context, WidgetRef ref, VenueReviewModel review) {
    final uid = ref.read(currentUserProvider)?.uid;
    showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'review.delete_review'.tr(),
      text: 'review.delete_review_confirm'.tr(),
      confirmBtnText: 'common.delete'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
      confirmBtnColor: context.colors.error,
      onConfirmBtnTap: () async {
        Navigator.pop(context);
        await ref.read(reviewProvider.notifier).deleteReview(review.id);
        ref.invalidate(venueReviewsProvider(review.placeId));
        if (uid != null) ref.invalidate(myReviewsProvider(uid));
        ref.invalidate(topReviewsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reviews.isEmpty) {
      return Container(
        color: context.colors.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: context.colors.hint,
              ),
              SizedBox(height: 12),
              Text(
                'profile.no_reviews'.tr(),
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: reviews.length,
      itemBuilder: (context, i) {
        final review = reviews[i];
        // Sadece kullanıcının kendi eklediği fotoğraf gösterilir — mekanın
        // genel/stok fotoğrafı fallback olarak KULLANILMAZ. Aksi halde aynı
        // mekana birden fazla yorum yapıldığında profilde aynı fotoğraf
        // tekrar tekrar görünüyordu (ki bu fotoğraf kullanıcıya ait değildi).
        final imgUrl = review.photoUrl;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              // Hücreye dokununca bu mekanın tüm yorumlarını gösteren
              // VenueDetailPage açılır (tek bir yorum değil).
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VenueDetailPage(
                    placeId: review.placeId,
                    venueName: review.venueName,
                    venueAddress: review.venueAddress,
                    venuePhotoUrl: review.displayPhotoUrl,
                    lat: review.lat,
                    lng: review.lng,
                  ),
                ),
              ),
              onLongPress: () => _confirmDelete(context, ref, review),
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: context.colors.border),
                      errorWidget: (_, _, _) => _ReviewPlaceholderTile(review: review),
                    )
                  : _ReviewPlaceholderTile(review: review),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _confirmDelete(context, ref, review),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewPlaceholderTile extends StatelessWidget {
  final VenueReviewModel review;
  const _ReviewPlaceholderTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: context.colors.primary, size: 22),
          SizedBox(height: 4),
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

// ── Kaydedilen Mekanlar ───────────────────────────────────────────────────────

class _SavedVenuesList extends ConsumerWidget {
  final List<PlaceResult> venues;

  const _SavedVenuesList({required this.venues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (venues.isEmpty) {
      return _EmptyTab(
        icon: Icons.bookmark_border_outlined,
        message: 'profile.no_saved_venues'.tr(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _VenueTile(
        place: venues[i],
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () =>
                  ref.read(savedVenuesProvider.notifier).toggle(venues[i]),
              child: Icon(Icons.bookmark,
                  color: context.colors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _reopenDirections(venues[i]),
              child: Icon(Icons.directions_outlined,
                  color: context.colors.primary, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarifi Alınan Mekanlar ────────────────────────────────────────────────────

class _NavigatedVenuesList extends ConsumerWidget {
  final List<PlaceResult> venues;

  const _NavigatedVenuesList({required this.venues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (venues.isEmpty) {
      return _EmptyTab(
        icon: Icons.navigation_outlined,
        message: 'profile.no_navigated_venues'.tr(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final place = venues[i];
        return _VenueTile(
          place: place,
          // Eski "Feedde Paylaş" (CreatePostPage) butonu yerine "Yorum Ekle" —
          // bu mekan zaten navigatedVenuesProvider'da olduğu için doğrudan
          // _AddReviewSheet açılabiliyor. Ayrıca insanlar bu mekana zaten bir
          // kez tarif aldığı için tekrar tarif alabilmesi için bir buton da
          // eklendi.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => showAddReviewSheet(context, ref, place),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_comment_outlined,
                          size: 13, color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'profile.add_review'.tr(),
                        style: TextStyle(
                            fontSize: 12,
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _reopenDirections(place),
                child: Icon(Icons.directions_outlined,
                    color: context.colors.primary, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Ortak Venue Tile ──────────────────────────────────────────────────────────

class _VenueTile extends StatelessWidget {
  final PlaceResult place;
  final Widget trailing;

  const _VenueTile({required this.place, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          // Küçük fotoğraf veya emoji
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: place.photoUrl != null
                ? Image.network(
                    place.photoUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _PlaceholderBox(place),
                  )
                : _PlaceholderBox(place),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place.vicinity != null)
                  Text(
                    place.vicinity!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        place.primaryTypeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (place.rating != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFFFB800)),
                      const SizedBox(width: 2),
                      Text(
                        place.ratingText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  final PlaceResult place;
  const _PlaceholderBox(this.place);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          place.primaryTypeLabel.isNotEmpty
              ? place.primaryTypeLabel[0]
              : '📍',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
    