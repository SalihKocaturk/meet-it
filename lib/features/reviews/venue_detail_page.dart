import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/services/places_service.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/core/widgets/app_alert.dart';

/// Bir mekanın placeId'sinden TÜM Google fotoğraflarını çeker.
///
/// VenueDetailPage hangi yoldan açılmış olursa olsun (arama sonucu, kendi/
/// arkadaş profili yorumu, kaydedilenler, ana sayfa carousel'i...) elde
/// genelde sadece TEK bir venuePhotoUrl bulunuyor — çünkü o veriler
/// Firestore'daki yorum dokümanında veya basitleştirilmiş PlaceResult'ta
/// tek foto olarak saklı. Galerinin gerçekten "galeri" olabilmesi için
/// placeId üzerinden Place Details ile ek fotoğraflar burada çekiliyor.
final venuePhotosProvider =
    FutureProvider.family<List<String>, String>((ref, placeId) {
  return PlacesService.fetchPhotoUrls(placeId);
});

/// Tek bir mekanın detay sayfası: fotoğraf + Google puanı + yorum listesi +
/// (ziyaret edilmişse) yorum ekleme aksiyonu.
///
/// Arama sonuçlarından (PlaceResult ile) veya carousel/yorum kartından
/// (sadece placeId + ad + adres + fotoğraf + opsiyonel puan bilgisiyle)
/// açılabilir — bu yüzden PlaceResult zorunlu değil, gerekli alanlar
/// doğrudan named parametre olarak da verilebilir.
class VenueDetailPage extends ConsumerWidget {
  final String placeId;
  final String venueName;
  final String? venueAddress;
  final String? venuePhotoUrl;
  // Mekanın TÜM resmi Google fotoğrafları (varsa). Tek `venuePhotoUrl`
  // (geriye dönük uyum için hâlâ tutuluyor) yerine bu doluysa galeri bunu
  // kullanır — bu sayede kullanıcı yorum fotoğrafı olmasa da mekanın
  // gerçek galerisi dönebiliyor.
  final List<String> venuePhotoUrls;
  final double? googleRating;
  final int? googleRatingCount;
  final double? lat;
  final double? lng;

  const VenueDetailPage({
    super.key,
    required this.placeId,
    required this.venueName,
    this.venueAddress,
    this.venuePhotoUrl,
    this.venuePhotoUrls = const [],
    this.googleRating,
    this.googleRatingCount,
    this.lat,
    this.lng,
  });

