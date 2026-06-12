import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

InputDecoration buildCustomInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  Widget? suffixIcon,
  bool isSearch = false,
}) {
  final colors = context.colors;
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(fontSize: 16, color: colors.textSecondary),
    hintText: hint,
    hintStyle: TextStyle(color: colors.hint),

    filled: true,
    fillColor: Colors.transparent,

    prefixIcon: isSearch
        ? Icon(Icons.search, color: colors.textSecondary)
        : null,

    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colors.border,
        width: 1.2,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colors.primary,
        width: 1.6,
      ),
    ),

    suffixIcon: suffixIcon,
  );
}
