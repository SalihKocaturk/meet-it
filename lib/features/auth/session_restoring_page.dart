import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/widgets/pulsing_logo.dart';

/// Samsung gibi agresif süreç yönetimi olan cihazlarda force-kill sonrası
/// Firebase Auth token'ını yükleyemeyebilir. Bu sürede kullanıcıyı login
/// ekranında bırakmak yerine 3 saniyelik bir "oturum yükleniyor" ekranı gösterilir.
///
/// AuthNotifier'daki `authStateChanges()` Firebase'i dinler:
///   • Firebase 3s içinde yüklenirse  → auto-restore → /main
///   • 3 saniye geçerse              → /signin (arka planda dinleme devam eder)
///   • Firebase /signin'deyken gelirse → SignInPage.ref.listen → auto-restore → /main
class SessionRestoringPage extends StatelessWidget {
  const SessionRestoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light.primary,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Merkeze hizala
          const Spacer(),

          // Nabız atan logo
          const Center(child: PulsingLogo()),

          const SizedBox(height: 48),

          // Üç nokta animasyonu
          const _BouncingDots(),

          const SizedBox(height: 20),

          // Açıklama metni
          Text(
            'Oturum geri yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

/// Sırayla zıplayan üç beyaz nokta.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // Her nokta 333ms arayla geciktiriliyor
        final delay = i * 0.33;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            // 0..1 aralığını gecikme ile döngüye sok
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            // Yukarı-aşağı (sin eğrisi)
            final offset = -6.0 * (t < 0.5 ? (t * 2) : (2 - t * 2));
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
