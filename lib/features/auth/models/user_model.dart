import 'package:meetit/features/personality/models/personality_model.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? location;
  final int? age;
  final String? gender;
  final String? photoUrl;
  final DateTime createdAt;
  final PersonalityProfile? personalityProfile;

  /// Kullanıcının son bilinen GPS/harita üzerinden seçtiği konum
  /// koordinatları. Firestore'a kaydedilir ki arkadaşlar buluşma
  /// mekanı ararken bu kullanıcının konumunu her zaman güvenilir bir
  /// şekilde okuyabilsin — anlık konum servisine veya her seferinde
  /// yeniden konum girilmesine ihtiyaç kalmasın.
  final double? lat;
  final double? lng;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.location,
    this.age,
    this.gender,
    this.photoUrl,
    required this.createdAt,
    this.personalityProfile,
    this.lat,
    this.lng,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String? ?? '',
      location: map['location'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
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
      'email': email,
      if (location != null) 'location': location,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (personalityProfile != null)
        'personalityProfile': personalityProfile!.toMap(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  bool get hasCoords => lat != null && lng != null;

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? location,
    int? age,
    String? gender,
    String? photoUrl,
    DateTime? createdAt,
    PersonalityProfile? personalityProfile,
    bool clearProfile = false,
    double? lat,
    double? lng,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      location: location ?? this.location,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      personalityProfile:
          clearProfile ? null : (personalityProfile ?? this.personalityProfile),
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
