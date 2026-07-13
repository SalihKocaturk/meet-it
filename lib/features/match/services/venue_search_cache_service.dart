import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetit/features/match/models/place_result.dart';

/// 💸 MALİYET DÜŞÜRME (2026-06-28): Asıl Places API maliyetinin BÜYÜK kısmı
/// fotoğraflardan değil, Nearby Search çağrısının KENDİSİNDEN geliyor (her
/// arama = 1 faturalanan istek). Bu servis ham Nearby Search sonuçlarını
/// konum+tip bazlı KALICI Firestore önbelleğine yazarak tekrar aramaların
/// Google'a gitmemesini sağlar.
///
/// 🗂️ SHARDING (2026-07-05): Firestore doküman boyutu 1MB ile sınırlıdır.
/// ~1.4KB/venue ile 500 venue ~700KB yapıyor — bu yeterli ama 1000+ venue
/// için sığmıyor. Çözüm: büyük havuzları `{key}__s0`, `{key}__s1` ... gibi
/// birden fazla shard dokümana böl. 400 venue/shard × 4 shard = 1600 venue
/// güvenle saklanabilir (~560KB/shard). Küçük havuzlar (<= 400 venue) ESKİ
/// FORMAT olarak tek dokümanda kalır — geriye dönük uyumluluk korunur.
class VenueSearchCacheService {
  VenueSearchCacheService._();

  static final _firestore = FirebaseFirestore.instance;
  static const String _collection = 'venueSearchCache';

  /// Shard başına maksimum venue sayısı (~560KB/shard @ 1.4KB/venue).
  static const int _maxShardSize = 400;

  /// Konumu ~1.1km'lik bir ızgaraya yuvarlar.
  static double _gridRound(double value) => (value * 100).roundToDouble() / 100;

  static String _buildKey({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
  }) {
    final sortedTypes = [...types]..sort();
    final raw = '${_gridRound(lat)}_${_gridRound(lng)}_r${radius}_'
        '${sortedTypes.join("-")}';
    return raw.replaceAll('/', '_').replaceAll('.', 'p');
  }

  /// Listeyi `size` büyüklüğünde parçalara böler.
  static List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, min(i + size, list.length)));
    }
    return chunks;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getCached
  // ─────────────────────────────────────────────────────────────────────────

  /// Önbellekte bu konum+tip kombinasyonu için bir havuz varsa döner;
  /// yoksa null (çağıran taraf Google'a gitmeli).
  ///
  /// İki format desteklenir:
  ///  • ESKİ FORMAT: `{key}` dokümanında `places` dizisi → doğrudan döner.
  ///  • SHARD FORMAT: `{key}` dokümanında `shards: N` → shard dokümanlarını
  ///    paralel okuyup birleştirir.
  static Future<List<PlaceResult>?> getCached({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
  }) async {
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    try {
      final snap = await _firestore.collection(_collection).doc(key).get();
      final data = snap.data();
      if (data == null) return null;

      // Eski format: places dizisi doğrudan burada
      if (data.containsKey('places')) {
        final places = (data['places'] as List<dynamic>? ?? [])
            .map((p) => PlaceResult.fromStorageMap(p as Map<String, dynamic>))
            .toList();
        return places.isEmpty ? null : places;
      }

      // Shard format: N shard dokümanı paralel okunur
      final shardCount = (data['shards'] as int?) ?? 0;
      if (shardCount == 0) return null;

      final shardSnaps = await Future.wait([
        for (int i = 0; i < shardCount; i++)
          _firestore.collection(_collection).doc('${key}__s$i').get(),
      ]);

      final all = <PlaceResult>[];
      for (final s in shardSnaps) {
        final rows = (s.data()?['places'] as List<dynamic>? ?? [])
            .map((p) => PlaceResult.fromStorageMap(p as Map<String, dynamic>))
            .toList();
        all.addAll(rows);
      }
      return all.isEmpty ? null : all;
    } catch (e) {
      // ignore: avoid_print
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // setCached
  // ─────────────────────────────────────────────────────────────────────────

  /// Google'dan TAZE çekilen ham sonuç havuzunu önbelleğe yazar.
  ///
  /// • `places.length <= _maxShardSize` → ESKİ FORMAT (tek doküman, `places` alanı)
  ///   — geriye dönük uyumluluk.
  /// • `places.length > _maxShardSize` → SHARD FORMAT — havuz shard
  ///   dokümanlarına bölünür, metadata `{key}` dokümanına yazılır.
  static Future<void> setCached({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
    required List<PlaceResult> places,
  }) async {
    if (places.isEmpty) return;
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    try {
      if (places.length <= _maxShardSize) {
        // Eski format — tek doküman
        await _firestore.collection(_collection).doc(key).set({
          'places': places.map((p) => p.toStorageMap()).toList(),
          'cachedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Shard format — batch write
        final chunks = _chunk(places, _maxShardSize);
        final batch = _firestore.batch();
        for (int i = 0; i < chunks.length; i++) {
          final shardRef =
              _firestore.collection(_collection).doc('${key}__s$i');
          batch.set(shardRef, {
            'places': chunks[i].map((p) => p.toStorageMap()).toList(),
          });
        }
        // Metadata dokümanı — `places` alanı YOK, sadece shard sayısı
        batch.set(_firestore.collection(_collection).doc(key), {
          'shards': chunks.length,
          'cachedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        // ignore: avoid_print
      }
    } catch (e) {
      // ignore: avoid_print
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getExpandedAt
  // ─────────────────────────────────────────────────────────────────────────

  /// Son havuz genişleme zamanını döner; alan yoksa null döner.
  static Future<DateTime?> getExpandedAt({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
  }) async {
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    try {
      final snap = await _firestore.collection(_collection).doc(key).get();
      final ts = snap.data()?['expandedAt'] as Timestamp?;
      return ts?.toDate();
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // mergeExpand
  // ─────────────────────────────────────────────────────────────────────────

  /// Mevcut havuza `newPlaces`'i ekler (dedup + `maxSize` sınırı).
  ///
  /// Toplam venue sayısına göre `setCached` formatı seçer (eski / shard).
  /// Ardından metadata dokümanındaki `expandedAt` alanını günceller.
  static Future<void> mergeExpand({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
    required List<PlaceResult> existing,
    required List<PlaceResult> newPlaces,
    required int maxSize,
  }) async {
    if (newPlaces.isEmpty) return;
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    final seen = <String>{};
    final merged = <PlaceResult>[];
    for (final p in existing) {
      if (seen.add(p.placeId)) merged.add(p);
    }
    var added = 0;
    for (final p in newPlaces) {
      if (merged.length >= maxSize) break;
      if (seen.add(p.placeId)) {
        merged.add(p);
        added++;
      }
    }
    if (added == 0) return;
    try {
      // setCached format seçimini halleder (eski veya shard)
      await setCached(
        lat: lat,
        lng: lng,
        types: types,
        radius: radius,
        places: merged,
      );
      // expandedAt metadata dokümanına merge ile yaz
      await _firestore.collection(_collection).doc(key).set(
            {'expandedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
      // ignore: avoid_print
    } catch (e) {
      // ignore: avoid_print
    }
  }
}
