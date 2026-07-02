import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friend_code_page.dart';
import 'package:meetit/features/match/match_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/reviews/models/venue_review_model.dart';
import 'package:meetit/features/reviews/notifiers/review_notifier.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';

import '../history/meeting_history_page.dart';

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

  List<_MenuItem> _searchItems(
    BuildContext context,
    WidgetRef ref,
    bool isEmailUser,
    List<VenueReviewModel> likedReviews,
  ) =>
      [
        _MenuItem(
          icon: Iconsax.heart,
          title: 'profile.liked_reviews'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ReviewListPage(
                title: 'profile.liked_reviews'.tr(),
                reviews: likedReviews,
                emptyText: 'profile.empty_liked_reviews'.tr(),
              ),
            ),
          ),
        ),
        _MenuItem(
          icon: Iconsax.clock,
          title: 'settings.meeting_history'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MeetingHistoryPage()),
          ),
        ),
        _MenuItem(
          icon: Iconsax.profile_circle,
          title: 'settings.edit_profile'.tr(),
          onTap: () => context.push(AppRoutes.editProfile),
        ),
        if (isEmailUser)
          _MenuItem(
            icon: Iconsax.lock_1,
            title: 'settings.change_password'.tr(),
            onTap: () => context.push(AppRoutes.changePassword),
          ),
        _MenuItem(
          icon: Iconsax.activity,
          title: 'settings.retake_quiz'.tr(),
          onTap: () => context.push(AppRoutes.quiz),
        ),
        _MenuItem(
          icon: Iconsax.location,
          title: 'settings.update_location'.tr(),
          onTap: () async {
            final current = ref.read(userLocationProvider);
            final result = await Navigator.of(context)
                .push<UserLocation>(
                  MaterialPageRoute(
                    builder: (_) => MapLocationPickerPage(
                      initial: current?.hasCoords == true
                          ? LatLng(current!.lat!, current.lng!)
                          : null,
                    ),
                  ),
                );
            if (result != null) {
              ref.read(userLocationProvider.notifier).state = result;
            }
          },
        ),
        _MenuItem(
          icon: Iconsax.hashtag,
          title: 'settings.add_friend_code'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FriendCodePage()),
          ),
        ),
        _MenuItem(
          icon: Iconsax.global,
          title: 'settings.language'.tr(),
          onTap: () => showLanguagePickerSheet(context),
        ),
        _MenuItem(
          icon: Iconsax.info_circle,
          title: 'settings.about'.tr(),
          onTap: () => showAppAlert(
            context: context,
            type: AppAlertType.info,
            title: 'app_name'.tr(),
            text: 'settings.about_text'.tr(),
            confirmBtnText: 'common.ok'.tr(),
            confirmBtnColor: context.colors.primary,
          ),
        ),
        _MenuItem(
          icon: Iconsax.document_text_1,
          title: 'legal.terms_title'.tr(),
          onTap: () => _showLegalSheet(context, isTerms: true),
        ),
        _MenuItem(
          icon: Iconsax.shield_tick,
          title: 'legal.privacy_title'.tr(),
          onTap: () => _showLegalSheet(context, isTerms: false),
        ),
      ];

  bool _isEmailUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  void _showLegalSheet(BuildContext context, {required bool isTerms}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegalBottomSheet(isTerms: isTerms),
    );
  }

  void _showLogoutAlert(BuildContext context) {
    showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'settings.sign_out_title'.tr(),
      text: 'settings.sign_out_confirm'.tr(),
      confirmBtnText: 'settings.sign_out_yes'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
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
    final isEmailUser = _isEmailUser();

    // NOT: VenueReviewModel'de PostModel'deki savedBy alanına karşılık gelen
    // bir "kaydedilen yorum" kavramı yok (sadece likedBy var). Bu yüzden
    // "Kaydedilenler" bölümü kaldırıldı, sadece "Beğenilenler" bırakıldı —
    // sayfayı bozmamak için en basit ve güvenli seçim bu (bkz. görev notları).
    // Arama, kullanıcının kendi yazdığı yorumlar arasında yapılır.
    final myReviewsAsync = ref.watch(myReviewsProvider(currentUid));
    final allReviews = myReviewsAsync.value ?? const <VenueReviewModel>[];

    final likedReviews = allReviews
        .where((r) => r.isLikedBy(currentUid))
        .toList();

    final filteredMenuItems = _query.isEmpty
        ? <_MenuItem>[]
        : _searchItems(context, ref, isEmailUser, likedReviews)
            .where(
              (item) => item.title
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
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
                      Iconsax.arrow_left_2,
                      color: context.colors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'profile.menu'.tr(),
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
                  ? _MenuSearchResults(items: filteredMenuItems, query: _query)
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
                            hintText: 'profile.search_hint'.tr(),
                            hintStyle: TextStyle(
                              color: context.colors.hint,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Iconsax.search_normal_1,
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
                        _SectionLabel('profile.section_activity'.tr()),
                        const SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Iconsax.heart,
                              title: 'profile.liked_reviews'.tr(),
                              badge: likedReviews.isNotEmpty
                                  ? likedReviews.length
                                  : null,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ReviewListPage(
                                    title: 'profile.liked_reviews'.tr(),
                                    reviews: likedReviews,
                                    emptyText: 'profile.empty_liked_reviews'
                                        .tr(),
                                  ),
                                ),
                              ),
                            ),
                            _MenuItem(
                              icon: Iconsax.clock,
                              title: 'settings.meeting_history'.tr(),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MeetingHistoryPage(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Hesap ───────────────────────────────────────
                        _SectionLabel('settings.section_account'.tr()),
                        const SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Iconsax.profile_circle,
                              title: 'settings.edit_profile'.tr(),
                              onTap: () => context.push(AppRoutes.editProfile),
                            ),
                            if (isEmailUser)
                              _MenuItem(
                                icon: Iconsax.lock_1,
                                title: 'settings.change_password'.tr(),
                                onTap: () =>
                                    context.push(AppRoutes.changePassword),
                              ),
                            _MenuItem(
                              icon: Iconsax.activity,
                              title: 'settings.retake_quiz'.tr(),
                              subtitle: 'settings.retake_quiz_desc'.tr(),
                              onTap: () => context.push(AppRoutes.quiz),
                            ),
                            _MenuItem(
                              icon: Iconsax.location,
                              title: 'settings.update_location'.tr(),
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
                              icon: Iconsax.hashtag,
                              title: 'settings.add_friend_code'.tr(),
                              subtitle: 'settings.add_friend_code_desc'.tr(),
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
                        _SectionLabel('settings.section_app'.tr()),
                        SizedBox(height: 8),
                        _MenuSection(
                          items: [
                            _MenuItem(
                              icon: Iconsax.moon,
                              // `ThemeMode.system` durumunda da doğru metni
                              // göstermek için isEffectivelyDark kullanılıyor
                              // (== ThemeMode.dark yalnızca açık/kapalı
                              // tercihi seçildiğinde doğru sonuç verirdi).
                              title:
                                  isEffectivelyDark(
                                    ref.watch(themeModeProvider),
                                  )
                                  ? 'settings.light_mode'.tr()
                                  : 'settings.dark_mode'.tr(),
                              onTap: () =>
                                  ref.read(themeModeProvider.notifier).toggle(),
                            ),
                            _MenuItem(
                              icon: Iconsax.global,
                              title: 'settings.language'.tr(),
                              trailing: Text(
                                context.locale.languageCode == 'tr'
                                    ? 'Türkçe'
                                    : 'English',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              onTap: () => showLanguagePickerSheet(context),
                            ),
                            _MenuItem(
                              icon: Iconsax.info_circle,
                              title: 'settings.about'.tr(),
                              onTap: () => showAppAlert(
                                context: context,
                                type: AppAlertType.info,
                                title: 'app_name'.tr(),
                                text: 'settings.about_text'.tr(),
                                confirmBtnText: 'common.ok'.tr(),
                                confirmBtnColor: context.colors.primary,
                              ),
                            ),
                            _MenuItem(
                              icon: Iconsax.document_text_1,
                              title: 'legal.terms_title'.tr(),
                              onTap: () =>
                                  _showLegalSheet(context, isTerms: true),
                            ),
                            _MenuItem(
                              icon: Iconsax.shield_tick,
                              title: 'legal.privacy_title'.tr(),
                              onTap: () =>
                                  _showLegalSheet(context, isTerms: false),
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
                              Iconsax.logout,
                              color: context.colors.error,
                            ),
                            title: Text(
                              'settings.sign_out'.tr(),
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
                  Iconsax.arrow_right_3,
                  size: 14,
                  color: context.colors.hint,
                ),
      onTap: onTap,
    );
  }
}

// ── Arama Sonuçları ───────────────────────────────────────────────────────────
//
// PostModel/PostDetailPage kaldırıldı (eski Feed) — artık kullanıcının kendi
// yorumları (VenueReviewModel) içinde arama yapılıyor, dokununca o yorumun
// ait olduğu mekanın VenueDetailPage'i açılıyor.

class _MenuSearchResults extends StatelessWidget {
  final List<_MenuItem> items;
  final String query;

  const _MenuSearchResults({required this.items, required this.query});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'profile.no_search_result'.tr(namedArgs: {'query': query}),
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [_MenuSection(items: items)],
    );
  }
}


