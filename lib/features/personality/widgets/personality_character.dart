// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Cinsiyet Enum ─────────────────────────────────────────────────────────────

enum CharacterGender { male, female, neutral }

CharacterGender genderFromString(String? raw) {
  final g = (raw ?? '').toLowerCase();
  if (g.contains('kadın') || g.contains('female') || g.contains('kadin')) {
    return CharacterGender.female;
  }
  if (g.contains('erkek') || g.contains('male')) {
    return CharacterGender.male;
  }
  return CharacterGender.neutral;
}

// ── Ana Widget ────────────────────────────────────────────────────────────────

/// Kişilik tipine ve cinsiyete göre animasyonlu karakter illüstrasyonu.
///
/// `type`   → hangi kişilik tipinin çizileceğini belirler (poz, aksesuar, arka plan)
/// `gender` → saç stili farklılaştırır (erkek: kısa, kadın: uzun, diğer: nötr)
/// `size`   → widget genişlik ve yüksekliği (kare)
class PersonalityCharacterWidget extends StatefulWidget {
  final PersonalityType type;
  final String? gender;
  final double size;

  /// `true` → karakter yürüyerek büyüteçle arama yapar (loading ekranı için).
  /// `false` → normal kişilik analizi animasyonu (varsayılan).
  final bool searchMode;

  /// `true` → karakter yatay olarak aynılanır (sağdan gelen arkadaş figürü
  /// için). Loading sayfasında sağdaki karakter sola bakacak şekilde çizilir.
  final bool flipX;

  /// 0..1 — çömelip inceleme pozu (sadece searchMode'da anlamlı).
  /// 0 = normal yürüyüş; 1 = tam çömelmiş: dizler bükük, gövde öne eğik,
  /// büyüteç yere doğrultulmuş. Ara değerler pozlar arası akıcı geçiştir.
  final double inspect;

  /// 0..1 — arama moduna giriş sekansı (sadece searchMode'da anlamlı).
  /// 0→1 boyunca karakter elindeki tip aksesuarını (kitap, kupa vb.) yere
  /// bırakır, çömelip yerdeki büyüteci kavrar ve doğrulur. 1 = sekans bitti,
  /// büyüteç elde (varsayılan — normal arama pozu).
  final double pickup;

  /// `false` → kişilik tipine özgü arka plan öğeleri (dağlar, kitaplık,
  /// bitkiler) çizilmez; karakter sade zeminde duruşunu/girişini yapar.
  /// Loading sahnesinde dekor sabit kalsın diye kullanılır.
  final bool showBackground;

  /// 0..1 — yürüyüş yoğunluğu (sadece searchMode). 1 = adım atıyor
  /// (bacaklar, kol salınımı, adım sekmesi), 0 = yerinde duruyor.
  final double walkAmount;

  /// 0..1 — sevinç pozu (sadece searchMode). Mekanlar bulununca büyüteç
  /// söner, iki kol havaya kalkar, karakter hafifçe zıplar.
  final double celebrate;

  /// Sevinçte iç kol (karşıdaki karaktere bakan kol) ortada beşlik çakar;
  /// false ise iki kol da havaya kalkar (tek başına arama).
  final bool highFive;

  const PersonalityCharacterWidget({
    super.key,
    required this.type,
    this.gender,
    this.size = 220,
    this.searchMode = false,
    this.flipX = false,
    this.inspect = 0.0,
    this.pickup = 1.0,
    this.showBackground = true,
    this.walkAmount = 1.0,
    this.celebrate = 0.0,
    this.highFive = false,
  });

  @override
  State<PersonalityCharacterWidget> createState() =>
      _PersonalityCharacterWidgetState();
}

