import 'package:flutter_test/flutter_test.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

PersonalityProfile profile(Map<PersonalityType, double> scores) =>
    PersonalityProfile(scores: scores, lastUpdated: DateTime(2026, 1, 1));

void main() {
  group('PersonalityProfile.compatibilityWith (kosinüs benzerliği)', () {
    test('aynı profiller en yüksek skoru (98) vermeli', () {
      final a = profile({
        PersonalityType.sosyalKelebek: 0.6,
        PersonalityType.gurme: 0.4,
      });
      expect(a.compatibilityWith(a), 98);
    });

    test('birbirine dik (ortak tipi olmayan) profiller en düşük skoru (50) vermeli',
        () {
      final a = profile({PersonalityType.sosyalKelebek: 1.0});
      final b = profile({PersonalityType.sakinRuh: 1.0});
      expect(a.compatibilityWith(b), 50);
    });

    test('ölçekten bağımsız olmalı (oranlar aynıysa skor aynı)', () {
      final a = profile({
        PersonalityType.maceraperest: 1.0,
        PersonalityType.gurme: 1.0,
      });
      final b = profile({
        PersonalityType.maceraperest: 0.5,
        PersonalityType.gurme: 0.5,
      });
      expect(a.compatibilityWith(b), 98);
    });

    test('kısmi örtüşme: cos = 1/√2 → 84', () {
      final a = profile({
        PersonalityType.sosyalKelebek: 1.0,
        PersonalityType.sakinRuh: 0.0,
      });
      final b = profile({
        PersonalityType.sosyalKelebek: 1.0,
        PersonalityType.sakinRuh: 1.0,
      });
      expect(a.compatibilityWith(b), 84);
    });

    test('simetrik olmalı (a→b == b→a)', () {
      final a = profile({
        PersonalityType.sosyalKelebek: 0.7,
        PersonalityType.entelektuel: 0.3,
      });
      final b = profile({
        PersonalityType.entelektuel: 0.5,
        PersonalityType.gurme: 0.5,
      });
      expect(a.compatibilityWith(b), b.compatibilityWith(a));
    });

    test('sıfır vektörde varsayılan 70 dönmeli', () {
      final empty = profile({});
      final a = profile({PersonalityType.gurme: 1.0});
      expect(empty.compatibilityWith(a), 70);
      expect(a.compatibilityWith(empty), 70);
    });

    test('sonuç her zaman 50–98 aralığında olmalı', () {
      final a = profile({
        PersonalityType.sosyalKelebek: 0.2,
        PersonalityType.sakinRuh: 0.2,
        PersonalityType.maceraperest: 0.2,
        PersonalityType.entelektuel: 0.2,
        PersonalityType.gurme: 0.2,
      });
      for (final t in PersonalityType.values) {
        final score = a.compatibilityWith(profile({t: 1.0}));
        expect(score, inInclusiveRange(50, 98));
      }
    });
  });
}
