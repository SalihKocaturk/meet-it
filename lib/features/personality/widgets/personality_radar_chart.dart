import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// 5 eksenli (her [PersonalityType] için bir eksen) radar/spider chart.
///
/// Harici bir paket (fl_chart vb.) EKLEMEDEN, doğrudan [CustomPainter] ile
/// çiziliyor — proje zaten chart paketi kullanmıyordu, yeni bir bağımlılık
/// eklemek yerine basit bir 5-köşeli poligon çizimi yeterli.
///
/// Tek profil (örn. quiz sonucu, Kişilik Analizim sayfası) İÇİN
/// [profile] verilip [secondaryProfile] boş bırakılır. İki profili
/// karşılaştırmak için (Arkadaş Kişilik Uyumu sayfası) ikisi de verilir —
/// iki yarı-saydam poligon üst üste çizilir, örtüşme görsel olarak
/// kendiliğinden ortaya çıkar.
class PersonalityRadarChart extends StatelessWidget {
  final PersonalityProfile profile;
  final PersonalityProfile? secondaryProfile;

  /// Ana profilin etiketi (örn. "Sen") — sadece iki profil gösterilirken
  /// lejantta kullanılır.
  final String? primaryLabel;

  /// İkincil profilin etiketi (örn. arkadaşın adı).
  final String? secondaryLabel;

  final double size;

  const PersonalityRadarChart({
    super.key,
    required this.profile,
    this.secondaryProfile,
    this.primaryLabel,
    this.secondaryLabel,
    this.size = 260,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colors.primary;
    // İkincil profil rengi: temadan bağımsız sabit bir turuncu — birincil
    // mavi/ana renkle her zaman net ayrışsın diye kasıtlı olarak temaya
    // bağlı değil.
    const secondaryColor = Color(0xFFFF8A3D);

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RadarChartPainter(
              profile: profile,
              secondaryProfile: secondaryProfile,
              gridColor: context.colors.border,
              labelColor: context.colors.textSecondary,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
        ),
        if (secondaryProfile != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: primaryColor, label: primaryLabel ?? ''),
              const SizedBox(width: 20),
              _LegendDot(color: secondaryColor, label: secondaryLabel ?? ''),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final PersonalityProfile profile;
  final PersonalityProfile? secondaryProfile;
  final Color gridColor;
  final Color labelColor;
  final Color primaryColor;
  final Color secondaryColor;

  _RadarChartPainter({
    required this.profile,
    required this.secondaryProfile,
    required this.gridColor,
    required this.labelColor,
    required this.primaryColor,
    required this.secondaryColor,
  });

  static const _types = PersonalityType.values;
  static const _ringCount = 4; // %25 aralıklarla ızgara halkaları

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Etiketler için kenarlardan biraz boşluk bırak.
    final radius = math.min(size.width, size.height) / 2 - 36;
    final axisCount = _types.length;
    final angleStep = (2 * math.pi) / axisCount;
    // Üstten başla (saat 12 yönü), saat yönünde ilerle.
    const startAngle = -math.pi / 2;

    Offset pointFor(int index, double value) {
      final angle = startAngle + angleStep * index;
      final r = radius * value.clamp(0.0, 1.0);
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }

    // ── Izgara halkaları (%25, %50, %75, %100) ──────────────────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= _ringCount; ring++) {
      final ringValue = ring / _ringCount;
      final path = Path();
      for (var i = 0; i < axisCount; i++) {
        final p = pointFor(i, ringValue);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ── Merkezden eksenlere çizgiler ─────────────────────────────────────
    for (var i = 0; i < axisCount; i++) {
      final p = pointFor(i, 1.0);
      canvas.drawLine(center, p, gridPaint);
    }

    // ── Profil poligonu çizen yardımcı ───────────────────────────────────
    void drawProfile(PersonalityProfile p, Color color) {
      final fillPaint = Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()..color = color;

      final path = Path();
      final points = <Offset>[];
      for (var i = 0; i < axisCount; i++) {
        final value = p.scores[_types[i]] ?? 0.0;
        final pt = pointFor(i, value);
        points.add(pt);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
      for (final pt in points) {
        canvas.drawCircle(pt, 3.2, dotPaint);
      }
    }

    drawProfile(profile, primaryColor);
    if (secondaryProfile != null) {
      drawProfile(secondaryProfile!, secondaryColor);
    }

    // ── Eksen etiketleri (emoji + kısa isim) ─────────────────────────────
    for (var i = 0; i < axisCount; i++) {
      final type = _types[i];
      final labelPoint = pointFor(i, 1.18);
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${type.emoji}\n',
              style: const TextStyle(fontSize: 14),
            ),
            TextSpan(
              text: type.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 64);
      textPainter.paint(
        canvas,
        Offset(
          labelPoint.dx - textPainter.width / 2,
          labelPoint.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.profile != profile ||
        oldDelegate.secondaryProfile != secondaryProfile ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
