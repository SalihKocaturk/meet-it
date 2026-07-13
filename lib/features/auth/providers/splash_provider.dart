import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

/// Splash screen için hazır-mı sinyali.
///
/// En az 2 saniye bekler, ardından SharedPreferences'tan oturum yüklenene
/// kadar (genellikle < 50ms) polling yapar. Tamamlandığında `isAuthenticated`
/// değerini döner → çağıran `SplashPage` bu değere göre navigasyon kararı
/// verir (bkz. `ref.listen` kullanımı).
final splashReadyProvider = FutureProvider.autoDispose<bool>((ref) async {
  await Future.delayed(const Duration(seconds: 2));

  // Session yükleniyorsa bitene kadar bekle (genellikle < 50ms)
  while (ref.read(authProvider).isSessionLoading) {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  return ref.read(authProvider).isAuthenticated;
});
