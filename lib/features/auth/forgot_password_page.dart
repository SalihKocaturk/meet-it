import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/forgot_password_form_provider.dart';

class ForgotPasswordPage extends ConsumerWidget {
  const ForgotPasswordPage({super.key});

  Future<void> _onSend(BuildContext context, WidgetRef ref) async {
    final email = ref.read(forgotPasswordEmailControllerProvider).text.trim();

    if (email.isEmpty) {
      showAppAlert(
        context: context,
        type: AppAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'auth.enter_email_warning'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    await ref.read(authProvider.notifier).forgotPassword(email);

    if (!context.mounted) return;
    final error = ref.read(authErrorProvider);
    if (error != null) {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'auth.send_failed'.tr(),
        text: error.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      ref.read(authProvider.notifier).clearError();
      return;
    }

    ref.read(forgotPasswordEmailSentProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final emailSent = ref.watch(forgotPasswordEmailSentProvider);
    final emailController = ref.watch(forgotPasswordEmailControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'auth.forgot_password_title'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: emailSent
              ? _buildSuccess(context)
              : _buildForm(context, ref, isLoading, emailController),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    bool isLoading,
    TextEditingController emailController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 32),
        Icon(Icons.lock_reset, size: 56, color: context.colors.primary),
        SizedBox(height: 20),
        Text(
          'auth.forgot_password_subtitle'.tr(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'auth.forgot_password_desc'.tr(),
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 32),
        AppTextField(
          controller: emailController,
          label: 'auth.email'.tr(),
          hint: 'auth.email_hint'.tr(),
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () => _onSend(context, ref),
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
                    'auth.send_link'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: context.colors.success,
        ),
        SizedBox(height: 24),
        Text(
          'auth.email_sent'.tr(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'auth.email_sent_desc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: context.colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'auth.back_to_sign_in'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
