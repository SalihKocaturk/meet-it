import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';
import {
  PERSONALITY_LABELS,
  PERSONALITY_EMOJIS,
  PERSONALITY_COLORS,
} from '../data/questions';
import { PersonalityType } from '../types';

export default function EditProfile() {
  const { currentUser, updateProfile, logout } = useApp();
  const navigate = useNavigate();
  const modalRef = useRef<HTMLDivElement>(null);

  const [name, setName] = useState('');
  const [bio, setBio] = useState('');
  const [age, setAge] = useState('');
  const [saved, setSaved] = useState(false);
  const [showLogoutModal, setShowLogoutModal] = useState(false);
  const [showInviteCodeModal, setShowInviteCodeModal] = useState(false);
  const [error, setError] = useState('');

  // Initialize form from currentUser
  useEffect(() => {
    if (currentUser) {
      setName(currentUser.name);
      setBio(currentUser.bio || '');
      setAge(currentUser.age?.toString() || '');
    }
  }, [currentUser]);

  // Close modal on outside click
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (modalRef.current && !modalRef.current.contains(e.target as Node)) {
        setShowLogoutModal(false);
        setShowInviteCodeModal(false);
      }
    }
    if (showLogoutModal || showInviteCodeModal) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showLogoutModal, showInviteCodeModal]);

  // Close modal on Escape key
  useEffect(() => {
    function handleEsc(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        setShowLogoutModal(false);
        setShowInviteCodeModal(false);
      }
    }
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, []);

  if (!currentUser) {
    navigate('/login');
    return null;
  }

  const pt = currentUser.personalityType as PersonalityType | undefined;

  function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setError('');

    if (!name.trim()) {
      setError('İsim boş bırakılamaz.');
      return;
    }
    if (age && (isNaN(Number(age)) || Number(age) < 13 || Number(age) > 120)) {
      setError('Geçerli bir yaş gir.');
      return;
    }

    updateProfile(currentUser.id, {
      name: name.trim(),
      bio: bio.trim(),
      age: age ? Number(age) : undefined,
    });
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  function handleLogout() {
    setShowLogoutModal(false);
    logout();
    navigate('/login');
  }

  return (
    <div className="page-container">
      <div className="profile-header">
        <button className="back-btn" onClick={() => navigate('/')}>
          ← Geri
        </button>
        <h1 className="page-title">Profil</h1>
      </div>

      {/* Avatar */}
      <div className="profile-avatar-section">
        <div
          className="profile-avatar-big"
          style={{ background: pt ? PERSONALITY_COLORS[pt] + '33' : '#e5e7eb' }}
        >
          <span className="profile-avatar-text">{currentUser.avatar}</span>
          {pt && (
            <span className="profile-personality-badge">{PERSONALITY_EMOJIS[pt]}</span>
          )}
        </div>
        {pt && (
          <div
            className="profile-personality-pill"
            style={{ background: PERSONALITY_COLORS[pt] + '22', color: PERSONALITY_COLORS[pt] }}
          >
            {PERSONALITY_EMOJIS[pt]} {PERSONALITY_LABELS[pt]}
          </div>
        )}
      </div>

      {/* Edit form */}
      <form className="profile-form" onSubmit={handleSave}>
        <div className="form-group">
          <label htmlFor="name">Ad Soyad</label>
          <input
            id="name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Adınız"
            maxLength={50}
          />
        </div>
        <div className="form-group">
          <label htmlFor="bio">Biyografi</label>
          <textarea
            id="bio"
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            placeholder="Kendinizden bahsedin..."
            rows={3}
            maxLength={150}
          />
          <span className="char-count">{bio.length}/150</span>
        </div>
        <div className="form-group">
          <label htmlFor="age">Yaş</label>
          <input
            id="age"
            type="number"
            value={age}
            onChange={(e) => setAge(e.target.value)}
            placeholder="Yaşınız"
            min={13}
            max={120}
          />
        </div>

        {error && <div className="form-error">{error}</div>}

        <button type="submit" className={`btn-primary ${saved ? 'btn-saved' : ''}`}>
          {saved ? '✅ Kaydedildi!' : 'Değişiklikleri Kaydet'}
        </button>
      </form>

      {/* Info section */}
      <div className="profile-info-section">
        <div className="profile-info-row">
          <span className="profile-info-label">E-posta</span>
          <span className="profile-info-value">{currentUser.email}</span>
        </div>
        <div className="profile-info-row">
          <span className="profile-info-label">Davet Kodu</span>
          <button
            className="invite-code-btn"
            onClick={() => setShowInviteCodeModal(true)}
            type="button"
          >
            {currentUser.inviteCode} →
          </button>
        </div>
      </div>

      {/* Quiz section */}
      <div className="profile-quiz-section">
        <h3>Kişilik Testi</h3>
        {pt ? (
          <div className="profile-quiz-result">
            <span>{PERSONALITY_EMOJIS[pt]}</span>
            <div>
              <div style={{ color: PERSONALITY_COLORS[pt], fontWeight: 600 }}>
                {PERSONALITY_LABELS[pt]}
              </div>
              <div className="profile-quiz-retake" onClick={() => navigate('/quiz')}>
                Tekrar al →
              </div>
            </div>
          </div>
        ) : (
          <button className="btn-outline" onClick={() => navigate('/quiz')}>
            🧠 Testi Tamamla
          </button>
        )}
      </div>

      {/* Logout */}
      <button
        className="btn-danger"
        onClick={() => setShowLogoutModal(true)}
        type="button"
      >
        Çıkış Yap
      </button>

      {/* ── LOGOUT CONFIRM MODAL ── */}
      {showLogoutModal && (
        <div className="modal-overlay">
          <div className="modal-card modal-confirm" ref={modalRef}>
            <div className="modal-header">
              <h2>Çıkış Yap</h2>
              <button
                className="modal-close"
                onClick={() => setShowLogoutModal(false)}
                type="button"
              >
                ✕
              </button>
            </div>
            <div className="modal-body">
              <p>Hesabından çıkış yapmak istediğine emin misin?</p>
              <div className="modal-actions">
                <button
                  className="btn-secondary"
                  onClick={() => setShowLogoutModal(false)}
                  type="button"
                >
                  İptal
                </button>
                <button
                  className="btn-danger"
                  onClick={handleLogout}
                  type="button"
                >
                  Çıkış Yap
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── INVITE CODE MODAL ── */}
      {showInviteCodeModal && (
        <div className="modal-overlay">
          <div className="modal-card" ref={modalRef}>
            <div className="modal-header">
              <h2>Davet Kodun</h2>
              <button
                className="modal-close"
                onClick={() => setShowInviteCodeModal(false)}
                type="button"
              >
                ✕
              </button>
            </div>
            <div className="modal-body">
              <div className="invite-code-display">{currentUser.inviteCode}</div>
              <p>Arkadaşlarına bu kodu ver, seni arkadaş listelerine ekleyebilirler.</p>
              <button
                className="btn-primary"
                onClick={() => {
                  navigator.clipboard.writeText(currentUser.inviteCode).catch(() => {});
                  setShowInviteCodeModal(false);
                }}
                type="button"
              >
                📋 Kodu Kopyala
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
