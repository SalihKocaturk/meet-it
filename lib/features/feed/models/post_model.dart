/// Firestore `posts` koleksiyonundaki tek bir buluşma paylaşımı.
class PostModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;

  /// Birlikte buluşulan arkadaşın bilgileri
  final String? friendUid;
  final String? friendName;
  final String? friendPhotoUrl;

  /// Mekan bilgileri
  final String venueName;
  final String? venueAddress;
  final String? venuePhotoUrl;
  final double? venueLat;
  final double? venueLng;

  /// Kullanıcının yazdığı caption
  final String? caption;

  /// Kullanıcının yüklediği fotoğraf (opsiyonel)
  final String? postPhotoUrl;

  /// Uygulama içi yıldız değerlendirmesi (1-5), null ise normal paylaşım
  final int? rating;

  /// Beğeni yapan kullanıcı uid'leri
  final List<String> likedBy;

  /// Kaydeden kullanıcı uid'leri
  final List<String> savedBy;

  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    this.friendUid,
    this.friendName,
    this.friendPhotoUrl,
    required this.venueName,
    this.venueAddress,
    this.venuePhotoUrl,
    this.venueLat,
    this.venueLng,
    this.caption,
    this.postPhotoUrl,
    this.rating,
    this.likedBy = const [],
    this.savedBy = const [],
    required this.createdAt,
  });

  int get likeCount => likedBy.length;
  int get saveCount => savedBy.length;

  bool isLikedBy(String uid) => likedBy.contains(uid);
  bool isSavedBy(String uid) => savedBy.contains(uid);

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      authorUid: map['authorUid'] as String,
      authorName: map['authorName'] as String,
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      friendUid: map['friendUid'] as String?,
      friendName: map['friendName'] as String?,
      friendPhotoUrl: map['friendPhotoUrl'] as String?,
      venueName: map['venueName'] as String? ?? '',
      venueAddress: map['venueAddress'] as String?,
      venuePhotoUrl: map['venuePhotoUrl'] as String?,
      venueLat: (map['venueLat'] as num?)?.toDouble(),
      venueLng: (map['venueLng'] as num?)?.toDouble(),
      caption: map['caption'] as String?,
      postPhotoUrl: map['postPhotoUrl'] as String?,
      rating: (map['rating'] as num?)?.toInt(),
      likedBy: List<String>.from(map['likedBy'] as List? ?? []),
      savedBy: List<String>.from(map['savedBy'] as List? ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        if (friendUid != null) 'friendUid': friendUid,
        if (friendName != null) 'friendName': friendName,
        if (friendPhotoUrl != null) 'friendPhotoUrl': friendPhotoUrl,
        'venueName': venueName,
        if (venueAddress != null) 'venueAddress': venueAddress,
        if (venuePhotoUrl != null) 'venuePhotoUrl': venuePhotoUrl,
        if (venueLat != null) 'venueLat': venueLat,
        if (venueLng != null) 'venueLng': venueLng,
        if (caption != null) 'caption': caption,
        if (postPhotoUrl != null) 'postPhotoUrl': postPhotoUrl,
        if (rating != null) 'rating': rating,
        'likedBy': likedBy,
        'savedBy': savedBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  PostModel copyWith({
    List<String>? likedBy,
    List<String>? savedBy,
    String? caption,
    int? rating,
    bool clearRating = false,
  }) =>
      PostModel(
        id: id,
        authorUid: authorUid,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        friendUid: friendUid,
        friendName: friendName,
        friendPhotoUrl: friendPhotoUrl,
        venueName: venueName,
        venueAddress: venueAddress,
        venuePhotoUrl: venuePhotoUrl,
        venueLat: venueLat,
        venueLng: venueLng,
        caption: caption ?? this.caption,
        postPhotoUrl: postPhotoUrl,
        rating: clearRating ? null : (rating ?? this.rating),
        likedBy: likedBy ?? this.likedBy,
        savedBy: savedBy ?? this.savedBy,
        createdAt: createdAt,
      );
}
