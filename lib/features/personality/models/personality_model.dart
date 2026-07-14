// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Uygulamadaki kişilik tipleri
enum PersonalityType {
  sosyalKelebek,
  sakinRuh,
  maceraperest,
  entelektuel,
  gurme,
}

extension PersonalityTypeX on PersonalityType {
  String get displayName {
    switch (this) {
      case PersonalityType.sosyalKelebek: return 'personality.social_butterfly'.tr();
      case PersonalityType.sakinRuh:      return 'personality.calm_soul'.tr();
      case PersonalityType.maceraperest:  return 'personality.adventurer'.tr();
      case PersonalityType.entelektuel:   return 'personality.intellectual'.tr();
      case PersonalityType.gurme:         return 'personality.foodie'.tr();
    }
  }

  String get emoji {
    switch (this) {
      case PersonalityType.sosyalKelebek:
        return '🦋';
      case PersonalityType.sakinRuh:
        return '☕';
      case PersonalityType.maceraperest:
        return '🏔️';
      case PersonalityType.entelektuel:
        return '📚';
      case PersonalityType.gurme:
        return '🍽️';
    }
  }

  String get description {
    switch (this) {
      case PersonalityType.sosyalKelebek: return 'personality.social_butterfly_desc'.tr();
      case PersonalityType.sakinRuh:      return 'personality.calm_soul_desc'.tr();
      case PersonalityType.maceraperest:  return 'personality.adventurer_desc'.tr();
      case PersonalityType.entelektuel:   return 'personality.intellectual_desc'.tr();
      case PersonalityType.gurme:         return 'personality.foodie_desc'.tr();
    }
  }

  String get colorHex {
    switch (this) {
      case PersonalityType.sosyalKelebek:
        return '#FF6B6B';
      case PersonalityType.sakinRuh:
        return '#4ECDC4';
      case PersonalityType.maceraperest:
        return '#45B7D1';
      case PersonalityType.entelektuel:
        return '#96CEB4';
      case PersonalityType.gurme:
        return '#FFEAA7';
    }
  }
  /// Uygulamanın Iconsax icon setinden bu kişilik tipini temsil eden ikon.
  /// Emoji yerine tüm UI'larda bu kullanılmalı.
  IconData get iconsaxIcon {
    switch (this) {
      case PersonalityType.sosyalKelebek: return Iconsax.people;    // sosyal bağlantı
      case PersonalityType.sakinRuh:      return Iconsax.coffee;      // kahve/dinginlik
      case PersonalityType.maceraperest:  return Icons.terrain;       // dağ silüeti/macera
      case PersonalityType.entelektuel:   return Iconsax.book_1;     // bilgi/okuma
      case PersonalityType.gurme:         return Iconsax.cake;        // yemek/lezzet
    }
  }

  // Not: Dart 3 enum'larında .name built-in olarak mevcuttur — override gerekmez.
}

// ── Google Places Tipi → Kişilik Ağırlığı Eşlemesi ──────────────────────────
//
// [PersonalityProfile.evolvedWith] tarafından kullanılır. Bir mekanın Google
// Places `types` alanındaki kategoriler burada eşleşirse, o kategorinin
// "taşıdığı" kişilik sinyali (0.0–1.0 ağırlıkla, birden fazla tipe
// dağıtılabilir) profile küçük bir oranda karıştırılır.
//
// ÖNEMLİ — TUTARLILIK NOTU: Bu tablo, mekan ARAMA/EŞLEŞTİRME tarafında
// kullanılan `PlacesService._personalityScores` (places_service.dart) ile
// BİREBİR aynı oranları yansıtacak şekilde hizalanmıştır. Önceden bu iki
// tablo birbirinden bağımsız elle yazılmıştı ve sayılar uyuşmuyordu — örneğin
// burada 'gym' kullanıcıyı hem maceraperest HEM sakin ruh yönünde besliyordu,
// ama arama tarafında gym SADECE maceraperest'e puan veriyordu (ayrıca
// "sakin ruh kullanıcılara gym önerilmesin" diye bilerek arama dışı
// bırakılmıştı — bkz. PlacesService._personalityTypes ve geçmiş düzeltme).
// Sonuç: bir kullanıcıya kişiliğine göre ÖNERİLEN bir mekan, ziyaret
// ettiğinde profilini FARKLI bir yöne kaydırabiliyordu. İki taraf da artık
// aynı kaynaktan (places_service.dart'taki ağırlıklar) türetildiği için
// "önerilen mekana göre eşleşme" ile "o mekana gidince kişiliğin nasıl
// değişir" mantığı tutarlı. (places_service.dart `personality_model.dart`'ı
// import ettiğinden, döngüsel bağımlılık olmasın diye tabloyu burada literal
// olarak tekrar tanımlıyoruz — iki taraf güncellenirken birlikte
// güncellenmeli.)
//
// Sadece `_personalityScores`'ta karşılığı OLMAYAN tipler (shopping_mall,
// stadium, zoo, aquarium, book_store, meal_takeaway, meal_delivery, spa —
// bunlar arama tarafında sadece aktivite seçildiğinde devreye giriyor, baskın
// kişilik tipine göre hiç aranmıyor) eski yaklaşık ağırlıklarında bırakıldı.
const Map<String, Map<PersonalityType, double>> kVenueTypePersonalityWeights =
    {
  // ── Sosyal Kelebek ── (places_service._personalityScores ile hizalı)
  'night_club': {
    PersonalityType.sosyalKelebek: 1.0,
    PersonalityType.maceraperest: 0.5,
    PersonalityType.gurme: 0.3,
  },
  'bar': {
    PersonalityType.sosyalKelebek: 1.0,
    PersonalityType.maceraperest: 0.4,
    PersonalityType.gurme: 0.5,
  },
  'bowling_alley': {PersonalityType.maceraperest: 1.0},
  'shopping_mall': {
    PersonalityType.sosyalKelebek: 0.6,
    PersonalityType.gurme: 0.4,
  },
  'movie_theater': {PersonalityType.entelektuel: 0.8},

  // ── Sakin Ruh ──
  'spa': {PersonalityType.sakinRuh: 1.0},
  'park': {
    PersonalityType.sakinRuh: 1.0,
    PersonalityType.maceraperest: 0.9,
    PersonalityType.entelektuel: 0.5,
  },
  'cafe': {
    PersonalityType.sakinRuh: 1.0,
    PersonalityType.gurme: 0.8,
    PersonalityType.entelektuel: 0.6,
    PersonalityType.sosyalKelebek: 0.4,
  },

  // ── Maceraperest ──
  'amusement_park': {
    PersonalityType.maceraperest: 1.0,
    PersonalityType.sosyalKelebek: 0.5,
  },
  // NOT: 'gym' artık SADECE maceraperest besliyor — "sakin ruh kullanıcıya
  // gym önerilmesin" kararıyla tutarlı (eskiden sakin ruh'a da 0.2 puan
  // veriyordu, bu çelişkiliydi).
  'gym': {PersonalityType.maceraperest: 1.0},
  'stadium': {
    PersonalityType.maceraperest: 0.6,
    PersonalityType.sosyalKelebek: 0.4,
  },
  'zoo': {PersonalityType.maceraperest: 0.6, PersonalityType.sakinRuh: 0.4},
  'aquarium': {
    PersonalityType.maceraperest: 0.5,
    PersonalityType.entelektuel: 0.5,
  },

  // ── Entelektüel ──
  'museum': {PersonalityType.entelektuel: 1.0, PersonalityType.sakinRuh: 0.6},
  'art_gallery': {PersonalityType.entelektuel: 1.0},
  'library': {PersonalityType.entelektuel: 0.9, PersonalityType.sakinRuh: 0.9},
  'book_store': {PersonalityType.entelektuel: 0.7, PersonalityType.sakinRuh: 0.3},

  // ── Gurme ──
  'restaurant': {
    PersonalityType.gurme: 1.0,
    PersonalityType.sosyalKelebek: 0.8,
    PersonalityType.sakinRuh: 0.4,
  },
  'bakery': {PersonalityType.gurme: 0.9, PersonalityType.sakinRuh: 0.7},
  'meal_takeaway': {PersonalityType.gurme: 0.6},
  'meal_delivery': {PersonalityType.gurme: 0.5},
};

