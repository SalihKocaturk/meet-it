import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color scaffold;
  final Color textPrimary;
  final Color textSecondary;
  final Color hint;
  final Color border;
  final Color success;
  final Color error;
  final Color card;

  const AppColors({
    required this.primary,
    required this.scaffold,
    required this.textPrimary,
    required this.textSecondary,
    required this.hint,
    required this.border,
    required this.success,
    required this.error,
    required this.card,
  });

  static const light = AppColors(
    primary: Color(0xFF5CB58A),
    scaffold: Color(0xFFFCF4F1),
    textPrimary: Color(0xFF24323C),
    textSecondary: Color(0xFF4A5568),
    hint: Color(0xFF98A2B3),
    border: Color(0xFFE2E8F0),
    success: Color(0xFF12B76A),
    error: Color(0xFFD92D20),
    card: Colors.white,
  );

  static const dark = AppColors(
    primary: Color.fromARGB(255, 61, 116, 90),
    scaffold: Color(0xFF0D1117),
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF8B949E),
    hint: Color(0xFF484F58),
    border: Color(0xFF30363D),
    success: Color(0xFF3FB950),
    error: Color(0xFFF85149),
    card: Color(0xFF161B22),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? scaffold,
    Color? textPrimary,
    Color? textSecondary,
    Color? hint,
    Color? border,
    Color? success,
    Color? error,
    Color? card,
  }) => AppColors(
    primary: primary ?? this.primary,
    scaffold: scaffold ?? this.scaffold,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    hint: hint ?? this.hint,
    border: border ?? this.border,
    success: success ?? this.success,
    error: error ?? this.error,
    card: card ?? this.card,
  );

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
