import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';

/// Yasal metin onay kutusu — linkli metin + checkbox.
///
/// App Store Guideline 1.2: kullanıcı hesap oluşturmadan ÖNCE Kullanım
/// Koşulları'nı (EULA) kabul etmeli; koşullar uygunsuz içeriğe ve taciz eden
/// kullanıcılara sıfır tolerans olduğunu açıkça söylemeli. Gizlilik
/// Politikası ayrı bir kutuyla onaylanır (KVKK açısından da ayrı onay daha
/// doğru). Hem e-posta kaydında (SignUpPage) hem Google/Apple ile ilk girişte
/// (CompleteProfilePage) kullanılır.
class LegalConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String prefixKey;
  final String linkKey;
  final String suffixKey;
  final String route;

  const LegalConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.prefixKey,
    required this.linkKey,
    required this.suffixKey,
    required this.route,
  });

  /// Kullanım Koşulları kutusu.
  const LegalConsentCheckbox.terms({
    super.key,
    required this.value,
    required this.onChanged,
  })  : prefixKey = 'auth.terms_consent_prefix',
        linkKey = 'auth.terms_consent_link',
        suffixKey = 'auth.terms_consent_suffix',
        route = AppRoutes.terms;

  /// Gizlilik Politikası kutusu.
  const LegalConsentCheckbox.privacy({
    super.key,
    required this.value,
    required this.onChanged,
  })  : prefixKey = 'auth.privacy_consent_prefix',
        linkKey = 'auth.privacy_consent_link',
        suffixKey = 'auth.privacy_consent_suffix',
        route = AppRoutes.privacyPolicy;

  @override
  Widget build(BuildContext context) {
    final prefix = prefixKey.tr();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          activeColor: context.colors.primary,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                  children: [
                    if (prefix.isNotEmpty) TextSpan(text: prefix),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => context.push(route),
                        child: Text(
                          linkKey.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: context.colors.primary,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: suffixKey.tr()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
