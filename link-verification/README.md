# Davet linki doğrulama dosyaları

Bu klasördeki dosyalar **`salihkocaturk.github.io`** adlı ayrı bir GitHub
reposunun KÖKÜNE konur. Android App Links ve iOS Universal Links, davet
linkinin (`https://salihkocaturk.github.io/meet-it/davet/?u=...`) uygulamayı
doğrudan açması için alan adının kökünde bu dosyaları arar; `meet-it`
reposunun sayfası (`/meet-it/`) kök sayılmadığı için ayrı repo gerekiyor.

## Kurulum (bir kez)

1. GitHub'da **`salihkocaturk.github.io`** adında public bir repo oluştur.
2. Bu klasördeki üç öğeyi o reponun köküne kopyala:
   - `.nojekyll` (boş dosya — GitHub Pages'in `.well-known` klasörünü
     gizlememesi için şart)
   - `.well-known/apple-app-site-association`
   - `.well-known/assetlinks.json`
3. Repo → Settings → Pages → Branch: `main` / root → Save.
4. `assetlinks.json` içindeki iki yer tutucuyu doldur:
   Play Console → MeetIt → Test ve yayın → Uygulama bütünlüğü →
   **Uygulama imzalama** sekmesinde:
   - "Uygulama imzalama anahtarı sertifikası" → SHA-256 → `PLAY_APP_SIGNING_SHA256_BURAYA`
   - "Yükleme anahtarı sertifikası" → SHA-256 → `UPLOAD_KEY_SHA256_BURAYA`
   (İki nokta üst üste ile, büyük harf: `AB:CD:...` biçiminde.)

## Kontrol

- https://salihkocaturk.github.io/.well-known/assetlinks.json
- https://salihkocaturk.github.io/.well-known/apple-app-site-association
- Android: https://developers.google.com/digital-asset-links/tools/generator
- iOS: Apple, dosyayı uygulama yüklenince/güncellenince kendi CDN'inden
  çeker; değişiklik birkaç saat sürebilir.

## iOS ek adım

`ios/Runner/Runner.entitlements` içine `applinks:salihkocaturk.github.io`
eklendi. Apple Developer → Identifiers → `com.kocaturksalih.meetit` →
**Associated Domains** yeteneği açık olmalı (Xcode otomatik imzalama bunu
kendisi açar; manuel profil kullanılıyorsa profil yeniden oluşturulmalı).

Doğrulama dosyaları yayında olmasa da akış çalışır: link davet sayfasını
açar, mağaza butonuna basınca davet kodu panoya kopyalanır ve uygulama ilk
açılışta onu okur.
