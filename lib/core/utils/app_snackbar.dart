import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan awesome_snackbar_content yardımcı sınıfı.
/// Her metodun kullanımı:
/// ```dart
/// AppSnackbar.success(context, title: 'Başarılı', message: 'İşlem tamamlandı.');
/// ```
class AppSnackbar {
  AppSnackbar._();

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
  }) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: contentType,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// ✅ Başarı snackbar'ı
  static void success(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      _show(context,
          title: title, message: message, contentType: ContentType.success);

  /// 🔴 Hata snackbar'ı
  static void error(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      _show(context,
          title: title, message: message, contentType: ContentType.failure);

  /// ⚠ Uyarı snackbar'ı
  static void warning(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      _show(context,
          title: title, message: message, contentType: ContentType.warning);

  /// ❔ Bilgi snackbar'ı
  static void info(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      _show(context,
          title: title, message: message, contentType: ContentType.help);
}
