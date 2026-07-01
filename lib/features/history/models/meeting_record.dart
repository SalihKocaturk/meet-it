import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir mekan aramasının anlık görüntüsü — Firestore'a kaydedilen veri modeli.
///
/// `PlaceResult` aksine buradaki veriler ANLIKTIR (bkz. Firestore `meetingHistory/{id}`)
/// — yani arama yapıldığındaki mekan adı, koordinat, puan vb. olduğu gibi
/// kalır, Place Details API sonradan ne değişirse değişsin.
class VenueSnapshot {
  final String placeId;
  final String name;
  final String? vicinity;
  final double lat;
  final double lng;
  final double? rating;
  final List<String> photoUrls; // Firebase Storage'daki önbellek URL'leri
  final List<String> types; // Google taksonomisi: ['cafe', 'restaurant', ...]
  final int? priceLevel;

  const VenueSnapshot({
    required this.placeId,
    required this.name,
    this.vicinity,
    required this.lat,
    required this.lng,
    this.rating,
    this.photoUrls = const [],
    this.types = const [],
    this.priceLevel,
  });

  Map<String, dynamic> toMap() => {
        'placeId': placeId,
        'name': name,
        if (vicinity != null) 'vicinity': vicinity,
        'lat': lat,
        'lng': lng,
        if (rating != null) 'rating': rating,
        'photoUrls': photoUrls,
        'types': types,
        if (priceLevel != null) 'priceLevel': priceLevel,
      };

  factory VenueSnapshot.fromMap(Map<String, dynamic> map) => VenueSnapshot(
        placeId: map['placeId'] as String,
        name: map['name'] as String,
        vicinity: map['vicinity'] as String?,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        rating: (map['rating'] as num?)?.toDouble(),
        photoUrls: List<String>.from(map['photoUrls'] ?? []),
        types: List<String>.from(map['types'] ?? []),
        priceLevel: map['priceLevel'] as int?,
      );
}

/// Başarılı bir mekan aramasının kaydı.
///
/// Firestore şeması: `meetingHistory/{id}`
/// Sorgu: `participantUids` arrayContains uid → iki kullanıcı da kendi
/// geçmişlerinde bu kaydı görür.
class MeetingRecord {
  final String id;
  final String initiatorUid;
  final String initiatorName;
  final String? initiatorPhotoUrl;

  // null = tek başına arama
  final String? friendUid;
  final String? friendName;
  final String? friendPhotoUrl;

  final List<String> activities; // seçilen aktivite etiketleri
  final List<VenueSnapshot> venues; // bulunan tüm mekanlar (midpoint + others)
  final double searchLat;
  final double searchLng;
  final bool hasMidpoint; // orta nokta modu kullanıldı mı?
  final DateTime createdAt;

  /// Hem initiator hem de friend'in UID'si buraya eklenir.
  /// Firestore `arrayContains` sorgusu her iki kullanıcının geçmişinde
  /// bu kaydı döndürmesini sağlar.
  final List<String> participantUids;

  const MeetingRecord({
    required this.id,
    required this.initiatorUid,
    required this.initiatorName,
    this.initiatorPhotoUrl,
    this.friendUid,
    this.friendName,
    this.friendPhotoUrl,
    required this.activities,
    required this.venues,
    required this.searchLat,
    required this.searchLng,
    required this.hasMidpoint,
    required this.createdAt,
    required this.participantUids,
  });

  bool get isSolo => friendUid == null;

  Map<String, dynamic> toMap() => {
        'initiatorUid': initiatorUid,
        'initiatorName': initiatorName,
        if (initiatorPhotoUrl != null) 'initiatorPhotoUrl': initiatorPhotoUrl,
        if (friendUid != null) 'friendUid': friendUid,
        if (friendName != null) 'friendName': friendName,
        if (friendPhotoUrl != null) 'friendPhotoUrl': friendPhotoUrl,
        'activities': activities,
        'venues': venues.map((v) => v.toMap()).toList(),
        'searchLat': searchLat,
        'searchLng': searchLng,
        'hasMidpoint': hasMidpoint,
        'createdAt': FieldValue.serverTimestamp(),
        'participantUids': participantUids,
      };

  factory MeetingRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return MeetingRecord(
      id: doc.id,
      initiatorUid: data['initiatorUid'] as String,
      initiatorName: data['initiatorName'] as String? ?? '',
      initiatorPhotoUrl: data['initiatorPhotoUrl'] as String?,
      friendUid: data['friendUid'] as String?,
      friendName: data['friendName'] as String?,
      friendPhotoUrl: data['friendPhotoUrl'] as String?,
      activities: List<String>.from(data['activities'] ?? []),
      venues: (data['venues'] as List<dynamic>? ?? [])
          .map((v) => VenueSnapshot.fromMap(v as Map<String, dynamic>))
          .toList(),
      searchLat: (data['searchLat'] as num).toDouble(),
      searchLng: (data['searchLng'] as num).toDouble(),
      hasMidpoint: data['hasMidpoint'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantUids: List<String>.from(data['participantUids'] ?? []),
    );
  }
}
