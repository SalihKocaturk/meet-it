# 🤝 MeetIt

**MeetIt**, iki kullanıcının kişilik analizine göre birbirlerine uygun buluşma mekanları önerisinde bulunan sosyal bir Flutter uygulamasıdır. Arkadaşlarınla buluşmak için en uygun yeri bulmak artık çok kolay!

---

## ✨ Özellikler

- **Kişilik Analizi** — Trivia bazlı kısa bir testle 5 boyutlu kişilik profili (OCEAN modeli)
- **Akıllı Mekan Önerileri** — Her iki kullanıcının kişiliğine ve seçilen aktivite türlerine göre Google Places API üzerinden öneri
- **Orta Nokta Hesaplama** — İki kullanıcının GPS konumu ortalaması alınarak en yakın buluşma noktası önce listelenir
- **Arkadaşlık Sistemi** — 6 haneli kod ile arkadaş ekleme, istek gönderme/iptal etme
- **Feed** — Mekan değerlendirmeleri (1–5 yıldız + yorum) feed'e otomatik düşer
- **Profil Sayfası** — Instagram tarzı profil; gönderiler, arkadaşlar ve bekleyen istekler
- **Realtime Veri** — Firestore `snapshots()` ile anlık güncellenen feed, arkadaşlar ve profil
- **Harita ile Konum Seçme** — Google Maps üzerinden parmakla sürükleyerek konum belirleme
- **Firebase Auth** — Email/şifre ve Google ile giriş, SharedPreferences ile oturum kalıcılığı

---

## 🛠 Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| UI | Flutter 3 |
| State Management | Riverpod (NotifierProvider, StreamProvider) |
| Backend | Firebase (Auth, Firestore, Storage) |
| Haritalar | Google Maps Flutter + Places API + Geocoding API |
| Navigasyon | GoRouter |
| Kişilik Modeli | OCEAN (5 boyut) + Kosinüs Benzerliği |

---

## 📁 Proje Yapısı

```
lib/
├── core/
│   ├── constants/        # Renkler, temalar
│   ├── router/           # GoRouter tanımları
│   └── widgets/          # Ortak UI bileşenleri
├── features/
│   ├── auth/             # Giriş, kayıt, session
│   ├── feed/             # Gönderi akışı, mekan değerlendirme
│   ├── friends/          # Arkadaşlık sistemi, kod ile ekleme
│   ├── match/            # Buluşma önerileri, mekan arama
│   ├── personality/      # Kişilik testi ve modeli
│   ├── profile/          # Profil sayfası
│   └── settings/         # Ayarlar, profil düzenleme, şifre
└── main.dart
```

---

## 🚀 Kurulum

### Gereksinimler
- Flutter SDK `^3.10`
- Firebase projesi (Firestore, Auth, Storage etkin)
- Google Maps API anahtarı (Maps SDK + Places API + Geocoding API etkin)

### Adımlar

```bash
# 1. Depoyu klonla
git clone https://github.com/KULLANICI_ADI/meetit.git
cd meetit

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Firebase yapılandırmasını ekle
# android/app/google-services.json  → Firebase Console'dan indir
# ios/Runner/GoogleService-Info.plist → Firebase Console'dan indir
# lib/firebase_options.dart → flutterfire configure ile oluştur

# 4. Google Maps API anahtarını ayarla
# android/app/src/main/AndroidManifest.xml içindeki
# com.google.android.maps.v2.API_KEY değerini güncelle

# 5. Uygulamayı çalıştır
flutter run
```

### Gizli Dosyalar (Git'e dahil edilmez)
Bu dosyaları kendin oluşturman gerekir:
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
android/key.properties
```

---

## 🔑 Firebase Güvenlik Kuralları (Firestore)

Temel okuma/yazma kuralı — production öncesi sıkılaştırılmalıdır:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📸 Ekran Görüntüleri

> Ekran görüntüleri eklenecek

---

## 📄 Lisans

Bu proje kişisel/öğrenci projesi olarak geliştirilmektedir. Lisans belirlenmemiştir.
