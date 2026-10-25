# Paylaşım özellikleri — kurulum adımları

Misafir modu, grup oylaması ve davet kartı için bir kez
yapılması gerekenler. Kod hazır; bunlar Firebase / mağaza tarafı ayarları.

## 1. Paketler
```
flutter pub get
```
(`share_plus` ve `firebase_analytics` eklendi.)

## 2. Firebase Console
1. **Authentication → Oturum açma yöntemi → Anonim → Etkinleştir.**
   Hem uygulamadaki "Hesap açmadan dene" hem de web sayfaları (davet/,
   oylama/) bunu kullanır.
2. **Firestore kuralları ve fonksiyonlar:**
   ```
   firebase deploy --only firestore:rules,functions
   ```
   Yeni kurallar: `polls` koleksiyonu; anonim
   kullanıcılar (misafir + web ziyaretçisi) kullanıcı listesini ve
   arkadaşlıkları OKUYAMAZ.
3. **Web yapılandırması:** Proje ayarları → Genel → Uygulamalarınız →
   *meetit (web)* → Yapılandırma. `apiKey` ve `appId` değerlerini
   `firebase-web-config.js` dosyasına yapıştır.
4. **App Check:** Firestore için App Check "zorunlu" (enforce) ise web
   sayfaları çalışmaz. Ya App Check → web uygulamasına reCAPTCHA v3
   ekleyip site anahtarını `firebase-web-config.js` →
   `MEETIT_RECAPTCHA_SITE_KEY` alanına yaz, ya da Firestore için
   zorunluluğu kapalı tut.

## 3. Web sayfaları (GitHub Pages, bu repo)
- `davet/`  — kişilik kartı davet linki
- `oylama/` — grup mekan oylaması

Push sonrası birkaç dakikada yayına girer:
`https://salihkocaturk.github.io/meet-it/oylama/` vb.

## 4. Uygulama linkleri (isteğe bağlı ama önerilir)
`link-verification/README.md` — `salihkocaturk.github.io` reposu ve
SHA-256 değerleri. Olmadan da her şey çalışır; sadece davet linki önce
web sayfasını açar.

## 5. Analytics hunisi
Firebase Console → Analytics → Funnels'ta şu olaylarla huni kur:
`first_open → guest_start / sign_up → quiz_complete → venue_search →
venues_shown`. Paylaşım olayları: `share_personality_card`,
`share_duo_card`, `poll_created`, `invite_accepted`. Test önerisi
pop-up'ı: `quiz_nudge` (action: shown / accepted / dismissed).

## 6. Oylamaların otomatik silinmesi (TTL)
Her oylama `expireAt` alanıyla oluşturulur (7 gün sonrası). Firestore'un
bunları kendiliğinden silmesi için bir kez:
Firebase Console → Firestore → **TTL** (Zaman aşımı politikaları) →
*Politika oluştur* → Koleksiyon grubu: `polls`, Zaman damgası alanı:
`expireAt`. Silme genelde süre dolduktan sonraki 24 saat içinde olur.
Gizlilik politikası bu 7 günlük süreyi taahhüt ediyor — politikayı
mutlaka aç.

## 7. Mağaza gizlilik beyanları
Gizlilik politikası misafir hesap, Analytics ve oylamaları kapsayacak
şekilde güncellendi. Mağaza formlarını da buna göre güncelle:
- **App Store Connect → App Privacy:** "Usage Data → Product
  Interaction" (Analytics, App Functionality + Analytics amaçlı, kimliğe
  bağlı) ve "Identifiers → User ID" (Firebase kullanıcı kimliği) ekle.
  Takip (tracking) için kullanılmıyor.
- **Play Console → Data safety:** "App activity → App interactions"
  (Analytics) ve "Device or other IDs" ekle; amaç: Analytics, App
  functionality. Veriler aktarımda şifreli; kullanıcı silme talep
  edebilir.
