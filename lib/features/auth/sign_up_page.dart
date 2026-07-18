import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/utils/validators.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/sign_up_form_provider.dart';
import 'package:meetit/features/auth/widgets/gender_dropdown.dart';
import 'package:meetit/features/auth/widgets/sign_up_email_field.dart';
import 'package:meetit/features/auth/widgets/sign_up_location_field.dart';

class SignUpPage extends ConsumerWidget {
  const SignUpPage({super.key});

  Future<void> _onSignUp(BuildContext context, WidgetRef ref) async {
    final name = ref.read(signUpNameControllerProvider).text.trim();
    final email = ref.read(signUpEmailControllerProvider).text.trim();
    final password = ref.read(signUpPasswordControllerProvider).text.trim();
    final location = ref.read(signUpLocationControllerProvider).text.trim();
    final pickedLocation = ref.read(signUpPickedLocationProvider);
    final ageText = ref.read(signUpAgeControllerProvider).text.trim();
    final gender = ref.read(signUpGenderProvider);

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        location.isEmpty ||
        ageText.isEmpty) {
      showAppAlert(
        context: context,
        type: AppAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'validation.fill_required'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    if (!Validators.isValidEmail(email)) {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'validation.invalid_email'.tr(),
        text: 'validation.invalid_email_message'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    final age = int.tryParse(ageText) ?? 0;
    if (age < 18) {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'validation.invalid_age'.tr(),
        text: 'validation.must_be_18'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    await ref.read(authProvider.notifier).signUp(
          email: email,
          password: password,
          name: name,
          location: location,
          age: age,
          gender: gender,
          lat: pickedLocation?.lat,
          lng: pickedLocation?.lng,
        );

    if (!context.mounted) return;
    final error = ref.read(authErrorProvider);
    if (error != null) {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'auth.sign_up_failed'.tr(),
        text: error.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      ref.read(authProvider.notifier).clearError();
      return;
    }

    showAppAlert(
      context: context,
      type: AppAlertType.success,
      title: 'auth.welcome'.tr(),
      text: 'auth.account_created'.tr(),
      confirmBtnText: 'common.ok'.tr(),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.of(context).pop();
        context.go(AppRoutes.main);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final selectedGender = ref.watch(signUpGenderProvider);
    final nameCtrl = ref.watch(signUpNameControllerProvider);
    final passwordCtrl = ref.watch(signUpPasswordControllerProvider);
    final ageCtrl = ref.watch(signUpAgeControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'auth.sign_up'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'auth.enter_your_info'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'auth.fill_form_desc'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              AppTextField(
                controller: nameCtrl,
                label: 'auth.name_surname'.tr(),
                hint: 'auth.name_hint'.tr(),
                prefixIcon: Iconsax.profile_circle,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              const SignUpEmailField(),
              const SizedBox(height: 16),

              AppTextField(
                controller: passwordCtrl,
                label: 'auth.password'.tr(),
                hint: 'auth.min_6_chars'.tr(),
                isPassword: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              const SignUpLocationField(),
              const SizedBox(height: 16),

              AppTextField(
                controller: ageCtrl,
                label: 'auth.age'.tr(),
                hint: 'auth.age_hint'.tr(),
                prefixIcon: Iconsax.cake,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              GenderDropdown(
                value: selectedGender,
                onChanged: (v) =>
                    ref.read(signUpGenderProvider.notifier).state = v,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _onSignUp(context, ref),
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
                          'auth.sign_up'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'auth.already_have_account'.tr(),
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'auth.sign_in'.tr(),
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(child: LanguageSwitcherCard()),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
