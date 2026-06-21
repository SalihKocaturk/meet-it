import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
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
  //
  // NOT: Firestore'da where('placeId', ...) + orderBy('createdAt', ...)
  // birlikte kullanılınca composite index gerekiyor (oluşturulmamışsa
  // FAILED_PRECONDITION hatası verip sorgu tamamen başarısız oluyor —
  // canlı loglarda da bu hata görüldü). Index oluşturmayı beklemek yerine
  // sorguyu sade where'e indirip sıralamayı client-side yapıyoruz; bu hem
  // index'siz çalışır hem de ek bir Firebase Console adımı gerektirmez.
  Future<List<VenueReviewModel>> loadReviewsForVenue(String placeId) async {
    try {
      final snap = await _db
          .collection('venue_reviews')
          .where('placeId', isEqualTo: placeId)
          .get();
      final reviews =
          snap.docs.map((d) => VenueReviewModel.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(reviews: reviews, isLoading: false);
      return reviews;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Yorumlar yüklenirken hata oluştu.');
      return [];
    }
  }

  /// Bir kullanıcının yazdığı tüm yorumları getirir (en yeniden eskiye).
  //
  // Aynı composite-index sorunu burada da var (authorUid + createdAt),
  // aynı çözüm uygulanıyor: client-side sıralama.
  Future<List<VenueReviewModel>> loadMyReviews(String uid) async {
    try {
      final snap = await _db
          .collection('venue_reviews')
          .where('authorUid', isEqualTo: uid)
          .get();
      final reviews =
          snap.docs.map((d) => VenueReviewModel.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      return [];
    }
  }

  /// Bir kullanıcı bir mekana zaten yorum yapmış mı? Spam'i önlemek için
  /// hem UI katmanında (buton gizleme) hem de burada (asıl yazma anında,
  /// UI state'i bayatlamış olsa bile) kontrol ediliyor.
  Future<bool> hasReviewed(String placeId, String authorUid) async {
    try {
      final snap = await _db
          .collection('venue_reviews')
          .where('placeId', isEqualTo: placeId)
          .where('authorUid', isEqualTo: authorUid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Yeni yorum ekler. Ziyaret edilmiş mekan kontrolü UI katmanında yapılır —
  /// burada Firestore'a yazma ve fotoğraf yükleme işinin yanında, bir
  /// kullanıcının aynı mekana birden fazla yorum yazmasını (spam) önlemek
  /// için son bir kontrol daha yapılır.
  ///
  /// Döndürülen değer: true ise yorum eklendi, false ise kullanıcı bu
  /// mekana zaten yorum yapmış olduğu için EKLENMEDİ (çağıran taraf bunu
  /// kullanıcıya bildirmeli).
  Future<bool> addReview({
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
      // Aynı kullanıcı + aynı mekan için zaten bir yorum varsa burada
      // engelle — UI butonu zaten gizliyor olmalı ama bu, state bayatsa
      // veya iki istek aynı anda gönderilirse son güvenlik ağı.
      if (await hasReviewed(venue.placeId, authorUid)) {
        return false;
      }

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

      final docRef = _db.collection('venue_reviews').doc();
      await docRef.set(review.toMap());

      // ── Kişilik profilini ziyaret edilen mekana göre evrilt ──────────────
      //
      // Statik quiz sonucu yerine, kullanıcı bir mekana yorum bıraktıkça
      // (= orayı ziyaret ettikçe) profil küçük adımlarla o mekanın Google
      // Places kategorilerine doğru kayar. Bu sayede profil zamanla
      // kullanıcının gerçek alışkanlıklarını yansıtır. Henüz quiz
      // tamamlanmamışsa (personalityProfile == null) dokunulmaz — evrim,
      // var olan bir temel profili güncellemek için var, sıfırdan
      // oluşturmak için değil.
      final currentUser = this.ref.read(authProvider).user;
      final currentProfile = currentUser?.personalityProfile;
      if (currentUser != null && currentProfile != null) {
        final evolved = currentProfile.evolvedWith(venue.types);
        if (evolved != currentProfile) {
          await this.ref
              .read(authProvider.notifier)
              .setPersonalityProfile(evolved);
        }
      }

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Yorum eklenirken hata oluştu.');
      return false;
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
//
// SADECE gerçek kullanıcı yorumları gösterilir — sahte/bot yorum YOK.
// Henüz hiç yorum yoksa liste boş döner; home_page.dart bu durumda
// 'home.no_reviews_hint' mesajını gösteriyor (carousel'i sahte içerikle
// doldurmak yerine dürüstçe "henüz yorum yok" demek tercih edildi).
//
// NOT: orderBy('rating',...).orderBy('createdAt',...) çift sıralaması
// Firestore'da composite index gerektiriyor; index oluşturulmadığı için
// sorgu FAILED_PRECONDITION ile tamamen başarısız oluyordu (canlı loglarda
// görüldü) — bu da eklenen yorumların ana sayfada hiç görünmemesinin asıl
// sebebiydi. Çözüm: index gerektirmeyen basit bir sorgu + client-side sort.
final topReviewsProvider = FutureProvider<List<VenueReviewModel>>((ref) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('venue_reviews')
        .limit(50)
        .get();
    final reviews = snap.docs
        .map((d) => VenueReviewModel.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) {
        final ratingCmp = b.rating.compareTo(a.rating);
        if (ratingCmp != 0) return ratingCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return reviews.take(15).toList();
  } catch (e) {
    return [];
  }
});
