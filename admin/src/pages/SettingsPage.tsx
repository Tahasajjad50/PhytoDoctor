import React, { useEffect, useState } from 'react';
import {
  Settings,
  Shield,
  Cloud,
  CheckCircle2,
  DollarSign,
  AlertTriangle,
  Server,
  Compass,
} from 'lucide-react';
import { Header } from '../components/Header';
import { api } from '../services/api';
import { CloudinaryUsageEstimate } from '../types';
import { useAuth } from '../context/AuthContext';

export const SettingsPage: React.FC = () => {
  const { user, isOwner } = useAuth();
  const [usage, setUsage] = useState<CloudinaryUsageEstimate | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadUsage = async () => {
      try {
        if (isOwner) {
          const data = await api.getCloudinaryUsage(20);
          setUsage(data);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to fetch Cloudinary usage metrics');
      } finally {
        setIsLoading(false);
      }
    };
    loadUsage();
  }, [isOwner]);

  return (
    <div>
      <Header
        title="System Governance & Media Storage Settings"
        subtitle="Operational parameters, evidence collection policy, and Cloudinary quota management"
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
            }}
          >
            {error}
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
          {/* Organization & System Parameters */}
          <div className="card">
            <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Server size={18} color="var(--botanical-primary)" />
              System Architecture & Policy Standards
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 14, fontSize: 13 }}>
              <div>
                <label style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
                  Organization / Entity
                </label>
                <div style={{ fontWeight: 600 }}>Phyto Doctor (Pvt) Ltd</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Agri-Biotech & Crop Protection Distribution</div>
              </div>

              <div>
                <label style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
                  GPS Evidence Accuracy Threshold
                </label>
                <div style={{ fontWeight: 600, color: 'var(--botanical-primary)' }}>50.0 Meters Radius</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  Visits captured with &gt;50m GNSS reported radius are automatically flagged for supervisor audit.
                </div>
              </div>

              <div>
                <label style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
                  Background Location Tracking Policy
                </label>
                <div style={{ fontWeight: 600, color: 'var(--crop-green)' }}>Disabled (Zero Background Tracking)</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  GPS coordinates and in-app camera photos are collected exclusively on-demand during visit submission.
                </div>
              </div>

              <div>
                <label style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
                  Evidence Retention Period
                </label>
                <div style={{ fontWeight: 600 }}>30 Days Confirmed Local Sandbox Retention</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  Unsynced photos are never pruned. Confirmed synced photos are preserved locally for 30 days.
                </div>
              </div>
            </div>
          </div>

          {/* Cloudinary Quota & Cost Management */}
          <div className="card">
            <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Cloud size={18} color="var(--botanical-primary)" />
              Cloudinary Media Quota & Cost Governance
            </h3>

            {isOwner && usage ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14, fontSize: 13 }}>
                <div
                  style={{
                    padding: '12px 14px',
                    backgroundColor: 'var(--crop-green-light)',
                    border: '1px solid var(--crop-green-border)',
                    borderRadius: 'var(--radius-sm)',
                    color: 'var(--crop-green)',
                  }}
                >
                  <div style={{ fontWeight: 700, fontSize: 13.5 }}>Current Plan: {usage.plan_name}</div>
                  <div style={{ fontSize: 12, marginTop: 2 }}>Monthly Cost: <strong>${usage.cost_current_usd.toFixed(2)} USD / month</strong></div>
                </div>

                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ fontSize: 12, fontWeight: 600 }}>Credit Usage vs Allowance:</span>
                    <span style={{ fontSize: 12, fontWeight: 700 }}>
                      {usage.estimated_monthly_credits_used} / {usage.monthly_credit_allowance} Credits ({usage.utilization_percentage}%)
                    </span>
                  </div>
                  <div className="progress-container">
                    <div className="progress-bar" style={{ width: `${usage.utilization_percentage}%` }} />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: 12.5 }}>
                  <div style={{ padding: 10, backgroundColor: 'var(--surface-subtle)', borderRadius: 6 }}>
                    <span style={{ color: 'var(--text-muted)', display: 'block' }}>Monthly Visits</span>
                    <strong>{usage.estimated_visits_per_month}</strong>
                  </div>
                  <div style={{ padding: 10, backgroundColor: 'var(--surface-subtle)', borderRadius: 6 }}>
                    <span style={{ color: 'var(--text-muted)', display: 'block' }}>Monthly Storage</span>
                    <strong>{usage.estimated_storage_gb_per_month} GB</strong>
                  </div>
                </div>

                <div style={{ fontSize: 12, color: 'var(--text-muted)', fontStyle: 'italic', borderTop: '1px solid var(--sage-border)', paddingTop: 12 }}>
                  * Policy Note: {usage.policy_note}
                </div>
              </div>
            ) : (
              <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                Cloudinary usage metrics and quota cost estimation are restricted to Executive Owners.
              </div>
            )}
          </div>
        </div>

        {/* Current Admin User Profile Details */}
        <div className="card" style={{ marginTop: 24 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
            <Shield size={18} color="var(--botanical-primary)" />
            Authenticated Administrator Profile
          </h3>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, fontSize: 13 }}>
            <div>
              <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: 11, textTransform: 'uppercase' }}>Administrator Name</span>
              <strong>{user?.full_name}</strong>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: 11, textTransform: 'uppercase' }}>Username</span>
              <code>{user?.username}</code>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: 11, textTransform: 'uppercase' }}>Email</span>
              <span>{user?.email}</span>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: 11, textTransform: 'uppercase' }}>Role Privilege</span>
              <span className={`badge ${user?.role === 'OWNER' ? 'badge-verified' : 'badge-flagged'}`}>
                {user?.role}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
