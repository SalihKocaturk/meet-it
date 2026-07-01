import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../providers/network_provider.dart';

/// AppBar'ın hemen altında kayarak çıkan ağ durumu banner'ı.
///
/// Durum → Görsel:
///   🟢 connected   : Yeşil nokta + "Bağlantı kuruldu"  → 2.5 sn sonra kapanır
///   🟠 maintenance : Turuncu nokta + "Sunucu bakımda"   → açık kalır
///   🟡 noInternet  : Sarı nokta + "Ağ bağlı, internet yok" → açık kalır
///   🔴 noConnection: "İnternet bağlantısı yok" + sağda küçük kırmızı nokta → açık kalır
///
/// [MainPage]'in body Stack'ine `Positioned(top:0, left:0, right:0)` olarak yerleştirilir.
class NetworkStatusBanner extends ConsumerStatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  ConsumerState<NetworkStatusBanner> createState() =>
      _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends ConsumerState<NetworkStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _size;

  NetworkStatus _displayStatus = NetworkStatus.connected;
  bool _inTree = false;
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _size = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _show(NetworkStatus status) {
    _dismiss?.cancel();
    setState(() {
      _displayStatus = status;
      _inTree = true;
    });
    _ctrl.forward();

    if (status == NetworkStatus.connected) {
      // Bağlantı tekrar kurulduysa 2.5 sn göster sonra kapat
      _dismiss = Timer(const Duration(milliseconds: 2500), () {
        _ctrl.reverse().then((_) {
          if (mounted) setState(() => _inTree = false);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkStatus>(networkStatusProvider, (prev, next) {
      if (prev != next) _show(next);
    });

    if (!_inTree) return const SizedBox.shrink();

    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: _BannerContent(status: _displayStatus),
    );
  }
}

// ── Banner içeriği ──────────────────────────────────────────────────────────

class _BannerContent extends StatelessWidget {
  final NetworkStatus status;
  const _BannerContent({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cfg = _config(c, isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: cfg.bg,
        border: Border(
          bottom: BorderSide(
            color: (cfg.dotColor ?? c.error).withOpacity(0.35),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sol gösterge noktası (noConnection durumunda yok)
          if (cfg.dotColor != null) ...[
            _StatusDot(color: cfg.dotColor!, size: 9, glowing: true),
            const SizedBox(width: 8),
          ],
          // Mesaj
          Text(
            cfg.text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          // Sağ kırmızı nokta (yalnızca noConnection durumunda)
          if (cfg.showRedRight) ...[
            const SizedBox(width: 8),
            _StatusDot(color: c.error, size: 6, glowing: false),
          ],
        ],
      ),
    );
  }

  _BannerCfg _config(AppColors c, bool isDark) {
    return switch (status) {
      NetworkStatus.connected => _BannerCfg(
          text: 'Bağlantı kuruldu',
          dotColor: c.success,
          showRedRight: false,
          bg: c.success.withOpacity(isDark ? 0.15 : 0.10),
        ),
      NetworkStatus.maintenance => _BannerCfg(
          text: 'Sunucu bakımda',
          dotColor: const Color(0xFFFF8C00),
          showRedRight: false,
          bg: const Color(0xFFFF8C00).withOpacity(isDark ? 0.15 : 0.10),
        ),
      NetworkStatus.noInternet => _BannerCfg(
          text: 'Ağ bağlı, internet yok',
          dotColor: const Color(0xFFFFC107),
          showRedRight: false,
          bg: const Color(0xFFFFC107).withOpacity(isDark ? 0.13 : 0.08),
        ),
      NetworkStatus.noConnection => _BannerCfg(
          text: 'İnternet bağlantısı yok',
          dotColor: null,
          showRedRight: true,
          bg: c.error.withOpacity(isDark ? 0.13 : 0.07),
        ),
    };
  }
}

class _BannerCfg {
  final String text;
  final Color? dotColor;
  final bool showRedRight;
  final Color bg;
  const _BannerCfg({
    required this.text,
    required this.dotColor,
    required this.showRedRight,
    required this.bg,
  });
}

// ── Nokta widget'ı ──────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glowing;

  const _StatusDot({
    required this.color,
    required this.size,
    required this.glowing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: color.withOpacity(0.55),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
