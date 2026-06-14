import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/feed/venue_picker_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:quickalert/quickalert.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  /// Venue sonrası çağrılırsa bu bilgiler önceden dolu gelir
  final String? venueName;
  final String? venueAddress;
  final String? venuePhotoUrl;
  final double? venueLat;
  final double? venueLng;

  const CreatePostPage({
    super.key,
    this.venueName,
    this.venueAddress,
    this.venuePhotoUrl,
    this.venueLat,
    this.venueLng,
  });

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _captionCtrl = TextEditingController();
  File? _photo;
  UserFriendModel? _selectedFriend;
  bool _isPosting = false;
  int _rating = 0; // 0 = seçilmedi

  // Seçilen mekan bilgileri
  String? _venueName;
  String? _venueAddress;
  double? _venueLat;
  double? _venueLng;
  String? _venuePhotoUrl; // Maps'ten gelen mekan fotoğrafı

  @override
  void initState() {
    super.initState();
    // Venue sonrası geldiyse önceden dolu
    _venueName = widget.venueName;
    _venueAddress = widget.venueAddress;
    _venueLat = widget.venueLat;
    _venueLng = widget.venueLng;
    _venuePhotoUrl = widget.venuePhotoUrl;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVenueFromMap() async {
    final result = await Navigator.of(context).push<PickedVenue>(
      MaterialPageRoute(builder: (_) => const VenuePickerPage()),
    );
    if (result != null) {
      setState(() {
        _venueName = result.name;
        _venueAddress = result.address;
        _venueLat = result.lat;
        _venueLng = result.lng;
        _venuePhotoUrl = result.photoUrl;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_photo == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_photo!);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_venueName == null || _venueName!.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'feed.venue_required'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    setState(() => _isPosting = true);

    final photoUrl = await _uploadPhoto(user.uid);

    final post = PostModel(
      id: '',
      authorUid: user.uid,
      authorName: user.name,
      authorPhotoUrl: user.photoUrl,
      friendUid: _selectedFriend?.uid,
      friendName: _selectedFriend?.name,
      friendPhotoUrl: _selectedFriend?.photoUrl,
      venueName: _venueName!,
      venueAddress: _venueAddress,
      venuePhotoUrl: _venuePhotoUrl,
      venueLat: _venueLat,
      venueLng: _venueLng,
      caption: _captionCtrl.text.trim().isNotEmpty
          ? _captionCtrl.text.trim()
          : null,
      postPhotoUrl: photoUrl,
      rating: _rating > 0 ? _rating : null,
      createdAt: DateTime.now(),
    );

    await ref.read(feedProvider.notifier).createPost(post);

    setState(() => _isPosting = false);

    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'feed.post_shared'.tr(),
      text: 'feed.post_shared_desc'.tr(),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.pop(context); // alert kapat
        Navigator.pop(context); // sayfadan çık
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('feed.share_meetup'.tr(),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isPosting ? null : _submit,
              child: _isPosting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.colors.primary))
                  : Text('feed.post'.tr(),
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
            // Kullanıcı bilgisi
            Row(
              children: [
                CircularAvatar(
                    name: user?.name ?? '', photoUrl: user?.photoUrl, radius: 22),
                SizedBox(width: 10),
                Text(user?.name ?? '',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary)),
              ],
            ),

            SizedBox(height: 20),

            // Mekan — haritadan seç
            _Label('feed.select_venue_label'.tr()),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _pickVenueFromMap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _venueName != null
                        ? context.colors.primary.withOpacity(0.5)
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _venueName != null
                          ? Icons.location_on
                          : Icons.add_location_alt_outlined,
                      color: context.colors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _venueName ?? 'feed.select_venue_map'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: _venueName != null
                              ? context.colors.textPrimary
                              : context.colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: context.colors.hint),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Arkadaş seç
            _Label('feed.with_friend_label'.tr()),
            SizedBox(height: 8),
            if (connections.isEmpty)
              Text('friends.no_friends'.tr(),
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary))
            else
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: connections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final f = connections[i];
                    final isSelected = _selectedFriend?.uid == f.uid;
                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selectedFriend = isSelected ? null : f),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: context.colors.primary, width: 2.5)
                                  : null,
                            ),
                            child: CircularAvatar(
                                name: f.name,
                                photoUrl: f.photoUrl,
                                radius: 26),
                          ),
                          SizedBox(height: 4),
                          Text(f.name.split(' ').first,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? context.colors.primary
                                      : context.colors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Yıldız değerlendirmesi
            _Label('feed.rate_venue_optional'.tr()),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _rating = _rating == star ? 0 : star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          _rating >= star
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey('$star-$_rating'),
                          size: 36,
                          color: _rating >= star
                              ? const Color(0xFFFFB800)
                              : context.colors.hint,
                        ),
                      ),
                    ),
                  );
                }),
                if (_rating > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    _ratingLabel(_rating),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFB800)),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Caption
            _Label('feed.caption_label_optional'.tr()),
            const SizedBox(height: 8),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              maxLength: 280,
              decoration: _inputDeco(context, hint: 'feed.caption_hint'.tr()),
            ),

            const SizedBox(height: 20),

            // Fotoğraf
            _Label('feed.add_photo'.tr()),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPhoto,
              child: _photo != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_photo!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _photo = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _venuePhotoUrl != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: _venuePhotoUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          color: Colors.white, size: 32),
                                      SizedBox(height: 6),
                                      Text('feed.add_own_photo'.tr(),
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: context.colors.border,
                                style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 36, color: context.colors.hint),
                                SizedBox(height: 6),
                                Text('feed.select_photo'.tr(),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: context.colors.textSecondary)),
                              ],
                            ),
                          ),
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
      default: return '';
    }
  }

  InputDecoration _inputDeco(BuildContext context, {required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: context.colors.hint, size: 20) : null,
      filled: true,
      fillColor: context.colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.textSecondary));
}
