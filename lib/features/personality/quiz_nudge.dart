import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/router/app_router.dart';
import 'package:meetit/core/services/analytics_service.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/personality/quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Kişilik testi önerisi ────────────────────────────────────────────────────
//
// Test tamamen isteğe bağlı: hiçbir akış testi beklemez. Test çözülmemişse
// ara sıra (mekan sonuçları gösterildikten sonra, en fazla [_kInterval]'de
// bir) neden çözmesi gerektiğini anlatan kısa bir alt sayfa çıkar.

const _kLastShownKey = 'quiz_nudge_last_shown';
const _kInterval = Duration(days: 5);

/// Koşullar uygunsa test önerisini gösterir. [container], çağıran widget
/// kapanmış olsa bile güvenle okunabilsin diye dışarıdan verilir.
Future<void> maybeShowQuizNudge(
  ProviderContainer container, {
  Duration delay = const Duration(milliseconds: 1200),
}) async {
  final auth = container.read(authProvider);
  if (!auth.isAuthenticated || auth.hasPersonality) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastShownKey);
    final now = DateTime.now();
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
            _kInterval) {
      return;
    }
    await Future<void>.delayed(delay);
    // Bekleme sırasında test çözülmüş olabilir.
    if (container.read(authProvider).hasPersonality) return;

    final nav = container
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState;
    final ctx = nav?.context;
    if (nav == null || ctx == null || !ctx.mounted) return;

    await prefs.setInt(_kLastShownKey, now.millisecondsSinceEpoch);
    AnalyticsService.quizNudge('shown').ignore();

    final start = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: ctx.colors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _QuizNudgeSheet(),
    );

    if (start == true) {
      AnalyticsService.quizNudge('accepted').ignore();
      // fromGuard: true → test bitince sonuç ekranı Navigator.pop ile kapanır.
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const QuizPage(fromGuard: true)),
      );
    } else {
      AnalyticsService.quizNudge('dismissed').ignore();
    }
  } catch (e) {
    debugPrint('[QuizNudge] $e');
  }
}

class _QuizNudgeSheet extends StatelessWidget {
  const _QuizNudgeSheet();

  @override
  Widget build(BuildContext context) {
    Widget reason(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Emerald.base.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: context.accentStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'quiz_nudge.title'.tr(),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'quiz_nudge.desc'.tr(),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            reason(Icons.auto_awesome_rounded, 'quiz_nudge.reason_venues'.tr()),
            reason(Icons.favorite_rounded, 'quiz_nudge.reason_compat'.tr()),
            reason(Icons.timer_outlined, 'quiz_nudge.reason_time'.tr()),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Emerald.base,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'quiz_nudge.start'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'quiz_nudge.later'.tr(),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
