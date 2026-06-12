import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailPage extends ConsumerWidget {
  final PostModel post;
  const PostDetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedProvider);
    final currentPost = feedState.posts.firstWhere(
      (p) => p.id == post.id,
      orElse: () => post,
    );
    final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
    final isOwner = currentPost.authorUid == currentUid;
    final isLiked = currentPost.isLikedBy(currentUid);
    final isSaved = currentPost.isSavedBy(currentUid);
    final hasPhoto =
        currentPost.postPhotoUrl != null || currentPost.venuePhotoUrl != null;

    return Scaffold(
      backgroundColor: context.colors.card,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar: fotoğraf varsa büyük, yoksa sadece bar ─────────
          SliverAppBar(
            expandedHeight: hasPhoto ? 340 : 0,
            pinned: true,
            backgroundColor: context.colors.card,
            foregroundColor: hasPhoto
                ? Colors.white
                : context.colors.textPrimary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasPhoto
                      ? Colors.black.withOpacity(0.35)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: hasPhoto ? Colors.white : context.colors.textPrimary,
                  size: 18,
                ),
              ),
            ),
            actions: [
              if (isOwner)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasPhoto
                          ? Colors.black.withOpacity(0.35)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: hasPhoto
                          ? Colors.white
                          : context.colors.textPrimary,
                      size: 22,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val == 'edit')
                      _showEditSheet(context, ref, currentPost);
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
                          ref
                              .read(feedProvider.notifier)
                              .deletePost(currentPost.id);
                          Navigator.pop(context);
                        },
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: context.colors.primary,
                          ),
                          SizedBox(width: 10),
                          Text('Düzenle'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text('Sil', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: hasPhoto
                ? FlexibleSpaceBar(
                    background: GestureDetector(
                      onDoubleTap: () => ref
                          .read(feedProvider.notifier)
                          .toggleLike(currentPost.id, currentUid),
                      child: CachedNetworkImage(
                        imageUrl:
                            currentPost.postPhotoUrl ??
                            currentPost.venuePhotoUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : null,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Kullanıcı + Aksiyon barı ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                  child: Row(
                    children: [
                      // Avatarlar
                      CircularAvatar(
                        name: currentPost.authorName,
                        photoUrl: currentPost.authorPhotoUrl,
                        radius: 20,
                      ),
                      if (currentPost.friendName != null)
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: CircularAvatar(
                            name: currentPost.friendName!,
                            photoUrl: currentPost.friendPhotoUrl,
                            radius: 20,
                          ),
                        ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost.friendName != null
                                  ? '${currentPost.authorName} & ${currentPost.friendName}'
                                  : currentPost.authorName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              _timeAgo(currentPost.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.hint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Like
                      IconButton(
                        onPressed: () => ref
                            .read(feedProvider.notifier)
                            .toggleLike(currentPost.id, currentUid),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isLiked),
                            color: isLiked
                                ? Colors.red
                                : context.colors.textPrimary,
                            size: 26,
                          ),
                        ),
                      ),
                      // Kaydet
                      IconButton(
                        onPressed: () => ref
                            .read(feedProvider.notifier)
                            .toggleSave(currentPost.id, currentUid),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            key: ValueKey(isSaved),
                            color: isSaved
                                ? context.colors.primary
                                : context.colors.textPrimary,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Beğeni sayısı ────────────────────────────────────────────
                if (currentPost.likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      '${currentPost.likeCount} beğeni',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),

                // ── Yıldız ───────────────────────────────────────────────────
                if (currentPost.rating != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < currentPost.rating!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 22,
                            color: i < currentPost.rating!
                                ? const Color(0xFFFFB800)
                                : context.colors.hint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ratingLabel(currentPost.rating!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFB800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Caption ──────────────────────────────────────────────────
                if (currentPost.caption != null &&
                    currentPost.caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${currentPost.authorName} ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: currentPost.caption!,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                // ── Mekan Kartı ──────────────────────────�
                GestureDetector(
                  onTap: currentPost.venueLat != null
                      ? () => _openMaps(currentPost)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPost.venueName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              if (currentPost.venueAddress != null)
                                Text(
                                  currentPost.venueAddress!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              if (currentPost.venueLat != null)
                                Text(
                                  'Haritada gör →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                if (currentPost.friendName != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularAvatar(
                          name: currentPost.friendName!,
                          photoUrl: currentPost.friendPhotoUrl,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Birlikte',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textSecondary,
                              ),
                            ),
                            Text(
                              currentPost.friendName!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Text(
                    _fullDate(currentPost.createdAt),
                    style: TextStyle(fontSize: 12, color: context.colors.hint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOwnerMenu(
    BuildContext context,
    WidgetRef ref,
    PostModel currentPost,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: context.colors.primary),
              title: const Text(
                'Düzenle',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context, ref, currentPost);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Sil',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
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
                    ref.read(feedProvider.notifier).deletePost(currentPost.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    PostModel currentPost,
  ) {
    final captionCtrl = TextEditingController(text: currentPost.caption ?? '');
    int rating = currentPost.rating ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Gönderiyi Düzenle',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Değerlendirme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => rating = rating == star ? 0 : star),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            rating >= star
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 32,
                            color: rating >= star
                                ? const Color(0xFFFFB800)
                                : context.colors.hint,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Açıklama',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: captionCtrl,
                    maxLines: 3,
                    maxLength: 280,
                    decoration: InputDecoration(
                      hintText: 'Ne yaşadınız?',
                      hintStyle: TextStyle(
                        color: context.colors.hint,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(feedProvider.notifier)
                            .editPost(
                              currentPost.id,
                              caption: captionCtrl.text.trim().isNotEmpty
                                  ? captionCtrl.text.trim()
                                  : null,
                              rating: rating > 0 ? rating : null,
                              clearRating: rating == 0,
                            );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                          'Kaydet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
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

  Future<void> _openMaps(PostModel p) async {
    if (p.venueLat == null || p.venueLng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${p.venueLat},${p.venueLng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fullDate(DateTime dt) =>
      '${dt.day} ${_month(dt.month)} ${dt.year}';

  String _month(int m) => [
        '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ][m];

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
