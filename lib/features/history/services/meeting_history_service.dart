import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetit/features/history/models/meeting_record.dart';

/// Geçmiş buluşma kayıtlarını Firestore'a yazan ve okuyan servis.
///
/// Koleksiyon: `meetingHistory/{autoId}`
/// Sorgu indeksi gereksinimi:
///   participantUids (array-contains) + createdAt (desc)
///   → Firebase Console'dan ya da `firestore.indexes.json` üzerinden ekle.
class MeetingHistoryService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'meetingHistory';

  /// Yeni bir buluşma kaydı oluşturur ve otomatik üretilen Firestore ID'sini döner.
  static Future<String> save(MeetingRecord record) async {
    final ref = _db.collection(_col).doc();
    await ref.set(record.toMap());
    return ref.id;
  }

  /// Verilen uid'e ait buluşma kayıtlarını en yeniden eskiye doğru akıtır.
  ///
  /// `participantUids` alanı hem initiator hem de friend UID'sini içerdiğinden,
  /// tek bir sorgu her iki tarafın da geçmişini döndürebilir.
  static Stream<List<MeetingRecord>> historyStream(String uid) {
    return _db
        .collection(_col)
        .where('participantUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(MeetingRecord.fromDoc).toList(),
        );
  }
}
