import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/core/widgets/langauge_switcher.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/sign_up_form_provider.dart';
import 'package:meetit/features/match/match_page.dart' show MapLocationPickerPage;
import 'package:meetit/features/match/providers/match_provider.dart';

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

    await ref
        .read(authProvider.notifier)
        .signUp(
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

    // Yeni kayıt olanlara önce email doğrulama sayfasına yönlendir —
    // hesaba gönderilen onay mailini doğrulamadan quiz'e geçemezler
    // (router'daki `needsEmailVerification` kontrolü de bunu zaten
    // garanti eder, burada sadece doğru sayfaya gidiyoruz). "Devam Et"e
    // basılınca yönlendirir.
    showAppAlert(
      context: context,
      type: AppAlertType.success,
      title: 'auth.welcome'.tr(),
      text: 'auth.account_created'.tr(),
      confirmBtnText: 'common.ok'.tr(),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.of(context).pop();
        context.go(AppRoutes.verification, extra: email);
      },
    );
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

              _SignUpLocationField(locationCtrl: locationCtrl),
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
                      fillColor: context.colors.card,
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

// ── Kayıt Sırasında Gerçek Konum Seçimi ─────────────────────────────────────
//
// Düz metin alanı yerine, uygulamanın diğer yerlerinde (Match, Settings)
// kullanılan harita tabanlı konum seçiciyi (MapLocationPickerPage) burada
// da kullanıyoruz. Henüz Firebase hesabı oluşturulmadığı için seçilen
// lat/lng `signUpPickedLocationProvider`'da tutulur; hesap oluşturulduktan
// SONRA AuthNotifier.signUp() bunu UserModel'e yazar (bkz. _onSignUp).
class _SignUpLocationField extends ConsumerWidget {
  final TextEditingController locationCtrl;

  const _SignUpLocationField({required this.locationCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(signUpPickedLocationProvider);
    final hasCoords = picked?.hasCoords ?? false;

    Future<void> pickLocation() async {
      final result = await Navigator.of(context).push<UserLocation>(
        MaterialPageRoute(builder: (_) => const MapLocationPickerPage()),
      );
      if (result == null) return;
      ref.read(signUpPickedLocationProvider.notifier).state = result;
      // Doğrulama mantığı hâlâ text controller'a bakıyor — senkron tutuyoruz.
      locationCtrl.text = result.text;
    }

    // Diğer alanlarla (isim, e-posta, şifre) aynı düz text field görünümü —
    // ama dokunulduğunda klavye yerine harita seçiciyi (MapLocationPickerPage)
    // açar ve seçilen konumu alana yazar. AbsorbPointer, alanın kendisinin
    // odak/klavye almasını engelleyip dokunuşu dıştaki GestureDetector'a
    // bırakır.
    return GestureDetector(
      onTap: pickLocation,
      child: AbsorbPointer(
        child: AppTextField(
          controller: locationCtrl,
          label: 'auth.city_location'.tr(),
          hint: 'auth.location_hint'.tr(),
          prefixIcon: hasCoords
              ? Icons.location_on
              : Icons.location_on_outlined,
          suffixIcon: Icon(
            Icons.chevron_right,
            size: 18,
            color: context.colors.hint,
          ),
          readOnly: true,
        ),
      ),
    );
  }
}
