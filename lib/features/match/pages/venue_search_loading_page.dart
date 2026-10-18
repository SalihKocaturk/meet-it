// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/services/ad_service.dart';
import 'package:meetit/core/widgets/ad_banner_widget.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_character.dart';

// Debug'da reklam yerleşimini önizlemek için bu sabiti geçici olarak
// `true` yap (commit'leme, sadece local test amaçlı).
// ignore: constant_identifier_names
const _kShowAdInDebug = false;

// ── Sayfa ─────────────────────────────────────────────────────────────────────

/// Mekan arama loading sayfası — iki fazlı animasyon:
///
///  Faz 1 (0–2.5 sn): Her karakter kendi kişilik animasyonunu oynar.
///    • Maceraperest → paraşütle iner
///    • Gurme        → tabak+çatalla durur
///    • vb.
///
///  Faz 2 (2.5 sn+): Karakterler sahnenin içinde yürüyerek büyüteçle dolaşır.
///    Kullanıcı soldan sağa, arkadaş sağdan sola ilerliyorken yön döndüklerinde
///    flipX otomatik değişir — birbirlerinden geçer gibi görünürler.
///
/// [simulationMode] = true iken gerçek API çağrısı yapılmaz; 6.5 sn
/// sonra otomatik pop olur (önizleme/demo amaçlı).
class VenueSearchLoadingPage extends ConsumerStatefulWidget {
  final PersonalityProfile userProfile;
  final PersonalityProfile friendProfile;
  final String? friendUid;
  final List<String> selectedActivities;
  final int? priceLevel;
  final double? userLat;
  final double? userLng;
  final double? maxVenueDistanceKm;

  /// true → API çağrısı yapılmaz, animasyon simüle edilir (önizleme).
  final bool simulationMode;

  const VenueSearchLoadingPage({
    super.key,
    required this.userProfile,
    required this.friendProfile,
    required this.friendUid,
    required this.selectedActivities,
    this.priceLevel,
    this.userLat,
    this.userLng,
    this.maxVenueDistanceKm,
    this.simulationMode = false,
  });

  @override
  ConsumerState<VenueSearchLoadingPage> createState() =>
      _VenueSearchLoadingPageState();
}

