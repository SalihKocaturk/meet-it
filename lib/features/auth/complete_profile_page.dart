import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/complete_profile_form_provider.dart';
import 'package:meetit/features/match/match_page.dart' show MapLocationPickerPage;
import 'package:meetit/features/match/providers/match_provider.dart';

/// Google ile İLK KEZ giriş yapan kullanıcıya gösterilen profil tamamlama
/// sayfası.
///
/// `signInWithGoogle()` sadece uid/isim/email/foto ile minimal bir
/// UserModel oluşturduğu için (bkz. AuthNotifier.signInWithGoogle), konum/
/// yaş/cinsiyet alanları her zaman eksik kalır. Router (`app_router.dart`),
/// `AuthState.needsProfileCompletion` true olduğu sürece kullanıcıyı buraya
/// yönlendirir — quiz'den ve ana sayfadan ÖNCE.
///
/// `SignUpPage`'in küçültülmüş bir kopyası: email/şifre alanı YOK (Google'dan
/// zaten geldi), email doğrulama adımı YOK (Google hesapları doğrulanmış
/// sayılır) — form gönderildikten sonra router otomatik olarak quiz'e veya
/// (quiz zaten tamamlanmışsa) ana sayfaya yönlendirir.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // NOT (bug fix): Bu satır önceden `build()` içinde DOĞRUDAN çağrılıyordu.
    // `_prefillIfNeeded`, `completeProfilePickedLocationProvider` gibi bir
    // StateProvider'ın state'ini set ediyor — bu, widget ağacı henüz build
    // OLURKEN bir provider'ı değiştirmeye çalıştığı için Riverpod'un
    // "Tried to modify a provider while the widget tree was building"
    // hatasına yol açıyordu (sayfa her açıldığında pop/crash). Çözüm:
    // değişikliği build bittikten SONRAKİ ilk frame'e ertele
    // (`addPostFrameCallback`) — bu, provider state'ini build döngüsünün
    // tamamen dışında, güvenli bir zamanda değiştirir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillIfNeeded(ref);
    });
  }

  List<String> _genders() => [
        'auth.gender_male'.tr(),
        'auth.gender_female'.tr(),
        'auth.gender_other'.tr(),
      ];

  /// Google'dan/Firestore'dan gelen mevcut (kısmi) verilerle formu
  /// doldurur — kullanıcı zaten bildiğimiz hiçbir şeyi tekrar yazmasın.
  /// `initState`'teki `addPostFrameCallback` içinden sadece bir kez çalışır
  /// (`_prefilled` guard'ı).
  void _prefillIfNeeded(WidgetRef ref) {
    if (_prefilled) return;
    _prefilled = true;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (user.location != null && user.location!.trim().isNotEmpty) {
      ref.read(completeProfileLocationControllerProvider).text =
          user.location!;
    }
    if (user.hasCoords) {
      ref.read(completeProfilePickedLocationProvider.notifier).state =
          UserLocation(text: user.location ?? '', lat: user.lat, lng: user.lng);
    }
    if (user.age != null) {
      ref.read(completeProfileAgeControllerProvider).text =
          user.age!.toString();
    }
    if (user.gender != null && user.gender!.trim().isNotEmpty) {
      ref.read(completeProfileGenderProvider.notifier).state = user.gender;
    }

    // TextEditingController'lara yapılan atamalar provider state'i
    // olmadığından yukarıdaki gibi otomatik dinleyicileri tetiklemez, ama
    // dropdown'un seçili değerini gösteren `build()` bu provider'ları
    // `watch` ettiği için (gender/picked-location) o ikisi zaten otomatik
    // yeniden çizilir. Ekstra bir `setState` gerekmiyor.
  }

  Future<void> _onSubmit(BuildContext context, WidgetRef ref) async {
    final location =
        ref.read(completeProfileLocationControllerProvider).text.trim();
    final pickedLocation = ref.read(completeProfilePickedLocationProvider);
    final ageText = ref.read(completeProfileAgeControllerProvider).text.trim();
    final gender = ref.read(completeProfileGenderProvider);

    // NOT (bug fix): `gender` BİLEREK bu kontrole dahil EDİLMİYOR — alan
    // UI'da "opsiyonel" olarak gösteriliyor (bkz. dropdown hint metni),
    // dolayısıyla seçilmeden de devam edilebilmeli. Sadece konum ve yaş
    // gerçekten zorunlu.
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

    // NOT (bug fix): Önceden burada HİÇBİR ŞEY yapılmıyordu — yorum, router'ın
    // `refreshListenable` ile otomatik olarak yönlendireceğini varsayıyordu.
    // Ama bu sayfaya MapLocationPickerPage gibi imperative bir
    // `Navigator.push` ile gidilip geri dönülüyor; bu durumda go_router'ın
    // otomatik redirect tetiklemesi güvenilir çalışmıyordu — kullanıcı
    // "Devam Et"e bastığında veriler Firestore'a doğru kaydediliyordu
    // (uygulamayı yeniden başlatınca doğru sayfaya gidiyordu) ama EKRANDA
    // hiçbir geçiş olmuyordu. Çözüm: `verification_page.dart`,
    // `sign_in_page.dart` ve `splash_page.dart`'taki aynı desen — başarılı
    // bir auth işleminden sonra router'a güvenmek yerine AÇIKÇA
    // `context.go(...)` ile bir sonraki sayfaya geçiyoruz.
    // NOT: Kişilik testi artık burada ZORUNLU tetiklenmiyor — sadece
    // kullanıcı "önemli" bir işlem denediğinde devreye giriyor (bkz.
    // `important_action_guard.dart`).
    context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final selectedGender = ref.watch(completeProfileGenderProvider);
    final locationCtrl = ref.watch(completeProfileLocationControllerProvider);
    final ageCtrl = ref.watch(completeProfileAgeControllerProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_pin_circle_outlined,
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

              if (user?.name.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: context.colors.primary.withOpacity(0.15),
                        backgroundImage: (user?.photoUrl != null)
                            ? NetworkImage(user!.photoUrl!)
                            : null,
                        child: (user?.photoUrl == null)
                            ? Icon(Icons.person, color: context.colors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user!.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              _CompleteProfileLocationField(locationCtrl: locationCtrl),
              const SizedBox(height: 16),

              AppTextField(
                controller: ageCtrl,
                label: 'auth.age'.tr(),
                hint: 'auth.age_hint'.tr(),
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

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
                  const SizedBox(height: 6),
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
                    items: _genders()
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => ref
                        .read(completeProfileGenderProvider.notifier)
                        .state = v,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _onSubmit(context, ref),
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

// `sign_up_page.dart`'taki `_SignUpLocationField` ile birebir aynı desen —
// düz metin yerine harita tabanlı konum seçici (MapLocationPickerPage).
class _CompleteProfileLocationField extends ConsumerWidget {
  final TextEditingController locationCtrl;

  const _CompleteProfileLocationField({required this.locationCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(completeProfilePickedLocationProvider);
    final hasCoords = picked?.hasCoords ?? false;

    Future<void> pickLocation() async {
      final result = await Navigator.of(context).push<UserLocation>(
        MaterialPageRoute(builder: (_) => const MapLocationPickerPage()),
      );
      if (result == null) return;
      ref.read(completeProfilePickedLocationProvider.notifier).state = result;
      locationCtrl.text = result.text;
    }

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
