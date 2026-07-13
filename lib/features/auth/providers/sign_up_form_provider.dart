import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// Sign Up form controller provider'ları (autoDispose)
final signUpNameControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final signUpEmailControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final signUpPasswordControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final signUpLocationControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

final signUpAgeControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

// Cinsiyet seçimi için StateProvider (String? — opsiyonel)
final signUpGenderProvider = StateProvider.autoDispose<String?>((ref) => null);

// Haritadan seçilen gerçek konum (lat/lng + adres metni). Henüz Firebase
// hesabı yokken sadece burada (form state'inde) tutulur; hesap
// oluşturulduktan SONRA AuthNotifier.signUp() içinde UserModel'e lat/lng
// olarak yazılır (bkz. sign_up_page.dart _onSignUp).
final signUpPickedLocationProvider =
    StateProvider.autoDispose<UserLocation?>((ref) => null);

// ── Email canlı doğrulama state'leri ─────────────────────────────────────────
// SignUpEmailField (ConsumerWidget) tarafından kullanılır.
// `touched`: alan odaktan ilk kez çıktığında true olur — daha önce hata
// gösterme. `emailError`: geçersizse hata metni, geçerliyse/boşsa null.
final signUpEmailTouchedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final signUpEmailErrorProvider =
    StateProvider.autoDispose<String?>((ref) => null);
