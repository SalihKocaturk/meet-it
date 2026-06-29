import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/utils/travel_time_estimator.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/match/widgets/travel_chip.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';

// ── Alt Bilgi Çubuğu (Harita Görünümü) ────────────────────────────────────────
//
// `AttemptMeetPage`'in (harita görünümü) altında seçili mekanın kartını
// gösteren çubuk — sayfa view dosyasının kendisi yerine ayrı bir widget
// dosyasına taşındı (bkz. attempt_meet_page.dart).
class VenueBottomBar extends ConsumerWidget {
  final PlaceResult place;
  final int index;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onOpenMaps;

  const VenueBottomBar({
    super.key,
    required this.place,
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(
      savedVenuesProvider.select(
        (list) => list.any((p) => p.placeId == place.placeId),
      ),
    );

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gezinme + sayaç
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                color: onPrev == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  'match.map_venue_of'.tr(
                    namedArgs: {
                      'current': '${index + 1}',
                      'total': '$total',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                color: onNext == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // Fotoğraf + isim/etiket bölümüne dokununca mekanın detay
          // sayfasına gidilir (yorumlar, foto galerisi, beğeniler vb.) —
          // alttaki ok/Kaydet/Git butonları kendi onTap'lerine sahip
          // olduğu için bu genel tıklama onlarla çakışmaz.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VenueDetailPage.fromPlace(place),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: place.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: place.photoUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 72,
                            height: 72,
                            color: context.colors.primary.withOpacity(0.06),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: context.colors.hint,
                            ),
                          ),
                        )
                      : Container(
                          width: 72,
                          height: 72,
                          color: context.colors.primary.withOpacity(0.06),
                          child: Icon(
                            Icons.place_outlined,
                            color: context.colors.hint,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (place.vicinity != null)
                        Text(
                          place.vicinity!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              place.primaryTypeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (place.rating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFFFB800),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  place.ratingText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          if (place.priceLabelText != null)
                            Text(
                              place.priceLabelText!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Ulaşım süresi — liste görünümündeki ile AYNI kaynak ──────────
          // Hazır veri `venueSearchProvider.travelEstimates`'ten okunuyor
          // (arama sonrası arka planda Google Distance Matrix API'den
          // dolduruluyor, bkz. `venue_search_notifier.dart`). Veri henüz
          // gelmediyse veya bu mekan için yoksa satır hiç gösterilmiyor.
          // Gerçek API verisinde "~" öneki yok, kuş uçuşu fallback'inde var
          // (`TravelEstimate.isApproximate`).
          Builder(
            builder: (_) {
              final estimate = ref.watch(
                venueSearchProvider.select(
                  (s) => s.travelEstimates[place.placeId],
                ),
              );
              if (estimate == null) return const SizedBox.shrink();
              final prefix = estimate.isApproximate ? '~' : '';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (estimate.carMinutes != null)
                      TravelChip(
                        icon: Icons.directions_car_filled_outlined,
                        label:
                            '$prefix${formatTravelMinutes(estimate.carMinutes!)}',
                      ),
                    if (estimate.transitMinutes != null)
                      TravelChip(
                        icon: Icons.directions_bus_filled_outlined,
                        label:
                            '$prefix${formatTravelMinutes(estimate.transitMinutes!)}',
                      ),
                    if (estimate.walkMinutes != null)
                      TravelChip(
                        icon: Icons.directions_walk_outlined,
                        label:
                            '$prefix${formatTravelMinutes(estimate.walkMinutes!)}',
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(savedVenuesProvider.notifier).toggle(place),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? context.colors.primary.withOpacity(0.12)
                          : context.colors.scaffold,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSaved
                            ? context.colors.primary
                            : context.colors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                          color: isSaved
                              ? context.colors.primary
                              : context.colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSaved ? 'match.saved'.tr() : 'match.save'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSaved
                                ? context.colors.primary
                                : context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenMaps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'match.navigate'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
