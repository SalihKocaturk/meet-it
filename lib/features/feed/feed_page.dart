import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/create_post_page.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/post_detail_page.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:quickalert/quickalert.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePostPage()),
        ),
        backgroundColor: context.colors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Paylaş',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        elevation: 3,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MeetIt Feed',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary)),
                    Text('Buluşmaları keşfet',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary)),
                  ],
                ),
              ),
            ),

            // ── Loading ───────────────────────────────────────────────────
            if (feedState.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: context.colors.primary),
                ),
              )

            // ── Error ─────────────────────────────────────────────────────
            else if (feedState.errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_outlined,
                          size: 48, color: context.colors.hint),
                      SizedBox(height: 12),
                      Text(feedState.errorMessage!,
                          style: TextStyle(color: context.colors.textSecondary)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(feedProvider.notifier).loadFeed(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Tekrar Dene',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )

            // ── Boş ───────────────────────────────────────────────────────
            else if (feedState.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🍽️',
                          style: TextStyle(fontSize: 56)),
                      SizedBox(height: 16),
                      Text('Henüz paylaşım yok',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary)),
                      SizedBox(height: 8),
                      Text('İlk buluşmayı sen paylaş!',
                          style: TextStyle(
                              fontSize: 14, color: context.colors.textSecondary)),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CreatePostPage()),
                        ),
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text('Buluşmayı Paylaş',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                      ),
                    ],
                  ),
                ),
              )

            // ── Post Listesi ───────────────────────────────────────────────
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final post = feedState.posts[i];
                    return _PostCard(
                      post: post,
                      currentUid: currentUser?.uid ?? '',
                    );
                  },
                  childCount: feedState.posts.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// ── Post Kartı ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final PostModel post;
  final String currentUid;

  const _PostCard({required this.post, required this.currentUid});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = post.isLikedBy(currentUid);
    final isSaved = post.isSavedBy(currentUid);
    final isOwner = post.authorUid == currentUid;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
      ),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Üst: Avatar + İsim + Zaman ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // Yazar
                CircularAvatar(
                    name: post.authorName,
                    photoUrl: post.authorPhotoUrl,
                    radius: 18),
                // Arkadaş varsa üst üste göster
                if (post.friendName != null)
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: CircularAvatar(
                        name: post.friendName!,
                        photoUrl: post.friendPhotoUrl,
                        radius: 18),
                  ),
                SizedBox(width: post.friendName != null ? 0 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.friendName != null
                            ? '${post.authorName} & ${post.friendName}'
                            : post.authorName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(_timeAgo(post.createdAt),
                          style: TextStyle(
                              fontSize: 11, color: context.colors.textSecondary)),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: context.colors.hint, size: 22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') _showEditSheet(context, ref);
                      if (val == 'delete') {
                        QuickAlert.show(
                          context: context,
                          type: QuickAlertType.confirm,
                          title: 'Postu Sil',
                          text: 'Bu paylaşım silinsin mi?',
                          confirmBtnText: 'Sil',
                          cancelBtnText: 'Vazgeç',
                          confirmBtnColor: Colors.red,
                          onConfirmBtnTap: () {
                            Navigator.pop(context);
                            ref.read(feedProvider.notifier).deletePost(post.id);
                          },
                        );
                      }
                    },
                    itemBuilder: (_) => [
                       PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18, color: context.colors.primary),
                          SizedBox(width: 10),
                          Text('Düzenle'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Sil', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Mekan bilgisi ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    size: 14, color: context.colors.primary),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.venueAddress != null
                        ? '${post.venueName} · ${post.venueAddress}'
                        : post.venueName,
                    style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Yıldız Değerlendirmesi ────────────────────────────────────────
          if (post.rating != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                    i < post.rating!
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: i < post.rating!
                        ? const Color(0xFFFFB800)
                        : context.colors.hint,
                  )),
                  const SizedBox(width: 6),
                  Text(
                    _ratingLabel(post.rating!),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFB800)),
                  ),
                ],
              ),
            ),

          // ── Caption ──────────────────────────────────────────────────────
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(post.caption!,
                  style: TextStyle(
                      fontSize: 14, color: context.colors.textPrimary, height: 1.4)),
            ),

          // ── Fotoğraf ─────────────────────────────────────────────────────
          if (post.postPhotoUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(0)),
                child: CachedNetworkImage(
                  imageUrl: post.postPhotoUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else if (post.venuePhotoUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: post.venuePhotoUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.15),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),

          // ── Alt: Beğeni ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref
                      .read(feedProvider.notifier)
                      .toggleLike(post.id, currentUid),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(isLiked),
                      color: isLiked ? Colors.red : context.colors.hint,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLiked ? Colors.red : context.colors.textSecondary),
                ),
                const SizedBox(width: 4),
                Text('beğeni',
                    style: TextStyle(
                        fontSize: 12, color: context.colors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => ref
                      .read(feedProvider.notifier)
                      .toggleSave(post.id, currentUid),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      key: ValueKey(isSaved),
                      color: isSaved ? context.colors.primary : context.colors.hint,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ), // Container
    ); // GestureDetector
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final captionCtrl = TextEditingController(text: post.caption ?? '');
    int rating = post.rating ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Text('Gönderiyi Düzenle',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text('Değerlendirme',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => rating = rating == star ? 0 : star),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            rating >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 32,
                            color: rating >= star ? const Color(0xFFFFB800) : context.colors.hint,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text('Açıklama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: captionCtrl,
                    maxLines: 3,
                    maxLength: 280,
                    decoration: InputDecoration(
                      hintText: 'Ne yaşadınız?',
                      hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(feedProvider.notifier).editPost(
                          post.id,
                          caption: captionCtrl.text.trim().isNotEmpty ? captionCtrl.text.trim() : null,
                          rating: rating > 0 ? rating : null,
                          clearRating: rating == 0,
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Kaydet',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Berbattı';
      case 2: return 'İdare eder';
      case 3: return 'İyiydi';
      case 4: return 'Çok güzeldi';
      case 5: return 'Mükemmeldi! 🎉';
      default: return '';
    }
  }
}
