import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/services/venue_photo_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 💸 MALİYET DÜŞÜRME (2026-06-28): Bir mekan "Kaydet" veya "Tarif Al" ile
/// kalıcı bir listeye eklendiğinde, o mekan artık bu kullanıcının
/// profilinde/anasayfasında TEKRAR TEKRAR gösterilecek demektir. Mekan arama
/// akışından geldiyse fotoğrafları zaten önbelleğe alınmış olur (bkz.
/// PlacesService.searchVenues) — ama mekan başka bir yoldan (örn. arkadaş
/// profili, yorum kartı) gelip hâlâ ham bir Google foto referansı
/// taşıyorsa, bu fonksiyon kalıcı kayıttan ÖNCE onu çözümleyip Storage
/// URL'ine çevirir. Böylece kalıcı kayda HER ZAMAN çözümlenmiş bir URL
/// yazılır — kullanıcı bu listeyi her açtığında Google'a gidilmez.
Future<PlaceResult> _withCachedPhotos(PlaceResult place) async {
  final namesToCache = place.photoReferences.isNotEmpty
      ? place.photoReferences
      : (place.photoReference != null ? [place.photoReference!] : <String>[]);
  if (namesToCache.isEmpty) return place;
  try {
    final cachedUrls = await VenuePhotoCacheService.resolvePhotoUrls(
      placeId: place.placeId,
      photoNames: namesToCache,
    );
    if (cachedUrls.isEmpty) return place;
    return place.copyWith(
      photoReference: cachedUrls.first,
      photoReferences: cachedUrls,
    );
  } catch (_) {
    return place; // önbellekleme başarısız olursa ham referansla devam
  }
}

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
        .map((s) => PlaceResult.fromStorageMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    // Sonra Firestore'dan taze veriyi çek (giriş yapılmışsa) — bu, gerçek
    // kaynak olarak kalıcılığı garanti eder.
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap =
          await _db.collection('users').doc(uid).collection('saved_venues').get();
      final fromDb =
          snap.docs.map((d) => PlaceResult.fromStorageMap(d.data())).toList();
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
    // Kalıcı kayıttan önce fotoğrafları önbellekten çözümle (bkz.
    // _withCachedPhotos) — UI'da ANINDA gösterim gecikmesin diye state
    // önce ham haliyle güncelleniyor, çözümleme arka planda tamamlanınca
    // hem state hem kalıcı kayıt güncel URL ile yenileniyor.
    final next = [place, ...state];
    state = next;
    await _persistLocal(next);

    final cachedPlace = await _withCachedPhotos(place);
    final withCache =
        [cachedPlace, ...state.where((p) => p.placeId != place.placeId)];
    state = withCache;
    await _persistLocal(withCache);

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('saved_venues')
          .doc(place.placeId)
          .set(cachedPlace.toStorageMap());
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
      list.map((p) => jsonEncode(p.toStorageMap())).toList(),
    );
  }
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
        .map((s) => PlaceResult.fromStorageMap(jsonDecode(s) as Map<String, dynamic>))
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
          snap.docs.map((d) => PlaceResult.fromStorageMap(d.data())).toList();
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

    // Kalıcı kayıttan önce fotoğrafları önbellekten çözümle (bkz.
    // _withCachedPhotos) — "Tarif Al" da, "Kaydet" gibi, mekanın profilde
    // tekrar tekrar gösterileceği bir kalıcı liste oluşturuyor.
    final cachedPlace = await _withCachedPhotos(place);
    final withCache = [
      cachedPlace,
      ...state.where((p) => p.placeId != place.placeId),
    ];
    state = withCache;
    await _persistLocal(withCache);

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('navigated_venues')
          .doc(place.placeId)
          .set({
        ...cachedPlace.toStorageMap(),
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _persistLocal(List<PlaceResult> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      list.map((p) => jsonEncode(p.toStorageMap())).toList(),
    );
  }
}

final navigatedVenuesProvider =
    NotifierProvider<NavigatedVenuesNotifier, List<PlaceResult>>(
  NavigatedVenuesNotifier.new,
);
