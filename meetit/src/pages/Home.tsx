import { useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';
import {
  PERSONALITY_LABELS,
  PERSONALITY_DESCRIPTIONS,
  PERSONALITY_EMOJIS,
  PERSONALITY_COLORS,
} from '../data/questions';
import { PersonalityType } from '../types';

export default function Home() {
  const { currentUser, getFriends } = useApp();
  const navigate = useNavigate();

  if (!currentUser) {
    navigate('/login');
    return null;
  }

  const friends = getFriends(currentUser.id);
  const pt = currentUser.personalityType as PersonalityType | undefined;

  return (
    <div className="page-container">
      <div className="home-hero">
        <div
          className="home-avatar"
          style={{ background: pt ? PERSONALITY_COLORS[pt] + '33' : '#e5e7eb' }}
        >
          <span className="home-avatar-text">{currentUser.avatar}</span>
          {pt && (
            <span className="home-personality-badge">{PERSONALITY_EMOJIS[pt]}</span>
          )}
        </div>
        <div className="home-greeting">
          <p className="home-hi">Merhaba,</p>
          <h1 className="home-name">{currentUser.name} 👋</h1>
        </div>
      </div>

      {/* Personality card */}
      {pt ? (
        <div
          className="personality-card"
          style={{ borderLeft: `4px solid ${PERSONALITY_COLORS[pt]}` }}
        >
          <div className="personality-card-header">
            <span style={{ fontSize: 28 }}>{PERSONALITY_EMOJIS[pt]}</span>
            <div>
              <div className="personality-type-label" style={{ color: PERSONALITY_COLORS[pt] }}>
                {PERSONALITY_LABELS[pt]}
              </div>
              <div className="personality-type-sub">Kişilik Tipin</div>
            </div>
          </div>
          <p className="personality-desc">{PERSONALITY_DESCRIPTIONS[pt]}</p>
          <button
            className="btn-outline"
            onClick={() => navigate('/quiz')}
            style={{ borderColor: PERSONALITY_COLORS[pt], color: PERSONALITY_COLORS[pt] }}
          >
            Testi Tekrar Al
          </button>
        </div>
      ) : (
        <div className="quiz-prompt-card">
          <div className="quiz-prompt-emoji">🧠</div>
          <h2>Kişilik Testini Tamamla!</h2>
          <p>
            8 soruluk kısa testi tamamla, kişiliğine en uygun buluşma mekanlarını bulalım.
          </p>
          <button className="btn-primary" onClick={() => navigate('/quiz')}>
            Teste Başla →
          </button>
        </div>
      )}

      {/* Quick stats */}
      <div className="home-stats">
        <div className="stat-card" onClick={() => navigate('/friends')}>
          <div className="stat-num">{friends.length}</div>
          <div className="stat-label">Arkadaş</div>
        </div>
        <div className="stat-card" onClick={() => navigate('/friends')}>
          <div className="stat-num">
            {friends.filter((f) => f.personalityType).length}
          </div>
          <div className="stat-label">Test Yaptı</div>
        </div>
        <div className="stat-card" onClick={() => navigate('/quiz')}>
          <div className="stat-num">{pt ? '✓' : '?'}</div>
          <div className="stat-label">Testim</div>
        </div>
      </div>

      {/* Friends preview */}
      {friends.length > 0 && (
        <div className="home-section">
          <div className="home-section-header">
            <h2>Arkadaşların</h2>
            <button className="see-all-btn" onClick={() => navigate('/friends')}>
              Tümünü Gör →
            </button>
          </div>
          <div className="friends-preview">
            {friends.slice(0, 3).map((friend) => {
              const fp = friend.personalityType as PersonalityType | undefined;
              return (
                <div key={friend.id} className="friend-preview-card">
                  <div
                    className="friend-preview-avatar"
                    style={{ background: fp ? PERSONALITY_COLORS[fp] + '33' : '#f3f4f6' }}
                  >
                    {friend.avatar}
                    {fp && (
                      <span className="friend-preview-badge">{PERSONALITY_EMOJIS[fp]}</span>
                    )}
                  </div>
                  <div className="friend-preview-name">{friend.name.split(' ')[0]}</div>
                  <button
                    className="meet-btn-sm"
                    onClick={() => navigate(`/meeting/${friend.id}`)}
                  >
                    📍 Buluş
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* CTA if no friends */}
      {friends.length === 0 && (
        <div className="home-cta">
          <button className="btn-primary" onClick={() => navigate('/friends')}>
            🤝 Arkadaş Ekle
          </button>
        </div>
      )}
    </div>
  );
}
