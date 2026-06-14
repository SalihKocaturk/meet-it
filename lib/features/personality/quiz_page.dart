import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/providers/personality_provider.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key});

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _animateToNext() async {
    ref.read(quizProvider.notifier).nextQuestion();
  }

  void _animateToPrev() async {
    await _slideController.reverse();
    await _fadeController.reverse();
    ref.read(quizProvider.notifier).previousQuestion();
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward(from: 0);
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    if (quizState.isCompleted && quizState.result != null) {
      return _ResultPage(result: quizState.result!);
    }

    final question = quizState.currentQuestion;
    final selectedAnswer = quizState.selectedAnswerForCurrent;
    final progress =
        (quizState.currentQuestionIndex + 1) / kQuizQuestions.length;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24),

              // Üst bar: geri + ilerleme
              Row(
                children: [
                  if (quizState.currentQuestionIndex > 0)
                    GestureDetector(
                      onTap: _animateToPrev,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'quiz.question_of'.tr(namedArgs: {
                            'current': '${quizState.currentQuestionIndex + 1}',
                            'total': '${kQuizQuestions.length}',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: context.colors.primary.withOpacity(
                              0.12,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.primary,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // Başlık
              Center(
                child: Text(
                  '🧠 ${'quiz.title'.tr()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Soru (animasyonlu)
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Soru metni
                        Text(
                          question.question,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Seçenekler
                        ...question.options.map(
                          (option) => _OptionTile(
                            option: option,
                            isSelected: selectedAnswer == option.type,
                            onTap: () => ref
                                .read(quizProvider.notifier)
                                .selectAnswer(option.type),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Devam butonu
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedAnswer != null ? _animateToNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      disabledBackgroundColor: context.colors.primary
                          .withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      quizState.isLastQuestion ? 'quiz.see_results'.tr() : 'common.continue'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Seçenek Tile ──────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final QuizOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.primary.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Seçim göstergesi
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? context.colors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sonuç Sayfası ─────────────────────────────────────────────────────────────

class _ResultPage extends ConsumerWidget {
  final PersonalityProfile result;

  const _ResultPage({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dominant = result.dominantType;
    final secondary = result.secondaryType;
    final ranked = result.rankedTypes;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),

              Text('🎉', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),

              Text(
                'quiz.profile_ready'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),

              // Dominant tip
              Text(dominant.emoji, style: TextStyle(fontSize: 64)),
              SizedBox(height: 8),
              Text(
                dominant.displayName,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),

              // İkincil tip varsa göster
              if (secondary != null) ...[
                SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'quiz.secondary_type'.tr(namedArgs: {
                      'emoji': secondary.emoji,
                      'name': secondary.displayName,
                    }),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 16),

              // Açıklama
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  dominant.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // ── Skor Barları ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'quiz.personality_distribution'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...ranked.map(
                      (entry) => _ScoreBar(
                        type: entry.key,
                        score: entry.value,
                        isDominant: entry.key == dominant,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Bilgi notu
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: context.colors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'quiz.venue_personalized'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Devam et butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Kişilik profilini auth state'e kaydet (SharedPreferences'a da yazar)
                    await ref
                        .read(authProvider.notifier)
                        .setPersonalityProfile(result);
                    if (!context.mounted) return;
                    context.go(AppRoutes.main);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'quiz.explore_app'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Testi tekrarla
              TextButton(
                onPressed: () {
                  ref.read(quizProvider.notifier).reset();
                },
                child: Text(
                  'quiz.retake_test'.tr(),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skor Çubuğu ───────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final PersonalityType type;
  final double score; // 0.0 – 1.0
  final bool isDominant;

  const _ScoreBar({
    required this.type,
    required this.score,
    required this.isDominant,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Emoji + isim
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    type.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isDominant
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isDominant
                          ? context.colors.primary
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // Çubuk
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 8,
                backgroundColor: context.colors.primary.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDominant
                      ? context.colors.primary
                      : context.colors.primary.withOpacity(0.40),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          // Yüzde
          SizedBox(
            width: 32,
            child: Text(
              '%$percent',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDominant ? FontWeight.w700 : FontWeight.w400,
                color: isDominant
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
