import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Kaydedilen Mekanlar ───────────────────────────────────────────────────────
//
// NOT: Önceden bu liste SADECE SharedPreferences'a yazılıyordu — yani
// kullanıcı uygulamayı silip yeniden kurduğunda veya başka bir cihazdan
// giriş yaptığında kaydettiği mekanlar kaybolurdu. Artık giriş yapmış bir
// kullanıcı varsa aynı veri Firestore'da `users/{uid}/saved_venues/{placeId}`
// altında da tutulur — SharedPreferences hâlâ anlık/lokal önbellek olarak
// kullanılıyor (uygulama açılışında hızlı göstersin diye), ama gerçek kaynak
// artık Firestore.

class SavedVenuesNotifier extends Notifier<List<PlaceResult>> {
  static const _kKey = 'saved_venues';
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  List<PlaceResult> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    // Önce lokal önbellekten anlık göster
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    state = raw
        .map((s) => PlaceResult.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    // Sonra Firestore'dan taze veriyi çek (giriş yapılmışsa) — bu, gerçek
    // kaynak olarak kalıcılığı garanti eder.
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap =
          await _db.collection('users').doc(uid).collection('saved_venues').get();
      final fromDb =
          snap.docs.map((d) => PlaceResult.fromJson(d.data())).toList();
      state = fromDb;
      await _persistLocal(fromDb);
    } catch (_) {
      // Ağ/Firestore hatasında lokal önbellekte kalınır
    }
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
    await _persistLocal(next);

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('saved_venues')
          .doc(place.placeId)
          .set(_toMap(place));
    } catch (_) {
      // Firestore hatası lokal kaydı etkilemesin
    }
  }

  Future<void> _remove(String placeId) async {
    final next = state.where((p) => p.placeId != placeId).toList();
    state = next;
    await _persistLocal(next);

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('saved_venues')
          .doc(placeId)
          .delete();
    } catch (_) {}
  }

  Future<void> _persistLocal(List<PlaceResult> list) async {
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
        // Tüm foto referansları saklanıyor (sadece ilki değil) — kaydedilen/
        // tarifi alınan mekanlar uygulama yeniden açıldığında da galerideki
        // tüm fotoğrafları gösterebilsin diye.
        'photos': p.photoReferences.isNotEmpty
            ? p.photoReferences
                .map((ref) => {'photo_reference': ref})
                .toList()
            : (p.photoReference != null
                ? [
                    {'photo_reference': p.photoReference}
                  ]
                : null),
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
//
// Aynı Firestore kalıcılığı burada da uygulanıyor —
// `users/{uid}/navigated_venues/{placeId}`.

class NavigatedVenuesNotifier extends Notifier<List<PlaceResult>> {
  static const _kKey = 'navigated_venues';
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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

    final uid = _uid;
    if (uid == null) return;
    try {
      // `addedAt` (serverTimestamp) alanına göre en yeniden eskiye sırala —
      // listenin en üstünde en son "Gitmeye Başla" denen mekan görünsün.
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('navigated_venues')
          .orderBy('addedAt', descending: true)
          .get();
      final fromDb =
          snap.docs.map((d) => PlaceResult.fromJson(d.data())).toList();
      state = fromDb;
      await _persistLocal(fromDb);
    } catch (_) {
      // Composite index henüz yoksa ya da ağ hatası varsa lokal önbellekte
      // kalınır — sıralama olmadan en azından veri kaybı yaşanmaz.
    }
  }

  Future<void> add(PlaceResult place) async {
    // Zaten varsa tekrar ekleme, en üste taşı
    final filtered = state.where((p) => p.placeId != place.placeId).toList();
    final next = [place, ...filtered];
    state = next;
    await _persistLocal(next);

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('navigated_venues')
          .doc(place.placeId)
          .set({
        ..._toMap(place),
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _persistLocal(List<PlaceResult> list) async {
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
        // Tüm foto referansları saklanıyor (sadece ilki değil) — kaydedilen/
        // tarifi alınan mekanlar uygulama yeniden açıldığında da galerideki
        // tüm fotoğrafları gösterebilsin diye.
        'photos': p.photoReferences.isNotEmpty
            ? p.photoReferences
                .map((ref) => {'photo_reference': ref})
                .toList()
            : (p.photoReference != null
                ? [
                    {'photo_reference': p.photoReference}
                  ]
                : null),
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
