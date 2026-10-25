import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Konum isteği ─────────────────────────────────────────────────────────────
//
// Uygulaması olmayan arkadaşla buluşma: kullanıcı bir link paylaşır,
// arkadaş web sayfasında (konum/) konumunu tek dokunuşla gönderir, uygulama
// ikisinin ortasındaki mekanları bulur ve sonuçları aynı dokümana yazar —
// arkadaş da önerileri web'de görür. Firestore: locationRequests/{id}.

enum LocationRequestStatus { waiting, shared, done }

class LocationRequest {
  final String id;
  final String ownerUid;
  final String ownerName;
  final LocationRequestStatus status;
  final String? friendName;
  final double? friendLat;
  final double? friendLng;

  const LocationRequest({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.status,
    this.friendName,
    this.friendLat,
    this.friendLng,
  });

  bool get hasFriendLocation => friendLat != null && friendLng != null;

  factory LocationRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return LocationRequest(
      id: d.id,
      ownerUid: m['ownerUid'] as String? ?? '',
      ownerName: m['ownerName'] as String? ?? '',
      status: LocationRequestStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => LocationRequestStatus.waiting,
      ),
      friendName: (m['friendName'] as String?)?.trim(),
      friendLat: (m['friendLat'] as num?)?.toDouble(),
      friendLng: (m['friendLng'] as num?)?.toDouble(),
    );
  }
}

abstract final class LocationRequestService {
  static final _col = FirebaseFirestore.instance.collection('locationRequests');

  static Future<String> create({
    required String ownerUid,
    required String ownerName,
  }) async {
    final ref = await _col.add({
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'status': LocationRequestStatus.waiting.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Bulunan mekanları arkadaşın web sayfasında görünsün diye yazar.
  static Future<void> publishResults(
    String requestId,
    List<PlaceResult> venues,
  ) async {
    try {
      await _col.doc(requestId).update({
        'status': LocationRequestStatus.done.name,
        'results': [
          for (final v in venues.take(5))
            {
              'name': v.name,
              if (v.vicinity != null) 'address': v.vicinity,
              if (v.rating != null) 'rating': v.rating,
              'mapsUrl': v.googleMapsUrl,
            },
        ],
        'resultsAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[LocationRequest] publishResults hatası: $e');
    }
  }

  static Future<void> delete(String requestId) async {
    try {
      await _col.doc(requestId).delete();
    } catch (_) {}
  }

  static Stream<LocationRequest?> watch(String requestId) => _col
      .doc(requestId)
      .snapshots()
      .map((d) => d.exists ? LocationRequest.fromDoc(d) : null);
}

/// Kullanıcının aktif (beklenen / paylaşılmış) konum isteğinin id'si.
/// Uygulama kapanıp açılsa da korunur.
class ActiveLocationRequestNotifier extends Notifier<String?> {
  static const _kKey = 'active_location_request';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kKey);
      if (id != null && state == null) state = id;
    } catch (_) {}
  }

  Future<void> set(String? id) async {
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_kKey);
      } else {
        await prefs.setString(_kKey, id);
      }
    } catch (_) {}
  }

  /// Yeni bir istek oluşturur ve aktif yapar; paylaşılacak id'yi döner.
  Future<String?> createNew() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    try {
      final id = await LocationRequestService.create(
        ownerUid: user.uid,
        ownerName: user.isGuest ? '' : user.name,
      );
      await set(id);
      return id;
    } catch (e) {
      debugPrint('[LocationRequest] create hatası: $e');
      return null;
    }
  }
}

final activeLocationRequestIdProvider =
    NotifierProvider<ActiveLocationRequestNotifier, String?>(
  ActiveLocationRequestNotifier.new,
);

/// Aktif isteğin canlı hali (yoksa null).
final activeLocationRequestProvider =
    StreamProvider.autoDispose<LocationRequest?>((ref) {
  final id = ref.watch(activeLocationRequestIdProvider);
  if (id == null) return Stream.value(null);
  return LocationRequestService.watch(id);
});
