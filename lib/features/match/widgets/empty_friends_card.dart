import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

// ── Boş Arkadaş Kartı ────────────────────────────────────────────────────────

class EmptyFriendsCard extends StatelessWidget {
  const EmptyFriendsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, color: context.colors.hint),
          SizedBox(width: 12),
          Text(
            'match.add_friend_hint'.tr(),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
