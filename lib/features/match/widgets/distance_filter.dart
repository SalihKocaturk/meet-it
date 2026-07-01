import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Mesafe Filtresi ───────────────────────────────────────────────────────────
//
// Kullanıcı talebi: önce serbest km seçimi için Slider denendi, ardından
// kullanıcı bunun "kaba durduğunu" belirtip _PriceFilter'daki gibi hazır
// kutucuk (chip) tasarımına geçilmesini istedi — bu yüzden artık aynı
// GestureDetector + AnimatedContainer chip deseni kullanılıyor. Aşan
// mekanlar TAMAMEN sonuçlardan çıkarılıyor (bkz. venue_search_notifier.dart
// içindeki hard filter, artık Haversine değil GERÇEK rota mesafesiyle).
// İki kişi modunda mesafe ORTA NOKTADAN, tek başına modda kullanıcının
// kendi konumundan ölçülür — ikisi de `searchVenues()`'a aynı parametre
// (maxVenueDistanceKm) olarak gidiyor.
class DistanceFilter extends ConsumerWidget {
  const DistanceFilter({super.key});

  // (km değeri null=tümü/sınırsız, çeviri anahtarı)
  static const _options = [
    (null, 'match.distance_all'),
    (3.0, 'match.distance_3km'),
    (5.0, 'match.distance_5km'),
    (10.0, 'match.distance_10km'),
    (30.0, 'match.distance_30km'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMaxDistanceKmProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedMaxDistanceKmProvider.notifier).state =
                      opt.$1,
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
                child: Text(
                  opt.$2.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.colors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
