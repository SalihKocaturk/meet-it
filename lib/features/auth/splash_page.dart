import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // 0.35 → 1.0 arası yumuşak nabız
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
    _navigate();
  }

  Future<void> _navigate() async {
    // En az 2 saniye splash göster
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // SharedPreferences'tan oturum yükleniyorsa bitene kadar bekle
    // (genellikle ~10-50ms, 2 saniye içinde çoktan tamamlanır)
    while (ref.read(authProvider).isSessionLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    if (!mounted) return;
    final auth = ref.read(authProvider);

    if (auth.isAuthenticated) {
      context.go(auth.hasPersonality ? AppRoutes.main : AppRoutes.quiz);
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _pulseAnim,
          child: Image.asset(
            'assets/images/logo.png',
            height: 120,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
