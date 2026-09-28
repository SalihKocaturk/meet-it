import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';

/// Engelleme onayı — profil menüsü, gelen istek kartı ve şikâyet sonrası
/// akışların ortak diyaloğu. [afterReport] true ise "Şikâyetin alındı"
/// başlığıyla, şikâyetin ardından engelleme teklifi olarak gösterilir.
///
/// Kullanıcı engellediyse true döner.
Future<bool> showBlockUserDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
  required String name,
  bool afterReport = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final displayName = name.trim().isEmpty ? 'safety.this_user'.tr() : name;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        afterReport
            ? 'safety.report_sent_title'.tr()
            : 'safety.block_title'.tr(),
      ),
      content: Text(
        afterReport
            ? 'safety.offer_block_text'.tr(namedArgs: {'name': displayName})
            : 'safety.block_confirm_text'.tr(namedArgs: {'name': displayName}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            afterReport ? 'safety.not_now'.tr() : 'common.cancel'.tr(),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            'safety.block'.tr(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  final ok = await ref.read(friendsProvider.notifier).blockUser(uid);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'safety.blocked_snack'.tr(namedArgs: {'name': displayName})
            : 'safety.block_failed'.tr(),
      ),
      backgroundColor: ok ? null : Colors.red,
    ),
  );
  return ok;
}
