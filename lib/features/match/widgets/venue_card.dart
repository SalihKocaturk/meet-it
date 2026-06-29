import 'dart:async';

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
import 'package:url_launcher/url_launcher.dart';

// ── Mekan Kartı (Places API) ──────────────────────────────────────────────────

class VenueCard extends ConsumerWidget {
  final PlaceResult place;
  final int rank;
  // ignore: avoid_field_initializers_in_const_classes
  final BuildContext context;
  const VenueCard({
    super.key,
    required this.place,
    required this.rank,
    required this.context,
  });

  Color _rankColor(BuildContext ctx) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return ctx.colors.border;
  }

  Future<void> _openInMaps(WidgetRef ref) async {
    // 📍 GECİKME DÜZELTMESİ (2026-06-28): bkz. attempt_meet_page.dart'taki
    // aynı düzeltme — bu kayıt artık AWAIT EDİLMİYOR, harita anında açılır.
    unawaited(ref.read(navigatedVenuesProvider.notifier).add(place));
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3
              ? _rankColor(context).withOpacity(0.5)
              : context.colors.border,
        ),
        boxShadow: rank == 1
            ? [
                BoxShadow(
                  color: context.colors.primary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fotoğraf ────────────────────────────────────────────────────────
          if (place.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: place.photoUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 160,
                  color: context.colors.primary.withOpacity(0.06),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  height: 100,
                  color: context.colors.primary.withOpacity(0.06),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: context.colors.hint,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

          // ── İçerik ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst satır: rozet + isim
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sıralama rozeti
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? _rankColor(context).withOpacity(0.15)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                          style: TextStyle(
                            fontSize: rank <= 3 ? 14 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (place.vicinity != null)
                            Text(
                              place.vicinity!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Alt satır: tip etiketi + puan + durum + harita butonu
                Row(
                  children: [
                    // Tip etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        place.primaryTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Rating
                    if (place.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFFFB800),
                      ),
                      SizedBox(width: 2),
                      Text(
                        place.ratingText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (place.userRatingsTotal != null)
                        Text(
                          ' (${place.userRatingsTotal})',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],

                    // Fiyat etiketi
                    if (place.priceLabelText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          place.priceLabelText!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Haritada Gör (küçük link)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(place.googleMapsUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: context.colors.hint,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'match.open_maps'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.hint,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Ulaşım süresi (GERÇEK — Google Distance Matrix API) ──────
                // NOT (güncelleme): Önceden kuş uçuşu mesafe + ortalama hız
                // varsayımıyla TAHMİN ediliyordu. Kullanıcı bunun gerçekliği
                // yansıtmadığını belirtti (örn. boğaz/köprü girince tahmin çok
                // sapıyor) — artık asıl veri kaynağı `venueSearchProvider`
                // üzerinden önceden (notifier içinde) hesaplanmış GERÇEK API
                // verisi. Süreler arama sonrası arka planda çekildiği için ilk
                // anda bu map boş olabilir; o sırada chip'ler gösterilmez,
                // veri gelince otomatik belirir (Consumer zaten dinliyor).
                // API'ye ulaşılamazsa o mekan için `isApproximate: true` ile
                // kuş uçuşu fallback'i kullanılır ve chip'te "~" öneki çıkar;
                // gerçek API verisinde "~" YOKTUR.
                Consumer(
                  builder: (ctx, ref, _) {
                    final estimate = ref.watch(
                      venueSearchProvider.select(
                        (s) => s.travelEstimates[place.placeId],
                      ),
                    );
                    if (estimate == null) {
                      return const SizedBox.shrink();
                    }
                    final prefix = estimate.isApproximate ? '~' : '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
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

                // ── Kaydet + Gitmeye Başla ───────────────────────────────────
                const SizedBox(height: 10),
                Consumer(
                  builder: (ctx, ref, _) {
                    final isSaved = ref.watch(
                      savedVenuesProvider.select(
                        (list) => list.any((p) => p.placeId == place.placeId),
                      ),
                    );
                    return Row(
                      children: [
                        // Kaydet butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () => ref
                                .read(savedVenuesProvider.notifier)
                                .toggle(place),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? context.colors.primary.withOpacity(0.12)
                                    : context.colors.card,
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
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border_outlined,
                                    size: 15,
                                    color: isSaved
                                        ? context.colors.primary
                                        : context.colors.textSecondary,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    isSaved
                                        ? 'match.saved'.tr()
                                        : 'match.save'.tr(),
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
                        // Gitmeye Başla butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openInMaps(ref),
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
                                    Icons.navigation_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
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
                    );
                  },
                ),

                // Açık mı?
                if (place.isOpenNow) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3FB950),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'match.now_open'.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
