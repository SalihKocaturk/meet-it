import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// FCM push bildirimlerini arka planda yakalar.
/// `@pragma('vm:entry-point')` olmadan release build'lerde tree-shake edilir.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase zaten main() içinde init edildi — burada tekrar init etmeye gerek yok.
  debugPrint('[FCM] Arka plan mesajı: ${message.notification?.title}');
  // iOS'ta arka plan push'larını sistem otomatik gösterir (APNs).
  // Android için burada flutter_local_notifications kullanmak gerekir,
  // ama flutter_local_notifications'ı isolate'siz arka plan handler'ından
  // başlatmak önerilmiyor — bunun yerine FCM payloadında notification objesi
  // gönderiyoruz ki sistem kendisi göstersin.
}

/// MeetIt bildirim sistemi.
///
/// Kullanım:
///   1) main() içinde `await NotificationService.initialize()` çağır
///   2) Kullanıcı giriş yaptıktan sonra `await NotificationService.saveFcmToken(uid)` çağır
///   3) Arkadaşlık isteği / meetup daveti anında `NotificationService.sendNotification(...)` çağır
///
/// Mimari:
///   - FCM token → Firestore `users/{uid}.fcmToken` alanına kaydedilir
///   - Bildirim verisi → `notifications/{targetUid}/items/{autoId}` dökümanına yazılır
///   - Cloud Function bu dökümanı izleyip FCM push gönderir (functions/index.js)
///   - Uygulama ön plandayken `flutter_local_notifications` ile yerel bildirim gösterilir
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static final _firestore = FirebaseFirestore.instance;

  static const _androidChannelId = 'meetit_default';
  static const _androidChannelName = 'MeetIt Bildirimleri';
  static const _androidChannelDesc = 'Arkadaşlık istekleri ve buluşma davetiyeleri';

  static const _androidChannel = AndroidNotificationChannel(
    _androidChannelId,
    _androidChannelName,
    description: _androidChannelDesc,
    importance: Importance.high,
    playSound: true,
  );

  // ── Initialize ──────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    // Arka plan mesaj handler'ını kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // iOS bildirim izni iste
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[NotificationService] Bildirim izni reddedildi.');
      return;
    }

    // flutter_local_notifications başlat (ön plan bildirimleri için)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // iOS'ta izni firebase_messaging zaten istedi — burada tekrar isteme.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Android bildirim kanalı oluştur
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Uygulama ön plandayken gelen FCM mesajları → yerel bildirim olarak göster
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Kullanıcı arka planda gelen bildirime tıklarsa
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedFromBackground);

    // Uygulama tamamen kapalıyken gelen bildirime tıklanıp uygulama açıldıysa
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationOpenedFromBackground(initialMessage);
    }

    debugPrint('[NotificationService] Başlatıldı — izin durumu: ${settings.authorizationStatus}');
  }

  // ── Token Yönetimi ──────────────────────────────────────────────────────────

  /// Kullanıcı giriş yaptıktan sonra FCM token'ını Firestore'a kaydet.
  /// Token yenilendiğinde otomatik güncelleme de başlatır.
  static Future<void> saveFcmToken(String uid) async {
    try {
      // iOS'ta APNs token'ı beklenmesi gerekiyor — bu beklemeyi messaging paketi
      // kendi içinde yapıyor, burada sadece getToken()'ı çağırıyoruz.
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[NotificationService] FCM token alınamadı (henüz hazır değil).');
        return;
      }

      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
      debugPrint('[NotificationService] FCM token Firestore\'a kaydedildi.');

      // Token yenilendiğinde (nadiren: uygulama yeniden kurulunca vb.) güncelle
      _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _firestore.collection('users').doc(uid).update({
            'fcmToken': newToken,
          });
          debugPrint('[NotificationService] FCM token yenilendi ve kaydedildi.');
        } catch (e) {
          debugPrint('[NotificationService] Token yenileme kaydetme hatası: $e');
        }
      });
    } catch (e) {
      debugPrint('[NotificationService] saveFcmToken hatası: $e');
    }
  }

  /// Çıkış yaparken FCM token'ı Firestore'dan temizle
  /// (bu cihaza artık bildirim gönderilmesin).
  static Future<void> clearFcmToken(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[NotificationService] clearFcmToken hatası: $e');
    }
  }

  // ── Bildirim Gönderme ───────────────────────────────────────────────────────

  /// Hedef kullanıcıya Firestore üzerinden bildirim gönder.
  ///
  /// Firestore'daki `notifications/{toUid}/items` koleksiyonuna yeni bir
  /// döküman yazar. Cloud Function (functions/index.js) bu dökümanı izleyip
  /// gerçek FCM push'u gönderir. Bu sayede client tarafından hiçbir zaman
  /// FCM API'sine doğrudan istek atılmıyor (güvenli mimari).
  ///
  /// [type] değerleri:
  ///   - `'friend_request'`  — arkadaşlık isteği
  ///   - `'friend_accepted'` — istek kabul edildi
  ///   - `'meetup_invite'`   — buluşma daveti
  static Future<void> sendNotification({
    required String toUid,
    required String type,
    required String fromName,
    String? fromUid,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(toUid)
          .collection('items')
          .add({
        'type': type,
        'fromName': fromName,
        'fromUid': fromUid ?? '',
        'extra': extra ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] Bildirim yazıldı: $type → $toUid');
    } catch (e) {
      // Bildirim gönderilemese de ana akışı engelleme — sessizce yut.
      debugPrint('[NotificationService] sendNotification hatası: $e');
    }
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  /// Uygulama ön plandayken FCM mesajı geldi → yerel bildirim göster.
  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      // Benzersiz id: hashCode yeterince benzersiz (taşma ihtimali düşük)
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'],
    );
  }

  /// Yerel bildirime tıklandı (ön plan bildirimi).
  static void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Yerel bildirime tıklandı: ${response.payload}');
    // TODO: İleride GoRouter ile ilgili sayfaya yönlendirme eklenebilir.
    // Şu anlık uygulama açık zaten — kullanıcı kendisi navigate edebilir.
  }

  /// Arka plandan / kapalı durumdan bildirime tıklanıp uygulama açıldı.
  static void _onNotificationOpenedFromBackground(RemoteMessage message) {
    final type = message.data['type'];
    debugPrint('[NotificationService] Bildirimle uygulama açıldı: $type');
    // TODO: GoRouter'a bağla — friendsPage / homePage yönlendirmesi
  }
}