// ── Kişilik Profili (Skor Tabanlı) ───────────────────────────────────────────

/// Quiz sonuçlarını tek bir "kazanan tip" olarak değil,
/// her tipin normalize edilmiş skoru (0.0–1.0) olarak tutar.
/// Bu sayede iki kullanıcı arasındaki uyumluluk, vektör benzerliğiyle hesaplanır.
class PersonalityProfile {
  /// Her kişilik tipinin normalize edilmiş skoru (0.0 – 1.0)
  final Map<PersonalityType, double> scores;

  /// Profilin en son güncellendiği tarih
  final DateTime lastUpdated;

  const PersonalityProfile({
    required this.scores,
    required this.lastUpdated,
  });

  // ── Türetilmiş Getterlar ─────────────────────────────────────────────────

  /// En yüksek skorlu (baskın) kişilik tipi
  PersonalityType get dominantType {
    if (scores.isEmpty) return PersonalityType.sosyalKelebek;
    return scores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Skora göre azalan sıralı tip listesi
  List<MapEntry<PersonalityType, double>> get rankedTypes {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// İkincil (2. en yüksek, en az %10 skor alan) kişilik tipi
  PersonalityType? get secondaryType {
    final ranked = rankedTypes;
    if (ranked.length < 2) return null;
    return ranked[1].value >= 0.10 ? ranked[1].key : null;
  }

  // ── Uyumluluk Hesabı ─────────────────────────────────────────────────────

  /// İki profil arasındaki uyumluluğu kosinüs benzerliğiyle hesapla (50–98 arası)
  ///
  /// Aynı profiller → 98, tamamen zıt profiller → ~50
  int compatibilityWith(PersonalityProfile other) {
    double dot = 0, mag1 = 0, mag2 = 0;
    for (final type in PersonalityType.values) {
      final s1 = scores[type] ?? 0.0;
      final s2 = other.scores[type] ?? 0.0;
      dot += s1 * s2;
      mag1 += s1 * s1;
      mag2 += s2 * s2;
    }
    if (mag1 == 0 || mag2 == 0) return 70;
    final cosine = dot / (sqrt(mag1) * sqrt(mag2));
    // cosine ∈ [0,1] → compat ∈ [50,98]
    return (50 + cosine * 48).round().clamp(50, 98);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'scores': scores.map((k, v) => MapEntry(k.name, v)),
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory PersonalityProfile.fromMap(Map<String, dynamic> map) {
    final rawScores = map['scores'] as Map<String, dynamic>? ?? {};
    final parsedScores = <PersonalityType, double>{};
    for (final entry in rawScores.entries) {
      final type = PersonalityType.values.firstWhere(
        (t) => t.name == entry.key,
        orElse: () => PersonalityType.sosyalKelebek,
      );
      parsedScores[type] = (entry.value as num).toDouble();
    }
    return PersonalityProfile(
      scores: parsedScores,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int)
          : DateTime.now(),
    );
  }

  PersonalityProfile copyWith({
    Map<PersonalityType, double>? scores,
    DateTime? lastUpdated,
  }) {
    return PersonalityProfile(
      scores: scores ?? Map.unmodifiable(this.scores),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // ── Dinamik Evrim (Ziyaret Edilen Mekanlara Göre) ───────────────────────
  //
  // Quiz sonucu artık tek seferlik/statik bir profil değil — kullanıcı bir
  // mekana yorum bıraktığında (yani orayı ziyaret ettiğinde), o mekanın
  // Google Places kategorileri ([PlaceResult.types]) küçük bir ağırlıkla
  // mevcut profile karıştırılır. Böylece profil zamanla kullanıcının
  // gerçek alışkanlıklarını yansıtacak şekilde "kayar" — ama tek bir ziyaret
  // profili aniden değiştirmez (öğrenme oranı düşük tutulduğu için).

  /// Bu profili, ziyaret edilen bir mekanın Google Places [placeTypes]
  /// listesine göre hafifçe günceller ve yeni bir [PersonalityProfile] döner.
  ///
  /// [learningRate]: Yeni sinyalin profile karışma oranı (0.0–1.0). Varsayılan
  /// %6 — yani 1 ziyaret profili büyük oranda değiştirmez, ama düzinelerce
  /// ziyaret üzerinden profil belirgin şekilde evrilir.
  ///
  /// [rating]: Kullanıcının o mekana verdiği yıldız puanı (1–5). Verilirse
  /// [learningRate] bu puana göre ölçeklenir — mekanı seçip gitmiş olması
  /// zaten bir ilgi sinyali olduğu için etki asla negatife çevrilmez, sadece
  /// zayıflatılır: 5 yıldızda tam etki, 3 yıldızda yarı etki, 1 yıldızda
  /// ~sıfır etki. Düşük puan "bu kişilik tipine uymuyor" değil, "bu mekan
  /// kötüydü" anlamına gelebileceğinden ters yönde bir evrim uygulanmaz.
  /// `rating` verilmezse (null) ölçekleme yapılmadan eski davranış sürer.
  ///
  /// Eşleşen tip yoksa (örn. tanınmayan bir Places kategorisi) profil
  /// değişmeden (ama lastUpdated güncellenmeden) geri döner.
  PersonalityProfile evolvedWith(
    List<String> placeTypes, {
    double learningRate = 0.06,
    int? rating,
  }) {
    if (rating != null) {
      // 1 yıldız → 0.0, 3 yıldız → 0.5, 5 yıldız → 1.0 — asla negatif.
      final ratingMultiplier = ((rating - 1) / 4).clamp(0.0, 1.0);
      learningRate *= ratingMultiplier;
      if (learningRate <= 0) return this; // Çok düşük puan: profile dokunma
    }

    // 1) Bu mekanın tiplerinden toplam bir "sinyal" vektörü oluştur.
    final rawSignal = <PersonalityType, double>{};
    for (final placeType in placeTypes) {
      final weights = kVenueTypePersonalityWeights[placeType];
      if (weights == null) continue;
      for (final entry in weights.entries) {
        rawSignal[entry.key] = (rawSignal[entry.key] ?? 0) + entry.value;
      }
    }
    if (rawSignal.isEmpty) return this; // Tanınan bir kategori yoksa dokunma

    // 2) Sinyali normalize et (toplamı 1 olsun).
    final signalTotal = rawSignal.values.fold<double>(0, (a, b) => a + b);
    final signal = <PersonalityType, double>{
      for (final type in PersonalityType.values)
        type: signalTotal > 0 ? (rawSignal[type] ?? 0) / signalTotal : 0,
    };

    // 3) Mevcut skorları normalize ederek sinyalle harmanla.
    final currentTotal = scores.values.fold<double>(0, (a, b) => a + b);
    final blended = <PersonalityType, double>{};
    for (final type in PersonalityType.values) {
      final current =
          currentTotal > 0 ? (scores[type] ?? 0) / currentTotal : 0.2;
      blended[type] =
          current * (1 - learningRate) + signal[type]! * learningRate;
    }

    // 4) Sonucu yeniden normalize et (toplam tam 1 olsun).
    final blendedTotal = blended.values.fold<double>(0, (a, b) => a + b);
    final newScores = <PersonalityType, double>{
      for (final type in PersonalityType.values)
        type: blendedTotal > 0 ? blended[type]! / blendedTotal : 0.2,
    };

    return PersonalityProfile(scores: newScores, lastUpdated: DateTime.now());
  }

  // ── Mock Yardımcı Fabrika ─────────────────────────────────────────────────

  /// Test / mock verisi için: baskın tip %65, ikincil %20, geri kalanlar %5
  factory PersonalityProfile.mock(
    PersonalityType dominant, [
    PersonalityType? secondary,
  ]) {
    final scores = <PersonalityType, double>{};
    for (final t in PersonalityType.values) {
      if (t == dominant) {
        scores[t] = 0.65;
      } else if (t == secondary) {
        scores[t] = 0.20;
      } else {
        scores[t] = 0.05;
      }
    }
    return PersonalityProfile(scores: scores, lastUpdated: DateTime.now());
  }
}

// ── Quiz Modelleri ────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.question,
    required this.options,
  });
}

class QuizOption {
  final String text;
  final PersonalityType type;

