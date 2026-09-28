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

    // Hedef kullanıcının FCM token'ını al (fcmTokens koleksiyonu — private)
    const tokenSnap = await db.collection("fcmTokens").doc(uid).get();
    const fcmToken = tokenSnap.data()?.token;

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
      case "venue_found":
        title = "Mekan Bulundu 🗺️";
        body = `${data.fromName} seninle buluşmak için mekan buldu!`;
        break;
      case "review_liked":
        title = "Yorumun Beğenildi ❤️";
        body = `${data.fromName}, "${data.extra?.venueName ?? "bir mekan"}" yorumunu beğendi.`;
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
        await db.collection("fcmTokens").doc(uid).delete();
        console.log(`[sendPushNotification] Geçersiz token temizlendi: ${uid}`);
      }
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────
// Hesap silindiğinde kullanıcıya ait verileri temizle.
//
// Tetikleyici: Firebase Auth kullanıcısı silindiğinde (uygulamadaki
// Ayarlar > Hesabı Sil → fbUser.delete()). App Store 5.1.1(v) ve KVKK:
// hesap silme, ilişkili verileri de silmeli. İstemci yalnızca users/{uid}
// dokümanını siliyordu; alt koleksiyonlar, arkadaşlıklar, yorumlar,
// fotoğraflar vb. kalıyordu.
//
// ÖNEMLİ: Gizlilik Politikası'ndaki "Saklama Süresi ve Hesap Silme" bölümü
// bu fonksiyonun yaptıklarını anlatır — biri değişirse diğeri de güncellensin.
//
// Şikâyet kayıtları (reports) BİLEREK silinmez: moderasyon ve olası hukuki
// talepler için saklanır (politikada en fazla 2 yıl).
// ─────────────────────────────────────────────────────────────────────────
const functionsV1 = require("firebase-functions/v1");
const { logger } = require("firebase-functions");

/** Sorgunun döndürdüğü tüm dokümanları 450'lik batch'lerle siler. */
async function deleteQuery(query) {
  const snap = await query.get();
  let batch = db.batch();
  let pending = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    if (++pending === 450) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending) await batch.commit();
  return snap.size;
}

exports.cleanupDeletedUser = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const FieldValue = admin.firestore.FieldValue;
  const bucket = admin.storage().bucket();
  const stats = { uid };

  const step = async (name, fn) => {
    try {
      stats[name] = await fn();
    } catch (e) {
      // Bir adım patlasa bile diğerleri çalışmaya devam etsin.
      stats[name] = `HATA: ${e.message}`;
      logger.error(`[cleanupDeletedUser] ${name}`, e);
    }
  };

  // Profil + alt koleksiyonlar (saved_venues, navigated_venues)
  await step("user", () => db.recursiveDelete(db.collection("users").doc(uid)));
  // Bildirim kuyruğu + FCM token
  await step("notifications", () =>
    db.recursiveDelete(db.collection("notifications").doc(uid)));
  await step("fcmToken", () => db.collection("fcmTokens").doc(uid).delete());
  // Arkadaşlıklar (iki yön)
  await step("friendships", async () =>
    (await deleteQuery(db.collection("friendships").where("fromUid", "==", uid))) +
    (await deleteQuery(db.collection("friendships").where("toUid", "==", uid))));
  // Kullanıcının yorumları
  await step("reviews", () =>
    deleteQuery(db.collection("venue_reviews").where("authorUid", "==", uid)));
  // Başkalarının yorumlarındaki beğenileri
  await step("likes", async () => {
    const snap = await db.collection("venue_reviews")
        .where("likedBy", "array-contains", uid).get();
    await Promise.all(snap.docs.map((d) =>
      d.ref.update({ likedBy: FieldValue.arrayRemove(uid) })));
    return snap.size;
  });
  // Buluşma geçmişi (kullanıcının katıldığı kayıtlar)
  await step("meetingHistory", () =>
    deleteQuery(db.collection("meetingHistory")
        .where("participantUids", "array-contains", uid)));
  // Engellemeler (iki yön)
  await step("blocks", async () =>
    (await deleteQuery(db.collection("blocks").where("blockerUid", "==", uid))) +
    (await deleteQuery(db.collection("blocks").where("blockedUid", "==", uid))));
  // Storage: profil fotoğrafı + yorum fotoğrafları
  await step("profilePhoto", () =>
    bucket.file(`profile_photos/${uid}.jpg`).delete({ ignoreNotFound: true }));
  await step("reviewPhotos", () =>
    bucket.deleteFiles({ prefix: `review_photos/${uid}/` }));

  logger.info("[cleanupDeletedUser] tamamlandı", stats);
});
