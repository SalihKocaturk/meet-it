import 'package:flutter/material.dart';
import 'package:meetit/theme/custom_input_decoration.dart';

import 'visibilty_button_builder.dart';

class CustomTextfield extends StatelessWidget {
  final String label;
  final String? hint;
  final bool isPassword;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const CustomTextfield({
    super.key,
    required this.label,
    this.hint,
    this.isPassword = false,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 🔹 PASSWORD DEĞİL
    if (!isPassword) {
      return TextField(
        onChanged: onChanged,
        decoration: buildCustomInputDecoration(
          context,
          label: label,
          hint: hint,
          suffixIcon: suffixIcon, // 👈 dışarıdan gelebilir
        ),
      );
    }

    // 🔹 PASSWORD
    return VisibilityButtonBuilder(
      builder: (context, obscure, iconButton) {
        return TextField(
          obscureText: obscure,
          onChanged: onChanged,
          decoration: buildCustomInputDecoration(
            context,
            label: label,
            hint: hint,
            suffixIcon: iconButton, // 🔒 her zaman visibility
          ),
        );
      },
    );
  }
}
