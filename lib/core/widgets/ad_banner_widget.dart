import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/app_config.dart';

/// Google Mobile Ads banner widget'ı (320×50 / adaptive format).
///
/// ── Debug modda test ID kullanılır; prod'da dart_defines.json'dan gelen
///    gerçek Unit ID (ADMOB_BANNER_ID) devreye girer.
/// ── Premium kullanıcılara (isPremium) bu widget gösterilmez —
///    VenueSearchLoadingPage'de AdService.shouldShowAd() ile karar verilir.
/// ── Reklam yüklenemezse placeholder gösterilir (hiçbir şey çökmez).
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;

  // Debug modda Google'ın resmi test ID'si kullanılır.
  // Bu ID her zaman reklam döndürür, gerçek tıklamaları saymaz.
  static const String _testUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Android test banner

  String get _unitId =>
      kDebugMode ? _testUnitId : AppConfig.admobBannerUnitId;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_unitId.isEmpty) return; // dart_defines.json'da key yoksa yükleme
    // `final` closure içinde kendine referans veremez (referenced_before_declaration).
    // Önce nullable declare et, sonra assign et.
    BannerAd? ad;
    ad = BannerAd(
      adUnitId: _unitId,
      size: AdSize.banner, // 320×50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad;
            _adLoaded = true;
          });
        },
        onAdFailedToLoad: (loadedAd, error) {
          loadedAd.dispose();
          // Sessizce başarısız ol — placeholder görünür, uygulama çökmez.
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adLoaded && _bannerAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        height: _bannerAd!.size.height.toDouble(),
        width: _bannerAd!.size.width.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // Reklam yüklenene kadar (veya başarısız olursa) minimal placeholder.
    return _AdPlaceholder(isDebug: kDebugMode);
  }
}

// ── Placeholder (yükleniyor / başarısız) ────────────────────────────────────

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
      child: Center(
        child: Text(
          isDebug ? 'Reklam yükleniyor…' : 'Reklam',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}
