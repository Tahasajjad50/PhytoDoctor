import React, { useEffect, useState } from 'react';
import {
  Users2,
  Trophy,
  CheckCircle2,
  Target,
  Percent,
  AlertCircle,
  TrendingUp,
} from 'lucide-react';
import { Header } from '../components/Header';
import { api } from '../services/api';
import { TeamComparison, User } from '../types';
import { useAuth } from '../context/AuthContext';

export const TeamPerformance: React.FC = () => {
  const { isOwner, user } = useAuth();
  const [managers, setManagers] = useState<User[]>([]);
  const [selectedManagerId, setSelectedManagerId] = useState<string>('');
  const [teamComparison, setTeamComparison] = useState<TeamComparison | null>(null);

  const [dateFrom, setDateFrom] = useState<string>('');
  const [dateTo, setDateTo] = useState<string>('');

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadInitial = async () => {
      try {
        if (isOwner) {
          const mgrData = await api.getUsers({ role: 'MANAGER' });
          setManagers(mgrData.items);
          if (mgrData.items.length > 0) {
            setSelectedManagerId(mgrData.items[0].id);
          }
        } else if (user) {
          setSelectedManagerId(user.id);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to load manager list');
      }
    };
    loadInitial();
  }, [isOwner, user]);

  const loadTeamData = async () => {
    if (!selectedManagerId && !isOwner) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await api.getTeamComparison({
        manager_id: selectedManagerId || undefined,
        date_from: dateFrom || undefined,
        date_to: dateTo || undefined,
      });
      setTeamComparison(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load team comparison');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadTeamData();
  }, [selectedManagerId, dateFrom, dateTo]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadTeamData();
  };

  return (
    <div>
      <Header
        title="Regional Team Performance & Leaderboard"
        subtitle="Ranked team completion metrics and supervisor comparative analytics"
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

        {/* Filter Toolbar */}
        <div className="toolbar-filter">
          <div className="filter-group">
            {isOwner && (
              <>
                <label style={{ fontSize: 13, fontWeight: 600 }}>Filter by Regional Team:</label>
                <select
                  className="input-control"
                  style={{ width: 240 }}
                  value={selectedManagerId}
                  onChange={(e) => setSelectedManagerId(e.target.value)}
                >
                  <option value="">Executive Organization (All Teams)</option>
                  {managers.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.full_name} ({m.username})
                    </option>
                  ))}
                </select>
              </>
            )}

            <label style={{ fontSize: 13, fontWeight: 600, marginLeft: 8 }}>Date Range:</label>
            <input
              type="date"
              className="input-control"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
            />
            <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>to</span>
            <input
              type="date"
              className="input-control"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
            />
          </div>

          <span className="badge badge-verified">
            {teamComparison?.members.length ?? 0} Agronomists Ranked
          </span>
        </div>

        {teamComparison && (
          <>
            {/* Team Summary KPIs */}
            <div className="grid-kpis">
              <div className="kpi-card">
                <div className="kpi-label">Team Size</div>
                <div className="kpi-value">{teamComparison.team_size}</div>
                <div className="kpi-subtext">
                  <Users2 size={13} color="var(--botanical-primary)" />
                  <span>Assigned agronomists</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-label">Combined Target Quota</div>
                <div className="kpi-value">{teamComparison.team_target_total}</div>
                <div className="kpi-subtext">
                  <Target size={13} color="var(--earth-amber)" />
                  <span>Total visit goal</span>
                </div>
              </div>

              <div className="kpi-card verified">
                <div className="kpi-label">Verified Completed</div>
                <div className="kpi-value" style={{ color: 'var(--crop-green)' }}>
                  {teamComparison.team_verified_total}
                </div>
                <div className="kpi-subtext">
                  <CheckCircle2 size={13} color="var(--crop-green)" />
                  <span>Audited evidence count</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-label">Team Average Attainment</div>
                <div className="kpi-value">{teamComparison.team_average_completion}%</div>
                <div className="kpi-subtext">
                  <Percent size={13} color="var(--botanical-primary)" />
                  <span>Collective completion rate</span>
                </div>
              </div>
            </div>

            {/* Ranked Leaderboard Table */}
            <div className="card" style={{ marginTop: 20 }}>
              <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
                <Trophy size={18} color="var(--earth-amber)" />
                Team Performance Leaderboard (Ranked by Attainment)
              </h3>

              <div className="table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th style={{ width: 60 }}>Rank</th>
                      <th>Agronomist Name</th>
                      <th>Target Quota</th>
                      <th>Verified Completed</th>
                      <th>Remaining</th>
                      <th style={{ width: 220 }}>Attainment Rate</th>
                      <th>Rejected</th>
                      <th>Flagged</th>
                    </tr>
                  </thead>
                  <tbody>
                    {teamComparison.members.length === 0 ? (
                      <tr>
                        <td colSpan={8} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                          No team member data available for this range.
                        </td>
                      </tr>
                    ) : (
                      teamComparison.members.map((member, idx) => (
                        <tr key={member.employee_id}>
                          <td>
                            <span
                              style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                width: 28,
                                height: 28,
                                borderRadius: '50%',
                                backgroundColor:
                                  idx === 0
                                    ? '#FFD700'
                                    : idx === 1
                                    ? '#E0E0E0'
                                    : idx === 2
                                    ? '#CD7F32'
                                    : 'var(--sage-light)',
                                fontWeight: 700,
                                fontSize: 13,
                                color: idx < 3 ? '#222' : 'var(--text-main)',
                              }}
                            >
                              {idx + 1}
                            </span>
                          </td>
                          <td>
                            <strong>{member.employee_name}</strong>
                            <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{member.employee_email}</div>
                          </td>
                          <td>
                            <span style={{ fontWeight: 600 }}>{member.target_visits}</span>
                          </td>
                          <td>
                            <strong style={{ color: 'var(--crop-green)' }}>{member.verified_visits}</strong>
                          </td>
                          <td>{member.remaining_visits}</td>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <div style={{ flex: 1 }} className="progress-container">
                                <div
                                  className="progress-bar"
                                  style={{
                                    width: `${Math.min(member.completion_percentage, 100)}%`,
                                    backgroundColor:
                                      member.completion_percentage >= 100
                                        ? 'var(--crop-green)'
                                        : 'var(--botanical-primary)',
                                  }}
                                />
                              </div>
                              <span style={{ fontSize: 12.5, fontWeight: 700, width: 44, textAlign: 'right' }}>
                                {member.completion_percentage}%
                              </span>
                            </div>
                          </td>
                          <td>
                            {member.rejected_visits > 0 ? (
                              <span className="badge badge-rejected">{member.rejected_visits}</span>
                            ) : (
                              <span style={{ color: 'var(--text-muted)' }}>0</span>
                            )}
                          </td>
                          <td>
                            {member.flagged_visits > 0 ? (
                              <span className="badge badge-flagged">{member.flagged_visits}</span>
                            ) : (
                              <span style={{ color: 'var(--text-muted)' }}>0</span>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
