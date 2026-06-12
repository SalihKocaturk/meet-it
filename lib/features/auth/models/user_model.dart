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
    };
  }

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
    );
  }
}
