import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_config.dart';

/// Bir mekanın Google puanı (yıldız) ve değerlendirme sayısı.
typedef VenueGoogleRating = ({double? rating, int? count});

/// Mekanın GOOGLE puanını, elimizde PlaceResult olmayan yerlerde (örn. ana
/// sayfadaki yorum kartları, yorumdan açılan detay sayfası) bulmak için.
///
/// 💸 MALİYET: fotoğraf önbelleğiyle (VenuePhotoCacheService) AYNI mantık —
/// önce Firestore'daki paylaşımlı `venuePhotoCache/{placeId}` dokümanına
/// bakılır (ayrı bir koleksiyon açılmadı ki firestore.rules değişmesin;
/// alanlar `merge: true` ile ekleniyor, foto `urls` alanına dokunulmuyor).
/// Önbellekte yoksa ya da [_ttl]'den eskiyse Place Details (New)'e SADECE
/// `rating,userRatingCount` alanlarıyla BİR KEZ gidilir ve sonuç tüm
/// kullanıcılar için önbelleğe yazılır.
///
/// Arama sonucundan gelen PlaceResult'larda puan zaten var — oralarda bu
/// servis HİÇ çağrılmaz. Yeni yorumlar da puanı kendi dokümanında taşır
/// (bkz. VenueReviewModel.googleRating), yani bu servis esasen eski
/// yorumlar içindir.
class VenueRatingService {
  VenueRatingService._();

  static const _collection = 'venuePhotoCache';
  static const _ttl = Duration(days: 30);

  static final _firestore = FirebaseFirestore.instance;

  /// Elde zaten bilinen bir Google puanını (örn. yorum eklenirken
  /// PlaceResult'tan) ücretsiz olarak önbelleğe yazar.
  static Future<void> remember(
    String placeId, {
    required double? rating,
    int? count,
  }) async {
    if (placeId.isEmpty || rating == null) return;
    try {
      await _firestore.collection(_collection).doc(placeId).set({
        'placeId': placeId,
        'googleRating': rating,
        if (count != null) 'googleRatingCount': count,
        'ratingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Önce önbellek, yoksa Google. Hiçbiri olmazsa (rating: null).
  static Future<VenueGoogleRating> fetch(String placeId) async {
    if (placeId.isEmpty) return (rating: null, count: null);

    // 1) Paylaşımlı Firestore önbelleği
    try {
      final snap = await _firestore.collection(_collection).doc(placeId).get();
      final data = snap.data();
      final cachedRating = (data?['googleRating'] as num?)?.toDouble();
      final updatedAt = (data?['ratingUpdatedAt'] as Timestamp?)?.toDate();
      final fresh = updatedAt == null ||
          DateTime.now().difference(updatedAt) < _ttl;
      if (cachedRating != null && fresh) {
        return (
          rating: cachedRating,
          count: (data?['googleRatingCount'] as num?)?.toInt(),
        );
      }
    } catch (_) {}

    // 2) Google Place Details (New) — yalnızca puan alanları
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.placesDetailsUrl}/$placeId'),
            headers: {
              'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
              'X-Goog-FieldMask': 'rating,userRatingCount',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return (rating: null, count: null);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rating = (decoded['rating'] as num?)?.toDouble();
      final count = (decoded['userRatingCount'] as num?)?.toInt();
      await remember(placeId, rating: rating, count: count);
      return (rating: rating, count: count);
    } catch (_) {
      return (rating: null, count: null);
    }
  }
}
