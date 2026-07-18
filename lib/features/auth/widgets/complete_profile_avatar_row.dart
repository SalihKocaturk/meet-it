import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

/// Google ile giren kullanıcının adını ve (varsa) profil fotoğrafını gösterir.
///
/// Kullanıcı adı boşsa hiçbir şey render edilmez.
class CompleteProfileAvatarRow extends ConsumerWidget {
  const CompleteProfileAvatarRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colors.primary.withOpacity(0.15),
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Icon(Iconsax.profile_circle, color: context.colors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
