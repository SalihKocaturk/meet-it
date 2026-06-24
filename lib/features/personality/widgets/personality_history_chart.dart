import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// [PersonalityProfile] skorlarının ZAMAN İÇİNDEKİ değişimini gösteren
/// çizgi grafik + lejant bileşeni.
///
/// Solda her kişilik tipi için bir çizgi çizen bir grafik, sağda ise her
/// tipin rengini/ismini ve geçmişteki İLK kayıttan ŞİMDİKİ kayda kadar
/// puanının ne kadar arttığını/azaldığını (▲/▼ + yüzde puan) gösteren bir
/// lejant bulunuyor — kullanıcı "kişiliğim zamanla nasıl değişiyor, hangi
/// tip artıyor hangisi azalıyor" sorusunu burada tek bakışta görebiliyor.
///
/// [history] en az 2 kayıt içermiyorsa (örn. henüz hiç mekan ziyareti
/// üzerinden evrim yaşanmamışsa) çizgi grafik yerine bilgilendirici bir
/// boş durum gösterilir — bir tek noktadan "değişim" çizilemez.
class PersonalityHistoryChart extends StatelessWidget {
  final List<PersonalityProfile> history;

  const PersonalityHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart, color: context.colors.hint, size: 28),
            const SizedBox(height: 8),
            Text(
              'personality_analysis.history_empty'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'personality_analysis.history_title'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'personality_analysis.history_subtitle'.tr(
              namedArgs: {'count': '${history.length}'},
            ),
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 14),
          // ── Sol: çizgi grafik │ Sağ: tip + renk + artış/azalış lejantı ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: _HistoryLinePainter(
                      history: history,
                      gridColor: context.colors.border,
                      labelColor: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: PersonalityType.values
                      .map((t) => _HistoryLegendRow(type: t, history: history))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Tarih aralığı (ilk kayıt → son kayıt) ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(history.first.lastUpdated),
                style: TextStyle(fontSize: 10, color: context.colors.hint),
              ),
              Text(
                _formatDate(history.last.lastUpdated),
                style: TextStyle(fontSize: 10, color: context.colors.hint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// Belirli bir tipin rengini hex string'den ([PersonalityTypeX.colorHex])
/// gerçek bir [Color]'a çevirir.
Color _typeColor(PersonalityType type) {
  final hex = type.colorHex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

// ── Lejant Satırı ────────────────────────────────────────────────────────────

class _HistoryLegendRow extends StatelessWidget {
  final PersonalityType type;
  final List<PersonalityProfile> history;

  const _HistoryLegendRow({required this.type, required this.history});

  @override
  Widget build(BuildContext context) {
    final first = history.first.scores[type] ?? 0.0;
    final last = history.last.scores[type] ?? 0.0;
    final deltaPoints = ((last - first) * 100).round();

    final IconData arrow;
    final Color arrowColor;
    if (deltaPoints > 0) {
      arrow = Icons.arrow_drop_up;
      arrowColor = const Color(0xFF2ECC71); // yeşil — artış
    } else if (deltaPoints < 0) {
      arrow = Icons.arrow_drop_down;
      arrowColor = const Color(0xFFE74C3C); // kırmızı — azalış
    } else {
      arrow = Icons.remove;
      arrowColor = context.colors.hint;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _typeColor(type),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.emoji} ${type.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Icon(arrow, size: 14, color: arrowColor),
                    Text(
                      deltaPoints == 0
                          ? '%0'
                          : '${deltaPoints > 0 ? '+' : ''}%$deltaPoints',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: arrowColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Çizgi Grafik ──────────────────────────────────────────────────────────────

class _HistoryLinePainter extends CustomPainter {
  final List<PersonalityProfile> history;
  final Color gridColor;
  final Color labelColor;

  _HistoryLinePainter({
    required this.history,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0; // %0/%50/%100 etiketleri için
    const bottomPad = 4.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    // ── Yatay ızgara çizgileri (%0, %25, %50, %75, %100) + etiketler ─────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight * i / 4);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width, y),
        gridPaint,
      );
      final percentLabel = TextPainter(
        text: TextSpan(
          text: '%${i * 25}',
          style: TextStyle(fontSize: 8.5, color: labelColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      percentLabel.paint(canvas, Offset(0, y - percentLabel.height / 2));
    }

    if (history.length < 2) return;

    final stepX = chartWidth / (history.length - 1);

    Offset pointFor(int index, double value) {
      final x = leftPad + stepX * index;
      final y = chartHeight - (chartHeight * value.clamp(0.0, 1.0));
      return Offset(x, y);
    }

    // ── Her kişilik tipi için bir çizgi çiz ───────────────────────────────
    for (final type in PersonalityType.values) {
      final linePaint = Paint()
        ..color = _typeColor(type)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = _typeColor(type);

      final path = Path();
      for (var i = 0; i < history.length; i++) {
        final value = history[i].scores[type] ?? 0.0;
        final p = pointFor(i, value);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      // Son noktayı vurgula (şu anki skor).
      final lastValue = history.last.scores[type] ?? 0.0;
      canvas.drawCircle(pointFor(history.length - 1, lastValue), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryLinePainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
