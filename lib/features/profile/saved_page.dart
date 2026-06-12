import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/post_detail_page.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:meetit/features/friends/friend_code_page.dart';
import 'package:meetit/features/match/match_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:quickalert/quickalert.dart';

class ProfileMenuPage extends ConsumerStatefulWidget {
  const ProfileMenuPage({super.key});

  @override
  ConsumerState<ProfileMenuPage> createState() => _ProfileMenuPageState();
}

class _ProfileMenuPageState extends ConsumerState<ProfileMenuPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isEmailUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  void _showLogoutAlert(BuildContext context) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Çıkış Yap',
      text: 'Hesabından çıkış yapmak istediğinden emin misin?',
      confirmBtnText: 'Evet, Çık',
      cancelBtnText: 'İptal',
      confirmBtnColor: context.colors.error,
      onConfirmBtnTap: () async {
        Navigator.pop(context);
        await ref.read(authProvider.notifier).signOut();
        if (!context.mounted) return;
        context.go(AppRoutes.signIn);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentUid = currentUser?.uid ?? '';
    final allPosts = ref.watch(feedProvider).posts;
    final isEmailUser = _isEmailUser();

    final savedPosts = allPosts.where((p) => p.isSavedBy(currentUid)).toList();
    final likedPosts = allPosts.where((p) => p.isLikedBy(currentUid)).toList();

    final searchResults = _query.isEmpty
        ? <PostModel>[]
        : allPosts
              .where(
                (p) =>
                    p.venueName.toLowerCase().contains(_query.toLowerCase()) ||
                    (p.caption?.toLowerCase().contains(_query.toLowerCase()) ??
                        false) ||
                    p.authorName.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Üst bar ────────────────────────────────────────────────────
            Container(
              color: context.colors.card,
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: context.colors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Menü',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _query.isNotEmpty
                  ? _SearchResults(results: searchResults, query: _query)
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        // ── Arama barı ───────────────────────────────────
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Mekan, kişi veya gönderi ara...',
                            hintStyle: TextStyle(
                              color: context.colors.hint,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: context.colors.hint,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: context.colors.card,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: context.colors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Hareketler ──────────────────────────────────
                        _SectionLabel('Hareketler'),
                        const SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Icons.bookmark_outline,
                              title: 'Kaydedilenler',
                              badge: savedPosts.isNotEmpty
                                  ? savedPosts.length
                                  : null,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _PostListPage(
                                    title: 'Kaydedilenler',
                                    posts: savedPosts,
                                    emptyText: 'Henüz kaydettiğin gönderi yok.',
                                  ),
                                ),
                              ),
                            ),
                            _MenuItem(
                              icon: Icons.favorite_border_rounded,
                              title: 'Beğenilenler',
                              badge: likedPosts.isNotEmpty
                                  ? likedPosts.length
                                  : null,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _PostListPage(
                                    title: 'Beğenilenler',
                                    posts: likedPosts,
                                    emptyText: 'Henüz beğendiğin gönderi yok.',
                                  ),
                                ),
                              ),
                            ),
                            _MenuItem(
                              icon: Icons.notifications_outlined,
                              title: 'Bildirimler',
                              onTap: () {},
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Hesap ───────────────────────────────────────
                        _SectionLabel('Hesap'),
                        const SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Icons.person_outline,
                              title: 'Profili Düzenle',
                              onTap: () => context.push(AppRoutes.editProfile),
                            ),
                            if (isEmailUser)
                              _MenuItem(
                                icon: Icons.lock_outline,
                                title: 'Şifre Değiştir',
                                onTap: () =>
                                    context.push(AppRoutes.changePassword),
                              ),
                            _MenuItem(
                              icon: Icons.psychology_outlined,
                              title: 'Kişilik Testini Yenile',
                              subtitle:
                                  'Testini tekrar alarak mekan önerilerini güncelle',
                              onTap: () => context.push(AppRoutes.quiz),
                            ),
                            _MenuItem(
                              icon: Icons.location_on_outlined,
                              title: 'Konum Güncelle',
                              subtitle: ref.watch(userLocationProvider)?.text,
                              onTap: () async {
                                final current = ref.read(userLocationProvider);
                                final result = await Navigator.of(context)
                                    .push<UserLocation>(
                                      MaterialPageRoute(
                                        builder: (_) => MapLocationPickerPage(
                                          initial: current?.hasCoords == true
                                              ? LatLng(
                                                  current!.lat!,
                                                  current.lng!,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                if (result != null) {
                                  ref
                                          .read(userLocationProvider.notifier)
                                          .state =
                                      result;
                                }
                              },
                            ),
                            _MenuItem(
                              icon: Icons.tag,
                              title: 'Kodla Arkadaş Ekle',
                              subtitle:
                                  '6 haneli kod ile arkadaş ekle veya kodunu paylaş',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FriendCodePage(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Uygulama ────────────────────────────────────
                        _SectionLabel('Uygulama'),
                        SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Icons.dark_mode_outlined,
                              title:
                                  ref.watch(themeModeProvider) == ThemeMode.dark
                                  ? 'Açık Tema'
                                  : 'Koyu Tema',
                              onTap: () =>
                                  ref.read(themeModeProvider.notifier).toggle(),
                            ),
                            _MenuItem(
                              icon: Icons.language_outlined,
                              title: 'Dil',
                              trailing: Text(
                                'Türkçe',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              onTap: () {},
                            ),
                            _MenuItem(
                              icon: Icons.info_outline,
                              title: 'Hakkında',
                              onTap: () => QuickAlert.show(
                                context: context,
                                type: QuickAlertType.info,
                                title: 'MeetIt',
                                text:
                                    'Versiyon 1.0.0\nBuluşmak hiç bu kadar kolay olmamıştı.',
                                confirmBtnText: 'Tamam',
                                confirmBtnColor: context.colors.primary,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20),

                        // ── Çıkış ───────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.logout,
                              color: context.colors.error,
                            ),
                            title: Text(
                              'Çıkış Yap',
                              style: TextStyle(
                                color: context.colors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const SizedBox.shrink(),
                            onTap: () => _showLogoutAlert(context),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı Widgetlar ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: context.colors.textSecondary,
      letterSpacing: 0.8,
    ),
  );
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          return Column(
            children: [
              e.value,
              if (e.key < items.length - 1)
                const Divider(height: 1, indent: 52, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int? badge;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.primary, size: 22),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : trailing ??
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: context.colors.hint,
                ),
      onTap: onTap,
    );
  }
}

// ── Arama Sonuçları ───────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final List<PostModel> results;
  final String query;

  const _SearchResults({required this.results, required this.query});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          '"$query" için sonuç bulunamadı.',
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final p = results[i];
        final img = p.postPhotoUrl ?? p.venuePhotoUrl;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: img != null
                ? CachedNetworkImage(
                    imageUrl: img,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 52,
                    height: 52,
                    color: context.colors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.location_on,
                      color: context.colors.primary,
                    ),
                  ),
          ),
          title: Text(
            p.venueName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          subtitle: Text(
            p.authorName,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          trailing: p.rating != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFFFB800),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${p.rating}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () => Navigator.of(
            ctx,
          ).push(MaterialPageRoute(builder: (_) => PostDetailPage(post: p))),
        );
      },
    );
  }
}

// ── Post Liste Sayfası (Kaydedilenler / Beğenilenler) ─────────────────────────

class _PostListPage extends StatelessWidget {
  final String title;
  final List<PostModel> posts;
  final String emptyText;

  const _PostListPage({
    required this.title,
    required this.posts,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    title == 'Kaydedilenler'
                        ? Icons.bookmark_border_rounded
                        : Icons.favorite_border_rounded,
                    size: 56,
                    color: context.colors.hint,
                  ),
                  SizedBox(height: 12),
                  Text(
                    emptyText,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                final imgUrl = post.postPhotoUrl ?? post.venuePhotoUrl;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailPage(post: post),
                    ),
                  ),
                  child: imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: context.colors.border),
                          errorWidget: (_, _, _) =>
                              _GridPlaceholder(post: post),
                        )
                      : _GridPlaceholder(post: post),
                );
              },
            ),
    );
  }
}

class _GridPlaceholder extends StatelessWidget {
  final PostModel post;
  const _GridPlaceholder({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: context.colors.primary, size: 22),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              post.venueName,
              style: TextStyle(fontSize: 9, color: context.colors.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
