import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Aktivite Grid (Çoklu Seçim) ───────────────────────────────────────────────

class ActivityGrid extends ConsumerWidget {
  const ActivityGrid({super.key});

  // (key used in provider, translation key, icon)
  static const _activities = [
    ('Kafe', 'match.activity_cafe', Iconsax.coffee),
    ('Restoran', 'match.activity_restaurant', Iconsax.cake),
    ('Park', 'match.activity_park', Iconsax.sun_1),
    ('Sinema', 'match.activity_cinema', Iconsax.video_play),
    ('Alışveriş', 'match.activity_shopping', Iconsax.bag),
    ('Spor', 'match.activity_sports', Iconsax.activity),
    ('Kültür/Müze', 'match.activity_culture', Iconsax.building_3),
    ('Bar', 'match.activity_bar', Iconsax.cup),
    ('Eğlence', 'match.activity_entertainment', Iconsax.music),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActivitiesProvider);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _activities.map((a) {
        final isSelected = selected.contains(a.$1);
        return GestureDetector(
          onTap: () {
            final current = Set<String>.from(selected);
            if (isSelected) {
              current.remove(a.$1);
            } else {
              current.add(a.$1);
            }
            ref.read(selectedActivitiesProvider.notifier).state = current;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? context.colors.primary : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  a.$3,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : context.colors.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  a.$2.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
