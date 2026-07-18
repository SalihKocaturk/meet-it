import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetit/features/match/services/places_api_version_service.dart';

/// 💰 4 AŞAMALI API KULLANIM YÖNETİCİSİ (2026-07-05)
///
/// Aylık iki farklı Google Places API kotasını (New + Legacy) otomatik
/// takip eder ve foto/arama limitlerine göre aşağıdaki aşamalara geçer:
///
///   Aşama 1 — [newWithPhotos]:    New API + fotoğraf çekimi
///   Aşama 2 — [legacyWithPhotos]: Legacy API + fotoğraf çekimi
///   Aşama 3 — [newNoPhotos]:      New API, fotoğrafsız (flag: backfill bekliyor)
///   Aşama 4 — [legacyNoPhotos]:   Legacy API, fotoğrafsız
///
/// Her ay yeni Firestore key'i oluşur (`YYYY_MM` suffix) → sıfırlama
/// otomatik, sil/yazma gerekmez. Bir sonraki aya geçilince kota yenilenir
/// ve fotoğrafsız kaydedilen mekanlar natural backfill ile foto kazanır
/// (searchVenues her arama öncesi VenuePhotoCacheService'i çağırıyor;
/// cache miss → aşama fotoya izin veriyorsa → Google → Storage → cache).
///
/// Firestore şekli (`appConfig/apiUsage`):
///   photo_new_YYYY_MM:     int  — New API foto çekimi (bu ay)
///   photo_legacy_YYYY_MM:  int  — Legacy API foto çekimi (bu ay)
///   search_new_YYYY_MM:    int  — New API Nearby Search çağrısı (bu ay)
///   photo_limit:           int  — foto kotası (varsayılan 1000)
///   search_new_limit:      int  — New API arama kotası (varsayılan 4000)
///
/// RACE CONDITION: FieldValue.increment atomic olduğu için sayaç kaybı
/// olmaz. Limit ±2-3 aşılabilir (TOCTOU) — 1000'lik limitler için kabul
/// edilebilir ve önemli bir mali riski yok.
enum ApiStage { newWithPhotos, legacyWithPhotos, newNoPhotos, legacyNoPhotos }

extension ApiStageX on ApiStage {
  /// Bu aşamada New Places API mi kullanılıyor?
  bool get usesNewApi =>
      this == ApiStage.newWithPhotos || this == ApiStage.newNoPhotos;

  /// Bu aşamada Google'dan fotoğraf çekilmeli mi?
  bool get photosEnabled =>
      this == ApiStage.newWithPhotos || this == ApiStage.legacyWithPhotos;

  /// Bu aşamaya karşılık gelen Places API versiyonu.
  PlacesApiVersion get apiVersion =>
      usesNewApi ? PlacesApiVersion.newApi : PlacesApiVersion.legacy;

  /// Debug / loglama için kısa açıklama.
  String get label => switch (this) {
    ApiStage.newWithPhotos => 'New+foto',
    ApiStage.legacyWithPhotos => 'Legacy+foto',
    ApiStage.newNoPhotos => 'New+fotosuz',
    ApiStage.legacyNoPhotos => 'Legacy+fotosuz',
  };
}

class ApiUsageService {
  ApiUsageService._();

  static final _fs = FirebaseFirestore.instance;
  static const _docPath = 'appConfig/apiUsage';

  // ── Varsayılan limitler (Firestore'dan override edilebilir) ──────────────
  static const _defaultPhotoLimit = 1000; // New veya Legacy başına
  static const _defaultSearchNewLimit = 4000; // New API aramalarına limit

  // ── In-memory cache — Firestore'a her aramada gidilmesin ─────────────────
  static ApiStage? _cached;
  static DateTime? _cachedAt;
  static const _ttl = Duration(minutes: 5);

  // ── Yardımcı: aylık key ─────────────────────────────────────────────────

  static String _mk() {
    final n = DateTime.now();
    return '${n.year}_${n.month.toString().padLeft(2, '0')}';
  }

  // ── Aşama belirleme ──────────────────────────────────────────────────────

  /// Mevcut API aşamasını döner. 5 dakika bellek-içi önbellekte saklanır.
  ///
  /// Firestore okunamazsa (ağ, izin): son geçerli değer döner; değer yoksa
  /// [ApiStage.newWithPhotos] (en güvenli varsayılan — yanlış direction yok).
  static Future<ApiStage> currentStage() async {
    final now = DateTime.now();
    if (_cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cached!;
    }

    try {
      final mk = _mk();
      final snap = await _fs.doc(_docPath).get();
      final d = snap.data() ?? <String, dynamic>{};

      final photoNew = (d['photo_new_$mk'] as int?) ?? 0;
      final photoLegacy = (d['photo_legacy_$mk'] as int?) ?? 0;
      final searchNew = (d['search_new_$mk'] as int?) ?? 0;
      final photoLimit = (d['photo_limit'] as int?) ?? _defaultPhotoLimit;
      final searchLimit =
          (d['search_new_limit'] as int?) ?? _defaultSearchNewLimit;

      final stage = _resolve(
        photoNew: photoNew,
        photoLegacy: photoLegacy,
        searchNew: searchNew,
        photoLimit: photoLimit,
        searchNewLimit: searchLimit,
      );

      _cached = stage;
      _cachedAt = now;
      // ignore: avoid_print
      'photoNew=$photoNew/$photoLimit '
          'photoLeg=$photoLegacy/$photoLimit ';
      return stage;
    } catch (e) {
      // ignore: avoid_print
      // Firestore erişilemezse son bilinen değeri veya güvenli varsayılanı döndür.
      return _cached ?? ApiStage.newWithPhotos;
    }
  }

  static ApiStage _resolve({
    required int photoNew,
    required int photoLegacy,
    required int searchNew,
    required int photoLimit,
    required int searchNewLimit,
  }) {
    if (photoNew < photoLimit) return ApiStage.newWithPhotos;
    if (photoLegacy < photoLimit) return ApiStage.legacyWithPhotos;
    if (searchNew < searchNewLimit) return ApiStage.newNoPhotos;
    return ApiStage.legacyNoPhotos;
  }

  // ── Sayaç güncelleme ─────────────────────────────────────────────────────

  /// Google'dan başarıyla bir fotoğraf indirildiğinde çağrılır.
  /// Fire-and-forget (`.ignore()` ile çağrılabilir).
  ///
  /// Counter yazılır → in-memory cache temizlenir → bir sonraki
  /// [currentStage] çağrısı taze Firestore verisini okur.
  static Future<void> recordPhotoFetch({required bool isNew}) async {
    final field = isNew ? 'photo_new_${_mk()}' : 'photo_legacy_${_mk()}';
    _cached = null; // stage yeniden hesaplanmalı
    try {
      await _fs.doc(_docPath).set({
        field: FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
    }
  }

  /// Nearby Search API çağrısı yapıldıktan sonra çağrılır.
  /// Fire-and-forget (`.ignore()` ile çağrılabilir).
  ///
  /// Legacy aramalarını şimdilik saymıyoruz (limit belirsiz); yalnızca
  /// New API aramaları stage geçişine katkı yapar.
  static Future<void> recordSearchCall({required bool isNew}) async {
    if (!isNew) return;
    final field = 'search_new_${_mk()}';
    _cached = null;
    try {
      await _fs.doc(_docPath).set({
        field: FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
    }
  }

  /// Stage cache'ini dışarıdan geçersiz kıl (test / force-refresh için).
  static void invalidateCache() {
    _cached = null;
    _cachedAt = null;
  }
}
