import React, { useEffect, useState } from 'react';
import {
  Users,
  Target,
  CheckCircle2,
  Clock,
  ShieldAlert,
  ArrowUpRight,
  TrendingUp,
  Eye,
  AlertCircle,
} from 'lucide-react';
import { Header } from '../components/Header';
import { VisitDetailModal } from '../components/VisitDetailModal';
import { api } from '../services/api';
import { FieldVisit } from '../types';
import { NavigationTab } from '../components/Sidebar';

interface OverviewDashboardProps {
  onNavigate: (tab: NavigationTab) => void;
}

export const OverviewDashboard: React.FC<OverviewDashboardProps> = ({ onNavigate }) => {
  const [overview, setOverview] = useState<{
    date: string;
    active_employees: number;
    today_target_sum: number;
    today_verified_visits: number;
    today_submitted_visits: number;
    pending_review_count: number;
    flagged_visits_count: number;
    today_completion_rate: number;
  } | null>(null);

  const [recentVisits, setRecentVisits] = useState<FieldVisit[]>([]);
  const [selectedVisit, setSelectedVisit] = useState<FieldVisit | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setError(null);
      const [overviewData, visitsData] = await Promise.all([
        api.getCompanyOverview(),
        api.getVisits({ limit: 6 }),
      ]);
      setOverview(overviewData);
      setRecentVisits(visitsData.items);
    } catch (err: any) {
      setError(err.message || 'Failed to load overview data');
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

  const handleVisitUpdated = (updated: FieldVisit) => {
    setRecentVisits((prev) =>
      prev.map((v) => (v.id === updated.id ? updated : v))
    );
    loadData();
  };

  return (
    <div>
      <Header
        title="Operations Overview Dashboard"
        subtitle="Real-time field visit tracking, verification status, and daily quota metrics"
        onRefresh={handleRefresh}
        isRefreshing={isRefreshing}
        extraActions={
          <button
            onClick={() => onNavigate('visits')}
            className="btn btn-primary btn-sm"
            type="button"
          >
            <span>Review Visits Queue</span>
            <ArrowUpRight size={14} />
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

        {/* 6 Key Performance Metric Cards */}
        <div className="grid-kpis">
          <div className="kpi-card">
            <div className="kpi-label">Active Field Workforce</div>
            <div className="kpi-value">{overview?.active_employees ?? '—'}</div>
            <div className="kpi-subtext">
              <Users size={13} color="var(--botanical-primary)" />
              <span>Registered agronomists</span>
            </div>
          </div>

          <div className="kpi-card">
            <div className="kpi-label">Today's Target Quota</div>
            <div className="kpi-value">{overview?.today_target_sum ?? '—'}</div>
            <div className="kpi-subtext">
              <Target size={13} color="var(--earth-amber)" />
              <span>Assigned visit goal</span>
            </div>
          </div>

          <div className="kpi-card verified">
            <div className="kpi-label">Verified Visits</div>
            <div className="kpi-value" style={{ color: 'var(--crop-green)' }}>
              {overview?.today_verified_visits ?? '—'}
            </div>
            <div className="kpi-subtext">
              <CheckCircle2 size={13} color="var(--crop-green)" />
              <span>Strictly audited evidence</span>
            </div>
          </div>

          <div className="kpi-card pending">
            <div className="kpi-label">Pending Review</div>
            <div className="kpi-value" style={{ color: 'var(--earth-amber)' }}>
              {overview?.pending_review_count ?? '—'}
            </div>
            <div className="kpi-subtext">
              <Clock size={13} color="var(--earth-amber)" />
              <span>Awaiting supervisor audit</span>
            </div>
          </div>

          <div className="kpi-card flagged">
            <div className="kpi-label">Flagged For Audit</div>
            <div className="kpi-value" style={{ color: 'var(--alert-crimson)' }}>
              {overview?.flagged_visits_count ?? '—'}
            </div>
            <div className="kpi-subtext">
              <ShieldAlert size={13} color="var(--alert-crimson)" />
              <span>Low GPS or drift signals</span>
            </div>
          </div>

          <div className="kpi-card">
            <div className="kpi-label">Daily Quota Attainment</div>
            <div className="kpi-value">{overview?.today_completion_rate ? `${overview.today_completion_rate}%` : '0%'}</div>
            <div style={{ marginTop: 4 }}>
              <div className="progress-container">
                <div
                  className="progress-bar"
                  style={{ width: `${Math.min(overview?.today_completion_rate || 0, 100)}%` }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Action Shortcuts & Live Verification Queue */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 24, marginTop: 12 }}>
          {/* Recent Field Visits Inspection Table */}
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <div>
                <h2 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-main)' }}>
                  Recent Field Visit Submissions
                </h2>
                <p style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>
                  Audited on-site photographic evidence and GPS coordinate verification
                </p>
              </div>

              <button
                type="button"
                onClick={() => onNavigate('visits')}
                className="btn btn-secondary btn-sm"
              >
                <span>View Full Roster ({recentVisits.length})</span>
                <ArrowUpRight size={14} />
              </button>
            </div>

            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Photo Proof</th>
                    <th>Client / Dealer</th>
                    <th>Capture Time (PKT)</th>
                    <th>GPS Accuracy</th>
                    <th>Review Signals</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr>
                      <td colSpan={7} style={{ textAlign: 'center', padding: 32, color: 'var(--text-muted)' }}>
                        Loading latest field visit records...
                      </td>
                    </tr>
                  ) : recentVisits.length === 0 ? (
                    <tr>
                      <td colSpan={7} style={{ textAlign: 'center', padding: 32, color: 'var(--text-muted)' }}>
                        No field visits recorded today yet.
                      </td>
                    </tr>
                  ) : (
                    recentVisits.map((visit) => {
                      const photoThumb = visit.photo_url || `https://res.cloudinary.com/phytodoctor/image/upload/c_fill,w_120,h_120,g_auto,q_auto,f_auto/${visit.photo_asset_id}`;
                      return (
                        <tr key={visit.id}>
                          <td style={{ width: 64 }}>
                            <div
                              onClick={() => setSelectedVisit(visit)}
                              style={{
                                width: 44,
                                height: 44,
                                borderRadius: 'var(--radius-sm)',
                                overflow: 'hidden',
                                border: '1px solid var(--sage-border)',
                                cursor: 'pointer',
                                backgroundColor: '#222',
                              }}
                              title="Click to inspect photo"
                            >
                              <img
                                src={photoThumb}
                                alt="Thumb"
                                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                onError={(e) => {
                                  (e.target as HTMLImageElement).src = '/assets/phytodoctor_icon.png';
                                }}
                              />
                            </div>
                          </td>
                          <td>
                            <div style={{ fontWeight: 600 }}>{visit.client_name}</div>
                            {visit.client_phone && (
                              <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{visit.client_phone}</div>
                            )}
                          </td>
                          <td style={{ fontSize: 12.5 }}>
                            {new Date(visit.device_capture_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                              {new Date(visit.device_capture_time).toLocaleDateString()}
                            </div>
                          </td>
                          <td>
                            <span
                              style={{
                                fontSize: 12.5,
                                fontWeight: 600,
                                color: visit.gps_accuracy > 50 ? 'var(--alert-crimson)' : 'var(--text-main)',
                              }}
                            >
                              {visit.gps_accuracy.toFixed(1)} m
                            </span>
                          </td>
                          <td>
                            {visit.is_flagged_for_review ? (
                              <span className="badge badge-flagged" title={visit.review_signals || 'Flagged for audit'}>
                                <ShieldAlert size={11} /> Flagged
                              </span>
                            ) : (
                              <span style={{ fontSize: 12, color: 'var(--crop-green)', fontWeight: 500 }}>
                                Normal Fix
                              </span>
                            )}
                          </td>
                          <td>
                            <span
                              className={`badge ${
                                visit.status === 'VERIFIED'
                                  ? 'badge-verified'
                                  : visit.status === 'REJECTED'
                                  ? 'badge-rejected'
                                  : 'badge-pending'
                              }`}
                            >
                              {visit.status}
                            </span>
                          </td>
                          <td style={{ textAlign: 'right' }}>
                            <button
                              type="button"
                              onClick={() => setSelectedVisit(visit)}
                              className="btn btn-secondary btn-sm"
                            >
                              <Eye size={13} />
                              <span>Inspect</span>
                            </button>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      {/* Visit Detail & Verification Modal */}
      {selectedVisit && (
        <VisitDetailModal
          visit={selectedVisit}
          onClose={() => setSelectedVisit(null)}
          onVisitUpdated={handleVisitUpdated}
        />
      )}
    </div>
  );
};
