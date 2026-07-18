import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/features/auth/providers/verification_provider.dart';

/// Email doğrulama sayfası.
///
/// NOT: Bu sayfa artık kayıt/giriş sonrası ZORUNLU olarak otomatik
/// gösterilmiyor. Sadece `important_action_guard.dart`'taki
/// `ensureEmailVerified()` tarafından, kullanıcı "önemli" bir işlem
/// (arkadaş ekleme, buluşma/mekan arama) denediğinde PUSH edilir.
///
/// `StatefulWidget` yok — `verificationProvider` (`VerificationNotifier`)
/// `isChecking`, `isResending`, `cooldownRemaining` state'lerini ve
/// `Timer` yaşam döngüsünü (`ref.onDispose`) yönetir.
class VerificationPage extends ConsumerWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  Future<void> _onCheckPressed(BuildContext context, WidgetRef ref) async {
    final verified =
        await ref.read(verificationProvider.notifier).checkVerified();
    if (!context.mounted) return;

    if (verified) {
      // Hem push (guard) hem go_router (eski senaryo) desteği
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(true);
      } else {
        context.go(AppRoutes.main);
      }
    } else {
      showAppAlert(
        context: context,
        type: AppAlertType.warning,
        title: 'auth.verify_not_yet_title'.tr(),
        text: 'auth.verify_not_yet_desc'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
    }
  }

  Future<void> _onResendPressed(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(verificationProvider.notifier).resendEmail();
    if (!context.mounted) return;

    if (success) {
      showAppAlert(
        context: context,
        type: AppAlertType.success,
        title: 'auth.welcome'.tr(),
        text: 'auth.verify_resent_success'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
    } else {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'auth.send_failed'.tr(),
        text: 'auth.verify_resent_failed'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
    }
  }

  void _onChangeAccountPressed(BuildContext context, WidgetRef ref) {
    ref.read(verificationProvider.notifier).signOut();
    context.go(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Iconsax.arrow_left_2,
                  color: context.colors.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(false),
              )
            : null,
        title: Text(
          'auth.verify_title'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.message,
                size: 80,
                color: context.colors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'auth.verify_heading'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'auth.verify_desc'.tr(namedArgs: {'email': email}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // Doğruladım butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isChecking
                      ? null
                      : () => _onCheckPressed(context, ref),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: state.isChecking
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.card,
                          ),
                        )
                      : Text(
                          'auth.verify_confirm_btn'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Tekrar gönder
              TextButton(
                onPressed:
                    (state.isResending || state.cooldownRemaining > 0)
                        ? null
                        : () => _onResendPressed(context, ref),
                child: state.isResending
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : Text(
                        state.cooldownRemaining > 0
                            ? '${'auth.verify_resend_cooldown'.tr()} (${state.cooldownRemaining}s)'
                            : 'auth.verify_resend_btn'.tr(),
                        style: TextStyle(
                          color: state.cooldownRemaining > 0
                              ? context.colors.textSecondary
                              : context.colors.primary,
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => _onChangeAccountPressed(context, ref),
                child: Text(
                  'auth.verify_change_account'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
