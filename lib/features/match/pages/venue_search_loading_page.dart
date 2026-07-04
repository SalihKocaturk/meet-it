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
