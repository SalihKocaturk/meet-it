import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friend_code_page.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:quickalert/quickalert.dart';

// Arkadaşlar sekmesindeki arama metni için provider
final friendsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

// Tab controller için index provider (Öneri / Bağlantılarım)
final friendsTabIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(friendsTabIndexProvider);
    final invitationsCount = ref.watch(invitationsCountProvider);
    final sentCount = ref.watch(sentRequestsProvider).length;
    final connectionsCount = ref.watch(connectionsCountProvider);
    final requestsBadge = invitationsCount + sentCount;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'friends.title'.tr(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendCodePage(),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 12,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'friends.invite_friends'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arkadaş kodu butonu
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendCodePage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.colors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tag,
                            size: 14,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'friends.my_code'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arama çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _SearchBar(
                onChanged: (v) =>
                    ref.read(friendsSearchProvider.notifier).state = v,
              ),
            ),

            // Tabs: Öneri / İstekler / Bağlantılarım
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.scaffold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'friends.tab_suggestions'.tr(),
                      isSelected: tabIndex == 0,
                      onTap: () =>
                          ref.read(friendsTabIndexProvider.notifier).state = 0,
                    ),
                    _TabButton(
                      label: requestsBadge > 0
                          ? 'friends.tab_requests_badge'.tr(namedArgs: {'count': '$requestsBadge'})
                          : 'friends.tab_requests'.tr(),
                      isSelected: tabIndex == 1,
                      onTap: () =>
                          ref.read(friendsTabIndexProvider.notifier).state = 1,
                      hasBadge: invitationsCount > 0,
                    ),
                    _TabButton(
                      label: 'friends.tab_my_friends'.tr(namedArgs: {'count': '$connectionsCount'}),
                      isSelected: tabIndex == 2,
                      onTap: () =>
                          ref.read(friendsTabIndexProvider.notifier).state = 2,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // İçerik
            Expanded(
              child: RefreshIndicator(
                color: context.colors.primary,
                backgroundColor: context.colors.card,
                onRefresh: () async {
                  final uid = ref.read(currentUserProvider)?.uid ?? '';
                  await Future.wait([
                    if (uid.isNotEmpty)
                      ref.read(friendsProvider.notifier).loadAll(uid),
                    Future.delayed(const Duration(milliseconds: 700)),
                  ]);
                },
                child: switch (tabIndex) {
                  0 => const _SuggestionsTab(),
                  1 => const _RequestsTab(),
                  _ => _ConnectionsTab(connectionsCount: connectionsCount),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arama Çubuğu ──────────────────────────────────────────────────────────────
class _SearchBar extends ConsumerWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) {
        onChanged(v);
        ref.read(friendsProvider.notifier).updateSearchQuery(v);
      },
      decoration: InputDecoration(
        hintText: 'friends.search_hint'.tr(),
        hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: context.colors.hint),
        filled: true,
        fillColor: context.colors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Tab Butonu ────────────────────────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasBadge;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : context.colors.textSecondary,
                ),
              ),
              if (hasBadge && !isSelected)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Öneriler Sekmesi ──────────────────────────────────────────────────────────
class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(filteredSuggestionsProvider);
    final isLoading = ref.watch(friendsLoadingProvider);

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _SectionHeader(title: 'friends.suggestions_section'.tr(namedArgs: {'count': '${suggestions.length}'})),
        ...suggestions.map((f) => _SuggestionTile(friend: f)),
        if (suggestions.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'common.no_result'.tr(),
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── İstekler Sekmesi ─────────────────────────────────────────────────────────
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(pendingInvitationsProvider);
    final sent = ref.watch(sentRequestsProvider);

    if (incoming.isEmpty && sent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: context.colors.hint),
            SizedBox(height: 12),
            Text(
              'friends.no_requests'.tr(),
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Gelen istekler
        if (incoming.isNotEmpty) ...[
          _SectionHeader(title: 'friends.incoming_section'.tr(namedArgs: {'count': '${incoming.length}'})),
          ...incoming.map((f) => _InvitationTile(friend: f)),
          const SizedBox(height: 16),
        ],
        // Gönderilen istekler
        if (sent.isNotEmpty) ...[
          _SectionHeader(title: 'friends.sent_section'.tr(namedArgs: {'count': '${sent.length}'})),
          ...sent.map((f) => _SentRequestTile(friend: f)),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Bağlantılar Sekmesi ───────────────────────────────────────────────────────
class _ConnectionsTab extends ConsumerWidget {
  final int connectionsCount;

  const _ConnectionsTab({required this.connectionsCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _SectionHeader(title: 'friends.my_friends_section'.tr(namedArgs: {'count': '$connectionsCount'})),
        ...connections.map((f) => _ConnectionTile(friend: f)),
        if (connections.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'friends.no_friends_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

// ── Öneri Tile ────────────────────────────────────────────────────────────────
class _SuggestionTile extends ConsumerWidget {
  final UserFriendModel friend;

  const _SuggestionTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 24,
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
                  '@${friend.name.toLowerCase().replaceAll(' ', '')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(friendsProvider.notifier)
                .sendFriendRequest(friend.uid),
            icon: Icon(
              Icons.person_add_outlined,
              size: 14,
              color: context.colors.primary,
            ),
            label: Text(
              'friends.add'.tr(),
              style: TextStyle(fontSize: 12, color: context.colors.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: BorderSide(color: context.colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                ref.read(friendsProvider.notifier).removeFriend(friend.uid),
            child: Icon(Icons.close, size: 18, color: context.colors.hint),
          ),
        ],
      ),
    );
  }
}

// ── Davet Tile ────────────────────────────────────────────────────────────────
class _InvitationTile extends ConsumerWidget {
  final UserFriendModel friend;

  const _InvitationTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAgo = DateTime.now().difference(friend.addedAt).inDays;
    final timeText = daysAgo == 0 ? 'friends.today'.tr() : '$daysAgo ${'feed.days_ago'.tr()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 24,
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
                  timeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 22,
              color: context.colors.textSecondary,
            ),
            onPressed: () =>
                ref.read(friendsProvider.notifier).rejectInvitation(friend.uid),
          ),
          IconButton(
            icon: Icon(
              Icons.check_circle_outline,
              size: 22,
              color: context.colors.primary,
            ),
            onPressed: () =>
                ref.read(friendsProvider.notifier).acceptInvitation(friend.uid),
          ),
        ],
      ),
    );
  }
}

