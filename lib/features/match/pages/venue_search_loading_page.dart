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
  late final AnimationController _shimmerCtrl;  // progress bar shimmer
  late final AnimationController _pulseCtrl;    // merkez pin nabzı
  late final AnimationController _celebrateCtrl; // %100: beşlik + sevinç pozu

  late final Animation<double> _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _searchStarted    = false;
  bool _popping          = false;
  bool _navigated        = false; // çifte pop koruması (Atla + oto-geçiş yarışı)
  bool _searchDone       = false;
  bool _showSkipButton   = false; // %100 olunca gösterilir
  bool _showInterstitial = false; // bu aramada tam ekran reklam gösterilecek mi?
  bool _adDismissed      = true;  // reklam yok ya da kapandı → geçişe izin ver
  bool _progressFull     = false; // görsel ilerleme %100'e ulaştı mı
  bool _rawDone          = false; // ham ilerleme 1.0'a ulaştı (arama bitti)
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

  /// visualProgress %100'e vardığında: atla butonu, kutlama, oto-geçiş.
  void _onVisualProgress() {
    if (!_rawDone || _progressFull || _visualCtrl.value < 0.995) return;
    // Bayrak ÖNCE set edilir: value ataması dinleyiciyi yeniden tetikler.
    _progressFull = true;
    _visualCtrl.value = 1.0;
    setState(() => _showSkipButton = true);
    _maybeCelebrate();
    // 3 sn sonra otomatik geç (kullanıcı atlamazsa)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && _showSkipButton) _doNavigate();
    });
  }

  /// Karakterler ortada buluşmuş VE ilerleme %100 ise sevinç sahnesini oynat.
  void _maybeCelebrate() {
    if (!mounted || !_progressFull) return;
    if (_celebrateCtrl.isAnimating || _celebrateCtrl.value > 0) return;
    _celebrateCtrl.forward();
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
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrateCtrl.dispose();
    _simTimer?.cancel();
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
                  progressCtrl: _visualCtrl,
                  searchDone: _searchDone,
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
                    AnimatedBuilder(
                      animation: _visualCtrl,
                      builder: (_, __) {
                        final pct = (_visualCtrl.value * 100).round();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _searchDone
                                    ? 'Mekanlar bulundu!'
                                    : widget.simulationMode
                                        ? 'Simülasyon çalışıyor...'
                                        : 'Aranıyor...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              Text(
                                '%$pct',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: Listenable.merge([_visualCtrl, _shimmerCtrl]),
                      builder: (_, __) => _GradientProgressBar(
                        progress: _visualCtrl.value,
                        shimmer: _shimmerCtrl.value,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _visualCtrl,
                      builder: (_, __) => _StepDots(
                        progress: _visualCtrl.value,
                        accentColor: primary,
                      ),
                    ),

                    // ── Animasyonu Atla butonu (%100 olunca belirir) ──────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _showSkipButton
                          ? Padding(
                              key: const ValueKey('skip_btn'),
                              padding: const EdgeInsets.only(top: 20),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: _doNavigate,
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
                            )
                          : const SizedBox(key: ValueKey('skip_btn_hidden'),
                              height: 0),
                    ),
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
// Koreografi (tamamı yumuşatılmış visualProgress'e bağlı):
//   1) %0–15 : karakterler köşelerde kişilik pozunda.
//   2) %15–40: elindeki aksesuar çok yavaşça solar (opacity 1→0), büyüteç
//      easeInOut ile belirir. Karakter dimdik durur — sıfır dikey hareket.
//   3) %20–92: dik gövdeyle, yavaş adımlarla tek seferde ortaya yürürler.
//   4) %100  : ortanın ±38 px'inde, aynı zemin hizasında beşlik çakarlar.
//      Parıltı / konfeti / partikül yok.

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
  final AnimationController progressCtrl;
  final bool searchDone;
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
    required this.progressCtrl,
    required this.searchDone,
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
        slideAnim, progressCtrl, celebrateCtrl, pulseCtrl,
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
          final prog = progressCtrl.value;
          final celebrate = celebrateCtrl.value;

          // Aksesuar → büyüteç geçişi %15–%40 aralığına yayılır (≈2 sn):
          // aksesuar elde yavaşça solar, büyüteç belirir. Karakter dik durur.
          final inSearchMode = prog >= 0.15;
          final pickupT = ((prog - 0.15) / 0.25).clamp(0.0, 1.0);

          // Şehir silüeti en baştan sahnede; mekan pinleri arama başlarken,
          // büyüteci alma sekansının ilk %60'ında yavaşça belirir.
          final pinT = !inSearchMode
              ? 0.0
              : Curves.easeInOut.transform((pickupT / 0.6).clamp(0.0, 1.0));

          // Yaklaşma %20'de başlar, %92'de ortaya varılır — yürüyüş geniş
          // bir aralığa yayıldığı için adımlar yavaş ve sakin.
          final a = ((prog - 0.20) / 0.72).clamp(0.0, 1.0);
          final su0 = _sample(a);
          final sf0 = _sample(a);
          // Arama sürerken ilerleme çok yavaşladığında (%90+) adımlar da
          // kısalır — yerinde sayar gibi görünmesin.
          final creep = (!searchDone && prog >= 0.90) ? 0.35 : 1.0;
          final suWalk = su0.walk * creep;
          final sfWalk = sf0.walk * creep;

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
  // Duraklama / çömelme yok: karakterler dik gövdeyle tek seferde ortaya
  // yürür. Konum easeInOutCubic; adım yoğunluğu hızla orantılı (başta ve
  // sonda bacaklar yavaşlayarak durur).
  static _WalkSample _sample(double t) {
    final local = t.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(local);
    final walk = math.sqrt(math.sin(math.pi * local).clamp(0.0, 1.0));
    return _WalkSample(eased, walk);
  }
}

// ── Gradient Progress Bar ─────────────────────────────────────────────────────

class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final double shimmer;
  final Color  color;

  const _GradientProgressBar({
    required this.progress,
    required this.shimmer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(
        painter: _ProgressPainter(
          progress: progress,
          shimmer: shimmer,
          color: color,
        ),
        size: const Size(double.infinity, 20),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final double shimmer;
  final Color  color;

  const _ProgressPainter({
    required this.progress,
    required this.shimmer,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(r)),
      Paint()..color = color.withOpacity(0.13),
    );

    if (progress <= 0.005) return;

    final fillW    = size.width * progress.clamp(0.0, 1.0);
    final fillRect = Rect.fromLTWH(0, 0, fillW, size.height);
    final fillRRect = RRect.fromRectAndRadius(fillRect, Radius.circular(r));

    canvas.drawRRect(
      fillRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color,
            Color.lerp(color, Colors.white, 0.35)!,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.save();
    canvas.clipRRect(fillRRect);
    final shimW = size.width * 0.38;
    final shimX = -shimW + shimmer * (size.width + shimW);
    canvas.drawRect(
      Rect.fromLTWH(shimX, 0, shimW, size.height),
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.30),
          Colors.white.withOpacity(0),
        ]).createShader(Rect.fromLTWH(shimX, 0, shimW, size.height)),
    );
    canvas.restore();

    if (progress > 0.02 && progress < 0.998) {
      canvas.drawCircle(
        Offset(fillW, size.height / 2),
        size.height * 0.62,
        Paint()
          ..color = color.withOpacity(0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(fillW, size.height / 2),
        size.height * 0.26,
        Paint()..color = Colors.white.withOpacity(0.80),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) =>
      old.progress != progress || old.shimmer != shimmer;
}

// ── Adım Göstergesi ───────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final double progress;
  final Color  accentColor;

  const _StepDots({required this.progress, required this.accentColor});

  static const _labels     = ['Konum', 'Mekanlar', 'Filtreleme', 'Hazır'];
  static const _thresholds = [0.20, 0.52, 0.78, 1.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_labels.length, (i) {
        final done   = progress >= _thresholds[i];
        final active = !done && (i == 0 || progress >= _thresholds[i - 1]);
        final col    = done
            ? accentColor
            : active
                ? accentColor.withOpacity(0.48)
                : Colors.grey.withOpacity(0.22);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOut,
              width: done ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    (done || active) ? FontWeight.w700 : FontWeight.w400,
                color: col,
              ),
              child: Text(_labels[i]),
            ),
          ],
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
