import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/utils/app_snackbar.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/forgot_password_form_provider.dart';

class ForgotPasswordPage extends ConsumerWidget {
  const ForgotPasswordPage({super.key});

  Future<void> _onSend(BuildContext context, WidgetRef ref) async {
    final email = ref.read(forgotPasswordEmailControllerProvider).text.trim();

    if (email.isEmpty) {
      AppSnackbar.warning(
        context,
        title: 'Eksik Alan',
        message: 'Lütfen email adresinizi girin.',
      );
      return;
    }

    await ref.read(authProvider.notifier).forgotPassword(email);

    if (!context.mounted) return;
    final error = ref.read(authErrorProvider);
    if (error != null) {
      AppSnackbar.error(context, title: 'Gönderim Başarısız', message: error);
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
          'Şifremi Unuttum',
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
          'Şifreni sıfırla',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Kayıtlı email adresine şifre sıfırlama bağlantısı göndereceğiz.',
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 32),
        AppTextField(
          controller: emailController,
          label: 'Email',
          hint: 'ornek@email.com',
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
                : const Text(
                    'Bağlantı Gönder',
                    style: TextStyle(
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
          'Email Gönderildi!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Şifre sıfırlama bağlantısı email adresinize gönderildi. Lütfen gelen kutunuzu kontrol edin.',
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
              'Giriş Sayfasına Dön',
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
