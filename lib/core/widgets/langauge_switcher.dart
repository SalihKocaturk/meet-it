import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

// ── Dil bayrakları — emoji ile, asset gerektirmez ─────────────────────────────
const _trFlag = '🇹🇷';
const _enFlag = '🇬🇧';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final isTurkish = context.locale.languageCode == 'tr';

    return GestureDetector(
      onTap: () => showLanguagePickerSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isTurkish ? _trFlag : _enFlag,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 6),
          Text(
            isTurkish ? 'Türkçe' : 'English',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Auth sayfaları için tam genişlikli dil seçici kartı
class LanguageSwitcherCard extends StatelessWidget {
  const LanguageSwitcherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isTurkish = context.locale.languageCode == 'tr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => showLanguagePickerSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bayrak
              Text(
                isTurkish ? _trFlag : _enFlag,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              // Dil adı
              Text(
                isTurkish ? 'Türkçe' : 'English',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              // Dil değiştir ikonu
              Icon(
                Icons.translate_rounded,
                color: context.colors.primary,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet dil seçici — temaya tam uyumlu
void showLanguagePickerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.colors.card,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tutamaç ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Başlık ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.language_outlined,
                    color: context.colors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'settings.language_select'.tr(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Türkçe ──────────────────────────────────────────────────
            _LangTile(
              flag: _trFlag,
              label: 'Türkçe',
              sublabel: 'Turkish',
              isSelected: context.locale.languageCode == 'tr',
              onTap: () {
                context.setLocale(const Locale('tr'));
                Navigator.pop(ctx);
              },
            ),

            const SizedBox(height: 10),

            // ── English ─────────────────────────────────────────────────
            _LangTile(
              flag: _enFlag,
              label: 'English',
              sublabel: 'İngilizce',
              isSelected: context.locale.languageCode == 'en',
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      );
    },
  );
}

// ── Dil tile'ı ────────────────────────────────────────────────────────────────

class _LangTile extends StatelessWidget {
  final String flag;
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangTile({
    required this.flag,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withOpacity(0.08)
              : context.colors.scaffold,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji bayrak
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            // İsim + alt yazı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.hint,
                    ),
                  ),
                ],
              ),
            ),
            // Seçim göstergesi
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('check'),
                      color: context.colors.primary,
                      size: 22,
                    )
                  : Icon(
                      Icons.radio_button_unchecked,
                      key: const ValueKey('empty'),
                      color: context.colors.border,
                      size: 22,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
