import React, { useState } from 'react';
import { Shield, Lock, User, AlertCircle, ArrowRight } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export const AdminLogin: React.FC = () => {
  const { login } = useAuth();
  const [usernameOrEmail, setUsernameOrEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!usernameOrEmail || !password) {
      setError('Please provide your admin username and password.');
      return;
    }

    setIsLoading(true);
    setError(null);
    try {
      await login(usernameOrEmail.trim(), password);
    } catch (err: any) {
      setError(err.message || 'Login failed. Please verify credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'var(--warm-offwhite)',
        padding: 20,
      }}
    >
      <div
        className="card"
        style={{
          width: '100%',
          maxWidth: 440,
          padding: 36,
          boxShadow: 'var(--shadow-lg)',
          border: '1px solid var(--sage-border)',
        }}
      >
        {/* Brand Banner */}
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <img
            src="/assets/phytodoctor_logo.png"
            alt="Phyto Doctor Logo"
            style={{
              maxHeight: 64,
              maxWidth: 240,
              objectFit: 'contain',
              marginBottom: 12,
            }}
            onError={(e) => {
              (e.target as HTMLImageElement).src = '/assets/phytodoctor_icon.png';
            }}
          />
          <h1 style={{ fontSize: 20, fontWeight: 700, color: 'var(--botanical-dark)', letterSpacing: -0.3 }}>
            Admin & Management Portal
          </h1>
          <p style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>
            Field Operations & Visit Verification System
          </p>
        </div>

        {error && (
          <div
            style={{
              padding: '12px 14px',
              backgroundColor: 'var(--alert-crimson-light)',
              border: '1px solid var(--alert-crimson-border)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--alert-crimson)',
              marginBottom: 20,
              fontSize: 13,
              display: 'flex',
              alignItems: 'flex-start',
              gap: 8,
            }}
          >
            <AlertCircle size={16} style={{ flexShrink: 0, marginTop: 2 }} />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, color: 'var(--text-main)', marginBottom: 6 }}>
                Admin Username or Email
              </label>
              <div style={{ position: 'relative' }}>
                <User
                  size={16}
                  style={{ position: 'absolute', left: 12, top: 11, color: 'var(--text-muted)' }}
                />
                <input
                  type="text"
                  className="input-control"
                  style={{ width: '100%', paddingLeft: 36 }}
                  placeholder="e.g. owner or manager.punjab"
                  value={usernameOrEmail}
                  onChange={(e) => setUsernameOrEmail(e.target.value)}
                  disabled={isLoading}
                  autoComplete="username"
                  required
                />
              </div>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, color: 'var(--text-main)', marginBottom: 6 }}>
                Secure Password
              </label>
              <div style={{ position: 'relative' }}>
                <Lock
                  size={16}
                  style={{ position: 'absolute', left: 12, top: 11, color: 'var(--text-muted)' }}
                />
                <input
                  type="password"
                  className="input-control"
                  style={{ width: '100%', paddingLeft: 36 }}
                  placeholder="••••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="current-password"
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="btn btn-primary"
              style={{ width: '100%', padding: '12px 16px', marginTop: 8 }}
            >
              <span>{isLoading ? 'Authenticating...' : 'Sign In to Operations Portal'}</span>
              <ArrowRight size={16} />
            </button>
          </div>
        </form>

        <div
          style={{
            marginTop: 28,
            paddingTop: 18,
            borderTop: '1px solid var(--sage-border)',
            textAlign: 'center',
            fontSize: 12,
            color: 'var(--text-muted)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 6,
          }}
        >
          <Shield size={14} color="var(--botanical-primary)" />
          <span>Restricted to Authorized Company Administrators & Regional Managers</span>
        </div>
      </div>
    </div>
  );
};
