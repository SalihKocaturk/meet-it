import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

/// Google ile ilk kez giriş yapan kullanıcının profilini tamamlama
/// formunun (CompleteProfilePage) controller/provider'ları.
///
/// `sign_up_form_provider.dart`'ın küçültülmüş bir kopyası — KASITLI
/// OLARAK email ve şifre alanı YOK, çünkü bu bilgiler Google hesabından
/// zaten geliyor (bkz. CompleteProfilePage).
final completeProfileLocationControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final completeProfileAgeControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final completeProfileGenderProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Haritadan seçilen gerçek konum (lat/lng + adres metni) — sign-up
/// formundaki aynı `UserLocation` tipini kullanır (bkz. match_provider.dart).
final completeProfilePickedLocationProvider =
    StateProvider.autoDispose<UserLocation?>((ref) => null);

/// Profil tamamlama sayfası yüklendiğinde Firestore/Google'dan gelen mevcut
/// verileri form alanlarına otomatik dolduran tek-seferlik provider.
///
/// `Provider.autoDispose<void>` — yani bir değer üretmiyor, sadece yan etki
/// (form doldurma) yaratıyor. `CompleteProfilePage` bunu `ref.watch` ile
/// izlediğinde provider ilk kez oluşturulur ve `addPostFrameCallback`
/// ile ilk build'den SONRAKİ frame'de form alanlarını doldurur.
/// `autoDispose` sayesinde sayfa kapandığında provider da dispose edilir
/// -> sonraki açılışta taze bir init çalışır.
final completeProfileInitProvider = Provider.autoDispose<void>((ref) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (user.location != null && user.location!.trim().isNotEmpty) {
      ref.read(completeProfileLocationControllerProvider).text = user.location!;
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
  });
});
