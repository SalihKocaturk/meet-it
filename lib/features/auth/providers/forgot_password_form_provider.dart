import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Forgot Password email controller
final forgotPasswordEmailControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

// Email gönderildi mi durumu
final forgotPasswordEmailSentProvider =
    StateProvider.autoDispose<bool>((ref) => false);
