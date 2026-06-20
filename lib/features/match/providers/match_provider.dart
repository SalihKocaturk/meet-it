import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

// ── Seçili arkadaş UID'si ─────────────────────────────────────────────────────
final selectedFriendUidProvider = StateProvider.autoDispose<String?>((ref) => null);

// ── Seçili aktivite türleri (çoklu seçim) ─────────────────────────────────────
final selectedActivitiesProvider =
    StateProvider.autoDispose<Set<String>>((ref) => {});

// ── Mekan önerileri gösteriliyor mu? ──────────────────────────────────────────
final showVenuesProvider = StateProvider.autoDispose<bool>((ref) => false);

// ── Kullanıcının girdiği konum (text + lat/lng) ───────────────────────────────
class UserLocation {
  final String text;
  final double? lat;
  final double? lng;
  const UserLocation({required this.text, this.lat, this.lng});
  bool get hasCoords => lat != null && lng != null;
}

// Konum DB'den (UserModel.lat/lng) geliyorsa başlangıç değeri olarak
// otomatik doldurulur — kullanıcı uygulamayı her açtığında yeniden
// konum girmek veya konum servisini açık tutmak zorunda kalmasın.
// `currentUserProvider` değiştiğinde (örn. konum DB'ye yazıldıktan
// sonra) bu da otomatik senkronize olur.
final userLocationProvider = StateProvider<UserLocation?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.hasCoords ?? false) {
    return UserLocation(
      text: (user!.location != null && user.location!.trim().isNotEmpty)
          ? user.location!
          : '${user.lat!.toStringAsFixed(4)}, ${user.lng!.toStringAsFixed(4)}',
      lat: user.lat,
      lng: user.lng,
    );
  }
  return null;
});

// ── Fiyat seviyesi filtresi ────────────────────────────────────────────────────
// null = tümü, 0 = ücretsiz, 1 = ucuz, 2 = orta, 3 = pahalı, 4 = çok pahalı
final selectedPriceLevelProvider = StateProvider.autoDispose<int?>((ref) => null);

// ── Seçili arkadaş modeli ──────────────────────────────────────────────────────
final selectedFriendProvider = Provider.autoDispose<UserFriendModel?>((ref) {
  final uid = ref.watch(selectedFriendUidProvider);
  if (uid == null) return null;
  final connections = ref.watch(connectionsProvider);
  try {
    return connections.firstWhere((f) => f.uid == uid);
  } catch (_) {
    return null;
  }
});

// ── Mekan önerileri ────────────────────────────────────────────────────────────
//
// İki kullanıcının PersonalityProfile'ına ve seçili aktivitelere göre
// getVenueRecommendations() çağrılır. Profil yoksa mock profil kullanılır.
final venueRecommendationsProvider =
    Provider.autoDispose<List<VenueRecommendation>>((ref) {
  final showVenues = ref.watch(showVenuesProvider);
  if (!showVenues) return [];

  final currentUser = ref.watch(currentUserProvider);
  final selectedFriend = ref.watch(selectedFriendProvider);
  final selectedActivities = ref.watch(selectedActivitiesProvider);

  // Profil yoksa fallback: sosyalKelebek dominant mock
  final userProfile = currentUser?.personalityProfile ??
      PersonalityProfile.mock(PersonalityType.sosyalKelebek);
  final friendProfile = selectedFriend?.personalityProfile ??
      PersonalityProfile.mock(PersonalityType.sosyalKelebek);

  return getVenueRecommendations(
    userProfile: userProfile,
    friendProfile: friendProfile,
    selectedActivities: selectedActivities.toList(),
  );
});

// ── Uyumluluk skoru (50–98) ────────────────────────────────────────────────────
//
// PersonalityProfile.compatibilityWith() kosinüs benzerliğiyle hesaplar.
// Profil yoksa 70 döner.
final compatibilityScoreProvider = Provider.autoDispose<int>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final selectedFriend = ref.watch(selectedFriendProvider);

  if (selectedFriend == null) return 0;

  final userProfile = currentUser?.personalityProfile;
  final friendProfile = selectedFriend.personalityProfile;

  // İkisi de profil sahibiyse gerçek hesap yap
  if (userProfile != null && friendProfile != null) {
    return userProfile.compatibilityWith(friendProfile);
  }

  // Fallback: tek bir dominant tipi varsa eski mantık
  if (userProfile != null) {
    final key = _compatKey(
      userProfile.dominantType,
      friendProfile?.dominantType ?? PersonalityType.sosyalKelebek,
    );
    return _legacyScore(key);
  }

  return 70;
});

/// Simetrik karşılaştırma key'i
String _compatKey(PersonalityType a, PersonalityType b) {
  final parts = [a.name, b.name]..sort();
  return '${parts[0]}_${parts[1]}';
}

/// Eski tip bazlı uyumluluk (fallback)
int _legacyScore(String key) {
  const highCompatKeys = {
    'gurme_sosyalKelebek',
    'maceraperest_sosyalKelebek',
    'entelektuel_sakinRuh',
    'entelektuel_gurme',
    'maceraperest_sakinRuh',
  };
  if (key.split('_').first == key.split('_').last) return 95;
  if (highCompatKeys.contains(key)) return 85;
  return 70;
}
