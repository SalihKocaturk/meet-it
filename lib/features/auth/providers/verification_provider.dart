import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class VerificationState {
  final bool isChecking;
  final bool isResending;
  final int cooldownRemaining;

  const VerificationState({
    this.isChecking = false,
    this.isResending = false,
    this.cooldownRemaining = 0,
  });

  VerificationState copyWith({
    bool? isChecking,
    bool? isResending,
    int? cooldownRemaining,
  }) {
    return VerificationState(
      isChecking: isChecking ?? this.isChecking,
      isResending: isResending ?? this.isResending,
      cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VerificationNotifier extends AutoDisposeNotifier<VerificationState> {
  static const _cooldownSeconds = 30;

  Timer? _timer;

  @override
  VerificationState build() {
    ref.onDispose(() => _timer?.cancel());
    return const VerificationState();
  }

  /// Firebase'den taze email doğrulama durumunu çeker.
  /// Dönen bool: true → doğrulandı, false → henüz doğrulanmadı.
  Future<bool> checkVerified() async {
    state = state.copyWith(isChecking: true);
    final result =
        await ref.read(authProvider.notifier).checkEmailVerified();
    state = state.copyWith(isChecking: false);
    return result;
  }

  /// Doğrulama mailini yeniden gönderir.
  /// Dönen bool: true → başarıyla gönderildi.
  Future<bool> resendEmail() async {
    state = state.copyWith(isResending: true);
    final result =
        await ref.read(authProvider.notifier).resendVerificationEmail();
    state = state.copyWith(isResending: false);
    if (result) _startCooldown();
    return result;
  }

  /// Hesap değiştir — oturumu kapatır (navigasyon çağıran sayfada yapılır).
  void signOut() => ref.read(authProvider.notifier).signOut();

  void _startCooldown() {
    state = state.copyWith(cooldownRemaining: _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = state.cooldownRemaining - 1;
      if (next <= 0) {
        t.cancel();
        state = state.copyWith(cooldownRemaining: 0);
      } else {
        state = state.copyWith(cooldownRemaining: next);
      }
    });
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final verificationProvider =
    NotifierProvider.autoDispose<VerificationNotifier, VerificationState>(
  VerificationNotifier.new,
);
