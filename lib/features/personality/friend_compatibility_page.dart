import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_breakdown.dart';
import 'package:meetit/features/personality/widgets/personality_radar_chart.dart';

/// Arkadaş listesindeki herkesle kişilik uyumunu (cosine similarity tabanlı
/// `PersonalityProfile.compatibilityWith`) gösteren liste sayfası.
///
/// Profili olmayan (henüz quiz yapmamış) arkadaşlar listede görünür ama
/// devre dışı bırakılır — uyum hesaplanamaz çünkü kıyaslanacak bir profil
/// yok.
class FriendCompatibilityPage extends ConsumerWidget {
  const FriendCompatibilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentUserProvider)?.personalityProfile;
    final friends = ref.watch(connectionsProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'friend_compat.title'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: myProfile == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'match.no_profile_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
              )
            : friends.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'friends.no_friends_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _FriendCompatTile(
                      friend: friends[i],
                      myProfile: myProfile,
                    ),
                  ),
      ),
    );
  }
}

class _FriendCompatTile extends StatelessWidget {
  final UserFriendModel friend;
  final PersonalityProfile myProfile;

  const _FriendCompatTile({required this.friend, required this.myProfile});

  @override
  Widget build(BuildContext context) {
    final friendProfile = friend.personalityProfile;
    final hasProfile = friendProfile != null;
    final compat = hasProfile ? myProfile.compatibilityWith(friendProfile) : null;

    return Opacity(
      opacity: hasProfile ? 1 : 0.5,
      child: GestureDetector(
        onTap: hasProfile
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FriendCompatibilityDetailPage(
                      friend: friend,
                      myProfile: myProfile,
                      friendProfile: friendProfile,
                      compatibility: compat!,
                    ),
                  ),
                )
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              CircularAvatar(name: friend.name, photoUrl: friend.photoUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (hasProfile) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${friendProfile.dominantType.emoji} ${friendProfile.dominantType.displayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ] else
                      Text(
                        'friend_compat.no_profile'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasProfile) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '%$compat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: context.colors.hint, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detay Sayfası ─────────────────────────────────────────────────────────────

/// İki kullanıcının kişilik profillerini yan yana karşılaştıran detay sayfası.
class FriendCompatibilityDetailPage extends StatelessWidget {
  final UserFriendModel friend;
  final PersonalityProfile myProfile;
  final PersonalityProfile friendProfile;
  final int compatibility;

  const FriendCompatibilityDetailPage({
    super.key,
    required this.friend,
    required this.myProfile,
    required this.friendProfile,
    required this.compatibility,
  });

  String get _tierKey {
    if (compatibility >= 90) return 'friend_compat.tier_excellent';
    if (compatibility >= 80) return 'friend_compat.tier_great';
    if (compatibility >= 70) return 'friend_compat.tier_good';
    if (compatibility >= 60) return 'friend_compat.tier_medium';
    return 'friend_compat.tier_different';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          friend.name,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              // ── Uyum yüzdesi başlığı ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularAvatar(
                    name: 'common.user'.tr(),
                    radius: 26,
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, color: context.colors.primary, size: 22),
                  const SizedBox(width: 8),
                  CircularAvatar(
                    name: friend.name,
                    photoUrl: friend.photoUrl,
                    radius: 26,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'friend_compat.percent_match'.tr(namedArgs: {'percent': '$compatibility'}),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _tierKey.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Üst üste bindirilmiş radar chart ──────────────────────
              //
              // İki ayrı PersonalityBreakdown'daki skor çubukları yan yana
              // kıyaslamayı zorlaştırıyordu (yukarı-aşağı kaydırmak
              // gerekiyordu). Aynı radar üzerinde iki yarı saydam poligon
              // çizerek örtüşme/farklılık tek bakışta görülüyor.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'friend_compat.overlap_title'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PersonalityRadarChart(
                      profile: myProfile,
                      secondaryProfile: friendProfile,
                      primaryLabel: 'friend_compat.you_label'.tr(),
                      secondaryLabel: friend.name,
                      size: 240,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Senin profilin ────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'friend_compat.your_profile'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PersonalityBreakdown(profile: myProfile),

              const SizedBox(height: 24),

              // ── Arkadaşının profili ───────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'friend_compat.friend_profile'.tr(namedArgs: {'name': friend.name}),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PersonalityBreakdown(profile: friendProfile),
            ],
          ),
        ),
      ),
    );
  }
}
