import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/feed/models/post_model.dart';
import 'package:meetit/features/feed/post_detail_page.dart';
import 'package:meetit/features/feed/providers/feed_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/profile/saved_page.dart';
import 'package:quickalert/quickalert.dart';

// Profil tab index
final profileTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final feedState = ref.watch(feedProvider);
    final connections = ref.watch(connectionsProvider);
    final sentRequests = ref.watch(sentRequestsProvider);
    final tabIndex = ref.watch(profileTabProvider);

    // Kendi postları
    final myPosts = feedState.posts
        .where((p) => p.authorUid == (user?.uid ?? ''))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                user: user,
                postsCount: myPosts.length,
                friendsCount: connections.length,
                sentCount: sentRequests.length,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabIndex: tabIndex,
                onTabChanged: (i) =>
                    ref.read(profileTabProvider.notifier).state = i,
              ),
            ),
          ],
          body: switch (tabIndex) {
            0 => _PostsGrid(posts: myPosts),
            1 => _FriendsList(friends: connections),
            _ => _SentRequestsList(sent: sentRequests),
          },
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final UserModel? user;
  final int postsCount;
  final int friendsCount;
  final int sentCount;

  const _ProfileHeader({
    required this.user,
    required this.postsCount,
    required this.friendsCount,
    required this.sentCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          // Üst bar: boş + Ayarlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user?.name ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: context.colors.textPrimary,
                  size: 26,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileMenuPage()),
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Avatar + istatistikler
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => context.push(AppRoutes.editProfile),
                child: Stack(
                  children: [
                    user?.photoUrl != null
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(user!.photoUrl!),
                          )
                        : CircularAvatar(name: user?.name ?? '', radius: 40),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.card, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // İstatistikler
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: 'Gönderi', value: postsCount),
                    _Stat(label: 'Arkadaş', value: friendsCount),
                    _Stat(label: 'Bekleyen', value: sentCount),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Bio bilgileri
          if (user?.location != null || user?.personalityProfile != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user?.location != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.colors.hint,
                      ),
                      SizedBox(width: 3),
                      Text(
                        user!.location!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                if (user?.personalityProfile != null)
                  Row(
                    children: [
                      Text(
                        user!.personalityProfile!.dominantType.emoji,
                        style: TextStyle(fontSize: 13),
                      ),
                      SizedBox(width: 4),
                      Text(
                        user!.personalityProfile!.dominantType.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const _TabBarDelegate({required this.tabIndex, required this.onTabChanged});

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Row(
      children: [
        _Tab(
          icon: Icons.grid_on,
          isSelected: tabIndex == 0,
          onTap: () => onTabChanged(0),
        ),
        _Tab(
          icon: Icons.people_outline,
          isSelected: tabIndex == 1,
          onTap: () => onTabChanged(1),
        ),
        _Tab(
          icon: Icons.schedule_outlined,
          isSelected: tabIndex == 2,
          onTap: () => onTabChanged(2),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabIndex != tabIndex;
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? context.colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? context.colors.primary : context.colors.hint,
          ),
        ),
      ),
    );
  }
}

// ── Posts Grid ────────────────────────────────────────────────────────────────

class _PostsGrid extends StatelessWidget {
  final List<PostModel> posts;

  const _PostsGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Container(
        color: context.colors.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: context.colors.hint,
              ),
              SizedBox(height: 12),
              Text(
                'Henüz paylaşım yok',
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        final imgUrl = post.postPhotoUrl ?? post.venuePhotoUrl;
        return GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PostDetailPage(post: post))),
          child: imgUrl != null
              ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: context.colors.border),
                  errorWidget: (_, _, _) => _PlaceholderTile(post: post),
                )
              : _PlaceholderTile(post: post),
        );
      },
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  final PostModel post;
  const _PlaceholderTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: context.colors.primary, size: 22),
          SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              post.venueName,
              style: TextStyle(fontSize: 9, color: context.colors.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arkadaşlar Listesi ────────────────────────────────────────────────────────

class _FriendsList extends ConsumerWidget {
  final List<UserFriendModel> friends;

  const _FriendsList({required this.friends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (friends.isEmpty) {
      return Container(
        color: context.colors.card,

        child: Center(
          child: Text(
            'Henüz arkadaşın yok.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      color: context.colors.card,

      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
        itemBuilder: (_, i) {
          final f = friends[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircularAvatar(
              name: f.name,
              photoUrl: f.photoUrl,
              radius: 22,
            ),
            title: Text(
              f.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            subtitle: f.personalityProfile != null
                ? Text(
                    '${f.personalityProfile!.dominantType.emoji} ${f.personalityProfile!.dominantType.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  )
                : null,
            trailing: GestureDetector(
              onTap: () {
                ref.read(selectedFriendUidProvider.notifier).state = f.uid;
                ref.read(mainTabIndexProvider.notifier).state = 2;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Buluş',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Bekleyen İstekler ────────────────────────────────────────────────────────

class _SentRequestsList extends ConsumerWidget {
  final List<UserFriendModel> sent;

  const _SentRequestsList({required this.sent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sent.isEmpty) {
      return Container(
        color: context.colors.card,

        child: Center(
          child: Text(
            'Bekleyen istek yok.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      color: context.colors.card,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sent.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
        itemBuilder: (_, i) {
          final f = sent[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircularAvatar(
              name: f.name,
              photoUrl: f.photoUrl,
              radius: 22,
            ),
            title: Text(
              f.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => QuickAlert.show(
                context: context,
                type: QuickAlertType.confirm,
                title: 'İsteği İptal Et',
                text: '${f.name} kişisine gönderilen istek iptal edilsin mi?',
                confirmBtnText: 'İptal Et',
                cancelBtnText: 'Vazgeç',
                confirmBtnColor: Colors.red,
                onConfirmBtnTap: () {
                  Navigator.pop(context);
                  ref.read(friendsProvider.notifier).cancelSentRequest(f.uid);
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text(
                  'İptal',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
