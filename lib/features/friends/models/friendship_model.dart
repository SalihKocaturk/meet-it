/// Firestore `friendships` koleksiyonundaki tek bir arkadaşlık kaydı.
///
/// Doc ID: küçük uid + '_' + büyük uid (simetrik, duplicate olmaz)
class FriendshipModel {
  final String id;
  final String fromUid; // isteği gönderen
  final String toUid;   // isteği alan
  final FriendshipStatus status;
  final DateTime createdAt;

  /// Bu arkadaşla "Buluş" butonuna kaç kez basıldığı (her iki taraf da
  /// sayılır — dokümana yön bağımsız, çift taraflı tek sayaç). Ana
  /// sayfadaki "Arkadaşların" listesi, en sık buluşulan kişiye öncelik
  /// vermek için bununla sıralanıyor (bkz. home_page.dart).
  final int meetCount;

  const FriendshipModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
    this.meetCount = 0,
  });

  /// İki uid'den deterministik doc ID üret
  static String docId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  factory FriendshipModel.fromMap(String id, Map<String, dynamic> map) {
    return FriendshipModel(
      id: id,
      fromUid: map['fromUid'] as String,
      toUid: map['toUid'] as String,
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      meetCount: (map['meetCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'meetCount': meetCount,
      };

  FriendshipModel copyWith({FriendshipStatus? status, int? meetCount}) =>
      FriendshipModel(
        id: id,
        fromUid: fromUid,
        toUid: toUid,
        status: status ?? this.status,
        createdAt: createdAt,
        meetCount: meetCount ?? this.meetCount,
      );
}

enum FriendshipStatus { pending, accepted, rejected }
