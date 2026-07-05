import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
import 'package:meetit/features/personality/friend_compatibility_page.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/personality_analysis_page.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:meetit/core/utils/geo_utils.dart';
import 'package:meetit/core/widgets/network_status_banner.dart';

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
    // "Arkadaşların" listesi en çok "Buluş" butonuna basılan kişiden en aza
    // doğru sıralanır (sağdan sola en çok buluşulan en başta) — bu, en sık
    // buluştuğumuz arkadaşlara öncelik verir (kullanıcı isteği). connections
    // immutable kalsın diye kopya üzerinde sıralanıyor.
    final sortedConnections = [...connections]
      ..sort((a, b) => b.meetCount.compareTo(a.meetCount));
    final topReviewsAsync = ref.watch(topReviewsProvider);

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
          // Friends sayfasındaki aşağı çekip yenileme davranışıyla aynı:
          // arkadaş listesi + yakınınızdaki beğenilen mekanlar (yorumlar)
          // tazelenir. Min. 700ms bekleme, gerçek istek çok hızlı dönse
          // bile kullanıcıya "yenilendi" hissi versin diye (friends_page'le
          // aynı UX tutarlılığı).
          onRefresh: () async {
            final uid = ref.read(currentUserProvider)?.uid ?? '';
            await Future.wait([
              if (uid.isNotEmpty)
                ref.read(friendsProvider.notifier).loadAll(uid),
              Future(() => ref.invalidate(topReviewsProvider)),
              Future.delayed(const Duration(milliseconds: 700)),
            ]);
          },
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
                        ],
                      ),
                    ),
                    // Profil avatarı — dokununca Profil sekmesine geç
                    //
                    // NOT: Önceden burada ham CircleAvatar + NetworkImage
                    // kullanılıyordu — internet yokken (örn. Google hesabı
                    // fotoğrafı lh3.googleusercontent.com'dan çekilemediğinde)
                    // bu, yakalanmayan bir SocketException fırlatıyor ve bu da
                    // build/layout sırasında art arda "Null check operator
                    // used on a null value" / "RenderBox was not laid out"
                    // hatalarına, dolayısıyla ana sayfanın bozuk/boş
                    // görünmesine sebep oluyordu. CircularAvatar zaten
                    // CachedNetworkImage + errorWidget ile bu durumu güvenli
                    // şekilde harf-avatara düşürüyor — diğer tüm avatarlarda
                    // (arkadaş kartları, profil sayfası vb.) bu yüzden o
                    // kullanılıyordu, burada da aynısına geçirildi.
                    GestureDetector(
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).state = 3,
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
                        itemCount: sortedConnections.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _HomeFriendCard(friend: sortedConnections[i]),
                      ),
                    ),
            ),

            // ── Yakınınızdaki Beğenilen Mekanlar ────────────────────────────
            // (eski adıyla "Öne Çıkan Mekanlar ve Yorumlar" — artık
            // topReviewsProvider, kullanıcının konumuna 10km'den uzak
            // yorumları göstermiyor, bkz. review_notifier.dart)
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

            // ── Kişiliğini Yönet ────────────────────────────────────────────
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
                // NOT: Bu height olmadan, sınırsız (unbounded) bir dikey
                // alanda yatay kayan bir ListView, layout aşamasında
                // "RenderBox was not laid out" / NEEDS-PAINT hatası
                // fırlatıyordu — ana sayfanın bozuk/boş görünmesinin bir
                // diğer sebebi buydu.
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  // NOT: "Testi tekrar al" kartı buradan kaldırıldı — ana
                  // sayfada bu kadar göz önünde olmaması gerekiyordu
                  // (kullanıcı isteği). O eylem artık Ayarlar sayfasında
                  // (settings_page.dart -> settings.retake_quiz) tek giriş
                  // noktası olarak duruyor. Kalan 2 kart, kullanıcının
                  // isteğiyle yeniden sıralandı: önce arkadaşlarla uyum,
                  // sonra kişilik analizi.
                  itemCount: 2,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    switch (i) {
                      case 0:
                        return _FriendCompatActionCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendCompatibilityPage(),
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
                              builder: (_) => const PersonalityAnalysisPage(),
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
//
// connectionsProvider + currentUserProvider'dan en yüksek uyumlu arkadaşı
// hesaplar ve kartın alt yazısında gösterir ("Ali ile %87 uyum").
// Veri yoksa (profil yok / arkadaş yok) statik çeviri metnine düşer.

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
              // Buluş sayısını artır — ana sayfadaki "Arkadaşların" listesi
              // bu sayıma göre en çok buluşulan kişiye öncelik verir.
              ref.read(friendsProvider.notifier).incrementMeetCount(friend.uid);
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

class _ReviewCarouselCard extends ConsumerWidget {
  final VenueReviewModel review;
  const _ReviewCarouselCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOT: review.displayPhotoUrl, Firestore'da SAKLI veriye (eski yorumlarda
    // hâlâ kırık olabilen embedded-key URL veya hiç referans yok) dayanıyor.
    // VenueDetailPage ise placeId üzerinden Place Details'ten HER ZAMAN taze
    // bir foto çekiyor (venuePhotosProvider) — bu yüzden detay sayfasında foto
    // görünüyor ama ana sayfa carousel'inde görünmüyordu. Aynı taze-çekme
    // mekanizması burada da kullanılarak placeId'si olan TÜM yorumlar (eski
    // veya yeni, fark etmez) için çalışan bir foto garanti ediliyor.
    final currentUser = ref.watch(currentUserProvider);
    final fetchedPhotos = ref.watch(venuePhotosProvider(review.placeId));
    final freshPhotoUrl =
        fetchedPhotos.value?.isNotEmpty == true ? fetchedPhotos.value!.first : null;
    final displayUrl = freshPhotoUrl ?? review.displayPhotoUrl;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VenueDetailPage(
            placeId: review.placeId,
            venueName: review.venueName,
            venueAddress: review.venueAddress,
            venuePhotoUrl: displayUrl,
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
                          errorWidget: (_, _, _) => Container(
                            color: context.colors.primary.withOpacity(0.08),
                            child: Icon(
                              Iconsax.location,
                              color: context.colors.primary,
                              size: 28,
                            ),
                          ),
                        )
                      : Container(
                          color: context.colors.primary.withOpacity(0.08),
                          child: Icon(
                            Iconsax.location,
                            color: context.colors.primary,
                            size: 28,
                          ),
                        ),
                ],
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
                    const SizedBox(height: 3),
                    RatingBarIndicator(
                      rating: review.rating.toDouble(),
                      itemBuilder: (context, _) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB800),
                      ),
                      itemCount: 5,
                      itemSize: 12,
                      unratedColor: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 5),
                    // ── Mekan tipi + mesafe chip'leri ─────────────────────
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
