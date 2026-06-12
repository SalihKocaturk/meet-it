import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/feed/models/post_model.dart';

class FeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final String? errorMessage;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class FeedNotifier extends Notifier<FeedState> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;

  @override
  FeedState build() {
    // Notifier dispose edilince subscription iptal et
    ref.onDispose(() => _sub?.cancel());
    _listenFeed();
    return const FeedState(isLoading: true);
  }

  void _listenFeed() {
    _sub?.cancel();
    _sub = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snap) {
        final posts = snap.docs
            .map((d) => PostModel.fromMap(d.id, d.data()))
            .toList();
        final sorted = _sort(posts);
        state = state.copyWith(posts: sorted, isLoading: false);
      },
      onError: (_) => state = state.copyWith(
        isLoading: false,
        errorMessage: 'Feed yüklenirken hata oluştu.',
      ),
    );
  }

  List<PostModel> _sort(List<PostModel> posts) {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent = posts
        .where((p) => p.createdAt.isAfter(oneWeekAgo))
        .toList()
      ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
    final older =
        posts.where((p) => !p.createdAt.isAfter(oneWeekAgo)).toList();
    return [...recent, ...older];
  }

  Future<void> loadFeed() async => _listenFeed();

  Future<void> createPost(PostModel post) async {
    try {
      final ref = _db.collection('posts').doc();
      await ref.set(post.toMap());
      // Stream listener yeni postu otomatik alır — optimistic insert yok.
    } catch (e) {
      state = state.copyWith(errorMessage: 'Post paylaşılırken hata oluştu.');
    }
  }

  Future<void> toggleLike(String postId, String uid) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.posts[idx];
    final liked = post.isLikedBy(uid);
    final newLikedBy = liked
        ? post.likedBy.where((u) => u != uid).toList()
        : [...post.likedBy, uid];

    // Optimistic update
    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(likedBy: newLikedBy);
    state = state.copyWith(posts: updated);

    // Firestore güncelle
    try {
      await _db.collection('posts').doc(postId).update({
        'likedBy': liked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (_) {
      // Rollback
      final rollback = List<PostModel>.from(state.posts);
      rollback[idx] = post;
      state = state.copyWith(posts: rollback);
    }
  }

  Future<void> toggleSave(String postId, String uid) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    final saved = post.isSavedBy(uid);
    final newSavedBy = saved
        ? post.savedBy.where((u) => u != uid).toList()
        : [...post.savedBy, uid];
    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(savedBy: newSavedBy);
    state = state.copyWith(posts: updated);
    try {
      await _db.collection('posts').doc(postId).update({
        'savedBy': saved
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (_) {
      final rollback = List<PostModel>.from(state.posts);
      rollback[idx] = post;
      state = state.copyWith(posts: rollback);
    }
  }

  Future<void> editPost(String postId, {String? caption, int? rating, bool clearRating = false}) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(caption: caption, rating: rating, clearRating: clearRating);
    state = state.copyWith(posts: updated);
    try {
      await _db.collection('posts').doc(postId).update({
        'caption': caption,
        if (clearRating) 'rating': null else if (rating != null) 'rating': rating,
      });
    } catch (_) {
      final rollback = List<PostModel>.from(state.posts);
      rollback[idx] = post;
      state = state.copyWith(posts: rollback);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
      state = state.copyWith(
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } catch (_) {}
  }
}
