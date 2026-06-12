import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/notifiers/auth_notifier.dart';

// Ana auth notifier provider'ı
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// Kullanıcı bilgisine kolayca erişmek için derived provider
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

// Bir auth işlemi (signIn/signUp) devam ediyor mu?
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

// Uygulama açılışında SharedPreferences'tan oturum yükleniyor mu?
final sessionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isSessionLoading;
});

// Hata mesajı için derived provider
final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).errorMessage;
});

// Giriş yapılmış mı kontrolü için derived provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

// Kişilik testi tamamlandı mı?
final hasPersonalityProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).hasPersonality;
});
