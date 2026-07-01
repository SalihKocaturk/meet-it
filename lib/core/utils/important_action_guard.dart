import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/verification_page.dart';
import 'package:meetit/features/personality/quiz_intro_page.dart';

// ── Önemli İşlem Kapıları (Email Doğrulama / Kişilik Testi) ─────────────────
//
// Önceden email doğrulama VE kişilik testi, kayıt/giriş akışının HEMEN
// sonrasında router seviyesinde ZORUNLU olarak gösteriliyordu — kullanıcı
// uygulamadan hiçbir şey görmeden bu iki uzun adımı tamamlamak zorunda
// kalıyordu (kullanıcı şikayeti). Artık `app_router.dart`'taki bu zorunlu
// yönlendirmeler kaldırıldı; kullanıcı kayıt/giriş sonrası DOĞRUDAN
// uygulamayı (ana sayfayı) görür ve gezinebilir.
//
// Bu iki adım artık sadece "önemli" bir işlem denendiğinde (arkadaş ekleme,
// buluşma/mekan arama) devreye girer — bu dosyadaki yardımcı fonksiyonlar
// ilgili butonların `onPressed`'inde çağrılır. Kullanıcı doğrulama/testi
// iptal ederse (geri tuşuyla çıkarsa) işlem gerçekleştirilmez, `false` döner.

/// Email doğrulanmamışsa doğrulama sayfasını (geri tuşu ile, PUSH olarak)
/// açar ve kullanıcı doğrulayıp "Devam Et"e basana kadar bekler.
///
/// Dönüş: doğrulama gerekmiyorsa veya doğrulama tamamlandıysa `true`;
/// kullanıcı geri tuşuyla sayfadan çıkıp işlemi iptal ettiyse `false`.
Future<bool> ensureEmailVerified(BuildContext context, WidgetRef ref) async {
  final needsVerification = ref.read(authProvider).needsEmailVerification;
  if (!needsVerification) return true;

  final email = ref.read(authProvider).user?.email ?? '';
  final verified = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => VerificationPage(email: email)),
  );

  if (!context.mounted) return false;
  // Sayfa `pop(true)` ile değil de başka bir sebeple kapandıysa (örn. geri
  // tuşu `pop(false)`/`pop()` ile), en güncel auth state'ine bakarak karar
  // veriyoruz — çift güvenlik.
  return verified ?? !ref.read(authProvider).needsEmailVerification;
}

/// Kullanıcının henüz bir kişilik profili yoksa, önce kısa bir tanıtım
/// ekranı ("Seni Tanıyalım") sonra kişilik testini (PUSH olarak) açar.
///
/// Dönüş: profil zaten varsa veya test tamamlandıysa `true`; kullanıcı
/// testten/ekrandan geri çıkıp işlemi iptal ettiyse `false`.
Future<bool> ensurePersonalityReady(BuildContext context, WidgetRef ref) async {
  final hasPersonality = ref.read(authProvider).hasPersonality;
  if (hasPersonality) return true;

  final completed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const QuizIntroPage()),
  );

  if (!context.mounted) return false;
  return completed ?? ref.read(authProvider).hasPersonality;
}
