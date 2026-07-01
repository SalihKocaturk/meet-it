import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

// ── Ulaşım süresi chip'i ───────────────────────────────────────────────────
//
// Küçük, ikon + "~X dk" şeklinde bir etiket. Diğer rozetlerle (tip/puan/
// fiyat) aynı görsel dilde ama farklı bir nötr renkte (gri tonlu) tutuldu —
// bu bir TAHMİN olduğu için fiyat/puan gibi "kesin" bilgilerle aynı vurguda
// gösterilmemesi bilinçli bir seçim.
class TravelChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const TravelChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.textSecondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
