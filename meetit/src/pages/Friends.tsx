import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';
import {
  PERSONALITY_LABELS,
  PERSONALITY_EMOJIS,
  PERSONALITY_COLORS,
} from '../data/questions';
import { PersonalityType } from '../types';

export default function Friends() {
  const { currentUser, getFriends, addFriendByCode, generateInviteLink } = useApp();
  const navigate = useNavigate();

  const [showInviteModal, setShowInviteModal] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [inputCode, setInputCode] = useState('');
  const [addResult, setAddResult] = useState<'success' | 'error' | 'already' | null>(null);
  const [copiedLink, setCopiedLink] = useState(false);

  if (!currentUser) {
    navigate('/login');
    return null;
  }

  const myFriends = getFriends(currentUser.id);
  const inviteLink = generateInviteLink(currentUser.id);

  function handleCopyLink() {
    navigator.clipboard.writeText(inviteLink).catch(() => {});
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  }

  function handleCopyCode() {
    navigator.clipboard.writeText(currentUser.inviteCode).catch(() => {});
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  }

  function handleAddFriend() {
    const success = addFriendByCode(inputCode);
    if (success) {
      setAddResult('success');
      setInputCode('');
      setTimeout(() => {
        setAddResult(null);
        setShowAddModal(false);
      }, 1500);
    } else {
      setAddResult('error');
    }
  }

  function handleMeet(friendId: string) {
    navigate(`/meeting/${friendId}`);
  }

  return (
    <div className="page-container">
      {/* Header with invite button top-left */}
      <div className="friends-header">
        <button className="invite-header-btn" onClick={() => setShowInviteModal(true)}>
          <span className="invite-icon">🔗</span>
          Arkadaşlarını Davet Et
        </button>
        <h1 className="page-title">Arkadaşlar</h1>
        <button className="icon-btn" onClick={() => setShowAddModal(true)} title="Kod ile ekle">
          ➕
        </button>
      </div>

      {/* Friends list */}
      {myFriends.length === 0 ? (
        <div className="empty-state">
          <div className="empty-emoji">👋</div>
          <p>Henüz arkadaşın yok.</p>
          <p className="empty-sub">
            Davet bağlantını paylaş veya bir arkadaşının kodunu gir.
          </p>
          <button className="btn-primary" onClick={() => setShowInviteModal(true)}>
            🔗 Davet Bağlantısı Oluştur
          </button>
        </div>
      ) : (
        <div className="friends-list">
          {myFriends.map((friend) => {
            const pt = friend.personalityType as PersonalityType | undefined;
            return (
              <div key={friend.id} className="friend-card">
                <div
                  className="friend-avatar"
                  style={{ background: pt ? PERSONALITY_COLORS[pt] + '22' : '#f3f4f6' }}
                >
                  <span className="friend-avatar-text">{friend.avatar}</span>
                  {pt && (
                    <span className="friend-personality-badge">{PERSONALITY_EMOJIS[pt]}</span>
                  )}
                </div>
                <div className="friend-info">
                  <div className="friend-name">{friend.name}</div>
                  {pt ? (
                    <div
                      className="friend-personality"
                      style={{ color: PERSONALITY_COLORS[pt] }}
                    >
                      {PERSONALITY_EMOJIS[pt]} {PERSONALITY_LABELS[pt]}
                    </div>
                  ) : (
                    <div className="friend-personality-pending">Henüz test yapmadı</div>
                  )}
                  {friend.bio && <div className="friend-bio">{friend.bio}</div>}
                </div>
                <button
                  className="meet-btn"
                  onClick={() => handleMeet(friend.id)}
                  title="Buluşma Planla"
                >
                  📍 Buluş
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* ── INVITE MODAL ── */}
      {showInviteModal && (
        <div className="modal-overlay" onClick={() => setShowInviteModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Arkadaşlarını Davet Et</h2>
              <button className="modal-close" onClick={() => setShowInviteModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="invite-illustration">🔗</div>
              <p className="invite-explain">
                Aşağıdaki bağlantıyı veya kodu arkadaşlarınla paylaş. Kod girerek seni arkadaş
                listesine ekleyebilirler.
              </p>

              <div className="invite-code-box">
                <span className="invite-code-label">Davet Kodun</span>
                <div className="invite-code-value">{currentUser.inviteCode}</div>
                <button className="btn-copy" onClick={handleCopyCode}>
                  {copiedLink ? '✅ Kopyalandı!' : '📋 Kodu Kopyala'}
                </button>
              </div>

              <div className="invite-divider">veya</div>

              <button className="btn-primary invite-link-btn" onClick={handleCopyLink}>
                {copiedLink ? '✅ Bağlantı Kopyalandı!' : '🔗 Davet Bağlantısını Kopyala'}
              </button>

              <p className="invite-note">
                Arkadaşın "➕ Kod ile Ekle" butonuna basarak bu kodu girebilir.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* ── ADD FRIEND MODAL ── */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Kod ile Arkadaş Ekle</h2>
              <button className="modal-close" onClick={() => setShowAddModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <p className="invite-explain">
                Arkadaşının davet kodunu gir, hemen ekleyelim!
              </p>
              <input
                className="code-input"
                type="text"
                placeholder="Örn: ZEYN-RT83"
                value={inputCode}
                onChange={(e) => {
                  setInputCode(e.target.value.toUpperCase());
                  setAddResult(null);
                }}
                maxLength={12}
              />
              {addResult === 'success' && (
                <div className="add-result success">✅ Arkadaş eklendi!</div>
              )}
              {addResult === 'error' && (
                <div className="add-result error">❌ Geçersiz kod veya zaten arkadaşsınız.</div>
              )}
              <button
                className="btn-primary"
                onClick={handleAddFriend}
                disabled={inputCode.trim().length < 4}
              >
                Arkadaş Ekle
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
