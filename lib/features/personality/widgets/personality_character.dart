// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  const PersonalityCharacterWidget({
    super.key,
    required this.type,
    this.gender,
    this.size = 220,
    this.searchMode = false,
    this.flipX = false,
  });

  @override
  State<PersonalityCharacterWidget> createState() =>
      _PersonalityCharacterWidgetState();
}

class _PersonalityCharacterWidgetState extends State<PersonalityCharacterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _landed = false; // maceraperest: iniş bitti mi?

  @override
  void initState() {
    super.initState();
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
      animation: _anim,
      builder: (context, _) {
        final charWidget = Container(
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
            ),
          ),
        );
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

  _CharacterPainter({
    required this.type,
    required this.gender,
    required this.anim,
    required this.typeColor,
    this.landed = false,
    this.searchMode = false,
  });

  // ── Sabit renkler ──────────────────────────────────────────────────────────

  static const _skin     = Color(0xFFFFCBA4);
  static const _hairDark = Color(0xFF3B2012);
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

    // ── Arka plan: translate dışında, sabit kalır ────────────────────────────
    // Arama modunda arka plan çizilmez; karakter sade şekilde yürür.
    if (!searchMode) _drawBackground(canvas, s);

    // ── Karakter animasyon ötelemesi ─────────────────────────────────────────
    // Maceraperest (iniş sırasında): tek seferlik büyük iniş.
    //   anim=0 → karakter 0.75s yukarıda (ayaklar ~%19'da görünür, kafa dışarı).
    //   anim=1 → normal konumda. Sonra (landed=true) diğerleri gibi sallanır.
    // Diğerleri: ±5px yukarı-aşağı sallanma.
    canvas.save();
    if (searchMode) {
      // Yürüme sırasında hafif yukarı-aşağı sekme (±3px, çift frekans)
      canvas.translate(0, -math.sin(anim * math.pi * 2) * 3.0);
    } else if (type == PersonalityType.maceraperest && !landed) {
      // Tek seferlik iniş: yukarıdan aşağıya süzülür
      canvas.translate(0, -s * 0.75 * (1 - anim));
    } else if (type == PersonalityType.maceraperest && landed) {
      // İniş bitti: tam sin dalgası → yukarı-aşağı sallanma (±4px)
      canvas.translate(0, math.sin(anim * 2 * math.pi) * 4.0);
    } else {
      // Diğer tipler: sin(anim·π) → küçük yukarı sallanma (±5px)
      canvas.translate(0, -math.sin(anim * math.pi) * 5.0);
    }

    _drawLegs(canvas, s);
    _drawTorso(canvas, s);
    _drawArms(canvas, s);
    _drawNeck(canvas, s);
    _drawHead(canvas, s);
    _drawHair(canvas, s);
    _drawFace(canvas, s);
    _drawProp(canvas, s);
    _drawAccents(canvas, s);

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

    plant(0.11, 0.90);
    plant(0.89, 0.90);
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
    // ÖNEMLI: Tüm gövde çizimleri y=0.510'dan (baş alt kenarı) başlar.
    // Daha önce y=0.465'ten başlıyordu → baş çemberinin yanlarından taşan typeColor
    // "sakal" görünümü veriyordu. Artık baş altında başlıyoruz = sıfır örtüşme.
    final cx = s * _cx;
    final bodyTop = s * 0.512; // baş alt kenarı (headCY + r = 0.395+0.115+0.002)

    if (gender == CharacterGender.female) {
      // ── Kadın: dar bluz + A-line etek ────────────────────────────────────────
      // Bluz: bodyTop'tan bele kadar, omuzu kapsar
      final blouseRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx - s * 0.115, bodyTop,
          cx + s * 0.115, s * 0.662,
        ),
        Radius.circular(s * 0.035),
      );
      canvas.drawRRect(blouseRect, _fill(typeColor));

      // A-line etek: bluz altından genişleyen trapezoid
      final skirtPath = Path()
        ..moveTo(cx - s * 0.108, s * 0.648)   // sol üst (bluz eni)
        ..lineTo(cx + s * 0.108, s * 0.648)   // sağ üst
        ..lineTo(cx + s * 0.172, s * 0.808)   // sağ alt (geniş)
        ..lineTo(cx - s * 0.172, s * 0.808)   // sol alt
        ..close();
      canvas.drawPath(skirtPath, _fill(typeColor.withOpacity(0.80)));

      // Kemer çizgisi
      canvas.drawLine(
        Offset(cx - s * 0.112, s * 0.650),
        Offset(cx + s * 0.112, s * 0.650),
        _stroke(_hairDark.withOpacity(0.15), s * 0.016),
      );
    } else {
      // ── Erkek / nötr: trapezoid gövde (üstte dar → belde ince → kalçada geniş)
      // Boyun genişliğinde (0.10s) başlar, omuzlarda (0.13s) açılır, belde (0.12s)
      // hafif kısar, kalçada (0.135s) tekrar açılır → bel görünümü sağlar
      final bodyPath = Path()
        ..moveTo(cx - s * 0.100, bodyTop)          // sol üst (dar — boyun hizası)
        ..lineTo(cx + s * 0.100, bodyTop)          // sağ üst
        ..lineTo(cx + s * 0.138, s * 0.788)        // sağ alt (geniş)
        ..lineTo(cx - s * 0.138, s * 0.788)        // sol alt
        ..close();
      canvas.drawPath(bodyPath, _fill(typeColor));
      // Omuz kanalı: üst kenarda ince yatay çizgi renk derinliği
      canvas.drawLine(
        Offset(cx - s * 0.100, bodyTop + s * 0.004),
        Offset(cx + s * 0.100, bodyTop + s * 0.004),
        _stroke(typeColor.withOpacity(0.4), s * 0.012),
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
      // Yürüme animasyonu: tüm tipler searchMode'da, maceraperest her zaman
      final walk = math.sin(anim * math.pi) * s * 0.045;
      final leftFoot  = Offset(s * 0.400 - walk, s * 0.912);
      final rightFoot = Offset(s * 0.580 + walk, s * 0.912);
      canvas.drawLine(Offset(s * 0.445, s * 0.747), leftFoot,  legP);
      canvas.drawLine(Offset(s * 0.555, s * 0.747), rightFoot, legP);
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
      final swing = math.sin(anim * math.pi) * s * 0.022;
      // Sağ: kol yukarı-içe kalkık (büyüteç yüzün üzerinde)
      canvas.drawLine(rs, Offset(s * 0.620, s * 0.432 - swing * 0.35), armP);
      // Sol: yürüme dengesi — sağın tersi yönde sallanır
      canvas.drawLine(ls, Offset(s * 0.285 - swing, s * 0.660), armP);
      return;
    }

    switch (type) {
      case PersonalityType.entelektuel:
        // Kitabı tutuyormuş gibi: öne doğru dirsek kıvırma
        canvas.drawLine(ls, Offset(s * 0.285, s * 0.625), armP);
        canvas.drawLine(Offset(s * 0.285, s * 0.625), Offset(s * 0.295, s * 0.660), armP);
        canvas.drawLine(rs, Offset(s * 0.715, s * 0.625), armP);
        canvas.drawLine(Offset(s * 0.715, s * 0.625), Offset(s * 0.700, s * 0.660), armP);
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
        // Sağ el çatal tutuyor (yukarı)
        canvas.drawLine(rs, Offset(s * 0.720, s * 0.390), armP);
        // Sol el tabak tutuyor (öne)
        canvas.drawLine(ls, Offset(s * 0.255, s * 0.625), armP);
        break;
    }
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
    final hairP = _fill(_hairDark);

    // ── Saç şapkası ───────────────────────────────────────────────────────────
    // addArc + lineTo + close() fill'i güvenilir değil; clipRect + drawCircle tercih edildi.
    // hairlineY: kaşlar headCY - s*0.037 = 0.358 → hairline 0.347'de (kaşların üstünde).
    const kH = 0.42; // hairline = headCY - r*kH
    final hairlineY = headCY - r * kH;                    // ≈ 0.347
    final hairlineX = r * math.sqrt(1 - kH * kH);        // ≈ r * 0.907 (hairline'ın baş kenarı)

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      cx - r - s * 0.01,
      headCY - r - s * 0.01,  // başın tepesinin biraz üstü
      cx + r + s * 0.01,
      hairlineY,               // tam hairline'da kes — yan saç buradan başlar
    ));
    // Dairenin yarıçapı tam r: hairlineY'de cap genişliği = hairlineX
    // → yan saçın moveTo noktasıyla piksel-mükemmel örtüşür, boşluk kalmaz.
    canvas.drawCircle(Offset(cx, headCY), r, hairP);
    canvas.restore();

    // ── Yan saç (kadın / nötr) ────────────────────────────────────────────────
    // Başlangıç noktası cap'in biraz ÜSTÜNDE (hairlineY - r*0.18):
    //   → cap ile piksel-mükemmel örtüşme garantisi (anti-aliasing gap yok).
    // İç kenar biraz baş çemberinin içine girer (r*0.92):
    //   → fazladan dolgunluk, sakal/overlap etkisi olmaz (cap üstünde cilt çizilir).
    if (gender == CharacterGender.female || gender == CharacterGender.neutral) {
      void sideHair(double dir) {
        final path = Path();

        // Başlangıç: hairline'ın biraz ÜSTÜ — cap ile örtüşerek gap'i kapatır
        final topY = hairlineY - r * 0.18;
        final topX = hairlineX * 0.94; // cap dairesinin bu y'deki genişliğine yakın

        path.moveTo(cx + dir * topX, topY);

        // Dış kenar: dolgun aşağı akış
        path.cubicTo(
          cx + dir * (hairlineX + s * 0.020), headCY,             // üst — geniş başlangıç
          cx + dir * (r + s * 0.042),          headCY + r * 0.55, // orta — en geniş
          cx + dir * (r + s * 0.026),          headCY + r * 1.00, // çene altı
        );
        // Alt kıvrım
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.008), headCY + r * 1.16,
          cx + dir * r,               headCY + r * 0.98,
        );
        // İç kenar: r'ye yakın kal, yukarı dön
        path.cubicTo(
          cx + dir * r,          headCY + r * 0.60,
          cx + dir * r,          headCY - r * 0.05,
          cx + dir * topX,       topY,               // aynı başlangıca dön
        );
        path.close();
        canvas.drawPath(path, hairP);
      }

      sideHair(-1); // sol
      sideHair(1);  // sağ
    }

    // Erkek / nötr male: sadece cap — şakak oval yok (kafadan çıkar görünüyordu)
  }

  // ── Yüz ───────────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas, double s) {
    final cx = s * _cx;
    final cy = s * 0.395;
    final isFemale = gender == CharacterGender.female;

    // ── Kaşlar (her cinsiyet, şekil farklı) ──────────────────────────────────
    final browP = _stroke(_hairDark.withOpacity(0.85), s * 0.012);
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
    canvas.drawCircle(Offset(cx - s * 0.042, cy - s * 0.008), eyeR, _fill(_hairDark));
    canvas.drawCircle(Offset(cx + s * 0.042, cy - s * 0.008), eyeR, _fill(_hairDark));

    // Göz parıltısı
    canvas.drawCircle(Offset(cx - s * 0.038, cy - s * 0.014), s * 0.006, _fill(Colors.white.withOpacity(0.8)));
    canvas.drawCircle(Offset(cx + s * 0.046, cy - s * 0.014), s * 0.006, _fill(Colors.white.withOpacity(0.8)));

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
    }

    // ── Kirpikler (sadece kadın) ──────────────────────────────────────────────
    if (isFemale) {
      final lashP = _stroke(_hairDark, s * 0.008);
      void lashes(double ex, double ey) {
        final top = ey - eyeR;
        // 3 kirpik: dış, orta, iç
        canvas.drawLine(Offset(ex - s * 0.012, top + s * 0.002), Offset(ex - s * 0.018, top - s * 0.015), lashP);
        canvas.drawLine(Offset(ex,             top             ), Offset(ex,             top - s * 0.018), lashP);
        canvas.drawLine(Offset(ex + s * 0.012, top + s * 0.002), Offset(ex + s * 0.016, top - s * 0.015), lashP);
      }
      lashes(cx - s * 0.042, cy - s * 0.008);
      lashes(cx + s * 0.042, cy - s * 0.008);
    }

    // ── Gülümseme ────────────────────────────────────────────────────────────
    // Kadın: biraz daha küçük ve şirin; erkek: standart
    final smileW = isFemale ? s * 0.030 : s * 0.038;
    final smileH = isFemale ? s * 0.048 : s * 0.056;
    final smilePath = Path();
    smilePath.moveTo(cx - smileW, cy + s * 0.030);
    smilePath.quadraticBezierTo(cx, cy + smileH, cx + smileW, cy + s * 0.030);
    canvas.drawPath(smilePath, _stroke(const Color(0xFFBB7755), s * 0.014));

    // ── Yanak pembesi ────────────────────────────────────────────────────────
    final cheekOpacity = isFemale ? 0.45 : 0.30;
    canvas.drawCircle(Offset(cx - s * 0.068, cy + s * 0.022), s * 0.021, _fill(const Color(0xFFFFAA88).withOpacity(cheekOpacity)));
    canvas.drawCircle(Offset(cx + s * 0.068, cy + s * 0.022), s * 0.021, _fill(const Color(0xFFFFAA88).withOpacity(cheekOpacity)));
  }

  // ── Aksesuarlar (prop) ────────────────────────────────────────────────────

  void _drawProp(Canvas canvas, double s) {
    if (searchMode) {
      _drawSearchMagnifier(canvas, s);
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
    final swing = math.sin(anim * math.pi) * s * 0.022;

    // Sapın başladığı nokta (sağ el) — _drawArms ile senkron
    final handleBase = Offset(s * 0.620, s * 0.432 - swing * 0.35);
    // Mercek merkezi — yüzün üzerinde, sağ göz bölgesinde
    final lensC = Offset(s * 0.548, s * 0.370 - swing * 0.35);
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
    for (var i = 0; i < 2; i++) {
      final t = (anim + i * 0.5) % 1.0; // 0→1, ofsetli
      final r = lensR * (1.0 + t * 0.90);
      final opacity = (1.0 - t) * 0.30;
      canvas.drawCircle(
        lensC, r,
        _stroke(typeColor.withOpacity(opacity), s * 0.007),
      );
    }
  }

  void _drawBook(Canvas canvas, double s) {
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
    // Çatal (sağ el yukarıda)
    final forkX = s * 0.720, forkBot = s * 0.388, forkTop = s * 0.220;
    final forkP = _stroke(const Color(0xFFCCCCCC), s * 0.022);
    canvas.drawLine(Offset(forkX, forkBot), Offset(forkX, forkTop + s * 0.06), forkP);

    // Çatal dişleri
    final tineP = _stroke(const Color(0xFFCCCCCC), s * 0.014);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(forkX + i * s * 0.022, forkTop + s * 0.060),
        Offset(forkX + i * s * 0.022, forkTop),
        tineP,
      );
    }

    // Tabak (sol el)
    final plateC = Offset(s * 0.255, s * 0.645);
    canvas.drawCircle(plateC, s * 0.090, _fill(const Color(0xFFF0F0F0)));
    canvas.drawCircle(plateC, s * 0.090, _stroke(const Color(0xFFCCCCCC), s * 0.012));
    // Tabaktaki yemek lekesi
    canvas.drawCircle(Offset(plateC.dx, plateC.dy - s * 0.012), s * 0.038, _fill(typeColor.withOpacity(0.7)));
    canvas.drawCircle(Offset(plateC.dx + s * 0.030, plateC.dy + s * 0.018), s * 0.022, _fill(typeColor.withOpacity(0.5)));
    canvas.drawCircle(Offset(plateC.dx - s * 0.028, plateC.dy + s * 0.018), s * 0.018, _fill(typeColor.withOpacity(0.4)));
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

    // Buhar (animasyonlu)
    final steamOff = anim * s * 0.038;
    final steamP = _stroke(Colors.white.withOpacity(0.45 + anim * 0.25), s * 0.013);
    final st1 = Path()
      ..moveTo(mugC.dx - s * 0.018, mugC.dy - mH * 0.52 - steamOff)
      ..quadraticBezierTo(
        mugC.dx - s * 0.040, mugC.dy - mH * 0.72 - steamOff,
        mugC.dx - s * 0.010, mugC.dy - mH * 0.90 - steamOff,
      );
    canvas.drawPath(st1, steamP);
    final st2 = Path()
      ..moveTo(mugC.dx + s * 0.018, mugC.dy - mH * 0.52 - steamOff * 0.75)
      ..quadraticBezierTo(
        mugC.dx + s * 0.038, mugC.dy - mH * 0.70 - steamOff * 0.75,
        mugC.dx + s * 0.008, mugC.dy - mH * 0.88 - steamOff * 0.75,
      );
    canvas.drawPath(st2, steamP);
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
        _drawButterflies(canvas, s);
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
      final opacity = (1.0 - phase) * 0.35;
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

    final domeCY = s * 0.210; // kubbenin alt merkezi (ip bağlantı hizası)
    final domeR  = s * 0.240; // yarıçap — geniş, gerçekçi paraşüt profili

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
    final positions = [
      Offset(s * 0.140, s * 0.230),
      Offset(s * 0.790, s * 0.200),
      Offset(s * 0.745, s * 0.360),
    ];
    final offsets = [
      math.sin(anim * math.pi * 2) * s * 0.04,
      math.cos(anim * math.pi * 2) * s * 0.035,
      math.sin(anim * math.pi * 2 + 0.8) * s * 0.028,
    ];
    final sizes = [s * 0.055, s * 0.045, s * 0.035];
    final opacities = [0.85, 0.65, 0.45];

    for (var i = 0; i < 3; i++) {
      _butterfly(canvas, Offset(positions[i].dx, positions[i].dy + offsets[i]),
          sizes[i], typeColor.withOpacity(opacities[i]));
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
      old.landed != landed || old.searchMode != searchMode;
}
