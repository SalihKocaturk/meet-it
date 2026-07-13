import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/complete_profile_form_provider.dart';
import 'package:meetit/features/match/match_page.dart' show MapLocationPickerPage;
import 'package:meetit/features/match/providers/match_provider.dart';

/// Profil tamamlama sayfasında gerçek konum seçimi.
///
/// `SignUpLocationField` ile birebir aynı desen — farklı provider'lar kullanır.
class CompleteProfileLocationField extends ConsumerWidget {
  const CompleteProfileLocationField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(completeProfileLocationControllerProvider);
    final picked = ref.watch(completeProfilePickedLocationProvider);
    final hasCoords = picked?.hasCoords ?? false;

    Future<void> pickLocation() async {
      final result = await Navigator.of(context).push<UserLocation>(
        MaterialPageRoute(builder: (_) => const MapLocationPickerPage()),
      );
      if (result == null) return;
      ref.read(completeProfilePickedLocationProvider.notifier).state = result;
      controller.text = result.text;
    }

    return GestureDetector(
      onTap: pickLocation,
      child: AbsorbPointer(
        child: AppTextField(
          controller: controller,
          label: 'auth.city_location'.tr(),
          hint: 'auth.location_hint'.tr(),
          prefixIcon: hasCoords ? Iconsax.location : Iconsax.location,
          suffixIcon: Icon(
            Iconsax.arrow_right_3,
            size: 18,
            color: context.colors.hint,
          ),
          readOnly: true,
        ),
      ),
    );
  }
}
