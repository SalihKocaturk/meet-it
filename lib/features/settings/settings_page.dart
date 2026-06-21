import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friend_code_page.dart';
import 'package:meetit/features/match/match_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/core/widgets/app_alert.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Sadece email/şifre ile giriş yapıldıysa true döner
  bool _isEmailUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  void _showLogoutAlert(BuildContext context, WidgetRef ref) {
    showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'settings.sign_out_title'.tr(),
      text: 'settings.sign_out_confirm'.tr(),
      confirmBtnText: 'settings.sign_out_yes'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
      confirmBtnColor: context.colors.error,
      headerBackgroundColor: context.colors.error.withOpacity(0.1),
      onConfirmBtnTap: () async {
        Navigator.pop(context);
        await ref.read(authProvider.notifier).signOut();
        if (!context.mounted) return;
        context.go(AppRoutes.signIn);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isEmailUser = _isEmailUser();

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('settings.title'.tr(),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary)),
              ),
            ),

            SizedBox(height: 20),

            // Profil kartı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.editProfile),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      currentUser?.photoUrl != null
                          ? CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  NetworkImage(currentUser!.photoUrl!),
                            )
                          : CircularAvatar(
                              name: currentUser?.name ?? 'K', radius: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentUser?.name ?? 'common.user'.tr(),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary)),
                            Text(currentUser?.email ?? '',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.textSecondary)),
                            if (currentUser?.location != null)
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: context.colors.hint),
                                  SizedBox(width: 2),
                                  Text(currentUser!.location!,
                                      style: TextStyle(
                                          fontSize: 12, color: context.colors.hint)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('common.edit'.tr(),
                            style: TextStyle(
                                fontSize: 11,
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SettingsSection(
                    title: 'settings.section_account'.tr(),
                    items: [
                      _SettingsItem(
                        icon: Icons.person_outline,
                        title: 'settings.edit_profile'.tr(),
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      if (isEmailUser)
                        _SettingsItem(
                          icon: Icons.lock_outline,
                          title: 'settings.change_password'.tr(),
                          onTap: () => context.push(AppRoutes.changePassword),
                        ),
                      _SettingsItem(
                        icon: Icons.psychology_outlined,
                        title: 'settings.retake_quiz'.tr(),
                        subtitle: 'settings.retake_quiz_desc'.tr(),
                        onTap: () => context.push(AppRoutes.quiz),
                      ),
                      _SettingsItem(
                        icon: Icons.location_on_outlined,
                        title: 'settings.update_location'.tr(),
                        subtitle: ref.watch(userLocationProvider)?.text,
                        onTap: () async {
                          final current = ref.read(userLocationProvider);
                          final result =
                              await Navigator.of(context).push<UserLocation>(
                            MaterialPageRoute(
                              builder: (_) => MapLocationPickerPage(
                                initial: current?.hasCoords == true
                                    ? LatLng(current!.lat!, current.lng!)
                                    : null,
                              ),
                            ),
                          );
                          if (result != null) {
                            ref.read(userLocationProvider.notifier).state =
                                result;
                          }
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.tag,
                        title: 'settings.add_friend_code'.tr(),
                        subtitle: 'settings.add_friend_code_desc'.tr(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FriendCodePage()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _SettingsSection(
                    title: 'settings.section_app'.tr(),
                    items: [
                      _SettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'settings.notifications'.tr(),
                        onTap: () {},
                      ),
                      _SettingsItem(
                        icon: Icons.language_outlined,
                        title: 'settings.language'.tr(),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.locale.languageCode == 'tr' ? '🇹🇷' : '🇬🇧',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.locale.languageCode == 'tr'
                                  ? 'Türkçe'
                                  : 'English',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary),
                            ),
                          ],
                        ),
                        onTap: () => showLanguagePickerSheet(context),
                      ),
                      _SettingsItem(
                        icon: Icons.info_outline,
                        title: 'settings.about'.tr(),
                        onTap: () {
                          showAppAlert(
                            context: context,
                            type: AppAlertType.info,
                            title: 'MeetIt',
                            text: 'settings.about_text'.tr(),
                            confirmBtnText: 'common.ok'.tr(),
                            confirmBtnColor: context.colors.primary,
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: context.colors.error),
                      title: Text('settings.sign_out'.tr(),
                          style: TextStyle(
                              color: context.colors.error,
                              fontWeight: FontWeight.w600)),
                      onTap: () => _showLogoutAlert(context, ref),
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: items
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < items.length - 1)
                          const Divider(height: 1, indent: 52, endIndent: 16),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.primary, size: 22),
      title: Text(title,
          style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, size: 14, color: context.colors.hint),
      onTap: onTap,
    );
  }
}
