import 'package:avatar_maker/avatar_maker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/app_alert.dart';

/// Avatar özelleştirme sayfası.
/// avatar_maker paketi kendi Provider tabanlı state'ini yönetiyor;
/// Riverpod ile çakışmaz — [AvatarMakerProvider] yalnızca bu widget'ın
/// alt ağacını sarar.
class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  // PersistentAvatarMakerController SharedPreferences'a otomatik kaydeder.
  final _controller = PersistentAvatarMakerController();
  bool _saving = false;

  Future<void> _saveToFirestore() async {
    setState(() => _saving = true);
    try {
      // SVG'yi JSON string olarak al
      final json = await _controller.getJsonOptions();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && json != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'avatarJson': json,
        });
      }
      if (!mounted) return;
      showAppAlert(
        context: context,
        type: AppAlertType.success,
        title: 'avatar.saved_title'.tr(),
        text: 'avatar.saved_desc'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
        onConfirmBtnTap: () {
          Navigator.pop(context); // alert
          Navigator.pop(context); // avatar sayfası
        },
      );
    } catch (_) {
      if (!mounted) return;
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'common.error'.tr(),
        text: 'common.try_again'.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // AvatarMakerProvider sadece bu sayfanın alt ağacını sarar.
    return AvatarMakerProvider(
      controller: _controller,
      child: Scaffold(
        backgroundColor: context.colors.scaffold,
        appBar: AppBar(
          backgroundColor: context.colors.scaffold,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Iconsax.arrow_left_2,
              size: 18,
              color: context.colors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'avatar.title'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _saving ? null : _saveToFirestore,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : Text(
                        'common.save'.tr(),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Önizleme avatarı ──────────────────────────────────────────
            Container(
              color: context.colors.card,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: AvatarMakerAvatar(
                  backgroundColor: context.colors.scaffold,
                  radius: 60,
                ),
              ),
            ),

            // ── Özelleştirici ─────────────────────────────────────────────
            Expanded(
              child: AvatarMakerCustomizer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
