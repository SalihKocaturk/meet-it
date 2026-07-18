import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/helpers/auth_helpers.dart';

/// Cinsiyet seçimi için paylaşılan dropdown widget'ı.
///
/// Hem `SignUpPage` hem `CompleteProfilePage` tarafından kullanılır.
/// Değer ve callback dışarıdan verilir — kendi içinde provider tutmaz.
class GenderDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const GenderDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'auth.gender'.tr(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.colors.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.colors.border,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.colors.border,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.colors.primary,
                width: 1.6,
              ),
            ),
          ),
          hint: Text(
            'auth.gender_hint'.tr(),
            style: TextStyle(
              color: context.colors.hint,
              fontSize: 14,
            ),
          ),
          items: kGenderCodes
              .map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: Text(
                    genderLabel(code),
                    style: TextStyle(color: context.colors.textPrimary),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