class _ReviewListPage extends StatelessWidget {
  final String title;
  final List<VenueReviewModel> reviews;
  final String emptyText;

  const _ReviewListPage({
    required this.title,
    required this.reviews,
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
            Iconsax.arrow_left_2,
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
      body: reviews.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.heart, size: 56, color: context.colors.hint),
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
              itemCount: reviews.length,
              itemBuilder: (context, i) {
                final review = reviews[i];
                final imgUrl = review.photoUrl ?? review.displayPhotoUrl;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VenueDetailPage(
                        placeId: review.placeId,
                        venueName: review.venueName,
                        venueAddress: review.venueAddress,
                        venuePhotoUrl: review.displayPhotoUrl,
                        lat: review.lat,
                        lng: review.lng,
                      ),
                    ),
                  ),
                  child: imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: context.colors.border),
                          errorWidget: (_, _, _) =>
                              _GridPlaceholder(review: review),
                        )
                      : _GridPlaceholder(review: review),
                );
              },
            ),
    );
  }
}

// ── Legal Bottom Sheet ────────────────────────────────────────────────────────

class _LegalBottomSheet extends StatelessWidget {
  final bool isTerms;
  const _LegalBottomSheet({required this.isTerms});

  @override
  Widget build(BuildContext context) {
    final sections = isTerms ? _termsSections : _privacySections;
    final title = isTerms
        ? 'legal.terms_title'.tr()
        : 'legal.privacy_title'.tr();
    final lastUpdated = isTerms
        ? 'legal.terms_last_updated'.tr()
        : 'legal.privacy_last_updated'.tr();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.colors.scaffold,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.colors.border),
            // İçerik
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  ...sections.map(
                    (s) => _LegalSection(title: s[0], body: s[1]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lastUpdated,
                    style: TextStyle(fontSize: 12, color: context.colors.hint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;
  const _LegalSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

List<List<String>> get _termsSections => [
  ['legal.terms_s1_title'.tr(), 'legal.terms_s1_body'.tr()],
  ['legal.terms_s2_title'.tr(), 'legal.terms_s2_body'.tr()],
  ['legal.terms_s3_title'.tr(), 'legal.terms_s3_body'.tr()],
  ['legal.terms_s4_title'.tr(), 'legal.terms_s4_body'.tr()],
  ['legal.terms_s5_title'.tr(), 'legal.terms_s5_body'.tr()],
  ['legal.terms_s6_title'.tr(), 'legal.terms_s6_body'.tr()],
];

List<List<String>> get _privacySections => [
  ['legal.privacy_s1_title'.tr(), 'legal.privacy_s1_body'.tr()],
  ['legal.privacy_s2_title'.tr(), 'legal.privacy_s2_body'.tr()],
  ['legal.privacy_s3_title'.tr(), 'legal.privacy_s3_body'.tr()],
  ['legal.privacy_s4_title'.tr(), 'legal.privacy_s4_body'.tr()],
  ['legal.privacy_s5_title'.tr(), 'legal.privacy_s5_body'.tr()],
  ['legal.privacy_s6_title'.tr(), 'legal.privacy_s6_body'.tr()],
];

class _GridPlaceholder extends StatelessWidget {
  final VenueReviewModel review;
  const _GridPlaceholder({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.location, color: context.colors.primary, size: 22),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              review.venueName,
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