class _PersonalityCharacterWidgetState extends State<PersonalityCharacterWidget>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _landed = false; // maceraperest: iniş bitti mi?

  /// Sürekli akan zaman (sn) — nefes, göz kırpma, buhar, sarkaç gibi
  /// döngüleri ana animasyondan bağımsız ve kesintisiz sürdürür.
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  /// Sahneye giriş (easeOutBack ile büyüyerek belirme). Arama modunda yok.
  late final AnimationController _enterCtrl;

  /// Örnek başına faz kayması: yan yana iki karakter aynı anda göz
  /// kırpmasın / aynı anda nefes almasın.
  final double _seed = math.Random().nextDouble() * 10;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.searchMode) {
      _enterCtrl.value = 1.0;
    } else {
      _enterCtrl.forward();
    }
    if (widget.type == PersonalityType.maceraperest && !widget.searchMode) {
      // Tek seferlik paraşütle iniş: 5 saniye, yavaşlayarak iner (easeOut)
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5),
      )..forward();
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
      _ctrl.addStatusListener(_onDescentComplete);
    } else {
      // searchMode'da daha canlı: 1400ms — normal modda: 2600ms
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.searchMode ? 1400 : 2600),
      )..repeat(reverse: true);
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    }
  }

  /// Paraşüt inişi tamamlanınca hafif sallanma animasyonuna geç.
  /// Aynı controller'ı reuse eder — dispose timing problemi olmaz.
  void _onDescentComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _ctrl.duration = const Duration(milliseconds: 2600);
    _ctrl.reset(); // 0'dan başlat
    setState(() {
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
      _landed = true;
    });
    _ctrl.repeat(); // reverse olmadan — tam sin dalgası için
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _enterCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  static Color _colorFor(PersonalityType type) {
    switch (type) {
      case PersonalityType.sosyalKelebek:  return const Color(0xFFFF6B6B);
      case PersonalityType.sakinRuh:       return const Color(0xFF4ECDC4);
      case PersonalityType.maceraperest:   return const Color(0xFF45B7D1);
      case PersonalityType.entelektuel:    return const Color(0xFF96CEB4);
      case PersonalityType.gurme:          return const Color(0xFFFFD93D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorFor(widget.type);
    final charGender = genderFromString(widget.gender);

    return AnimatedBuilder(
      animation: Listenable.merge([_anim, _time, _enterCtrl]),
      builder: (context, _) {
        Widget charWidget = Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                typeColor.withOpacity(0.25),
                typeColor.withOpacity(0.04),
              ],
              stops: const [0.35, 1.0],
            ),
          ),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CharacterPainter(
              type: widget.type,
              gender: charGender,
              anim: _anim.value,
              typeColor: typeColor,
              landed: _landed,
              searchMode: widget.searchMode,
              inspect: widget.inspect.clamp(0.0, 1.0),
              pickup: widget.pickup.clamp(0.0, 1.0),
              showBackground: widget.showBackground,
              time: _time.value,
              seed: _seed,
              walkAmount: widget.walkAmount.clamp(0.0, 1.0),
              celebrate: widget.celebrate.clamp(0.0, 1.0),
              highFive: widget.highFive,
            ),
          ),
        );
        // Sahneye giriş: easeOutBack ile hafif taşarak büyür.
        final e = _enterCtrl.value;
        if (e < 1.0) {
          charWidget = Opacity(
            opacity: Curves.easeOut.transform(e),
            child: Transform.scale(
              scale: 0.6 + 0.4 * Curves.easeOutBack.transform(e),
              child: charWidget,
            ),
          );
        }
        // flipX: sağdan gelen karakteri (arkadaş) sola bakacak şekilde aynıla
        if (widget.flipX) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: charWidget,
          );
        }
        return charWidget;
      },
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _CharacterPainter extends CustomPainter {
  final PersonalityType type;
  final CharacterGender gender;
  final double anim; // 0.0 → 1.0 (sinüzoid, Curves.easeInOut)
  final Color typeColor;
  final bool landed;     // maceraperest: iniş tamamlandı mı?
  final bool searchMode; // tüm tipler: yürüyerek büyüteçle arama
  final double inspect;  // 0..1: çömelip inceleme pozu (searchMode)
  final double pickup;   // 0..1: büyüteci yerden alma sekansı (searchMode)
  final bool showBackground; // kişilik arka planı (dağ, kitaplık vb.) çizilsin mi
  final double time;       // sürekli zaman (sn) — nefes, kırpma, buhar vb.
  final double seed;       // örnek başına faz kayması
  final double walkAmount; // 0..1: adım atma yoğunluğu (searchMode)
  final double celebrate;  // 0..1: sevinç pozu (searchMode)
  final bool highFive;     // sevinçte iç kolla beşlik

  _CharacterPainter({
    required this.type,
    required this.gender,
    required this.anim,
    required this.typeColor,
    this.landed = false,
    this.searchMode = false,
    this.inspect = 0.0,
    this.pickup = 1.0,
    this.showBackground = true,
    this.time = 0.0,
    this.seed = 0.0,
    this.walkAmount = 1.0,
    this.celebrate = 0.0,
    this.highFive = false,
  });

  // ── Paraşüt geometrisi (maceraperest) ─────────────────────────────────────
  // Kubbe tamamen dairesel çerçevenin içinde kalacak şekilde ayarlandı
  // (eskiden tepe y=-0.03'teydi → üstten kesiliyordu). Tepe artık y≈0.07.
  static const _domeCY = 0.270; // kubbenin alt merkezi (ip bağlantı hizası)
  static const _domeR  = 0.200; // yarıçap

  // ── Zaman tabanlı yardımcılar ─────────────────────────────────────────────

  /// Yürüyüş adım fazı (radyan) — tam adım döngüsü 0.8 sn.
  double get _walkPhase => time * 2 * math.pi / 0.8;

  /// Paraşüt sarkacı (radyan): iniş boyunca söner, yere değince 0.
  double get _parachuteSwing =>
      (type == PersonalityType.maceraperest && !landed && !searchMode)
          ? 0.09 *
              math.sin(2 * math.pi * time / 2.4) *
              math.sqrt((1 - anim).clamp(0.0, 1.0))
          : 0.0;

  /// Gurme: çatal sallarken kafa keyifle sağa-sola.
  double get _headTilt => (type == PersonalityType.gurme && !searchMode)
      ? 0.07 * math.sin(2 * math.pi * time / 1.3 + 0.7)
      : 0.0;

  /// Entelektüel: kitap yığınının ağırlığıyla hafif sağa-sola eğilme.
  double get _bookTilt => (type == PersonalityType.entelektuel && !searchMode)
      ? 0.045 * math.sin(2 * math.pi * time / 2.6)
      : 0.0;

  /// Göz açıklığı (1 = açık, 0 = kapalı). 3.5–4 sn'de bir 150 ms kırpma.
  double get _eyeOpen {
    final period = 3.5 + 0.5 * (seed - seed.floorToDouble());
    final ph = (time + seed) % period;
    if (ph >= 0.15) return 1.0;
    return 1.0 - math.sin(math.pi * ph / 0.15);
  }

  bool get _gurmeAnim => type == PersonalityType.gurme && !searchMode;

  /// Gurme döngüsü (0..1): tabak kalkar → lokma havaya fırlar → geri düşer.
  double get _gurmePh => ((time + seed) % 2.6) / 2.6;
  double get _plateLift {
    if (!_gurmeAnim) return 0.0;
    final ph = _gurmePh;
    return ph < 0.30 ? math.sin(math.pi * ph / 0.30) : 0.0;
  }

  /// Havadaki lokmanın uçuş ilerlemesi (0..1), uçmuyorsa null.
  double? get _morselFlight {
    if (!_gurmeAnim) return null;
    final ph = _gurmePh;
    if (ph < 0.15 || ph > 0.62) return null;
    return (ph - 0.15) / 0.47;
  }

  double get _forkWave =>
      _gurmeAnim ? math.sin(2 * math.pi * time / 1.3) : 0.0;

  static Offset _rotAround(Offset p, Offset c, double a) {
    if (a == 0) return p;
    final dx = p.dx - c.dx, dy = p.dy - c.dy;
    return Offset(
      c.dx + dx * math.cos(a) - dy * math.sin(a),
      c.dy + dx * math.sin(a) + dy * math.cos(a),
    );
  }

  /// Arama modunda büyüteç tutan sağ el — kol, büyüteç ve alma sekansı
  /// aynı noktayı kullansın diye tek yerde hesaplanır.
  Offset _searchRightHand(double s) {
    final still = 1 - _stillAmt;
    final swing = math.sin(_walkPhase) * s * 0.022 * walkAmount * still;
    final reach = _pickingUp ? math.sin(pickup * math.pi) : 0.0;
    var hand = Offset.lerp(
      Offset(s * 0.620, s * 0.432 - swing * 0.35),
      Offset(s * 0.640, s * 0.590),
      reach,
    )!;
    if (!_pickingUp) {
      // Etrafı inceliyormuş gibi küçük daireler
      final w = time * 2 * math.pi / 1.6;
      final k = s * 0.010 * (1 - celebrate);
      hand = hand.translate(math.cos(w) * k, math.sin(w) * k);
    }
    if (celebrate > 0) {
      final Offset target;
      if (highFive) {
        // Beşlik: iç el sahne ortasına (karakter merkezinden +38 px →
        // 148 px'lik karakterde x≈0.757), baş hizasına uzanır. Karşıdaki
        // karakter aynalandığı için iki el tam ortada buluşur.
        target = Offset(s * 0.757, s * 0.330);
      } else {
        final bounce =
            math.sin(time * 2 * math.pi / 0.7) * s * 0.02 * celebrate;
        target = Offset(s * 0.768, s * 0.385 - bounce);
      }
      hand = Offset.lerp(hand, target, Curves.easeOutBack.transform(celebrate))!;
    }
    return hand;
  }

  // ── Çömelme pozu sabitleri ─────────────────────────────────────────────────
  static const _crouchFwd  = 0.030; // öne kayma (s oranı)
  static const _crouchDrop = 0.095; // aşağı çökme (s oranı)
  static const _crouchRot  = 0.32;  // kalça pivotundan öne eğilme (radyan)

  /// Büyüteci yerden alma sekansı sürüyor mu?
  bool get _pickingUp => searchMode && pickup < 1.0;

  /// Hareketsizlik (0..1): salınım/sekme/iz efektlerini söndürür.
  /// İnceleme ve alma sekansı boyunca karakter yerinde durur.
  double get _stillAmt =>
      searchMode ? (_pickingUp ? 1.0 : inspect) : 0.0;

  /// Çömelme miktarı (0..1): inceleme VEYA alma sekansının çömelme fazı.
  double get _crouchAmt => searchMode
      ? math.max(inspect, _pickingUp ? math.sin(pickup * math.pi) : 0.0)
      : 0.0;

  /// Çömelme dönüşümünü bir noktaya uygular — üst gövde grubunun canvas
  /// transform'uyla birebir aynı matematik (grup dışından senkron çizim için).
  Offset _crouchXform(Offset p, double s) {
    final c = _crouchAmt;
    if (c <= 0.001) return p;
    final th = _crouchRot * c;
    final px = s * 0.5, py = s * 0.78;
    final rx = p.dx - px, ry = p.dy - py;
    return Offset(
      px + rx * math.cos(th) - ry * math.sin(th) + s * _crouchFwd * c,
      py + rx * math.sin(th) + ry * math.cos(th) + s * _crouchDrop * c,
    );
  }

  // ── Sabit renkler ──────────────────────────────────────────────────────────

  static const _skin     = Color(0xFFFFCBA4);
  static const _hairDark = Color(0xFF3B2012);
  // Kadın saçı: koyu arka planda kaybolmasın diye daha sıcak/parlak kestane
  static const _hairWarm = Color(0xFF8B4A2B);
  static const _hairRim  = Color(0xFFF2C29A); // saç dış kenarı ışık konturu
  static const _gold     = Color(0xFFF4C542);
  static const _pants    = Color(0xFF3D5A80);
  static const _shoe     = Color(0xFF2C1A0E);
  static const _white    = Color(0xFFFFF9F0);
  static const _bookSpine = Color(0xFF7A4F2E);

  // ── Paint yardımcıları ────────────────────────────────────────────────────

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  // ── Ana çizim girişi ──────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final swing = _parachuteSwing;

    // ── Arka plan: karakter grubunun dışında ─────────────────────────────────
    // Maceraperest inerken dağlar sarkaca ters yönde hafifçe kayar (paralaks).
    if (!searchMode && showBackground) {
      canvas.save();
      if (swing != 0) canvas.translate(-swing * s * 0.30, 0);
      _drawBackground(canvas, s);
      canvas.restore();
    }

    // Sosyal kelebek balonları gövdenin zıplamasından bağımsız süzülür.
    if (!searchMode && type == PersonalityType.sosyalKelebek) {
      _drawButterflies(canvas, s);
    }

    // ── Karakter grubu ötelemesi ─────────────────────────────────────────────
    canvas.save();
    if (searchMode) {
      // Adım sekmesi: her adımda |sin| ile hafif yukarı-aşağı.
      // Çömelirken / büyüteci alırken söner. Sevinçte küçük zıplamalar.
      final still = 1 - _stillAmt;
      final stepBob =
          math.sin(_walkPhase).abs() * s * 0.016 * walkAmount * still;
      final cheer =
          math.sin(time * 2 * math.pi / 0.7).abs() * s * 0.035 * celebrate;
      canvas.translate(0, -stepBob - cheer);
    } else if (type == PersonalityType.maceraperest && !landed) {
      // Tek seferlik iniş + paraşüt tepesini pivot alan sarkaç
      canvas.translate(0, -s * 0.75 * (1 - anim));
      final px = s * 0.5, py = s * (_domeCY - _domeR);
      canvas.translate(px, py);
      canvas.rotate(swing);
      canvas.translate(-px, -py);
    } else if (type == PersonalityType.maceraperest && landed) {
      canvas.translate(0, math.sin(anim * 2 * math.pi) * 4.0);
    } else if (type == PersonalityType.sosyalKelebek) {
      // Kollar kalkarken zıplama + squash & stretch (ayak tabanı pivot)
      final up = math.sin(anim * math.pi);
      canvas.translate(0, -up * s * 0.035);
      final fx = s * 0.5, fy = s * 0.95;
      final rest = (1 - up) * (1 - up);
      final sy = 1 + 0.05 * up - 0.025 * rest;
      final sx = 1 - 0.025 * up + 0.012 * rest;
      canvas.translate(fx, fy);
      canvas.scale(sx, sy);
      canvas.translate(-fx, -fy);
    } else {
      // Diğer tipler: yumuşak harmonik sallanma (±5px)
      canvas.translate(0, -math.sin(anim * math.pi) * 5.0);
    }

    // Bacaklar ve zemin efektleri çömelme dönüşümünün DIŞINDA çizilir:
    // ayaklar yerde sabit kalır, dizler _drawLegs içinde bükülür.
    _drawLegs(canvas, s);
    _drawAccents(canvas, s);

    // Alma sekansı öğeleri de grup DIŞINDA: yere bırakılan aksesuar ve
    // yerdeki büyüteç zemine sabit kalmalı, gövdeyle dönmemeli.
    if (_pickingUp) _drawPickupItems(canvas, s);

    // ── Üst gövde: çömelmede aşağı iner + kalçadan öne eğilir ────────────────
    final crouch = _crouchAmt;
    canvas.save();
    if (crouch > 0.001) {
      // Aşağı çök + hafif öne kay
      canvas.translate(s * _crouchFwd * crouch, s * _crouchDrop * crouch);
      // Kalça pivotundan öne eğil (karakter sağa bakar; flipX aynalar)
      final px = s * 0.5, py = s * 0.78;
      canvas.translate(px, py);
      canvas.rotate(_crouchRot * crouch);
      canvas.translate(-px, -py);
    }
    // Nefes alma: gövde Y ekseninde 1.00–1.03 arası (easeInOutSine eşdeğeri
    // 0.5 − 0.5·cos), kalça hizası pivot — karakter dururken bile canlı.
    final breath = 0.5 - 0.5 * math.cos(2 * math.pi * (time + seed) / 3.4);
    final bx = s * 0.5, by = s * 0.76;
    canvas.translate(bx, by);
    canvas.scale(1.0, 1.0 + 0.03 * breath);
    canvas.translate(-bx, -by);

    _drawTorso(canvas, s);
    _drawArms(canvas, s);
    _drawNeck(canvas, s);

    // Baş grubu (gurmede keyifle sağa-sola sallanır, boyun pivot)
    final tilt = _headTilt;
    canvas.save();
    if (tilt != 0) {
      final hx = s * 0.5, hy = s * 0.50;
      canvas.translate(hx, hy);
      canvas.rotate(tilt);
      canvas.translate(-hx, -hy);
    }
    _drawHead(canvas, s);
    _drawHair(canvas, s);
    _drawFace(canvas, s);
    canvas.restore();

    _drawProp(canvas, s);
    canvas.restore();

    canvas.restore();
  }

  double get _cx => 0.5; // normalize

  // ── Arka plan öğeleri ──────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, double s) {
    switch (type) {
      case PersonalityType.maceraperest:
        _drawMountains(canvas, s);
        break;
      case PersonalityType.sakinRuh:
        _drawLeafPlants(canvas, s);
        break;
      case PersonalityType.entelektuel:
        _drawMiniShelves(canvas, s);
        break;
      case PersonalityType.gurme:
        // Zemin desen yok, önde aksesuar yeterli
        break;
      case PersonalityType.sosyalKelebek:
        // Kelebekler accent'ta
        break;
    }
  }

  void _drawMountains(Canvas canvas, double s) {
    final p = _fill(typeColor.withOpacity(0.12));

    void triangle(double x1, double y1, double x2, double y2, double x3, double y3) {
      final path = Path()
        ..moveTo(s * x1, s * y1)
        ..lineTo(s * x2, s * y2)
        ..lineTo(s * x3, s * y3)
        ..close();
      canvas.drawPath(path, p);
    }

    triangle(0.04, 0.87, 0.22, 0.55, 0.40, 0.87);
    triangle(0.38, 0.87, 0.58, 0.58, 0.78, 0.87);
    triangle(0.68, 0.87, 0.80, 0.68, 0.96, 0.87);

    // Kar
    final snow = _fill(Colors.white.withOpacity(0.20));
    final sn1 = Path()
      ..moveTo(s * 0.22, s * 0.55)
      ..lineTo(s * 0.16, s * 0.63)
      ..lineTo(s * 0.28, s * 0.63)
      ..close();
    canvas.drawPath(sn1, snow);
  }

  void _drawLeafPlants(Canvas canvas, double s) {
    final leafP = _fill(typeColor.withOpacity(0.28));
    final stemP = _stroke(typeColor.withOpacity(0.40), s * 0.013);

    void plant(double bx, double by) {
      final x = s * bx;
      final base = s * by;

      // Dikey sap
      canvas.drawLine(Offset(x, base), Offset(x, base - s * 0.22), stemP);

      // Döndürülmüş yapraklar — canvas.save/restore + translate + rotate ile
      void leaf(double offX, double offY, double angle, double w, double h) {
        canvas.save();
        canvas.translate(x + offX, base + offY);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          leafP,
        );
        canvas.restore();
      }

      // Alt çift yaprak
      leaf(-s * 0.042, -s * 0.088, -0.65, s * 0.092, s * 0.038);
      leaf( s * 0.042, -s * 0.088,  0.65, s * 0.092, s * 0.038);
      // Üst çift yaprak (biraz daha küçük)
      leaf(-s * 0.030, -s * 0.158, -0.52, s * 0.072, s * 0.030);
      leaf( s * 0.030, -s * 0.158,  0.52, s * 0.072, s * 0.030);
      // Tepe yaprak (dikine — bitkinin ucunda)
      leaf(0, -s * 0.225, 0.0, s * 0.034, s * 0.068);
    }

    // Rüzgâr salınımı: bitki tabanından eğilir — tepesi daha çok oynar.
    void swaying(double bx, double by, double phase) {
      final a = 0.05 * math.sin(2 * math.pi * time / 3.0 + phase);
      canvas.save();
      canvas.translate(s * bx, s * by);
      canvas.rotate(a);
      canvas.translate(-s * bx, -s * by);
      plant(bx, by);
      canvas.restore();
    }

    swaying(0.11, 0.90, 0.0);
    swaying(0.89, 0.90, 1.3);
  }

  void _drawMiniShelves(Canvas canvas, double s) {
    final shelfP = _fill(typeColor.withOpacity(0.15));
    final colors = [
      typeColor.withOpacity(0.35),
      const Color(0xFF45B7D1).withOpacity(0.25),
      const Color(0xFFFF6B6B).withOpacity(0.20),
    ];

    void shelf(double lx, double by) {
      canvas.drawRect(Rect.fromLTRB(s * lx, s * (by - 0.02), s * (lx + 0.22), s * by), shelfP);
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              s * (lx + 0.01 + i * 0.07), s * (by - 0.13),
              s * (lx + 0.06 + i * 0.07), s * (by - 0.025),
            ),
            const Radius.circular(2),
          ),
          _fill(colors[i]),
        );
      }
    }

    shelf(0.03, 0.72);
    shelf(0.75, 0.72);
  }

  // ── Gövde ─────────────────────────────────────────────────────────────────

  void _drawTorso(Canvas canvas, double s) {
    // ÖNEMLI: Tüm gövde çizimleri y=0.512'den (baş alt kenarı) başlar —
    // baş çemberinin yanlarından taşan renk "sakal" görünümü vermesin.
    final cx = s * _cx;
    final bodyTop = s * 0.512;

    if (gender == CharacterGender.female) {
      // ── Kadın: belden aşağı hafif genişleyen zarif kesim + V-yaka ─────────
      final blouse = Path()
        ..moveTo(cx - s * 0.098, bodyTop)
        ..quadraticBezierTo(cx - s * 0.120, bodyTop + s * 0.004,
            cx - s * 0.120, bodyTop + s * 0.034)          // yuvarlak omuz
        ..lineTo(cx - s * 0.104, s * 0.652)              // bel (hafif içe)
        ..lineTo(cx + s * 0.104, s * 0.652)
        ..lineTo(cx + s * 0.120, bodyTop + s * 0.034)
        ..quadraticBezierTo(cx + s * 0.120, bodyTop + s * 0.004,
            cx + s * 0.098, bodyTop)
        ..close();
      canvas.drawPath(blouse, _fill(typeColor));

      // A-line etek: belden genişleyen yumuşak trapez
      final skirtPath = Path()
        ..moveTo(cx - s * 0.106, s * 0.646)
        ..lineTo(cx + s * 0.106, s * 0.646)
        ..quadraticBezierTo(cx + s * 0.150, s * 0.720, cx + s * 0.172, s * 0.808)
        ..lineTo(cx - s * 0.172, s * 0.808)
        ..quadraticBezierTo(cx - s * 0.150, s * 0.720, cx - s * 0.106, s * 0.646)
        ..close();
      canvas.drawPath(skirtPath, _fill(typeColor.withOpacity(0.80)));

      // Kemer çizgisi
      canvas.drawLine(
        Offset(cx - s * 0.104, s * 0.650),
        Offset(cx + s * 0.104, s * 0.650),
        _stroke(_hairDark.withOpacity(0.15), s * 0.016),
      );

      // V-yaka
      final vNeck = Path()
        ..moveTo(cx - s * 0.036, bodyTop - s * 0.002)
        ..lineTo(cx + s * 0.036, bodyTop - s * 0.002)
        ..lineTo(cx, bodyTop + s * 0.058)
        ..close();
      canvas.drawPath(vNeck, _fill(_skin));

      // İnce kolye + küçük pandantif
      final necklace = Path()
        ..moveTo(cx - s * 0.034, bodyTop + s * 0.002)
        ..quadraticBezierTo(cx, bodyTop + s * 0.060, cx + s * 0.034, bodyTop + s * 0.002);
      canvas.drawPath(necklace, _stroke(_gold.withOpacity(0.9), s * 0.006));
      canvas.drawCircle(Offset(cx, bodyTop + s * 0.034), s * 0.009, _fill(_gold));
      canvas.drawCircle(Offset(cx - s * 0.003, bodyTop + s * 0.031), s * 0.003,
          _fill(Colors.white.withOpacity(0.8)));
    } else {
      // ── Erkek / nötr: geniş omuzlu, bisiklet yaka tişört ─────────────────
      final shirt = Path()
        ..moveTo(cx - s * 0.100, bodyTop)
        ..quadraticBezierTo(cx - s * 0.142, bodyTop + s * 0.002,
            cx - s * 0.142, bodyTop + s * 0.042)          // geniş, yuvarlak omuz
        ..lineTo(cx - s * 0.126, s * 0.788)
        ..lineTo(cx + s * 0.126, s * 0.788)
        ..lineTo(cx + s * 0.142, bodyTop + s * 0.042)
        ..quadraticBezierTo(cx + s * 0.142, bodyTop + s * 0.002,
            cx + s * 0.100, bodyTop)
        ..close();
      canvas.drawPath(shirt, _fill(typeColor));

      // Bisiklet yaka (boyun altında koyu bant)
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, bodyTop), width: s * 0.080, height: s * 0.056),
        0, math.pi, false,
        _stroke(Color.lerp(typeColor, Colors.black, 0.28)!, s * 0.013),
      );
    }
  }

  void _drawNeck(Canvas canvas, double s) {
    // Boyun: baş altından (0.514) gövde üstüne (0.510) kadar → kesintisiz bağlantı
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(s * _cx, s * 0.475),
        width: s * 0.068, height: s * 0.080,
      ),
      _fill(_skin),
    );
  }

  // ── Bacaklar ve ayakkabılar ────────────────────────────────────────────────

  void _drawLegs(Canvas canvas, double s) {
    final legP = _stroke(_pants, s * 0.085);
    final shoeP = _fill(_shoe);

    if (searchMode || type == PersonalityType.maceraperest) {
      // Yürüme animasyonu: tüm tipler searchMode'da, maceraperest her zaman.
      // Çömelmede adım salınımı söner, kalça çöker, dizler öne bükülür —
      // ayaklar yerde sabit kalır.
      final crouch = _crouchAmt;
      final drop = s * _crouchDrop * crouch;
      final hipL = Offset(s * 0.445, s * 0.747 + drop);
      final hipR = Offset(s * 0.555, s * 0.747 + drop);
      final double walk, liftL, liftR;
      if (searchMode) {
        // Gerçek adım: ayaklar karşılıklı ileri-geri, öne gelen ayak kalkar.
        final amt = walkAmount * (1 - _stillAmt);
        final ph = _walkPhase;
        walk = math.sin(ph) * s * 0.045 * amt;
        liftL = math.max(0.0, -math.cos(ph)) * s * 0.022 * amt;
        liftR = math.max(0.0, math.cos(ph)) * s * 0.022 * amt;
      } else {
        walk = math.sin(anim * math.pi) * s * 0.045;
        liftL = 0.0;
        liftR = 0.0;
      }
      final leftFoot  = Offset(s * 0.400 - walk, s * 0.912 - liftL);
      final rightFoot = Offset(s * 0.580 + walk, s * 0.912 - liftR);

      // Diz: crouch=0'da tam orta nokta (düz bacak görünümü),
      // crouch arttıkça öne (bakış yönüne) çıkar.
      Offset knee(Offset hip, Offset foot, double fwd) => Offset(
            (hip.dx + foot.dx) / 2 + fwd,
            (hip.dy + foot.dy) / 2 + s * 0.012 * crouch,
          );
      final kneeL = knee(hipL, leftFoot,  s * 0.070 * crouch);
      final kneeR = knee(hipR, rightFoot, s * 0.088 * crouch);

      canvas.drawLine(hipL, kneeL, legP);
      canvas.drawLine(kneeL, leftFoot, legP);
      canvas.drawLine(hipR, kneeR, legP);
      canvas.drawLine(kneeR, rightFoot, legP);
      canvas.drawOval(Rect.fromCenter(center: Offset(leftFoot.dx,  leftFoot.dy  + s * 0.022), width: s * 0.11, height: s * 0.044), shoeP);
      canvas.drawOval(Rect.fromCenter(center: Offset(rightFoot.dx, rightFoot.dy + s * 0.022), width: s * 0.11, height: s * 0.044), shoeP);
    } else {
      // Bacak ucu y=0.900, ayakkabı merkezi y=0.942 → ayakkabı tam bacak ucunun ALTINDA
      canvas.drawLine(Offset(s * 0.445, s * 0.747), Offset(s * 0.405, s * 0.900), legP);
      canvas.drawLine(Offset(s * 0.555, s * 0.747), Offset(s * 0.590, s * 0.900), legP);
      canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.400, s * 0.942), width: s * 0.115, height: s * 0.046), shoeP);
      canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.592, s * 0.942), width: s * 0.115, height: s * 0.046), shoeP);
    }
  }

  // ── Kollar ─────────────────────────────────────────────────────────────────

  void _drawArms(Canvas canvas, double s) {
    final armP = _stroke(typeColor, s * 0.075);

    final ls = Offset(s * 0.365, s * 0.535); // sol omuz
    final rs = Offset(s * 0.635, s * 0.535); // sağ omuz

    if (searchMode) {
      // Arama pozu: sağ el büyüteç tutarak göz hizasına kaldırılmış,
      // sol el yürüme dengesi için karşılıklı sallantı yapıyor.
      // Sol el çömelmede dize dayanır, salınım söner. Sağ el büyüteci HER
      // ZAMAN yüz hizasında tutar (incelemede yere yaklaşma gövde eğiminden
      // gelir) — yalnızca alma sekansında yerdeki büyütece uzanır.
      final crouch = _crouchAmt;
      final swing =
          math.sin(_walkPhase) * s * 0.022 * walkAmount * (1 - _stillAmt);
      final rHand = _searchRightHand(s);
      canvas.drawLine(rs, rHand, armP);
      // Sol: sallanma → dize dayalı → (sevinçte) havada
      var lHand = Offset.lerp(
        Offset(s * 0.285 - swing, s * 0.660),
        Offset(s * 0.408, s * 0.700),
        crouch,
      )!;
      if (celebrate > 0) {
        final bounce =
            math.sin(time * 2 * math.pi / 0.7) * s * 0.02 * celebrate;
        lHand = Offset.lerp(lHand, Offset(s * 0.230, s * 0.385 + bounce),
            Curves.easeOutBack.transform(celebrate))!;
      }
      canvas.drawLine(ls, lHand, armP);
      return;
    }

    switch (type) {
      case PersonalityType.entelektuel:
        // Kitabı tutuyormuş gibi: öne doğru dirsek kıvırma. Kitapla birlikte
        // hafifçe sağa-sola eğilir (ağırlık hissi).
        final pivot = Offset(s * 0.5, s * 0.675);
        final a = _bookTilt;
        Offset r(double x, double y) => _rotAround(Offset(s * x, s * y), pivot, a);
        canvas.drawLine(ls, r(0.285, 0.625), armP);
        canvas.drawLine(r(0.285, 0.625), r(0.295, 0.660), armP);
        canvas.drawLine(rs, r(0.715, 0.625), armP);
        canvas.drawLine(r(0.715, 0.625), r(0.700, 0.660), armP);
        break;

      case PersonalityType.sosyalKelebek:
        // Kollar yukarı → kutlama pozu
        final swing = math.sin(anim * math.pi) * s * 0.03;
        canvas.drawLine(ls, Offset(s * 0.230, s * 0.385 + swing), armP);
        canvas.drawLine(rs, Offset(s * 0.768, s * 0.385 - swing), armP);
        break;

      case PersonalityType.sakinRuh:
        // Sol el kupa tutuyor
        canvas.drawLine(ls, Offset(s * 0.270, s * 0.625), armP);
        canvas.drawLine(Offset(s * 0.270, s * 0.625), Offset(s * 0.260, s * 0.645), armP);
        // Sağ el serbest sarkıyor
        canvas.drawLine(rs, Offset(s * 0.700, s * 0.660), armP);
        break;

      case PersonalityType.maceraperest:
        // Yürüme: kollar hafif sallantı
        final swing = math.sin(anim * math.pi) * s * 0.03;
        canvas.drawLine(ls, Offset(s * 0.295 + swing, s * 0.660), armP);
        canvas.drawLine(rs, Offset(s * 0.705 - swing, s * 0.660), armP);
        break;

      case PersonalityType.gurme:
        // Sağ el çatalı sallıyor (yukarı)
        canvas.drawLine(rs, _gurmeForkHand(s), armP);
        // Sol el tabağı tutuyor — lokmayı fırlatırken yukarı kalkar
        canvas.drawLine(ls, Offset(s * 0.255, s * 0.625 - s * 0.05 * _plateLift), armP);
        break;
    }
  }

  /// Gurmenin çatal tutan eli (sallanma dahil).
  Offset _gurmeForkHand(double s) {
    final w = _forkWave;
    return Offset(s * 0.720 + s * 0.018 * w, s * 0.390 - s * 0.010 * w.abs());
  }

  // ── Baş ───────────────────────────────────────────────────────────────────

  void _drawHead(Canvas canvas, double s) {
    canvas.drawCircle(Offset(s * _cx, s * 0.395), s * 0.115, _fill(_skin));
  }

  // ── Saç ───────────────────────────────────────────────────────────────────

  void _drawHair(Canvas canvas, double s) {
    final cx = s * _cx;
    final headCY = s * 0.395;
    final r = s * 0.115;
    final isFemale = gender == CharacterGender.female;
    final hairP = _fill(isFemale ? _hairWarm : _hairDark);

    // hairline: kaşların üstünde (headCY - r*kH)
    const kH = 0.42;
    final hairlineY = headCY - r * kH;
    final hairlineX = r * math.sqrt(1 - kH * kH);

    // ── Kadın: topuz (başın üst-arkası) ──────────────────────────────────────
    final bunC = Offset(cx + r * 0.48, headCY - r * 0.98);
    final bunR = r * 0.40;
    if (isFemale) {
      canvas.drawCircle(bunC, bunR, hairP);
      // Topuz tokası
      canvas.drawArc(
        Rect.fromCircle(center: bunC, radius: bunR * 0.98),
        math.pi * 0.55, math.pi * 0.45, false,
        _stroke(typeColor, s * 0.012),
      );
    }

    // ── Saç şapkası (clipRect + drawCircle güvenilir dolgu) ──────────────────
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      cx - r - s * 0.01,
      headCY - r - s * 0.01,
      cx + r + s * 0.01,
      hairlineY,
    ));
    canvas.drawCircle(Offset(cx, headCY), r, hairP);
    canvas.restore();

    // ── Erkek: üstte hafif dokulu / hacimli kısa kesim ───────────────────────
    if (gender == CharacterGender.male) {
      for (final t in const [
        (-0.62, 0.10, 0.30), (-0.25, 0.16, 0.34), (0.15, 0.17, 0.34),
        (0.52, 0.12, 0.30),
      ]) {
        canvas.drawCircle(
          Offset(cx + r * t.$1, headCY - r + r * 0.10 - r * t.$2),
          r * t.$3,
          hairP,
        );
      }
    }

    // ── Yan saç (kadın / nötr) ────────────────────────────────────────────────
    Path sideHairPath(double dir) {
      final path = Path();
      final topY = hairlineY - r * 0.18;
      final topX = hairlineX * 0.94;
      path.moveTo(cx + dir * topX, topY);
      if (isFemale) {
        // Omuz hizasında dışa kıvrılan uçlar
        path.cubicTo(
          cx + dir * (hairlineX + s * 0.020), headCY,
          cx + dir * (r + s * 0.040),          headCY + r * 0.55,
          cx + dir * (r + s * 0.028),          headCY + r * 1.02,
        );
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.030), headCY + r * 1.22,
          cx + dir * (r + s * 0.062), headCY + r * 1.20,
        );
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.030), headCY + r * 1.34,
          cx + dir * (r + s * 0.002), headCY + r * 1.10,
        );
      } else {
        path.cubicTo(
          cx + dir * (hairlineX + s * 0.020), headCY,
          cx + dir * (r + s * 0.042),          headCY + r * 0.55,
          cx + dir * (r + s * 0.026),          headCY + r * 1.00,
        );
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.008), headCY + r * 1.16,
          cx + dir * r,               headCY + r * 0.98,
        );
      }
      path.cubicTo(
        cx + dir * r, headCY + r * 0.60,
        cx + dir * r, headCY - r * 0.05,
        cx + dir * topX, topY,
      );
      path.close();
      return path;
    }

    if (isFemale || gender == CharacterGender.neutral) {
      canvas.drawPath(sideHairPath(-1), hairP);
      canvas.drawPath(sideHairPath(1), hairP);
    }

    if (!isFemale) return;

    // ── Kadın: alına yana doğru savrulan perçem ──────────────────────────────
    final bangs = Path()
      ..moveTo(cx - r * 0.95, hairlineY - r * 0.10)
      ..quadraticBezierTo(cx - r * 0.20, hairlineY + r * 0.24,
          cx + r * 0.78, hairlineY - r * 0.02)
      ..quadraticBezierTo(cx + r * 0.10, hairlineY - r * 0.30,
          cx - r * 0.95, hairlineY - r * 0.10)
      ..close();
    canvas.drawPath(bangs, hairP);

    // ── Kadın: saçın dış sınırında ince açık kontur (rim light) ──────────────
    // Koyu arka planda saç silüeti kaybolmasın. Sadece başın DIŞINDA kalan
    // kenarlar boyanır (yüzün üstüne çizgi düşmez).
    final rimP = _stroke(_hairRim.withOpacity(0.55), s * 0.007);
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, s, s))
      ..addOval(Rect.fromCircle(center: Offset(cx, headCY), radius: r * 0.995)));
    canvas.drawPath(sideHairPath(-1), rimP);
    canvas.drawPath(sideHairPath(1), rimP);
    canvas.drawCircle(bunC, bunR, rimP);
    canvas.restore();
    // Şapkanın üst yayı
    const a0 = math.pi + 0.4334; // asin(kH)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, headCY), radius: r + s * 0.002),
      a0, math.pi - 2 * 0.4334, false, rimP,
    );

    // ── Küpeler: kulak hizasında küçük parlak noktalar ───────────────────────
    for (final dir in const [-1.0, 1.0]) {
      final e = Offset(cx + dir * (r + s * 0.006), headCY + r * 0.60);
      canvas.drawCircle(e, s * 0.011, _fill(_gold));
      canvas.drawCircle(e.translate(-s * 0.003, -s * 0.003), s * 0.004,
          _fill(Colors.white.withOpacity(0.9)));
    }
  }

  // ── Yüz ───────────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas, double s) {
    final cx = s * _cx;
    // Çömelirken yüz hatları hafif aşağı kayar → yere bakma hissi
    final cy = s * 0.395 + s * 0.022 * _crouchAmt;
    final isFemale = gender == CharacterGender.female;

    // ── Kaşlar (her cinsiyet, şekil farklı) ──────────────────────────────────
    // Kadın: ince ve kavisli; erkek: daha kalın ve düz kaş
    final browP = _stroke(
      isFemale ? _hairWarm.withOpacity(0.95) : _hairDark.withOpacity(0.90),
      isFemale ? s * 0.009 : (gender == CharacterGender.male ? s * 0.016 : s * 0.012),
    );
    if (isFemale) {
      // Kadın: kavisli, yüksek kaş
      final leftBrow = Path()
        ..moveTo(cx - s * 0.063, cy - s * 0.040)
        ..quadraticBezierTo(cx - s * 0.042, cy - s * 0.054, cx - s * 0.022, cy - s * 0.040);
      final rightBrow = Path()
        ..moveTo(cx + s * 0.022, cy - s * 0.040)
        ..quadraticBezierTo(cx + s * 0.042, cy - s * 0.054, cx + s * 0.063, cy - s * 0.040);
      canvas.drawPath(leftBrow, browP);
      canvas.drawPath(rightBrow, browP);
    } else {
      // Erkek/nötr: düz, hafif kalın kaş
      canvas.drawLine(Offset(cx - s * 0.063, cy - s * 0.037), Offset(cx - s * 0.022, cy - s * 0.037), browP);
      canvas.drawLine(Offset(cx + s * 0.022, cy - s * 0.037), Offset(cx + s * 0.063, cy - s * 0.037), browP);
    }

    // ── Gözler ───────────────────────────────────────────────────────────────
    final eyeR = isFemale ? s * 0.018 : s * 0.015; // kadın gözü biraz daha büyük
    // Doğal göz kırpma: göz yüksekliği 150 ms içinde 0'a inip açılır.
    final open = _eyeOpen;
    final eyeH = eyeR * 2 * math.max(open, 0.12);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - s * 0.042, cy - s * 0.008), width: eyeR * 2, height: eyeH), _fill(_hairDark));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.042, cy - s * 0.008), width: eyeR * 2, height: eyeH), _fill(_hairDark));

    // Göz parıltısı (göz kapalıyken görünmez)
    if (open > 0.6) {
      canvas.drawCircle(Offset(cx - s * 0.038, cy - s * 0.014), s * 0.006, _fill(Colors.white.withOpacity(0.8)));
      canvas.drawCircle(Offset(cx + s * 0.046, cy - s * 0.014), s * 0.006, _fill(Colors.white.withOpacity(0.8)));
    }

    // ── Gözlük (sadece entelektüel) ──────────────────────────────────────────
    if (type == PersonalityType.entelektuel) {
      const frameR  = 0.024;           // yarıçap katsayısı
      final eyeXL   = cx - s * 0.042;
      final eyeXR   = cx + s * 0.042;
      final eyeYG   = cy - s * 0.008;
      final glassP  = _stroke(_hairDark.withOpacity(0.72), s * 0.012);
      final trimP   = _stroke(_hairDark.withOpacity(0.50), s * 0.009);
      // Sol ve sağ çerçeve (dolgu yok, sadece kontur)
      canvas.drawCircle(Offset(eyeXL, eyeYG), s * frameR, glassP);
      canvas.drawCircle(Offset(eyeXR, eyeYG), s * frameR, glassP);
      // Köprü (burun üstü)
      canvas.drawLine(
        Offset(eyeXL + s * frameR, eyeYG),
        Offset(eyeXR - s * frameR, eyeYG),
        trimP,
      );
      // Sol kulak çubuğu
      canvas.drawLine(
        Offset(eyeXL - s * frameR, eyeYG),
        Offset(cx - s * 0.108, eyeYG + s * 0.006),
        trimP,
      );
      // Sağ kulak çubuğu
      canvas.drawLine(
        Offset(eyeXR + s * frameR, eyeYG),
        Offset(cx + s * 0.108, eyeYG + s * 0.006),
        trimP,
      );

      // Camlardan periyodik geçen çapraz beyaz parlama (glint)
      final gp = ((time + seed) % 3.2) / 0.45;
      if (gp < 1.0) {
        final lensR = s * frameR;
        final glintP = _stroke(
            Colors.white.withOpacity(0.85 * math.sin(math.pi * gp)), s * 0.007);
        for (final ex in [eyeXL, eyeXR]) {
          final c = Offset(ex, eyeYG);
          canvas.save();
          canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: lensR)));
          // Çizgi (1,-1) yönünde; (1,1) normali boyunca camı süpürür
          final off = (-1.4 + 2.8 * gp) * lensR / math.sqrt2;
          final mid = c.translate(off, off);
          final d = lensR * 1.5 / math.sqrt2;
          canvas.drawLine(mid.translate(-d, d), mid.translate(d, -d), glintP);
          canvas.restore();
        }
      }
    }

    // ── Kirpikler (sadece kadın): gözün üst-dış köşesinde 2 kıvrık kirpik ──
    if (isFemale && open > 0.3) {
      final lashP = _stroke(_hairDark, s * 0.008);
      void lashes(double ex, double ey, double outward) {
        final top = ey - eyeR * open;
        for (final k in const [0.0, 1.0]) {
          final start = Offset(ex + outward * eyeR * (0.35 + 0.45 * k), top + eyeR * 0.15 * k);
          final ctrl  = start.translate(outward * s * 0.006, -s * 0.012);
          final end   = start.translate(outward * s * 0.016, -s * 0.010);
          canvas.drawPath(
            Path()
              ..moveTo(start.dx, start.dy)
              ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
            lashP,
          );
        }
      }
      lashes(cx - s * 0.042, cy - s * 0.008, -1);
      lashes(cx + s * 0.042, cy - s * 0.008, 1);
    }

    // ── Gülümseme ────────────────────────────────────────────────────────────
    // Sevinçte geniş, açık "D" gülüşüne dönüşür.
    final smileW = isFemale ? s * 0.030 : s * 0.038;
    final smileH = isFemale ? s * 0.048 : s * 0.056;
    if (celebrate > 0.25) {
      final w = smileW * 1.15;
      final y0 = cy + s * 0.026;
      final mouth = Path()
        ..moveTo(cx - w, y0)
        ..lineTo(cx + w, y0)
        ..quadraticBezierTo(cx, y0 + s * 0.060, cx - w, y0)
        ..close();
      canvas.drawPath(mouth, _fill(const Color(0xFF7A3328)));
      // Üst dişler
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawRect(Rect.fromLTRB(cx - w, y0, cx + w, y0 + s * 0.010),
          _fill(Colors.white.withOpacity(0.95)));
      // Dil
      canvas.drawCircle(Offset(cx, y0 + s * 0.034), s * 0.016,
          _fill(const Color(0xFFE57373)));
      canvas.restore();
    } else {
      final smilePath = Path();
      smilePath.moveTo(cx - smileW, cy + s * 0.030);
      smilePath.quadraticBezierTo(cx, cy + smileH, cx + smileW, cy + s * 0.030);
      canvas.drawPath(smilePath, _stroke(const Color(0xFFBB7755), s * 0.014));
    }

    // ── Yanak allığı ─────────────────────────────────────────────────────────
    if (isFemale) {
      // Kadın: yumuşak, bulanık mercan allık
      final blush = Paint()
        ..color = const Color(0xFFFF8A80).withOpacity(0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.010);
      canvas.drawCircle(Offset(cx - s * 0.066, cy + s * 0.022), s * 0.020, blush);
      canvas.drawCircle(Offset(cx + s * 0.066, cy + s * 0.022), s * 0.020, blush);
    } else {
      canvas.drawCircle(Offset(cx - s * 0.068, cy + s * 0.022), s * 0.021, _fill(const Color(0xFFFFAA88).withOpacity(0.30)));
      canvas.drawCircle(Offset(cx + s * 0.068, cy + s * 0.022), s * 0.021, _fill(const Color(0xFFFFAA88).withOpacity(0.30)));
    }
  }

  // ── Aksesuarlar (prop) ────────────────────────────────────────────────────

  void _drawProp(Canvas canvas, double s) {
    if (searchMode) {
      // Alma sekansı sürerken büyüteç grup DIŞINDA (_drawPickupItems) çizilir
      if (!_pickingUp) _drawSearchMagnifier(canvas, s);
      return;
    }
    switch (type) {
      case PersonalityType.entelektuel: _drawBook(canvas, s); break;
      case PersonalityType.gurme:       _drawForkAndPlate(canvas, s); break;
      case PersonalityType.sakinRuh:    _drawMug(canvas, s); break;
      case PersonalityType.maceraperest: _drawHikingStick(canvas, s); break;
      case PersonalityType.sosyalKelebek: break; // kelebekler accent'ta
    }
  }

  /// Büyüteç: arama modunda tüm tiplerin prop'u.
  ///
  /// Sağ kolun bitmesiyle aynı koordinattan başlar ve
  /// yukarı-sağa doğru uzanır. Cam içinde nabız gibi titreşen bir
  /// parıltı + dışarı yayılan iki "radar" halkası var.
  void _drawSearchMagnifier(Canvas canvas, double s) {
    // Büyüteç DAİMA yüz hizasında: sap sağ elde, mercek göz önünde.
    // İncelemede mercek yüzle birlikte alçalır (gövde eğimi grubu döndürür).
    // El küçük daireler çizerek etrafı inceler; sevinçte büyüteç söner.
    final fade = (1.0 - celebrate * 1.6).clamp(0.0, 1.0);
    if (fade <= 0.02) return;
    final handleBase = _searchRightHand(s);
    final lensC = handleBase.translate(-s * 0.072, -s * 0.062);
    if (fade < 1.0) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(fade));
      _paintMagnifier(canvas, s, handleBase, lensC);
      canvas.restore();
    } else {
      _paintMagnifier(canvas, s, handleBase, lensC);
    }
  }

  /// Büyüteç çizimi — hem elde tutulan (grup içi) hem alma sekansındaki
  /// (grup dışı) büyüteç için ortak. [ringScale] radar halkalarını söndürür
  /// (yerde dururken ping atmasın diye).
  void _paintMagnifier(Canvas canvas, double s, Offset handleBase, Offset lensC,
      {double ringScale = 1.0}) {
    final lensR = s * 0.062;

    // Sap
    canvas.drawLine(
      handleBase, lensC,
      _stroke(const Color(0xFF7A5230), s * 0.026),
    );

    // Mercek cam alanı (hafif şeffaf)
    canvas.drawCircle(lensC, lensR, _fill(Colors.white.withOpacity(0.14)));
    // Mercek çerçevesi
    canvas.drawCircle(lensC, lensR, _stroke(const Color(0xFF7A5230), s * 0.024));

    // Cam içi yansıma: nabız gibi parlayan küçük daire
    final shimmer = 0.28 + math.sin(anim * math.pi * 2) * 0.18;
    canvas.drawCircle(
      Offset(lensC.dx - lensR * 0.28, lensC.dy - lensR * 0.28),
      lensR * 0.28,
      _fill(Colors.white.withOpacity(shimmer)),
    );

    // Radar halkaları: mercekten dışarı yayılan iki ping dalgası
    if (ringScale <= 0.02) return;
    for (var i = 0; i < 2; i++) {
      final t = (anim + i * 0.5) % 1.0; // 0→1, ofsetli
      final r = lensR * (1.0 + t * 0.90);
      final opacity = (1.0 - t) * 0.30 * ringScale;
      canvas.drawCircle(
        lensC, r,
        _stroke(typeColor.withOpacity(opacity), s * 0.007),
      );
    }
  }

  // ── Büyüteci yerden alma sekansı ─────────────────────────────────────────
  //
  //  pickup 0.00–0.30 : elindeki tip aksesuarı yere bırakılır (hızla düşer)
  //  pickup 0.00–0.50 : çömelme derinleşir (sin eğrisi, _crouchAmt)
  //  pickup 0.50–0.90 : el büyüteci kavrar, yerden ele taşınır
  //  pickup 0.50–1.00 : karakter doğrulur, yürüyüş pozuna döner
  //  Bırakılan aksesuar 0.80'den sonra solarak kaybolur.

  /// Bırakılan aksesuarın normal duruştaki yaklaşık merkezi.
  Offset _propAnchor(double s) {
    switch (type) {
      case PersonalityType.entelektuel:   return Offset(s * 0.500, s * 0.675);
      case PersonalityType.gurme:         return Offset(s * 0.450, s * 0.550);
      case PersonalityType.sakinRuh:      return Offset(s * 0.252, s * 0.640);
      case PersonalityType.maceraperest:  return Offset(s * 0.270, s * 0.780);
      case PersonalityType.sosyalKelebek: return Offset(s * 0.500, s * 0.600);
    }
  }

  void _drawPickupItems(Canvas canvas, double s) {
    // ── 1) Eski aksesuar yere bırakılır ──────────────────────────────────────
    // (Sosyal kelebeğin elinde taşınan aksesuar yok — kelebekler uçup gider.)
    if (type != PersonalityType.sosyalKelebek) {
      // Yumuşak iniş: aksesuar yere süzülür (easeInOutCubic), yere değdikten
      // sonra aniden kaybolmak yerine yavaşça solar.
      final dropT =
          Curves.easeInOutCubic.transform((pickup / 0.40).clamp(0.0, 1.0));
      final fade = pickup > 0.55
          ? Curves.easeInOut
              .transform((1.0 - (pickup - 0.55) / 0.45).clamp(0.0, 1.0))
          : 1.0;
      if (fade > 0.02) {
        final anchor = _propAnchor(s);
        final target = Offset(s * 0.260, s * 0.870); // karakterin gerisinde, yerde
        canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(fade));
        canvas.translate(
          (target.dx - anchor.dx) * dropT,
          (target.dy - anchor.dy) * dropT,
        );
        // Yere inerken hafif küçülsün
        final k = 1.0 - 0.18 * dropT;
        canvas.translate(anchor.dx, anchor.dy);
        canvas.scale(k, k);
        canvas.translate(-anchor.dx, -anchor.dy);
        switch (type) {
          case PersonalityType.entelektuel:  _drawBook(canvas, s); break;
          case PersonalityType.gurme:        _drawForkAndPlate(canvas, s); break;
          case PersonalityType.sakinRuh:     _drawMug(canvas, s); break;
          case PersonalityType.maceraperest: _drawHikingStick(canvas, s); break;
          case PersonalityType.sosyalKelebek: break;
        }
        canvas.restore();
      }
    }

    // ── 2) Büyüteç: yerde durur → el kavrar → elle birlikte yüze taşınır ─────
    final grabT = Curves.easeInOut
        .transform(((pickup - 0.50) / 0.40).clamp(0.0, 1.0));

    // Sağ elin anlık konumu — _drawArms ile aynı formül (reach: uzanma),
    // çömelme dönüşümü uygulanır ki grup içindeki kolla örtüşsün.
    final reach = math.sin(pickup * math.pi);
    final hand = _crouchXform(
      Offset.lerp(Offset(s * 0.620, s * 0.432),
          Offset(s * 0.640, s * 0.590), reach)!,
      s,
    );

    // Yerde yatan büyüteç konumu
    final handleGround = Offset(s * 0.745, s * 0.915);
    final lensGround   = Offset(s * 0.640, s * 0.885);

    // Mercek-sap ofseti: yerde yatık → elde yüz hizası duruşuna döner.
    // grabT=1 && pickup→1'de sap = el = (0.620, 0.432), mercek = (0.548,
    // 0.370) → grup içi _drawSearchMagnifier ile kesintisiz devralma.
    final lensOffset = Offset.lerp(
      lensGround - handleGround,
      Offset(s * (0.548 - 0.620), s * (0.370 - 0.432)),
      grabT,
    )!;

    // Kavranana dek yerde sabit; sonra ele yapışık yükselir.
    final handleBase = Offset.lerp(handleGround, hand, grabT)!;

    _paintMagnifier(
      canvas, s,
      handleBase,
      handleBase + lensOffset,
      ringScale: grabT, // yerdeyken ping atmaz, ele gelince başlar
    );
  }

  void _drawBook(Canvas canvas, double s) {
    final a = _bookTilt;
    if (a != 0) {
      canvas.save();
      canvas.translate(s * 0.5, s * 0.675);
      canvas.rotate(a);
      canvas.translate(-s * 0.5, -s * 0.675);
      _drawBookShape(canvas, s);
      canvas.restore();
    } else {
      _drawBookShape(canvas, s);
    }
  }

  void _drawBookShape(Canvas canvas, double s) {
    // Açık kitap, iki elin arasında tutulmuş
    final bL = s * 0.285, bR = s * 0.715;
    final bT = s * 0.620, bB = s * 0.730;
    final cx = s * _cx;

    // Sol sayfa
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(bL, bT, cx - s * 0.010, bB),
        topLeft: const Radius.circular(3), bottomLeft: const Radius.circular(3),
      ),
      _fill(_white),
    );
    // Sol sayfa satırları
    final lineP = _stroke(const Color(0xFFCCBBAA), s * 0.010);
    for (var i = 1; i <= 3; i++) {
      final y = bT + (bB - bT) * i / 4.0;
      canvas.drawLine(Offset(bL + s * 0.020, y), Offset(cx - s * 0.022, y), lineP);
    }

    // Sağ sayfa
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cx + s * 0.010, bT, bR, bB),
        topRight: const Radius.circular(3), bottomRight: const Radius.circular(3),
      ),
      _fill(const Color(0xFFF5EDD8)),
    );
    for (var i = 1; i <= 3; i++) {
      final y = bT + (bB - bT) * i / 4.0;
      canvas.drawLine(Offset(cx + s * 0.022, y), Offset(bR - s * 0.020, y), lineP);
    }

    // Sırt
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, (bT + bB) / 2), width: s * 0.022, height: bB - bT),
      _fill(_bookSpine),
    );
  }

  void _drawForkAndPlate(Canvas canvas, double s) {
    // ── Çatal: sağ elde, sallanırken elle birlikte döner ─────────────────────
    final hand = _gurmeForkHand(s);
    final forkP = _stroke(const Color(0xFFCCCCCC), s * 0.022);
    final tineP = _stroke(const Color(0xFFCCCCCC), s * 0.014);
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(0.18 * _forkWave);
    canvas.drawLine(Offset(0, -s * 0.002), Offset(0, -s * 0.108), forkP);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(i * s * 0.022, -s * 0.108),
        Offset(i * s * 0.022, -s * 0.168),
        tineP,
      );
    }
    canvas.restore();

    // ── Tabak: sol elde, kalkıp lokmayı havaya fırlatır ──────────────────────
    final lift = s * 0.05 * _plateLift;
    final plateC = Offset(s * 0.255, s * 0.645 - lift);
    canvas.drawCircle(plateC, s * 0.090, _fill(const Color(0xFFF0F0F0)));
    canvas.drawCircle(plateC, s * 0.090, _stroke(const Color(0xFFCCCCCC), s * 0.012));
    // Küçük yemekler tabakta kalır
    canvas.drawCircle(Offset(plateC.dx + s * 0.030, plateC.dy + s * 0.018), s * 0.022, _fill(typeColor.withOpacity(0.5)));
    canvas.drawCircle(Offset(plateC.dx - s * 0.028, plateC.dy + s * 0.018), s * 0.018, _fill(typeColor.withOpacity(0.4)));

    // Ana lokma: parabolik yörüngeyle havaya fırlar, dönerek tabağa düşer
    final restFood = Offset(plateC.dx, s * 0.645 - s * 0.012);
    final u = _morselFlight;
    if (u == null) {
      canvas.drawCircle(Offset(plateC.dx, plateC.dy - s * 0.012), s * 0.038, _fill(typeColor.withOpacity(0.7)));
    } else {
      final y0 = restFood.dy - s * 0.05; // fırlatıldığı an tabak yukarıdaydı
      final y1 = restFood.dy;
      final y = y0 * (1 - u) + y1 * u - s * 0.16 * 4 * u * (1 - u);
      final x = restFood.dx + s * 0.012 * math.sin(math.pi * u);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(u * 1.5 * math.pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.080, height: s * 0.064),
        _fill(typeColor.withOpacity(0.75)),
      );
      // Dönüşün görünmesi için küçük parlak nokta
      canvas.drawCircle(Offset(s * 0.018, -s * 0.012), s * 0.008, _fill(Colors.white.withOpacity(0.7)));
      canvas.restore();
    }
  }

  void _drawMug(Canvas canvas, double s) {
    final mugC = Offset(s * 0.252, s * 0.640);
    final mW = s * 0.110, mH = s * 0.120;

    // Kupa gövdesi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: mugC, width: mW, height: mH),
        const Radius.circular(6),
      ),
      _fill(const Color(0xFFEEEEEE)),
    );

    // İçecek yüzeyi
    canvas.drawOval(
      Rect.fromCenter(center: Offset(mugC.dx, mugC.dy - mH * 0.36), width: mW * 0.82, height: mH * 0.22),
      _fill(typeColor.withOpacity(0.55)),
    );

    // Kulp
    canvas.drawArc(
      Rect.fromCenter(center: Offset(mugC.dx + mW * 0.62, mugC.dy), width: mW * 0.65, height: mH * 0.60),
      -math.pi / 2, math.pi, false,
      _stroke(const Color(0xFFDDDDDD), s * 0.020),
    );

    // Buhar: sin dalgasıyla sağa-sola kıvrılarak yükselir, yukarı çıktıkça
    // opaklığı 1.0'dan 0'a düşer. Faz zamanla kaydığı için dalga yukarı akar.
    const segs = 12;
    final h = s * 0.15;
    final topY = mugC.dy - mH * 0.52;
    for (var i = 0; i < 2; i++) {
      final baseX = mugC.dx + (i == 0 ? -s * 0.018 : s * 0.018);
      Offset pt(double f) => Offset(
            baseX + math.sin(f * 3 * math.pi - time * 3.0 + i * 1.7) *
                s * 0.014 * (0.5 + f),
            topY - f * h,
          );
      for (var k = 0; k < segs; k++) {
        final f0 = k / segs, f1 = (k + 1) / segs;
        final opacity = 1.0 - f1; // tabanda ~1.0, tepede 0
        if (opacity <= 0.01) continue;
        canvas.drawLine(
          pt(f0), pt(f1),
          _stroke(Colors.white.withOpacity(opacity), s * 0.013 * (1 - 0.4 * f0)),
        );
      }
    }
  }

  void _drawHikingStick(Canvas canvas, double s) {
    // Sol elin anlık konumunu _drawArms ile aynı formülle hesapla
    final swing = math.sin(anim * math.pi) * s * 0.03;
    final handX = s * 0.295 + swing;
    final handY = s * 0.660;
    // Baston el noktasından yere uzanıyor (sol-aşağı yönde)
    final tipX = handX - s * 0.055;
    final tipY = s * 0.895;
    canvas.drawLine(
      Offset(handX, handY),
      Offset(tipX, tipY),
      _stroke(const Color(0xFF8B5E3C), s * 0.022),
    );
    // Metal uç
    canvas.drawCircle(Offset(tipX, tipY), s * 0.013, _fill(const Color(0xFF555555)));
  }

  // ── Animasyonlu aksesuarlar ────────────────────────────────────────────────

  void _drawAccents(Canvas canvas, double s) {
    if (searchMode) {
      // Arama modunda tip-spesifik aksesuarlar yerine zemin nokta efektleri
      _drawSearchTrail(canvas, s);
      return;
    }
    switch (type) {
      case PersonalityType.sosyalKelebek:
        // Balonlar paint() içinde gövde grubunun dışında çizilir
        break;
      case PersonalityType.entelektuel:
        _drawIdeaBubbles(canvas, s);
        break;
      case PersonalityType.gurme:
        _drawFoodSparkles(canvas, s);
        break;
      case PersonalityType.maceraperest:
        _drawParachute(canvas, s);
        break;
      default:
        break;
    }
  }

  /// Yürürken ayakların gerisinde kalan küçük renk noktaları —
  /// karakterin hareket ettiğini anlatan zemin izi.
  void _drawSearchTrail(Canvas canvas, double s) {
    final baseY = s * 0.950;
    final offsets = [-s * 0.12, -s * 0.22, -s * 0.32];
    for (var i = 0; i < offsets.length; i++) {
      final phase = (anim + i * 0.28) % 1.0;
      // Dururken (inceleme / büyüteci alma) hareket izi solar
      final opacity = (1.0 - phase) * 0.35 * (1 - _stillAmt);
      final r = s * 0.012 * (1.0 - phase * 0.5);
      canvas.drawCircle(
        Offset(s * 0.50 + offsets[i], baseY),
        r,
        _fill(typeColor.withOpacity(opacity)),
      );
    }
  }

  // ── Paraşüt (maceraperest) ────────────────────────────────────────────────
  // Opaklık sin(anim·π): yüksekte (anim≈0.5) tam görünür,
  // yere değerken (anim≈0 veya ≈1) sıfıra solar → doğal iniş hissi.
  void _drawParachute(Canvas canvas, double s) {
    // İniş tamamlandıysa (bob animasyonu) paraşüt hiç çizilmez.
    if (landed) return;

    final cx = s * _cx;

    // Tek seferlik iniş: anim=0.85→1.0 arasında solar, sonra tamamen kaybolur.
    // anim=0'dan 0.85'e kadar tam görünür; 0.85'te solar, 1.0'da sıfır.
    final opacity = ((1.0 - anim) / 0.15).clamp(0.0, 1.0);
    if (opacity < 0.02) return;

    const domeRed   = Color(0xFFE53935); // kırmızı panel
    const domeWhite = Color(0xFFF5F5F5); // beyaz panel
    const numPanels = 6;

    final domeCY = s * _domeCY; // kubbenin alt merkezi (ip bağlantı hizası)
    final domeR  = s * _domeR;  // yarıçap — tamamı dairesel çerçeve içinde

    // ── 6 dilimli kubbe ───────────────────────────────────────────────────────
    // sweepAngle pozitif → saat yönü → sol(π)→ tepe(3π/2)→ sağ(0): ÜST YAY ✓
    for (var i = 0; i < numPanels; i++) {
      final pStart = math.pi + i * (math.pi / numPanels);
      final pSweep = math.pi / numPanels;
      final color  = (i % 2 == 0) ? domeRed : domeWhite;

      final p = Path()..moveTo(cx, domeCY);
      p.arcTo(
        Rect.fromCircle(center: Offset(cx, domeCY), radius: domeR),
        pStart, pSweep, false,
      );
      p.close();
      canvas.drawPath(p, _fill(color.withOpacity(opacity * 0.92)));
    }

    // Dış hat
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, domeCY), radius: domeR),
      math.pi, math.pi, false, // sol → tepe → sağ (pozitif sweep)
      _stroke(_hairDark.withOpacity(opacity * 0.35), s * 0.009),
    );

    // Dilim ayırıcı çizgiler (merkez → kubbe kenarı)
    for (var i = 0; i <= numPanels; i++) {
      final angle = math.pi + i * (math.pi / numPanels);
      canvas.drawLine(
        Offset(cx, domeCY),
        Offset(cx + domeR * math.cos(angle), domeCY + domeR * math.sin(angle)),
        _stroke(_hairDark.withOpacity(opacity * 0.18), s * 0.007),
      );
    }

    // Tepe hava deliği
    canvas.drawCircle(
      Offset(cx, domeCY - domeR + s * 0.015),
      s * 0.013,
      _fill(domeWhite.withOpacity(opacity * 0.90)),
    );

    // ── İpler: kubbenin alt kenarından karakter göğsüne ──────────────────────
    final stringP = _stroke(
      const Color(0xFF5D4037).withOpacity(opacity * 0.65),
      s * 0.009,
    );
    const hY = 0.555; // göğüs / harness hizası

    canvas.drawLine(Offset(cx - domeR,        domeCY), Offset(s * 0.378, s * hY), stringP);
    canvas.drawLine(Offset(cx - domeR * 0.52, domeCY), Offset(s * 0.442, s * hY), stringP);
    canvas.drawLine(Offset(cx - domeR * 0.08, domeCY), Offset(s * 0.492, s * hY), stringP);
    canvas.drawLine(Offset(cx + domeR * 0.08, domeCY), Offset(s * 0.508, s * hY), stringP);
    canvas.drawLine(Offset(cx + domeR * 0.52, domeCY), Offset(s * 0.558, s * hY), stringP);
    canvas.drawLine(Offset(cx + domeR,        domeCY), Offset(s * 0.622, s * hY), stringP);
  }

  void _drawButterflies(Canvas canvas, double s) {
    // Faz farkıyla (staggered) beliren balonlar: scale + opacity ile büyür,
    // yukarı süzülür, solarak kaybolur; sonra yeniden doğar.
    const positions = [
      Offset(0.170, 0.340),
      Offset(0.800, 0.300),
      Offset(0.735, 0.460),
    ];
    final sizes = [s * 0.055, s * 0.045, s * 0.035];
    const opacities = [0.85, 0.65, 0.50];
    const cycle = 2.8;

    for (var i = 0; i < 3; i++) {
      final ph = ((time + seed * 0.1) / cycle + i / 3.0) % 1.0;
      final appear = Curves.easeOutBack.transform((ph / 0.22).clamp(0.0, 1.0));
      final fade = ph < 0.65 ? 1.0 : (1.0 - (ph - 0.65) / 0.35).clamp(0.0, 1.0);
      final rise = Curves.easeOut.transform(ph) * s * 0.12;
      final drift = math.sin(ph * 2 * math.pi + i) * s * 0.012;
      final r = sizes[i] * appear;
      if (r < 0.5 || fade <= 0.01) continue;
      _butterfly(
        canvas,
        Offset(s * positions[i].dx + drift, s * positions[i].dy - rise),
        r,
        typeColor.withOpacity(opacities[i] * fade),
      );
    }
  }

  void _butterfly(Canvas canvas, Offset center, double r, Color color) {
    final p = _fill(color);
    // Üst kanatlar
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx - r, center.dy - r * 0.45), width: r * 1.35, height: r), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx + r, center.dy - r * 0.45), width: r * 1.35, height: r), p);
    // Alt kanatlar (daha küçük)
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx - r * 0.7, center.dy + r * 0.30), width: r * 0.90, height: r * 0.65), _fill(color.withOpacity(color.opacity * 0.65)));
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx + r * 0.7, center.dy + r * 0.30), width: r * 0.90, height: r * 0.65), _fill(color.withOpacity(color.opacity * 0.65)));
    // Gövde
    canvas.drawCircle(center, r * 0.13, _fill(_hairDark.withOpacity(0.55)));
  }

  void _drawIdeaBubbles(Canvas canvas, double s) {
    final pts = [
      Offset(s * 0.140, s * 0.200),
      Offset(s * 0.820, s * 0.230),
      Offset(s * 0.830, s * 0.380),
    ];
    final rs = [s * 0.025, s * 0.018, s * 0.015];

    for (var i = 0; i < 3; i++) {
      final yOff = math.sin((anim + i * 0.33) * math.pi) * s * 0.022;
      canvas.drawCircle(
        Offset(pts[i].dx, pts[i].dy + yOff),
        rs[i],
        _fill(typeColor.withOpacity(0.40 - i * 0.10)),
      );
    }
  }

  void _drawFoodSparkles(Canvas canvas, double s) {
    // Tabaktan yükselen küçük parıltılar
    final sparkP = _fill(typeColor.withOpacity(0.45));
    final positions = [
      Offset(s * 0.240, s * 0.540),
      Offset(s * 0.260, s * 0.510),
      Offset(s * 0.280, s * 0.525),
    ];
    final animOff = anim * s * 0.030;
    for (final pos in positions) {
      canvas.drawCircle(Offset(pos.dx, pos.dy - animOff), s * 0.012, sparkP);
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) =>
      old.anim != anim || old.type != type || old.gender != gender ||
      old.landed != landed || old.searchMode != searchMode ||
      old.inspect != inspect || old.pickup != pickup ||
      old.showBackground != showBackground || old.time != time ||
      old.walkAmount != walkAmount || old.celebrate != celebrate ||
      old.highFive != highFive;
}
