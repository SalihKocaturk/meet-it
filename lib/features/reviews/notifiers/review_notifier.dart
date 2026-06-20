import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';

/// Belirli bir mekana ait yorumların durumu (yüklenen/yükleniyor/hata).
class ReviewState {
  final List<VenueReviewModel> reviews;
  final bool isLoading;
  final String? errorMessage;

  const ReviewState({
    this.reviews = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ReviewState copyWith({
    List<VenueReviewModel>? reviews,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ReviewState(
        reviews: reviews ?? this.reviews,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// `venue_reviews` koleksiyonu için CRUD + beğeni işlemleri.
///
/// FeedNotifier'dan farklı olarak burada genel bir stream dinlenmiyor —
/// yorumlar placeId/uid bazlı sorgularla istek üzerine (loadReviewsForVenue/
/// loadMyReviews) çekiliyor; ekranlar bu metodları FutureProvider.family
/// aracılığıyla tetikliyor (aşağıya bakınız).
class ReviewNotifier extends Notifier<ReviewState> {
  final _db = FirebaseFirestore.instance;

  @override
  ReviewState build() => const ReviewState();

  /// Belirli bir mekana ait yorumları getirir (en yeniden eskiye).
  Future<List<VenueReviewModel>> loadReviewsForVenue(String placeId) async {
    try {
      final snap = await _db
          .collection('venue_reviews')
          .where('placeId', isEqualTo: placeId)
          .orderBy('createdAt', descending: true)
          .get();
      final reviews =
          snap.docs.map((d) => VenueReviewModel.fromMap(d.id, d.data())).toList();
      state = state.copyWith(reviews: reviews, isLoading: false);
      return reviews;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Yorumlar yüklenirken hata oluştu.');
      return [];
    }
  }

  /// Bir kullanıcının yazdığı tüm yorumları getirir (en yeniden eskiye).
  Future<List<VenueReviewModel>> loadMyReviews(String uid) async {
    try {
      final snap = await _db
          .collection('venue_reviews')
          .where('authorUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => VenueReviewModel.fromMap(d.id, d.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Yeni yorum ekler. Ziyaret edilmiş mekan kontrolü UI katmanında yapılır —
  /// burada sadece Firestore'a yazma ve fotoğraf yükleme işi yapılır.
  Future<void> addReview({
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required PlaceResult venue,
    required int rating,
    String? comment,
    File? photo,
    // venue.photoUrl, photoReference üzerinden hesaplanır; çağıran taraf
    // (örn. VenueDetailPage) elinde zaten bilinen bir venuePhotoUrl varsa
    // bunu doğrudan iletip venue.photoUrl hesaplamasının ezilmesini sağlar.
    String? venuePhotoUrlOverride,
  }) async {
    try {
      final photoUrl = await _uploadPhoto(authorUid, photo);

      final review = VenueReviewModel(
        id: '',
        authorUid: authorUid,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        placeId: venue.placeId,
        venueName: venue.name,
        venueAddress: venue.vicinity,
        venuePhotoUrl: venuePhotoUrlOverride ?? venue.photoUrl,
        lat: venue.lat,
        lng: venue.lng,
        rating: rating,
        comment: comment,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
      );

      final ref = _db.collection('venue_reviews').doc();
      await ref.set(review.toMap());
    } catch (e) {
      state = state.copyWith(errorMessage: 'Yorum eklenirken hata oluştu.');
    }
  }

  Future<String?> _uploadPhoto(String uid, File? photo) async {
    if (photo == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'review_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(photo);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteReview(String id) async {
    try {
      await _db.collection('venue_reviews').doc(id).delete();
      state = state.copyWith(
        reviews: state.reviews.where((r) => r.id != id).toList(),
      );
    } catch (_) {}
  }

  Future<void> toggleLike(String id, String uid) async {
    final idx = state.reviews.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final review = state.reviews[idx];
    final liked = review.isLikedBy(uid);
    final newLikedBy = liked
        ? review.likedBy.where((u) => u != uid).toList()
        : [...review.likedBy, uid];

    // Optimistic update
    final updated = List<VenueReviewModel>.from(state.reviews);
    updated[idx] = review.copyWith(likedBy: newLikedBy);
    state = state.copyWith(reviews: updated);

    try {
      await _db.collection('venue_reviews').doc(id).update({
        'likedBy': liked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (_) {
      // Rollback
      final rollback = List<VenueReviewModel>.from(state.reviews);
      rollback[idx] = review;
      state = state.copyWith(reviews: rollback);
    }
  }
}

final reviewProvider = NotifierProvider<ReviewNotifier, ReviewState>(
  ReviewNotifier.new,
);

// ── Mekana göre yorumlar ──────────────────────────────────────────────────────
final venueReviewsProvider =
    FutureProvider.family<List<VenueReviewModel>, String>((ref, placeId) async {
  return ref.read(reviewProvider.notifier).loadReviewsForVenue(placeId);
});

// ── Kullanıcının kendi yorumları ──────────────────────────────────────────────
final myReviewsProvider =
    FutureProvider.family<List<VenueReviewModel>, String>((ref, uid) async {
  return ref.read(reviewProvider.notifier).loadMyReviews(uid);
});

// ── Ana sayfa carousel'i için en yüksek puanlı yorumlar ──────────────────────
final topReviewsProvider = FutureProvider<List<VenueReviewModel>>((ref) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('venue_reviews')
        .orderBy('rating', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(15)
        .get();
    return snap.docs
        .map((d) => VenueReviewModel.fromMap(d.id, d.data()))
        .toList();
  } catch (e) {
    return [];
  }
});
