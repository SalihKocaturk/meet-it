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
final appRouterProvider = Provider<GoRouter>((ref) {
  // Auth state değişimlerini dinle → router'ı yenile
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
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