class _VenueSearchLoadingPageState
    extends ConsumerState<VenueSearchLoadingPage>
    with TickerProviderStateMixin {
  // ── Animasyonlar ─────────────────────────────────────────────────────────────
  late final AnimationController _slideCtrl;   // sahneye giriş (1.2 sn)
  late final AnimationController _progressCtrl; // ham ilerleme (zamanlayıcı + arama)
  /// visualProgress: ekranda görünen, yumuşatılmış ilerleme. Karakter
  /// yürüyüşü, aksesuar geçişi, faz metni, % göstergesi ve bar BUNU dinler.
  late final AnimationController _visualCtrl;
  /// Aksesuar → büyüteç geçişi (2 sn, zamanla sürülür).
  late final AnimationController _swapCtrl;
  /// Ortaya yürüyüş (6.5 sn) — ilerleme yüzdesinden tamamen bağımsız:
  /// yüzde ne kadar sıçrarsa sıçrasın karakterler sabit hızda yürür.
  late final AnimationController _walkCtrl;
  late final AnimationController _shimmerCtrl;  // progress bar shimmer
  late final AnimationController _pulseCtrl;    // merkez pin nabzı
  late final AnimationController _celebrateCtrl; // %100: beşlik + sevinç pozu

  late final Animation<double> _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _searchStarted    = false;
  bool _popping          = false;
  bool _navigated        = false; // çifte pop koruması (Atla + oto-geçiş yarışı)
  bool _searchDone       = false;
  bool _skipVisible      = false; // aramanın 2. sn'sinden itibaren görünür
  bool _skipRequested    = false; // kullanıcı "Animasyonu Atla"ya bastı
  bool _resultsReady     = false; // arama sonucu hazır (geçiş yapılabilir)
  int  _shownPct         = 0;     // ekrandaki yüzde (yalnızca artar)
  Timer? _skipTimer;
  bool _showInterstitial = false; // bu aramada tam ekran reklam gösterilecek mi?
  bool _adDismissed      = true;  // reklam yok ya da kapandı → geçişe izin ver
  bool _progressFull     = false; // görsel ilerleme %100'e ulaştı mı
  bool _rawDone          = false; // ham ilerleme 1.0'a ulaştı (arama bitti)
  bool _swapStarted      = false; // aksesuar → büyüteç geçişi başladı mı
  bool _walkStarted      = false; // ortaya yürüyüş başladı mı
  double _visualTarget   = 0.0;   // visualProgress'in son hedefi

  /// Görsel ilerlemenin yumuşaklığı: kritik sönümlü yay, bir sıçramayı
  /// ~2.2 sn'de easeInOut benzeri bir eğriyle kapatır. animateTo her karede
  /// yeniden başlatılsaydı easeInOutCubic sürekli sıfır hızdan başlar ve
  /// ilerleme takılırdı; yay mevcut hızı koruyarak yeni hedefe yönelir.
  static final _visualSpring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 7.0, // ω≈2.65 → %98 yerleşme ≈ 2.2 sn
    ratio: 1.0,
  );
  late final DateTime _startTime;
  Timer? _simTimer;

  /// Durum metni doğrudan ilerlemeye bağlı — zamanlayıcıyla dönüp başa
  /// sarmaz ("Son dokunuşlar" → tekrar "Konumunuz alınıyor" olmaz).
  static String _phaseFor(double p) {
    if (p >= 0.999) return 'Mekanlar bulundu!';
    if (p < 0.25) return 'Konumunuz alınıyor...';
    if (p < 0.55) return 'Kişiliğinize göre mekanlar aranıyor...';
    if (p < 0.80) return 'En iyi eşleşmeler seçiliyor...';
    return 'Son dokunuşlar yapılıyor...';
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _startTime = DateTime.now();

    // Sahneye giriş kaymasını başlat
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _slideCtrl.forward();

    // "Animasyonu Atla" aramanın 2. saniyesinde yumuşakça belirir.
    _skipTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted && !_progressFull) setState(() => _skipVisible = true);
    });

    // Progress koreografiyle senkron:
    //   %0–40  (4 sn)  : intro + büyüteci alma — karakterler köşelerde
    //   %40–90 (3.5 sn): ortaya yürüyüş (yaklaşma %40–%96'ya yayılır)
    //   %90–96 (9 sn)  : arama sürüyorsa çok yavaş ilerler (takılı görünmez)
    //   Arama bitince : kalan yol doğal hızda tamamlanır → %100'de kutlama
    _progressCtrl = AnimationController(vsync: this, value: 0);
    _progressCtrl
        .animateTo(0.40,
            duration: const Duration(milliseconds: 4000),
            curve: Curves.easeInOut)
        .then((_) {
      if (!mounted || _searchDone) return;
      _progressCtrl
          .animateTo(0.90,
              duration: const Duration(milliseconds: 3500),
              curve: Curves.easeInOut)
          .then((_) {
        if (!mounted || _searchDone) return;
        _progressCtrl.animateTo(0.96,
            duration: const Duration(milliseconds: 9000),
            curve: Curves.linear);
      });
    });

    // Ham ilerleme ne kadar ani değişirse değişsin, ekrandaki ilerleme ona
    // yavaşça (≈2.2 sn) yetişir — karakterler hiçbir zaman sıçramaz.
    _visualCtrl = AnimationController(vsync: this, value: 0);
    _progressCtrl.addListener(_onRawProgress);
    _visualCtrl.addListener(_onVisualProgress);

    // %12'de aksesuar 2 sn'de solar / büyüteç belirir; karakterler bu sırada
    // köşelerinde sabit durur. Geçiş bitip ilerleme %25'i geçince yürüyüş
    // başlar (6.5 sn, easeInOutSine).
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _maybeStartWalk();
      });
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _maybeCelebrate();
      });

    // Shimmer şeridi
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Pin nabzı
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    // Final: mekanlar bulununca karakterler beşlik çakıp sevinir.
    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // NOT: Aksesuar → büyüteç geçişi ve ortaya yürüyüş artık zamanlayıcıyla
    // değil, doğrudan ilerlemeyle (progress) sürülüyor — bkz. _SearchStage.

    // ── Reklam kararı ───────────────────────────────────────────────────
    // • Simülasyon modunda reklam gösterilmez.
    // • Debug modunda _kShowAdInDebug sabiti false ise gösterilmez.
    // • Gerçek aramada: her 4 aramadan 1'inde tam ekran (interstitial) reklam.
    //
    // ÖNEMLİ: Reklam artık ARAMA SONUNDA değil, YÜKLEME BAŞINDA gösterilir.
    // Kullanıcı "Mekan Bul" diye bastığında loading sayfası açılır; reklam
    // hemen (800ms sonra) belirir ve arama arka planda yürür. Reklam kapanınca
    // + arama bitince geçiş yapılır → bekleme süresini reklamla değerlendirmiş
    // oluruz, sonuçları ayrıca bekletmeyiz.
    // Reklamlar geçici olarak devre dışı bırakıldı.
    // if (!widget.simulationMode && (kReleaseMode || _kShowAdInDebug)) {
    //   final isPremium = ref.read(isPremiumProvider);
    //   AdService.incrementSearchCount().ignore();
    //   _showInterstitial = AdService.shouldShowAd(isPremium: isPremium);
    //   if (_showInterstitial) {
    //     _adDismissed = false; // geçişi kilitle: reklam kapanana dek beklenir
    //     // Reklamı yükle; yüklenir yüklenmez göster (minimum 800ms bekle).
    //     final loadStart = DateTime.now();
    //     AdService.preloadInterstitial(onLoaded: () {
    //       final elapsed = DateTime.now().difference(loadStart).inMilliseconds;
    //       final wait = (800 - elapsed).clamp(0, 800);
    //       Future.delayed(Duration(milliseconds: wait), () {
    //         if (!mounted) return;
    //         AdService.showInterstitial(
    //           onDismissed: () {
    //             if (!mounted) return;
    //             setState(() => _adDismissed = true);
    //             if (_popping && !_navigated) _doNavigate();
    //           },
    //         );
    //       });
    //     });
    //   }
    //   // _showInterstitial = false ise _adDismissed zaten true (geçişi kilitlemez)
    // }

    if (widget.simulationMode) {
      // Simülasyon: 8 sn sonra tamamlan, sonra atla butonu göster
      _simTimer = Timer(const Duration(milliseconds: 8000), () {
        if (mounted) _finishAndPop();
      });
    } else {
      // Gerçek arama: slide-in bittikten kısa süre sonra başlat
      Future.delayed(const Duration(milliseconds: 450), _startSearch);
    }
  }

  Future<void> _startSearch() async {
    if (!mounted || _searchStarted) return;
    _searchStarted = true;

    await ref.read(venueSearchProvider.notifier).searchVenues(
      userProfile: widget.userProfile,
      friendProfile: widget.friendProfile,
      selectedActivities: widget.selectedActivities,
      friendUid: widget.friendUid,
      priceLevel: widget.priceLevel,
      userLat: widget.userLat,
      userLng: widget.userLng,
      maxVenueDistanceKm: widget.maxVenueDistanceKm,
    );

    if (!mounted) return;
    _finishAndPop();
  }

  void _finishAndPop() {
    if (_popping) return;
    _popping = true;
    _resultsReady = true;

    // Kullanıcı daha önce "Animasyonu Atla"ya bastıysa beklemeden geç.
    if (_skipRequested) {
      _doNavigate();
      return;
    }

    // Minimum 6 saniye animasyon süresi garantisi
    final elapsed  = DateTime.now().difference(_startTime).inMilliseconds;
    final waitLeft = math.max(0, 6000 - elapsed);

    Future.delayed(Duration(milliseconds: waitLeft), () {
      if (!mounted) return;
      setState(() => _searchDone = true);

      // Kalan yolu doğal hızda tamamla — karakterler koşturmadan ortaya varır.
      final remaining = 1.0 - _progressCtrl.value;
      final ms = (remaining * 6000).clamp(600, 3500).round();
      _progressCtrl
          .animateTo(1.0,
              duration: Duration(milliseconds: ms),
              curve: Curves.easeInOut)
          .then((_) {
        if (!mounted) return;
        // Ham ilerleme %100 — atla butonu / kutlama, visualProgress de
        // %100'e yetiştiğinde (_onVisualProgress) tetiklenir.
        _rawDone = true;
        _onRawProgress();
        _onVisualProgress();
      });
    });
  }

  /// Ham ilerleme değişti → visualProgress'i yeni hedefe yumuşakça yönelt.
  void _onRawProgress() {
    final target = _progressCtrl.value;
    if (target < 1.0 && (target - _visualTarget).abs() < 0.002) return;
    if (target == _visualTarget) return;
    _visualTarget = target;
    _visualCtrl.animateWith(SpringSimulation(
      _visualSpring,
      _visualCtrl.value,
      target,
      _visualCtrl.velocity,
    ));
  }

  /// visualProgress değişti: geçiş / yürüyüş tetikleri ve %100 sonu.
  void _onVisualProgress() {
    final v = _visualCtrl.value;
    if (!_swapStarted && v >= 0.12) {
      _swapStarted = true;
      _swapCtrl.forward();
    }
    _maybeStartWalk();

    if (!_rawDone || _progressFull || v < 0.995) return;
    // Bayrak ÖNCE set edilir: value ataması dinleyiciyi yeniden tetikler.
    _progressFull = true;
    _visualCtrl.value = 1.0;
    _skipTimer?.cancel();
    setState(() {}); // atla butonu gizlenir, başlık "Mekanlar bulundu!"

    // %100 olduğunda yürüyüş bitmediyse kalan yolu hızlıca tamamla.
    if (!_walkCtrl.isCompleted) {
      if (!_swapStarted) {
        _swapStarted = true;
        _swapCtrl.forward();
      }
      _walkStarted = true;
      final ms = ((1.0 - _walkCtrl.value) * 6500 * 0.35).clamp(500, 2000).round();
      _walkCtrl.animateTo(1.0,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
    }
    _maybeCelebrate();
  }

  /// Geçiş bitti VE görsel ilerleme %25'i geçti → yürüyüşü başlat.
  void _maybeStartWalk() {
    if (_walkStarted || !_swapCtrl.isCompleted) return;
    if (_visualCtrl.value < 0.25) return;
    _walkStarted = true;
    _walkCtrl.forward();
  }

  /// Karakterler ortada buluşmuş VE ilerleme %100 ise sevinç sahnesini oynat.
  void _maybeCelebrate() {
    if (!mounted || !_progressFull || !_walkCtrl.isCompleted) return;
    if (_celebrateCtrl.isAnimating || _celebrateCtrl.value > 0) return;
    _celebrateCtrl.forward();
    // Beşlikten 3 sn sonra otomatik geç (kullanıcı atlamazsa)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) _doNavigate();
    });
  }

  /// "Animasyonu Atla": sonuç hazırsa hemen geç; değilse arama biter bitmez
  /// (6 sn minimum beklemeden) geçilir. Sonuç gelmeden pop edilirse arama
  /// sayfası "mekan bulunamadı" gösterirdi.
  void _onSkipPressed() {
    if (_skipRequested) return;
    setState(() => _skipRequested = true);
    if (_resultsReady) _doNavigate();
  }

  /// Ekrandaki yüzde: visualProgress'ten 1'er 1'er akar, asla geri gitmez;
  /// %100 yalnızca gerçekten bittiğinde gösterilir.
  int _displayPct() {
    final raw = (_visualCtrl.value * 100).floor();
    final target = _progressFull ? 100 : raw.clamp(0, 99);
    if (target > _shownPct) _shownPct = target;
    return _shownPct;
  }

  void _doNavigate() {
    // mounted, route çıkış animasyonu bitene dek true kalır — "Animasyonu
    // Atla"ya basıldıktan hemen sonra 3 sn'lik oto-geçiş de tetiklenirse
    // Navigator iki kez pop edilir ve alttaki sayfa da kapanırdı (crash).
    if (!mounted || _navigated) return;

    // Reklam açıksa bekle: onDismissed callback'i tekrar çağırır.
    // (Reklam yoksa veya kapandıysa _adDismissed == true, engel yok.)
    if (!_adDismissed) return;

    _navigated = true;
    _simTimer?.cancel();

    Navigator.of(context).pop();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _slideCtrl.dispose();
    _progressCtrl.removeListener(_onRawProgress);
    _progressCtrl.dispose();
    _visualCtrl.dispose();
    _swapCtrl.dispose();
    _walkCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrateCtrl.dispose();
    _simTimer?.cancel();
    _skipTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final me        = ref.watch(currentUserProvider);
    final friend    = ref.watch(selectedFriendProvider);
    // final isPremium = ref.watch(isPremiumProvider); // Reklamlar devre dışı — kullanılmıyor
    final isSolo = widget.friendUid == null;

    final myType     = widget.userProfile.dominantType;
    final friendType = widget.friendProfile.dominantType;

    final primary  = context.colors.primary;
    final scaffold = context.colors.scaffold;

    // Arka plan: soluk yeşil gradyan, light/dark temaya uyumlu
    final bgGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(primary.withOpacity(0.10), scaffold),
        scaffold,
        Color.alphaBlend(primary.withOpacity(0.06), scaffold),
      ],
    );

    return Scaffold(
      backgroundColor: scaffold,
      body: Container(
        decoration: BoxDecoration(gradient: bgGrad),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 44),

              // ── Başlık ─────────────────────────────────────────────────────
              Text(
                isSolo ? 'Mekan Aranıyor' : 'Buluşma Noktası Aranıyor',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),

              // Simülasyon rozeti
              if (widget.simulationMode) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primary.withOpacity(0.30)),
                  ),
                  child: Text(
                    'Önizleme Modu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // ── Faz metni ─────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _visualCtrl,
                builder: (context, _) => SizedBox(
                height: 20,
                // Eski metin önce tamamen söner, yeni metin sonra belirir —
                // geçişte iki metin asla üst üste binmez.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: anim,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                  child: Text(
                    _phaseFor(_visualCtrl.value),
                    key: ValueKey<String>(_phaseFor(_visualCtrl.value)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              ),

              // ── Kişilik tipi rozetleri: arama boyunca hep görünür ──────────
              Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PersonalityChip(
                              name: (me?.name ?? 'Sen').split(' ').first,
                              type: myType,
                              color: primary,
                            ),
                            if (!isSolo) ...[
                              const SizedBox(width: 20),
                              _PersonalityChip(
                                name: (friend?.name ?? '').split(' ').first,
                                type: friendType,
                                color: primary,
                              ),
                            ],
                          ],
                        ),
                      ),

              const Spacer(),

              // ── Karakter animasyon alanı ──────────────────────────────────
              // Tek sahne: intro ve arama arasında sahne takası yok.
              // Arama başlarken kişilik arka planı sönerken şehir silüeti
              // yavaşça belirir; karakterler yerlerinde arama moduna geçer.
              SizedBox(
                height: 240,
                child: _SearchStage(
                  me: me,
                  friend: friend,
                  isSolo: isSolo,
                  myType: myType,
                  friendType: friendType,
                  slideAnim: _slideAnim,
                  swapCtrl: _swapCtrl,
                  walkCtrl: _walkCtrl,
                  celebrateCtrl: _celebrateCtrl,
                  pulseCtrl: _pulseCtrl,
                  accentColor: primary,
                ),
              ),

              const Spacer(),

              // ── Banner reklam (her aramada, premium olmayan kullanıcılara) ──
              // Reklamlar geçici olarak devre dışı bırakıldı.
              // if (!widget.simulationMode && !isPremium)
              //   const Padding(
              //     padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
              //     child: AdBannerWidget(),
              //   ),

              // ── Progress bölümü ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Durum satırı: nefes alan nokta + metin | akıcı yüzde
                    AnimatedBuilder(
                      animation: Listenable.merge([_visualCtrl, _pulseCtrl]),
                      builder: (_, __) {
                        final pct = _displayPct();
                        final label = _progressFull
                            ? 'Mekanlar bulundu!'
                            : widget.simulationMode
                                ? 'Simülasyon çalışıyor...'
                                : 'Aranıyor...';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              _StatusDot(
                                pulse: _pulseCtrl.value,
                                done: _progressFull,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [...previous, if (current != null) current],
                                  ),
                                  child: Text(
                                    label,
                                    key: ValueKey<String>(label),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _progressFull
                                          ? _kEmerald
                                          : context.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '%$pct',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _kEmerald,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: Listenable.merge([_visualCtrl, _shimmerCtrl]),
                      builder: (context, _) => _GradientProgressBar(
                        progress: _visualCtrl.value,
                        shimmer: _shimmerCtrl.value,
                        trackColor: context.colors.textPrimary.withOpacity(
                            Theme.of(context).brightness == Brightness.dark
                                ? 0.08
                                : 0.07),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _visualCtrl,
                      builder: (_, __) => _StepIndicator(
                        progress: _progressFull ? 1.0 : _visualCtrl.value,
                        finished: _progressFull,
                      ),
                    ),

                    // ── Animasyonu Atla: aramanın 2. sn'sinden itibaren
                    // görünür, %100'de (zaten geçiş yapılacağı için) gizlenir.
                    Builder(builder: (_) {
                      final visible =
                          _skipVisible && !_progressFull && !_skipRequested;
                      return IgnorePointer(
                        ignoring: !visible,
                        child: AnimatedOpacity(
                          opacity: visible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeInOut,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _onSkipPressed,
                                icon: Icon(Icons.skip_next_rounded,
                                    size: 18, color: primary),
                                label: Text(
                                  'Animasyonu Atla',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  backgroundColor: primary.withOpacity(0.09),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(
                                        color: primary.withOpacity(0.28)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sahne: intro + arama tek parça ───────────────────────────────────────────
//
// Intro ve arama iki ayrı sahne değil — dekor HİÇ değişmez:
//   • Şehir silüeti en baştan sahnede; kişilik arka planları (dağ, kitaplık
//     vb.) hiç çizilmez (showBackground: false).
//   • Intro: karakterler kenarlarda kişilik girişini oynar (paraşütle iniş,
//     kitap okuma vb.).
//   • Arama başlayınca sadece mekan pinleri yavaşça belirir; karakterler
//     crossfade ile arama moduna geçer, elindeki aksesuarı bırakıp yerden
//     büyüteci alır (pickup sekansı) ve yürüyüşe koyulur.
//
// Koreografi:
//   1) %0–12 : karakterler köşelerde kişilik pozunda.
//   2) %12'de: aksesuar 2 sn'de yavaşça solar, büyüteç belirir (swapCtrl).
//      Karakterler bu sırada köşelerinde sabit, dimdik durur.
//   3) Geçiş bitip %25 geçilince: ilerleme yüzdesinden BAĞIMSIZ 6.5 sn'lik
//      yürüyüş (walkCtrl, easeInOutSine) — yüzde sıçrasa da fırlama olmaz.
//      %100'e gelindiğinde yürüyüş bitmediyse kalan yol hızlıca tamamlanır.
//   4) Ortaya varınca + %100: ±38 px'te beşlik. Parıltı / partikül yok.

/// Yaklaşmanın anlık örneği: konum (0..1) + adım yoğunluğu (0..1).
class _WalkSample {
  final double pos;
  final double walk;
  const _WalkSample(this.pos, this.walk);
}

class _SearchStage extends StatelessWidget {
  final dynamic me;
  final dynamic friend;
  final bool isSolo;
  final PersonalityType myType;
  final PersonalityType friendType;
  final Animation<double> slideAnim;
  final AnimationController swapCtrl;
  final AnimationController walkCtrl;
  final AnimationController celebrateCtrl;
  final AnimationController pulseCtrl;
  final Color accentColor;

  static const _charSize = 148.0;

  /// Karakterlerin ayak hizası — ikisi için de birebir aynı (üst üste
  /// binme / biri diğerinin başına çıkma olmasın).
  static const _ground = 22.0;

  /// Buluşma anında karakter merkezlerinin ortadan uzaklığı (px).
  static const _meetGap = 38.0;

  const _SearchStage({
    required this.me,
    required this.friend,
    required this.isSolo,
    required this.myType,
    required this.friendType,
    required this.slideAnim,
    required this.swapCtrl,
    required this.walkCtrl,
    required this.celebrateCtrl,
    required this.pulseCtrl,
    required this.accentColor,
  });

  /// Intro ↔ arama modu karakteri: mod değişince 450 ms crossfade —
  /// kişilik pozu yumuşakça söner, arama karakteri aynı konumda belirir.
  Widget _characterSwitcher({
    required bool inSearchMode,
    required PersonalityType type,
    required String? gender,
    required bool flip,
    required double pickupT,
    required double walk,
    required double celebrate,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: inSearchMode
          ? PersonalityCharacterWidget(
              key: const ValueKey('search'),
              type: type, gender: gender,
              size: _charSize, searchMode: true, flipX: flip,
              pickup: pickupT,
              walkAmount: walk, celebrate: celebrate, highFive: !isSolo)
          : PersonalityCharacterWidget(
              key: const ValueKey('intro'),
              type: type, gender: gender,
              size: _charSize, searchMode: false, flipX: flip,
              // Kişilik arka planı (dağ, kitaplık vb.) çizilmez — dekor
              // en baştan şehir silüeti, geçişte hiçbir dekor kaybolmaz.
              showBackground: false),
    );
  }

  Widget _nameLabel(String name) => Text(
        name,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        slideAnim, swapCtrl, walkCtrl, celebrateCtrl, pulseCtrl,
      ]),
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          const pad = 6.0;
          const lo = pad;
          final hi = w - _charSize - pad;
          final centerX = w / 2;

          final slide = slideAnim.value.clamp(0.0, 1.0);
          final celebrate = celebrateCtrl.value;

          // Aksesuar → büyüteç geçişi (2 sn): aksesuar elde yavaşça solar,
          // büyüteç belirir. Bu sırada karakterler köşelerinde sabit durur.
          final inSearchMode = swapCtrl.status != AnimationStatus.dismissed;
          final pickupT = swapCtrl.value;

          // Şehir silüeti en baştan sahnede; mekan pinleri arama başlarken,
          // büyüteci alma sekansının ilk %60'ında yavaşça belirir.
          final pinT = !inSearchMode
              ? 0.0
              : Curves.easeInOut.transform((pickupT / 0.6).clamp(0.0, 1.0));

          // Yürüyüş ilerleme yüzdesinden bağımsız: 6.5 sn'lik walkCtrl.
          final su0 = _sample(walkCtrl.value);
          final sf0 = su0;
          final suWalk = su0.walk;
          final sfWalk = sf0.walk;

          // Karakter MERKEZLERİ: başlangıçta köşeler, sonunda ortanın ±38 px'i.
          // Sol karakter hep sağa, sağ karakter hep sola bakar — birbirlerinin
          // içinden geçmezler, böylece üst üste binme imkânsız.
          final userStartC = lo + _charSize / 2;
          final userEndC = isSolo ? centerX - 30 : centerX - _meetGap;
          final friendStartC = hi + _charSize / 2;
          const friendEndOffset = _meetGap;
          final userX =
              userStartC + (userEndC - userStartC) * su0.pos - _charSize / 2;
          final friendX = friendStartC +
              (centerX + friendEndOffset - friendStartC) * sf0.pos -
              _charSize / 2;

          const pins = [
            (0.06, 44.0, true), (0.22, 54.0, false), (0.38, 44.0, true),
            (0.54, 56.0, false), (0.70, 46.0, true), (0.84, 52.0, false),
          ];

          final userWidget = Column(mainAxisSize: MainAxisSize.min, children: [
            _characterSwitcher(
              inSearchMode: inSearchMode,
              type: myType, gender: me?.gender as String?,
              flip: false,
              pickupT: pickupT,
              walk: suWalk,
              celebrate: celebrate),
            const SizedBox(height: 3),
            _nameLabel(((me?.name ?? 'Sen') as String).split(' ').first),
          ]);

          return SizedBox(
            width: w, height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Opacity(
                  opacity: slide,
                  child: _CityScapeWidget(color: accentColor))),

              for (final p in pins)
                Positioned(left: w * p.$1, bottom: p.$2,
                  child: Opacity(
                    opacity: pinT * (1 - celebrate),
                    child: _PulsingPin(
                      pulseCtrl: pulseCtrl, color: accentColor,
                      evenPhase: p.$3))),

              Positioned(
                left: userX, bottom: _ground,
                child: Transform.translate(
                  offset: Offset(-160 * (1 - slide), 0),
                  child: Opacity(opacity: slide, child: userWidget),
                ),
              ),

              if (!isSolo)
                Positioned(
                  left: friendX, bottom: _ground,
                  child: Transform.translate(
                    offset: Offset(160 * (1 - slide), 0),
                    child: Opacity(
                      opacity: slide,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _characterSwitcher(
                          inSearchMode: inSearchMode,
                          type: friendType, gender: friend?.gender as String?,
                          flip: true,
                          pickupT: pickupT,
                          walk: sfWalk,
                          celebrate: celebrate),
                        const SizedBox(height: 3),
                        _nameLabel(
                            ((friend?.name ?? '') as String).split(' ').first),
                      ]),
                    ),
                  ),
                ),

            ]),
          );
        },
      ),
    );
  }

  // ── Yaklaşma ─────────────────────────────────────────────────────────────
  // walkT (0..1) → konum (easeInOutSine) + adım genişliği (stride envelope).
  // Adımlar ilk %15'te küçükten normale açılır, son %15'te küçülerek kapanır
  // — bacaklar hiçbir zaman bir anda makas gibi açılıp kapanmaz.
  static _WalkSample _sample(double walkT) {
    final t = walkT.clamp(0.0, 1.0);
    final pos = Curves.easeInOutSine.transform(t);
    final double stride;
    if (t <= 0.0 || t >= 1.0) {
      stride = 0.0;
    } else if (t < 0.15) {
      stride = Curves.easeInOut.transform(t / 0.15);
    } else if (t > 0.85) {
      stride = Curves.easeInOut.transform((1.0 - t) / 0.15);
    } else {
      stride = 1.0;
    }
    return _WalkSample(pos, stride);
  }
}

