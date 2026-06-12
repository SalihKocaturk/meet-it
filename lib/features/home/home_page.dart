import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final connections = ref.watch(connectionsProvider);
    final invitationsCount = ref.watch(invitationsCountProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Üst başlık
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba, ${currentUser?.name.split(' ').first ?? 'Kullanıcı'}!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              Text(
                                'Arkadaşlarınla buluşmaya hazır mısın?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Davet Et ikonu
                        GestureDetector(
                          onTap: () => _showInviteSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.colors.primary.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_outlined,
                                  size: 16,
                                  color: context.colors.primary,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Davet Et',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircularAvatar(
                          name: currentUser?.name ?? 'K',
                          radius: 22,
                        ),
                      ],
                    ),
                    // Kişilik profili chip — varsa dominant tipi göster
                    if (currentUser?.personalityProfile != null) ...[
                      const SizedBox(height: 10),
                      _PersonalityChip(
                        type: currentUser!.personalityProfile!.dominantType,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Davet bildirimi banner
            if (invitationsCount > 0)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(mainTabIndexProvider.notifier).state = 1,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.colors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          color: context.colors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$invitationsCount yeni arkadaşlık isteğin var!',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: context.colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Özet istatistikler
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    _StatCard(
                      count: connections.length,
                      label: 'Bağlantı',
                      icon: Icons.people_outline,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      count: invitationsCount,
                      label: 'Bekleyen',
                      icon: Icons.hourglass_empty_outlined,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      count: 0,
                      label: 'Buluşma',
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                ),
              ),
            ),

            // Hızlı Arkadaş Ekle butonu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Arkadaşlarım',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).state = 1,
                      child: Text(
                        '+ Arkadaş Ekle',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Arkadaş listesi
            if (connections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyConnectionsView(
                  onAddFriends: () =>
                      ref.read(mainTabIndexProvider.notifier).state = 1,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _FriendCard(friend: connections[i]),
                    childCount: connections.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.colors.card,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Icon(
              Icons.group_add_outlined,
              size: 48,
              color: context.colors.primary,
            ),
            SizedBox(height: 12),
            Text(
              'Arkadaşlarını Davet Et',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kişisel bağlantını paylaşarak arkadaşlarını MeetIt\'e davet et. Birlikte buluşma noktaları keşfedin!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Davet linki kutusu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'meetit.app/invite/abc123',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'meetit.app/invite/abc123'),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Davet linki kopyalandı! 🔗'),
                          backgroundColor: context.colors.success,
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 20,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  'Paylaş',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Kişilik Tipi Chip ─────────────────────────────────────────────────────────
class _PersonalityChip extends StatelessWidget {
  final PersonalityType type;

  const _PersonalityChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.emoji, style: TextStyle(fontSize: 14)),
          SizedBox(width: 5),
          Text(
            type.displayName,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Kart ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.count,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.primary, size: 22),
            SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arkadaş Kartı ─────────────────────────────────────────────────────────────
class _FriendCard extends StatelessWidget {
  final UserFriendModel friend;

  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final daysAgo = DateTime.now().difference(friend.addedAt).inDays;
    final isOnline = daysAgo == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircularAvatar(
                name: friend.name,
                photoUrl: friend.photoUrl,
                radius: 24,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: context.colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  isOnline ? 'Online' : '$daysAgo gün önce görüldü',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline
                        ? context.colors.success
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Buluşma butonu — arkadaşı seç + match sekmesine geç
          Consumer(
            builder: (context, ref, _) => IconButton(
              icon: Icon(
                Icons.location_on_outlined,
                color: context.colors.primary,
                size: 22,
              ),
              onPressed: () {
                ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
                ref.read(mainTabIndexProvider.notifier).state = 2;
              },
              tooltip: 'Buluşma yeri bul',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Boş Durum ─────────────────────────────────────────────────────────────────
class _EmptyConnectionsView extends StatelessWidget {
  final VoidCallback onAddFriends;

  const _EmptyConnectionsView({required this.onAddFriends});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: context.colors.hint),
            SizedBox(height: 16),
            Text(
              'Henüz arkadaşın yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Arkadaş ekleyerek buluşma planları yapmaya başla.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.people_outline, color: Colors.white),
              label: Text(
                'Arkadaş Ekle',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
