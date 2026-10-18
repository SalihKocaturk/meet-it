import 'package:flutter/material.dart';

/// Uygulamanın canlı zümrüt yeşili vurgu paleti (ana sayfa ile aynı dil).
///
/// Koyu temada açık tonlar (#34D399 / #6EE7B7), açık temada okunabilirlik
/// için aynı ailenin koyu tonları (#059669 / #047857) kullanılır.
abstract final class Emerald {
  static const deep = Color(0xFF059669);
  static const base = Color(0xFF10B981);
  static const light = Color(0xFF34D399);
  static const pale = Color(0xFF6EE7B7);
  static const ink = Color(0xFF047857);

  /// Ana sayfadaki "Buluş" butonu gibi tonlu (tinted) buton dekorasyonu.
  static BoxDecoration tint({double radius = 8}) => BoxDecoration(
        color: base.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: base.withOpacity(0.45)),
      );
}

extension EmeraldTheme on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  /// Link, ikon ve sekme vurgusu: koyu temada #34D399, açıkta #059669.
  Color get accentStrong => isDarkTheme ? Emerald.light : Emerald.deep;

  /// Tonlu buton üzerindeki metin/ikon: koyu temada #6EE7B7, açıkta #047857.
  Color get accentOnTint => isDarkTheme ? Emerald.pale : Emerald.ink;
}