// ── Renkler (alt bar) ─────────────────────────────────────────────────────────

const _kEmeraldDeep  = Color(0xFF059669);
const _kEmerald      = Color(0xFF10B981);
const _kEmeraldLight = Color(0xFF34D399);

// ── Durum noktası ─────────────────────────────────────────────────────────────

/// "Aranıyor..." yanında nefes alan küçük yeşil nokta; %100'de sabit parlar.
class _StatusDot extends StatelessWidget {
  final double pulse; // 0..1 (ileri-geri)
  final bool done;

  const _StatusDot({required this.pulse, required this.done});

  @override
  Widget build(BuildContext context) {
    final p = done ? 1.0 : Curves.easeInOut.transform(pulse);
    final color = done ? _kEmerald : _kEmeraldLight;
    return SizedBox(
      width: 10,
      height: 10,
      child: Center(
        child: Transform.scale(
          scale: done ? 1.0 : 0.80 + 0.25 * p,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(done ? 1.0 : 0.55 + 0.45 * p),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(done ? 0.75 : 0.25 + 0.45 * p),
                  blurRadius: done ? 8 : 3 + 5 * p,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient Progress Bar ─────────────────────────────────────────────────────

/// İnce (10 px) hap şeklinde bar: zümrüt gradyan dolgu, dolgu içinde sürekli
/// soldan sağa akan shimmer ve dolgunun ucunda hafif neon parlama.
/// Slider topuzu (beyaz daire) yok.
class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final double shimmer;
  final Color  trackColor;

  static const double height = 10;

  const _GradientProgressBar({
    required this.progress,
    required this.shimmer,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ProgressPainter(
          progress: progress,
          shimmer: shimmer,
          trackColor: trackColor,
        ),
        size: const Size(double.infinity, height),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final double shimmer;
  final Color  trackColor;

  const _ProgressPainter({
    required this.progress,
    required this.shimmer,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    const radius = Radius.circular(99);

    // Ray
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.003) return;

    final fillW = math.max(h, size.width * p);
    final fillRect = Rect.fromLTWH(0, 0, fillW, h);
    final fillRRect = RRect.fromRectAndRadius(fillRect, radius);

    // Uçtaki neon parlama (BoxShadow blur 10 eşdeğeri) — dolgunun altında
    canvas.drawCircle(
      Offset(fillW - h / 2, h / 2),
      h * 0.75,
      Paint()
        ..color = _kEmeraldLight.withOpacity(0.70)
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, Shadow.convertRadiusToSigma(10)),
    );

    // Dolgu: #059669 → #10B981 → #34D399
    canvas.drawRRect(
      fillRRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kEmeraldDeep, _kEmerald, _kEmeraldLight],
          stops: [0.0, 0.55, 1.0],
        ).createShader(fillRect),
    );

    // Shimmer: dolgu içinde sürekli soldan sağa akan yumuşak ışık dalgası
    canvas.save();
    canvas.clipRRect(fillRRect);
    final shimW = math.max(48.0, fillW * 0.45);
    final shimX = -shimW + shimmer * (fillW + shimW);
    final shimRect = Rect.fromLTWH(shimX, 0, shimW, h);
    canvas.drawRect(
      shimRect,
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.38),
          Colors.white.withOpacity(0),
        ]).createShader(shimRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) =>
      old.progress != progress ||
      old.shimmer != shimmer ||
      old.trackColor != trackColor;
}

// ── Adım Göstergesi ───────────────────────────────────────────────────────────

enum _StepState { completed, active, upcoming }

/// 4 adım: Konum (%0–25), Mekanlar (%25–55), Filtreleme (%55–85),
/// Hazır (%85–100). Her adım: üstte ince gösterge çubuğu + altında etiket.
class _StepIndicator extends StatelessWidget {
  final double progress;
  final bool finished;

  const _StepIndicator({required this.progress, required this.finished});

  static const _labels = ['Konum', 'Mekanlar', 'Filtreleme', 'Hazır'];
  static const _starts = [0.00, 0.25, 0.55, 0.85];
  static const _ends   = [0.25, 0.55, 0.85, 1.00];

  _StepState _stateFor(int i) {
    final done = i == _labels.length - 1 ? finished : progress >= _ends[i];
    if (done) return _StepState.completed;
    if (progress >= _starts[i]) return _StepState.active;
    return _StepState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = context.colors.textPrimary;
    const dur = Duration(milliseconds: 380);

    return Row(
      children: List.generate(_labels.length, (i) {
        final st = _stateFor(i);

        final Color barColor;
        final Color textColor;
        final FontWeight weight;
        final List<BoxShadow> glow;
        switch (st) {
          case _StepState.completed:
            barColor = _kEmerald;
            textColor = isDark ? _kEmerald : _kEmeraldDeep;
            weight = FontWeight.w600;
            glow = const [];
          case _StepState.active:
            barColor = _kEmeraldLight;
            textColor =
                isDark ? const Color(0xFFD1FAE5) : const Color(0xFF047857);
            weight = FontWeight.w600;
            glow = [
              BoxShadow(
                color: _kEmeraldLight.withOpacity(0.55),
                blurRadius: 8,
              ),
            ];
          case _StepState.upcoming:
            barColor = base.withOpacity(isDark ? 0.14 : 0.10);
            textColor = base.withOpacity(0.35);
            weight = FontWeight.w500;
            glow = const [];
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 3,
              right: i == _labels.length - 1 ? 0 : 3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: dur,
                  curve: Curves.easeOut,
                  height: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: glow,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tamamlandı: etiketin önünde zarif bir tik belirir
                    AnimatedSize(
                      duration: dur,
                      curve: Curves.easeOut,
                      child: st == _StepState.completed
                          ? Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(Icons.check_rounded,
                                  size: 12, color: textColor),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: dur,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: weight,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                        child: Text(
                          _labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Kişilik Tipi Rozeti ───────────────────────────────────────────────────────

class _PersonalityChip extends StatelessWidget {
  final String name;
  final PersonalityType type;
  final Color color;

  const _PersonalityChip({
    required this.name,
    required this.type,
    required this.color,
  });

  static String _label(PersonalityType t) {
    switch (t) {
      case PersonalityType.entelektuel:   return 'Entelektüel';
      case PersonalityType.sosyalKelebek: return 'Sosyal Kelebek';
      case PersonalityType.sakinRuh:      return 'Sakin Ruh';
      case PersonalityType.maceraperest:  return 'Maceraperest';
      case PersonalityType.gurme:         return 'Gurme';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Text(
            _label(type),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Şehir Silüeti ─────────────────────────────────────────────────────────────

class _CityScapeWidget extends StatelessWidget {
  final Color color;
  const _CityScapeWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CityScapePainter(color: color),
      size: Size.infinite,
    );
  }
}

class _CityScapePainter extends CustomPainter {
  final Color color;
  const _CityScapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final buildingP = Paint()..color = color.withOpacity(0.09);
    final windowP   = Paint()..color = color.withOpacity(0.20);

    const buildings = [
      [0.02, 0.07, 0.38],
      [0.10, 0.05, 0.28],
      [0.16, 0.09, 0.50],
      [0.26, 0.06, 0.35],
      [0.33, 0.10, 0.58],
      [0.44, 0.07, 0.44],
      [0.52, 0.05, 0.32],
      [0.58, 0.09, 0.54],
      [0.68, 0.07, 0.40],
      [0.76, 0.08, 0.48],
      [0.85, 0.07, 0.36],
      [0.93, 0.06, 0.29],
    ];

    final groundY = h * 0.76;

    for (final b in buildings) {
      final bx = w * b[0];
      final bw = w * b[1];
      final bh = h * b[2];
      final rect = Rect.fromLTWH(bx, groundY - bh, bw, bh);
      canvas.drawRect(rect, buildingP);

      final cols = (bw / (w * 0.028)).floor().clamp(1, 3);
      final rows = (bh / (h * 0.095)).floor().clamp(1, 5);
      final wW = bw * 0.22;
      final wH = h * 0.040;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final wx = bx + bw * (c + 0.5) / cols - wW / 2;
          final wy = groundY - bh + bh * (r + 0.8) / (rows + 0.5) - wH / 2;
          canvas.drawRect(Rect.fromLTWH(wx, wy, wW, wH), windowP);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CityScapePainter old) => old.color != color;
}

// ── Nabız Atan Konum Pini ─────────────────────────────────────────────────────

class _PulsingPin extends StatelessWidget {
  final AnimationController pulseCtrl;
  final Color color;
  final bool evenPhase;

  const _PulsingPin({
    required this.pulseCtrl,
    required this.color,
    required this.evenPhase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final raw = evenPhase ? pulseCtrl.value : (1.0 - pulseCtrl.value);
        final scale = 0.72 + raw * 0.35;
        final opacity = (0.42 + raw * 0.42).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.location_on_rounded,
            color: color.withOpacity(opacity),
            size: 20,
          ),
        );
      },
    );
  }
}
