import 'package:meetit/features/personality/models/personality_model.dart';

enum FriendStatus { pending, accepted, rejected }

class UserFriendModel {
  final String uid;
  final String name;
  final String? photoUrl;
  final FriendStatus status;
  final DateTime addedAt;

  /// Arkadaşın kişilik profili — DB'den çekilir, null ise henüz quiz yapmamış.
  final PersonalityProfile? personalityProfile;

  /// Arkadaşın konumu (gerçek uygulamada DB'den gelir).
  final double? lat;
  final double? lng;

  const UserFriendModel({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.status,
    required this.addedAt,
    this.personalityProfile,
    this.lat,
    this.lng,
  });

  factory UserFriendModel.fromMap(Map<String, dynamic> map) {
    return UserFriendModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      photoUrl: map['photoUrl'] as String?,
      status: FriendStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => FriendStatus.pending,
      ),
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      personalityProfile: map['personalityProfile'] != null
          ? PersonalityProfile.fromMap(
              map['personalityProfile'] as Map<String, dynamic>,
            )
          : null,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photoUrl': photoUrl,
      'status': status.name,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'personalityProfile': personalityProfile?.toMap(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  UserFriendModel copyWith({
    String? uid,
    String? name,
    String? photoUrl,
    FriendStatus? status,
    DateTime? addedAt,
    PersonalityProfile? personalityProfile,
    bool clearProfile = false,
    double? lat,
    double? lng,
  }) {
    return UserFriendModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      personalityProfile: clearProfile
          ? null
          : (personalityProfile ?? this.personalityProfile),
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
