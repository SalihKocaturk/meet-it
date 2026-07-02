import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

// ── Model ───────────────────────────────────────────────────────────────────

class NotificationItem {
  final String id;
  final String type;
  final String fromName;
  final String fromUid;
  final bool read;
  final DateTime? createdAt;
  final Map<String, dynamic> extra;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.fromName,
    required this.fromUid,
    required this.read,
    required this.createdAt,
    required this.extra,
  });

  factory NotificationItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      type: d['type'] as String? ?? '',
      fromName: d['fromName'] as String? ?? '',
      fromUid: d['fromUid'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      extra: Map<String, dynamic>.from(d['extra'] as Map? ?? {}),
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final _notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationItem>>((ref) {
  final uid = ref.watch(authProvider).user?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(NotificationItem.fromDoc).toList());
});

/// Okunmamış bildirim sayısı — menüde badge için.
final unreadNotifCountProvider = Provider.autoDispose<int>((ref) {
  return ref
          .watch(_notificationsStreamProvider)
          .whenData((items) => items.where((n) => !n.read).length)
          .value ??
      0;
});

// ── Page ─────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Sayfa açılınca tümünü okundu işaretle
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(_notificationsStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2,
              size: 18, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'notifications.title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('common.error'.tr(),
              style: TextStyle(color: context.colors.textSecondary)),
        ),
        data: (items) {
          if (items.isEmpty) return _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotifCard(item: items[i]),
          );
        },
      ),
    );
  }
}

// ── Boş durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.notification,
              size: 64, color: context.colors.hint.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text(
            'notifications.empty'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'notifications.empty_desc'.tr(),
            style: TextStyle(
                fontSize: 13, color: context.colors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Bildirim kartı ───────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final NotificationItem item;
  const _NotifCard({required this.item});

  IconData get _icon {
    switch (item.type) {
      case 'review_liked':
        return Iconsax.heart5;
      case 'friend_request':
        return Iconsax.profile_add;
      case 'friend_accepted':
        return Iconsax.profile_tick;
      case 'meetup_invite':
      case 'venue_found':
        return Iconsax.location;
      default:
        return Iconsax.notification;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (item.type) {
      case 'review_liked':
        return const Color(0xFFE53935);
      case 'friend_request':
      case 'friend_accepted':
        return context.colors.primary;
      case 'meetup_invite':
      case 'venue_found':
        return const Color(0xFF43A047);
      default:
        return context.colors.textSecondary;
    }
  }

  String _body(BuildContext context) {
    switch (item.type) {
      case 'review_liked':
        final venue = item.extra['venueName'] as String? ?? '';
        return 'notifications.review_liked'
            .tr(namedArgs: {'name': item.fromName, 'venue': venue});
      case 'friend_request':
        return 'notifications.friend_request'
            .tr(namedArgs: {'name': item.fromName});
      case 'friend_accepted':
        return 'notifications.friend_accepted'
            .tr(namedArgs: {'name': item.fromName});
      case 'meetup_invite':
        return 'notifications.meetup_invite'
            .tr(namedArgs: {'name': item.fromName});
      case 'venue_found':
        return 'notifications.venue_found'
            .tr(namedArgs: {'name': item.fromName});
      default:
        return item.fromName;
    }
  }

  String _timeAgo(BuildContext context) {
    if (item.createdAt == null) return '';
    final diff = DateTime.now().difference(item.createdAt!);
    if (diff.inMinutes < 1) return 'notifications.just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'notifications.minutes_ago'
          .tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'notifications.hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    return DateFormat('d MMM', context.locale.languageCode)
        .format(item.createdAt!);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    return Container(
      decoration: BoxDecoration(
        color: unread
            ? context.colors.primary.withOpacity(0.06)
            : context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unread
              ? context.colors.primary.withOpacity(0.2)
              : context.colors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor(context).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(_icon, size: 18, color: _iconColor(context)),
          ),
          const SizedBox(width: 12),

          // Metin + zaman
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _body(context),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textPrimary,
                    fontWeight:
                        unread ? FontWeight.w600 : FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                if (item.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(context),
                    style: TextStyle(
                        fontSize: 11, color: context.colors.hint),
                  ),
                ],
              ],
            ),
          ),

          // Okunmamış nokta
          if (unread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
