import 'package:flutter/material.dart';

// ── Iconsax'ta karşılığı olmayan çizgi ikonlar ───────────────────────────────
//
// Iconsax setinde kokteyl kadehi yok. Bu ikon Iconsax "linear" stiliyle
// birebir aynı ölçülerde çiziliyor: 24×24 tuval, 1.5 kalınlık, yuvarlak uç
// ve köşeler — diğer ikonların yanında yabancı durmaz.

class CocktailIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const CocktailIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CocktailPainter(c)),
    );
  }
}

class _CocktailPainter extends CustomPainter {
  final Color color;
  const _CocktailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Kadeh (üçgen), sıvı çizgisi, sap ve taban
    final glass = Path()
      ..moveTo(4, 3.5)
      ..lineTo(20, 3.5)
      ..lineTo(12, 12.5)
      ..close();
    canvas.drawPath(glass, p);
    canvas.drawLine(const Offset(6.6, 6.5), const Offset(17.4, 6.5), p);
    canvas.drawLine(const Offset(12, 12.5), const Offset(12, 20.5), p);
    canvas.drawLine(const Offset(8, 20.5), const Offset(16, 20.5), p);
  }

  @override
  bool shouldRepaint(_CocktailPainter old) => old.color != color;
}
