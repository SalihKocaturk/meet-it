import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/utils/validators.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/sign_up_form_provider.dart';

/// Email alanı — blur (odak kaybı) sonrası canlı format doğrulaması.
///
/// Durum, StatefulWidget yerine Riverpod provider'larında tutulur:
/// - `signUpEmailTouchedProvider`: alan ilk kez odaktan çıktıktan sonra true
/// - `signUpEmailErrorProvider`: geçersizse hata metni, geçerliyse null
///
/// `Focus` widget'ının `onFocusChange` callback'i, StatefulWidget'taki
/// `FocusNode` + listener kombinasyonunun yerini alır.
class SignUpEmailField extends ConsumerWidget {
  const SignUpEmailField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(signUpEmailControllerProvider);
    final errorText = ref.watch(signUpEmailErrorProvider);

    void validate() {
      final text = controller.text.trim();
      final touched = ref.read(signUpEmailTouchedProvider);
      if (!touched) return;
      final err = (text.isEmpty || Validators.isValidEmail(text))
          ? null
          : 'validation.invalid_email_message'.tr();
      ref.read(signUpEmailErrorProvider.notifier).state = err;
    }

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          // İlk kez odaktan çıkıyor → touched yap ve hemen doğrula
          ref.read(signUpEmailTouchedProvider.notifier).state = true;
          validate();
        }
      },
      child: AppTextField(
        controller: controller,
        label: 'auth.email'.tr(),
        hint: 'auth.email_hint'.tr(),
        prefixIcon: Iconsax.message,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        errorText: errorText,
        onChanged: (_) => validate(),
      ),
    );
  }
}
