import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';
import { ActivityType, MeetingSuggestion } from '../types';
import {
  PERSONALITY_LABELS,
  PERSONALITY_EMOJIS,
  PERSONALITY_COLORS,
} from '../data/questions';

const ACTIVITY_OPTIONS: { type: ActivityType; label: string; emoji: string; desc: string }[] = [
  { type: 'yeme-icme', label: 'Yeme & İçme', emoji: '🍽️', desc: 'Restoran, meyhane, iftar sofrası' },
  { type: 'kafe-kahve', label: 'Kafe & Kahve', emoji: '☕', desc: 'Specialty coffee, çay bahçesi' },
  { type: 'kultur-sanat', label: 'Kültür & Sanat', emoji: '🎨', desc: 'Müze, galeri, tiyatro, konser' },
  { type: 'spor-dogal', label: 'Spor & Doğa', emoji: '🌲', desc: 'Yürüyüş, bisiklet, piknik, park' },
  { type: 'eglence', label: 'Eğlence', emoji: '🎉', desc: 'Kaçış odası, oyun, aktivite' },
];

export default function Meeting() {
  const { friendId } = useParams<{ friendId: string }>();
  const { currentUser, users, getSuggestedVenues } = useApp();
  const navigate = useNavigate();

  const [selectedActivities, setSelectedActivities] = useState<ActivityType[]>([]);
  const [suggestions, setSuggestions] = useState<MeetingSuggestion[] | null>(null);
  const [step, setStep] = useState<'select' | 'results'>('select');

  const friend = users.find((u) => u.id === friendId);

  if (!currentUser || !friend) {
    navigate('/friends');
    return null;
  }

  function toggleActivity(type: ActivityType) {
    setSelectedActivities((prev) =>
      prev.includes(type) ? prev.filter((a) => a !== type) : [...prev, type]
    );
  }

  function handleSearch() {
    if (!currentUser) return;
    const results = getSuggestedVenues(selectedActivities, currentUser.id, friend!.id);
    setSuggestions(results);
    setStep('results');
  }

  const p1 = currentUser.personalityType;
  const p2 = friend.personalityType;

  return (
    <div className="page-container">
      <div className="meeting-header">
        <button className="back-btn" onClick={() => navigate('/friends')}>
          ← Geri
        </button>
        <h1 className="page-title">Buluşma Planla</h1>
      </div>

      {/* Compatibility card */}
      <div className="compat-card">
        <div className="compat-user">
          <div
            className="compat-avatar"
            style={{ background: p1 ? PERSONALITY_COLORS[p1] + '33' : '#f3f4f6' }}
          >
            {currentUser.avatar}
          </div>
          <div className="compat-name">{currentUser.name.split(' ')[0]}</div>
          {p1 && (
            <div className="compat-type" style={{ color: PERSONALITY_COLORS[p1] }}>
              {PERSONALITY_EMOJIS[p1]} {PERSONALITY_LABELS[p1]}
            </div>
          )}
        </div>

        <div className="compat-vs">❤️</div>

        <div className="compat-user">
          <div
            className="compat-avatar"
            style={{ background: p2 ? PERSONALITY_COLORS[p2] + '33' : '#f3f4f6' }}
          >
            {friend.avatar}
          </div>
          <div className="compat-name">{friend.name.split(' ')[0]}</div>
          {p2 ? (
            <div className="compat-type" style={{ color: PERSONALITY_COLORS[p2] }}>
              {PERSONALITY_EMOJIS[p2]} {PERSONALITY_LABELS[p2]}
            </div>
          ) : (
            <div className="compat-type" style={{ color: '#9ca3af' }}>
              Test yapılmadı
            </div>
          )}
        </div>
      </div>

      {step === 'select' && (
        <>
          <div className="section-title">Ne tür aktivite istiyorsunuz?</div>
          <p className="section-sub">Birden fazla seçebilirsiniz 👇</p>

          <div className="activity-grid">
            {ACTIVITY_OPTIONS.map((opt) => {
              const isSelected = selectedActivities.includes(opt.type);
              return (
                <button
                  key={opt.type}
                  className={`activity-card ${isSelected ? 'activity-card-selected' : ''}`}
                  onClick={() => toggleActivity(opt.type)}
                >
                  <div className="activity-emoji">{opt.emoji}</div>
                  <div className="activity-label">{opt.label}</div>
                  <div className="activity-desc">{opt.desc}</div>
                  {isSelected && <div className="activity-check">✓</div>}
                </button>
              );
            })}
          </div>

          <button
            className="btn-primary meeting-search-btn"
            onClick={handleSearch}
          >
            {selectedActivities.length === 0
              ? 'Tüm Mekanları Göster 🔍'
              : `${selectedActivities.length} Aktivite için Mekan Bul 🔍`}
          </button>
        </>
      )}

      {step === 'results' && suggestions && (
        <>
          <div className="section-title">
            Size Özel {suggestions.length} Öneri 🎯
          </div>
          <p className="section-sub">
            İki kişinin kişiliği ve seçimlerinize göre sıralandı
          </p>

          <div className="venue-list">
            {suggestions.map((s, idx) => (
              <div key={s.venue.id} className={`venue-card ${idx === 0 ? 'venue-card-top' : ''}`}>
                {idx === 0 && <div className="venue-top-badge">⭐ En İyi Eşleşme</div>}
                <div className="venue-card-header">
                  <div className="venue-emoji-big">{s.venue.emoji}</div>
                  <div className="venue-card-info">
                    <div className="venue-name">{s.venue.name}</div>
                    <div className="venue-location">📍 {s.venue.location}</div>
                    <div className="venue-meta">
                      <span className="venue-rating">⭐ {s.venue.rating}</span>
                      <span className="venue-price">{s.venue.priceRange}</span>
                    </div>
                  </div>
                  <div className="venue-score-circle">
                    <span className="venue-score-num">{s.compatibilityScore}</span>
                    <span className="venue-score-pct">puan</span>
                  </div>
                </div>
                <p className="venue-desc">{s.venue.description}</p>
                <div className="venue-reason">💡 {s.reason}</div>
                <div className="venue-tags">
                  {s.venue.tags.slice(0, 4).map((tag) => (
                    <span key={tag} className="venue-tag">#{tag}</span>
                  ))}
                </div>
              </div>
            ))}
          </div>

          <button
            className="btn-secondary meeting-back-btn"
            onClick={() => {
              setStep('select');
              setSuggestions(null);
            }}
          >
            ← Aktiviteleri Değiştir
          </button>
        </>
      )}
    </div>
  );
}
