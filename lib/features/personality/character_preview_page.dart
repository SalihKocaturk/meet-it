import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_character.dart';

/// Tüm kişilik tipi karakterlerini animasyonlu olarak gösteren sayfa.
/// Kullanıcılar diğer tiplerin nasıl göründüğünü buradan keşfedebilir.
class CharacterPreviewPage extends StatefulWidget {
  const CharacterPreviewPage({super.key});

  @override
  State<CharacterPreviewPage> createState() => _CharacterPreviewPageState();
}

class _CharacterPreviewPageState extends State<CharacterPreviewPage> {
  PersonalityType _type = PersonalityType.sosyalKelebek;
  String _gender = 'erkek';

  static const _types = PersonalityType.values;

  static const _labels = {
    PersonalityType.sosyalKelebek: 'Sosyal Kelebek',
    PersonalityType.sakinRuh:      'Sakin Ruh',
    PersonalityType.maceraperest:  'Maceraperest',
    PersonalityType.entelektuel:   'Entelektüel',
    PersonalityType.gurme:         'Gurme',
  };

  static const _descriptions = {
    PersonalityType.sosyalKelebek: 'Enerjik, sosyal ve eğlence odaklı.',
    PersonalityType.sakinRuh:      'Huzurlu, içe dönük ve doğa sevgini.',
    PersonalityType.maceraperest:  'Macera arayan, cesaretli ve aktif.',
    PersonalityType.entelektuel:   'Meraklı, analitik ve kültür odaklı.',
    PersonalityType.gurme:         'Lezzet arayışında, rafine ve sofistike.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Kişilik Tipleri',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Cinsiyet toggle ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GenderChip(
                  label: 'Erkek',
                  selected: _gender == 'erkek',
                  onTap: () => setState(() => _gender = 'erkek'),
                  color: context.colors.primary,
                ),
                const SizedBox(width: 10),
                _GenderChip(
                  label: 'Kadın',
                  selected: _gender == 'kadın',
                  onTap: () => setState(() => _gender = 'kadın'),
                  color: context.colors.primary,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Animasyonlu karakter ──────────────────────────────────────
            Expanded(
              child: Center(
                child: PersonalityCharacterWidget(
                  key: ValueKey('$_type-$_gender'),
                  type: _type,
                  gender: _gender,
                  size: 240,
                ),
              ),
            ),

            // ── Tip adı + açıklama ────────────────────────────────────────
            Text(
              _labels[_type] ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _descriptions[_type] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // ── Tip seçici ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _types.map((t) {
                  final selected = t == _type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.colors.primary
                            : context.colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? context.colors.primary
                              : context.colors.border,
                        ),
                      ),
                      child: Text(
                        _labels[t] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : context.colors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      ch