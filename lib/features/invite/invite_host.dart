import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/router/app_router.dart';
import 'package:meetit/core/services/analytics_service.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/notifiers/auth_notifier.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/invite/compat_reveal_page.dart';
import 'package:meetit/features/invite/invite_link.dart';
import 'package:meetit/features/invite/invite_provider.dart';
import 'package:meetit/features/invite/invite_service.dart';
import 'package:meetit/features/personality/quiz_intro_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Davet akışını uygulama genelinde yürüten görünmez katman
/// (MaterialApp.router builder'ında sarılır):
///
///  1. Kullanıcı hazır olunca (giriş + doğrulama + profil tamam) bir kez
///     panoyu kontrol eder: davet sayfası mağazaya giderken
///     `MEETIT-DAVET:{uid}` kopyalamışsa daveti yakalar (uygulama linkten
///     değil mağazadan ilk kez açıldığında).
///  2. Bekleyen davet varsa davet edenle otomatik arkadaş yapar.
///  3. Kullanıcının kişilik profili varsa (test bitince) uyum ekranını açar
///     ve davet edene uyumu bildirir.
class InviteHost extends ConsumerStatefulWidget {
  final Widget child;
  const InviteHost({super.key, required this.child});

  @override
  ConsumerState<InviteHost> createState() => _InviteHostState();
}

class _InviteHostState extends ConsumerState<InviteHost> {
  static const _kClipboardChecked = 'invite_clipboard_checked';

  bool _busy = false;
  bool _clipboardChecked = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(authProvider, (_, __) => _schedule(),
        fireImmediately: true);
    ref.listenManual<InviteState>(inviteProvider, (_, __) => _schedule(),
        fireImmediately: true);
  }

  void _schedule() {
    // Provider dinleyicisi içinden state değiştirmemek için bir sonraki
    // kareye ertele.
    WidgetsBinding.instance.addPostFrameCallback((_) => _process());
  }

  // Misafirken davet bekletilir: arkadaşlık hesap ister. Hesap açılınca
  // (aynı uid'e bağlanır) bekleyen davet otomatik işlenir.
  bool _isReady(AuthState auth) =>
      !auth.isGuest &&
      !auth.isSessionLoading &&
      !auth.isAwaitingFirebaseRestore &&
      auth.isAuthenticated &&
      !auth.needsEmailVerification &&
      !auth.needsProfileCompletion;

  Future<void> _process() async {
    if (_busy || !mounted) return;
    final auth = ref.read(authProvider);
    final invite = ref.read(inviteProvider);
    final me = auth.user;
    if (!invite.loaded || me == null || !_isReady(auth)) return;

    _busy = true;
    try {
      // 1) Pano (yalnızca bir kez, bekleyen/aktif davet yokken)
      if (!_clipboardChecked) {
        _clipboardChecked = true;
        if (invite.pending == null && invite.reveal == null) {
          await _checkClipboardOnce();
        }
      }

      // 2) Bekleyen davet → otomatik arkadaşlık
      final pending = ref.read(inviteProvider).pending;
      if (pending != null) {
        final inviter = await InviteService.accept(ref, pending.uid);
        await ref.read(inviteProvider.notifier).clearPending();
        if (inviter != null) {
          AnalyticsService.inviteAccepted().ignore();
          await ref
              .read(inviteProvider.notifier)
              .setReveal(InviteRef(inviter.uid, inviter.name));
          // Test henüz çözülmediyse doğrudan teste davet et — uyum ekranı
          // test bitince açılır (aşağıdaki 3. adım).
          if (ref.read(authProvider).user?.personalityProfile == null) {
            await _openQuizIntro();
          }
        }
      }

      // 3) Test bitmişse uyum ekranı
      final reveal = ref.read(inviteProvider).reveal;
      final myProfile = ref.read(authProvider).user?.personalityProfile;
      if (reveal != null && myProfile != null) {
        await ref.read(inviteProvider.notifier).clearReveal();
        final inviter = await _fetchUser(reveal.uid);
        final theirProfile = inviter?.personalityProfile;
        if (inviter != null && theirProfile != null) {
          final compat = myProfile.compatibilityWith(theirProfile);
          final freshMe = ref.read(authProvider).user;
          if (freshMe != null) {
            InviteService.notifyCompat(
              me: freshMe,
              inviterUid: inviter.uid,
              compat: compat,
            ).ignore();
          }
          await _showReveal(inviter, compat);
        }
      }
    } finally {
      _busy = false;
    }
    // İşlem sürerken yeni bir davet geldiyse onu da işle.
    if (mounted && ref.read(inviteProvider).pending != null) _schedule();
  }

  Future<void> _checkClipboardOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kClipboardChecked) ?? false) return;
      await prefs.setBool(_kClipboardChecked, true);
      // hasStrings iOS'ta "yapıştır" izni sormaz; yalnızca metin varsa oku.
      if (!await Clipboard.hasStrings()) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final uid = InviteLink.uidFromClipboard(data?.text);
      if (uid == null) return;
      // Aynı kod tekrar tetiklenmesin diye panoyu temizle.
      await Clipboard.setData(const ClipboardData(text: ''));
      await ref.read(inviteProvider.notifier).setPending(InviteRef(uid));
    } catch (_) {}
  }

  Future<UserModel?> _fetchUser(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      return data == null ? null : UserModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openQuizIntro() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final nav =
        ref.read(appRouterProvider).routerDelegate.navigatorKey.currentState;
    if (nav == null || !mounted) return;
    // Beklemeden (await etmeden) aç: test sürerken host kilitli kalmasın.
    nav.push(MaterialPageRoute<void>(builder: (_) => const QuizIntroPage()));
  }

  Future<void> _showReveal(UserModel inviter, int compat) async {
    // Test sonucu ekranından ana sayfaya geçiş otursun diye kısa bekle.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final nav =
        ref.read(appRouterProvider).routerDelegate.navigatorKey.currentState;
    if (nav == null || !mounted) return;
    await nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CompatRevealPage(inviter: inviter, compat: compat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
