import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/features/match/utils/venue_type_style.dart';

// ── Mekan Tipine Özel Harita Pini ─────────────────────────────────────────────
//
// Profildeki Kaydedilenler / Tarifi Alınanlar harita görünümünde kullanılan
// özel pin: yumuşak gölgeli, tipin rengine göre gradyanlı damla şekli;
// ortasında beyaz bir daire ve içinde tipin ikonu (kafe → kahve fincanı,
// restoran → çatal-bıçak, bar → kokteyl...). Seçili pin biraz daha büyük ve
// dışında ince bir parlama halkası var.
//
// `dart:ui` Canvas ile rasterize edilir; her (tip, seçili mi) çifti yalnızca
// BİR kez çizilip önbellekte tutulur. Boyut/`imagePixelRatio` mantığı
// MapMarkerBuilder._renderAvatarBitmap ile aynı (Retina ekranlarda pin'in
// dev görünmemesi için).
class VenueTypePin {
  VenueTypePin._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Normal pin genişliği (mantıksal piksel). Yükseklik ≈ genişlik × 1.3.
  static const double _baseWidth = 44;
  static const double _selectedWidth = 56;

  static Future<BitmapDescriptor> get(
    VenueTypeStyle style, {
    bool selected = false,
  }) async {
    final cacheKey = '${style.key}|$selected';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    try {
      final icon = await _render(style, selected: selected);
      _cache[cacheKey] = icon;
      return icon;
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }

  static Future<BitmapDescriptor> _render(
    VenueTypeStyle style, {
    required bool selected,
  }) async {
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final logicalW = selected ? _selectedWidth : _baseWidth;
    // Gölge ve parlama halkası için kenarlarda pay bırakılıyor.
    final pad = 6.0 * dpr;
    final w = logicalW * dpr;
    final r = w / 2; // baş kısmının yarıçapı
    final tipDepth = r * 0.62; // dairenin altından sivri uca olan mesafe
    final canvasW = w + pad * 2;
    final canvasH = w + tipDepth + pad * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    final center = Offset(canvasW / 2, pad + r);
    final tip = Offset(canvasW / 2, pad + w + tipDepth - pad * 0.2);
    final pinPath = _teardrop(center, r, tip);

    // 1) Yumuşak gölge
    canvas.save();
    canvas.translate(0, 2.0 * dpr);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.2 * dpr),
    );
    canvas.restore();

    // 2) Seçiliyse dış parlama halkası
    if (selected) {
      canvas.drawCircle(
        center,
        r + 3.2 * dpr,
        Paint()..color = style.color.withValues(alpha: 0.30),
      );
    }

    // 3) Gradyanlı gövde
    final bodyRect = Rect.fromLTRB(
      center.dx - r,
      center.dy - r,
      center.dx + r,
      tip.dy,
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..shader = ui.Gradient.linear(
          bodyRect.topLeft,
          bodyRect.bottomRight,
          [style.color, style.colorDark],
        ),
    );

    // 4) İnce beyaz dış kontur — koyu harita stilinde de pin net ayrışsın
    canvas.drawPath(
      pinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * dpr
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // 5) İç beyaz daire
    final innerR = r * 0.66;
    canvas.drawCircle(center, innerR, Paint()..color = Colors.white);

    // 6) Tip ikonu (Material ikon fontundan glif olarak çizilir)
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(style.icon.codePoint),
        style: TextStyle(
          fontSize: innerR * 1.25,
          fontFamily: style.icon.fontFamily,
          package: style.icon.fontPackage,
          color: style.colorDark,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.round(), canvasH.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  /// Daire + sivri uçtan oluşan, teğetleri yumuşak birleşen damla şekli.
  static Path _teardrop(Offset c, double r, Offset tip) {
    final d = tip.dy - c.dy; // merkezden uca uzaklık (> r)
    // Uçtan daireye çizilen teğetlerin daireye değdiği açı.
    final theta = math.acos(r / d);
    // Aşağı yön = pi/2. Teğet noktaları bu yönden ±theta sapmada.
    const down = math.pi / 2;
    final rightAngle = down - theta;
    final leftAngle = down + theta;
    final rightPoint = Offset(
      c.dx + r * math.cos(rightAngle),
      c.dy + r * math.sin(rightAngle),
    );

    final path = Path()..moveTo(tip.dx, tip.dy);
    // Uçtan sağ teğet noktasına (hafif içbükey, yumuşak)
    path.quadraticBezierTo(
      c.dx + r * 0.18,
      tip.dy - (tip.dy - rightPoint.dy) * 0.35,
      rightPoint.dx,
      rightPoint.dy,
    );
    // Daire üzerinden (üstten dolaşarak) sol teğet noktasına
    path.arcTo(
      Rect.fromCircle(center: c, radius: r),
      rightAngle,
      -(2 * math.pi - (leftAngle - rightAngle)),
      false,
    );
    // Sol teğetten uca
    final leftPoint = Offset(
      c.dx + r * math.cos(leftAngle),
      c.dy + r * math.sin(leftAngle),
    );
    path.quadraticBezierTo(
      c.dx - r * 0.18,
      tip.dy - (tip.dy - leftPoint.dy) * 0.35,
      tip.dx,
      tip.dy,
    );
    path.close();
    return path;
  }

  /// Pin'in haritadaki çapa noktası (sivri uç) — `Marker.anchor` için.
  static Offset anchorFor({bool selected = false}) {
    final logicalW = selected ? _selectedWidth : _baseWidth;
    const pad = 6.0;
    final r = logicalW / 2;
    final tipDepth = r * 0.62;
    final canvasH = logicalW + tipDepth + pad * 2;
    final tipY = pad + logicalW + tipDepth - pad * 0.2;
    return Offset(0.5, tipY / canvasH);
  }
}
