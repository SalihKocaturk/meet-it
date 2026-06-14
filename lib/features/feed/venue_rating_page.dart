import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/create_post_page.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:quickalert/quickalert.dart';

class VenueRatingPage extends ConsumerStatefulWidget {
  final String venueName;
  final String? venueAddress;
  final String? venuePhotoUrl;
  final double? venueLat;
  final double? venueLng;

  const VenueRatingPage({
    super.key,
    required this.venueName,
    this.venueAddress,
    this.venuePhotoUrl,
    this.venueLat,
    this.venueLng,
  });

  @override
  ConsumerState<VenueRatingPage> createState() => _VenueRatingPageState();
}

class _VenueRatingPageState extends ConsumerState<VenueRatingPage> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  UserFriendModel? _selectedFriend;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'venue_rating.rating_title'.tr(),
        text: 'venue_rating.no_rating_warning'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    // Değerlendirmeyi feed'e post olarak ekle
    final commentText = _commentCtrl.text.trim();

    final post = PostModel(
      id: '',
      authorUid: user.uid,
      authorName: user.name,
      authorPhotoUrl: user.photoUrl,
      friendUid: _selectedFriend?.uid,
      friendName: _selectedFriend?.name,
      friendPhotoUrl: _selectedFriend?.photoUrl,
      venueName: widget.venueName,
      venueAddress: widget.venueAddress,
      venuePhotoUrl: widget.venuePhotoUrl,
      venueLat: widget.venueLat,
      venueLng: widget.venueLng,
      caption: commentText.isNotEmpty ? commentText : null,
      rating: _rating,
      createdAt: DateTime.now(),
    );

    await ref.read(feedProvider.notifier).createPost(post);

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'venue_rating.rating_shared'.tr(),
      text: 'venue_rating.rating_shared_desc'.tr(namedArgs: {'venue': widget.venueName}),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.pop(context); // alert
        Navigator.pop(context); // rating page
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('venue_rating.title'.tr(),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.colors.primary))
                  : Text('feed.share_btn'.tr(),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mekan bilgisi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      color: context.colors.primary, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.venueName,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary)),
                        if (widget.venueAddress != null)
                          Text(widget.venueAddress!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28),

            // Yıldız puanı
            Text('venue_rating.your_rating'.tr(),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _rating >= star
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        key: ValueKey('$star-$_rating'),
                        size: 44,
                        color: _rating >= star
                            ? const Color(0xFFFFB800)
                            : context.colors.hint,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                _ratingLabel(_rating),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _rating > 0
                        ? const Color(0xFFFFB800)
                        : context.colors.hint),
              ),
            ),

            SizedBox(height: 28),

            // Yorum
            Text('venue_rating.comment_label'.tr(),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
            SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: 'venue_rating.comment_hint'.tr(),
                hintStyle: TextStyle(
                    color: context.colors.hint, fontSize: 14),
                filled: true,
                fillColor: context.colors.card,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.colors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.colors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: context.colors.primary, width: 1.5)),
              ),
            ),

            SizedBox(height: 20),

            // Birlikte gidilen kişi
            Text('venue_rating.select_friend'.tr(),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
            SizedBox(height: 8),
            if (connections.isEmpty)
              Text('venue_rating.no_friends'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary))
            else
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: connections.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final f = connections[i];
                    final isSel = _selectedFriend?.uid == f.uid;
                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selectedFriend = isSel ? null : f),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isSel
                                  ? Border.all(
                                      color: context.colors.primary,
                                      width: 2.5)
                                  : null,
                            ),
                            child: f.photoUrl != null
                                ? CircleAvatar(
                                    radius: 26,
                                    backgroundImage:
                                        NetworkImage(f.photoUrl!))
                                : CircleAvatar(
                                    radius: 26,
                                    backgroundColor: context.colors.primary
                                        .withOpacity(0.15),
                                    child: Text(
                                      f.name
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                  ),
                          ),
                          SizedBox(height: 4),
                          Text(f.name.split(' ').first,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSel
                                      ? context.colors.primary
                                      : context.colors.textSecondary)),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'feed.rating_1'.tr();
      case 2: return 'feed.rating_2'.tr();
      case 3: return 'feed.rating_3'.tr();
      case 4: return 'feed.rating_4'.tr();
      case 5: return 'feed.rating_5'.tr();
      default: return 'venue_rating.select_rating'.tr();
    }
  }
}
