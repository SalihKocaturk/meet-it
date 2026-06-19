import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/features/auth/forgot_password_page.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/sign_in_page.dart';
import 'package:meetit/features/auth/sign_up_page.dart';
import 'package:meetit/features/auth/splash_page.dart';
import 'package:meetit/features/auth/verification_page.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/personality/quiz_page.dart';
import 'package:meetit/features/settings/change_password_page.dart';
import 'package:meetit/features/settings/edit_profile_page.dart';
import 'package:meetit/features/settings/settings_page.dart';

import 'app_routes.dart';

/// GoRouter instance'ı sağlayan provider.
/// main.dart içinde `ref.watch(appRouterProvider)` ile kullanılır.
///
/// NOT: Burada KASITLI OLARAK `ref.watch(authProvider)` KULLANILMIYOR.
/// Önceden bu provider `authProvider`'ı watch ediyordu; bu da authProvider'ın
/// state'i HER değiştiğinde (sadece login/logout'ta değil, edit_profile'daki
/// gibi sadece `name`/`photoUrl` gibi alanlar güncellendiğinde de) bu
/// provider'ın yeniden çalışıp YEPYENİ bir GoRouter (ve dolayısıyla yeni bir
/// Navigator) oluşturmasına sebep oluyordu. Bu da, mesela Edit Profile'da
/// "Kaydet" sonrası açık olan başarı dialog'u (QuickAlert) tam o anda eski
/// Navigator'a referans tutarken sayfa pop edilmeye çalışıldığında hataya
/// (deactivated widget / nothing to pop) yol açıyordu.
///
/// Çözüm: GoRouter'ı bir kez oluştur, `refreshListenable` ile SADECE
/// routing'i gerçekten etkileyen alanlar (isSessionLoading, isAuthenticated,
/// hasPersonality) değiştiğinde haberdar ol. Diğer profil güncellemeleri
/// router'ı hiç etkilemesin.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();

  // authProvider'ı sadece DİNLE (watch değil) — routing'i etkileyen 3 alan
  // değişmediği sürece refreshNotifier'ı tetiklemiyoruz.
  (bool, bool, bool)? lastKey;
  ref.listen(authProvider, (previous, next) {
    final key = (
      next.isSessionLoading,
      next.isAuthenticated,
      next.hasPersonality,
    );
    if (lastKey != null && lastKey == key) return;
    lastKey = key;
    refreshNotifier.ping();
  }, fireImmediately: true);

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // En güncel auth state'i her redirect çağrısında taze okuyoruz.
      final authState = ref.read(authProvider);
      final isSessionLoading = authState.isSessionLoading;
      final isAuthenticated = authState.isAuthenticated;
      final hasPersonality = authState.hasPersonality;
      final location = state.matchedLocation;

      // Oturum henüz SharedPreferences'tan yükleniyor → splash'te kal
      if (isSessionLoading) return AppRoutes.splash;

      // Auth gerektirmeyen rotalar
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.signIn,
        AppRoutes.signUp,
        AppRoutes.forgotPassword,
        AppRoutes.verification,
      ];

      // Giriş yapmamışsa public'e git
      if (!isAuthenticated && !publicRoutes.contains(location)) {
        return AppRoutes.signIn;
      }

      // Giriş yapmış ama quiz yok → quiz'e yönlendir
      if (isAuthenticated &&
          !hasPersonality &&
          location != AppRoutes.quiz &&
          !publicRoutes.contains(location)) {
        return AppRoutes.quiz;
      }

      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return VerificationPage(email: email);
        },
      ),

      // ── Kişilik Testi ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.quiz,
        builder: (context, state) => const QuizPage(),
      ),

      // ── Ana uygulama ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) => const MainPage(),
      ),

      // ── Settings sayfaları — düz mutlak yollar ───────────────────────────
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

/// GoRouter'a `refreshListenable` olarak verilen basit yardımcı sınıf.
/// Sadece `ping()` çağrıldığında dinleyicilere haber verir; herhangi bir
/// değer taşımaz, sadece "redirect'i tekrar değerlendir" sinyali üretir.
class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
