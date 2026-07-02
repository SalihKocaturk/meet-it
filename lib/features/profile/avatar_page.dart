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
/// ## Dark theme
/// [AvatarMakerThemeData] ile `context.colors` renkleri Customizer'a
/// aktarılır; light/dark mode otomatik yansır.
///
/// ## Türkçe
/// [PersistentAvatarMakerController] constructor'ına `locale: context.locale`
/// geçilir. Paketin `app_localizations_tr.dart` dosyası delegate aracılığıyla
/// yüklenir (bkz. main.dart → avatarL10n.AppLocalizations.delegate).
///
/// ## Provider hatası
/// AvatarMakerCustomizer/Avatar, `widget.controller != null` olduğunda
/// `Provider.of(context)` çağrısını tamamen atlıyor (Dart ?? short-circuit).
/// Bu yüzden AvatarMakerControllerProvider kullanmıyoruz.
class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  PersistentAvatarMakerController? _controller;
  bool _saving = false;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    // initState'te inherited widget (EasyLocalization, Theme vb.) OKUNAMAZ —
    // context.locale çağrısı da dependOnInheritedWidgetOfExactType tetikler.
    // Locale okuma didChangeDependencies'e taşındı.
  }

  /// Flutter'ın inherited widget erişimi için önerdiği lifecycle hook.
  /// initState'ten hemen sonra çağrılır; inherited widget'lar burada güvenlidir.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerInitialized) return; // sadece ilk seferde çalıştır
    _controllerInitialized = true;
    _initController(context.locale);
  }

  /// 1. Eski SharedPreferences verisini temizle (Bad state: No element önlemi).
  /// 2. Uygulama diliyle uyumlu controller oluştur.
  Future<void> _initController(Locale locale) async {
    await PersistentAvatarMakerController.clearAvatarMaker();
    if (!mounted) return;
    setState(() => _controller = PersistentAvatarMakerController(
          locale: locale,
        ));
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

  /// Uygulamanın renk temasına göre Customizer görünümü.
  AvatarMakerThemeData _buildAvatarTheme(BuildContext context) {
    final colors = context.colors;
    return AvatarMakerThemeData(
      // ── Arkaplanlar ──────────────────────────────────────────────────
      primaryBgColor: colors.card,         // tab bar + ok butonları satırı
      secondaryBgColor: colors.scaffold,   // ikon grid alanı
      // ── Yazı ─────────────────────────────────────────────────────────
      labelTextStyle: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      // ── İkonlar ──────────────────────────────────────────────────────
      iconColor: colors.textSecondary,
      selectedIconColor: colors.primary,
      unselectedIconColor: colors.hint,
      // ── 