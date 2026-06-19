import 'dart:convert';

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

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isSessionLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isSessionLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;
  bool get hasPersonality => user?.personalityProfile != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isSessionLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isSessionLoading: isSessionLoading ?? this.isSessionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
      state = state.copyWith(user: user, isLoading: false);
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

      final user = UserModel(
        uid: cred.user!.uid,
        name: name,
        email: email,
        location: location,
        age: age,
        gender: gender,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      await _saveSession(user);
      state = state.copyWith(user: user, isLoading: false);
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

  // ── Personality ───────────────────────────────────────────────────────────

  /// Profil güncellemesi sonrası local state + session güncelle
  Future<void> updateUser(UserModel updatedUser) async {
    await _saveSession(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  /// Quiz bittikten sonra kişilik profilini hem state'e hem Firestore'a yaz.
  Future<void> setPersonalityProfile(PersonalityProfile profile) async {
    final user = state.user;
    if (user == null) return;

    final updatedUser = user.copyWith(personalityProfile: profile);
    await _saveSession(updatedUser);

    // Firestore'a kaydet
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'personalityProfile': profile.toMap(),
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
    await _googleSignIn.sig