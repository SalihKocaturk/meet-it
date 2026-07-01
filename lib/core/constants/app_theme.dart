import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final isDark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme(
        brightness: b,
        primary: c.primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: c.primary,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: c.error,
        onError: Colors.white,
        surface: c.card,
        onSurface: c.textPrimary,
        surfaceContainerHighest: c.scaffold,
        onSurfaceVariant: c.textSecondary,
        outline: c.border,
        outlineVariant: c.border,
      ),
      scaffoldBackgroundColor: c.scaffold,
      cardColor: c.card,
      dividerColor: c.border,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.hint, fontSize: 14),
        labelStyle: TextStyle(color: c.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.primary,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
    );
  }
}
