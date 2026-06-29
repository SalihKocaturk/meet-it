import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Arkadaş Chip ─────────────────────────────────────────────────────────────

class FriendChip extends ConsumerWidget {
  final UserFriendModel friend;

  const FriendChip({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedUid = ref.watch(selectedFriendUidProvider);
    final isSelected = selectedUid == friend.uid;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          ref.read(selectedFriendUidProvider.notifier).state = null;
        } else {
          ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: context.colors.primary, width: 2.5)
                  : null,
            ),
            child: CircularAvatar(
              name: friend.name,
              photoUrl: friend.photoUrl,
              radius: 28,
            ),
          ),
          SizedBox(height: 4),
          Text(
            friend.name.split(' ').first,
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? context.colors.primary
                  : context.colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (friend.personalityProfile != null)
            Text(
              friend.personalityProfile!.dominantType.emoji,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}
