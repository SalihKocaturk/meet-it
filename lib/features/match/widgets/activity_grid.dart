import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Aktivite Grid (Çoklu Seçim) ───────────────────────────────────────────────

class ActivityGrid extends ConsumerWidget {
  const ActivityGrid({super.key});

  // (key used in provider, translation key, icon)
  static const _activities = [
    ('Kafe', 'match.activity_cafe', Icons.local_cafe_outlined),
    ('Restoran', 'match.activity_restaurant', Icons.restaurant_outlined),
    ('Park', 'match.activity_park', Icons.park_outlined),
    ('Sinema', 'match.activity_cinema', Icons.movie_outlined),
    ('Alışveriş', 'match.activity_shopping', Icons.shopping_bag_outlined),
    ('Spor', 'match.activity_sports', Icons.fitness_center_outlined),
    ('Kültür/Müze', 'match.activity_culture', Icons.museum_outlined),
    ('Bar', 'match.activity_bar', Icons.local_bar_outlined),
    ('Eğlence', 'match.activity_entertainment', Icons.celebration_outlined),
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
