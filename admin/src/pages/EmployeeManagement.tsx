import React, { useEffect, useState } from 'react';
import {
  UserPlus,
  Search,
  KeyRound,
  Shield,
  UserCheck,
  UserX,
  AlertCircle,
  ShieldCheck,
} from 'lucide-react';
import { Header } from '../components/Header';
import { CreateEmployeeModal } from '../components/CreateEmployeeModal';
import { ResetPasswordModal } from '../components/ResetPasswordModal';
import { api } from '../services/api';
import { User, UserRole } from '../types';
import { useAuth } from '../context/AuthContext';

export const EmployeeManagement: React.FC = () => {
  const { isOwner } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState<string>('ALL');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [resetUser, setResetUser] = useState<User | null>(null);

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setError(null);
      const res = await api.getUsers();
      setUsers(res.items);
    } catch (err: any) {
      setError(err.message || 'Failed to load employee list');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadData();
  };

  const handleToggleStatus = async (user: User) => {
    try {
      const updated = await api.updateUser(user.id, { is_active: !user.is_active });
      setUsers((prev) => prev.map((u) => (u.id === updated.id ? updated : u)));
    } catch (err: any) {
      setError(err.message || 'Failed to update user status');
    }
  };

  const handleEmployeeCreated = (newUser: User) => {
    setUsers((prev) => [newUser, ...prev]);
  };

  const managers = users.filter((u) => u.role === 'MANAGER' || u.role === 'OWNER');

  // Filter local records
  const filteredUsers = users.filter((u) => {
    const matchesSearch =
      u.full_name.toLowerCase().includes(searchQuery.toLowerCase().trim()) ||
      u.username.toLowerCase().includes(searchQuery.toLowerCase().trim()) ||
      u.email.toLowerCase().includes(searchQuery.toLowerCase().trim());

    const matchesRole = roleFilter === 'ALL' || u.role === roleFilter;
    const matchesStatus =
      statusFilter === 'ALL' ||
      (statusFilter === 'ACTIVE' && u.is_active) ||
      (statusFilter === 'INACTIVE' && !u.is_active);

    return matchesSearch && matchesRole && matchesStatus;
  });

  return (
    <div>
      <Header
        title="Field Employee & Staff Roster"
        subtitle="Manage agronomist field accounts, manager assignments, and security credentials"
        onRefresh={handleRefresh}
        isRefreshing={isRefreshing}
        extraActions={
          <button
            type="button"
            onClick={() => setIsCreateModalOpen(true)}
            className="btn btn-primary btn-sm"
          >
            <UserPlus size={15} />
            <span>Create Account</span>
          </button>
        }
      />

      <div className="content-body">
        {error && (
          <div
            style={{
              padding: '12px 16px',
              backgroundColor: 'var(--alert-crimson-light)',
              border: '1px solid var(--alert-crimson-border)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--alert-crimson)',
              marginBottom: 20,
              fontSize: 13,
              display: 'flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        {/* Filters */}
        <div className="toolbar-filter">
          <div className="filter-group">
            <div style={{ position: 'relative' }}>
              <Search
                size={15}
                style={{ position: 'absolute', left: 10, top: 9, color: 'var(--text-muted)' }}
              />
              <input
                type="text"
                placeholder="Search by name, username, or email..."
                className="input-control"
                style={{ paddingLeft: 32, width: 260 }}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            <select
              className="input-control"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
            >
              <option value="ALL">All System Roles</option>
              <option value="EMPLOYEE">Field Agronomists Only</option>
              <option value="MANAGER">Regional Managers</option>
              <option value="OWNER">Executive Owners</option>
            </select>

            <select
              className="input-control"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="ALL">All Account Statuses</option>
              <option value="ACTIVE">Active Only</option>
              <option value="INACTIVE">Deactivated Only</option>
            </select>
          </div>

          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
            Showing <strong>{filteredUsers.length}</strong> staff accounts
          </div>
        </div>

        {/* Table */}
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Employee / Staff Name</th>
                <th>Username</th>
                <th>Email Address</th>
                <th>Role</th>
                <th>Regional Manager</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Security Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    Loading employee roster...
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    No staff records match your search criteria.
                  </td>
                </tr>
              ) : (
                filteredUsers.map((u) => {
                  const manager = users.find((m) => m.id === u.manager_id);
                  return (
                    <tr key={u.id}>
                      <td>
                        <div style={{ fontWeight: 600 }}>{u.full_name}</div>
                      </td>
                      <td style={{ fontFamily: 'monospace', fontSize: 13 }}>
                        {u.username}
                      </td>
                      <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                        {u.email}
                      </td>
                      <td>
                        <span
                          className={`badge ${
                            u.role === 'OWNER'
                              ? 'badge-verified'
                              : u.role === 'MANAGER'
                              ? 'badge-flagged'
                              : 'badge-pending'
                          }`}
                        >
                          <Shield size={10} />
                          {u.role}
                        </span>
                      </td>
                      <td style={{ fontSize: 13 }}>
                        {manager ? manager.full_name : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                      </td>
                      <td>
                        <span className={`badge ${u.is_active ? 'badge-active' : 'badge-inactive'}`}>
                          {u.is_active ? 'Active' : 'Deactivated'}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                          <button
                            type="button"
                            onClick={() => setResetUser(u)}
                            className="btn btn-secondary btn-sm"
                            title="Reset Credentials"
                          >
                            <KeyRound size={13} />
                            <span>Reset</span>
                          </button>

                          {isOwner && (
                            <button
                              type="button"
                              onClick={() => handleToggleStatus(u)}
                              className={`btn btn-sm ${u.is_active ? 'btn-secondary' : 'btn-primary'}`}
                              title={u.is_active ? 'Deactivate Account' : 'Activate Account'}
                            >
                              {u.is_active ? <UserX size={13} color="var(--alert-crimson)" /> : <UserCheck size={13} />}
                              <span>{u.is_active ? 'Deactivate' : 'Activate'}</span>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modals */}
      <CreateEmployeeModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onEmployeeCreated={handleEmployeeCreated}
        managers={managers}
      />

      <ResetPasswordModal
        user={resetUser}
        onClose={() => setResetUser(null)}
        onSuccess={() => loadData()}
      />
    </div>
  );
};
