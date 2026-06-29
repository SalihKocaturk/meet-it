import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/utils/important_action_guard.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/friendship_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:meetit/core/widgets/app_alert.dart';

class FriendCodePage extends ConsumerStatefulWidget {
  const FriendCodePage({super.key});

  @override
  ConsumerState<FriendCodePage> createState() => _FriendCodePageState();
}

class _FriendCodePageState extends ConsumerState<FriendCodePage> {
  final _codeController = TextEditingController();
  bool _isSearching = false;
  UserModel? _foundUser;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _myCode(String uid) {
    // UID'nin ilk 6 karakterini büyük harfe çevir → arkadaş kodu
    return uid.substring(0, 6).toUpperCase();
  }

  Future<void> _searchByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _errorText = 'friend_code.incomplete_code'.tr());
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _errorText = null;
    });

    try {
      // Firestore'daki tüm kullanıcıları tara — uid'nin başı kodla eşleşiyor mu?
      final snap = await FirebaseFirestore.instance.collection('users').get();
      UserModel? found;
      for (final doc in snap.docs) {
        final uid = doc.id;
        if (uid.length >= 6 && uid.substring(0, 6).toUpperCase() == code) {
          found = UserModel.fromMap(doc.data());
          break;
        }
      }

      setState(() {
        _isSearching = false;
        if (found == null) {
          _errorText = 'friend_code.user_not_found'.tr();
        } else {
          final myUid = ref.read(authProvider).user?.uid;
          if (found.uid == myUid) {
            _errorText = 'friend_code.own_code'.tr();
          } else {
            _foundUser = found;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorText = 'friend_code.search_error'.tr();
      });
    }
  }

  Future<void> _sendRequest(UserModel targetUser) async {
    // NOT: Arkadaş ekleme "önemli işlem" sayılıyor — kullanıcı email'ini
    // doğrulamadan arkadaş ekleyemesin. Doğrulanmamışsa burada
    // VerificationPage PUSH edilir; kullanıcı vazgeçerse (geri tuşu/
    // "Daha Sonra") `false` döner ve işlem burada durur.
    // bkz. `important_action_guard.dart`.
    if (!await ensureEmailVerified(context, ref)) return;
    if (!mounted) return;

    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    // Zaten arkadaş, bekleyen istek var mı, yoksa KARŞI TARAF ZATEN BANA
    // istek mi göndermiş (mutual match) — üç durumu da ayırt ediyoruz.
    //
    // 🐛 BUG FIX (2026-06-29): Önceden doküman varlığı tek başına
    // "already_exists" uyarısı için yeterliydi — bu, karşı tarafın bana
    // zaten istek gönderdiği (mutual) durumu da kapsıyordu ve bu yüzden
    // sendFriendRequest hiç çağrılmıyor, karşılıklı istek asla arkadaşlığa
    // dönüşmüyordu. Artık sadece "zaten arkadaşsınız" veya "ben zaten
    // istek atmışım" durumlarında uyarı gösteriyoruz; karşı taraftan
    // gelen pending bir istek varsa sendFriendRequest'i çağırıyoruz —
    // notifier artık bu durumu kendi içinde algılayıp otomatik kabul
    // ediyor (bkz. friends_notifier.dart).
    final docId = FriendshipModel.docId(currentUid, targetUser.uid);
    final existingSnap = await FirebaseFirestore.instance
        .collection('friendships')
        .doc(docId)
        .get();

    var mutualMatch = false;
    if (existingSnap.exists) {
      final existing = FriendshipModel.fromMap(docId, existingSnap.data()!);
      if (existing.status == FriendshipStatus.accepted) {
        if (!mounted) return;
        showAppAlert(
          context: context,
          type: AppAlertType.warning,
          title: 'friend_code.already_exists'.tr(),
          text: 'friend_code.already_exists_desc'.tr(),
          confirmBtnColor: context.colors.primary,
        );
        return;
      }
      if (existing.status == FriendshipStatus.pending &&
          existing.fromUid == currentUid) {
        if (!mounted) return;
        showAppAlert(
          context: context,
          type: AppAlertType.warning,
          title: 'friend_code.already_exists'.tr(),
          text: 'friend_code.already_exists_desc'.tr(),
          confirmBtnColor: context.colors.primary,
        );
        return;
      }
      // existing.fromUid == targetUser.uid && status == pending →
      // karşı taraf bana zaten istek göndermiş, devam et (mutual match).
      if (existing.status == FriendshipStatus.pending) {
        mutualMatch = true;
      }
    }

    await ref.read(friendsProvider.notifier).sendFriendRequest(targetUser.uid);

    if (!mounted) return;
    showAppAlert(
      context: context,
      type: AppAlertType.success,
      title: mutualMatch
          ? 'friend_code.matched'.tr()
          : 'friend_code.request_sent'.tr(),
      text: mutualMatch
          ? 'friend_code.matched_desc'.tr(namedArgs: {'name': targetUser.name})
          : 'friend_code.request_sent_desc'.tr(namedArgs: {'name': targetUser.name}),
      confirmBtnColor: context.colors.primary,
      onConfirmBtnTap: () {
        Navigator.pop(context);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myCode = currentUser != null ? _myCode(currentUser.uid) : '------';

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'friend_code.title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Benim kodum ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.primary,
                    context.colors.primary.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    'friend_code.my_code'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    myCode,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: myCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('friend_code.code_copied'.tr()),
                          backgroundColor: context.colors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.card.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'friend_code.copy'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28),

            // ── Kod ile ara ────────────────────────────────────────────────
            Text(
              'friend_code.enter_code'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'ABC123',
                      hintStyle: TextStyle(
                        color: context.colors.hint.withOpacity(0.5),
                        letterSpacing: 6,
                        fontSize: 20,
                      ),
                      filled: true,
                      fillColor: context.colors.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.5,
                        ),
                      ),
                      errorText: _errorText,
                    ),
                    onChanged: (_) => setState(() => _errorText = null),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchByCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSearching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.card,
                          ),
                        )
                      : Text(
                          'common.search'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),

            // ── Bulunan kullanıcı ──────────────────────────────────────────
            if (_foundUser != null) ...[
              SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: context.colors.primary.withOpacity(0.15),
                      backgroundImage: _foundUser!.photoUrl != null
                          ? NetworkImage(_foundUser!.photoUrl!)
                          : null,
                      child: _foundUser!.photoUrl == null
                          ? Text(
                              _foundUser!.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: context.colors.primary,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _foundUser!.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (_foundUser!.personalityProfile != null)
                            Text(
                              '${_foundUser!.personalityProfile!.dominantType.emoji} ${_foundUser!.personalityProfile!.dominantType.displayName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          if (_foundUser!.location != null)
                            Text(
                              '📍 ${_foundUser!.location}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendRequest(_foundUser!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
              