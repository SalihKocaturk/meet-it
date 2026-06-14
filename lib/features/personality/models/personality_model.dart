// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';

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
        return '🌿';
      case PersonalityType.maceraperest:
        return '🧗';
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
  // Not: Dart 3 enum'larında .name built-in olarak mevcuttur — override gerekmez.
}

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

const List<QuizQuestion> kQuizQuestions = [
  QuizQuestion(
    question: 'Boş zamanında ne yapmaktan en çok keyif alırsın?',
    options: [
      QuizOption(
        text: '🎉 Arkadaşlarımla kalabalık mekanlarda eğlenirim',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '📖 Sakin bir kafede kitap okur ya da film izlerim',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '🏕️ Yeni yerler keşfeder, doğada zaman geçiririm',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🎭 Müze, sergi veya kültürel etkinliklere giderim',
        type: PersonalityType.entelektuel,
      ),
    ],
  ),
  QuizQuestion(
    question: 'Arkadaşlarınla buluşunca genellikle ne yaparsınız?',
    options: [
      QuizOption(
        text: '🎵 Bar, konser ya da eğlenceli sosyal mekanlar',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '☕ Huzurlu bir kafede saatlerce sohbet ederiz',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '🧗 Spor, outdoor aktivite veya macera planlarız',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🍝 İyi bir restoranda uzun yemek sohbeti yaparız',
        type: PersonalityType.gurme,
      ),
    ],
  ),
  QuizQuestion(
    question: 'İdeal bir hafta sonu nasıl geçerdi?',
    options: [
      QuizOption(
        text: '🥳 Partiler, sosyal etkinlikler, yeni insanlar tanımak',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '🌸 Huzurlu bir doğa yürüyüşü veya spa günü',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '🚵 Trekking, bisiklet ya da macera sporu',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🍷 Yeni restoranlar deneyim, food festival gezmek',
        type: PersonalityType.gurme,
      ),
    ],
  ),
  QuizQuestion(
    question: 'Bir mekan seçerken en önemli kriterini söyle.',
    options: [
      QuizOption(
        text: '🎶 Canlı atmosfer ve müzik olmalı',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '🕯️ Sakin, huzurlu ve şık bir ortam',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '⚡ Aktivite veya deneyim imkanı sunuyor mu?',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🌟 Menü kalitesi ve şefin becerisi benim için önemli',
        type: PersonalityType.gurme,
      ),
    ],
  ),
  QuizQuestion(
    question: 'Seni en iyi tanımlayan cümle hangisi?',
    options: [
      QuizOption(
        text: '"Tanımadığım insanlarla da hemen kaynaşırım."',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '"Az insanla derin ilişkiler kurmayı tercih ederim."',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '"Konfor alanımın dışına çıkmaktan keyif alırım."',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '"Her yemeği bir ritüel gibi yaşarım."',
        type: PersonalityType.gurme,
      ),
    ],
  ),
  QuizQuestion(
    question: 'Stresli bir günden sonra ne yaparsın?',
    options: [
      QuizOption(
        text: '👫 Arkadaşlarımı arar, dışarı çıkarım',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '🛁 Sessiz bir ortamda dinlenirim',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '🏃 Spor yaparım ya da bir yere koşarım',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🍜 Güzel bir yemek pişirir ya da dışarıda iyi bir şey yerim',
        type: PersonalityType.gurme,
      ),
    ],
  ),
  QuizQuestion(
    question: 'Tatilde hangi aktiviteyi seçerdin?',
    options: [
      QuizOption(
        text: '🏖️ Büyük resort otelde eğlenceli aktiviteler',
        type: PersonalityType.sosyalKelebek,
      ),
      QuizOption(
        text: '🏡 Küçük, sakin bir butik otel veya doğa evi',
        type: PersonalityType.sakinRuh,
      ),
      QuizOption(
        text: '🧭 Backpacking, yeni şehirler keşfetmek',
        type: PersonalityType.maceraperest,
      ),
      QuizOption(
        text: '🥂 Gastronomi turu, yerel mutfaklar denemek',
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
