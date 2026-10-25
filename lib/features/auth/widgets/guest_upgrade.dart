import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

// ── Misafir → hesap ──────────────────────────────────────────────────────────
//
// Misafirler mekan arayabilir, konum linki ve oylama paylaşabilir. Arkadaş
// ekleme, yorum ve davet kartı gibi sosyal özellikler hesap ister. Hesap
// açılırken misafir oturumu aynı uid'e bağlanır; test ve konum korunur.

/// Kullanıcı misafirse hesap açma alt sayfasını gösterir.
/// Dönüş: kullanıcı (artık) gerçek bir hesapla girmişse `true`.
Future<bool> ensureFullAccount(BuildContext context, WidgetRef ref) async {
  if (!ref.read(authProvider).isGuest) return true;
  await showGuestUpgradeSheet(context);
  if (!context.mounted) return false;
  return !ref.read(authProvider).isGuest;
}

Future<void> showGuestUpgradeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _GuestUpgradeSheet(),
  );
}

class _GuestUpgradeSheet extends ConsumerWidget {
  const _GuestUpgradeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Bağlama başarılı olunca sayfayı kendiliğinden kapat.
    ref.listen(authProvider, (prev, next) {
      if ((prev?.isGuest ?? false) && !next.isGuest && next.user != null) {
        Navigator.of(context).maybePop();
      }
    });

    Widget button({
      required Widget icon,
      required String label,
      required VoidCallback? onTap,
      bool primary = false,
    }) {
      return SizedBox(
        width: double.infinity,
        child: primary
            ? ElevatedButton.icon(
                onPressed: onTap,
                icon: icon,
                label: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Emerald.base,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: icon,
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
      );
    }

    final busy = auth.isLoading;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'guest.upgrade_title'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'guest.upgrade_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            button(
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/google_logo.png',
                  width: 16,
                  height: 16,
                ),
              ),
              label: 'auth.sign_in_with_google'.tr(),
              primary: true,
              onTap: busy
                  ? null
                  : () => ref.read(authProvider.notifier).signInWithGoogle(),
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 10),
              button(
                icon: Icon(
                  Icons.apple,
                  color: context.colors.textPrimary,
                  size: 22,
                ),
                label: 'auth.sign_in_with_apple'.tr(),
                onTap: busy
                    ? null
                    : () => ref.read(authProvider.notifier).signInWithApple(),
              ),
            ],
            const SizedBox(height: 10),
            button(
              icon: Icon(
                Icons.mail_outline_rounded,
                color: context.colors.textPrimary,
                size: 20,
              ),
              label: 'guest.sign_up_email'.tr(),
              onTap: busy
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.signUp);
                    },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      // Var olan hesaba geçiş: misafir oturumu kapanır.
                      Navigator.of(context).pop();
                      await ref.read(authProvider.notifier).signOut();
                    },
              child: Text(
                'guest.have_account'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.accentStrong,
                ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                auth.errorMessage!.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Misafirken sosyal sekmelerin (ör. Arkadaşlar) yerine gösterilen panel.
class GuestLockedPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const GuestLockedPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Emerald.base.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: context.accentStrong),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => showGuestUpgradeSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Emerald.base,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'guest.create_account'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
