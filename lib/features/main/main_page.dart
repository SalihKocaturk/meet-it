import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // ── Telefon düzeni: altta yüzen cam kapsül ──────────────────────────
    // extendBody: içerik barın arkasına kayar (bulanıklık için şart).
    return Scaffold(
      backgroundColor: context.colors.scaffold,
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

// ── Telefon: altta yüzen "liquid glass" kapsül ──────────────────────────────
//
// Kick tarzı: ekranın altından ve kenarlarından içeride duran, yazısız,
// buzlu cam bir kapsül. Scaffold.extendBody: true sayesinde sayfa içeriği
// barın ARKASINA kayar; BackdropFilter onu bulanıklaştırıp hafif doygunluk
// ekler (iOS "liquid glass" hissi). Sayfalar alt boşluğu
// MediaQuery.paddingOf(context).bottom ile bırakır — extendBody bu değeri
// barın toplam yüksekliğine eşitler.

const _kNavHeight = 64.0;
const _kNavRadius = 32.0;
const _kNavSideInset = 22.0;
/// Aktif sekme ikonunun arkasındaki yuvarlak (ana sayfadaki ikon
/// rozetleriyle aynı dil).
const _kChip = 46.0;

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  const _NavSpec(this.icon, this.activeIcon, this.labelKey);
}

const _navItems = <_NavSpec>[
  // Uygulamanın geri kalanıyla aynı ikon seti (Iconsax)
  _NavSpec(Iconsax.home_2, Iconsax.home, 'nav.home'),
  _NavSpec(Iconsax.location, Iconsax.location, 'nav.meetup'),
  _NavSpec(Iconsax.people, Iconsax.people, 'nav.friends'),
  _NavSpec(Iconsax.user, Iconsax.user, 'nav.profile'),
];

class _MainBottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const _MainBottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Home indicator'ı olan cihazlarda kapsül biraz aşağı oturur; düz
    // altlı cihazlarda sabit bir boşluk kalır.
    final bottomGap = safeBottom > 0 ? safeBottom * 0.6 + 4 : 14.0;
    final radius = BorderRadius.circular(_kNavRadius);

    void select(int i) {
      if (i == currentIndex) return;
      HapticFeedback.selectionClick();
      ref.read(mainTabIndexProvider.notifier).state = i;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kNavSideInset,
        0,
        _kNavSideInset,
        bottomGap,
      ),
      child: SizedBox(
        height: _kNavHeight,
        child: CustomPaint(
          // Gölge yalnızca kapsülün DIŞINA çizilir; içeri sızsa yarı saydam
          // cam çamurlu görünürdü.
          painter: _OuterShadowPainter(
            radius: _kNavRadius,
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: const ColorFilter.matrix(_kSaturate),
                inner: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              ),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    // Cam gövdesi: koyu temada dumanlı, açıkta sütlü
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          // Uygulamanın kart rengi (#161B22) çok hafif
                          // tonlanıyor — arka plan net seçilsin diye düşük
                          // opaklık.
                          ? [
                              const Color(0xFF161B22).withOpacity(0.28),
                              const Color(0xFF0D1117).withOpacity(0.38),
                            ]
                          : [
                              Colors.white.withOpacity(0.42),
                              Colors.white.withOpacity(0.32),
                            ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cellW = c.maxWidth / _navItems.length;
                      return Stack(
                        children: [
                          // Üst parlama (ışığın cama vurduğu kısım)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: _kNavHeight * 0.5,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white
                                          .withOpacity(isDark ? 0.06 : 0.35),
                                      Colors.white.withOpacity(0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Aktif sekmenin arkasında kayan cam damla
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 340),
                            curve: Curves.easeOutCubic,
                            left: cellW * currentIndex + (cellW - _kChip) / 2,
                            top: (_kNavHeight - _kChip) / 2,
                            width: _kChip,
                            height: _kChip,
                            child: IgnorePointer(
                              child: _ActiveBlob(isDark: isDark),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < _navItems.length; i++)
                                _NavItem(
                                  spec: _navItems[i],
                                  isSelected: currentIndex == i,
                                  isDark: isDark,
                                  onTap: () => select(i),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arka planı hafifçe canlandıran doygunluk matrisi (s = 1.5, Rec.709).
const _kSaturate = <double>[
  1.4063, -0.3576, -0.0361, 0, 0, //
  -0.1063, 1.1424, -0.0361, 0, 0, //
  -0.1063, -0.3576, 1.4639, 0, 0, //
  0, 0, 0, 1, 0,
];

class _ActiveBlob extends StatelessWidget {
  final bool isDark;
  const _ActiveBlob({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Ana sayfadaki "Kişiliğini Yönet" kartlarının ikon rozetiyle aynı:
    // kenarsız, zümrüt tonlu daire.
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Emerald.base.withOpacity(isDark ? 0.20 : 0.16),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.spec,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = isDark ? Emerald.light : Emerald.deep;
    final idle = isDark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.55);

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: spec.labelKey.tr(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: isSelected ? 1.0 : 0.94,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? spec.activeIcon : spec.icon,
                  key: ValueKey(isSelected),
                  size: 24,
                  color: isSelected ? active : idle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kapsülün yalnızca dışına yumuşak gölge çizer.
class _OuterShadowPainter extends CustomPainter {
  final double radius;
  final Color color;
  const _OuterShadowPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(60)),
      Path()..addRRect(rrect),
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.color != color || old.radius != radius;
}
