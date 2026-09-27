import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
import 'package:meetit/features/profile/saved_page.dart';
import 'package:meetit/features/profile/widgets/venue_collection_view.dart';
import 'package:meetit/features/match/utils/venue_type_style.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/network_status_banner.dart';

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

    // Kaydedilenler (1) / Tarifi Alınanlar (2) sekmeleri için ortak veri.
    final isVenueTab = tabIndex != 0;
    final venueKind = tabIndex == 1
        ? VenueCollectionKind.saved
        : VenueCollectionKind.navigated;
    final tabVenues = tabIndex == 1 ? savedVenues : navigatedVenues;
    final filteredVenues = applyVenueFilter(
      tabVenues,
      ref.watch(venueCollectionFilterProvider(venueKind)),
    );
    // Harita görünümü: sekmede en az bir mekan varsa. Boş sekmede her
    // zaman liste düzenindeki "henüz mekan yok" mesajı gösterilir.
    final isMapMode = isVenueTab &&
        tabVenues.isNotEmpty &&
        ref.watch(venueCollectionMapModeProvider);
    // ÖNEMLİ: Ana sekmeler IndexedStack içinde — Profil sekmesi başka bir
    // sekme açıkken de arka planda canlı kalıyor. GoogleMap ise native bir
    // platform view olduğu için GİZLİYKEN bile ekranın o bölgesindeki
    // dokunuşları yutabiliyor (örn. Ana Sayfa'daki kayan mekan carousel'i
    // durdurulamıyor / tıklanamıyordu). Bu yüzden harita SADECE Profil
    // sekmesi gerçekten ekrandayken oluşturuluyor.
    final isProfileVisible = ref.watch(mainTabIndexProvider) == 3;

    final header = _ProfileHeader(
      user: user,
      postsCount: myReviews.length,
      friendsCount: connections.length,
      totalLikes: totalLikes,
    );
    void onTabChanged(int i) =>
        ref.read(profileTabProvider.notifier).state = i;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const NetworkStatusBanner(),
            Expanded(
              child: isMapMode
                  // ── Harita görünümü ────────────────────────────────────
                  // NestedScrollView içinde harita hem dikey sürükleme
                  // çakışması yaşar hem de alt kısmı (kart + filtreler)
                  // başlık kaydırılana kadar ekran dışında kalırdı; bu
                  // yüzden harita modunda sabit bir Column düzeni var.
                  ? Column(
                      children: [
                        header,
                        _ProfileTabs(
                          tabIndex: tabIndex,
                          onTabChanged: onTabChanged,
                        ),
                        Expanded(
                          child: isProfileVisible
                              ? VenueCollectionMapView(
                                  key: ValueKey(venueKind),
                                  kind: venueKind,
                                  venues: tabVenues,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        NestedScrollView(
                          headerSliverBuilder: (context, _) => [
                            SliverToBoxAdapter(child: header),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabBarDelegate(
                                tabIndex: tabIndex,
                                onTabChanged: onTabChanged,
                              ),
                            ),
                          ],
                          body: switch (tabIndex) {
                            0 => _ReviewsGrid(reviews: myReviews),
                            1 => _SavedVenuesList(
                              venues: filteredVenues,
                              isEmpty: savedVenues.isEmpty,
                            ),
                            _ => _NavigatedVenuesList(
                              venues: filteredVenues,
                              isEmpty: navigatedVenues.isEmpty,
                            ),
                          },
                        ),
                        // ── Alt: mekan tipi filtreleri ─────────────────
                        if (isVenueTab && tabVenues.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.only(top: 14, bottom: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    context.colors.scaffold
                                        .withValues(alpha: 0),
                                    context.colors.scaffold
                                        .withValues(alpha: 0.95),
                                  ],
                                ),
                              ),
                              child: VenueTypeFilterBar(
                                kind: venueKind,
                                venues: tabVenues,
                              ),
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
                  Iconsax.menu,
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
              // Avatar — basınca profil düzenleme
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
                          Iconsax.edit_2,
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
    return _ProfileTabs(tabIndex: tabIndex, onTabChanged: onTabChanged);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabIndex != tabIndex;
}

/// Profil sekme satırı — hem NestedScrollView'daki sabit başlıkta hem de
/// harita görünümünün Column düzeninde kullanılır.
class _ProfileTabs extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const _ProfileTabs({required this.tabIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _Tab(
            icon: Iconsax.grid_1,
            isSelected: tabIndex == 0,
            onTap: () => onTabChanged(0),
          ),
          _Tab(
            icon: Iconsax.save_2,
            isSelected: tabIndex == 1,
            onTap: () => onTabChanged(1),
          ),
          _Tab(
            icon: Iconsax.send_2,
            isSelected: tabIndex == 2,
            onTap: () => onTabChanged(2),
          ),
        ],
      ),
    );
  }
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
                Iconsax.gallery,
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
                    Iconsax.note_remove,
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
          Icon(Iconsax.location, color: context.colors.primary, size: 22),
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
  /// Tip filtresi UYGULANMIŞ liste.
  final List<PlaceResult> venues;

  /// Filtreden bağımsız olarak sekmede hiç kayıt yok mu.
  final bool isEmpty;

  const _SavedVenuesList({required this.venues, required this.isEmpty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEmpty) {
      return _EmptyTab(
        icon: Iconsax.save_2,
        message: 'profile.no_saved_venues'.tr(),
      );
    }

    return Column(
      children: [
        VenueCollectionToolbar(count: venues.length),
        Expanded(
          child: ListView.separated(
            // Alttaki filtre butonlarının arkasında son kart kalmasın diye
            // pay — butonlar birden fazla satıra geçebildiği için ölçülen
            // gerçek yüksekliğe göre.
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              ref.watch(venueFilterBarHeightProvider) + 28,
            ),
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
                    child: Icon(Iconsax.save_add,
                        color: context.colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => launchVenueDirections(venues[i]),
                    child: Icon(Iconsax.routing,
                        color: context.colors.primary, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tarifi Alınan Mekanlar ────────────────────────────────────────────────────

class _NavigatedVenuesList extends ConsumerWidget {
  /// Tip filtresi UYGULANMIŞ liste.
  final List<PlaceResult> venues;

  /// Filtreden bağımsız olarak sekmede hiç kayıt yok mu.
  final bool isEmpty;

  const _NavigatedVenuesList({required this.venues, required this.isEmpty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEmpty) {
      return _EmptyTab(
        icon: Iconsax.send_2,
        message: 'profile.no_navigated_venues'.tr(),
      );
    }

    return Column(
      children: [
        VenueCollectionToolbar(count: venues.length),
        Expanded(
          child: ListView.separated(
            // Alttaki filtre butonlarının arkasında son kart kalmasın diye
            // pay — butonlar birden fazla satıra geçebildiği için ölçülen
            // gerçek yüksekliğe göre.
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              ref.watch(venueFilterBarHeightProvider) + 28,
            ),
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final place = venues[i];
              return _VenueTile(
                place: place,
                // Tarifi alınan mekanlarda Google yıldızı gösterilmiyor.
                showRating: false,
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
                            Icon(Iconsax.message_add_1,
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
                      onTap: () => launchVenueDirections(place),
                      child: Icon(Iconsax.routing,
                          color: context.colors.primary, size: 22),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Ortak Venue Tile ──────────────────────────────────────────────────────────

class _VenueTile extends StatelessWidget {
  final PlaceResult place;
  final Widget trailing;

  /// Google yıldız puanı gösterilsin mi (Tarifi Alınanlar'da gizli).
  final bool showRating;

  const _VenueTile({
    required this.place,
    required this.trailing,
    this.showRating = true,
  });

  @override
  Widget build(BuildContext context) {
    // Karta dokununca mekan detay sayfası açılır. Sağdaki aksiyon
    // butonlarının (kaydet / yorum / tarif) kendi GestureDetector'ları
    // olduğu için onlara dokunmak detay sayfasını AÇMAZ.
    return Material(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openVenueDetail(context, place),
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          // Mekan fotoğrafı — kayıtlı foto yoksa, yüklenirken veya
          // yüklenemezse tipin ikonlu kutusu (restoran → çatal-bıçak vb.).
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: place.photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: place.photoUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _PlaceholderBox(place),
                    errorWidget: (_, _, _) => _PlaceholderBox(place),
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
                    Flexible(
                      child: VenueTypeBadge(style: VenueTypeStyle.of(place)),
                    ),
                    if (showRating && place.rating != null) ...[
                      const SizedBox(width: 6),
                      RatingBarIndicator(
                        rating: place.rating!,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB800),
                        ),
                        itemCount: 5,
                        itemSize: 10,
                        unratedColor: Colors.grey.withOpacity(0.3),
                      ),
                      const SizedBox(width: 4),
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
        ),
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  final PlaceResult place;
  const _PlaceholderBox(this.place);

  @override
  Widget build(BuildContext context) {
    // Fotoğraf yoksa tipin ikonu (kafe → kahve fincanı vb.)
    return VenueTypeIconBox(style: VenueTypeStyle.of(place), size: 52);
  }
}

// ── Boş tab ────────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colors.hint),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
