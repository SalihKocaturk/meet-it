import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_router.dart';
import 'package:meetit/features/notifications/notifications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama içi bildirim: yeni bir bildirim geldiğinde ekranın üstünden
/// kayarak açılan kart (iOS/Android sistem bildirimine benzer).
///
/// Kaynak Firestore'daki `notifications/{uid}/items` — push izni kapalı
/// olsa bile çalışır. Uygulama açıkken gelen bildirimler anında, uygulama
/// kapalıyken gelenler ise uygulama açılınca (son 48 saat, okunmamış) bir
/// kez gösterilir. Her bildirim yalnızca bir kez gösterilir.
///
/// MaterialApp.router'ın `builder`'ında tüm sayfaların üstüne sarılır.
class InAppNotificationHost extends ConsumerStatefulWidget {
  final Widget child;
  const InAppNotificationHost({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationHost> createState() =>
      _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost>
    with SingleTickerProviderStateMixin {
  static const _kShownKey = 'inapp_notif_shown_ids';
  static const _kMaxRemembered = 100;
  static const _kMaxAge = Duration(hours: 48);
  static const _kVisibleFor = Duration(seconds: 5);
  static const _kTypes = {
    'meetup_invite',
    'venue_found',
    'friend_request',
    'friend_accepted',
    'review_liked',
  };

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ));

  List<String> _shown = [];
  bool _prefsLoaded = false;
  List<NotificationItem>? _pending;
  NotificationItem? _current;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadShown();
    ref.listenManual<AsyncValue<List<NotificationItem>>>(
      notificationsStreamProvider,
      (_, next) => next.whenData(_onItems),
      fireImmediately: true,
    );
  }

  Future<void> _loadShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _shown = prefs.getStringList(_kShownKey) ?? [];
    } catch (_) {}
    _prefsLoaded = true;
    final pending = _pending;
    _pending = null;
    if (pending != null && mounted) _onItems(pending);
  }

  Future<void> _rememberShown(Iterable<String> ids) async {
    _shown = [..._shown, ...ids];
    if (_shown.length > _kMaxRemembered) {
      _shown = _shown.sublist(_shown.length - _kMaxRemembered);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kShownKey, _shown);
    } catch (_) {}
  }

  void _onItems(List<NotificationItem> items) {
    if (!_prefsLoaded) {
      _pending = items;
      return;
    }
    final now = DateTime.now();
    // Liste en yeniden eskiye sıralı geliyor.
    final fresh = items.where((n) {
      if (n.read || n.createdAt == null) return false;
      if (!_kTypes.contains(n.type)) return false;
      if (_shown.contains(n.id)) return false;
      return now.difference(n.createdAt!) < _kMaxAge;
    }).toList();
    if (fresh.isEmpty) return;

    // Aynı anda birden fazla birikmişse sadece en yenisini göster —
    // kullanıcıyı art arda kartlarla boğmamak için. Kalanlar zaten
    // Bildirimler sayfasında duruyor.
    _rememberShown(fresh.map((n) => n.id));
    final newest = fresh.first;
    // Dinleyici build/initState sırasında tetiklenebilir — setState'i
    // bir sonraki kareye bırak.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(newest);
    });
  }

  void _show(NotificationItem item) {
    _hideTimer?.cancel();
    setState(() => _current = item);
    HapticFeedback.lightImpact();
    _anim.forward(from: 0);
    _hideTimer = Timer(_kVisibleFor, _hide);
  }

  Future<void> _hide() async {
    _hideTimer?.cancel();
    if (!mounted || _current == null) return;
    await _anim.reverse();
    if (mounted) setState(() => _current = null);
  }

  Future<void> _open() async {
    final item = _current;
    if (item == null) return;
    _hide();
    markNotificationRead(ref, item);
    final nav = ref.read(appRouterProvider).routerDelegate.navigatorKey.currentState;
    if (nav == null) return;
    await openNotificationTarget(nav, ref, item);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Stack(
      children: [
        widget.child,
        if (item != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SlideTransition(
                  position: _slide,
                  child: GestureDetector(
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < -100) _hide();
                    },
                    child: _Banner(item: item, onTap: _open, onClose: _hide),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// NOT: Bu widget Navigator'ın (ve Overlay'in) ÜSTÜNDE çalışıyor — Tooltip
// gibi Overlay isteyen widget'lar burada kullanılmamalı.
class _Banner extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Banner({
    required this.item,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = notificationColor(context, item.type);
    return Material(
      color: context.colors.card,
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.25),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(notificationIcon(item.type), size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificationTitle(item.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notificationText(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Iconsax.close_circle,
                  size: 20,
                  color: context.colors.hint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