// ── Gönderilen İstek Tile ─────────────────────────────────────────────────────
class _SentRequestTile extends ConsumerWidget {
  final UserFriendModel friend;

  const _SentRequestTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 24,
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
          // Bekliyor etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.primary.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 12, color: context.colors.primary),
                SizedBox(width: 4),
                Text(
                  'friends.pending'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // İptal butonu
          GestureDetector(
            onTap: () {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.confirm,
                title: 'friends.cancel_request'.tr(),
                text: 'friends.cancel_request_confirm'.tr(namedArgs: {'name': friend.name}),
                confirmBtnText: 'friends.cancel_btn'.tr(),
                cancelBtnText: 'common.cancel'.tr(),
                confirmBtnColor: Colors.red,
                onConfirmBtnTap: () {
                  Navigator.pop(context);
                  ref
                      .read(friendsProvider.notifier)
                      .cancelSentRequest(friend.uid);
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bağlantı Tile ─────────────────────────────────────────────────────────────
class _ConnectionTile extends ConsumerWidget {
  final UserFriendModel friend;

  const _ConnectionTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 24,
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
                if (friend.personalityProfile != null)
                  Row(
                    children: [
                      Text(
                        friend.personalityProfile!.dominantType.emoji,
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 2),
                      Text(
                        friend.personalityProfile!.dominantType.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Buluşma yeri bul butonu — match sayfasına yönlendir
          GestureDetector(
            onTap: () {
              // Arkadaşı match provider'da seç
              ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
              // Buluşma sekmesine geç (index 2)
              ref.read(mainTabIndexProvider.notifier).state = 2;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.colors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'friends.meet'.tr(),
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
        ],
      ),
    );
  }
}
