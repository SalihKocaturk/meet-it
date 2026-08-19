import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/features/auth/complete_profile_page.dart';
import 'package:meetit/features/auth/forgot_password_page.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/session_restoring_page.dart';
import 'package:meetit/features/auth/sign_in_page.dart';
import 'package:meetit/features/auth/sign_up_page.dart';
import 'package:meetit/features/auth/splash_page.dart';
import 'package:meetit/features/auth/verification_page.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/personality/quiz_page.dart';
import 'package:meetit/features/settings/change_password_page.dart';
import 'package:meetit/features/settings/edit_profile_page.dart';
import 'package:meetit/features/settings/delete_account_page.dart';
import 'package:meetit/features/settings/privacy_policy_page.dart';
import 'package:meetit/features/settings/settings_page.dart';
import 'package:meetit/features/settings/terms_page.dart';

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
/// hasPersonality, needsEmailVerification, needsProfileCompletion)
/// değiştiğinde haberdar ol. Diğer profil güncellemeleri router'ı hiç
/// etkilemesin.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();

  // authProvider'ı sadece DİNLE (watch değil) — routing'i etkileyen alanlar
  // değişmediği sürece refreshNotifier'ı tetiklemiyoruz.
  (bool, bool, bool, bool, bool, bool)? lastKey;
  ref.listen(authProvider, (previous, next) {
    final key = (
      next.isSessionLoading,
      next.isAwaitingFirebaseRestore,
      next.isAuthenticated,
      next.hasPersonality,
      next.needsEmailVerification,
      next.needsProfileCompletion,
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
      final isAwaitingFirebaseRestore = authState.isAwaitingFirebaseRestore;
      final isAuthenticated = authState.isAuthenticated;
      // NOT: hasPersonality artık burada kullanılmıyor — quiz zorunlu
      // yönlendirmesi kaldırıldı (bkz. yukarıdaki not).
      final needsEmailVerification = authState.needsEmailVerification;
      final needsProfileCompletion = authState.needsProfileCompletion;
      final location = state.matchedLocation;

      // Oturum henüz SharedPreferences'tan yükleniyor → splash'te kal
      if (isSessionLoading) return AppRoutes.splash;

      // Local session var ama Firebase Auth henüz yüklenmedi (Samsung force-kill)
      // → restore ekranında bekle, Firebase gelince auto-restore olacak
      if (isAwaitingFirebaseRestore) return AppRoutes.restoring;

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

      // Email/şifre ile kayıt olan ama henüz mailini doğrulamamış kullanıcı →
      // verification bekleme sayfasında tut. Router redirect burada güvenlik
      // ağı görevi görür: sign_up_page ve sign_in_page kendi context.go()'sunu
      // zaten yapıyor, ama uygulama herhangi bir yerden bu state'e düşerse
      // (session restore, deep link vb.) burada da yakalanır.
      // NOT: Google ile giriş yapanlar bu daldan GEÇMEZ — signInWithGoogle()
      // hiçbir zaman needsEmailVerification = true set etmiyor (Google hesapları
      // Google tarafından zaten doğrulanmış sayılır).
      if (isAuthenticated &&
          needsEmailVerification &&
          location != AppRoutes.verification) {
        return AppRoutes.verification;
      }

      // Google ile ilk kez giriş yapan ve konum/yaş/cinsiyet alanları eksik
      // kalan kullanıcı → profil tamamlama sayfasına git. Bu kontrol
      // KASITLI OLARAK quiz kontrolünden ÖNCE gelir — kullanıcı önce
      // temel bilgilerini girmeli, sonra kişilik testine geçmeli. Email
      // doğrulamasından farklı olarak burada bekleme YOK; Google
      // hesapları zaten doğrulanmış sayılıyor.
      if (isAuthenticated &&
          !needsEmailVerification &&
          needsProfileCompletion &&
          location != AppRoutes.completeProfile) {
        return AppRoutes.completeProfile;
      }

      // Oturum açık ama geçici bir sayfadaysa (restoring, signin, splash)
      // → ana sayfaya yönlendir.
      // Bu özellikle Samsung force-kill sonrası auto-restore için kritik:
      // _tryAutoRestoreFromLocal() isAuthenticated'ı true yapar ama
      // GoRouter'ın yalnızca "unauthenticated → login" yönlendirmesi varken
      // "authenticated → main" yönlendirmesi yoktu. ref.listen veya Google
      // re-auth olmadan navigasyon tetiklenmiyordu.
      const _transitionalRoutes = [
        AppRoutes.restoring,
        AppRoutes.signIn,
        AppRoutes.splash,
      ];
      if (isAuthenticated &&
          !needsEmailVerification &&
          !needsProfileCompletion &&
          _transitionalRoutes.contains(location)) {
        return AppRoutes.main;
      }

      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Session Restore (Samsung force-kill) ─────────────────────────────
      GoRoute(
        path: AppRoutes.restoring,
        builder: (context, state) => const SessionRestoringPage(),
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
          // sign_up/sign_in sayfalarından gelen extra'da email var.
          // Router redirect ile gelince extra boş kalır — auth state'ten al.
          final extraEmail = state.extra as String? ?? '';
          final email = extraEmail.isNotEmpty
              ? extraEmail
              : ref.read(authProvider).user?.email ?? '';
          return VerificationPage(email: email);
        },
      ),

      // ── Google sign-in profil tamamlama ─────────────────────────────────
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) => const CompleteProfilePage(),
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
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyPage(),
      ),

      // Hesap silme — deep link meetit://delete-account → /delete-account
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountPage(),
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
