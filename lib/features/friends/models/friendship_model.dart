/// Firestore `friendships` koleksiyonundaki tek bir arkadaşlık kaydı.
///
/// Doc ID: küçük uid + '_' + büyük uid (simetrik, duplicate olmaz)
class FriendshipModel {
  final String id;
  final String fromUid; // isteği gönderen
  final String toUid;   // isteği alan
  final FriendshipStatus status;
  final DateTime createdAt;

  const FriendshipModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  FriendshipModel copyWith({FriendshipStatus? status}) => FriendshipModel(
        id: id,
        fromUid: fromUid,
        toUid: toUid,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

enum FriendshipStatus { pending, accepted, rejected }
