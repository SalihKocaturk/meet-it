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
/// SharedPreferences'daki eski/bozuk veriyi önlemek için controller,
/// [initState] içinde temizlendikten sonra oluşturuluyor.
/// Firestore'daki [avatarJson] gerçek kaynaktır; SharedPreferences
/// sadece pakete ait geçici önbellek olarak kullanılır.
class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  /// Controller, SharedPreferences temizlendikten sonra null'dan set edilir.
  PersistentAvatarMakerController? _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  /// Eski/bozuk SharedPreferences verilerini sil, ardından controller oluştur.
  /// Böylece jsonDecodeSelectedOptions "Bad state: No element" hatası önlenir.
  Future<void> _initController() async {
    await PersistentAvatarMakerController.clearAvatarMaker();
    if (!mounted) return;
    setState(() => _controller = PersistentAvatarMakerController());
  }

  Future<void> _saveToFirestore() async {
    setState(() => _saving = true);
    try {
      // Static method — class üzerinden çağrılır, instance üzerinden değil.
      final json = await PersistentAvatarMakerController.getJsonOptions();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && json.isNotEmpty) {
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
    final ctrl = _controller;

    // Controller hazır değilken yükleme göster.
    if (ctrl == null) {
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
            'avatar.title'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

    // AvatarMakerControllerProvider sadece bu sayfanın alt ağacını sarar.
    return AvatarMakerControllerProvider(
      controller: ctrl,
      child: Scaffold(
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
                        child: CircularProgressIndicator