import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

/// Hesap oluşturulduktan sonra (veya henüz doğrulamamış bir hesapla giriş
/// yapıldığında) gösterilen email doğrulama sayfası.
///
/// Akış:
/// 1. `signUp()` zaten Firebase'e gerçek bir doğrulama maili gönderdi
///    (bkz. `AuthNotifier.signUp`). Bu sayfa o mailin tıklanmasını bekler.
/// 2. "Doğruladım, Devam Et" → `checkEmailVerified()` ile Firebase'den taze
///    durumu çeker; doğrulanmışsa router otomatik olarak quiz/ana sayfaya
///    yönlendirir (bkz. `app_router.dart`'taki `needsEmailVerification`
///    kontrolü), doğrulanmamışsa kullanıcıyı bilgilendirir.
/// 3. "Tekrar Gönder" → gerçek `sendEmailVerification()` çağrısı, 30 saniye
///    bekleme süresiyle (spam/abuse'u önlemek için).
class VerificationPage extends ConsumerStatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  static const _resendCooldownSeconds = 30;

  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = _resendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) timer.cancel();
      });
    });
  }

  Future<void> _onCheckPressed() async {
    setState(() => _isChecking = true);
    final isVerified =
        await ref.read(authProvider.notifier).checkEmailVerified();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (isVerified) {
      final hasPersonality = ref.read(authProvider).hasPersonality;
      context.go(hasPersonality ? AppRoutes.main : AppRoutes.quiz);
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

  Future<void> _onResendPressed() async {
    setState(() => _isResending = true);
    final success =
        await ref.read(authProvider.notifier).resendVerificationEmail();
    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      showAppAlert(
        context: context,
        type: AppAlertType.success,
        title: 'auth.welcome'.tr(),
        text: 'auth.verify_resent_success'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      _startCooldown();
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

  void _onChangeAccountPressed() {
    ref.read(authProvider.notifier).signOut();
    context.go(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                Icons.mark_email_unread_outlined,
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
                'auth.verify_desc'.tr(namedArgs: {'email': widget.email}),
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
                  onPressed: _isChecking ? null : _onCheckPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isChecking
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
                onPressed: (_isResending || _cooldownRemaining > 0)
                    ? null
                    : _onResendPressed,
                child: _isResending
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : Text(
                        _cooldownRemaining > 0
                            ? '${'auth.verify_resend_cooldown'.tr()} (${_cooldownRemaining}s)'
                            : 'auth.verify_resend_btn'.tr(),
                        style: TextStyle(
                          color: _cooldownRemaining > 0
                              ? context.colors.textSecondary
                              : context.colors.primary,
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: _onChangeAccountPressed,
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
