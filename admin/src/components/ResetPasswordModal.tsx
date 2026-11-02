import React, { useState } from 'react';
import { X, KeyRound, Check } from 'lucide-react';
import { api } from '../services/api';
import { User } from '../types';

interface ResetPasswordModalProps {
  user: User | null;
  onClose: () => void;
  onSuccess: () => void;
}

export const ResetPasswordModal: React.FC<ResetPasswordModalProps> = ({
  user,
  onClose,
  onSuccess,
}) => {
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  if (!user) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters long.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      await api.resetPassword(user.id, newPassword);
      setSuccessMessage(`Password successfully reset for ${user.full_name}.`);
      setTimeout(() => {
        onSuccess();
        onClose();
      }, 1500);
    } catch (err: any) {
      setError(err.message || 'Failed to reset password');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Reset Employee Password</h2>
          <button onClick={onClose} className="btn btn-secondary btn-icon-only" type="button">
            <X size={18} />
          </button>
        </div>

        <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 16 }}>
          Resetting credentials for: <strong>{user.full_name}</strong> (<code>{user.username}</code>)
        </p>

        {error && (
          <div
            style={{
              padding: '10px 14px',
              backgroundColor: 'var(--alert-crimson-light)',
              border: '1px solid var(--alert-crimson-border)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--alert-crimson)',
              marginBottom: 16,
              fontSize: 13,
            }}
          >
            {error}
          </div>
        )}

        {successMessage && (
          <div
            style={{
              padding: '10px 14px',
              backgroundColor: 'var(--crop-green-light)',
              border: '1px solid var(--crop-green-border)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--crop-green)',
              marginBottom: 16,
              fontSize: 13,
              display: 'flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <Check size={16} />
            <span>{successMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                New Password
              </label>
              <input
                type="password"
                className="input-control"
                style={{ width: '100%' }}
                placeholder="Enter new secure password (min 8 characters)"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                Confirm New Password
              </label>
              <input
                type="password"
                className="input-control"
                style={{ width: '100%' }}
                placeholder="Re-type new password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
              />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" onClick={onClose} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={isSubmitting} className="btn btn-primary">
              <KeyRound size={16} />
              <span>{isSubmitting ? 'Resetting...' : 'Reset Password'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
