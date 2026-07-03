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

    if (type == PersonalityType.maceraperest) {
      // Yürüme: her kare farklı konum — ayak uçları hesaplanıp ayakkabıya iletiliyor
      final walk = math.sin(anim * math.pi) * s * 0.045;
      final leftFoot  = Offset(s * 0.400 - walk, s * 0.895);
      final rightFoot = Offset(s * 0.580 + walk, s * 0.895);
      canvas.drawLine(Offset(s * 0.445, s * 0.747), leftFoot,  legP);
      canvas.drawLine(Offset(s * 0.555, s * 0.747), rightFoot, legP);
      // Ayakkabılar ayak ucunu takip ediyor
      canvas.drawOval(Rect.fromCenter(center: Offset(leftFoot.dx,  leftFoot.dy  + s * 0.008), width: s * 0.11, height: s * 0.044), shoeP);
      canvas.drawOval(Rect.fromCenter(center: Offset(rightFoot.dx, rightFoot.dy + s * 0.008), width: s * 0.11, height: s * 0.044), shoeP);
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
      hairlineY,               // hairline'ın altını kes
    ));
    canvas.drawCircle(Offset(cx, headCY), r + s * 0.006, hairP);
    canvas.restore();

    // ── Yan saç (kadın / nötr) ────────────────────────────────────────────────
    // Kök neden: eski iç kenar r*0.80–0.96 baş çemberinin IÇINE giriyordu
    // → yüzün yanında koyu alan = sakal görünümü.
    // Düzeltme: iç kenar tam cx ± r'da → baş çemberinin DIŞINDA, yüzle sıfır örtüşme.
    if (gender == CharacterGender.female || gender == CharacterGender.neutral) {
      void sideHair(double dir) {
        final path = Path();
        // Başlangıç: hairline seviyesindeki baş kenarı
        path.moveTo(cx + dir * hairlineX, hairlineY);

        // Dış kenar: aşağı ve dışa doğru genişleyen akış
        path.cubicTo(
          cx + dir * (hairlineX + s * 0.012), headCY,             // üst — dışa açılmaya başlar
          cx + dir * (r + s * 0.032),          headCY + r * 0.55, // orta — en geniş
          cx + dir * (r + s * 0.018),          headCY + r * 1.00, // çene altı
        );
        // Alt kıvrım
        path.quadraticBezierTo(
          cx + dir * (r + s * 0.006), headCY + r * 1.14, // alt uç
          cx + dir * r,               headCY + r * 0.98,  // iç alt — TAM baş kenarında
        );
        // İç kenar: cx ± r'da kal, yukarı dön — yüzle HİÇ örtüşmez
        // (headCY'nin üstünde baş çemberi daralır; r'de kalmak = çemberin dışında kalmak)
        path.cubicTo(
          cx + dir * r, headCY + r * 0.60,
          cx + dir * r, headCY - r * 0.05,
          cx + dir * hairlineX, hairlineY,  // hairline başlangıç noktasına dön
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
        Rect.fromLTRB