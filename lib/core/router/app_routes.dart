/// Uygulama genelindeki route sabitleri.
/// Kullanım: context.go(AppRoutes.main)
abstract class AppRoutes {
  static const splash = '/';
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const forgotPassword = '/forgot-password';
  static const verification = '/verification';
  static const completeProfile = '/complete-profile';
  static const main = '/main';

  // Kişilik testi
  static const quiz = '/quiz';

  // Settings sayfaları — düz (flat) mutlak yollar
  static const editProfile = '/edit-profile';
  static const changePassword = '/change-password';
  static const settings = '/settings';

  // Yasal
  static const terms = '/terms';
  static const privacyPolicy = '/privacy-policy';
}
