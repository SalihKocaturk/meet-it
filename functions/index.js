/**
 * MeetIt — Cloud Functions
 *
 * Bu dosya, Firestore'daki bildirim dökümanlarını izleyip FCM push gönderir.
 *
 * DEPLOY:
 *   cd functions && npm install
 *   cd .. && firebase deploy --only functions
 *
 * İlk kurulum (sadece bir kez):
 *   npm install -g firebase-tools
 *   firebase login
 *   firebase use meetit-497814
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Tetikleyici: `notifications/{uid}/items/{itemId}` koleksiyonuna
 * yeni bir döküman eklendiğinde çalışır.
 *
 * Flutter tarafında `NotificationService.sendNotification()` bu dökümanı
 * oluşturur; bu Cloud Function da hedef kullanıcının FCM token'ını
 * Firestore'dan okuyup gerçek push bildirimini gönderir.
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{uid}/items/{itemId}",
  async (event) => {
    const uid = event.params.uid;       // bildirim alacak kullanıcının uid'i
    const data = event.data?.data();    // NotificationService.sendNotification'dan gelen veri

    if (!data) {
      console.log("Bildirim verisi boş, atlanıyor.");
      return;
    }

    // Hedef kullanıcının FCM token'ını al
    const userSnap = await db.collection("users").doc(uid).get();
    const fcmToken = userSnap.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`[sendPushNotification] ${uid} için FCM token bulunamadı.`);
      return;
    }

    // Bildirim türüne göre başlık ve içerik belirle
    let title = "MeetIt";
    let body = "";

    switch (data.type) {
      case "friend_request":
        title = "Arkadaşlık İsteği 👋";
        body = `${data.fromName} sana arkadaşlık isteği gönderdi.`;
        break;
      case "friend_accepted":
        title = "İstek Kabul Edildi 🎉";
        body = `${data.fromName} arkadaşlık isteğini kabul etti!`;
        break;
      case "meetup_invite":
        title = "Buluşma Daveti 📍";
        body = `${data.fromName} seninle buluşmak istiyor!`;
        break;
      default:
        body = "Yeni bir bildirim aldın.";
    }

    // FCM mesajını gönder
    try {
      await messaging.send({
        token: fcmToken,
        notification: {
          title,
          body,
        },
        // Flutter tarafında RemoteMessage.data olarak gelir
        data: {
          type: data.type ?? "",
          fromUid: data.fromUid ?? "",
          fromName: data.fromName ?? "",
        },
        // iOS özel ayarlar
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        // Android özel ayarlar
        android: {
          notification: {
            sound: "default",
            priority: "high",
          },
        },
      });

      console.log(`[sendPushNotification] ✅ ${uid} kullanıcısına gönderildi: ${data.type}`);
    } catch (error) {
      console.error(`[sendPushNotification] ❌ ${uid} kullanıcısına gönderilemedi:`, error);

      // Token geçersizse Firestore'dan temizle (eski/silinen cihaz)
      if (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
      ) {
        await db.collection("users").doc(uid).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log(`[sendPushNotification] Geçersiz token temizlendi: ${uid}`);
      }
    }
  }
);
