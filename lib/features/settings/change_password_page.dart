import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:quickalert/quickalert.dart';

final currentPasswordControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
      final c = TextEditingController();
      ref.onDispose(c.dispose);
      return c;
    });

final newPasswordControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
      final c = TextEditingController();
      ref.onDispose(c.dispose);
      return c;
    });

final confirmPasswordControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
      final c = TextEditingController();
      ref.onDispose(c.dispose);
      return c;
    });

final changePasswordLoadingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

class ChangePasswordPage extends ConsumerWidget {
  const ChangePasswordPage({super.key});

  Future<void> _onSave(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currentPasswordControllerProvider).text.trim();
    final newPass = ref.read(newPasswordControllerProvider).text.trim();
    final confirm = ref.read(confirmPasswordControllerProvider).text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'Eksik Alan',
        text: 'Lütfen tüm alanları doldurun.',
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    if (newPass.length < 6) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Geçersiz Şifre',
        text: 'Yeni şifre en az 6 karakter olmalıdır.',
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    if (newPass != confirm) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Şifre Uyuşmuyor',
        text: 'Yeni şifre ve tekrar alanları aynı olmalıdır.',
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    ref.read(changePasswordLoadingProvider.notifier).state = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null)
        throw Exception('Kullanıcı bulunamadı');

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPass);

      ref.read(changePasswordLoadingProvider.notifier).state = false;
      if (!context.mounted) return;

      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Başarılı',
        text: 'Şifren başarıyla güncellendi.',
        confirmBtnColor: context.colors.primary,
        onConfirmBtnTap: () {
          Navigator.pop(context);
          context.pop();
        },
      );
    } on FirebaseAuthException catch (e) {
      ref.read(changePasswordLoadingProvider.notifier).state = false;
      if (!context.mounted) return;
      final msg = e.code == 'wrong-password'
          ? 'Mevcut şifren yanlış.'
          : 'Şifre güncellenemedi: ${e.message}';
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Hata',
        text: msg,
        confirmBtnColor: context.colors.primary,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(changePasswordLoadingProvider);
    final currentCtrl = ref.watch(currentPasswordControllerProvider);
    final newCtrl = ref.watch(newPasswordControllerProvider);
    final confirmCtrl = ref.watch(confirmPasswordControllerProvider);

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
          'Şifre Değiştir',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.primary.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.colors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Güçlü bir şifre büyük harf, rakam ve özel karakter içermelidir.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppTextField(
                controller: currentCtrl,
                label: 'Mevcut Şifre',
                hint: 'Mevcut şifreni gir',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: newCtrl,
                label: 'Yeni Şifre',
                hint: 'En az 6 karakter',
                prefixIcon: Icons.lock_reset,
                isPassword: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: confirmCtrl,
                label: 'Yeni Şifre (Tekrar)',
                hint: 'Yeni şifreni tekrar gir',
                prefixIcon: Icons.lock_reset,
                isPassword: true,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _onSave(context, ref),
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
                          'Şifremi Güncelle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
