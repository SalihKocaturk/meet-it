import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_radar_chart.dart';

/// Bir [PersonalityProfile]'ın görsel dökümü: dominant tip, varsa ikincil
/// tip rozeti, açıklama kartı ve skor çubukları.
///
/// Hem quiz sonuç sayfasında (quiz_page.dart — yeni tamamlanan profil için)
/// hem de "Kişilik Analizim" sayfasında (kayıtlı/evrilmiş profil için)
/// kullanılır — kod tekrarını önlemek için tek bir yerde tutuluyor.
class PersonalityBreakdown extends StatelessWidget {
  final PersonalityProfile profile;

  const PersonalityBreakdown({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final dominant = profile.dominantType;
    final secondary = profile.secondaryType;
    final ranked = profile.rankedTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Dominant tip
        Text(dominant.emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(
          dominant.displayName,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),

        if (secondary != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'quiz.secondary_type'.tr(namedArgs: {
                'emoji': secondary.emoji,
                'name': secondary.displayName,
              }),
              style: TextStyle(
                fontSize: 13,
                color: context.colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Açıklama
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            dominant.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textPrimary,
              height: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Radar (Spider) Chart ─────────────────────────────────────────
        //
        // Skor çubukları zaten her tipin yüzdesini ayrı ayrı gösteriyor,
        // ama "profilin genel şekli" tek bakışta görülmüyordu. Radar chart
        // 5 ekseni (5 kişilik tipi) aynı anda gösterip bir beşgen çizerek
        // bunu sağlıyor — özellikle mekan ziyaretleriyle profil zamanla
        // değiştiğinde, şeklin nasıl evrildiğini görmek daha sezgisel.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'quiz.personality_shape'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PersonalityRadarChart(profile: profile, size: 230),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Skor Barları ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'quiz.personality_distribution'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...ranked.map(
                (entry) => PersonalityScoreBar(
                  type: entry.key,
                  score: entry.value,
                  isDominant: entry.key == dominant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Skor Çubuğu ───────────────────────────────────────────────────────────────

class PersonalityScoreBar extends StatelessWidget {
  final PersonalityType type;
  final double score; // 0.0 – 1.0
  final bool isDominant;

  const PersonalityScoreBar({
    super.key,
    required this.type,
    required this.score,
    required this.isDominant,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Emoji + isim
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    type.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isDominant
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isDominant
                          ? context.colors.primary
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Çubuk
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 8,
                backgroundColor: context.colors.primary.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDominant
                      ? context.colors.primary
                      : context.colors.primary.withOpacity(0.40),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Yüzde
          SizedBox(
            width: 32,
            child: Text(
              '%$percent',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDominant ? FontWeight.w700 : FontWeight.w400,
                color: isDominant
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
