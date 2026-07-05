// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_character.dart';

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

  late final Animation<double> _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _searchStarted  = false;
  bool _popping        = false;
  bool _searchDone     = false;
  bool _inSearchMode   = false; // false=intro, true=büyüteçli yürüyüş
  bool _showSkipButton = false; // %100 olunca gösterilir
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

    // Progress: 5 sn'de %88'e dolar; arama bitince %100'e zıplar
    _progressCtrl = AnimationController(vsync: this, value: 0);
    _progressCtrl.animateTo(
      0.88,
      duration: const Duration(milliseconds: 5000),
      curve: Curves.easeOut,
    );

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

    // Yürüyüş: 3.5 sn periyot, ileri-geri
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );

    // _walkCtrl animasyonu _WalkingStage içindeki kendi AnimatedBuilder'ı ile
    // yönetilir — burada merge etmeye gerek yok.

    // Faz metni döngüsü
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted) return;
      setState(() => _phaseIdx = (_phaseIdx + 1) % _phases.length);
    });

    // 2.5 sn sonra intro → yürüyüş moduna geç + walk controller'ı başlat
    _introTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _inSearchMode = true);
      _walkCtrl.repeat(reverse: true);
    });

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
    if (!mounted) return;
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
    _phaseTimer?.cancel();
    _introTimer?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final me     = ref.watch(currentUserProvider);
    final friend = ref.watch(selectedFriendProvider);
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
                              name: (me?.name as String? ?? 'Sen').split(' ').first,
                              type: myType,
                              color: primary,
                            ),
                            if (!isSolo) ...[
                              const SizedBox(width: 20),
                              _PersonalityChip(
                                name: (friend?.name as String? ?? '').split(' ').first,
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
              // Intro sahne için slide animasyonunu izliyoruz.
              // Walk sahne kendi AnimatedBuilder'ını içeriyor.
              AnimatedBuilder(
                animation: _slideAnim,
                builder: (_, __) => SizedBox(
                  height: 240,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: _inSearchMode
                        ? _WalkingStage(
                            key: const ValueKey('walk'),
                            me: me,
                            friend: friend,
                            isSolo: isSolo,
                            myType: myType,
                            friendType: friendType,
                            walkCtrl: _walkCtrl,
                            pulseCtrl: _pulseCtrl,
                            accentColor: primary,
                          )
                        : _IntroStage(
                            key: const ValueKey('intro'),
                            me: me,
                            friend: friend,
                            isSolo: isSolo,
                            myType: myType,
                            friendType: friendType,
                            slideAnim: _slideAnim,
                            pulseCtrl: _pulseCtrl,
                            accentColor: primary,
                          ),
                  ),
                ),
              ),

              const Spacer(),

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

// ── Faz 1: Intro Sahne ────────────────────────────────────────────────────────
//
// Karakterler sabit pozisyonlarında kendi kişilik animasyonlarını oynar.
// Maceraperest iner, gurme tabağıyla durur vb.

class _IntroStage extends StatelessWidget {
  final dynamic me;
  final dynamic friend;
  final bool isSolo;
  final PersonalityType myType;
  final PersonalityType friendType;
  final Animation<double> slideAnim;
  final AnimationController pulseCtrl;
  final Color accentColor;

  const _IntroStage({
    super.key,
    required this.me,
    required this.friend,
    required this.isSolo,
    required this.myType,
    required this.friendType,
    required this.slideAnim,
    required this.pulseCtrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final slide = slideAnim.value.clamp(0.0, 1.0);

    if (isSolo) {
      return Center(
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - slide)),
          child: Opacity(
            opacity: slide,
            child: PersonalityCharacterWidget(
              type: myType,
              gender: me?.gender as String?,
              size: 200,
              searchMode: false,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Kullanıcı — soldan kayar
        Transform.translate(
          offset: Offset(-160 * (1 - slide), 0),
          child: Opacity(
            opacity: slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonalityCharacterWidget(
                  type: myType,
                  gender: me?.gender as String?,
                  size: 155,
                  searchMode: false,
                ),
                const SizedBox(height: 4),
                Text(
                  ((me?.name ?? 'Sen') as String).split(' ').first,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Merkez: nabız atan pin ikonu
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) {
            final scale = 0.80 + pulseCtrl.value * 0.32;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor
                          .withOpacity(0.28 + pulseCtrl.value * 0.18),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(Icons.location_on_rounded,
                    color: accentColor, size: 24),
              ),
            );
          },
        ),

        // Arkadaş — sağdan kayar, intro modda sola bakacak şekilde flipX
        Transform.translate(
          offset: Offset(160 * (1 - slide), 0),
          child: Opacity(
            opacity: slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonalityCharacterWidget(
                  type: friendType,
                  gender: friend?.gender as String?,
                  size: 155,
                  searchMode: false,
                  flipX: true,
                ),
                const SizedBox(height: 4),
                Text(
                  ((friend?.name ?? '') as String).split(' ').first,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Faz 2: Yürüyüş Sahne ────────────────────────────────────────────────────
//
// Karakterler Stack içinde Positioned ile ekranın bir ucundan diğerine
// gerçekten yürür. walkCtrl.value 0→1→0 repeat(reverse: true) ile:
//   • Kullanıcı: sol kenardan sağa → geri sola → …
//   • Arkadaş:   sağ kenardan sola → geri sağa → …
// Yön değiştiklerinde flipX otomatik değişir (sola giden sola bakar).

class _WalkingStage extends StatelessWidget {
  final dynamic me;
  final dynamic friend;
  final bool isSolo;
  final PersonalityType myType;
  final PersonalityType friendType;
  final AnimationController walkCtrl;
  final AnimationController pulseCtrl;
  final Color accentColor;

  static const _charSize = 148.0;

  const _WalkingStage({
    super.key,
    required this.me,
    required this.friend,
    required this.isSolo,
    required this.myType,
    required this.friendType,
    required this.walkCtrl,
    required this.pulseCtrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: walkCtrl,
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pad = 6.0;
          final lo = pad;
          final hi = w - _charSize - pad;
          final rawT = walkCtrl.value;
          final pos = _remapWalkT(rawT);

          final goingForward = walkCtrl.status != AnimationStatus.reverse;

          final userX    = lo + (hi - lo) * pos;
          final userFlip = !goingForward;
          final friendX  = hi - (hi - lo) * pos;
          final friendFlip = goingForward;

          if (isSolo) {
            final soloX = lo + (hi - lo) * (0.5 + 0.4 * math.sin(rawT * math.pi));
            final soloY = 14.0 + math.sin(rawT * math.pi * 6) * 8.0;
            return SizedBox(
              width: w, height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: _CityScapeWidget(color: accentColor)),
                Positioned(left: w * 0.10, bottom: 46,
                  child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
                Positioned(left: w * 0.28, bottom: 54,
                  child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: false)),
                Positioned(left: w * 0.46, bottom: 44,
                  child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
                Positioned(left: w * 0.64, bottom: 56,
                  child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: false)),
                Positioned(left: w * 0.82, bottom: 46,
                  child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
                Positioned(
                  left: soloX, bottom: soloY,
                  child: PersonalityCharacterWidget(
                    type: myType, gender: me?.gender as String?,
                    size: _charSize, searchMode: true, flipX: userFlip)),
              ]),
            );
          }

          final userBob   = math.sin(pos * math.pi * 6) * 9.0;
          final friendBob = math.sin(pos * math.pi * 6 + math.pi) * 9.0;

          final dist = (userX - friendX).abs();
          final push = (_charSize * 1.05 - dist).clamp(0.0, _charSize) * 0.46;
          final userBottom   = (22.0 + userBob  + push).clamp(8.0, 90.0);
          final friendBottom = (22.0 + friendBob - push).clamp(8.0, 90.0);

          return SizedBox(
            width: w, height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: _CityScapeWidget(color: accentColor)),

              Positioned(left: w * 0.06, bottom: 44,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
              Positioned(left: w * 0.22, bottom: 54,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: false)),
              Positioned(left: w * 0.38, bottom: 44,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
              Positioned(left: w * 0.54, bottom: 56,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: false)),
              Positioned(left: w * 0.70, bottom: 46,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: true)),
              Positioned(left: w * 0.84, bottom: 52,
                child: _PulsingPin(pulseCtrl: pulseCtrl, color: accentColor, evenPhase: false)),

              Positioned(
                left: userX, bottom: userBottom,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PersonalityCharacterWidget(
                    type: myType, gender: me?.gender as String?,
                    size: _charSize, searchMode: true, flipX: userFlip),
                  const SizedBox(height: 3),
                  Text(((me?.name ?? 'Sen') as String).split(' ').first,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
                ]),
              ),

              Positioned(
                left: friendX, bottom: friendBottom,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PersonalityCharacterWidget(
                    type: friendType, gender: friend?.gender as String?,
                    size: _charSize, searchMode: true, flipX: friendFlip),
                  const SizedBox(height: 3),
                  Text(((friend?.name ?? '') as String).split(' ').first,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  static double _remapWalkT(double rawT) {
    if (rawT < 0.10) return rawT * 1.40;
    if (rawT < 0.22) return 0.14 + (rawT - 0.10) * 0.500;
    if (rawT < 0.42) return 0.20 + (rawT - 0.22) * 1.300;
    if (rawT < 0.57) return 0.46 + (rawT - 0.42) * 0.533;
    if (rawT < 0.75) return 0.54 + (rawT - 0.57) * 1.389;
    if (rawT < 0.88) return 0.79 + (rawT - 0.75) * 0.462;
    return (0.85 + (rawT - 0.88) * 1.250).clamp(0.0, 1.0);
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
        final opacity = 0.42 + raw * 0.42;
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
