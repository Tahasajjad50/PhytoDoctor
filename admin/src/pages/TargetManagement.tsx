import React, { useEffect, useState } from 'react';
import { Target, Users, Calendar, Plus, AlertCircle, CheckCircle2 } from 'lucide-react';
import { Header } from '../components/Header';
import { BatchTargetModal } from '../components/BatchTargetModal';
import { api } from '../services/api';
import { EmployeeTarget, User } from '../types';

export const TargetManagement: React.FC = () => {
  const [targets, setTargets] = useState<EmployeeTarget[]>([]);
  const [employees, setEmployees] = useState<User[]>([]);
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false);

  // Single target state
  const [selectedEmpId, setSelectedEmpId] = useState('');
  const [singleCount, setSingleCount] = useState(10);
  const [singleStart, setSingleStart] = useState(new Date().toISOString().split('T')[0]);
  const [singleEnd, setSingleEnd] = useState('');
  const [isSubmittingSingle, setIsSubmittingSingle] = useState(false);
  const [singleSuccess, setSingleSuccess] = useState<string | null>(null);

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setError(null);
      const [targetsData, usersData] = await Promise.all([
        api.getTargets(),
        api.getUsers({ role: 'EMPLOYEE' }),
      ]);
      setTargets(targetsData);
      setEmployees(usersData.items);
      if (usersData.items.length > 0 && !selectedEmpId) {
        setSelectedEmpId(usersData.items[0].id);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load targets');
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

  const handleSingleTargetSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedEmpId || singleCount < 1) return;

    setIsSubmittingSingle(true);
    setSingleSuccess(null);
    setError(null);
    try {
      await api.createTarget({
        employee_id: selectedEmpId,
        target_count: singleCount,
        period_type: 'DAILY',
        start_date: singleStart,
        end_date: singleEnd || null,
      });
      setSingleSuccess('Target successfully assigned and historical record preserved.');
      loadData();
      setTimeout(() => setSingleSuccess(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to create target');
    } finally {
      setIsSubmittingSingle(false);
    }
  };

  const getEmployeeName = (id: string) => {
    const emp = employees.find((e) => e.id === id);
    return emp ? `${emp.full_name} (${emp.username})` : id.substring(0, 8);
  };

  return (
    <div>
      <Header
        title="Field Visit Target Management"
        subtitle="Configure daily quota quotas and effective date windows across the field workforce"
        onRefresh={handleRefresh}
        isRefreshing={isRefreshing}
        extraActions={
          <button
            type="button"
            onClick={() => setIsBatchModalOpen(true)}
            className="btn btn-primary btn-sm"
          >
            <Users size={15} />
            <span>Batch Assign Targets</span>
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

        <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: 24 }}>
          {/* Left Column: Quick Single Target Assignment Card */}
          <div className="card">
            <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Target size={18} color="var(--botanical-primary)" />
              Individual Target Form
            </h2>
            <p style={{ fontSize: 12.5, color: 'var(--text-muted)', marginBottom: 16 }}>
              Assign or update daily visit goals with date-bound validity.
            </p>

            {singleSuccess && (
              <div
                style={{
                  padding: '10px 12px',
                  backgroundColor: 'var(--crop-green-light)',
                  border: '1px solid var(--crop-green-border)',
                  borderRadius: 'var(--radius-sm)',
                  color: 'var(--crop-green)',
                  fontSize: 12.5,
                  marginBottom: 14,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                <CheckCircle2 size={15} />
                <span>{singleSuccess}</span>
              </div>
            )}

            <form onSubmit={handleSingleTargetSubmit}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                    Field Agronomist
                  </label>
                  <select
                    className="input-control"
                    style={{ width: '100%' }}
                    value={selectedEmpId}
                    onChange={(e) => setSelectedEmpId(e.target.value)}
                    required
                  >
                    {employees.map((e) => (
                      <option key={e.id} value={e.id}>
                        {e.full_name} ({e.username})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                    Daily Target Visit Quota
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="100"
                    className="input-control"
                    style={{ width: '100%' }}
                    value={singleCount}
                    onChange={(e) => setSingleCount(parseInt(e.target.value) || 1)}
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                    Start Date
                  </label>
                  <input
                    type="date"
                    className="input-control"
                    style={{ width: '100%' }}
                    value={singleStart}
                    onChange={(e) => setSingleStart(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                    End Date (Optional)
                  </label>
                  <input
                    type="date"
                    className="input-control"
                    style={{ width: '100%' }}
                    value={singleEnd}
                    onChange={(e) => setSingleEnd(e.target.value)}
                  />
                </div>

                <button
                  type="submit"
                  disabled={isSubmittingSingle || !selectedEmpId}
                  className="btn btn-primary"
                  style={{ width: '100%', marginTop: 8 }}
                >
                  <Plus size={16} />
                  <span>{isSubmittingSingle ? 'Saving Target...' : 'Assign Target'}</span>
                </button>
              </div>
            </form>
          </div>

          {/* Right Column: Historical & Active Target Roster */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h2 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-main)' }}>
                  Active & Historical Targets Record
                </h2>
                <p style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>
                  Preserved historical audit logs ensuring past performance metrics remain accurate
                </p>
              </div>

              <span className="badge badge-verified">
                {targets.filter((t) => t.is_active).length} Active Target Quotas
              </span>
            </div>

            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Employee Name</th>
                    <th>Target Quota</th>
                    <th>Period</th>
                    <th>Effective Start</th>
                    <th>Effective End</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr>
                      <td colSpan={6} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                        Loading target history...
                      </td>
                    </tr>
                  ) : targets.length === 0 ? (
                    <tr>
                      <td colSpan={6} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                        No target quotas have been created yet.
                      </td>
                    </tr>
                  ) : (
                    targets.map((target) => (
                      <tr key={target.id}>
                        <td>
                          <strong>{getEmployeeName(target.employee_id)}</strong>
                        </td>
                        <td>
                          <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--botanical-dark)' }}>
                            {target.target_count} visits/day
                          </span>
                        </td>
                        <td>
                          <span className="badge badge-flagged">{target.period_type}</span>
                        </td>
                        <td style={{ fontSize: 13 }}>
                          {target.start_date}
                        </td>
                        <td style={{ fontSize: 13 }}>
                          {target.end_date ? target.end_date : <span style={{ color: 'var(--crop-green)' }}>Ongoing</span>}
                        </td>
                        <td>
                          <span className={`badge ${target.is_active ? 'badge-active' : 'badge-inactive'}`}>
                            {target.is_active ? 'Active' : 'Archived'}
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <BatchTargetModal
        isOpen={isBatchModalOpen}
        onClose={() => setIsBatchModalOpen(false)}
        employees={employees}
        onTargetsAssigned={() => loadData()}
      />
    </div>
  );
};
