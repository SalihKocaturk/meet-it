import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meetit/core/services/notification_service.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/providers/personality_provider.dart';

const _kSessionKey = 'meetit_session';

/// Session versiyonu — UserModel şeması değişince bu sayıyı artır.
/// Güncelleme sonrası eski versiyondaki session otomatik temizlenir ve
/// kullanıcıdan bir kez temiz giriş yapması istenir.
///
/// Ne zaman artırılmalı:
///  • UserModel'e yeni ZORUNLU alan eklenince
///  • fromMap / toMap mantığı geriye dönük uyumsuz değişince
///
/// ÖNEMLİ: sadece gerçekten gerektiğinde artır — her artışta tüm
/// kullanıcılar bir kez daha giriş yapmak zorunda kalır.
const _kSessionVersion = 1;
const _kSessionVersionKey = 'meetit_session_ver';

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

  /// Local session var ama Firebase Auth henüz token'ı yükleyemedi
  /// (Samsung force-kill sonrası ağ kısıtlaması vb.). Bu flag true iken
  /// router kullanıcıyı SessionRestoringPage'de tutar; Firebase gelince
  /// auto-restore edilir, 15s timeout'ta login ekranına gönderilir.
  final bool isAwaitingFirebaseRestore;

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
    this.isAwaitingFirebaseRestore = false,
    this.errorMessage,
    this.needsEmailVerification = false,
  });

  bool get isAuthenticated => user != null;
  bool get hasPersonality => user?.personalityProfile != null;

  /// Google ile ilk kez giriş yapan bir kullanıcının profili eksik kalır:
  /// `signInWithGoogle()` sadece uid/isim/email/foto ile minimal bir
  /// UserModel oluşturur — konum, yaş ve cinsiyet alanları boş kalır (bkz.
  /// auth_notifier.signInWithGoogle). Email/şifre ile kayıt olan
  /// kullanıcılarda bu alanlar sign_up formunda ZORUNLU olduğu için bu
  /// getter onlar için her zaman false döner — yalnızca eksik-profilli
  /// Google kullanıcılarını yakalar.
  bool get needsProfileCompletion {
    final u = user;
    if (u == null) return false;
    final locationMissing = u.location == null || u.location!.trim().isEmpty;
    // NOT (bug fix): `gender` BİLEREK bu kontrole dahil EDİLMİYOR. Cinsiyet
    // alanı tüm formlarda (sign_up, edit_profile, complete_profile) UI'da
    // "opsiyonel" olarak etiketleniyor ve `UserModel.gender` nullable —
    // ama bu getter eskiden gender boşsa da kullanıcıyı sürekli
    // CompleteProfilePage'e geri yönlendiriyordu, bu da gerçekte opsiyonel
    // olması gereken bir alanı fiilen ZORUNLU hale getiriyordu (kullanıcı
    // cinsiyet seçmeden asla devam edemiyordu). Sadece gerçekten zorunlu
    // olan location/age burada kontrol ediliyor.
    return locationMissing || u.age == null;
  }

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isSessionLoading,
    bool? isAwaitingFirebaseRestore,
    String? errorMessage,
    bool? needsEmailVerification,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isSessionLoading: isSessionLoading ?? this.isSessionLoading,
      isAwaitingFirebaseRestore:
          isAwaitingFirebaseRestore ?? this.isAwaitingFirebaseRestore,
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

  /// Firebase Auth, _restoreSession() çalışmadan önce `null` event'i
  /// emit ettiyse true olur. Bu durumda token kesinlikle yok — restore
  /// page göstermeden direkt login'e gönder.
  bool _firebaseEmittedNullEarly = false;

  @override
  AuthState build() {
    // Firebase Auth state'ini sürekli dinle.
    // Samsung gibi agresif süreç yönetiminde force-kill sonrası Firebase Auth,
    // token'ını 15+ saniyede yüklüyor (ağ kısıtlaması vb.). Bu durumda
    // _restoreSession() erken çalışırsa currentUser null bulur.
    // authStateChanges() Firebase yüklenince bizi haberdar eder → auto-restore.
    final sub = FirebaseAuth.instance.authStateChanges().listen(_onFirebaseAuthChange);
    ref.onDispose(sub.cancel);

    Future(() => _restoreSession());
    return const AuthState(isSessionLoading: true);
  }

  /// Firebase Auth state değişikliklerini işle.
  /// Üç durum önemli:
  ///   1. isSessionLoading: true iken Firebase null emit ettiyse → kaydet (token kesinlikle yok).
  ///   2. Restore beklerken Firebase null gelirse → restore iptal, hızlı login.
  ///   3. Firebase geç yüklendiyse → local session varsa restore et.
  ///   4. Kullanıcı giriş yapmışken Firebase null döndürürse → oturumu kapat.
  void _onFirebaseAuthChange(User? fbUser) {
    if (state.isSessionLoading) {
      // _restoreSession() henüz çalışıyor. Firebase null event'ini kaydet —
      // token gerçekten yok demektir. _restoreSession() bunu okuyunca restore
      // page göstermeden direkt login ekranına gider.
      if (fbUser == null) {
        _firebaseEmittedNullEarly = true;
        debugPrint('[Session] Firebase early null — token yok (session loading sırasında)');
      }
      return;
    }

    if (fbUser != null && !state.isAuthenticated) {
      // Firebase geç yüklendi (Samsung force-kill senaryosu).
      // Login ekranındayken arka planda token geldi → local session varsa restore et.
      debugPrint('[Session] Firebase geç yüklendi → auto-restore deneniyor');
      _tryAutoRestoreFromLocal(fbUser).ignore();
    } else if (fbUser == null && state.isAwaitingFirebaseRestore) {
      // Restore page gösterilirken Firebase null bildirdi → token yok, bekleme anlamsız.
      debugPrint('[Session] Firebase null → restore iptal → login ekranı');
      state = state.copyWith(isAwaitingFirebaseRestore: false);
    } else if (fbUser == null && state.isAuthenticated) {
      // Firebase kullanıcıyı iptal etti (şifre değişti, hesap silindi vb.)
      // → oturumu kapat.
      debugPrint('[Session] Firebase auth iptal → oturum kapatılıyor');
      signOut();
    }
  }

  /// [_restoreSession] Firebase null bulduğunda kısa süre bekler.
  ///
  /// Samsung gibi cihazlarda force-kill sonrası Firebase Auth 20-30 saniye askıda
  /// kalabilir. 3 saniye sonra SessionRestoringPage'den login ekranına geçilir,
  /// ANCAK authStateChanges() dinleyicisi arka planda çalışmaya devam eder:
  /// Firebase geç yüklenirse (_onFirebaseAuthChange) kullanıcı login ekranındayken
  /// bile auto-restore edilir → SignInPage'deki ref.listen ana ekrana yönlendirir.
  void _startFirebaseRestoreTimeout() {
    Timer(const Duration(seconds: 3), () {
      if (state.isAwaitingFirebaseRestore) {
        debugPrint('[Session] Firebase restore timeout (3s) → login ekranı (arka planda dinleniyor)');
        state = state.copyWith(isAwaitingFirebaseRestore: false);
      }
    });
  }

  /// Firebase Auth geç yüklendikten sonra SharedPreferences'taki local
  /// session'ı restore etmeyi dener. Sadece oturum kapalıyken çağrılır.
  Future<void> _tryAutoRestoreFromLocal(User fbUser) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt(_kSessionVersionKey);
      if (savedVersion != _kSessionVersion) {
        debugPrint('[Session] auto-restore: versiyon uyuşmuyor, atlanıyor');
        return;
      }
      final raw = prefs.getString(_kSessionKey);
      if (raw == null) {
        debugPrint('[Session] auto-restore: local session yok, atlanıyor');
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final user = UserModel.fromMap(map);
      debugPrint('[Session] auto-restore başarılı → uid=${user.uid}');
      state = state.copyWith(user: user, isAwaitingFirebaseRestore: false);
      _syncUserFromFirestore(user.uid).ignore();
    } catch (e) {
      debugPrint('[Session] auto-restore hata: $e');
    }
  }

  /// Samsung force-kill sonrası Firebase Auth token'ı gider ama Google'ın
  /// kendi hesap cache'i cihazda kalır. Bu metod `signInSilently()` ile
  /// sessizce yeniden auth yapar, Firebase token'ını yeniler, ardından
  /// SharedPreferences'taki local session'ı restore eder.
  ///
  /// Başarılıysa state'i günceller ve `true` döner.
  /// Kullanıcı Google ile giriş yapmamışsa veya hata varsa `false` döner
  /// → caller login ekranına yönlendirir.
  Future<bool> _trySilentGoogleRestore(String sessionRaw) async {
    try {
      debugPrint('[Session] Google silent sign-in deneniyor...');
      final googleUser = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (googleUser == null) {
        debugPrint('[Session] Google silent sign-in: hesap yok veya timeout');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      debugPrint('[Session] Google silent sign-in başarılı → Firebase Auth yenilendi');

      final map = jsonDecode(sessionRaw) as Map<String, dynamic>;
      final user = UserModel.fromMap(map);
      debugPrint('[Session] Silent restore tamamlandı → uid=${user.uid}');
      state = state.copyWith(user: user, isSessionLoading: false);
      _syncUserFromFirestore(user.uid).ignore();
      return true;
    } catch (e) {
      debugPrint('[Session] Google silent sign-in hata: $e');
      return false;
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    debugPrint('[Session] _restoreSession başladı');
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Session versiyon kontrolü ────────────────────────────────────────
      // UserModel şeması değiştiğinde _kSessionVersion'ı artır → eski session
      // otomatik temizlenir, kullanıcıdan bir kez temiz giriş istenir.
      final savedVersion = prefs.getInt(_kSessionVersionKey);
      debugPrint('[Session] versiyon: saved=$savedVersion beklenen=$_kSessionVersion');
      if (savedVersion != _kSessionVersion) {
        debugPrint('[Session] versiyon uyuşmuyor → session temizleniyor');
        await prefs.remove(_kSessionKey);
        await prefs.remove(_kSessionVersionKey);
        state = state.copyWith(isSessionLoading: false);
        return;
      }

      final raw = prefs.getString(_kSessionKey);
      debugPrint('[Session] raw session var mı: ${raw != null} (uzunluk: ${raw?.length ?? 0})');

      if (raw == null) {
        // Hiç session yok.
        debugPrint('[Session] session yok → login ekranı');
        state = state.copyWith(isSessionLoading: false);
        return;
      }

      // ── Firebase Auth kontrolü ───────────────────────────────────────────
      // main.dart'ta `runApp`'tan önce Firebase Auth pre-warm yapıldığı için
      // bu noktada `currentUser` güvenilir bir değer taşır:
      //   • Giriş yapılmışsa → non-null (token refresh dahil tamamlandı).
      //   • Çıkış yapılmışsa / timeout'sa → null.
      // Bu sayede session'ı yanlışlıkla silme riski ortadan kalktı.
      final fbUser = FirebaseAuth.instance.currentUser;
      debugPrint('[Session] Firebase currentUser: ${fbUser?.uid ?? "NULL"}');

      if (fbUser != null) {
        // Firebase Auth onayladı + local session var → güvenli restore.
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final user = UserModel.fromMap(map);
        debugPrint('[Session] restore başarılı → uid=${user.uid}');
        state = state.copyWith(user: user, isSessionLoading: false);

        // Arka planda Firestore'dan güncel veriyi çek (isPremium vb.).
        _syncUserFromFirestore(user.uid).ignore();
      } else {
        // Firebase Auth henüz null. İki ihtimal:
        //   a) authStateChanges() zaten null emit etti (token kesinlikle yok)
        //      → restore page gösterme, direkt login.
        //   b) Firebase henüz hiç emit etmedi (token yolda olabilir)
        //      → SessionRestoringPage göster, 15s bekle.
        if (_firebaseEmittedNullEarly) {
          // Samsung force-kill: Firebase kendi token'ını da kaybetmiş.
          // Google ile giriş yapmış kullanıcılar için sessiz yeniden auth dene —
          // GoogleSignIn'in kendi cache'i Samsung tarafından silinmiyor.
          final restored = await _trySilentGoogleRestore(raw);
          if (!restored) {
            // Email/şifre kullanıcısı veya Google hesabı yok → login ekranı.
            debugPrint('[Session] Silent restore başarısız → login ekranı');
            state = state.copyWith(isSessionLoading: false);
          }
          // restored == true: state _trySilentGoogleRestore içinde set edildi.
        } else {
          // Firebase henüz bir şey söylemedi — belki token geliyor.
          debugPrint('[Session] Firebase null → restore bekleniyor (SessionRestoringPage)');
          state = state.copyWith(
            isSessionLoading: false,
            isAwaitingFirebaseRestore: true,
          );
          // 15 saniye içinde Firebase gelmezse login ekranına düş.
          _startFirebaseRestoreTimeout();
        }
      }
    } catch (e) {
      // JSON parse hatası gibi beklenmedik durum → temizle.
      debugPrint('[Session] hata: $e → session temizleniyor');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
      await prefs.remove(_kSessionVersionKey);
      state = state.copyWith(isSessionLoading: false);
    }
  }

  /// Firestore'daki güncel kullanıcı verisini çekip hem state'i hem
  /// session'ı sessizce günceller. Hata olursa mevcut state bozulmaz.
  Future<void> _syncUserFromFirestore(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final fresh = UserModel.fromMap(snap.data()!);
      await _saveSession(fresh);
      state = state.copyWith(user: fresh);
    } catch (_) {
      // Ağ hatası vb. — mevcut state korunur, sessizce devam.
    }
  }

  Future<void> _saveSession(UserModel user) async {
    debugPrint('[Session] _saveSession çağrıldı: uid=${user.uid}');
    final prefs = await SharedPreferences.getInstance();
    final r1 = await prefs.setString(_kSessionKey, jsonEncode(user.toMap()));
    // Session versiyonunu da kaydet — güncelleme sonrası eski session
    // tespiti için kullanılır (bkz. _restoreSession).
    final r2 = await prefs.setInt(_kSessionVersionKey, _kSessionVersion);
    debugPrint('[Session] _saveSession tamamlandı: sessionOk=$r1 versionOk=$r2');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
    await prefs.remove(_kSessionVersionKey);
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
      // FCM token'ı Firestore'a kaydet (push bildirimleri için)
      NotificationService.saveFcmToken(user.uid).ignore();
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
      // FCM token'ı Firestore'a kaydet (push bildirimleri için)
      NotificationService.saveFcmToken(user.uid).ignore();
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
      // FCM token'ı Firestore'a kaydet (push bildirimleri için)
      NotificationService.saveFcmToken(savedUser.uid).ignore();
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

  /// İlk kez Google ile giriş yapan ve profili eksik kalan (konum/yaş/
  /// cinsiyet) kullanıcı için `CompleteProfilePage`'den çağrılır.
  ///
  /// `signInWithGoogle()` sadece minimal bir UserModel oluşturduğu için
  /// (bkz. `needsProfileCompletion` getter'ı), router bu kullanıcıyı quiz/
  /// ana sayfadan ÖNCE bu sayfaya yönlendirir. Burada eksik alanlar
  /// tamamlanır, hem state'e hem Firestore'a yazılır — email doğrulama
  /// adımı YOK (Google hesapları zaten doğrulanmış sayılır), bu yüzden
  /// `needsEmailVerification` hiç set edilmiyor/dokunulmuyor.
  Future<void> completeProfile({
    required String location,
    required int age,
    String? gender,
    double? lat,
    double? lng,
  }) async {
    final user = state.user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final updatedUser = user.copyWith(
      location: location,
      age: age,
      // Cinsiyet opsiyonel — kullanıcı seçmediyse mevcut (boş) değeri koru,
      // var olan bir değeri sıfırlamayız.
      gender: gender ?? user.gender,
      lat: lat ?? user.lat,
      lng: lng ?? user.lng,
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updatedUser.toMap(), SetOptions(merge: true));
      await _saveSession(updatedUser);
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      debugPrint('[completeProfile] error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'auth.sign_up_failed',
      );
    }
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

  // ── Premium ───────────────────────────────────────────────────────────────

  /// Kullanıcının premium durumunu günceller — hem Firestore'a yazar hem de
  /// local state + session'ı anında yansıtır.
  ///
  /// Kullanım senaryoları:
  ///   • İleride: in-app purchase doğrulandıktan sonra `setPremium(true)`
  ///   • Test/admin: Firebase Console'dan el ile `isPremium: true` yazmak
  ///     yerine (veya ek olarak) direkt çağrılabilir.
  ///   • Abonelik iptal: `setPremium(false)`
  Future<void> setPremium(bool value) async {
    final user = state.user;
    if (user == null) return;
    if (user.isPremium == value) return; // değişiklik yok

    final updatedUser = user.copyWith(isPremium: value);
    await _saveSession(updatedUser);
    state = state.copyWith(user: updatedUser);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isPremium': value,
      });
    } catch (e) {
      debugPrint('[setPremium] Firestore write failed: $e');
      // Firestore hatası local state'i geri almaz — bir sonraki sync düzeltir.
    }
  }

  // ── Çıkış ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // FCM token'ı temizle — bu cihaza artık bildirim gönderilmesin
    final uid = state.user?.uid;
    if (uid != null) {
      NotificationService.clearFcmToken(uid).ignore();
    }
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _clearSession();
    // Quiz state'ini sıfırla — bir sonraki kullanıcıda temiz başlasın
    ref.invalidate(quizProvider);
    state = const AuthState();
  }

  /// Hesabı kalıcı olarak siler.
  ///
  /// Sırayla: FCM token temizle → Firestore dokümanını sil → Firebase Auth
  /// hesabını sil → session temizle → state sıfırla.
  ///
  /// Başarılıysa `null` döner. Hata varsa çeviri anahtarı döner.
  /// Firebase Auth bazen son girişin üzerinden uzun süre geçmişse
  /// `requires-recent-login` hatası fırlatır — bu durumda kullanıcıya
  /// tekrar giriş yapması gerektiği söylenir.
  Future<String?> deleteAccount() async {
    try {
      final uid = state.user?.uid;
      if (uid == null) return 'auth.error_generic';

      // FCM token'ı önce temizle
      NotificationService.clearFcmToken(uid).ignore();

      // Firestore'daki kullanıcı dokümanını sil
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // Firebase Auth hesabını sil
      final fbUser = _auth.currentUser;
      if (fbUser == null) return 'auth.error_generic';
      await fbUser.delete();

      // Yerel session + state temizle
      await _googleSignIn.signOut();
      await _clearSession();
      ref.invalidate(quizProvider);
      state = const AuthState();
      return null; // başarı
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'settings.delete_account_relogin';
      }
      return 'auth.error_generic';
    } catch (_) {
      return 'auth.error_generic';
    }
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
