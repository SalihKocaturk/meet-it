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
/// ## Neden controller doğrudan geçiliyor?
/// `AvatarMakerCustomizer` ve `AvatarMakerAvatar`, `widget.controller != null`
/// olduğunda `Provider.of(context)` çağrısını tamamen atlıyor (Dart ?? short-circuit).
/// `Provider.of` çağrısı ise Flutter'ın `initState` sırasında izin vermediği
/// `dependOnInheritedWidgetOfExactType` hatasına yol açıyor.
///
/// Bu nedenle [AvatarMakerControllerProvider] kullanmıyoruz; controller'ı
/// her iki widget'a da `controller:` parametresiyle direkt veriyoruz.
class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  /// Controller, SharedPreferences temizlendikten sonra set edilir.
  PersistentAvatarMakerController? _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  /// 1. Eski SharedPreferences verisini temizle → jsonDecodeSelectedOptions
  ///    içindeki "Bad state: No element" hatasını önler.
  /// 2. Temiz controller oluştur.
  Future<void> _initController() async {
    await PersistentAvatarMakerController.clearAvatarMaker();
    if (!mounted) return;
    setState(() => _controller = PersistentAvatarMakerController());
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

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    // Controller hazır değilken yükleme göster.
    if (ctrl == null) {
      return Scaffold(
        backgroundColor: context.colors.scaffold,
        appBar: _appBar(ctrl: null),
        body: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: _appBar(ctrl: ctrl),
      body: Column(
        children: [
          // ── Önizleme avatarı ──────────────────────────────────────────
          Container(
            color: context.colors.card,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              // controller doğrudan geçildiği için Provider lookup yok.
              child: AvatarMakerAvatar(
                controller: ctrl,
                backgroundColor: context.colors.scaffold,
                radius: 60,
              ),
            ),
          ),

          // ── Özelleştirici ─────────────────────────────────────────────
          // controller doğrudan geçildiği için initState'te Provider.of çağrılmaz.
          Expanded(
            child: AvatarMakerCustomizer(
              controller: ctrl,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar({required PersistentAvatarMakerController? ctrl}) {
    return AppBar(
      backgroundColor: context.colors.scaffold,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2,
            size: 18, color: context.colors.textPrimary),
        onPressed: () =>