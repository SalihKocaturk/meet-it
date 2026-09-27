/// Kullanıcı içeriği için basit küfür/hakaret filtresi.
///
/// App Store Guideline 1.2 "uygunsuz içeriği filtreleme yöntemi" şartı için.
/// Bu bir başlangıç listesi — şikâyet akışı ve 24 saatlik manuel moderasyonla
/// birlikte çalışır, tek başına kusursuz bir filtre değildir.
///
/// İki tür eşleşme var:
///  - [_prefixes]: kelimenin BAŞINDA geçerse yakalanır (çekimli halleri için)
///  - [_exact]: sadece kelimenin tamamı eşleşirse yakalanır. Masum kelimelerin
///    ön eki olabilenler buraya konur (örn. "göt" → "götürmek" yakalanmasın).
class ContentFilter {
  ContentFilter._();

  static const _prefixes = <String>[
    // TR
    'amcık', 'amına', 'amina', 'orospu', 'yarrak', 'yarak', 'siktir',
    'sikiş', 'sikis', 'sikerim', 'sikeyim', 'sikik', 'pezevenk', 'kahpe',
    'yavşak', 'yavsak', 'gavat', 'ibne', 'puşt', 'pust', 'kaltak',
    'şerefsiz', 'serefsiz', 'ananı', 'anani', 'ananızı',
    // EN
    'fuck', 'shit', 'bitch', 'cunt', 'asshole', 'motherfuck', 'faggot',
    'nigger', 'nigga', 'whore', 'slut', 'retard',
  ];

  static const _exact = <String>[
    // TR
    'amk', 'aq', 'mk', 'oç', 'oc', 'piç', 'pic', 'sik', 'göt', 'got',
    'am', 'sg', 'siktir',
    // EN
    'dick', 'cock', 'pussy', 'fag', 'wtf',
  ];

  static final _tokenRe = RegExp(r"[\p{L}\p{N}]+", unicode: true);

  /// Türkçe'ye duyarlı küçük harf (İ→i, I→ı).
  static String _lower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  static bool _isBad(String word) {
    final w = _lower(word);
    if (_exact.contains(w)) return true;
    for (final p in _prefixes) {
      if (w.startsWith(p)) return true;
    }
    return false;
  }

  /// Metinde filtrelenen bir kelime var mı.
  static bool containsProfanity(String? text) {
    if (text == null || text.isEmpty) return false;
    return _tokenRe.allMatches(text).any((m) => _isBad(m.group(0)!));
  }

  /// Filtrelenen kelimeleri aynı uzunlukta yıldızla değiştirir.
  static String mask(String text) {
    return text.replaceAllMapped(_tokenRe, (m) {
      final w = m.group(0)!;
      return _isBad(w) ? '*' * w.length : w;
    });
  }
}
