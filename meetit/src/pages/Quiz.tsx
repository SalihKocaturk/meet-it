import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';
import { PersonalityType } from '../types';
import {
  QUIZ_QUESTIONS,
  PERSONALITY_LABELS,
  PERSONALITY_DESCRIPTIONS,
  PERSONALITY_EMOJIS,
  PERSONALITY_COLORS,
} from '../data/questions';

export default function Quiz() {
  const { currentUser, completeQuiz } = useApp();
  const navigate = useNavigate();

  const [currentQ, setCurrentQ] = useState(0);
  const [answers, setAnswers] = useState<PersonalityType[]>([]);
  const [selectedOption, setSelectedOption] = useState<PersonalityType | null>(null);
  const [phase, setPhase] = useState<'intro' | 'quiz' | 'result'>('intro');
  const [result, setResult] = useState<PersonalityType | null>(null);
  const [animating, setAnimating] = useState(false);

  const question = QUIZ_QUESTIONS[currentQ];
  const progress = ((currentQ) / QUIZ_QUESTIONS.length) * 100;

  function handleSelect(personality: PersonalityType) {
    if (animating) return;
    setSelectedOption(personality);
  }

  function handleNext() {
    if (!selectedOption || animating) return;
    setAnimating(true);

    const newAnswers = [...answers, selectedOption];

    setTimeout(() => {
      if (currentQ + 1 < QUIZ_QUESTIONS.length) {
        setAnswers(newAnswers);
        setCurrentQ(currentQ + 1);
        setSelectedOption(null);
        setAnimating(false);
      } else {
        // Calculate result
        const counts: Record<PersonalityType, number> = {
          explorer: 0,
          social: 0,
          creative: 0,
          cozy: 0,
        };
        newAnswers.forEach((a) => counts[a]++);
        const winner = (Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0]) as PersonalityType;
        setResult(winner);
        setPhase('result');
        setAnimating(false);
        if (currentUser) {
          completeQuiz(currentUser.id, winner);
        }
      }
    }, 300);
  }

  function handleGoHome() {
    navigate('/');
  }

  if (phase === 'intro') {
    return (
      <div className="quiz-page">
        <div className="quiz-intro-card">
          <div className="quiz-intro-emoji">🧠</div>
          <h1>Kişilik Testi</h1>
          <p>
            8 kısa soruyla seni daha iyi tanıyalım! Cevaplarına göre kişilik tipini belirleyecek ve
            arkadaşlarınla buluşmak için en uygun mekanları önereceğiz.
          </p>
          <div className="quiz-intro-types">
            {(['explorer', 'social', 'creative', 'cozy'] as PersonalityType[]).map((type) => (
              <div key={type} className="quiz-intro-type" style={{ borderColor: PERSONALITY_COLORS[type] }}>
                <span style={{ fontSize: 22 }}>{PERSONALITY_EMOJIS[type]}</span>
                <span style={{ color: PERSONALITY_COLORS[type], fontWeight: 600 }}>
                  {PERSONALITY_LABELS[type]}
                </span>
              </div>
            ))}
          </div>
          <button className="btn-primary" onClick={() => setPhase('quiz')}>
            Teste Başla →
          </button>
        </div>
      </div>
    );
  }

  if (phase === 'result' && result) {
    const color = PERSONALITY_COLORS[result];
    return (
      <div className="quiz-page">
        <div className="quiz-result-card" style={{ borderColor: color }}>
          <div className="quiz-result-confetti">🎉</div>
          <div className="quiz-result-emoji" style={{ background: color + '22' }}>
            {PERSONALITY_EMOJIS[result]}
          </div>
          <h2>Sen bir</h2>
          <h1 style={{ color }}>{PERSONALITY_LABELS[result]}sın!</h1>
          <p className="quiz-result-desc">{PERSONALITY_DESCRIPTIONS[result]}</p>
          <div className="quiz-result-tags">
            <span style={{ background: color + '22', color }}>
              {PERSONALITY_EMOJIS[result]} {PERSONALITY_LABELS[result]}
            </span>
          </div>
          <button className="btn-primary" style={{ background: color }} onClick={handleGoHome}>
            Ana Sayfaya Dön
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="quiz-page">
      {/* Progress bar */}
      <div className="quiz-progress-bar">
        <div className="quiz-progress-fill" style={{ width: `${progress}%` }} />
      </div>
      <div className="quiz-counter">
        Soru {currentQ + 1} / {QUIZ_QUESTIONS.length}
      </div>

      <div className={`quiz-card ${animating ? 'quiz-card-exit' : ''}`}>
        <p className="quiz-question">{question.text}</p>

        <div className="quiz-options">
          {question.options.map((opt) => (
            <button
              key={opt.personality}
              className={`quiz-option ${selectedOption === opt.personality ? 'quiz-option-selected' : ''}`}
              onClick={() => handleSelect(opt.personality)}
            >
              {opt.text}
            </button>
          ))}
        </div>

        <button
          className="btn-primary quiz-next-btn"
          disabled={!selectedOption}
          onClick={handleNext}
        >
          {currentQ + 1 === QUIZ_QUESTIONS.length ? 'Sonucu Gör 🎉' : 'Sonraki →'}
        </button>
      </div>
    </div>
  );
}
