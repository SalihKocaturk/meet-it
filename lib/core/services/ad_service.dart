import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reklam gösterim mantığını ve AdMob SDK yaşam döngüsünü yöneten servis.
///
/// ── Kullanım:
///    1. `main.dart`'ta `await AdService.initialize()` çağır.
///    2. Loading sayfasında `await AdService.incrementSearchCount()` çağır.
///    3. `shouldShowAd(isPremium)` → bu aramada büyük reklam gösterilecek mi?
///    4. Gösterilecekse: `preloadInterstitial()` → search bittikten sonra `showInterstitial()`.
///
/// Reklam kadansı: her [_adInterval] aramadan 1'inde TAM EKRAN (interstitial) reklam.
/// Premium kullanıcılar hiç reklam görmez.
///
/// Sayaç SharedPreferences'a yazılır — uygulama kapatılıp açılsa bile
/// kaldığı yerden devam eder. Örneğin 3 arama yapıp çıkan kullanıcı
/// geri döndüğünde 4. aramasında interstitial görür.
class AdService {
  AdService._();

  static int _searchCount = 0;
  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static bool _isLoadingInterstitial = false;

  /// Kaç aramada bir büyük reklam gösterilsin? (4 = her 4 aramadan 1'i)
  static const int _adInterval = 4;

  static const String _kSearchCountKey = 'ad_search_count';

  // ── Test ID'leri (kDebugMode) ────────────────────────────────────────────
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial

  // ── Init ────────────────────────────────────────────────────────────────

  /// AdMob SDK'yı başlat ve kalıcı sayacı yükle.
  /// `main.dart`'ta Firebase init'ten sonra çağrılmalı.
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    // Kalıcı sayacı SharedPreferences'tan yükle
    final prefs = await SharedPreferences.getInstance();
    _searchCount = prefs.getInt(_kSearchCountKey) ?? 0;
    _initialized = true;
  }

  // ── Sayaç ───────────────────────────────────────────────────────────────

  /// Her mekan araması başlamadan önce çağrılmalı.
  /// Sayaç artar ve SharedPreferences'a yazılır — uygulama kapansa bile korunur.
  static Future<void> incrementSearchCount() async {
    _searchCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSearchCountKey, _searchCount);
  }

  /// Bu aramada interstitial gösterilmeli mi?
  ///
  /// Premium kullanıcılar için her zaman false.
  /// [_adInterval] aramadan 1'inde true döner.
  static bool shouldShowAd({required bool isPremium}) {
    if (isPremium) return false;
    return _searchCount % _adInterval == 0;
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  String get _interstitialUnitId =>
      kDebugMode ? _testInterstitialId : AppConfig.admobInterstitialUnitId;

  static String _unitId() =>
      kDebugMode ? _testInterstitialId : AppConfig.admobInterstitialUnitId;

  /// Tam ekran reklamı önceden yükle (fire-and-forget).
  ///
  /// Arama başladıktan kısa süre sonra çağrılabilir — yüklenme süresi
  /// arama süresiyle örtüştüğü için kullanıcı beklemez.
  static Future<void> preloadInterstitial({VoidCallback? onLoaded}) async {
    if (_interstitialAd != null || _isLoadingInterstitial) {
      onLoaded?.call();
      return;
    }
    final unitId = _unitId();
    if (unitId.isEmpty) return;

    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          onLoaded?.call();
        },
        onAdFailedToLoad: (_) {
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// Tam ekran reklamı göster.
  ///
  /// Reklam kapatılınca (veya gösterilemezse) [onDismissed] çağrılır.
  /// Reklam yüklü değilse anında [onDismissed] çağrılıp false döner.
  static Future<bool> showInterstitial({
    required void Function() onDismissed,
  }) async {
    final ad = _interstitialAd;
    if (ad == null) {
      onDismissed();
      return false;
    }
    _interstitialAd = null; // kullanıldı, sonraki arama için sıfırla

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        ad.dispose();
        onDismissed();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        ad.dispose();
        onDismissed();
      },
    );

    await ad.show();
    return true;
  }

  /// Yüklü interstitial var mı?
  static bool get isInterstitialReady => _interstitialAd != null;

  /// Test/geliştirme amaçlı sayacı sıfırla (hem bellekte hem kalıcı depoda).
  static Future<void> resetCounterForTesting() async {
    _searchCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSearchCountKey);
  }
}