  const QuizOption({
    required this.text,
    required this.type,
  });
}

// ── Quiz Soruları ─────────────────────────────────────────────────────────────
//
// DAĞILIM (10 soru × 4 seçenek = 40 slot, 5 tip → her tip tam 8 soruda):
//  Q1:  sosyal | sakin | macer | entel
//  Q2:  sosyal | sakin | macer | gurme
//  Q3:  sosyal | entel | macer | gurme
//  Q4:  sosyal | sakin | entel | gurme
//  Q5:  sakin  | entel | macer | gurme
//  Q6:  sosyal | sakin | macer | entel
//  Q7:  sosyal | entel | macer | gurme
//  Q8:  sosyal | sakin | entel | gurme
//  Q9:  sakin  | entel | macer | gurme
//  Q10: sosyal | sakin | macer | gurme
//
// Toplam: sosyal=8 sakin=8 macer=8 entel=8 gurme=8  ✓ (dengeli)

const List<QuizQuestion> kQuizQuestions = [
  // ── Soru 1 ── (sosyal | sakin | macer | entel)
  QuizQuestion(
    question: 'Telefonu bir kenara bıraktığın bir Pazar sabahı — ilk içgüdün ne?',
    options: [
      QuizOption(
        text: 'Arkadaşlarımı mesajlaşmaya çeker, öğleden sonra için plan yaparım',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Kahvemi alır, acelesiz bir şekilde sadece var olurum',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Yürüyüş botlarımı giyer, kendiliğinden bir rotaya çıkarım',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Birikmiş bir belgesele ya da merak ettiğim bir konuya dalarım',
        type: PersonalityType.entelektuel,
      ),
    ],
  ),

  // ── Soru 2 ── (sosyal | sakin | macer | gurme)
  QuizQuestion(
    question: 'Bir arkadaşın "bu hafta sonu buluşalım" diyor. İlk aklına gelen plan ne?',
    options: [
      QuizOption(
        text: 'Büyük bir grup toplayalım, ne kadar çok insan o kadar iyi',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'İkimiz sakin bir yerde oturalım, uzun uzun sohbet edelim',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Yürüyüş, bisiklet ya da outdoor bir şey yapalım',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Hiç denemediğim ama merak ettiğim bir yemeği birlikte keşfedelim',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 3 ── (sosyal | entel | macer | gurme)
  QuizQuestion(
    question: 'Hiç gitmediğin bir şehre ilk kez geliyorsun. Neyle başlarsın?',
    options: [
      QuizOption(
        text: 'Yerel meydanları, barları dolaşır, yolda insanlarla tanışmaya çalışırım',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Şehrin tarihini öğrenir, müze ve kültürel mekânları gezerim',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Haritayı bir kenara bırakır, sezgiyle rastgele keşfederim',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Yerel spesiyalleri araştırır, en iyi sokak yemeğini bulmadan duramam',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 4 ── (sosyal | sakin | entel | gurme)
  QuizQuestion(
    question: 'Yeni bir mahalleye taşındın. Bir ay sonra "benim yerim" dediğin mekan ne olur?',
    options: [
      QuizOption(
        text: 'Barmenin yüzümü tanıdığı, herkesin sohbet ettiği canlı bir mekan',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Kalabalıktan uzak, köşe masama çekilebileceğim huzurlu bir kafe',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Sergi, etkinlik ya da iyi sohbet kültürü olan entelektüel bir mekan',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Menüsü ilginç, kaliteli malzeme kullanan bir lokanta ya da kafe',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 5 ── (sakin | entel | macer | gurme)
  QuizQuestion(
    question: 'Planlanmamış boş bir akşam önünde. Kendini nasıl bulursun?',
    options: [
      QuizOption(
        text: 'Köşedeki küçük kafede oturup kitabıma ya da sessiz düşüncelerime dalarım',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Kafamı kurcalayan bir konuya girer, saatlerce araştırma yaparım',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Hiç gitmediğim bir yere ya da deneyime kendimi atarım, bakarız',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Mutfağa girer yeni bir tarif denerim ya da iyi bir yemek yeri keşfederim',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 6 ── (sosyal | sakin | macer | entel)
  QuizQuestion(
    question: 'Zor bir haftanın ardından seni gerçekten şarj eden ne?',
    options: [
      QuizOption(
        text: 'Arkadaşlarla dışarı çıkmak, gülmek ve gürültülü bir ortam',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Hiç kimsenin olmadığı sessiz bir ortamda sadece kendimle kalmak',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Beden yorgunluğu — spor, koşu ya da hareket etmek',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Merak ettiğim bir şeye dalmak, öğrenmek ve keşfetmek',
        type: PersonalityType.entelektuel,
      ),
    ],
  ),

  // ── Soru 7 ── (sosyal | entel | macer | gurme)
  QuizQuestion(
    question: 'Bir arkadaşın "seni anlatan bir hediye alacağım" diyor. Ne önerirsin?',
    options: [
      QuizOption(
        text: 'Birlikte bir şeyler yapalım, deneyim hediyesi olsun',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'İlgimi çeken bir konuda kitap ya da özenle seçilmiş bir şey',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Daha önce yapmadığım bir deneyim — kurs, aktivite, macera',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'İyi seçilmiş bir restoran rezervasyonu ya da gurme bir ürün',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 8 ── (sosyal | sakin | entel | gurme)
  QuizQuestion(
    question: 'Film veya dizi seçme sırası sende. Ne açarsın?',
    options: [
      QuizOption(
        text: 'Birlikte izlenecek, güldürecek ve konuşmaya açacak bir şey',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Yavaş tempolu, duygusal ama içe dönük bir yapım',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Belgesel, gerçek olaydan uyarlama ya da düşündürücü bilim kurgu',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Yemek ya da seyahat belgeseli — ya da asıl önemli olan atıştırmalıklar',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 9 ── (sakin | entel | macer | gurme)
  QuizQuestion(
    question: 'Önemli bir randevudan önce bir saatin var. Nasıl değerlendirirsin?',
    options: [
      QuizOption(
        text: 'Yakında sessiz bir yere çekilir, müzik dinler ya da kitap okurum',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'O bölgeyi ya da randevumla ilgili bir şeyleri araştırır, bilgi edinirim',
        type: PersonalityType.entelektuel,
      ),
      QuizOption(
        text: 'Çevreyi yürüyerek keşfeder, hareket ederek enerjimi toplarım',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'İyi bir kahve ya da hafif bir şeyler yiyebileceğim yer ararım',
        type: PersonalityType.gurme,
      ),
    ],
  ),

  // ── Soru 10 ── (sosyal | sakin | macer | gurme)
  QuizQuestion(
    question: 'Birisi senin için hafta sonu planı yapıyor. Tek bir isteğin ne?',
    options: [
      QuizOption(
        text: 'Mümkün olduğu kadar çok kişi toplansın, kalabalık olsun',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: 'Temposu düşük, acele ettirmeyen, sakin bir şey olsun',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: 'Daha önce hiç yapmadığımız ya da bilmediğimiz bir şey olsun',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: 'Ne yaparsak yapalım, yemek iyi olsun',
        type: PersonalityType.gurme,
      ),
    ],
  ),
];

// ── Mekan Önerisi Modeli ──────────────────────────────────────────────────────

class VenueRecommendation {
  final String name;
  final String description;
  final String type;
  final String emoji;
  final double compatibilityScore; // 0.0 - 1.0
  final List<String> tags;

  const VenueRecommendation({
    required this.name,
    required this.description,
    required this.type,
    required this.emoji,
    required this.compatibilityScore,
    required this.tags,
  });
}

// ── Kişilik Kombinasyonuna Göre Mekan Önerileri ───────────────────────────────

/// İki kullanıcının [PersonalityProfile]'ına ve seçili aktivitelere göre
/// mekan önerisi listesi döndürür.
///
/// Mekan haritası dominant tipe göre aranır; uyumluluk skoru ise
/// gerçek profil vektörüyle cosine similarity ile hesaplanır.
List<VenueRecommendation> getVenueRecommendations({
  required PersonalityProfile userProfile,
  required PersonalityProfile friendProfile,
  required List<String> selectedActivities,
}) {
  final userType = userProfile.dominantType;
  final friendType = friendProfile.dominantType;
  final combo = _buildCombo(userType, friendType);
  final baseVenues = _venueMap[combo] ?? _venueMap['default']!;

  // Seçilen aktivitelere göre filtrele/önceliklendir
  if (selectedActivities.isEmpty) return baseVenues;

  final prioritized = <VenueRecommendation>[];
  final rest = <VenueRecommendation>[];

  for (final venue in baseVenues) {
    final matchesActivity = selectedActivities.any(
      (act) => venue.tags.any(
        (tag) => tag.toLowerCase().contains(act.toLowerCase()) ||
            act.toLowerCase().contains(tag.toLowerCase()),
      ),
    );
    if (matchesActivity) {
      prioritized.add(venue);
    } else {
      rest.add(venue);
    }
  }

  return [...prioritized, ...rest];
}

String _buildCombo(PersonalityType a, PersonalityType b) {
  // Alfabetik sıraya göre birleştir (simetrik)
  final list = [a.name, b.name]..sort();
  return '${list[0]}_${list[1]}';
}

const _venueMap = <String, List<VenueRecommendation>>{
  // Sosyal Kelebek + Sosyal Kelebek
  'sosyalKelebek_sosyalKelebek': [
    VenueRecommendation(
      name: 'Rooftop Bar & Lounge',
      description: 'Şehrin en yüksek noktasında canlı müzik ve eğlence.',
      type: 'Bar / Lounge',
      emoji: '🥂',
      compatibilityScore: 0.98,
      tags: ['bar', 'eğlence', 'müzik', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Canlı Müzik Mekanı',
      description: 'Her akşam farklı performanslarla dolu enerjik ortam.',
      type: 'Eğlence',
      emoji: '🎵',
      compatibilityScore: 0.95,
      tags: ['müzik', 'konser', 'eğlence'],
    ),
    VenueRecommendation(
      name: 'Sosyal Kafe & Co-Working',
      description: 'Tanışmalar için ideal, dinamik ve samimi atmosfer.',
      type: 'Kafe',
      emoji: '☕',
      compatibilityScore: 0.88,
      tags: ['kafe', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Bowling & Eğlence Merkezi',
      description: 'Rekabetçi oyunlar ve grup eğlencesi için mükemmel.',
      type: 'Aktivite',
      emoji: '🎳',
      compatibilityScore: 0.85,
      tags: ['spor', 'eğlence', 'aktivite'],
    ),
    VenueRecommendation(
      name: 'Street Food Market',
      description: 'Kalabalık ve renkli sokak yemekleri pazarı.',
      type: 'Yemek',
      emoji: '🌮',
      compatibilityScore: 0.82,
      tags: ['yemek', 'restoran', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Karaoke Bar',
      description: 'Eğlenceli bir gece için sahne sizin!',
      type: 'Eğlence',
      emoji: '🎤',
      compatibilityScore: 0.80,
      tags: ['eğlence', 'müzik', 'bar'],
    ),
  ],

  // Sakin Ruh + Sakin Ruh
  'sakinRuh_sakinRuh': [
    VenueRecommendation(
      name: 'Kitap Kafe',
      description: 'Kitap reyonları arasında kahve eşliğinde derin sohbet.',
      type: 'Kafe',
      emoji: '📚',
      compatibilityScore: 0.97,
      tags: ['kafe', 'sakin', 'kitap'],
    ),
    VenueRecommendation(
      name: 'Botanik Bahçesi Kafesi',
      description: 'Doğa içinde huzurlu bir buluşma noktası.',
      type: 'Park / Kafe',
      emoji: '🌿',
      compatibilityScore: 0.94,
      tags: ['park', 'doğa', 'sakin', 'kafe'],
    ),
    VenueRecommendation(
      name: 'Sessiz Çay Evi',
      description: 'Geleneksel çay kültürü, sakin ve şık ortam.',
      type: 'Çay Evi',
      emoji: '🍵',
      compatibilityScore: 0.91,
      tags: ['kafe', 'sakin', 'çay'],
    ),
    VenueRecommendation(
      name: 'Modern Sanat Galerisi',
      description: 'Güncel sergi ve enstalasyonlar eşliğinde ilham veren buluşma.',
      type: 'Kültür',
      emoji: '🎨',
      compatibilityScore: 0.88,
      tags: ['kültür', 'sanat', 'müze'],
    ),
    VenueRecommendation(
      name: 'Butik Pastane',
      description: 'El yapımı tatlılar ve özel kahveler.',
      type: 'Pastane',
      emoji: '🥐',
      compatibilityScore: 0.85,
      tags: ['kafe', 'yemek', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Nehir Kenarı Park Alanı',
      description: 'Açık havada piknik ve huzurlu yürüyüş.',
      type: 'Park',
      emoji: '🌊',
      compatibilityScore: 0.82,
      tags: ['park', 'doğa', 'yürüyüş'],
    ),
  ],

  // Maceraperest + Maceraperest
  'maceraperest_maceraperest': [
    VenueRecommendation(
      name: 'Doğa Parkuru & Kamp Alanı',
      description: 'Şehir dışında adrenalin dolu doğa aktiviteleri.',
      type: 'Outdoor',
      emoji: '🏕️',
      compatibilityScore: 0.98,
      tags: ['spor', 'doğa', 'aktivite', 'açık hava'],
    ),
    VenueRecommendation(
      name: 'Tırmanma Duvarı Merkezi',
      description: 'İç mekan kaya tırmanması - hem eğlenceli hem zorlayıcı.',
      type: 'Spor',
      emoji: '🧗',
      compatibilityScore: 0.95,
      tags: ['spor', 'aktivite', 'tırmanma'],
    ),
    VenueRecommendation(
      name: 'Escape Room',
      description: 'Takım çalışmasıyla bulmacaları çözün ve kaçın!',
      type: 'Aktivite',
      emoji: '🔓',
      compatibilityScore: 0.92,
      tags: ['eğlence', 'aktivite', 'macera'],
    ),
    VenueRecommendation(
      name: 'Bisiklet Rotası + Kafe Molası',
      description: 'Şehrin tarihi bölgelerini bisikletle keşfet.',
      type: 'Outdoor',
      emoji: '🚴',
      compatibilityScore: 0.89,
      tags: ['spor', 'bisiklet', 'açık hava'],
    ),
    VenueRecommendation(
      name: 'Go-Kart Pisti',
      description: 'Hız tutkunları için heyecan verici yarış deneyimi.',
      type: 'Spor',
      emoji: '🏎️',
      compatibilityScore: 0.86,
      tags: ['spor', 'eğlence', 'aktivite'],
    ),
    VenueRecommendation(
      name: 'Rafting & Su Sporları Merkezi',
      description: 'Adrenalin dolu su aktiviteleri paketi.',
      type: 'Su Sporları',
      emoji: '🌊',
      compatibilityScore: 0.83,
      tags: ['spor', 'doğa', 'su sporları'],
    ),
  ],

  // Gurme + Gurme
  'gurme_gurme': [
    VenueRecommendation(
      name: 'Fine Dining Restoran',
      description: 'Ödüllü şefin imza menüsüyle unutulmaz bir akşam.',
      type: 'Restoran',
      emoji: '⭐',
      compatibilityScore: 0.98,
      tags: ['restoran', 'yemek', 'fine dining'],
    ),
    VenueRecommendation(
      name: 'Şef Masası Deneyimi',
      description: 'Mutfağın tam önünde, şefi izleyerek yemek deneyimi.',
      type: 'Restoran',
      emoji: '👨‍🍳',
      compatibilityScore: 0.95,
      tags: ['restoran', 'yemek', 'özel deneyim'],
    ),
    VenueRecommendation(
      name: 'Şarap & Peynir Bar',
      description: 'Seçkin şarap listesi ve özel peynir tabakları.',
      type: 'Bar',
      emoji: '🍷',
      compatibilityScore: 0.92,
      tags: ['bar', 'yemek', 'şarap'],
    ),
    VenueRecommendation(
      name: 'Pazar Yeri + Yemek Turu',
      description: 'Yerel üreticilerden taze malzeme keşfi ve tadım.',
      type: 'Yemek Turu',
      emoji: '🧺',
      compatibilityScore: 0.89,
      tags: ['yemek', 'kültür', 'gezme'],
    ),
    VenueRecommendation(
      name: 'Sushi Omakase',
      description: 'Japon mutfağının en rafine yorumu, şefin seçimiyle.',
      type: 'Restoran',
      emoji: '🍣',
      compatibilityScore: 0.86,
      tags: ['restoran', 'yemek', 'japon'],
    ),
    VenueRecommendation(
      name: 'Çikolata Atölyesi',
      description: 'El yapımı çikolata üretim sürecini öğrenin ve tadın.',
      type: 'Atölye',
      emoji: '🍫',
      compatibilityScore: 0.83,
      tags: ['yemek', 'aktivite', 'tatlı'],
    ),
  ],

  // Sosyal Kelebek + Sakin Ruh
  'sakinRuh_sosyalKelebek': [
    VenueRecommendation(
      name: 'Bahçeli Butik Kafe',
      description: 'Canlı ama bunaltmayan, her ikisini de memnun edecek sıcak atmosfer.',
      type: 'Kafe',
      emoji: '🌺',
      compatibilityScore: 0.93,
      tags: ['kafe', 'bahçe', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Rooftop Kafe (Gündüz)',
      description: 'Şehir manzarasıyla hem sosyal hem huzurlu buluşma.',
      type: 'Kafe',
      emoji: '🌆',
      compatibilityScore: 0.90,
      tags: ['kafe', 'manzara', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Küçük Sergi + Kafe Kombinasyonu',
      description: 'Sanat gezisi sonrası kafede sohbet — ikisi de mutlu!',
      type: 'Kültür + Kafe',
      emoji: '🖼️',
      compatibilityScore: 0.87,
      tags: ['kültür', 'kafe', 'sanat'],
    ),
    VenueRecommendation(
      name: 'Yavaş Yemek Restoranı',
      description: 'Sosyal ama acele ettirmeyen, huzurlu bir akşam yemeği.',
      type: 'Restoran',
      emoji: '🍽️',
      compatibilityScore: 0.84,
      tags: ['restoran', 'yemek', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Açık Hava Sinema',
      description: 'Film keyfi, ne çok kalabalık ne çok sessiz.',
      type: 'Sinema',
      emoji: '🎬',
      compatibilityScore: 0.81,
      tags: ['sinema', 'eğlence', 'açık hava'],
    ),
  ],

  // Sosyal Kelebek + Maceraperest
  'maceraperest_sosyalKelebek': [
    VenueRecommendation(
      name: 'Grup Escape Room',
      description: 'Takım ruhuyla macera — sosyal ve heyecan verici!',
      type: 'Aktivite',
      emoji: '🔓',
      compatibilityScore: 0.95,
      tags: ['eğlence', 'aktivite', 'macera', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Bowling & Bar Kombinasyonu',
      description: 'Aktif oyun sonrası sosyal bar ortamı.',
      type: 'Eğlence',
      emoji: '🎳',
      compatibilityScore: 0.92,
      tags: ['spor', 'bar', 'eğlence'],
    ),
    VenueRecommendation(
      name: 'Lazer Tag Arena',
      description: 'Rekabetçi ve eğlenceli grup oyunu.',
      type: 'Aktivite',
      emoji: '🔫',
      compatibilityScore: 0.89,
      tags: ['eğlence', 'aktivite', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Sörf veya Sup Dersi + Sahil Bar',
      description: 'Deniz aktivitesi sonrası sahilde sosyalleşme.',
      type: 'Outdoor + Sosyal',
      emoji: '🏄',
      compatibilityScore: 0.86,
      tags: ['spor', 'deniz', 'bar', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Go-Kart + Yemek Molası',
      description: 'Yarış sonrası bol eğlenceli akşam yemeği.',
      type: 'Spor + Restoran',
      emoji: '🏎️',
      compatibilityScore: 0.83,
      tags: ['spor', 'yemek', 'eğlence'],
    ),
  ],

  // Sosyal Kelebek + Gurme
  'gurme_sosyalKelebek': [
    VenueRecommendation(
      name: 'Trend Restoran (Rezervasyonlu)',
      description: 'Şehrin yeni gözdesi — lezzetli ve çekici atmosfer.',
      type: 'Restoran',
      emoji: '🔥',
      compatibilityScore: 0.95,
      tags: ['restoran', 'yemek', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Food Hall & Market',
      description: 'Farklı mutfakları keşfedebileceğin büyük gastronomi alanı.',
      type: 'Yemek',
      emoji: '🏬',
      compatibilityScore: 0.92,
      tags: ['yemek', 'restoran', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Brunch & Mimosa Bar',
      description: 'Hafta sonu kahvaltısı için ideal sosyal ve lezzetli mekan.',
      type: 'Kafe + Bar',
      emoji: '🥞',
      compatibilityScore: 0.89,
      tags: ['yemek', 'kafe', 'sosyal', 'kahvaltı'],
    ),
    VenueRecommendation(
      name: 'Canlı Müzikli Restoran',
      description: 'İyi yemek ve canlı performans bir arada.',
      type: 'Restoran',
      emoji: '🎶',
      compatibilityScore: 0.86,
      tags: ['restoran', 'müzik', 'eğlence'],
    ),
    VenueRecommendation(
      name: 'Açık Hava Yemek Festivali',
      description: 'Şehrin en büyük lezzet buluşması.',
      type: 'Etkinlik',
      emoji: '🎪',
      compatibilityScore: 0.83,
      tags: ['yemek', 'etkinlik', 'sosyal'],
    ),
  ],

  // Sakin Ruh + Maceraperest
  'maceraperest_sakinRuh': [
    VenueRecommendation(
      name: 'Orman Yürüyüşü + Çay Molası',
      description: 'Doğada aktif keşif, sonunda huzurlu bir mola.',
      type: 'Outdoor',
      emoji: '🌲',
      compatibilityScore: 0.94,
      tags: ['doğa', 'yürüyüş', 'kafe', 'park'],
    ),
    VenueRecommendation(
      name: 'Bisiklet Turu + Butik Kafe',
      description: 'Şehri pedallayarak keşfet, yorgunluğu hafif bir kahveyle at.',
      type: 'Outdoor + Kafe',
      emoji: '🚴',
      compatibilityScore: 0.91,
      tags: ['spor', 'bisiklet', 'kafe'],
    ),
    VenueRecommendation(
      name: 'Yoga + Meditasyon Parkuru',
      description: 'Açık havada fiziksel aktivite ve iç dinginlik.',
      type: 'Spor / Wellness',
      emoji: '🧘',
      compatibilityScore: 0.88,
      tags: ['spor', 'doğa', 'wellness'],
    ),
    VenueRecommendation(
      name: 'Tekne Turu (Sakin Körfez)',
      description: 'Macera ama sakin sularda — ikisi için de ideal.',
      type: 'Su Aktivitesi',
      emoji: '⛵',
      compatibilityScore: 0.85,
      tags: ['doğa', 'su', 'aktivite'],
    ),
    VenueRecommendation(
      name: 'Fotoğraf Yürüyüşü',
      description: 'Şehrin gizli köşelerini keşfet, anları ölümsüzleştir.',
      type: 'Outdoor',
      emoji: '📷',
      compatibilityScore: 0.82,
      tags: ['gezme', 'doğa', 'sanat'],
    ),
  ],

  // Sakin Ruh + Gurme
  'gurme_sakinRuh': [
    VenueRecommendation(
      name: 'Sessiz Fine Dining',
      description: 'Gürültüsüz, özel bir atmosferde mükemmel yemek deneyimi.',
      type: 'Restoran',
      emoji: '🕯️',
      compatibilityScore: 0.96,
      tags: ['restoran', 'yemek', 'sakin', 'fine dining'],
    ),
    VenueRecommendation(
      name: 'Çay Evi & Aperatif Bar',
      description: 'Geleneksel lezzetler eşliğinde sakin sohbet.',
      type: 'Çay Evi',
      emoji: '🍵',
      compatibilityScore: 0.93,
      tags: ['kafe', 'yemek', 'sakin', 'çay'],
    ),
    VenueRecommendation(
      name: 'Şarap Tadımı Etkinliği',
      description: 'Küçük grup tadım seansı, öğretici ve keyifli.',
      type: 'Tadım',
      emoji: '🍷',
      compatibilityScore: 0.90,
      tags: ['yemek', 'şarap', 'kültür'],
    ),
    VenueRecommendation(
      name: 'Bahçeli Restoran (Akşam)',
      description: 'Doğa iç içe, mumlu bir akşam yemeği.',
      type: 'Restoran',
      emoji: '🌙',
      compatibilityScore: 0.87,
      tags: ['restoran', 'bahçe', 'yemek', 'doğa'],
    ),
    VenueRecommendation(
      name: 'Pişirme Atölyesi',
      description: 'İki kişilik özel pişirme dersi ve sonrasında yemek keyfi.',
      type: 'Atölye',
      emoji: '🍳',
      compatibilityScore: 0.84,
      tags: ['yemek', 'aktivite', 'kafe'],
    ),
  ],

  // Entelektüel kombinasyonları (diğer tiplerle)
  'entelektuel_sosyalKelebek': [
    VenueRecommendation(
      name: 'Kitap Festivali veya Söyleşi',
      description: 'Fikir insanlarıyla buluşma, sosyal ama aydınlatıcı.',
      type: 'Kültür',
      emoji: '🎙️',
      compatibilityScore: 0.92,
      tags: ['kültür', 'sosyal', 'kitap'],
    ),
    VenueRecommendation(
      name: 'Çarşamba Sinema Kulübü',
      description: 'Film sonrası grup tartışması — hem entelektüel hem sosyal.',
      type: 'Sinema',
      emoji: '🎞️',
      compatibilityScore: 0.89,
      tags: ['sinema', 'kültür', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Tiyatro + Cocktail Bar',
      description: 'Performans izledikten sonra sosyal bir buluşma.',
      type: 'Tiyatro',
      emoji: '🎭',
      compatibilityScore: 0.86,
      tags: ['tiyatro', 'kültür', 'bar'],
    ),
    VenueRecommendation(
      name: 'Tarihi Müze Turu',
      description: 'Rehberli ya da serbest, bilgi dolu bir keşif.',
      type: 'Müze',
      emoji: '🏛️',
      compatibilityScore: 0.83,
      tags: ['müze', 'kültür', 'tarih'],
    ),
  ],

  'entelektuel_sakinRuh': [
    VenueRecommendation(
      name: 'Kitap Kafe',
      description: 'Sessiz okuma köşesi ve bol kitap — iki ruh için cennet.',
      type: 'Kafe',
      emoji: '📚',
      compatibilityScore: 0.97,
      tags: ['kafe', 'kitap', 'sakin', 'kültür'],
    ),
    VenueRecommendation(
      name: 'Müze Kafesi',
      description: 'Sergi sonrası sakin müze kafesinde sohbet.',
      type: 'Kültür + Kafe',
      emoji: '🖼️',
      compatibilityScore: 0.94,
      tags: ['müze', 'kafe', 'kültür', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Şiir veya Öykü Okuma Gecesi',
      description: 'Küçük edebiyat etkinlikleri için butik mekanlar.',
      type: 'Kültür',
      emoji: '✒️',
      compatibilityScore: 0.91,
      tags: ['kültür', 'edebiyat', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Klasik Müzik Konseri',
      description: 'Dinleti ve sessiz, düşündürücü bir akşam.',
      type: 'Konser',
      emoji: '🎼',
      compatibilityScore: 0.88,
      tags: ['müzik', 'kültür', 'konser'],
    ),
  ],

  'entelektuel_maceraperest': [
    VenueRecommendation(
      name: 'Tarihi Bölge Yürüyüşü',
      description: 'Şehrin kadim mahallelerini keşfet, öğren ve hareket et.',
      type: 'Outdoor + Kültür',
      emoji: '🏰',
      compatibilityScore: 0.93,
      tags: ['kültür', 'yürüyüş', 'tarih', 'macera'],
    ),
    VenueRecommendation(
      name: 'Bilim Müzesi & Planetaryum',
      description: 'İnteraktif deneyimler ve gökyüzü gösterisi.',
      type: 'Müze',
      emoji: '🔭',
      compatibilityScore: 0.90,
      tags: ['müze', 'kültür', 'bilim'],
    ),
    VenueRecommendation(
      name: 'Macera + Fotoğraf Turu',
      description: 'Farklı semtleri gezip, anları kadraja almak.',
      type: 'Outdoor',
      emoji: '📸',
      compatibilityScore: 0.87,
      tags: ['gezme', 'fotoğraf', 'keşif'],
    ),
    VenueRecommendation(
      name: 'Arkeoloji veya Doğa Parkı',
      description: 'Hem keşif hem öğrenme dolu açık hava deneyimi.',
      type: 'Park / Kültür',
      emoji: '🦴',
      compatibilityScore: 0.84,
      tags: ['doğa', 'kültür', 'park'],
    ),
  ],

  'entelektuel_gurme': [
    VenueRecommendation(
      name: 'Yazar Akşam Yemeği (Tema Restoran)',
      description: 'Edebiyat temalı atmosferle özel yemek deneyimi.',
      type: 'Restoran',
      emoji: '✍️',
      compatibilityScore: 0.94,
      tags: ['restoran', 'yemek', 'kültür'],
    ),
    VenueRecommendation(
      name: 'Gastronomi & Tarih Turu',
      description: 'Tarihi yapıları gezerken yerel lezzetleri tadın.',
      type: 'Yemek Turu',
      emoji: '🗺️',
      compatibilityScore: 0.91,
      tags: ['yemek', 'kültür', 'tarih', 'tur'],
    ),
    VenueRecommendation(
      name: 'Şarap & Sanat Gecesi',
      description: 'Bir şişe iyi şarap eşliğinde galeri gezisi.',
      type: 'Kültür + Bar',
      emoji: '🍷',
      compatibilityScore: 0.88,
      tags: ['şarap', 'sanat', 'kültür'],
    ),
    VenueRecommendation(
      name: 'Çarşı Gastronomi Keşfi',
      description: 'Tarihi çarşıda gezerek yerel üreticileri tanıma.',
      type: 'Yemek Turu',
      emoji: '🧺',
      compatibilityScore: 0.85,
      tags: ['yemek', 'kültür', 'tarih'],
    ),
  ],

  'entelektuel_entelektuel': [
    VenueRecommendation(
      name: 'Felsefe Kulübü Kafesi',
      description: 'Düzenli tartışma gruplarının toplandığı entelektüel mekan.',
      type: 'Kafe',
      emoji: '🤔',
      compatibilityScore: 0.97,
      tags: ['kafe', 'kültür', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Sanat Galerisi + Söyleşi',
      description: 'Sanatçı söyleşisi ve ardından galeri turu.',
      type: 'Kültür',
      emoji: '🎨',
      compatibilityScore: 0.94,
      tags: ['sanat', 'kültür', 'galeri'],
    ),
    VenueRecommendation(
      name: 'Belgesel Film Gösterimi',
      description: 'Küçük salon, seçkin film, derin tartışma.',
      type: 'Sinema',
      emoji: '🎞️',
      compatibilityScore: 0.91,
      tags: ['sinema', 'kültür', 'belgesel'],
    ),
    VenueRecommendation(
      name: 'Tarihi Kütüphane',
      description: 'Şehrin en güzel kütüphanesinde buluşma.',
      type: 'Kültür',
      emoji: '🏛️',
      compatibilityScore: 0.88,
      tags: ['kültür', 'kitap', 'sakin'],
    ),
    VenueRecommendation(
      name: 'Planetaryum Gecesi',
      description: 'Gökyüzünün sırlarını birlikte keşfedin.',
      type: 'Kültür / Bilim',
      emoji: '🌌',
      compatibilityScore: 0.85,
      tags: ['bilim', 'kültür', 'müze'],
    ),
  ],

  // Varsayılan (tüm kombinasyonlar için fallback)
  'default': [
    VenueRecommendation(
      name: 'Şehrin Popüler Kafesi',
      description: 'Her zevke hitap eden, şık ve konforlu buluşma noktası.',
      type: 'Kafe',
      emoji: '☕',
      compatibilityScore: 0.80,
      tags: ['kafe', 'sosyal'],
    ),
    VenueRecommendation(
      name: 'Park ve Açık Hava Alanı',
      description: 'Doğal ortamda rahat ve keyifli buluşma.',
      type: 'Park',
      emoji: '🌳',
      compatibilityScore: 0.75,
      tags: ['park', 'doğa'],
    ),
    VenueRecommendation(
      name: 'Alışveriş Merkezi Food Court',
      description: 'Çeşitli seçenekler sunan merkezi buluşma noktası.',
      type: 'Yemek',
      emoji: '🛍️',
      compatibilityScore: 0.70,
      tags: ['yemek', 'alışveriş'],
    ),
    VenueRecommendation(
      name: 'Sinema',
      description: 'Her zaman bir klasik: birlikte film izlemek.',
      type: 'Sinema',
      emoji: '🎬',
      compatibilityScore: 0.72,
      tags: ['sinema', 'eğlence'],
    ),
  ],
};
