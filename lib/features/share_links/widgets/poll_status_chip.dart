import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/features/share_links/poll.dart';

/// Oylama durumunu (canlı / kapandı / süresi doldu) gösteren küçük çip.
class PollStatusChip extends StatelessWidget {
  final PollStatus status;

  const PollStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PollStatus.live => ('poll.status_live'.tr(), Emerald.base),
      PollStatus.closed => (
        'poll.status_closed'.tr(),
        context.colors.textSecondary,
      ),
      PollStatus.expired => (
        'poll.status_expired'.tr(),
        const Color(0xFFF59E0B),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
