import React, { useState } from 'react';
import {
  X,
  MapPin,
  Camera,
  Clock,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  ShieldAlert,
  User,
  Phone,
  FileText,
  ExternalLink,
} from 'lucide-react';
import { FieldVisit } from '../types';
import { api } from '../services/api';
import { useAuth } from '../context/AuthContext';

interface VisitDetailModalProps {
  visit: FieldVisit | null;
  onClose: () => void;
  onVisitUpdated: (updated: FieldVisit) => void;
}

export const VisitDetailModal: React.FC<VisitDetailModalProps> = ({
  visit,
  onClose,
  onVisitUpdated,
}) => {
  const { user } = useAuth();
  const [reviewReason, setReviewReason] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [isImageZoomed, setIsImageZoomed] = useState<boolean>(false);

  if (!visit) return null;

  // Review signals parse
  let parsedSignals: string[] = [];
  if (visit.review_signals) {
    try {
      parsedSignals = JSON.parse(visit.review_signals);
    } catch {
      parsedSignals = [visit.review_signals];
    }
  }

  // Handle Verify or Reject
  const handleDecision = async (status: 'VERIFIED' | 'REJECTED') => {
    if (status === 'REJECTED' && !reviewReason.trim()) {
      setActionError('A supervisor review reason is required when rejecting a field visit.');
      return;
    }

    setIsSubmitting(true);
    setActionError(null);
    try {
      const updated = await api.verifyVisit(visit.id, status, reviewReason.trim());
      onVisitUpdated(updated);
      onClose();
    } catch (err: any) {
      setActionError(err.message || 'Failed to submit verification decision');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Prevent employee from self-verifying (should not occur in admin dashboard, but safety first)
  const isSelfVisit = user?.id === visit.employee_id;

  // OpenStreetMap static / interactive URL
  const mapEmbedUrl = `https://www.openstreetmap.org/export/embed.html?bbox=${visit.longitude - 0.005}%2C${visit.latitude - 0.005}%2C${visit.longitude + 0.005}%2C${visit.latitude + 0.005}&layer=mapnik&marker=${visit.latitude}%2C${visit.longitude}`;

  const photoDeliveryUrl = visit.photo_url || `https://res.cloudinary.com/phytodoctor/image/upload/q_auto,f_auto/${visit.photo_asset_id}`;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div
        className="modal-content large"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: 960 }}
      >
        {/* Modal Header */}
        <div className="modal-header">
          <div>
            <h2>Field Visit Inspection & Verification</h2>
            <p style={{ fontSize: 13, color: 'var(--text-muted)' }}>
              Visit UUID: <code style={{ backgroundColor: 'var(--sage-light)', padding: '2px 6px', borderRadius: 4 }}>{visit.id}</code>
            </p>
          </div>
          <button onClick={onClose} className="btn btn-secondary btn-icon-only" type="button">
            <X size={18} />
          </button>
        </div>

        {actionError && (
          <div
            style={{
              padding: '12px 16px',
              backgroundColor: 'var(--alert-crimson-light)',
              border: '1px solid var(--alert-crimson-border)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--alert-crimson)',
              marginBottom: 16,
              fontSize: 13,
            }}
          >
            {actionError}
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 24 }}>
          {/* Left Column: Photo Evidence & Location Map */}
          <div>
            <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Camera size={16} color="var(--botanical-primary)" />
              In-App Photographic Evidence
            </h3>

            <div
              style={{
                position: 'relative',
                borderRadius: 'var(--radius-md)',
                overflow: 'hidden',
                border: '1px solid var(--sage-border)',
                backgroundColor: '#111',
                textAlign: 'center',
                minHeight: 240,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <img
                src={photoDeliveryUrl}
                alt={`Evidence for ${visit.client_name}`}
                style={{
                  width: '100%',
                  maxHeight: 280,
                  objectFit: 'contain',
                  cursor: 'pointer',
                }}
                onClick={() => setIsImageZoomed(!isImageZoomed)}
                onError={(e) => {
                  (e.target as HTMLImageElement).src = '/assets/phytodoctor_logo.jpg';
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  bottom: 8,
                  left: 8,
                  right: 8,
                  backgroundColor: 'rgba(0,0,0,0.7)',
                  color: '#FFF',
                  padding: '4px 8px',
                  borderRadius: 4,
                  fontSize: 11,
                  display: 'flex',
                  justifyContent: 'space-between',
                }}
              >
                <span>Asset: {visit.photo_asset_id}</span>
                <a
                  href={photoDeliveryUrl}
                  target="_blank"
                  rel="noreferrer"
                  style={{ color: 'var(--sage-accent)', display: 'inline-flex', alignItems: 'center', gap: 3 }}
                >
                  Full Res <ExternalLink size={10} />
                </a>
              </div>
            </div>

            {/* Geofence Map */}
            <h3 style={{ fontSize: 14, fontWeight: 700, marginTop: 18, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
              <MapPin size={16} color="var(--botanical-primary)" />
              GNSS Location Fix & Accuracy
            </h3>
            <div
              style={{
                borderRadius: 'var(--radius-md)',
                overflow: 'hidden',
                border: '1px solid var(--sage-border)',
                height: 180,
                backgroundColor: 'var(--surface-subtle)',
              }}
            >
              <iframe
                title="Visit Location Map"
                width="100%"
                height="180"
                frameBorder="0"
                scrolling="no"
                src={mapEmbedUrl}
              />
            </div>
            <div style={{ marginTop: 6, fontSize: 12, color: 'var(--text-muted)', display: 'flex', justifyContent: 'space-between' }}>
              <span>Latitude: <strong>{visit.latitude.toFixed(6)}°</strong>, Longitude: <strong>{visit.longitude.toFixed(6)}°</strong></span>
              <span>Accuracy: <strong style={{ color: visit.gps_accuracy > 50 ? 'var(--alert-crimson)' : 'var(--crop-green)' }}>{visit.gps_accuracy.toFixed(1)} m</strong></span>
            </div>
          </div>

          {/* Right Column: Visit Metadata & Fraud-Aware Signals */}
          <div>
            {/* Status & Review Flags Banner */}
            <div
              style={{
                padding: '12px 16px',
                borderRadius: 'var(--radius-md)',
                backgroundColor:
                  visit.status === 'VERIFIED'
                    ? 'var(--crop-green-light)'
                    : visit.status === 'REJECTED'
                    ? 'var(--alert-crimson-light)'
                    : 'var(--earth-amber-light)',
                border: `1px solid ${
                  visit.status === 'VERIFIED'
                    ? 'var(--crop-green-border)'
                    : visit.status === 'REJECTED'
                    ? 'var(--alert-crimson-border)'
                    : 'var(--earth-amber-border)'
                }`,
                marginBottom: 16,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: 13, fontWeight: 700, textTransform: 'uppercase' }}>
                  Current Status: {visit.status}
                </span>
                {visit.is_flagged_for_review && (
                  <span className="badge badge-flagged">
                    <ShieldAlert size={12} /> Flagged For Audit
                  </span>
                )}
              </div>
              {visit.review_reason && (
                <div style={{ marginTop: 6, fontSize: 12.5, color: 'var(--text-main)' }}>
                  <strong>Supervisor Note:</strong> {visit.review_reason}
                </div>
              )}
            </div>

            {/* Audit / Review Signals */}
            {parsedSignals.length > 0 && (
              <div
                style={{
                  padding: '12px 16px',
                  backgroundColor: '#FFF8E6',
                  border: '1px solid #FFE29A',
                  borderRadius: 'var(--radius-sm)',
                  marginBottom: 16,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700, fontSize: 12.5, color: '#855E00' }}>
                  <AlertTriangle size={15} /> Fraud-Aware Verification Indicators
                </div>
                <ul style={{ paddingLeft: 18, marginTop: 6, fontSize: 12, color: '#684800' }}>
                  {parsedSignals.map((signal, idx) => (
                    <li key={idx} style={{ marginTop: 3 }}>{signal}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Client & Verification Details Table */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, fontSize: 13 }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                <User size={16} color="var(--text-muted)" style={{ marginTop: 2 }} />
                <div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Client / Dealer / Farmer</div>
                  <div style={{ fontWeight: 600 }}>{visit.client_name}</div>
                </div>
              </div>

              {visit.client_phone && (
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                  <Phone size={16} color="var(--text-muted)" style={{ marginTop: 2 }} />
                  <div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Contact Phone</div>
                    <div>{visit.client_phone}</div>
                  </div>
                </div>
              )}

              {visit.notes && (
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                  <FileText size={16} color="var(--text-muted)" style={{ marginTop: 2 }} />
                  <div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Agronomist Field Notes</div>
                    <div style={{ color: 'var(--text-main)', fontStyle: 'italic' }}>"{visit.notes}"</div>
                  </div>
                </div>
              )}

              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                <Clock size={16} color="var(--text-muted)" style={{ marginTop: 2 }} />
                <div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Timestamp Comparison</div>
                  <div>Device Capture: <strong>{new Date(visit.device_capture_time).toLocaleString()}</strong></div>
                  <div>Server Receipt: <strong>{new Date(visit.server_receipt_time).toLocaleString()}</strong></div>
                  {visit.clock_drift_seconds !== null && visit.clock_drift_seconds !== undefined && (
                    <div style={{ fontSize: 12, color: Math.abs(visit.clock_drift_seconds) > 300 ? 'var(--alert-crimson)' : 'var(--text-muted)' }}>
                      Clock Delta: {visit.clock_drift_seconds.toFixed(0)} seconds
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Verification Form Section */}
            <div style={{ marginTop: 20, paddingTop: 16, borderTop: '1px solid var(--sage-border)' }}>
              <label style={{ display: 'block', fontSize: 12.5, fontWeight: 600, marginBottom: 6 }}>
                Supervisor Review Reason (Required for rejection):
              </label>
              <textarea
                value={reviewReason}
                onChange={(e) => setReviewReason(e.target.value)}
                placeholder="Enter audit explanation or verification confirmation notes..."
                rows={3}
                className="input-control"
                style={{ width: '100%', resize: 'vertical' }}
              />

              <div style={{ display: 'flex', gap: 12, marginTop: 14 }}>
                <button
                  type="button"
                  onClick={() => handleDecision('VERIFIED')}
                  disabled={isSubmitting || isSelfVisit}
                  className="btn btn-success"
                  style={{ flex: 1 }}
                >
                  <CheckCircle2 size={16} />
                  <span>Verify Visit</span>
                </button>

                <button
                  type="button"
                  onClick={() => handleDecision('REJECTED')}
                  disabled={isSubmitting || isSelfVisit}
                  className="btn btn-danger"
                  style={{ flex: 1 }}
                >
                  <XCircle size={16} />
                  <span>Reject Visit</span>
                </button>
              </div>

              {isSelfVisit && (
                <p style={{ fontSize: 11.5, color: 'var(--alert-crimson)', marginTop: 6 }}>
                  * Security Policy: Employees cannot verify or reject their own field visit submissions.
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
