import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/complete_profile_form_provider.dart';
import 'package:meetit/features/auth/widgets/complete_profile_avatar_row.dart';
import 'package:meetit/features/auth/widgets/complete_profile_location_field.dart';
import 'package:meetit/features/auth/widgets/gender_dropdown.dart';

/// Google ile İLK KEZ giriş yapan kullanıcıya gösterilen profil tamamlama
/// sayfası.
///
/// `StatefulWidget` yok — durum tamamen provider'larda tutulur.
/// Başlangıç verisi (Google'dan gelen isim, mevcut konum vb.) ilk build
/// sonrası `completeProfileInitProvider` tarafından otomatik doldurulur.
class CompleteProfilePage extends ConsumerWidget {
  const CompleteProfilePage({super.key});

  Future<void> _onSubmit(BuildContext context, WidgetRef ref) async {
    final location =
        ref.read(completeProfileLocationControllerProvider).text.trim();
    final pickedLocation = ref.read(completeProfilePickedLocationProvider);
    final ageText = ref.read(completeProfileAgeControllerProvider).text.trim();
    final gender = ref.read(completeProfileGenderProvider);

    if (location.isEmpty || ageText.isEmpty) {
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

    await ref.read(authProvider.notifier).completeProfile(
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

    context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tek seferlik form ön doldurma — sayfanın ilk build'i tamamlandıktan
    // sonra `addPostFrameCallback` ile çalışır (bkz. completeProfileInitProvider).
    ref.watch(completeProfileInitProvider);

    final isLoading = ref.watch(authLoadingProvider);
    final selectedGender = ref.watch(completeProfileGenderProvider);
    final ageCtrl = ref.watch(completeProfileAgeControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.profile_circle,
                  size: 56, color: context.colors.primary),
              const SizedBox(height: 16),
              Text(
                'auth.complete_profile_heading'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'auth.complete_profile_desc'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              const CompleteProfileAvatarRow(),
              const CompleteProfileLocationField(),
              const SizedBox(height: 16),

              AppTextField(
                controller: ageCtrl,
                label: 'auth.age'.tr(),
                hint: 'auth.age_hint'.tr(),
                prefixIcon: Iconsax.cake,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

              GenderDropdown(
                value: selectedGender,
                onChanged: (v) => ref
                    .read(completeProfileGenderProvider.notifier)
                    .state = v,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isLoading ? null : () => _onSubmit(context, ref),
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
                          'auth.complete_profile_button'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
