import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Uyumluluk Kartı ───────────────────────────────────────────────────────────

class CompatibilityCard extends StatelessWidget {
  final UserFriendModel friend;
  final int score;

  const CompatibilityCard({super.key, required this.friend, required this.score});

  Color _scoreColor(BuildContext context) {
    if (score >= 85) return context.colors.success;
    if (score >= 70) return context.colors.primary;
    return context.colors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (friend.personalityProfile != null)
                  Text(
                    '${friend.personalityProfile!.dominantType.emoji} ${friend.personalityProfile!.dominantType.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '%$score',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(context),
                ),
              ),
              Text(
                'match.compatibility'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
