import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Kaydedilen Mekanlar ───────────────────────────────────────────────────────

class SavedVenuesNotifier extends Notifier<List<PlaceResult>> {
  static const _kKey = 'saved_venues';

  @override
  List<PlaceResult> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    state = raw
        .map((s) => PlaceResult.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggle(PlaceResult place) async {
    final already = state.any((p) => p.placeId == place.placeId);
    if (already) {
      await _remove(place.placeId);
    } else {
      await _add(place);
    }
  }

  bool isSaved(String placeId) => state.any((p) => p.placeId == placeId);

  Future<void> _add(PlaceResult place) async {
    final next = [place, ...state];
    state = next;
    await _persist(next);
  }

  Future<void> _remove(String placeId) async {
    final next = state.where((p) => p.placeId != placeId).toList();
    state = next;
    await _persist(next);
  }

  Future<void> _persist(List<PlaceResult> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      list.map((p) => jsonEncode(_toMap(p))).toList(),
    );
  }

  Map<String, dynamic> _toMap(PlaceResult p) => {
        'place_id': p.placeId,
        'name': p.name,
        'vicinity': p.vicinity,
        'rating': p.rating,
        'user_ratings_total': p.userRatingsTotal,
        'types': p.types,
        'photos': p.photoReference != null
            ? [
                {'photo_reference': p.photoReference}
              ]
            : null,
        'geometry': {
          'location': {'lat': p.lat, 'lng': p.lng}
        },
        'opening_hours': {'open_now': p.isOpenNow},
        'price_level': p.priceLevel,
      };
}

final savedVenuesProvider =
    NotifierProvider<SavedVenuesNotifier, List<PlaceResult>>(
  SavedVenuesNotifier.new,
);

// ── Tarifi Alınan Mekanlar (Gitmeye Başla ile eklenenler) ────────────────────

class NavigatedVenuesNotifier extends Notifier<List<PlaceResult>> {
  static const _kKey = 'navigated_venues';

  @override
  List<PlaceResult> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    state = raw
        .map((s) => PlaceResult.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(PlaceResult place) async {
    // Zaten varsa tekrar ekleme, en üste taşı
    final filtered = state.where((p) => p.placeId != place.placeId).toList();
    final next = [place, ...filtered];
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      next.map((p) => jsonEncode(_toMap(p))).toList(),
    );
  }

  Map<String, dynamic> _toMap(PlaceResult p) => {
        'place_id': p.placeId,
        'name': p.name,
        'vicinity': p.vicinity,
        'rating': p.rating,
        'user_ratings_total': p.userRatingsTotal,
        'types': p.types,
        'photos': p.photoReference != null
            ? [
                {'photo_reference': p.photoReference}
              ]
            : null,
        'geometry': {
          'location': {'lat': p.lat, 'lng': p.lng}
        },
        'opening_hours': {'open_now': p.isOpenNow},
        'price_level': p.priceLevel,
      };
}

final navigatedVenuesProvider =
    NotifierProvider<NavigatedVenuesNotifier, List<PlaceResult>>(
  NavigatedVenuesNotifier.new,
);
