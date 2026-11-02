import React, { useState } from 'react';
import { X, Target, CheckSquare, Square } from 'lucide-react';
import { api } from '../services/api';
import { User } from '../types';

interface BatchTargetModalProps {
  isOpen: boolean;
  onClose: () => void;
  employees: User[];
  onTargetsAssigned: () => void;
}

export const BatchTargetModal: React.FC<BatchTargetModalProps> = ({
  isOpen,
  onClose,
  employees,
  onTargetsAssigned,
}) => {
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [targetCount, setTargetCount] = useState<number>(10);
  const [startDate, setStartDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [endDate, setEndDate] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const toggleSelectAll = () => {
    if (selectedIds.length === employees.length) {
      setSelectedIds([]);
    } else {
      setSelectedIds(employees.map((e) => e.id));
    }
  };

  const toggleSelectOne = (id: string) => {
    if (selectedIds.includes(id)) {
      setSelectedIds(selectedIds.filter((item) => item !== id));
    } else {
      setSelectedIds([...selectedIds, id]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedIds.length === 0) {
      setError('Please select at least one employee.');
      return;
    }
    if (targetCount < 1) {
      setError('Target count must be at least 1.');
      return;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      await api.batchAssignTargets({
        employee_ids: selectedIds,
        target_count: targetCount,
        period_type: 'DAILY',
        start_date: startDate,
        end_date: endDate ? endDate : null,
      });
      onTargetsAssigned();
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to assign batch targets');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 650 }}>
        <div className="modal-header">
          <h2>Assign Daily Targets (Batch Allocation)</h2>
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
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 16 }}>
            <div>
              <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                Daily Target Quota
              </label>
              <input
                type="number"
                min="1"
                max="100"
                className="input-control"
                style={{ width: '100%' }}
                value={targetCount}
                onChange={(e) => setTargetCount(parseInt(e.target.value) || 1)}
                required
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
                Effective Start Date
              </label>
              <input
                type="date"
                className="input-control"
                style={{ width: '100%' }}
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
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
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
              />
            </div>
          </div>

          <div style={{ marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 13, fontWeight: 600 }}>
              Select Target Employees ({selectedIds.length} of {employees.length} selected):
            </span>
            <button
              type="button"
              onClick={toggleSelectAll}
              className="btn btn-secondary btn-sm"
              style={{ fontSize: 11.5 }}
            >
              {selectedIds.length === employees.length ? 'Deselect All' : 'Select All'}
            </button>
          </div>

          {/* Employee Selection List */}
          <div
            style={{
              maxHeight: 220,
              overflowY: 'auto',
              border: '1px solid var(--sage-border)',
              borderRadius: 'var(--radius-sm)',
              backgroundColor: 'var(--surface-subtle)',
              padding: '6px 8px',
            }}
          >
            {employees.length === 0 ? (
              <div style={{ padding: 16, textAlign: 'center', color: 'var(--text-muted)', fontSize: 13 }}>
                No active field employees found.
              </div>
            ) : (
              employees.map((emp) => {
                const isChecked = selectedIds.includes(emp.id);
                return (
                  <div
                    key={emp.id}
                    onClick={() => toggleSelectOne(emp.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                      padding: '8px 10px',
                      cursor: 'pointer',
                      borderRadius: 4,
                      backgroundColor: isChecked ? 'var(--sage-light)' : 'transparent',
                      marginBottom: 2,
                    }}
                  >
                    {isChecked ? (
                      <CheckSquare size={16} color="var(--botanical-primary)" />
                    ) : (
                      <Square size={16} color="var(--text-muted)" />
                    )}
                    <span style={{ fontSize: 13, fontWeight: isChecked ? 600 : 400 }}>
                      {emp.full_name} ({emp.username})
                    </span>
                    <span style={{ fontSize: 11, color: 'var(--text-muted)', marginLeft: 'auto' }}>
                      {emp.email}
                    </span>
                  </div>
                );
              })
            )}
          </div>

          <div className="modal-footer">
            <button type="button" onClick={onClose} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={isSubmitting || selectedIds.length === 0} className="btn btn-primary">
              <Target size={16} />
              <span>{isSubmitting ? 'Assigning...' : `Assign to ${selectedIds.length} Employees`}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
