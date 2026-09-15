import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/notifiers/auth_notifier.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/sign_in_form_provider.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final emailController = ref.watch(signInEmailControllerProvider);
    final passwordController = ref.watch(signInPasswordControllerProvider);

    // ── Durum Dinleyici ──────────────────────────────────────────────────────
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        showAppAlert(
          context: context,
          type: AppAlertType.error,
          title: 'auth.sign_in_failed'.tr(),
          text: next.errorMessage!.tr(),
          confirmBtnText: 'common.ok'.tr(),
          confirmBtnColor: context.colors.primary,
          barrierDismissible: true,
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            ref.read(authProvider.notifier).clearError();
          },
        );
      }

      if (!(previous?.isAuthenticated ?? false) && next.isAuthenticated) {
        if (next.needsEmailVerification) {
          context.go(AppRoutes.verification, extra: next.user?.email ?? '');
        } else {
          context.go(AppRoutes.main);
        }
      }
    });

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 50;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  keyboardHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: isKeyboardOpen ? 16 : 32),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: isKeyboardOpen ? 60 : 100,
                    child: Image.asset(
                      'assets/images/logo_icon.png',
                      fit: BoxFit.fitHeight,
                    ),
                  ),

                  SizedBox(height: isKeyboardOpen ? 20 : 36),

                  AppTextField(
                    controller: emailController,
                    label: 'auth.email'.tr(),
                    hint: 'auth.email_hint'.tr(),
                    prefixIcon: Iconsax.message,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: passwordController,
                    label: 'auth.password'.tr(),
                    hint: 'auth.password_hint'.tr(),
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _submit(ref, emailController, passwordController),
                  ),

                  const SizedBox(height: 4),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: Text(
                        'auth.forgot_password'.tr(),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _submit(
                              ref,
                              emailController,
                              passwordController,
                            ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.card,
                              ),
                            )
                          : Text(
                              'auth.sign_in'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── VEYA ayırıcı ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'auth.or'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.colors.border)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Google ile Giriş ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(authProvider.notifier)
                                .signInWithGoogle(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: context.colors.card,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'auth.sign_in_with_google'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Apple ile Giriş — sadece iOS'ta göster ───────────────
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => ref
                                  .read(authProvider.notifier)
                                  .signInWithApple(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: context.colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: context.colors.card,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apple,
                              size: 24,
                              color: context.colors.textPrimary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'auth.sign_in_with_apple'.tr(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.no_account'.tr(),
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signUp),
                        child: Text(
                          'auth.sign_up'.tr(),
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  if (!isKeyboardOpen) ...[
                    const Center(child: LanguageSwitcherCard()),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(
    WidgetRef ref,
    TextEditingController email,
    TextEditingController password,
  ) {
    ref
        .read(authProvider.notifier)
        .signIn(email: email.text.trim(), password: password.text.trim());
  }
}
