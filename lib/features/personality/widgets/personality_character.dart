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

  const PersonalityCharacterWidget({
    super.key,
    required this.type,
    this.gender,
    this.size = 220,
  });

  @override
  State<PersonalityCharacterWidget> createState() =>
      _PersonalityCharacterWidgetState();
}

class _PersonalityCharacterWidgetState extends State<PersonalityCharacterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
        return Container(
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
            ),
          ),
        );
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

  _CharacterPainter({
    required this.type,
    required this.gender,
    required this.anim,
    required this.typeColor,
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

    // Tüm karakter hafifçe yukarı-aşağı yüzer
    final floatY = math.sin(anim * math.pi) * 5.0;
    canvas.save();
    canvas.translate(0, -floatY);

    _drawBackground(canvas, s);
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
    final leafP = _fill(typeColor.withOpacity(0.22));
    final stemP = _stroke(typeColor.withOpacity(0.30), s * 0.018);

    void plant(double bx, double by, double dir) {
      // Sap
      final stem = Path()
        ..moveTo(s * bx, s * by)
        ..quadraticBezierTo(s * (bx + dir * 0.04), s * (by - 0.10), s * (bx + dir * 0.02), s * (by - 0.18));
      canvas.drawPath(stem, stemP);
      // Yaprak
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * (bx + dir * 0.05), s * (by - 0.13)),
          width: s * 0.09, height: s * 0.05,
        ),
        leafP,
      );
    }

    plant(0.10, 0.88, -1);
    plant(0.88, 0.88,  1);
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
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * _cx, s * 0.615),
        width: s * 0.27, height: s * 0.30,
      ),
      const Radius.circular(s),
    );
    canvas.drawRRect(bodyRect, _fill(typeColor));
  }

  void _drawNeck(Canvas canvas, double s) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset(s * _cx, s * 0.470), width: s * 0.07, height: s * 0.055),
      _fill(_skin),
    );
  }

  // ── Bacaklar ve ayakkabılar ────────────────────────────────────────────────

  void _drawLegs(Canvas canvas, double s) {
    final legP = _stroke(_pants, s * 0.085);

    // Maceraperest yürüme hareketi
    if (type == PersonalityType.maceraperest) {
      final walk = math.sin(anim * math.pi) * s * 0.045;
      canvas.drawLine(
        Offset(s * 0.445, s * 0.747),
        Offset(s * 0.400 - walk, s * 0.895),
        legP,
      );
      canvas.drawLine(
        Offset(s * 0.555, s * 0.747),
        Offset(s * 0.580 + walk, s * 0.895),
        legP,
      );
    } else {
      canvas.drawLine(Offset(s * 0.445, s * 0.747), Offset(s * 0.405, s * 0.895), legP);
      canvas.drawLine(Offset(s * 0.555, s * 0.747), Offset(s * 0.590, s * 0.895), legP);
    }

    // Ayakkabılar
    final shoeP = _fill(_shoe);
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.400, s * 0.905), width: s * 0.11, height: s * 0.044), shoeP);
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.592, s * 0.905), width: s * 0.11, height: s * 0.044), shoeP);
  }

  // ── Kollar ─────────────────────────────────────────────────────────────────

  void _drawArms(Canvas canvas, double s) {
    final armP = _stroke(typeColor, s * 0.075);

    final ls = Offset(s * 0.365, s * 0.535); // sol omuz
    final rs = Offset(s * 0.635, s * 0.535); // sağ omuz

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
    final hairP = _fill(_hairDark);
    final cx = s * _cx;
    final headCY = s * 0.395;
    final r = s * 0.115;

    // Ortak: üst yarım daire (tüm cinsiyetler)
    final capPath = Path();
    capPath.addArc(
      Rect.fromCircle(center: Offset(cx, headCY), radius: r + s * 0.005),
      math.pi, math.pi, // üst yarım
    );
    capPath.lineTo(cx + r, headCY);
    capPath.lineTo(cx - r, headCY);
    capPath.close();
    canvas.drawPath(capPath, hairP);

    if (gender == CharacterGender.female || gender == CharacterGender.neutral) {
      // Uzun saç: sol ve sağ yanak kıvrımları
      void sideHair(double dir) {
        final path = Path();
        path.moveTo(cx + dir * r * 0.80, headCY - r * 0.55);
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.04), headCY + r * 0.20,
          cx + dir * (r + s * 0.02), headCY + r * 0.75,
        );
        path.quadraticBezierTo(
          cx + dir * r * 0.85, headCY + r * 0.80,
          cx + dir * r * 0.70, headCY + r * 0.60,
        );
        path.quadraticBezierTo(
          cx + dir * r * 1.05, headCY + r * 0.15,
          cx + dir * r * 0.78, headCY - s * 0.01,
        );
        path.close();
        canvas.drawPath(path, hairP);
      }

      sideHair(-1);
      sideHair(1);
    }

    if (gender == CharacterGender.male) {
      // Erkek: kısa yanlarda şakak
      final sideP = _fill(_hairDark);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - r + s * 0.012, headCY - s * 0.010), width: s * 0.038, height: s * 0.05),
        sideP,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + r - s * 0.012, headCY - s * 0.010), width: s * 0.038, height: s * 0.05),
        sideP,
      );
    }
  }

  // ── Yüz ───────────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas, double s) {
    final cx = s * _cx;
    final cy = s * 0.395;

    // Gözler
    canvas.drawCircle(Offset(cx - s * 0.042, cy - s * 0.010), s * 0.016, _fill(_hairDark));
    canvas.drawCircle(Offset(cx + s * 0.042, cy - s * 0.010), s * 0.016, _fill(_hairDark));

    // Göz parıltısı
    canvas.drawCircle(Offset(cx - s * 0.038, cy - s * 0.016), s * 0.006, _fill(Colors.white.withOpacity(0.8)));
    canvas.drawCircle(Offset(cx + s * 0.046, cy - s * 0.016), s * 0.006, _fill(Colors.white.withOpacity(0.8)));

    // Gülümseme
    final smilePath = Path();
    smilePath.moveTo(cx - s * 0.038, cy + s * 0.030);
    smilePath.quadraticBezierTo(cx, cy + s * 0.056, cx + s * 0.038, cy + s * 0.030);
    canvas.drawPath(smilePath, _stroke(const Color(0xFFBB7755), s * 0.016));

    // Yanak pembesi (opsiyonel, şirin görünüm)
    canvas.drawCircle(Offset(cx - s * 0.068, cy + s * 0.025), s * 0.020, _fill(const Color(0xFFFFAA88).withOpacity(0.35)));
    canvas.drawCircle(Offset(cx + s * 0.068, cy + s * 0.025), s * 0.020, _fill(const Color(0xFFFFAA88).withOpacity(0.35)));
  }

  // ── Aksesuarlar (prop) ────────────────────────────────────────────────────

  void _drawProp(Canvas canvas, double s) {
    switch (type) {
      case PersonalityType.entelektuel: _drawBook(canvas, s); break;
      case PersonalityType.gurme:       _drawForkAndPlate(canvas, s); break;
      case PersonalityType.sakinRuh:    _drawMug(canvas, s); break;
      case PersonalityType.maceraperest: _drawHikingStick(canvas, s); break;
      case PersonalityType.sosyalKelebek: break; // kelebekler accent'ta
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
    // Yürüyüş bastonunu sol elde tutuyor
    canvas.drawLine(
      Offset(s * 0.255, s * 0.645),
      Offset(s * 0.205, s * 0.900),
      _stroke(const Color(0xFF8B5E3C), s * 0.022),
    );
    // Uç nokta
    canvas.drawCircle(Offset(s * 0.205, s * 0.900), s * 0.013, _fill(const Color(0xFF555555)));
  }

  // ── Animasyonlu aksesuarlar ────────────────────────────────────────────────

  void _drawAccents(Canvas canvas, double s) {
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
      default:
        break;
    }
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
      old.anim != anim || old.type != type || old.gender != gender;
}