  /// PlaceResult'tan kolayca oluşturmak için yardımcı kurucu.
  factory VenueDetailPage.fromPlace(PlaceResult place, {Key? key}) {
    return VenueDetailPage(
      key: key,
      placeId: place.placeId,
      venueName: place.name,
      venueAddress: place.vicinity,
      venuePhotoUrl: place.photoUrl,
      venuePhotoUrls: place.photoUrls,
      googleRating: place.rating,
      googleRatingCount: place.userRatingsTotal,
      lat: place.lat,
      lng: place.lng,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(venueReviewsProvider(placeId));
    final navigatedVenues = ref.watch(navigatedVenuesProvider);
    final hasVisited = navigatedVenues.any((v) => v.placeId == placeId);
    // Spam'i önlemek için bir kullanıcı bir mekana sadece BİR yorum
    // yapabilir — burada kullanıcının bu mekana zaten yorumu var mı
    // kontrol ediliyor (asıl yazma anındaki son kontrol review_notifier'da).
    final currentUser = ref.watch(currentUserProvider);
    final reviewsForCheck = reviewsAsync.value ?? const <VenueReviewModel>[];
    final hasOwnReview = currentUser != null &&
        reviewsForCheck.any((r) => r.authorUid == currentUser.uid);
    // placeId üzerinden Place Details'ten çekilen TÜM resmi fotoğraflar —
    // sayfa hangi yoldan açılmış olursa olsun (sadece tek venuePhotoUrl
    // elde olsa bile) çalışır, asıl çoklu-foto kaynağı bu.
    final fetchedPhotosAsync = ref.watch(venuePhotosProvider(placeId));
    final fetchedPhotos = fetchedPhotosAsync.value ?? const <String>[];

    // Mekan hakkındaki tüm fotoğraflar: Place Details'ten çekilenler +
    // (varsa) elimizdeki resmi mekan fotoğraf(lar)ı + kullanıcıların
    // yorumlarına eklediği fotoğraflar — tek statik foto yerine galeri
    // olarak gösterilir, tek foto amatör kaçtığı için birden fazlaysa
    // dönen bir carousel'e dönüştürüldü.
    final reviews = reviewsAsync.value ?? const <VenueReviewModel>[];
    final galleryPhotos = <String>{
      ...fetchedPhotos,
      if (venuePhotoUrls.isNotEmpty)
        ...venuePhotoUrls
      else if (venuePhotoUrl != null)
        venuePhotoUrl!,
      ...reviews.map((r) => r.photoUrl).whereType<String>(),
    }.toList();
    final hasPhotos = galleryPhotos.isNotEmpty;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasPhotos ? 260 : 0,
            pinned: true,
            backgroundColor: context.colors.card,
            foregroundColor:
                hasPhotos ? Colors.white : context.colors.textPrimary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasPhotos
                      ? Colors.black.withOpacity(0.35)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: hasPhotos ? Colors.white : context.colors.textPrimary,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: hasPhotos
                ? FlexibleSpaceBar(
                    background: _VenuePhotoGallery(photos: galleryPhotos),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venueName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (venueAddress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      venueAddress!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (googleRating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 18, color: Color(0xFFFFB800)),
                        const SizedBox(width: 4),
                        Text(
                          googleRating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (googleRatingCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            'venue_detail.rating_count'
                                .tr(namedArgs: {'count': '$googleRatingCount'}),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'venue_detail.reviews_section'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'venue_detail.no_reviews'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ReviewTile(review: reviews[i]),
                    childCount: reviews.length,
                  ),
                ),
              );
            },
            loading: () => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.colors.primary,
                  ),
                ),
              ),
            ),
            error: (_, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'venue_detail.no_reviews'.tr(),
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              // Üç durum: (1) zaten yorum yapılmış — spam'i önlemek için bir
              // kullanıcı bir mekana sadece BİR yorum yapabilir, buton yerine
              // bilgi notu gösterilir; (2) ziyaret edilmiş ve henüz yorum
              // yapılmamış — Yorum Ekle butonu; (3) hiç ziyaret edilmemiş —
              // "önce ziyaret et" notu.
              child: hasOwnReview
                  ? _InfoNote(
                      icon: Icons.check_circle_outline,
                      text: 'venue_detail.already_reviewed'.tr(),
                    )
                  : hasVisited
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => showAddReviewSheet(
                              context,
                              ref,
                              PlaceResult(
                                placeId: placeId,
                                name: venueName,
                                vicinity: venueAddress,
                                // photoReference bilinmiyor (sadece hazır URL
                                // var); gerçek fotoğrafı venuePhotoUrlOverride
                                // ile veriyoruz.
                                photoReference: null,
                                rating: googleRating,
                                userRatingsTotal: googleRatingCount,
                                lat: lat ?? 0,
                                lng: lng ?? 0,
                              ),
                              overridePhotoUrl: venuePhotoUrl,
                            ),
                            icon: const Icon(Icons.add_comment_outlined,
                                color: Colors.white),
                            label: Text(
                              'venue_detail.add_review'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        )
                      : _InfoNote(
                          icon: Icons.info_outline,
                          text: 'venue_detail.must_visit_first'.tr(),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bilgi Notu (ziyaret/yorum durum bildirimi) ────────────────────────────────
//
// "Önce ziyaret et" ve "zaten yorum yaptın" notları birebir aynı görünümü
// paylaşıyor; tekrarı önlemek için ortak widget'a çıkarıldı.
class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.hint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mekan Fotoğraf Galerisi ───────────────────────────────────────────────────
//
// Tek statik foto yerine: mekanın resmi fotoğrafı + kullanıcıların yorumlara
// eklediği fotoğraflardan oluşan, otomatik dönen (ve elle kaydırılabilen)
// bir carousel. Tek foto varsa sade şekilde gösterilir, dönmez.
class _VenuePhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _VenuePhotoGallery({required this.photos});

  @override
  State<_VenuePhotoGallery> createState() => _VenuePhotoGalleryState();
}

class _VenuePhotoGalleryState extends State<_VenuePhotoGallery>
    with SingleTickerProviderStateMixin {
  late final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  // Tek foto kaldığında (kullanıcı yorum fotoğrafı yoksa ve mekanın
  // Google'da sadece 1 resmi varsa) sabit/durağan bir kare hoş durmuyordu.
  // Bu yüzden tek fotoda da yavaş, sürekli bir "Ken Burns" zoom efekti
  // uygulanıyor — hareket varmış gibi hissettirip statik görünümü kırıyor.
  late final AnimationController _zoomController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);
  late final Animation<double> _zoom = Tween<double>(begin: 1.0, end: 1.12)
      .animate(CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (widget.photos.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        _page = (_page + 1) % widget.photos.length;
        _controller.animateToPage(
          _page,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: _zoom,
            builder: (context, child) => Transform.scale(
              scale: _zoom.value,
              child: child,
            ),
            child: CachedNetworkImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: context.colors.border),
              errorWidget: (_, _, _) => Container(
                color: context.colors.primary.withOpacity(0.1),
                child: Icon(Icons.location_on,
                    size: 48, color: context.colors.primary),
              ),
            ),
          ),
        ),
        // Alt kenara hafif koyu gradyan — fotoğrafın altı çok parlak/düz
        // olursa nokta göstergeleri ve geri butonu sırtı seçilmiyordu, bu
        // aynı zamanda görsele bir derinlik/"profesyonel" his katıyor.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 90,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_page + 1}/${widget.photos.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Yorum Satırı ──────────────────────────────────────────────────────────────

