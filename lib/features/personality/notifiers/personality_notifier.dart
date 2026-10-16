import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Quiz State ────────────────────────────────────────────────────────────────

class QuizState {
  final int currentQuestionIndex;
  final Map<int, int> answers; // soru index → seçilen cevap index'i
  final bool isCompleted;

  /// Quiz tamamlandığında hesaplanan kişilik profili (skor tabanlı)
  final PersonalityProfile? result;

  const QuizState({
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.isCompleted = false,
    this.result,
  });

  bool get isLastQuestion =>
      currentQuestionIndex == kQuizQuestions.length - 1;

  double get progress => currentQuestionIndex / kQuizQuestions.length;

  QuizQuestion get currentQuestion =>
      kQuizQuestions[currentQuestionIndex];

  bool hasAnswered(int questionIndex) => answers.containsKey(questionIndex);

  int? get selectedAnswerForCurrent => answers[currentQuestionIndex];

  QuizState copyWith({
    int? currentQuestionIndex,
    Map<int, int>? answers,
    bool? isCompleted,
    PersonalityProfile? result,
    bool clearResult = false,
  }) {
    return QuizState(
      currentQuestionIndex:
          currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      isCompleted: isCompleted ?? this.isCompleted,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

// ── Quiz Notifier ─────────────────────────────────────────────────────────────

class QuizNotifier extends Notifier<QuizState> {
  @override
  QuizState build() => const QuizState();

  /// Mevcut soruya cevap seç ([optionIndex] = seçenek sırası).
  void selectAnswer(int optionIndex) {
    final updatedAnswers = Map<int, int>.from(state.answers);
    updatedAnswers[state.currentQuestionIndex] = optionIndex;
    state = state.copyWith(answers: updatedAnswers);
  }

  /// Sonraki soruya geç
  void nextQuestion() {
    if (!state.hasAnswered(state.currentQuestionIndex)) return;

    if (state.isLastQuestion) {
      _computeResult();
    } else {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  /// Önceki soruya dön
  void previousQuestion() {
    if (state.currentQuestionIndex == 0) return;
    state = state.copyWith(
      currentQuestionIndex: state.currentQuestionIndex - 1,
    );
  }

  /// Quizi sıfırla (tekrar başlat)
  void reset() {
    state = const QuizState();
  }

  /// Cevaplara göre kişilik profili hesapla.
  ///
  /// Her cevap tiplere + / − ağırlık verir (bkz. kQuizQuestions). Her tipin
  /// ham toplamı, o tipin bu testte alabileceği en düşük/en yüksek puana göre
  /// 0–1 aralığına çekilir — böylece bir tipin daha çok soruda geçmesi ona
  /// avantaj sağlamaz. Sonra kareleri alınıp toplamı 1 olacak şekilde
  /// normalize edilir: kare alma baskın tipi belirginleştirir (eski
  /// sayım-yüzde sistemine benzer bir dağılım çıkar, uygulamanın geri kalanı
  /// — ikincil tip eşiği, uyum hesabı — aynı şekilde çalışır).
  void _computeResult() {
    if (state.answers.isEmpty) return;

    final raw = {for (final t in PersonalityType.values) t: 0};
    final minPossible = {for (final t in PersonalityType.values) t: 0};
    final maxPossible = {for (final t in PersonalityType.values) t: 0};

    for (var q = 0; q < kQuizQuestions.length; q++) {
      final options = kQuizQuestions[q].options;
      for (final t in PersonalityType.values) {
        final values = options.map((o) => o.weights[t] ?? 0);
        minPossible[t] = minPossible[t]! + values.reduce(min);
        maxPossible[t] = maxPossible[t]! + values.reduce(max);
      }
      final chosen = state.answers[q];
      if (chosen == null || chosen < 0 || chosen >= options.length) continue;
      options[chosen].weights.forEach((t, w) => raw[t] = raw[t]! + w);
    }

    final sharpened = <PersonalityType, double>{};
    for (final t in PersonalityType.values) {
      final span = maxPossible[t]! - minPossible[t]!;
      final n = span <= 0 ? 0.0 : (raw[t]! - minPossible[t]!) / span;
      sharpened[t] = n * n;
    }
    final sum = sharpened.values.fold<double>(0, (a, b) => a + b);
    final scores = sum <= 0
        ? {for (final t in PersonalityType.values) t: 1 / PersonalityType.values.length}
        : sharpened.map((t, v) => MapEntry(t, v / sum));

    final profile = PersonalityProfile(
      scores: Map.unmodifiable(scores),
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      isCompleted: true,
      result: profile,
    );
  }
}
