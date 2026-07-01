import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
