import { useNavigate, useLocation } from 'react-router-dom';
import { useApp } from '../store/AppContext';

export default function BottomNav() {
  const navigate = useNavigate();
  const location = useLocation();
  const { currentUser } = useApp();

  if (!currentUser) return null;

  const tabs = [
    { path: '/', emoji: '🏠', label: 'Ana Sayfa' },
    { path: '/friends', emoji: '👥', label: 'Arkadaşlar' },
    { path: '/quiz', emoji: '🧠', label: 'Test' },
    { path: '/profile', emoji: '👤', label: 'Profil' },
  ];

  function isActive(path: string) {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  }

  return (
    <nav className="bottom-nav">
      {tabs.map((tab) => (
        <button
          key={tab.path}
          className={`bottom-nav-item ${isActive(tab.path) ? 'bottom-nav-active' : ''}`}
          onClick={() => navigate(tab.path)}
        >
          <span className="bottom-nav-emoji">{tab.emoji}</span>
          <span className="bottom-nav-label">{tab.label}</span>
        </button>
      ))}
    </nav>
  );
}
