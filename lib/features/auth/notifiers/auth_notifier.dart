import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/providers/personality_provider.dart';

const _kSessionKey = 'meetit_session';

/// `UserModel.personalityHistory` listesinin tutacağı maksimum anlık
/// görüntü (snapshot) sayısı — sınırsız büyüyüp Firestore doküman boyutunu
/// şişirmesin diye en eski kayıtlar bu sınırın üzerinde silinir. 40 kayıt,
/// haftada birkaç mekan ziyareti yapan bir kullanıcı için aylarca yetecek
/// bir geçmiş sağlıyor.
const kMaxPersonalityHistory = 40;

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isSessionLoading;
  final String? errorMessage;

  /// Firebase'deki `currentUser.emailVerified` durumunu yansıtır.
  ///
  /// NOT: Bu alan KASITLI OLARAK SharedPreferences'a / session'a
  /// kalıcı yazılmıyor (sadece in-memory) — çünkü kaynağı her zaman
  /// Firebase'in o anki durumu olmalı; cihazda eski/yanlış bir değer
  /// "yapışıp" kalmasın. Email/şifre ile giriş yapan kullanıcılar için
  /// `signIn`/`signUp` sırasında taze hesaplanır. Google ile giriş yapan
  /// kullanıcılarda her zaman `false` kalır (Google hesapları zaten
  /// Google tarafından doğrulanmış sayılır).
  final bool needsEmailVerification;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isSessionLoading = false,
    this.errorMessage,
    this.needsEmailVerification = false,
  });

  bool get isAuthenticated => user != null;
  bool get hasPersonality => user?.personalityProfile != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isSessionLoading,
    String? errorMessage,
    bool? needsEmailVerification,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isSessionLoading: isSessionLoading ?? this.isSessionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsEmailVerification:
          needsEmailVerification ?? this.needsEmailVerification,
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  @override
  AuthState build() {
    Future(() => _restoreSession());
    return const AuthState(isSessionLoading: true);
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final user = UserModel.fromMap(map);
        state = state.copyWith(user: user, isSessionLoading: false);
      } else {
        state = state.copyWith(isSessionLoading: false);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
      state = state.copyWith(isSessionLoading: false);
    }
  }

  Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(user.toMap()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  // ── Firestore Yardımcıları ────────────────────────────────────────────────

  /// Kullanıcı Firestore'da yoksa oluştur, varsa mevcut veriyi döner.
  Future<UserModel> _upsertFirestoreUser(UserModel user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get();

    if (!snap.exists) {
      await doc.set(user.toMap());
      return user;
    } else {
      // Mevcut kullanıcı — Firestore'daki veriyi döner (personality korunur)
      return UserModel.fromMap(snap.data()!);
    }
  }

  // ── Email / Şifre ─────────────────────────────────────────────────────────

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(
          errorMessage: 'validation.email_empty');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final fbUser = cred.user!;

      // Firebase'in cache'lediği `emailVerified` bayrağı eski olabilir
      // (kullanıcı linke tıkladıktan sonra cihazda hâlâ "doğrulanmamış"
      // görünebilir) — taze durum için sunucudan yeniden çekiyoruz.
      try {
        await fbUser.reload();
      } catch (_) {}
      final isVerified = _auth.currentUser?.emailVerified ?? fbUser.emailVerified;

      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      late UserModel user;
      if (doc.exists) {
        user = UserModel.fromMap(doc.data()!);
      } else {
        user = UserModel(
          uid: fbUser.uid,
          name: fbUser.displayName ?? email.split('@').first,
          email: email,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(fbUser.uid).set(user.toMap());
      }

      await _saveSession(user);
      state = state.copyWith(
        user: user,
        isLoading: false,
        needsEmailVerification: !isVerified,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _authError(e.code),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'auth.sign_in_failed',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String? location,
    int? age,
    String? gender,
    String? photoUrl,
    double? lat,
    double? lng,
  }) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      state = state.copyWith(errorMessage: 'validation.fill_required');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user!.updateDisplayName(name);

      // Hesaba onay (doğrulama) maili gönder. Bu çağrı Firebase Auth
      // tarafından otomatik olarak gerçek bir email gönderir — ekstra bir
      // backend/SMTP kurulumu gerekmez. Gönderim başarısız olsa bile (örn.
      // ağ hatası) kayıt akışını durdurmuyoruz; kullanıcı doğrulama
      // sayfasından "Tekrar Gönder" ile yeniden deneyebilir.
      try {
        await cred.user!.sendEmailVerification();
      } catch (e) {
        // TEŞHİS: Gerçek hata kodu görünür olsun — "mail gönderilemiyor"
        // şikayetinin asıl sebebini görmek için (geçici debug log).
        debugPrint('[sendEmailVerification/signUp] error: $e');
      }

      final user = UserModel(
        uid: cred.user!.uid,
        name: name,
        email: email,
        location: location,
        age: age,
        gender: gender,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        lat: lat,
        lng: lng,
      );

      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      await _saveSession(user);
      state = state.copyWith(
        user: user,
        isLoading: false,
        needsEmailVerification: true,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _authError(e.code),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'auth.sign_up_failed',
      );
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı iptal etti
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final fbUser = cred.user!;

      final userModel = UserModel(
        uid: fbUser.uid,
        name: fbUser.displayName ?? googleUser.displayName ?? 'common.user'.tr(),
        email: fbUser.email ?? googleUser.email,
        photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
        createdAt: DateTime.now(),
      );

      // Firestore'da yoksa oluştur, varsa mevcut veriyi al
      final savedUser = await _upsertFirestoreUser(userModel);

      await _saveSession(savedUser);
      state = state.copyWith(user: savedUser, isLoading: false);
    } on FirebaseAuthException catch (e) {
      // TEŞHİS: Gerçek hata kodu görünür olsun (geçici debug log — sorun
      // bulununca kaldırılacak). 'flutter run' loglarında "[GoogleSignIn]"
      // ile filtrelenebilir.
      debugPrint('[GoogleSignIn] FirebaseAuthException code=${e.code} message=${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _authError(e.code),
      );
    } catch (e, st) {
      // TEŞHİS: catch(e) öncesi gerçek istisna yutuluyordu — şimdi yazdırılıyor.
      debugPrint('[GoogleSignIn] unexpected error: $e');
      debugPrint('[GoogleSignIn] stack: $st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'auth.sign_in_failed',
      );
    }
  }

  // ── Şifre Sıfırlama ───────────────────────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    if (email.isEmpty) {
      state = state.copyWith(errorMessage: 'auth.enter_email_warning');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _authError(e.code),
      );
    }
  }

  // ── Email Doğrulama ───────────────────────────────────────────────────────

  /// Firebase'den taze kullanıcı durumunu çekip `emailVerified` bayrağını
  /// kontrol eder ve `state.needsEmailVerification`'ı güncelleyip sonucu
  /// (true = doğrulanmış) döner. [VerificationPage]'deki "Doğruladım" butonu
  /// bunu çağırır.
  Future<bool> checkEmailVerified() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return false;
    try {
      await fbUser.reload();
    } catch (_) {
      return !state.needsEmailVerification;
    }
    final isVerified = _auth.currentUser?.emailVerified ?? false;
    state = state.copyWith(needsEmailVerification: !isVerified);
    return isVerified;
  }

  /// Doğrulama emailini tekrar gönderir. Başarılıysa `true` döner.
  Future<bool> resendVerificationEmail() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return false;
    try {
      await fbUser.sendEmailVerification();
      return true;
    } catch (e) {
      // TEŞHİS: Gerçek hata kodu görünür olsun (geçici debug log).
      debugPrint('[sendEmailVerification/resend] error: $e');
      return false;
    }
  }

  // ── Personality ───────────────────────────────────────────────────────────

  /// Profil güncellemesi sonrası local state + session güncelle
  Future<void> updateUser(UserModel updatedUser) async {
    await _saveSession(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  /// Quiz bittikten sonra VEYA bir mekan ziyaretiyle (`evolvedWith`) profil
  /// değiştiğinde çağrılır — yeni profili hem state'e hem Firestore'a yazar.
  ///
  /// Ayrıca [PersonalityHistoryChart] tarafından kullanılan zaman serisine
  /// (`personalityHistory`) bu anki profilin bir anlık görüntüsünü ekler.
  /// Bu sayede "kişiliğim zamanla nasıl değişti" sorusu, sadece son durumu
  /// değil, geçmişteki her güncellemeyi de gösterebilir.
  Future<void> setPersonalityProfile(PersonalityProfile profile) async {
    final user = state.user;
    if (user == null) return;

    final updatedHistory = [...user.personalityHistory, profile];
    // En eski kayıtları kırp — sınırsız büyümesin.
    final trimmedHistory = updatedHistory.length > kMaxPersonalityHistory
        ? updatedHistory.sublist(updatedHistory.length - kMaxPersonalityHistory)
        : updatedHistory;

    final updatedUser = user.copyWith(
      personalityProfile: profile,
      personalityHistory: trimmedHistory,
    );
    await _saveSession(updatedUser);

    // Firestore'a kaydet
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'personalityProfile': profile.toMap(),
        'personalityHistory': trimmedHistory.map((p) => p.toMap()).toList(),
      });
    } catch (_) {
      // Firestore hatası session'ı etkilemesin
    }

    state = state.copyWith(user: updatedUser);
  }

  /// Kullanıcının haritadan seçtiği konumu hem state'e hem Firestore'a yaz.
  ///
  /// Bu, arkadaşların buluşma mekanı ararken konumumu her zaman DB'den
  /// güvenilir bir şekilde okuyabilmesini sağlar — anlık konum servisinin
  /// açık olmasına veya her seferinde yeniden konum girilmesine gerek
  /// kalmaz. `address` verilirse kullanıcıya gösterilen metin konum
  /// (örn. "Kadıköy, İstanbul") de güncellenir.
  Future<void> updateLocation(double lat, double lng, {String? address}) async {
    final user = state.user;
    if (user == null) return;

    final updatedUser = user.copyWith(
      lat: lat,
      lng: lng,
      location: address ?? user.location,
    );
    await _saveSession(updatedUser);

    // Firestore'a kaydet
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lat': lat,
        'lng': lng,
        if (address != null) 'location': address,
      });
    } catch (_) {
      // Firestore hatası session'ı etkilemesin
    }

    state = state.copyWith(user: updatedUser);
  }

  // ── Çıkış ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _clearSession();
    // Quiz state'ini sıfırla — bir sonraki kullanıcıda temiz başlasın
    ref.invalidate(quizProvider);
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Hata Mesajları ────────────────────────────────────────────────────────

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':       return 'auth.error_user_not_found';
      case 'wrong-password':       return 'auth.error_wrong_password';
      case 'email-already-in-use': return 'auth.error_email_in_use';
      case 'weak-password':        return 'auth.error_weak_password';
      case 'invalid-email':        return 'auth.error_invalid_email';
      case 'too-many-requests':    return 'auth.error_too_many_requests';
      case 'network-request-failed': return 'auth.error_no_network';
      default:                     return 'auth.error_generic';
    }
  }
}
