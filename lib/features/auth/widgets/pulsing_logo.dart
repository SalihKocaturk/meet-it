import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash screen için nabız atan logo animasyonu.
///
/// `StatefulWidget` + `AnimationController` yerine `TweenAnimationBuilder`
/// kullanır; yön bilgisi (ileri/geri) `_pulseForwardProvider`'da tutulur.
///
/// `onEnd` tetiklendiğinde provider state'i ters döner → widget yeni bir
/// `ValueKey` ile yeniden oluşturulur → animasyon ters yönde sıfırdan
/// başlar → kesintisiz nabız efekti elde edilir.
///
/// `autoDispose`: splash sayfası kapanınca provider da serbest bırakılır,
/// animasyon durur.
final _pulseForwardProvider =
    StateProvider.autoDispose<bool>((ref) => true);

class PulsingLogo extends ConsumerWidget {
  const PulsingLogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forward = ref.watch(_pulseForwardProvider);

    return TweenAnimationBuilder<double>(
      key: ValueKey(forward),
      tween: Tween(
        begin: forward ? 0.35 : 1.0,
        end: forward ? 1.0 : 0.35,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {
        ref.read(_pulseForwardProvider.notifier).state = !forward;
      },
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Image.asset('assets/images/logo_icon.png', height: 96),
    );
  }
}
