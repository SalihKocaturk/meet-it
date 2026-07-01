import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// Firestore'a örnek kullanıcılar ekler.
/// Sadece 'users' koleksiyonu boşsa çalışır.
class FirestoreSeedService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> seedIfEmpty() async {
    try {
      final snap =
          await _db.collection('users').limit(1).get();
      if (snap.docs.isNotEmpty) return; // Zaten veri var

      final users = _mockUsers();
      final batch = _db.batch();
      for (final u in users) {
        batch.set(_db.collection('users').doc(u.uid), u.toMap());
      }
      await batch.commit();
      // ignore: avoid_print
      print('✅ Firestore seed: ${users.length} kullanıcı eklendi.');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Firestore seed hatası: $e');
    }
  }

  static List<UserModel> _mockUsers() {
    final now = DateTime.now();
    return [
      UserModel(
        uid: 'seed_u01',
        name: 'Ayşe Kaya',
        email: 'ayse.kaya@example.com',
        location: 'İstanbul',
        age: 24,
        gender: 'Kadın',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.sosyalKelebek,
          PersonalityType.gurme,
        ),
      ),
      UserModel(
        uid: 'seed_u02',
        name: 'Mehmet Yılmaz',
        email: 'mehmet.yilmaz@example.com',
        location: 'Ankara',
        age: 28,
        gender: 'Erkek',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.maceraperest,
          PersonalityType.sosyalKelebek,
        ),
      ),
      UserModel(
        uid: 'seed_u03',
        name: 'Zeynep Demir',
        email: 'zeynep.demir@example.com',
        location: 'İzmir',
        age: 22,
        gender: 'Kadın',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.entelektuel,
          PersonalityType.sakinRuh,
        ),
      ),
      UserModel(
        uid: 'seed_u04',
        name: 'Can Öztürk',
        email: 'can.ozturk@example.com',
        location: 'İstanbul',
        age: 31,
        gender: 'Erkek',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.gurme,
          PersonalityType.entelektuel,
        ),
      ),
      UserModel(
        uid: 'seed_u05',
        name: 'Elif Şahin',
        email: 'elif.sahin@example.com',
        location: 'Bursa',
        age: 26,
        gender: 'Kadın',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.sakinRuh,
          PersonalityType.entelektuel,
        ),
      ),
      UserModel(
        uid: 'seed_u06',
        name: 'Burak Arslan',
        email: 'burak.arslan@example.com',
        location: 'İstanbul',
        age: 29,
        gender: 'Erkek',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.maceraperest,
        ),
      ),
      UserModel(
        uid: 'seed_u07',
        name: 'Selin Aydın',
        email: 'selin.aydin@example.com',
        location: 'Antalya',
        age: 23,
        gender: 'Kadın',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.sosyalKelebek,
          PersonalityType.maceraperest,
        ),
      ),
      UserModel(
        uid: 'seed_u08',
        name: 'Murat Çelik',
        email: 'murat.celik@example.com',
        location: 'İstanbul',
        age: 35,
        gender: 'Erkek',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.entelektuel,
          PersonalityType.gurme,
        ),
      ),
      UserModel(
        uid: 'seed_u09',
        name: 'Deniz Yıldız',
        email: 'deniz.yildiz@example.com',
        location: 'Eskişehir',
        age: 27,
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.gurme,
          PersonalityType.sosyalKelebek,
        ),
      ),
      UserModel(
        uid: 'seed_u10',
        name: 'Hande Kılıç',
        email: 'hande.kilic@example.com',
        location: 'İstanbul',
        age: 25,
        gender: 'Kadın',
        createdAt: now,
        personalityProfile: PersonalityProfile.mock(
          PersonalityType.sakinRuh,
          PersonalityType.gurme,
        ),
      ),
    ];
  }
}
