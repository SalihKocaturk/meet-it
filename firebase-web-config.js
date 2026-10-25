// MeetIt web sayfaları (davet/, konum/, oylama/) için Firebase ayarı.
//
// DOLDURMA: Firebase Console → Proje ayarları → Genel → "Uygulamalarınız"
// → meetit (web) → SDK kurulumu → "Yapılandırma". apiKey ve appId'yi
// buraya yapıştır. Bu değerler gizli değildir (her web sitesinde açıkça
// bulunur); güvenliği Firestore kuralları sağlar.
//
// Ayrıca Firebase Console → Authentication → Oturum açma yöntemi →
// "Anonim" sağlayıcısı AÇIK olmalı (web sayfaları hesapsız kullanıcıyı
// anonim oturumla yazdırır).
window.MEETIT_FIREBASE_CONFIG = {
  apiKey: "WEB_API_KEY_BURAYA",
  authDomain: "meetit-497814.firebaseapp.com",
  projectId: "meetit-497814",
  storageBucket: "meetit-497814.firebasestorage.app",
  messagingSenderId: "989610671267",
  appId: "WEB_APP_ID_BURAYA",
};

// Firestore'da App Check zorunlu (enforce) ise web için reCAPTCHA v3 site
// anahtarını buraya yaz ve Firebase Console → App Check'e web uygulamasını
// ekle. Zorunlu değilse boş bırak.
window.MEETIT_RECAPTCHA_SITE_KEY = "";
