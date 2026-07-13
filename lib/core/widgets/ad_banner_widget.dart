import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

/// Reklam banner alanı (320×50 formatı).
///
/// ──────────────────────────────────────────────────────────────────────────
/// DEBUG MODU  →  Reklam GÖSTERİLMEZ (bkz. [VenueSearchLoadingPage]).
///   Reklam yerleşimini önizlemek istersen yükleyici sayfadaki
///   [_kShowAdInDebug] sabitini geçici olarak `true` yap.
///
/// PROD MODU   →  Şu an: görsel placeholder gösterir (yer tutucu).
///   İleride buraya `google_mobile_ads` paketi entegre edilecek:
///     BannerAd → AdWidget (adUnitId: Platform.isIOS ? '...' : '...')
/// ──────────────────────────────────────────────────────────────────────────
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(premium): google_mobile_ads entegre edilince bu widget'ı
    // BannerAd → AdWidget ile değiştir. Debug'da test ad unit ID kullan.
    return _AdPlaceholder(isDebug: kDebugMode);
  }
}

// ── Placeholder ──────────────────────────────────────────────────────────────

class _AdPlaceholder extends StatelessWidget {
  final bool isDebug;
  const _AdPlaceholder({required this.isDebug});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      height: 60,
      decoration: BoxDecoration(
        color: colors.scaffold,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDebug
              ? Colors.orange.withOpacity(0.55)
              : colors.textSecondary.withOpacity(0.18),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // İçerik
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isDebug ? 'Reklam alanı (yer tutucu)' : 'Reklam',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary.withOpacity(0.65),
                  ),
                ),
                if (isDebug) ...[
                  const SizedBox(height: 2),
                  Text(
                    'google_mobile_ads · 320×50',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.textSecondary.withOpacity(0.40),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Etiket (sağ üst köşe)
          Positioned(
            top: 4,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isDebug
                    ? Colors.orange.withOpacity(0.14)
                    : colors.textSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDebug
                      ? Colors.orange.withOpacity(0.45)
                      : colors.textSecondary.withOpacity(0.20),
                ),
              ),
              child: Text(
                isDebug ? 'TEST' : 'Reklam',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: isDebug
                      ? Colors.orange
                      : colors.textSecondary.withOpacity(0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
