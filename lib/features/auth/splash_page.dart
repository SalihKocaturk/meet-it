import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/splash_provider.dart';
import 'package:meetit/features/auth/widgets/pulsing_logo.dart';

/// Uygulama açılış ekranı.
///
/// `splashReadyProvider` en az 2 saniye bekler, ardından SharedPreferences'tan
/// oturum bilgisi yüklenince `isAuthenticated` değerini döner. `ref.listen`
/// bu değeri dinleyip navigasyon kararı verir — `StatefulWidget` yok, saf
/// `ConsumerWidget`.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `splashReadyProvider` tamamlandığında (AsyncData) navigasyon yapar.
    ref.listen(splashReadyProvider, (_, next) {
      next.whenData((isAuthenticated) {
        if (!context.mounted) return;
        context.go(
          isAuthenticated ? AppRoutes.main : AppRoutes.signIn,
        );
      });
    });

    return Scaffold(
      // Splash her zaman light primary rengiyle gösterilir — logo PNG bu
      // renk üzerine tasarlandığı için dark modda primary koyu yeşile
      // kaydığında logo "ayrılıyordu". Splash screen tasarımı tema-bağımsız
      // olmalı (marka rengi sabit), AppColors.light.primary tam bunu sağlar.
      backgroundColor: AppColors.light.primary,
      body: const Center(child: PulsingLogo()),
    );
  }
}
