import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Quiz State ────────────────────────────────────────────────────────────────

class QuizState {
  final int currentQuestionIndex;
  final Map<int, PersonalityType> answers; // soru index → seçilen tip
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

  PersonalityType? get selectedAnswerForCurrent =>
      answers[currentQuestionIndex];

  QuizState copyWith({
    int? currentQuestionIndex,
    Map<int, PersonalityType>? answers,
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

  /// Mevcut soruya cevap seç
  void selectAnswer(PersonalityType type) {
    final updatedAnswers = Map<int, PersonalityType>.from(state.answers);
    updatedAnswers[state.currentQuestionIndex] = type;
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
  /// Her soru için seçilen tip sayılır, toplam soru sayısına bölünerek
  /// normalize edilir → her tipin 0.0–1.0 arası skoru oluşur.
  void _computeResult() {
    final total = state.answers.length;
    if (total == 0) return;

    // Her tip için cevap sayısını say
    final counts = <PersonalityType, int>{};
    for (final type in PersonalityType.values) {
      counts[type] = 0;
    }
    for (final type in state.answers.values) {
      counts[type] = (counts[type] ?? 0) + 1;
    }

    // Normalize et (0.0 – 1.0)
    final scores = counts.map(
      (type, count) => MapEntry(type, count / total),
    );

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
