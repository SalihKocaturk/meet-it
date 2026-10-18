import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/providers/network_provider.dart';
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

    // ── Telefon düzeni: altta yüzen kapsül nav bar ──────────────────────
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      // İçerik (harita dahil) kapsülün arkasına kadar uzanır
      extendBody: true,
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
          icon: const Icon(Iconsax.user),
          selectedIcon: const Icon(Iconsax.user),
          label: Text('nav.profile'.tr()),
        ),
      ],
    );
  }
}

// ── Telefon: altta yüzen buzlu cam kapsül (floating pill) ───────────────────
//
// Scaffold `extendBody: true` ile içerik kapsülün arkasına kadar uzanır.
// Scaffold, gövdenin MediaQuery alt padding'ine kapsülün yüksekliğini
// ekler; sekmelerdeki SafeArea / alt boşluklar bu sayede kapsülün üstünde
// kalır (son kartlar barın arkasında kaybolmaz).

class _MainBottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const _MainBottomNavBar({required this.currentIndex});

  // (pasif ikon, aktif ikon, çeviri anahtarı)
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'nav.home'),
    (Icons.location_on_outlined, Icons.location_on_rounded, 'nav.meetup'),
    (Icons.people_alt_outlined, Icons.people_alt_rounded, 'nav.friends'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'nav.profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(40);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: DecoratedBox(
          // Gölge ClipRRect'in dışında kalmalı, yoksa kırpılır
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A17).withOpacity(0.82)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: radius,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      _NavItem(
                        icon: _items[i].$1,
                        activeIcon: _items[i].$2,
                        label: _items[i].$3.tr(),
                        isSelected: currentIndex == i,
                        onTap: () =>
                            ref.read(mainTabIndexProvider.notifier).state = i,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiketsiz ikon sekmesi: aktifken dolgulu zümrüt ikon + hafif glow +
/// altında 4 px nokta; pasifken çizgisel ikon. Etiket ekran okuyucu için
/// Semantics'te durur.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Emerald.light : Emerald.deep;
    final idleColor =
        isDark ? Colors.white.withOpacity(0.65) : Colors.black54;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Emerald.base.withOpacity(0.35),
                              blurRadius: 16,
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 26,
                    color: isSelected ? activeColor : idleColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Emerald.base : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
