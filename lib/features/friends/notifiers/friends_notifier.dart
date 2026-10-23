import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/services/notification_service.dart';
import 'package:meetit/core/utils/geo_utils.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/friendship_model.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class FriendsState {
  final List<UserFriendModel> suggestions;      // arkadaş olmayan kullanıcılar
  final List<UserFriendModel> connections;      // accepted arkadaşlar
  final List<UserFriendModel> pendingInvitations; // bana gelen pending istekler
  final List<UserFriendModel> sentRequests;     // benim gönderdiğim pending istekler
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  /// Benim engellediklerim + beni engelleyenler (iki yönlü gizleme).
  final Set<String> blockedUids;

  /// Arkadaş olmayan kullanıcılarla kaç ortak arkadaşım var (uid → sayı).
  /// "Tanıyor Olabilirsin" listesi yalnızca ortak arkadaşı olanları gösterir.
  final Map<String, int> mutualCounts;

  /// Arkadaş olmayan kullanıcıların uid'leri, bana en yakından uzağa.
  /// Ortak arkadaşlı öneri azsa liste bunlarla tamamlanır.
  final List<String> nearbyOrder;

  /// Arama yokken en az kaç öneri gösterilsin (uygulama yeniyken kimsenin
  /// ortak arkadaşı olmayabilir — liste boş kalmasın).
  static const int minSuggestions = 5;

  const FriendsState({
    this.suggestions = const [],
    this.connections = const [],
    this.pendingInvitations = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.blockedUids = const {},
    this.mutualCounts = const {},
    this.nearbyOrder = const [],
  });

  /// Öneriler sekmesinde gösterilecek liste.
  ///
  /// Önceden arkadaş olmayan TÜM kullanıcılar listeleniyordu — kullanıcı az
  /// olduğu için herkes herkesin önerilerinde görünüyordu. Artık:
  ///  • Arama yokken: önce ortak arkadaşı olanlar (en çok olan üstte). Bunlar
  ///    [minSuggestions]'dan azsa liste, bana en yakın kullanıcılarla
  ///    tamamlanır — böylece herkes listelenmez ama liste de boş kalmaz.
  ///  • Arama varken (en az 2 harf): isme göre tüm kullanıcılarda arama —
  ///    tanıdığını ismiyle bulup ekleyebilsin diye.
  List<UserFriendModel> get filteredSuggestions {
    final q = searchQuery.trim().toLowerCase();
    if (q.length >= 2) {
      return suggestions.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    final mutual = suggestions
        .where((f) => (mutualCounts[f.uid] ?? 0) > 0)
        .toList()
      ..sort((a, b) =>
          (mutualCounts[b.uid] ?? 0).compareTo(mutualCounts[a.uid] ?? 0));
    if (mutual.length >= minSuggestions) return mutual;

    final shown = mutual.map((f) => f.uid).toSet();
    final byUid = {for (final f in suggestions) f.uid: f};
    final extra = nearbyOrder
        .where((uid) => !shown.contains(uid))
        .map((uid) => byUid[uid])
        .whereType<UserFriendModel>()
        .take(minSuggestions - mutual.length);
    return [...mutual, ...extra];
  }

  FriendsState copyWith({
    List<UserFriendModel>? suggestions,
    List<UserFriendModel>? connections,
    List<UserFriendModel>? pendingInvitations,
    List<UserFriendModel>? sentRequests,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    Set<String>? blockedUids,
    Map<String, int>? mutualCounts,
    List<String>? nearbyOrder,
  }) {
    return FriendsState(
      suggestions: suggestions ?? this.suggestions,
      connections: connections ?? this.connections,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      blockedUids: blockedUids ?? this.blockedUids,
      mutualCounts: mutualCounts ?? this.mutualCounts,
      nearbyOrder: nearbyOrder ?? this.nearbyOrder,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FriendsNotifier extends Notifier<FriendsState> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _friendshipSub;

  @override
  FriendsState build() {
    final currentUid = ref.watch(authProvider).user?.uid;
    ref.onDispose(() => _friendshipSub?.cancel());
    if (currentUid != null) {
      Future(() => _listenFriendships(currentUid));
    }
    return const FriendsState(isLoading: true);
  }

  Future<void> _listenFriendships(String currentUid) async {
    try {
    // Engellenen / engelleyen kullanıcıları yükle — listelerde hiç görünmesinler.
    await _loadBlocks(currentUid);

    // Önce tüm kullanıcıları bir kere çek
    final usersSnap = await _db.collection('users').get();
    final everyone =
        usersSnap.docs.map((d) => UserModel.fromMap(d.data())).toList();
    final me = everyone.where((u) => u.uid == currentUid).firstOrNull;
    final allUsers = everyone.where((u) => u.uid != currentUid).toList();

    // Friendships'i realtime dinle
    _friendshipSub?.cancel();
    _friendshipSub = _db
        .collection('friendships')
        .where(Filter.or(
          Filter('fromUid', isEqualTo: currentUid),
          Filter('toUid', isEqualTo: currentUid),
        ))
        .snapshots()
        .listen((snap) async {
      final friendships = snap.docs
          .map((d) => FriendshipModel.fromMap(d.id, d.data()))
          .toList();

      // Kullanıcı listesi açılışta bir kez çekiliyor. Sonradan katılan biri
      // (ör. davet linkiyle gelen yeni kullanıcı) arkadaşlık kurduğunda
      // listede yok — eksik kişileri tek tek çekip ekle ki bağlantılarda
      // hemen görünsün.
      final knownUids = allUsers.map((u) => u.uid).toSet();
      final missing = <String>{};
      for (final f in friendships) {
        final other = f.fromUid == currentUid ? f.toUid : f.fromUid;
        if (!knownUids.contains(other)) missing.add(other);
      }
      if (missing.isNotEmpty) {
        final fetched = await Future.wait(missing.map((uid) async {
          try {
            final doc = await _db.collection('users').doc(uid).get();
            final data = doc.data();
            return data == null ? null : UserModel.fromMap(data);
          } catch (_) {
            return null;
          }
        }));
        allUsers.addAll(fetched.whereType<UserModel>());
      }

      final acceptedUids = <String>{};
      final pendingFromMe = <String>{};
      final pendingToMe = <String>{};
      // Her arkadaşın meetCount'u — doğrudan friendship dokümanından
      // okunuyor (yön bağımsız, tek bir paylaşılan sayaç, bkz.
      // FriendshipModel.meetCount).
      final meetCounts = <String, int>{};

      for (final f in friendships) {
        final otherUid =
            f.fromUid == currentUid ? f.toUid : f.fromUid;
        meetCounts[otherUid] = f.meetCount;
        switch (f.status) {
          case FriendshipStatus.accepted:
            acceptedUids.add(otherUid);
          case FriendshipStatus.pending:
            if (f.fromUid == currentUid) {
              pendingFromMe.add(otherUid);
            } else {
              pendingToMe.add(otherUid);
            }
          case FriendshipStatus.rejected:
            break;
        }
      }

      final suggestions = <UserFriendModel>[];
      final connections = <UserFriendModel>[];
      final pendingInvitations = <UserFriendModel>[];
      final sentRequests = <UserFriendModel>[];

      for (final u in allUsers) {
        if (_blockedUids.contains(u.uid)) continue;
        final friend = UserFriendModel(
          uid: u.uid,
          name: u.name,
          photoUrl: u.photoUrl,
          status: acceptedUids.contains(u.uid)
              ? FriendStatus.accepted
              : FriendStatus.pending,
          addedAt: DateTime.now(),
          personalityProfile: u.personalityProfile,
          meetCount: meetCounts[u.uid] ?? 0,
          gender: u.gender,
          lat: u.lat,
          lng: u.lng,
        );
        if (acceptedUids.contains(u.uid)) {
          connections.add(friend);
        } else if (pendingToMe.contains(u.uid)) {
          pendingInvitations.add(friend);
        } else if (pendingFromMe.contains(u.uid)) {
          sentRequests.add(friend);
        } else {
          suggestions.add(friend);
        }
      }

      // Öneri listesi ortak arkadaşla dolmazsa yakındakilerle tamamlanır.
      final myLat = me?.lat;
      final myLng = me?.lng;
      double distanceOf(UserFriendModel f) =>
          (myLat == null || myLng == null || f.lat == null || f.lng == null)
              ? double.infinity
              : GeoUtils.haversineKm(myLat, myLng, f.lat!, f.lng!);
      final nearbyOrder = ([...suggestions]
            ..sort((a, b) => distanceOf(a).compareTo(distanceOf(b))))
          .map((f) => f.uid)
          .toList();

      state = state.copyWith(
        suggestions: suggestions,
        connections: connections,
        pendingInvitations: pendingInvitations,
        sentRequests: sentRequests,
        nearbyOrder: nearbyOrder,
        isLoading: false,
      );

      // Ortak arkadaş sayıları arkadaş listesi değiştikçe yeniden hesaplanır.
      _loadMutualCounts(acceptedUids).ignore();
    });
    } catch (e) {
      debugPrint('[FriendsNotifier] _listenFriendships hatası: $e — 3sn sonra tekrar deneniyor');
      await Future.delayed(const Duration(seconds: 3));
      if (ref.read(authProvider).user?.uid == currentUid) {
        await _listenFriendships(currentUid);
      }
    }
  }

  // ── Yükleme ───────────────────────────────────────────────────────────────

  Future<void> loadAll(String currentUid) async =>
      _listenFriendships(currentUid);

  // ── Engelleme ─────────────────────────────────────────────────────────────

  /// Benim engellediklerim + beni engelleyenler. İki yönde de kişi
  /// listelerde görünmez; Firestore kuralı (isBlockedPair) aralarında
  /// arkadaşlık isteği oluşturulmasını da sunucu tarafında engeller.
  Set<String> get _blockedUids => state.blockedUids;

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  Future<void> _loadBlocks(String currentUid) async {
    final uids = <String>{};
    try {
      final mine = await _db
          .collection('blocks')
          .where('blockerUid', isEqualTo: currentUid)
          .get();
      for (final d in mine.docs) {
        final other = d.data()['blockedUid'];
        if (other is! String) continue;
        uids.add(other);
        // Eski sürümlerin rastgele ID ile yazdığı kayıtları deterministik
        // ID'ye taşı — Firestore kuralı (isBlockedPair) sadece onu görür.
        final expectedId = '${currentUid}_$other';
        if (d.id != expectedId) {
          try {
            await _db.collection('blocks').doc(expectedId).set({
              'blockerUid': currentUid,
              'blockedUid': other,
              'createdAt':
                  d.data()['createdAt'] ?? FieldValue.serverTimestamp(),
            });
            await d.reference.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FriendsNotifier] _loadBlocks (mine) hatası: $e');
    }
    try {
      final theirs = await _db
          .collection('blocks')
          .where('blockedUid', isEqualTo: currentUid)
          .get();
      for (final d in theirs.docs) {
        final other = d.data()['blockerUid'];
        if (other is String) uids.add(other);
      }
    } catch (e) {
      debugPrint('[FriendsNotifier] _loadBlocks (theirs) hatası: $e');
    }
    state = state.copyWith(blockedUids: uids);
  }

  /// Ayarlar > Engellenenler için: benim engellediğim kullanıcılar.
  Future<List<BlockedUser>> fetchMyBlockedUsers() async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return const [];
    final snap = await _db
        .collection('blocks')
        .where('blockerUid', isEqualTo: currentUid)
        .get();
    final uids = <String>{
      for (final d in snap.docs)
        if (d.data()['blockedUid'] is String) d.data()['blockedUid'] as String,
    };
    final users = await Future.wait(uids.map((uid) async {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data();
        return BlockedUser(
          uid: uid,
          name: (data?['name'] as String?) ?? '',
          photoUrl: data?['photoUrl'] as String?,
        );
      } catch (_) {
        return BlockedUser(uid: uid, name: '');
      }
    }));
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  /// Engeli kaldır — benim bu kişi için yazdığım tüm engel kayıtları silinir,
  /// sonra listeler yeniden kurulur (karşı taraf da beni engellediyse
  /// gizlenmeye devam eder).
  Future<bool> unblockUser(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return false;
    try {
      final snap = await _db
          .collection('blocks')
          .where('blockerUid', isEqualTo: currentUid)
          .where('blockedUid', isEqualTo: targetUid)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('[FriendsNotifier] unblockUser hatası: $e');
      return false;
    }
    state = state.copyWith(
      blockedUids: {..._blockedUids}..remove(targetUid),
    );
    unawaited(_listenFriendships(currentUid));
    return true;
  }

  /// Kullanıcıyı engelle: blocks/{benimUid}_{hedefUid} yazılır, varsa
  /// aradaki arkadaşlık / istek silinir ve kişi tüm listelerden çıkar.
  Future<bool> blockUser(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return false;

    try {
      await _db.collection('blocks').doc('${currentUid}_$targetUid').set({
        'blockerUid': currentUid,
        'blockedUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FriendsNotifier] blockUser hatası: $e');
      return false;
    }

    state = state.copyWith(blockedUids: {..._blockedUids, targetUid});

    try {
      await _db
          .collection('friendships')
          .doc(FriendshipModel.docId(currentUid, targetUid))
          .delete();
    } catch (_) {
      // Arkadaşlık dokümanı yoksa sorun değil.
    }

    bool keep(UserFriendModel f) => f.uid != targetUid;
    state = state.copyWith(
      suggestions: state.suggestions.where(keep).toList(),
      connections: state.connections.where(keep).toList(),
      pendingInvitations: state.pendingInvitations.where(keep).toList(),
      sentRequests: state.sentRequests.where(keep).toList(),
    );
    return true;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Arkadaşlık isteği gönder
  ///
  /// 🐛 BUG FIX (2026-06-29): Daha önce burada doğrudan `.set()` ile
  /// dokümanın üzerine yazılıyordu. Karşı taraf ZATEN bana istek
  /// göndermişse (yani aynı `docId`'de `fromUid == targetUid` olan
  /// `pending` bir kayıt varsa), bu `.set()` o kaydın üzerine
  /// `fromUid`/`toUid`'i TERSİNE çevirip yeniden `pending` yazıyordu —
  /// hiçbir zaman `accepted`'a dönüşmüyordu. Sonuç: iki taraf da
  /// birbirine istek atınca arkadaşlık asla kurulmuyor, pending/sent
  /// listeleri sürekli birbirine karışıyordu (kullanıcının bildirdiği
  /// "bug").
  ///
  /// Çözüm: yazmadan ÖNCE mevcut dokümanı oku. Eğer karşı taraf zaten
  /// bana `pending` istek göndermişse, yeni bir istek YOLLAMA — direkt
  /// `accepted` yap (karşılıklı istek = otomatik eşleşme). Aksi halde
  /// eskisi gibi yeni bir `pending` istek oluştur. Race condition'a karşı
  /// hepsi bir transaction içinde.
  Future<void> sendFriendRequest(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;
    if (_blockedUids.contains(targetUid)) return;

    final docId = FriendshipModel.docId(currentUid, targetUid);
    final docRef = _db.collection('friendships').doc(docId);

    try {
      var mutualMatch = false;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);

        if (snap.exists) {
          final existing = FriendshipModel.fromMap(docId, snap.data()!);

          if (existing.status == FriendshipStatus.accepted) {
            // Zaten arkadaşlar — tekrar istek atmaya çalışmanın anlamı yok.
            return;
          }

          if (existing.status == FriendshipStatus.pending &&
              existing.fromUid == targetUid) {
            // Karşı taraf bana ZATEN istek göndermiş — benim de ona istek
            // atmam, bu karşılıklı isteği doğrudan kabul etmek demektir.
            tx.update(docRef, {'status': FriendshipStatus.accepted.name});
            mutualMatch = true;
            return;
          }

          // Reddedilmiş ya da benim daha önce attığım pending bir istek
          // varsa, yeniden (benim adıma) pending olarak yaz.
        }

        final friendship = FriendshipModel(
          id: docId,
          fromUid: currentUid,
          toUid: targetUid,
          status: FriendshipStatus.pending,
          createdAt: DateTime.now(),
        );
        tx.set(docRef, friendship.toMap());
      });

      // Yerel state güncelle — suggestions/pendingInvitations'dan çıkar,
      // mutualMatch ise direkt connections'a, değilse sentRequests'e ekle.
      final fromSuggestions =
          state.suggestions.where((f) => f.uid == targetUid).toList();
      final fromPendingInvitations =
          state.pendingInvitations.where((f) => f.uid == targetUid).toList();
      final friend = (fromSuggestions + fromPendingInvitations).firstOrNull;

      if (friend == null) return;

      // Bildirim gönder
      final myName = ref.read(authProvider).user?.name ?? '';
      if (mutualMatch) {
        // Karşılıklı istek = her iki taraf da arkadaş oldu
        // targetUid zaten kendi isteğini gönderdiği için ona "accepted" bildirimi
        NotificationService.sendNotification(
          toUid: targetUid,
          type: 'friend_accepted',
          fromName: myName,
          fromUid: currentUid,
        ).ignore();
        state = state.copyWith(
          suggestions:
              state.suggestions.where((f) => f.uid != targetUid).toList(),
          pendingInvitations: state.pendingInvitations
              .where((f) => f.uid != targetUid)
              .toList(),
          connections: [
            ...state.connections,
            friend.copyWith(status: FriendStatus.accepted),
          ],
        );
      } else {
        // Normal arkadaşlık isteği — hedef kullanıcıya bildir
        NotificationService.sendNotification(
          toUid: targetUid,
          type: 'friend_request',
          fromName: myName,
          fromUid: currentUid,
        ).ignore();
        state = state.copyWith(
          suggestions:
              state.suggestions.where((f) => f.uid != targetUid).toList(),
          sentRequests: [...state.sentRequests, friend],
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'friends.error_send'.tr());
    }
  }

  /// Gelen isteği kabul et
  Future<void> acceptInvitation(String fromUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, fromUid);

    try {
      await _db
          .collection('friendships')
          .doc(docId)
          .update({'status': FriendshipStatus.accepted.name});

      // İsteği gönderen kişiye "kabul edildi" bildirimi gönder
      final myName = ref.read(authProvider).user?.name ?? '';
      NotificationService.sendNotification(
        toUid: fromUid,
        type: 'friend_accepted',
        fromName: myName,
        fromUid: currentUid,
      ).ignore();

      final friend = state.pendingInvitations.firstWhere((f) => f.uid == fromUid);
      state = state.copyWith(
        pendingInvitations:
            state.pendingInvitations.where((f) => f.uid != fromUid).toList(),
        connections: [
          ...state.connections,
          friend.copyWith(status: FriendStatus.accepted),
        ],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'friends.error_accept'.tr());
    }
  }

  /// Gelen isteği reddet
  Future<void> rejectInvitation(String fromUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, fromUid);

    try {
      await _db
          .collection('friendships')
          .doc(docId)
          .update({'status': FriendshipStatus.rejected.name});

      state = state.copyWith(
        pendingInvitations:
            state.pendingInvitations.where((f) => f.uid != fromUid).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'friends.error_reject'.tr());
    }
  }

  /// Gönderilen isteği iptal et
  Future<void> cancelSentRequest(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, targetUid);

    try {
      await _db.collection('friendships').doc(docId).delete();

      final cancelled =
          state.sentRequests.firstWhere((f) => f.uid == targetUid);
      state = state.copyWith(
        sentRequests:
            state.sentRequests.where((f) => f.uid != targetUid).toList(),
        suggestions: [
          ...state.suggestions,
          cancelled.copyWith(status: FriendStatus.pending)
        ],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'friends.error_cancel'.tr());
    }
  }

  /// Arkadaşı çıkar
  Future<void> removeFriend(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, targetUid);

    try {
      await _db.collection('friendships').doc(docId).delete();

      final removed = state.connections.firstWhere((f) => f.uid == targetUid);
      state = state.copyWith(
        connections: state.connections.where((f) => f.uid != targetUid).toList(),
        suggestions: [...state.suggestions, removed.copyWith(status: FriendStatus.pending)],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Arkadaş çıkarılırken hata oluştu.');
    }
  }

  /// Bir öneriyi listeden kapat (henüz arkadaş olunmadığı için
  /// Firestore'da silinecek bir friendship dokümanı yok — sadece
  /// yerel state'ten çıkarılır).
  void dismissSuggestion(String targetUid) {
    state = state.copyWith(
      suggestions: state.suggestions.where((f) => f.uid != targetUid).toList(),
    );
  }

  int _mutualGen = 0;

  /// Arkadaşlarımın kabul edilmiş arkadaşlıklarını okuyup, arkadaşım
  /// olmayan her kullanıcı için kaç ortak arkadaşımız olduğunu sayar.
  /// Firestore `whereIn` en fazla 30 değer aldığı için arkadaş listesi
  /// 30'luk parçalar halinde sorgulanır.
  Future<void> _loadMutualCounts(Set<String> friendUids) async {
    final gen = ++_mutualGen;
    if (friendUids.isEmpty) {
      state = state.copyWith(mutualCounts: const {});
      return;
    }
    final counts = <String, int>{};
    final seenDocs = <String>{};
    final ids = friendUids.toList();
    try {
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, min(i + 30, ids.length));
        final snaps = await Future.wait([
          _db.collection('friendships').where('fromUid', whereIn: chunk).get(),
          _db.collection('friendships').where('toUid', whereIn: chunk).get(),
        ]);
        for (final snap in snaps) {
          for (final doc in snap.docs) {
            if (!seenDocs.add(doc.id)) continue;
            final data = doc.data();
            if (data['status'] != FriendshipStatus.accepted.name) continue;
            final a = data['fromUid'] as String?;
            final b = data['toUid'] as String?;
            if (a == null || b == null) continue;
            final aIsFriend = friendUids.contains(a);
            final bIsFriend = friendUids.contains(b);
            // İki uç da zaten arkadaşımsa ya da hiçbiri değilse sayılmaz.
            if (aIsFriend == bIsFriend) continue;
            final other = aIsFriend ? b : a;
            counts[other] = (counts[other] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint('[FriendsNotifier] ortak arkadaş hesabı hatası: $e');
      return;
    }
    if (gen != _mutualGen) return; // daha yeni bir hesap başladı
    state = state.copyWith(mutualCounts: counts);
  }

  void updateSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  /// Bir arkadaşla "Buluş" butonuna basıldığında çağrılır (home_page.dart ve
  /// friends_page.dart'taki bağlantı kartlarından). Sayaç, friendship
  /// dokümanı üzerinde tutuluyor — bu sayede yön (kim arkadaş isteği
  /// gönderdi) önemsiz, iki taraf da aynı sayacı paylaşıyor ve ana
  /// sayfadaki "Arkadaşların" listesi en sık buluşulan kişiye göre
  /// sıralanabiliyor (bkz. home_page.dart).
  ///
  /// Firestore tarafı FieldValue.increment ile atomik artırılıyor; yerel
  /// state ise optimistic olarak güncelleniyor ki kullanıcı butona basar
  /// basmaz sıralama değişikliğini (varsa) hemen görsün — bir sonraki
  /// snapshot zaten gerçek değeri getirip üzerine yazacak.
  Future<void> incrementMeetCount(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, targetUid);

    // Optimistic local update — connections listesindeki ilgili arkadaşın
    // meetCount'unu hemen bir artır.
    final idx = state.connections.indexWhere((f) => f.uid == targetUid);
    if (idx != -1) {
      final updated = List<UserFriendModel>.from(state.connections);
      updated[idx] =
          updated[idx].copyWith(meetCount: updated[idx].meetCount + 1);
      state = state.copyWith(connections: updated);
    }

    try {
      await _db
          .collection('friendships')
          .doc(docId)
          .update({'meetCount': FieldValue.increment(1)});
    } catch (_) {
      // Sessizce yut — bu sadece bir sıralama/öncelik sinyali, kullanıcının
      // asıl işlemi (buluşma akışına geçiş) bundan etkilenmemeli.
    }
  }
}

class BlockedUser {
  final String uid;
  final String name;
  final String? photoUrl;

  const BlockedUser({required this.uid, required this.name, this.photoUrl});
}
