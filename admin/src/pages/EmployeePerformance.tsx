import React, { useEffect, useState } from 'react';
import {
  BarChart3,
  Calendar,
  CheckCircle2,
  Clock,
  XCircle,
  AlertTriangle,
  TrendingUp,
  FileText,
  AlertCircle,
} from 'lucide-react';
import { Header } from '../components/Header';
import { api } from '../services/api';
import { PerformanceAnalytics, User } from '../types';

export const EmployeePerformance: React.FC = () => {
  const [employees, setEmployees] = useState<User[]>([]);
  const [selectedEmpId, setSelectedEmpId] = useState<string>('');
  const [period, setPeriod] = useState<'daily' | 'weekly' | 'monthly'>('daily');
  const [analytics, setAnalytics] = useState<PerformanceAnalytics | null>(null);

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadEmployees = async () => {
      try {
        const users = await api.getUsers({ role: 'EMPLOYEE' });
        setEmployees(users.items);
        if (users.items.length > 0) {
          setSelectedEmpId(users.items[0].id);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to load employee list');
      }
    };
    loadEmployees();
  }, []);

  const loadAnalytics = async () => {
    if (!selectedEmpId) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await api.getEmployeeAnalytics(selectedEmpId, period);
      setAnalytics(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load employee analytics');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadAnalytics();
  }, [selectedEmpId, period]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadAnalytics();
  };

  const selectedEmployee = employees.find((e) => e.id === selectedEmpId);

  return (
    <div>
      <Header
        title="Employee Performance & Visit Attainment"
        subtitle="Individual quota verification, daily/weekly/monthly completion rate, and audit histories"
        onRefresh={handleRefresh}
        isRefreshing={isRefreshing}
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

        {/* Top Controls: Employee Selector & Timeframe Tabs */}
        <div className="toolbar-filter">
          <div className="filter-group">
            <label style={{ fontSize: 13, fontWeight: 600 }}>Select Field Agronomist:</label>
            <select
              className="input-control"
              style={{ width: 260 }}
              value={selectedEmpId}
              onChange={(e) => setSelectedEmpId(e.target.value)}
            >
              {employees.map((emp) => (
                <option key={emp.id} value={emp.id}>
                  {emp.full_name} ({emp.username})
                </option>
              ))}
            </select>
          </div>

          <div style={{ display: 'flex', gap: 6 }}>
            {(['daily', 'weekly', 'monthly'] as const).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setPeriod(t)}
                className={`btn btn-sm ${period === t ? 'btn-primary' : 'btn-secondary'}`}
                style={{ textTransform: 'capitalize' }}
              >
                {t} View
              </button>
            ))}
          </div>
        </div>

        {analytics && (
          <>
            {/* KPI Metrics */}
            <div className="grid-kpis">
              <div className="kpi-card">
                <div className="kpi-label">Target Visits</div>
                <div className="kpi-value">{analytics.target_visits}</div>
                <div className="kpi-subtext">
                  <span>Assigned quota for {period}</span>
                </div>
              </div>

              <div className="kpi-card verified">
                <div className="kpi-label">Verified Completed</div>
                <div className="kpi-value" style={{ color: 'var(--crop-green)' }}>
                  {analytics.verified_visits}
                </div>
                <div className="kpi-subtext">
                  <CheckCircle2 size={13} color="var(--crop-green)" />
                  <span>Counted toward target</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-label">Remaining to Quota</div>
                <div className="kpi-value">
                  {analytics.remaining_visits}
                </div>
                <div className="kpi-subtext">
                  <span>Needed to satisfy target</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-label">Attainment Rate</div>
                <div className="kpi-value">{analytics.completion_percentage}%</div>
                <div style={{ marginTop: 4 }}>
                  <div className="progress-container">
                    <div
                      className="progress-bar"
                      style={{
                        width: `${Math.min(analytics.completion_percentage, 100)}%`,
                        backgroundColor: analytics.completion_percentage >= 100 ? 'var(--crop-green)' : 'var(--botanical-primary)',
                      }}
                    />
                  </div>
                </div>
              </div>

              <div className="kpi-card pending">
                <div className="kpi-label">Submitted / Pending</div>
                <div className="kpi-value" style={{ color: 'var(--earth-amber)' }}>
                  {analytics.pending_sync_count}
                </div>
                <div className="kpi-subtext">
                  <Clock size={13} color="var(--earth-amber)" />
                  <span>Awaiting verification</span>
                </div>
              </div>

              <div className="kpi-card flagged">
                <div className="kpi-label">Rejected Visits</div>
                <div className="kpi-value" style={{ color: 'var(--alert-crimson)' }}>
                  {analytics.rejected_visits}
                </div>
                <div className="kpi-subtext">
                  <XCircle size={13} color="var(--alert-crimson)" />
                  <span>Audit rejected</span>
                </div>
              </div>
            </div>

            {/* Day-by-Day Trend Chart & Audit Logs */}
            <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 24, marginTop: 20 }}>
              {/* Trend Chart */}
              <div className="card">
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <TrendingUp size={18} color="var(--botanical-primary)" />
                  Target vs. Verified Visits Trend
                </h3>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                  {analytics.trend.map((pt) => {
                    const maxVal = Math.max(pt.target, pt.submitted_visits, pt.verified_visits, 1);
                    const verifiedPct = (pt.verified_visits / maxVal) * 100;
                    const targetPct = (pt.target / maxVal) * 100;

                    return (
                      <div key={pt.date} style={{ fontSize: 13 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                          <span style={{ fontWeight: 600 }}>{pt.date}</span>
                          <span style={{ color: 'var(--text-muted)' }}>
                            Verified: <strong>{pt.verified_visits}</strong> / Target: <strong>{pt.target}</strong>
                          </span>
                        </div>
                        {/* Comparison double bar */}
                        <div style={{ height: 14, backgroundColor: 'var(--sage-border)', borderRadius: 4, overflow: 'hidden', position: 'relative' }}>
                          <div
                            style={{
                              position: 'absolute',
                              top: 0,
                              left: 0,
                              bottom: 0,
                              width: `${verifiedPct}%`,
                              backgroundColor: 'var(--crop-green)',
                              borderRadius: 4,
                            }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Supervisor Review Notes & Audit Reason List */}
              <div className="card">
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <FileText size={18} color="var(--botanical-primary)" />
                  Supervisor Review Decisions & Notes
                </h3>

                {analytics.review_reasons.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: 32, color: 'var(--text-muted)', fontSize: 13 }}>
                    No rejected or flagged review decisions on file for this period.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    {analytics.review_reasons.map((item, idx) => (
                      <div
                        key={idx}
                        style={{
                          padding: '12px 14px',
                          border: '1px solid var(--sage-border)',
                          borderRadius: 'var(--radius-sm)',
                          backgroundColor: item.status === 'REJECTED' ? 'var(--alert-crimson-light)' : 'var(--crop-green-light)',
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <strong style={{ fontSize: 13 }}>{item.client_name}</strong>
                          <span className={`badge ${item.status === 'REJECTED' ? 'badge-rejected' : 'badge-verified'}`}>
                            {item.status}
                          </span>
                        </div>
                        <div style={{ fontSize: 12.5, color: 'var(--text-main)', marginTop: 6 }}>
                          "{item.review_reason || 'No audit explanation provided'}"
                        </div>
                        {item.reviewed_at && (
                          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>
                            Reviewed on: {new Date(item.reviewed_at).toLocaleString()}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
