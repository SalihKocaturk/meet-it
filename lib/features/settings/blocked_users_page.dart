import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/friends/notifiers/friends_notifier.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';

/// Ayarlar > Engellenenler — kullanıcının engellediği hesapları listeler ve
/// engeli kaldırmasını sağlar.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  late Future<List<BlockedUser>> _future;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _future = ref.read(friendsProvider.notifier).fetchMyBlockedUsers();
  }

  void _reload() {
    setState(() {
      _future = ref.read(friendsProvider.notifier).fetchMyBlockedUsers();
    });
  }

  String _displayName(BlockedUser user) =>
      user.name.trim().isEmpty ? 'safety.deleted_user'.tr() : user.name;

  Future<void> _unblock(BlockedUser user) async {
    final name = _displayName(user);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('safety.unblock_title'.tr()),
        content: Text('safety.unblock_text'.tr(namedArgs: {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('safety.unblock'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(user.uid));
    final ok = await ref.read(friendsProvider.notifier).unblockUser(user.uid);
    if (!mounted) return;
    setState(() => _busy.remove(user.uid));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'safety.unblocked_snack'.tr(namedArgs: {'name': name})
              : 'safety.unblock_failed'.tr(),
        ),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'safety.blocked_title'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'safety.blocked_load_error'.tr(),
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _reload,
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            );
          }
          final users = snap.data ?? const <BlockedUser>[];
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.user_remove, size: 48, color: context.colors.hint),
                    const SizedBox(height: 12),
                    Text(
                      'safety.blocked_empty'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final user = users[i];
              final name = _displayName(user);
              final busy = _busy.contains(user.uid);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    CircularAvatar(name: name, photoUrl: user.photoUrl, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : OutlinedButton(
                            onPressed: () => _unblock(user),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.primary,
                              side: BorderSide(color: context.colors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text('safety.unblock'.tr()),
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
