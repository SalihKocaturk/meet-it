import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Huni (funnel) ölçümü için Firebase Analytics olayları.
///
/// Firebase Console → Analytics → Funnels ile şu sıra izlenebilir:
///   first_open → sign_up / guest_start → quiz_complete → venue_search
///   → (venues_shown) → share_* olayları
///
/// Hata olursa sessizce yutulur — ölçüm hiçbir akışı bozmamalı.
abstract final class AnalyticsService {
  static final _a = FirebaseAnalytics.instance;

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _a.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] $name hatası: $e');
    }
  }

  static Future<void> setUser(String? uid) async {
    try {
      await _a.setUserId(id: uid);
    } catch (_) {}
  }

  /// method: email | google | apple
  static Future<void> signUp(String method) async {
    try {
      await _a.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  static Future<void> login(String method) async {
    try {
      await _a.logLogin(loginMethod: method);
    } catch (_) {}
  }

  static Future<void> guestStart() => _log('guest_start');

  /// Misafir hesabını Google/Apple/e-posta ile kalıcı hesaba çevirdi.
  static Future<void> guestUpgrade(String method) =>
      _log('guest_upgrade', {'method': method});

  static Future<void> quizComplete(String dominantType) =>
      _log('quiz_complete', {'type': dominantType});

  static Future<void> quizSkipped() => _log('quiz_skipped');

  /// mode: solo | friend | location_link
  static Future<void> venueSearch(String mode) =>
      _log('venue_search', {'mode': mode});

  static Future<void> venuesShown(int count, String mode) =>
      _log('venues_shown', {'count': count, 'mode': mode});

  static Future<void> shareCard() => _log('share_personality_card');
  static Future<void> shareDuoCard() => _log('share_duo_card');
  static Future<void> inviteAccepted() => _log('invite_accepted');

  static Future<void> locationRequestCreated() =>
      _log('location_request_created');
  static Future<void> locationRequestShared() =>
      _log('location_request_shared');

  static Future<void> pollCreated(int options) =>
      _log('poll_created', {'options': options});
}
