import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/notifiers/friends_notifier.dart';

// Ana friends notifier provider'ı
final friendsProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);

// Arama sorgusuna göre filtrelenmiş öneriler
final filteredSuggestionsProvider = Provider<List<UserFriendModel>>((ref) {
  return ref.watch(friendsProvider).filteredSuggestions;
});

// Mevcut bağlantılar (kabul edilmiş arkadaşlar)
final connectionsProvider = Provider<List<UserFriendModel>>((ref) {
  return ref.watch(friendsProvider).connections;
});

// Bekleyen davetler
final pendingInvitationsProvider = Provider<List<UserFriendModel>>((ref) {
  return ref.watch(friendsProvider).pendingInvitations;
});

// Friends yükleme durumu
final friendsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(friendsProvider).isLoading;
});

// Toplam bağlantı sayısı
final connectionsCountProvider = Provider<int>((ref) {
  return ref.watch(connectionsProvider).length;
});

// Bekleyen davet sayısı
final invitationsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingInvitationsProvider).length;
});

// Benim gönderdiğim bekleyen istekler
final sentRequestsProvider = Provider<List<UserFriendModel>>((ref) {
  return ref.watch(friendsProvider).sentRequests;
});

// ── Bir arkadaşın TOPLAM arkadaş sayısı ──────────────────────────────────────
//
// connectionsProvider sadece şu anki kullanıcının arkadaş listesini tutar —
// FriendProfilePage'de arkadaşımızın KENDİ arkadaş sayısını göstermek için
// Firestore'daki `friendships` koleksiyonunu o kullanıcının uid'siyle ayrıca
// sorguluyoruz (fromUid veya toUid eşleşip status==accepted olanlar).
final friendFriendsCountProvider = FutureProvider.family<int, String>((
  ref,
  uid,
) async {
  if (uid.isEmpty) return 0;
  try {
    final db = FirebaseFirestore.instance;
    final fromSnap = await db
        .collection('friendships')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final toSnap = await db
        .collection('friendships')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    return fromSnap.docs.length + toSnap.docs.length;
  } catch (_) {
    return 0;
  }
});
