// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  late final AnimationController _progressCtrl; // progress bar dolumu (5 sn)
  late final AnimationController _shimmerCtrl;  // progress bar shimmer
  late final AnimationController _pulseCtrl;    // merkez pin nabzı
  late final AnimationController _walkCtrl;     // karakterlerin ekran boyunca yürüyüşü
  late final AnimationController _pickupCtrl;   // büyüteci yerden alma sekansı

  late final Animation<double> _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _searchStarted    = false;
  bool _popping          = false;
  bool _navigated        = false; // çifte pop koruması (Atla + oto-geçiş yarışı)
  bool _searchDone       = false;
  bool _inSearchMode     = false; // false=intro, true=büyüteçli yürüyüş
  bool _showSkipButton   = false; // %100 olunca gösterilir
  bool _showInterstitial = false; // bu aramada tam ekran reklam gösterilecek mi?
  bool _adDismissed      = true;  // reklam yok ya da kapandı → geçişe izin ver
  int  _phaseIdx       = 0;
  late final DateTime _startTime;
  Timer? _phaseTimer;
  Timer? _introTimer;
  Timer? _simTimer;

  static const _phases = [
    'Konumunuz alınıyor...',
    'Kişiliğinize göre mekanlar aranıyor...',
    'En iyi eşleşmeler seçiliyor...',
    'Son dokunuşlar yapılıyor...',
  ];

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

    // Progress: iki fazlı — takılı görünmemesi için 80%'de hız düşer.
    //   Faz 1: 0 → %80 — 3.5 sn, easeOut (hızlı başlar, yavaşlar)
    //   Faz 2: %80 → %95 — 9 sn, linear (çok yavaş ama daima hareket ediyor)
    //   Arama bitince: %100'e 480 ms'de zıplar
    _progressCtrl = AnimationController(vsync: this, value: 0);
    _progressCtrl
        .animateTo(
          0.80,
          duration: const Duration(milliseconds: 3500),
          curve: Curves.easeOut,
        )
        .then((_) {
      // Faz 1 bitti → arama zaten tamamlandıysa ikinci fazı başlatma
      if (!mounted || _searchDone) return;
      _progressCtrl.animateTo(
        0.95,
        duration: const Duration(milliseconds: 9000),
        curve: Curves.linear,
      );
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

    // Yürüyüş: 12 sn periyot, ileri-geri — waypoint'lerde durup inceleme yapar
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    );

    // Büyüteci alma sekansı: elindeki aksesuarı bırak → çömel → büyüteci
    // yerden kavra → doğrul. Bitince yürüyüş başlar.
    _pickupCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Faz metni döngüsü
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted) return;
      setState(() => _phaseIdx = (_phaseIdx + 1) % _phases.length);
    });

    // 2.5 sn sonra intro → arama moduna geç: önce büyüteci alma sekansı,
    // o bitince yürüyüş controller'ı başlar.
    _introTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _inSearchMode = true);
      _pickupCtrl.forward().whenComplete(() {
        if (mounted) _walkCtrl.repeat(reverse: true);
      });
    });

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
    if (!widget.simulationMode && (kReleaseMode || _kShowAdInDebug)) {
      final isPremium = ref.read(isPremiumProvider);
      AdService.incrementSearchCount().ignore();
      _showInterstitial = AdService.shouldShowAd(isPremium: isPremium);
      if (_showInterstitial) {
        _adDismissed = false; // geçişi kilitle: reklam kapanana dek beklenir
        // Reklamı yükle; yüklenir yüklenmez göster (minimum 800ms bekle).
        final loadStart = DateTime.now();
        AdService.preloadInterstitial(onLoaded: () {
          final elapsed = DateTime.now().difference(loadStart).inMilliseconds;
          final wait = (800 - elapsed).clamp(0, 800);
          Future.delayed(Duration(milliseconds: wait), () {
            if (!mounted) return;
            AdService.showInterstitial(
              onDismissed: () {
                if (!mounted) return;
                setState(() => _adDismissed = true);
                if (_popping && !_navigated) _doNavigate();
              },
            );
          });
        });
      }
      // _showInterstitial = false ise _adDismissed zaten true (geçişi kilitlemez)
    }

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
    _phaseTimer?.cancel();

    // Minimum 6 saniye animasyon süresi garantisi
    final elapsed  = DateTime.now().difference(_startTime).inMilliseconds;
    final waitLeft = math.max(0, 6000 - elapsed);

    Future.delayed(Duration(milliseconds: waitLeft), () {
      if (!mounted) return;
      setState(() => _searchDone = true);

      _progressCtrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOut)
          .then((_) {
        if (!mounted) return;
        // %100 oldu → Animasyonu Atla butonunu göster
        setState(() => _showSkipButton = true);
        // 3 sn sonra otomatik geç (kullanıcı atlamazsa)
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (mounted && _showSkipButton) _doNavigate();
        });
      });
    });
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
    _phaseTimer?.cancel();
    _introTimer?.cancel();
    _simTimer?.cancel();

    Navigator.of(context).pop();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _slideCtrl.dispose();
    _progressCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _walkCtrl.dispose();
    _pickupCtrl.dispose();
    _phaseTimer?.cancel();
    _introTimer?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final me        = ref.watch(currentUserProvider);
    final friend    = ref.watch(selectedFriendProvider);
    final isPremium = ref.watch(isPremiumProvider);
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
              SizedBox(
                height: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  child: Text(
                    _phases[_phaseIdx],
                    key: ValueKey(_phaseIdx),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // ── Kişilik tipi rozetleri (intro sırasında göster, yürüyüş başlayınca kaybolur) ─
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: !_inSearchMode
                    ? Padding(
                        key: const ValueKey('personality_chips'),
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
                      )
                    : const SizedBox(key: ValueKey('personality_chips_hidden'), height: 0),
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
                  inSearchMode: _inSearchMode,
                  slideAnim: _slideAnim,
                  walkCtrl: _walkCtrl,
                  pickupCtrl: _pickupCtrl,
                  pulseCtrl: _pulseCtrl,
                  accentColor: primary,
                ),
              ),

              const Spacer(),

              // ── Banner reklam (her aramada, premium olmayan kullanıcılara) ──
              if (!widget.simulationMode && !isPremium)
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                  child: AdBannerWidget(),
                ),

              // ── Progress bölümü ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) {
                        final pct = (_progressCtrl.value * 100).round();
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
                      animation: Listenable.merge([_progressCtrl, _shimmerCtrl]),
                      builder: (_, __) => _GradientProgressBar(
                        progress: _progressCtrl.value,
                        shimmer: _shimmerCtrl.value,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) => _StepDots(
                        progress: _progressCtrl.value,
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
// Yürüyüş, waypoint tabanlı bir programla ilerler:
//   yürü → pinin yanında dur → çömelip büyüteçle incele → devam et
// walkCtrl.value 0→1→0 repeat(reverse: true) ile:
//   • Kullanıcı: sol kenardan sağa → geri sola → …
//   • Arkadaş:   sağ kenardan sola → geri sağa → …
// Yön değiştiklerinde flipX otomatik değişir (sola giden sola bakar).

/// Yürüyüş programındaki tek bir zaman dilimi.
class _WalkSeg {
  final double t0, t1;   // rawT aralığı
  final double p0, p1;   // pozisyon aralığı (pause'da p0 == p1)
  final bool pause;
  const _WalkSeg(this.t0, this.t1, this.p0, this.p1, {this.pause = false});
}

/// Programın bir anlık örneği: konum + inceleme yoğunluğu (0..1).
/// [anchor] duraklamanın kimliğidir (durulan pozisyon) — durak başına
/// sözde-rastgele varyasyon üretmek için tohum olarak kullanılır.
class _WalkSample {
  final double pos;
  final double inspect;
  final double anchor;
  const _WalkSample(this.pos, this.inspect, [this.anchor = 0.0]);
}

class _SearchStage extends StatelessWidget {
  final dynamic me;
  final dynamic friend;
  final bool isSolo;
  final PersonalityType myType;
  final PersonalityType friendType;
  final bool inSearchMode;
  final Animation<double> slideAnim;
  final AnimationController walkCtrl;
  final AnimationController pickupCtrl;
  final AnimationController pulseCtrl;
  final Color accentColor;

  static const _charSize = 148.0;

  const _SearchStage({
    required this.me,
    required this.friend,
    required this.isSolo,
    required this.myType,
    required this.friendType,
    required this.inSearchMode,
    required this.slideAnim,
    required this.walkCtrl,
    required this.pickupCtrl,
    required this.pulseCtrl,
    required this.accentColor,
  });

  /// Intro ↔ arama modu karakteri: mod değişince 450 ms crossfade —
  /// kişilik pozu (ve painter içi kişilik arka planı) yumuşakça söner,
  /// arama karakteri aynı konumda belirir.
  Widget _characterSwitcher({
    required PersonalityType type,
    required String? gender,
    required bool flip,
    required double inspect,
    required double pickupT,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: inSearchMode
          ? PersonalityCharacterWidget(
              key: const ValueKey('search'),
              type: type, gender: gender,
              size: _charSize, searchMode: true, flipX: flip,
              inspect: inspect, pickup: pickupT)
          : PersonalityCharacterWidget(
              key: const ValueKey('intro'),
              type: type, gender: gender,
              size: _charSize, searchMode: false, flipX: flip,
              // Kişilik arka planı (dağ, kitaplık vb.) çizilmez — dekor
              // en baştan şehir silüeti, geçişte hiçbir dekor kaybolmaz.
              showBackground: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([slideAnim, walkCtrl, pickupCtrl, pulseCtrl]),
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pad = 6.0;
          final lo = pad;
          final hi = w - _charSize - pad;

          final slide = slideAnim.value.clamp(0.0, 1.0);
          final pickupT = pickupCtrl.value;

          // Şehir silüeti EN BAŞTAN sahnede (sayfa girişiyle belirir) —
          // dekor hiç değişmez. Sadece mekan pinleri arama başlarken,
          // büyüteci alma sekansının ilk %60'ında yavaşça belirir.
          final pinT = !inSearchMode
              ? 0.0
              : Curves.easeInOut.transform((pickupT / 0.6).clamp(0.0, 1.0));

          final rawT = walkCtrl.value;
          final su = _sample(rawT, _scheduleUser);   // kullanıcı programı
          final sf = _sample(rawT, _scheduleFriend); // arkadaş programı (farklı)
          final pos = su.pos;
          final inspect = su.inspect;

          final goingForward = walkCtrl.status != AnimationStatus.reverse;

          final userX    = lo + (hi - lo) * su.pos;
          final userFlip = !goingForward;
          final friendX  = hi - (hi - lo) * sf.pos;
          final friendFlip = goingForward;

          // Zıplama pozisyona bağlı → durunca kendiliğinden durur;
          // (1 - inspect) ile de yumuşakça yere basar. Her karakter kendi
          // inceleme durumuna göre yavaşlar/durur.
          final userBobAmp   = 8.0 * (1.0 - su.inspect);
          final friendBobAmp = 8.0 * (1.0 - sf.inspect);

          if (isSolo) {
            const soloPins = [
              (0.10, 46.0, true), (0.28, 54.0, false), (0.46, 44.0, true),
              (0.64, 56.0, false), (0.82, 46.0, true),
            ];
            final soloX = lo + (hi - lo) * pos;
            final soloCenter = soloX + _charSize / 2;
            final soloY = 14.0 + math.sin(pos * math.pi * 8) * userBobAmp;
            return SizedBox(
              width: w, height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: slide,
                    child: _CityScapeWidget(color: accentColor))),
                for (final p in soloPins)
                  Positioned(left: w * p.$1, bottom: p.$2,
                    child: Opacity(
                      opacity: pinT,
                      child: _PulsingPin(
                        pulseCtrl: pulseCtrl, color: accentColor,
                        evenPhase: p.$3,
                        boost: _pinBoost(w * p.$1 + 10, soloCenter, inspect)))),
                Positioned(
                  left: soloX, bottom: soloY,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - slide)),
                    child: Opacity(
                      opacity: slide,
                      child: _characterSwitcher(
                        type: myType, gender: me?.gender as String?,
                        flip: userFlip,
                        inspect: _crouchDepth(su, 0.0),
                        pickupT: pickupT)))),
              ]),
            );
          }

          final userBob   = math.sin(su.pos * math.pi * 8) * userBobAmp;
          final friendBob =
              math.sin(sf.pos * math.pi * 8 + math.pi) * friendBobAmp;

          final dist = (userX - friendX).abs();
          final push = (_charSize * 1.05 - dist).clamp(0.0, _charSize) * 0.46;
          final userBottom   = (22.0 + userBob + push).clamp(8.0, 90.0);
          final friendBottom = (22.0 + friendBob - push).clamp(8.0, 90.0);

          const pins = [
            (0.06, 44.0, true), (0.22, 54.0, false), (0.38, 44.0, true),
            (0.54, 56.0, false), (0.70, 46.0, true), (0.84, 52.0, false),
          ];
          final userCenter   = userX + _charSize / 2;
          final friendCenter = friendX + _charSize / 2;

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
                    opacity: pinT,
                    child: _PulsingPin(
                      pulseCtrl: pulseCtrl, color: accentColor, evenPhase: p.$3,
                      boost: math.max(
                        _pinBoost(w * p.$1 + 10, userCenter, su.inspect),
                        _pinBoost(w * p.$1 + 10, friendCenter, sf.inspect))))),

              Positioned(
                left: userX, bottom: userBottom,
                child: Transform.translate(
                  offset: Offset(-160 * (1 - slide), 0),
                  child: Opacity(
                    opacity: slide,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _characterSwitcher(
                        type: myType, gender: me?.gender as String?,
                        flip: userFlip,
                        inspect: _crouchDepth(su, 0.0),
                        pickupT: pickupT),
                      const SizedBox(height: 3),
                      Text(((me?.name ?? 'Sen') as String).split(' ').first,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
                    ]),
                  ),
                ),
              ),

              Positioned(
                left: friendX, bottom: friendBottom,
                child: Transform.translate(
                  offset: Offset(160 * (1 - slide), 0),
                  child: Opacity(
                    opacity: slide,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _characterSwitcher(
                        type: friendType, gender: friend?.gender as String?,
                        flip: friendFlip,
                        inspect: _crouchDepth(sf, 3.7), // farklı seed
                        pickupT: pickupT),
                      const SizedBox(height: 3),
                      Text(((friend?.name ?? '') as String).split(' ').first,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
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

  // ── Yürüyüş programları ─────────────────────────────────────────────────────
  // yürü(easeInOut) → dur & incele → yürü → dur & incele → …
  // İki karakterin programı bilinçli olarak FARKLI: duraklama zamanları ve
  // noktaları örtüşmez, böylece aynı anda eğilmezler — her biri kendi
  // keşfini yapıyormuş gibi görünür.
  static const _scheduleUser = [
    _WalkSeg(0.00, 0.15, 0.00, 0.24),
    _WalkSeg(0.15, 0.30, 0.24, 0.24, pause: true),
    _WalkSeg(0.30, 0.45, 0.24, 0.52),
    _WalkSeg(0.45, 0.60, 0.52, 0.52, pause: true),
    _WalkSeg(0.60, 0.75, 0.52, 0.80),
    _WalkSeg(0.75, 0.90, 0.80, 0.80, pause: true),
    _WalkSeg(0.90, 1.00, 0.80, 1.00),
  ];

  static const _scheduleFriend = [
    _WalkSeg(0.00, 0.06, 0.00, 0.10),
    _WalkSeg(0.06, 0.17, 0.10, 0.10, pause: true),
    _WalkSeg(0.17, 0.32, 0.10, 0.42),
    _WalkSeg(0.32, 0.44, 0.42, 0.42, pause: true),
    _WalkSeg(0.44, 0.62, 0.42, 0.72),
    _WalkSeg(0.62, 0.74, 0.72, 0.72, pause: true),
    _WalkSeg(0.74, 1.00, 0.72, 1.00),
  ];

  /// Durak kimliğinden 0..1 arası deterministik "rastgele" değer üretir.
  /// Aynı durakta aynı değeri verir (titreme olmaz), duraklar arasında değişir.
  static double _rand01(double seed) {
    final v = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// rawT (0..1) → konum + inceleme yoğunluğu.
  /// Pause dilimlerinde konum sabittir; inspect yumuşakça 0→1→0 gider,
  /// böylece eğilme/pin parlaması ani değil akıcı olur.
  static _WalkSample _sample(double rawT, List<_WalkSeg> schedule) {
    for (final seg in schedule) {
      if (rawT <= seg.t1 || identical(seg, schedule.last)) {
        final local = ((rawT - seg.t0) / (seg.t1 - seg.t0)).clamp(0.0, 1.0);
        if (seg.pause) {
          final double inspect;
          if (local < 0.25) {
            inspect = Curves.easeOut.transform(local / 0.25);
          } else if (local > 0.75) {
            inspect = Curves.easeOut.transform((1.0 - local) / 0.25);
          } else {
            inspect = 1.0;
          }
          return _WalkSample(seg.p0, inspect, seg.t0 + seg.p0);
        }
        final eased = Curves.easeInOut.transform(local);
        return _WalkSample(seg.p0 + (seg.p1 - seg.p0) * eased, 0.0);
      }
    }
    return const _WalkSample(1.0, 0.0);
  }

  /// Karakter merkezi ile pin arasındaki yakınlığa göre parlama katsayısı.
  static double _pinBoost(double pinCenterX, double charCenterX, double inspect) {
    if (inspect <= 0.001) return 0.0;
    final dx = (pinCenterX - charCenterX).abs();
    final proximity = (1.0 - dx / 70.0).clamp(0.0, 1.0);
    return inspect * proximity;
  }

  /// Çömelme derinliği: temel inspect değeri durak başına sözde-rastgele
  /// ölçeklenir (0.70–1.0) — her incelemede birebir aynı poz tekrarlanmaz.
  /// Gerçek çömelme pozunu PersonalityCharacterWidget kendi painter'ında
  /// çizer (dizler bükülür, gövde öne eğilir, büyüteç yere doğrultulur).
  static double _crouchDepth(_WalkSample sample, double seed) {
    if (sample.inspect <= 0.001) return 0.0;
    final scale = 0.70 + 0.30 * _rand01(sample.anchor * 7.31 + seed);
    return (sample.inspect * scale).clamp(0.0, 1.0);
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

  /// 0..1 — yakındaki karakter incelerken pin büyür ve parlar.
  final double boost;

  const _PulsingPin({
    required this.pulseCtrl,
    required this.color,
    required this.evenPhase,
    this.boost = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final raw = evenPhase ? pulseCtrl.value : (1.0 - pulseCtrl.value);
        final scale = (0.72 + raw * 0.35) * (1.0 + 0.55 * boost);
        final opacity = (0.42 + raw * 0.42 + 0.30 * boost).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.location_on_rounded,
            color: color.withOpacity(opacity),
            size: 20,
            shadows: boost > 0.05
                ? [Shadow(color: color.withOpacity(0.6 * boost), blurRadius: 12)]
                : null,
          ),
        );
      },
    );
  }
}
