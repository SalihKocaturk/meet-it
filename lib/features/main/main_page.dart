import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/friends_page.dart';
import 'package:meetit/features/home/home_page.dart';
import 'package:meetit/features/match/match_page.dart' hide SizedBox;
import 'package:meetit/features/profile/profile_page.dart';

final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  // Sekme sırası: Ana Sayfa, Buluşma, Arkadaşlar, Profil
  // (eski sıra: Feed, Arkadaşlar, Buluşma, Profil idi — Feed kaldırıldı,
  // Buluşma ve Arkadaşlar yer değiştirdi)
  static const _pages = <Widget>[
    HomePage(),
    MatchPage(),
    FriendsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: IndexedStack(index: currentIndex, children: _pages),
      bottomNavigationBar: _MainBottomNavBar(currentIndex: currentIndex),
    );
  }
}

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
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'nav.home'.tr(),
                isSelected: currentIndex == 0,
                onTap: () => ref.read(mainTabIndexProvider.notifier).state = 0,
              ),
              // Buluşma
              _NavItem(
                icon: Icons.location_on_outlined,
                activeIcon: Icons.location_on,
                label: 'nav.meetup'.tr(),
                isSelected: currentIndex == 1,
                onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
              ),
              // Arkadaşlar
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
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
                                currentIndex == 3
                                    ? Icons.person
                                    : Icons.person_outline,
                                color: currentIndex == 3
                                    ? context.colors.primary
                                    : context.colors.hint,
                                size: 24,
                              ),
                      ),
                      SizedBox(height: 3),
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
            SizedBox(height: 3),
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
