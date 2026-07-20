import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/splash_provider.dart';
import 'package:meetit/features/auth/widgets/pulsing_logo.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_character.dart';

/// Uygulama açılış ekranı.
///
/// `splashReadyProvider` en az 2 saniye bekler, ardından SharedPreferences'tan
/// oturum bilgisi yüklenince `isAuthenticated` değerini döner. `ref.listen`
/// bu değeri dinleyip navigasyon kararı verir.
///
/// Karakterler: 3 farklı kişilik tipi staggered slide-up animasyonla alttan
/// girer — splash beklenirken görsel zenginlik sağlar.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final List<Animation<double>> _charAnims;

  // Splash'ta gösterilecek 3 karakter kişilik tipi
  static const _chars = [
    PersonalityType.maceraperest,
    PersonalityType.gurme,
    PersonalityType.entelektuel,
  ];

  @override
  void initState() {
    super.initState();

    // 1200 ms'de 3 karakter birbirini izleyerek girer
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Her karakter %15 gecikmeli başlar → staggered etki
    _charAnims = List.generate(_chars.length, (i) {
      final start = i * 0.15;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(splashReadyProvider, (_, next) {
      next.whenData((isAuthenticated) {
        if (!context.mounted) return;
        context.go(
          isAuthenticated ? AppRoutes.main : AppRoutes.signIn,
        );
      });
    });

    return Scaffold(
      // Splash tema-bağımsız; logo ve karakterler bu renk üzerine tasarlandı
      backgroundColor: AppColors.light.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ── Logo ──────────────────────────────────────────────────────────
            const PulsingLogo(),

            const Spacer(flex: 2),

            // ── Karakter sırası ───────────────────────────────────────────────
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_chars.length, (i) {
                  final v = _charAnims[i].value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 70 * (1 - v)),
                    child: Opacity(
                      opacity: v,
                      child: PersonalityCharacterWidget(
                        type: _chars[i],
                        size: 92,
                        showBackground: false,
                        searchMode: false,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
