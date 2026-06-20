/// Firestore `venue_reviews` koleksiyonundaki tek bir mekan yorumu.
///
/// PostModel'in yerini alır — paylaşım yerine, kullanıcının gerçekten
/// gittiği (navigatedVenuesProvider'da olan) bir mekana yıldız + yorum +
/// opsiyonel fotoğraf ile değerlendirme yapmasını temsil eder.
class VenueReviewModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;

  /// Mekan bilgileri
  final String placeId;
  final String venueName;
  final String? venueAddress;
  final String? venuePhotoUrl;
  final double? lat;
  final double? lng;

  /// Yıldız değerlendirmesi (1-5) — her yorum için zorunlu
  final int rating;

  /// Kullanıcının yazdığı yorum metni
  final String? comment;

  /// Kullanıcının yüklediği fotoğraf (opsiyonel)
  final String? photoUrl;

  /// Beğeni yapan kullanıcı uid'leri
  final List<String> likedBy;

  final DateTime createdAt;

  const VenueReviewModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.placeId,
    required this.venueName,
    this.venueAddress,
    this.venuePhotoUrl,
    this.lat,
    this.lng,
    required this.rating,
    this.comment,
    this.photoUrl,
    this.likedBy = const [],
    required this.createdAt,
  });

  int get likeCount => likedBy.length;

  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory VenueReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return VenueReviewModel(
      id: id,
      authorUid: map['authorUid'] as String,
      authorName: map['authorName'] as String,
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      placeId: map['placeId'] as String? ?? '',
      venueName: map['venueName'] as String? ?? '',
      venueAddress: map['venueAddress'] as String?,
      venuePhotoUrl: map['venuePhotoUrl'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment'] as String?,
      photoUrl: map['photoUrl'] as String?,
      likedBy: List<String>.from(map['likedBy'] as List? ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        'placeId': placeId,
        'venueName': venueName,
        if (venueAddress != null) 'venueAddress': venueAddress,
        if (venuePhotoUrl != null) 'venuePhotoUrl': venuePhotoUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'rating': rating,
        if (comment != null) 'comment': comment,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'likedBy': likedBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  VenueReviewModel copyWith({
    List<String>? likedBy,
    String? comment,
    int? rating,
  }) =>
      VenueReviewModel(
        id: id,
        authorUid: authorUid,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        placeId: placeId,
        venueName: venueName,
        venueAddress: venueAddress,
        venuePhotoUrl: venuePhotoUrl,
        lat: lat,
        lng: lng,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        photoUrl: photoUrl,
        likedBy: likedBy ?? this.likedBy,
        createdAt: createdAt,
      );
}
