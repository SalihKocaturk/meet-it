import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/services/places_service.dart';

/// Ana sayfa hibrit carousel'i için kişiselleştirilmiş mekan önerileri.
///
/// ── Önceliklendirme:
///    1. Bellekte sonuç varsa (session boyunca) → anlık, 0 istek.
///    2. Firestore/local cache varsa → 1 Firestore okuma, 0 API çağrısı.
///    3. Cache yoksa → 1 Nearby Search API çağrısı, sonuç Firestore'a yazılır.
///
/// ── Koşullar:
///    • Kullanıcının kaydedilmiş konumu (lat/lng) yoksa boş liste döner.
///    • Kişilik profili yoksa boş liste döner (quiz henüz yapılmadı).
final personalizedVenuesProvider =
    FutureProvider.autoDispose<List<PlaceResult>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final lat = user.lat;
  final lng = user.lng;
  if (lat == null || lng == null) return [];

  final profile = user.personalityProfile;
  if (profile == null) return [];

  return PlacesService.fetchRecommendedVenues(
    lat: lat,
    lng: lng,
    profile: profile,
    maxCount: 6, // hibrit carousel max 6 öğe: önce yorumlar, kalanı buradan
  );
});
