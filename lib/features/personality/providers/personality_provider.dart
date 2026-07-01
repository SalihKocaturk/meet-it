import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/notifiers/personality_notifier.dart';

// Ana quiz notifier provider
final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);

// Mevcut soru
final currentQuizQuestionProvider = Provider<QuizQuestion>((ref) {
  return ref.watch(quizProvider).currentQuestion;
});

// İlerleme yüzdesi (0.0 – 1.0)
final quizProgressProvider = Provider<double>((ref) {
  return ref.watch(quizProvider).progress;
});

// Quiz tamamlandı mı?
final quizCompletedProvider = Provider<bool>((ref) {
  return ref.watch(quizProvider).isCompleted;
});

// Quiz sonucu — artık PersonalityProfile döner
final quizResultProvider = Provider<PersonalityProfile?>((ref) {
  return ref.watch(quizProvider).result;
});

// Mevcut soru için seçili cevap
final selectedAnswerProvider = Provider<PersonalityType?>((ref) {
  return ref.watch(quizProvider).selectedAnswerForCurrent;
});
