import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../store/AppContext';

export default function Login() {
  const { login } = useApp();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);

    setTimeout(() => {
      const user = login(email, password);
      setLoading(false);
      if (user) {
        navigate('/');
      } else {
        setError('E-posta veya şifre yanlış. Dene: ayse@example.com / 123456');
      }
    }, 600);
  }

  function fillDemo(email: string) {
    setEmail(email);
    setPassword('123456');
    setError('');
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <span className="logo-emoji">📍</span>
          <h1 className="logo-text">MeetIt</h1>
          <p className="logo-sub">Arkadaşlarınla mükemmel mekanı bul</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="email">E-posta</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="ornek@email.com"
              required
              autoComplete="email"
            />
          </div>
          <div className="form-group">
            <label htmlFor="password">Şifre</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••"
              required
              autoComplete="current-password"
            />
          </div>
          {error && <div className="login-error">{error}</div>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Giriş yapılıyor...' : 'Giriş Yap'}
          </button>
        </form>

        <div className="login-demo">
          <p className="demo-title">Demo Hesapları ile Dene:</p>
          <div className="demo-users">
            <button className="demo-user-btn" onClick={() => fillDemo('ayse@example.com')}>
              <span>AK</span> Ayşe Kaya
            </button>
            <button className="demo-user-btn" onClick={() => fillDemo('mehmet@example.com')}>
              <span>MD</span> Mehmet Demir
            </button>
            <button className="demo-user-btn" onClick={() => fillDemo('zeynep@example.com')}>
              <span>ZA</span> Zeynep Arslan
            </button>
          </div>
          <p className="demo-note">Tüm şifreler: 123456</p>
        </div>
      </div>
    </div>
  );
}
