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
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:quickalert/quickalert.dart';

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

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: venuePhotoUrl != null ? 260 : 0,
            pinned: true,
            backgroundColor: context.colors.card,
            foregroundColor: venuePhotoUrl != null
                ? Colors.white
                : context.colors.textPrimary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: venuePhotoUrl != null
                      ? Colors.black.withOpacity(0.35)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: venuePhotoUrl != null
                      ? Colors.white
                      : context.colors.textPrimary,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: venuePhotoUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: venuePhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: context.colors.border),
                      errorWidget: (_, _, _) => Container(
                        color: context.colors.primary.withOpacity(0.1),
                        child: Icon(Icons.location_on,
                            size: 48, color: context.colors.primary),
                      ),
                    ),
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
              child: hasVisited
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
                            // photoReference bilinmiyor (sadece hazır URL var);
                            // gerçek fotoğrafı venuePhotoUrlOverride ile veriyoruz.
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
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: context.colors.hint, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'venue_detail.must_visit_first'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yorum Satırı ──────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'review.select_rating_warning'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    await ref.read(reviewProvider.notifier).addReview(
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

    // İlgili providerları geçersiz kıl, yeni yorum hemen görünsün.
    ref.invalidate(venueReviewsProvider(widget.venue.placeId));
    ref.invalidate(myReviewsProvider(user.uid));
    ref.invalidate(topReviewsProvider);

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
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
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: context.colors.hint,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'review.submit'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
