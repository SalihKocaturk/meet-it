import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const FriendsState({
    this.suggestions = const [],
    this.connections = const [],
    this.pendingInvitations = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  List<UserFriendModel> get filteredSuggestions {
    if (searchQuery.isEmpty) return suggestions;
    return suggestions
        .where((f) => f.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
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
  }) {
    return FriendsState(
      suggestions: suggestions ?? this.suggestions,
      connections: connections ?? this.connections,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
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
    // Önce tüm kullanıcıları bir kere çek
    final usersSnap = await _db.collection('users').get();
    final allUsers = usersSnap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((u) => u.uid != currentUid)
        .toList();

    // Friendships'i realtime dinle
    _friendshipSub?.cancel();
    _friendshipSub = _db
        .collection('friendships')
        .where(Filter.or(
          Filter('fromUid', isEqualTo: currentUid),
          Filter('toUid', isEqualTo: currentUid),
        ))
        .snapshots()
        .listen((snap) {
      final friendships = snap.docs
          .map((d) => FriendshipModel.fromMap(d.id, d.data()))
          .toList();

      final acceptedUids = <String>{};
      final pendingFromMe = <String>{};
      final pendingToMe = <String>{};

      for (final f in friendships) {
        final otherUid =
            f.fromUid == currentUid ? f.toUid : f.fromUid;
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
        final friend = UserFriendModel(
          uid: u.uid,
          name: u.name,
          photoUrl: u.photoUrl,
          status: acceptedUids.contains(u.uid)
              ? FriendStatus.accepted
              : FriendStatus.pending,
          addedAt: DateTime.now(),
          personalityProfile: u.personalityProfile,
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

      state = state.copyWith(
        suggestions: suggestions,
        connections: connections,
        pendingInvitations: pendingInvitations,
        sentRequests: sentRequests,
        isLoading: false,
      );
    });
  }

  // ── Yükleme ───────────────────────────────────────────────────────────────

  Future<void> loadAll(String currentUid) async =>
      _listenFriendships(currentUid);

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Arkadaşlık isteği gönder
  Future<void> sendFriendRequest(String targetUid) async {
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    final docId = FriendshipModel.docId(currentUid, targetUid);

    try {
      final friendship = FriendshipModel(
        id: docId,
        fromUid: currentUid,
        toUid: targetUid,
        status: FriendshipStatus.pending,
        createdAt: DateTime.now(),
      );

      await _db.collection('friendships').doc(docId).set(friendship.toMap());

      // Yerel state güncelle — suggestions'dan çıkar, sentRequests'e ekle
      final sent = state.suggestions.firstWhere((f) => f.uid == targetUid);
      state = state.copyWith(
        suggestions: state.suggestions.where((f) => f.uid != targetUid).toList(),
        sentRequests: [...state.sentRequests, sent],
      );
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

  void updateSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);
}
