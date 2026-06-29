import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/quiz_page.dart';

// ── "Seni Tanıyalım" Ara Ekranı ──────────────────────────────────────────────
//
// Kişilik testi artık kayıt/giriş anında ZORUNLU olarak gösterilmiyor
// (kullanıcı şikayeti: uygulamayı hiç görmeden uzun bir teste zorlanıyordu).
// Bunun yerine kullanıcı ilk kez bir buluşma/mekan araması denediğinde
// (bkz. `important_action_guard.dart` -> `ensurePersonalityReady`) önce bu
// kısa tanıtım ekranı gösterilir, ardından "Teste Başla"ya basılınca asıl
// test (`QuizPage`) PUSH edilir. Kullanıcı testi tamamlarsa bu ekran da
// `true` ile kapanır; geri tuşuyla/"Daha Sonra" ile çıkarsa `false` ile
// kapanır (çağıran taraf işlemi — örn. mekan aramayı — gerçekleştirmez).
class QuizIntroPage extends StatelessWidget {
  const QuizIntroPage({super.key});

  Future<void> _onStart(BuildContext context) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QuizPage()),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop(completed ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 48,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'quiz_intro.title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'quiz_intro.desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onStart(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'quiz_intro.start_btn'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'quiz_intro.later_btn'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
