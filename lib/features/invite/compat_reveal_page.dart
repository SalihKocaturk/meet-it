import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

/// Davetle gelen kullanıcı testini bitirince açılan uyum ekranı:
/// "Salih ile %84 uyumlusunuz 🎉" + "Hemen ortak mekan bulun".
class CompatRevealPage extends ConsumerWidget {
  final UserModel inviter;
  final int compat;

  const CompatRevealPage({
    super.key,
    required this.inviter,
    required this.compat,
  });

  String _verdictKey() {
    if (compat >= 85) return 'invite.verdict_great';
    if (compat >= 70) return 'invite.verdict_good';
    return 'invite.verdict_diff';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tr = context.locale.languageCode == 'tr';
    final inviterName =
        titleCaseName(inviter.name.split(' ').first, turkish: tr);
    final myType = me?.personalityProfile?.dominantType;
    final theirType = inviter.personalityProfile?.dominantType;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1512),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ),
              const Spacer(),
              // İki avatar üst üste binerek
              SizedBox(
                width: 156,
                height: 92,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: _RingAvatar(
                        name: me?.name ?? '',
                        photoUrl: me?.photoUrl,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: _RingAvatar(
                        name: inviter.name,
                        photoUrl: inviter.photoUrl,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'invite.reveal_title'.tr(namedArgs: {'name': inviterName}),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              // Yüzde 0'dan yukarı sayarak gelir
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: compat.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(
                  '%${v.round()}',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Emerald.light,
                    letterSpacing: -2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                _verdictKey().tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (myType != null && theirType != null) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TypeChip(label: '${myType.emoji} ${myType.displayName}'),
                    _TypeChip(
                      label: '${theirType.emoji} ${theirType.displayName}',
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Text(
                'invite.reveal_friends_now'.tr(namedArgs: {'name': inviterName}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Buluşma sekmesine, arkadaş seçili olarak git.
                    ref.read(selectedFriendUidProvider.notifier).state =
                        inviter.uid;
                    ref.read(showVenuesProvider.notifier).state = false;
                    ref.read(mainTabIndexProvider.notifier).state = 1;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Emerald.base,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'invite.reveal_cta'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'invite.reveal_later'.tr(),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _RingAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Emerald.base,
      ),
      child: CircularAvatar(
        name: name,
        photoUrl: photoUrl,
        radius: 43,
        outline: false,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
