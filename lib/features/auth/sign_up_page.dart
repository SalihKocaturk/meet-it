import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/utils/app_snackbar.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/sign_up_form_provider.dart';

class SignUpPage extends ConsumerWidget {
  const SignUpPage({super.key});

  List<String> _genders(BuildContext context) => [
        'auth.gender_male'.tr(),
        'auth.gender_female'.tr(),
        'auth.gender_other'.tr(),
      ];

  Future<void> _onSignUp(BuildContext context, WidgetRef ref) async {
    final name = ref.read(signUpNameControllerProvider).text.trim();
    final email = ref.read(signUpEmailControllerProvider).text.trim();
    final password = ref.read(signUpPasswordControllerProvider).text.trim();
    final location = ref.read(signUpLocationControllerProvider).text.trim();
    final ageText = ref.read(signUpAgeControllerProvider).text.trim();
    final gender = ref.read(signUpGenderProvider);

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        location.isEmpty ||
        ageText.isEmpty) {
      AppSnackbar.warning(
        context,
        title: 'validation.missing_field'.tr(),
        message: 'validation.fill_required'.tr(),
      );
      return;
    }

    final age = int.tryParse(ageText) ?? 0;
    if (age < 18) {
      AppSnackbar.error(
        context,
        title: 'validation.invalid_age'.tr(),
        message: 'validation.must_be_18'.tr(),
      );
      return;
    }

    await ref
        .read(authProvider.notifier)
        .signUp(
          email: email,
          password: password,
          name: name,
          location: location,
          age: age,
          gender: gender,
        );

    if (!context.mounted) return;
    final error = ref.read(authErrorProvider);
    if (error != null) {
      AppSnackbar.error(context, title: 'auth.sign_up_failed'.tr(), message: error.tr());
      ref.read(authProvider.notifier).clearError();
      return;
    }

    AppSnackbar.success(
      context,
      title: 'auth.welcome'.tr(),
      message: 'auth.account_created'.tr(),
    );

    await Future.delayed(const Duration(milliseconds: 1200));
    // Yeni kayıt olanlara her zaman quiz'e yönlendir
    if (context.mounted) context.go(AppRoutes.quiz);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final selectedGender = ref.watch(signUpGenderProvider);

    final nameCtrl = ref.watch(signUpNameControllerProvider);
    final emailCtrl = ref.watch(signUpEmailControllerProvider);
    final passwordCtrl = ref.watch(signUpPasswordControllerProvider);
    final locationCtrl = ref.watch(signUpLocationControllerProvider);
    final ageCtrl = ref.watch(signUpAgeControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
              SizedBox(height: 4),
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
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: emailCtrl,
                label: 'auth.email'.tr(),
                hint: 'auth.email_hint'.tr(),
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: passwordCtrl,
                label: 'auth.password'.tr(),
                hint: 'auth.min_6_chars'.tr(),
                isPassword: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: locationCtrl,
                label: 'auth.city_location'.tr(),
                hint: 'auth.location_hint'.tr(),
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: ageCtrl,
                label: 'auth.age'.tr(),
                hint: 'auth.age_hint'.tr(),
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),

              // Cinsiyet dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'auth.gender'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFFF8F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.colors.border,
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.colors.border,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                    hint: Text(
                      'auth.gender_hint'.tr(),
                      style: TextStyle(
                        color: context.colors.hint,
                        fontSize: 14,
                      ),
                    ),
                    items: _genders(context)
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) =>
                        ref.read(signUpGenderProvider.notifier).state = v,
                  ),
                ],
              ),

              SizedBox(height: 32),

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

              SizedBox(height: 20),

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

              // Dil seçici kart
              const Center(child: LanguageSwitcherCard()),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