class _ReviewTile extends ConsumerWidget {
  final VenueReviewModel review;
  const _ReviewTile({required this.review});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'time.just_now'.tr();
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${'time.min_ago'.tr()}';
    if (diff.inHours < 24) return '${diff.inHours} ${'time.hr_ago'.tr()}';
    if (diff.inDays < 7) return '${diff.inDays} ${'time.days_ago'.tr()}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _toggleLike(WidgetRef ref, String uid) async {
    await ref.read(reviewProvider.notifier).toggleLike(review.id, uid);
    ref.invalidate(venueReviewsProvider(review.placeId));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String uid) {
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
        ref.invalidate(myReviewsProvider(uid));
        ref.invalidate(topReviewsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwn = user != null && user.uid == review.authorUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircularAvatar(
                name: review.authorName,
                photoUrl: review.authorPhotoUrl,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      _timeAgo(review.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.hint,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: i < review.rating
                        ? const Color(0xFFFFB800)
                        : context.colors.hint,
                  ),
                ),
              ),
              if (isOwn) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _confirmDelete(context, ref, user!.uid),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: context.colors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (review.photoUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: review.photoUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: user == null ? null : () => _toggleLike(ref, user.uid),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user != null && review.isLikedBy(user.uid)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 16,
                  color: user != null && review.isLikedBy(user.uid)
                      ? context.colors.error
                      : context.colors.hint,
                ),
                const SizedBox(width: 4),
                Text(
                  '${review.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yorum Ekleme Bottom Sheet ─────────────────────────────────────────────────
//
// profile_page.dart'tan da (Tarifi Alınan Mekanlar > Yorum Ekle) doğrudan
// çağrılabilmesi için top-level fonksiyon olarak dışa açıldı.
Future<void> showAddReviewSheet(
  BuildContext context,
  WidgetRef ref,
  PlaceResult venue, {
  String? overridePhotoUrl,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddReviewSheet(venue: venue, overridePhotoUrl: overridePhotoUrl),
  );
}

class _AddReviewSheet extends ConsumerStatefulWidget {
  final PlaceResult venue;
  final String? overridePhotoUrl;

  const _AddReviewSheet({required this.venue, this.overridePhotoUrl});

  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  File? _photo;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showAppAlert(
        context: context,
        type: AppAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'review.select_rating_warning'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final added = await ref.read(reviewProvider.notifier).addReview(
          authorUid: user.uid,
          authorName: user.name,
          authorPhotoUrl: user.photoUrl,
          venue: widget.venue,
          rating: _rating,
          comment: _commentCtrl.text.trim().isNotEmpty
              ? _commentCtrl.text.trim()
              : null,
          photo: _photo,
          venuePhotoUrlOverride: widget.overridePhotoUrl,
        );

    // İlgili providerları geçersiz kıl, yeni yorum (eklendiyse) hemen görünsün.
    ref.invalidate(venueReviewsProvider(widget.venue.placeId));
    ref.invalidate(myReviewsProvider(user.uid));
    ref.invalidate(topReviewsProvider);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    // Spam koruması: sayfa açıkken (örn. iki sekmeli/iki istek senaryosu)
    // kullanıcının bu mekana zaten bir yorumu oluşmuş olabilir — bu durumda
    // "eklendi" yerine "zaten yorum yaptın" bilgisi gösterilir.
    if (!added) {
      showAppAlert(
        context: context,
        type: AppAlertType.warning,
        title: 'review.already_reviewed_title'.tr(),
        text: 'review.already_reviewed_desc'.tr(),
        confirmBtnColor: context.colors.primary,
        onConfirmBtnTap: () {
          Navigator.pop(context); // alert kapat
          Navigator.pop(context); // sheet kapat
        },
      );
      return;
    }

    showAppAlert(
      context: context,
      type: AppAlertType.success,
      title: 'review.review_added'.tr(),
      text: 'review.review_added_desc'.tr(),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.pop(context); // alert kapat
        Navigator.pop(context); // sheet kapat
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açıldığında viewInsets.bottom artıyor; bottom sheet'in
    // mainAxisSize.min Column'u bu durumda sığmayabiliyor (RenderFlex
    // overflow). Çözüm: içeriği SingleChildScrollView ile sarmalayıp
    // klavye açıkken aşağı kaydırılabilir hale getirmek — bu sayede
    // sabit yükseklikli yıldızlar/foto kutusu/buton hiçbir zaman taşmıyor.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'review.add_title'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.venue.name,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'review.rating_label'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _rating = _rating == star ? 0 : star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        _rating >= star
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: _rating >= star
                            ? const Color(0xFFFFB800)
                            : context.colors.hint,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'review.comment_label'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                maxLength: 280,
                decoration: InputDecoration(
                  hintText: 'review.comment_hint'.tr(),
                  hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
                  filled: true,
                  fillColor: context.colors.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'review.add_photo'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhoto,
                child: _photo != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _photo!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
   