import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Fiyat Filtresi ────────────────────────────────────────────────────────────

class PriceFilter extends ConsumerWidget {
  const PriceFilter({super.key});

  // (price level int?, translation key, ₺ symbol)
  static const _options = [
    (null, 'match.price_all', ''),
    (1, 'match.price_cheap', '₺'),
    (2, 'match.price_mid', '₺₺'),
    (3, 'match.price_expensive', '₺₺₺'),
    (4, 'match.price_luxury', '₺₺₺₺'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPriceLevelProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedPriceLevelProvider.notifier).state = opt.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.card,
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
                    if (opt.$3.isNotEmpty) ...[
                      Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4CAF50),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                    Text(
                      opt.$2.tr(),
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
            ),
          );
        }).toList(),
      ),
    );
  }
}
