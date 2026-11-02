import React, { useState } from 'react';
import { X, UserPlus } from 'lucide-react';
import { api } from '../services/api';
import { User, UserRole } from '../types';
import { useAuth } from '../context/AuthContext';

interface CreateEmployeeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onEmployeeCreated: (user: User) => void;
  managers: User[];
}

export const CreateEmployeeModal: React.FC<CreateEmployeeModalProps> = ({
  isOpen,
  onClose,
  onEmployeeCreated,
  managers,
}) => {
  const { isOwner } = useAuth();
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<UserRole>('EMPLOYEE');
  const [managerId, setManagerId] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!fullName || !username || !email || !password) {
      setError('All fields are required.');
      return;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      const newUser = await api.createUser({
        full_name: fullName.trim(),
        username: username.trim().toLowerCase(),
        email: email.trim().toLowerCase(),
        password,
        role,
        manager_id: role === 'EMPLOYEE' && managerId ? managerId : null,
      });
      onEmployeeCreated(newUser);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to create employee account');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Create New User Account</h2>
          <button onClick={onClose} className="btn btn-secondary btn-icon-only" type="button">
            <X size={18} />
          </button>
        </div>

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

        <form onSubmit={handleSubmit}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                Full Legal Name
              </label>
              <input
                type="text"
                className="input-control"
                style={{ width: '100%' }}
                placeholder="e.g. Tariq Mehmood"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                required
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                  Assigned Username
                </label>
                <input
                  type="text"
                  className="input-control"
                  style={{ width: '100%' }}
                  placeholder="e.g. emp.tariq"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                  Company Email
                </label>
                <input
                  type="email"
                  className="input-control"
                  style={{ width: '100%' }}
                  placeholder="tariq@phytodoctor.pk"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                Initial Secure Password
              </label>
              <input
                type="password"
                className="input-control"
                style={{ width: '100%' }}
                placeholder="Minimum 8 characters"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>

            {isOwner && (
              <div>
                <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                  System Role
                </label>
                <select
                  className="input-control"
                  style={{ width: '100%' }}
                  value={role}
                  onChange={(e) => setRole(e.target.value as UserRole)}
                >
                  <option value="EMPLOYEE">Field Agronomist / Employee</option>
                  <option value="MANAGER">Regional Field Manager</option>
                  <option value="OWNER">Executive Owner / Admin</option>
                </select>
              </div>
            )}

            {role === 'EMPLOYEE' && (
              <div>
                <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 4 }}>
                  Assign to Regional Manager
                </label>
                <select
                  className="input-control"
                  style={{ width: '100%' }}
                  value={managerId}
                  onChange={(e) => setManagerId(e.target.value)}
                >
                  <option value="">No Direct Manager (Executive Supervision)</option>
                  {managers.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.full_name} ({m.username})
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          <div className="modal-footer">
            <button type="button" onClick={onClose} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={isSubmitting} className="btn btn-primary">
              <UserPlus size={16} />
              <span>{isSubmitting ? 'Creating...' : 'Create Account'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
