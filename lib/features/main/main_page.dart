import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/providers/network_provider.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friends_page.dart';
import 'package:meetit/features/home/home_page.dart';
import 'package:meetit/features/match/match_page.dart';
import 'package:meetit/features/profile/profile_page.dart';

final mainTabIndexProvider = StateProvider<int>((ref) => 0);

/// Tablet breakpoint: bu genişlikten itibaren NavigationRail kullanılır.
const _kTabletBreakpoint = 720.0;

class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  // Sekme sırası: Ana Sayfa, Buluşma, Arkadaşlar, Profil
  static const _pages = <Widget>[
    HomePage(),
    MatchPage(),
    FriendsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);
    final netStatus = ref.watch(networkStatusProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _kTabletBreakpoint;

    // Bağlantı yoksa sayfa içi tüm dokunmalar engellenir;
    // nav bar/rail kapsam dışında kalır (tab geçişi yine çalışır).
    final isOffline = netStatus == NetworkStatus.noConnection ||
        netStatus == NetworkStatus.noInternet;

    final pageContent = AbsorbPointer(
      absorbing: isOffline,
      child: IndexedStack(index: currentIndex, children: _pages),
    );

    if (isWide) {
      // ── Tablet düzeni: solda NavigationRail ─────────────────────────────
      return Scaffold(
        backgroundColor: context.colors.scaffold,
        body: Row(
          children: [
            _SideRail(currentIndex: currentIndex),
            Container(width: 1, color: context.colors.border),
            Expanded(child: pageContent),
          ],
        ),
      );
    }

    // ── Telefon düzeni: altta BottomNavBar ──────────────────────────────
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: pageContent,
      bottomNavigationBar: _MainBottomNavBar(currentIndex: currentIndex),
    );
  }
}

// ── Tablet: solda dikey navigasyon rayı ─────────────────────────────────────

class _SideRail extends ConsumerWidget {
  final int currentIndex;
  const _SideRail({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    Widget profileIcon({required bool active}) {
      if (currentUser?.photoUrl != null) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: context.colors.primary, width: 2)
                : null,
          ),
          child: CircleAvatar(
            radius: active ? 11 : 12,
            backgroundImage: NetworkImage(currentUser!.photoUrl!),
          ),
        );
      }
      return Icon(
        Iconsax.profile_circle,
        size: 24,
        color: active ? context.colors.primary : context.colors.hint,
      );
    }

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) =>
          ref.read(mainTabIndexProvider.notifier).state = i,
      labelType: NavigationRailLabelType.all,
      backgroundColor: context.colors.card,
      minWidth: 72,
      selectedIconTheme:
          IconThemeData(color: context.colors.primary, size: 24),
      unselectedIconTheme:
          IconThemeData(color: context.colors.hint, size: 24),
      selectedLabelTextStyle: TextStyle(
        color: context.colors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: context.colors.hint,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      indicatorColor: context.colors.primary.withOpacity(0.12),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Iconsax.home_2),
          selectedIcon: const Icon(Iconsax.home),
          label: Text('nav.home'.tr()),
        ),
        NavigationRailDestination(
          icon: const Icon(Iconsax.location),
          selectedIcon: const Icon(Iconsax.location),
          label: Text('nav.meetup'.tr()),
        ),
        NavigationRailDestination(
          icon: const Icon(Iconsax.people),
          selectedIcon: const Icon(Iconsax.people),
          label: Text('nav.friends'.tr()),
        ),
        NavigationRailDestination(
          icon: profileIcon(active: false),
          selectedIcon: profileIcon(active: true),
          label: Text('nav.profile'.tr()),
        ),
      ],
    );
  }
}

// ── Telefon: altta özel navigasyon barı ─────────────────────────────────────

class _MainBottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const _MainBottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Ana Sayfa
              _NavItem(
                icon: Iconsax.home_2,
                activeIcon: Iconsax.home,
                label: 'nav.home'.tr(),
                isSelected: currentIndex == 0,
                onTap: () => ref.read(mainTabIndexProvider.notifier).state = 0,
              ),
              // Buluşma
              _NavItem(
                icon: Iconsax.location,
                activeIcon: Iconsax.location,
                label: 'nav.meetup'.tr(),
                isSelected: currentIndex == 1,
                onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
              ),
              // Arkadaşlar
              _NavItem(
                icon: Iconsax.people,
                activeIcon: Iconsax.people,
                label: 'nav.friends'.tr(),
                isSelected: currentIndex == 2,
                onTap: () => ref.read(mainTabIndexProvider.notifier).state = 2,
              ),
              // Profil — fotoğraf veya ikon
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      ref.read(mainTabIndexProvider.notifier).state = 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: currentIndex == 3
                              ? Border.all(
                                  color: context.colors.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: currentUser?.photoUrl != null
                            ? CircleAvatar(
                                radius: 13,
                                backgroundImage: NetworkImage(
                                  currentUser!.photoUrl!,
                                ),
                              )
                            : Icon(
                                Iconsax.profile_circle,
                                color: currentIndex == 3
                                    ? context.colors.primary
                                    : context.colors.hint,
                                size: 24,
                              ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'nav.profile'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          color: currentIndex == 3
                              ? context.colors.primary
                              : context.colors.hint,
                          fontWeight: currentIndex == 3
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? context.colors.primary : context.colors.hint,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.hint,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
