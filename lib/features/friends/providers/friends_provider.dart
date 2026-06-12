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
