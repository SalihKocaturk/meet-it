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
///
/// ## Neden iki aşamalı yükleme?
/// `avatar_maker` paketi, `AvatarMakerCustomizer.initState` içinde
/// `Provider.of<AvatarMakerController>(context)` çağırıyor (paket bug'ı).
/// Flutter bu erişime `initState` sırasında izin vermiyor:
/// `_InheritedProviderScope` henüz mount tamamlanmamışken
/// `dependOnInheritedWidgetOfExactType` atıyor.
///
/// Çözüm: provider tam mount olduktan BİR FRAME SONRA
/// `AvatarMakerCustomizer`'ı göster. `addPostFrameCallback` bunu garantiler.
class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  PersistentAvatarMakerController? _controller;

  /// true olduğunda AvatarMakerCustomizer render edilir.
  /// Provider mount tamamlandıktan sonraki frame'de set edilir.
  bool _customizerReady = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  /// 1. Eski/bozuk SharedPreferences verilerini temizle (Bad state: No element önlemi).
  /// 2. Controller oluştur, provider'ı kur.
  /// 3. postFrameCallback ile bir frame bekle → Customizer'ı göster.
  Future<void> _initController() async {
    await PersistentAvatarMakerController.clearAvatarMaker();
    if (!mounted) return;
    setState(() => _controller = PersistentAvatarMakerController());

    // Provider frame'ini tamamla, ardından Customizer'ı güvenle mount et.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _customizerReady = true);
    });
  }

  Future<void> _saveToFirestore() async {
    setState(() => _saving = true);
    try {
      final json = await PersistentAvatarMakerController.getJsonOptions();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && json.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'avatarJson': json});
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

  AppBar _buildAppBar({bool showSave = false}) {
    return AppBar(
      backgroundColor: context.colors.scaffold,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2,
            size: 18, color: context.colors.textPrimary),
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
      actions: showSave
          ? [
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
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _contro