import React, { useEffect, useState } from 'react';
import {
  FileSpreadsheet,
  Download,
  Filter,
  CheckCircle2,
  Clock,
  XCircle,
  AlertCircle,
} from 'lucide-react';
import { Header } from '../components/Header';
import { api } from '../services/api';
import { FieldVisit, User } from '../types';

export const ReportsExport: React.FC = () => {
  const [visits, setVisits] = useState<FieldVisit[]>([]);
  const [employees, setEmployees] = useState<User[]>([]);

  // Filter criteria
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [employeeFilter, setEmployeeFilter] = useState<string>('');
  const [dateFrom, setDateFrom] = useState<string>('');
  const [dateTo, setDateTo] = useState<string>('');

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setError(null);
      const [visitsData, usersData] = await Promise.all([
        api.getVisits({
          limit: 100,
          status: statusFilter !== 'ALL' ? statusFilter : undefined,
          employee_id: employeeFilter || undefined,
        }),
        api.getUsers({ role: 'EMPLOYEE' }),
      ]);
      setVisits(visitsData.items);
      setEmployees(usersData.items);
    } catch (err: any) {
      setError(err.message || 'Failed to generate report dataset');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [statusFilter, employeeFilter]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadData();
  };

  // Local date filtering
  const filteredVisits = visits.filter((v) => {
    if (!dateFrom && !dateTo) return true;
    const vDate = new Date(v.device_capture_time).toISOString().split('T')[0];
    if (dateFrom && vDate < dateFrom) return false;
    if (dateTo && vDate > dateTo) return false;
    return true;
  });

  const verifiedVisits = filteredVisits.filter((v) => v.status === 'VERIFIED');
  const unverifiedVisits = filteredVisits.filter((v) => v.status !== 'VERIFIED');

  const getEmployeeName = (id: string) => {
    const emp = employees.find((e) => e.id === id);
    return emp ? emp.full_name : id.substring(0, 8);
  };

  // RFC 4180 Compliant CSV Export
  // Security guarantee: NEVER exposes passwords, tokens, or private secrets
  const exportToCSV = () => {
    const headers = [
      'Visit_ID',
      'Client_Name',
      'Client_Phone',
      'Field_Agronomist',
      'Capture_Time_UTC',
      'Capture_Time_PKT',
      'Latitude',
      'Longitude',
      'GPS_Accuracy_Meters',
      'Verification_Status',
      'Is_Flagged_Audit',
      'Supervisor_Review_Reason',
    ];

    const rows = filteredVisits.map((v) => [
      `"${v.id}"`,
      `"${v.client_name.replace(/"/g, '""')}"`,
      `"${(v.client_phone || '').replace(/"/g, '""')}"`,
      `"${getEmployeeName(v.employee_id).replace(/"/g, '""')}"`,
      `"${v.device_capture_time}"`,
      `"${new Date(v.device_capture_time).toLocaleString('en-GB')}"`,
      v.latitude,
      v.longitude,
      v.gps_accuracy,
      `"${v.status}"`,
      v.is_flagged_for_review ? 'YES' : 'NO',
      `"${(v.review_reason || '').replace(/"/g, '""')}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `phyto_doctor_visits_report_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div>
      <Header
        title="Field Operations Reports & Audited Export"
        subtitle="Filter by employee, team, date range, and export verified records to CSV"
        onRefresh={handleRefresh}
        isRefreshing={isRefreshing}
        extraActions={
          <button
            type="button"
            onClick={exportToCSV}
            disabled={filteredVisits.length === 0}
            className="btn btn-primary btn-sm"
          >
            <Download size={15} />
            <span>Export to CSV ({filteredVisits.length} records)</span>
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

        {/* Filter Controls */}
        <div className="toolbar-filter">
          <div className="filter-group">
            <select
              className="input-control"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="ALL">All Verification Statuses</option>
              <option value="VERIFIED">Verified Visits Only</option>
              <option value="PENDING">Pending Review Only</option>
              <option value="REJECTED">Rejected Visits Only</option>
            </select>

            <select
              className="input-control"
              value={employeeFilter}
              onChange={(e) => setEmployeeFilter(e.target.value)}
              style={{ width: 220 }}
            >
              <option value="">All Field Agronomists</option>
              {employees.map((emp) => (
                <option key={emp.id} value={emp.id}>
                  {emp.full_name}
                </option>
              ))}
            </select>

            <label style={{ fontSize: 13, fontWeight: 600, marginLeft: 6 }}>Date Range:</label>
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

          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
            Total Exportable: <strong>{filteredVisits.length}</strong> visits
          </div>
        </div>

        {/* Summary Breakdown Cards: Verified vs Unverified Separation */}
        <div className="grid-kpis">
          <div className="kpi-card verified">
            <div className="kpi-label">Verified Visits (Report Basis)</div>
            <div className="kpi-value" style={{ color: 'var(--crop-green)' }}>
              {verifiedVisits.length}
            </div>
            <div className="kpi-subtext">
              <CheckCircle2 size={13} color="var(--crop-green)" />
              <span>Counted toward verified quota</span>
            </div>
          </div>

          <div className="kpi-card pending">
            <div className="kpi-label">Unverified / Pending Visits</div>
            <div className="kpi-value" style={{ color: 'var(--earth-amber)' }}>
              {unverifiedVisits.filter((v) => v.status === 'PENDING').length}
            </div>
            <div className="kpi-subtext">
              <Clock size={13} color="var(--earth-amber)" />
              <span>Never inflates verified counts</span>
            </div>
          </div>

          <div className="kpi-card flagged">
            <div className="kpi-label">Rejected / Disqualified</div>
            <div className="kpi-value" style={{ color: 'var(--alert-crimson)' }}>
              {unverifiedVisits.filter((v) => v.status === 'REJECTED').length}
            </div>
            <div className="kpi-subtext">
              <XCircle size={13} color="var(--alert-crimson)" />
              <span>Flagged or invalid evidence</span>
            </div>
          </div>

          <div className="kpi-card">
            <div className="kpi-label">Verification Ratio</div>
            <div className="kpi-value">
              {filteredVisits.length > 0
                ? `${Math.round((verifiedVisits.length / filteredVisits.length) * 100)}%`
                : '0%'}
            </div>
            <div className="kpi-subtext">
              <span>Verified vs total submissions</span>
            </div>
          </div>
        </div>

        {/* Report Preview Table */}
        <div className="card" style={{ marginTop: 20 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
            <FileSpreadsheet size={18} color="var(--botanical-primary)" />
            Report Data Preview (Prior to CSV Export)
          </h3>

          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Client Name</th>
                  <th>Agronomist</th>
                  <th>Capture Time</th>
                  <th>GPS Fix</th>
                  <th>Status</th>
                  <th>Audit Decision / Note</th>
                </tr>
              </thead>
              <tbody>
                {isLoading ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                      Generating report dataset...
                    </td>
                  </tr>
                ) : filteredVisits.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                      No visit records match the requested report criteria.
                    </td>
                  </tr>
                ) : (
                  filteredVisits.slice(0, 25).map((visit) => (
                    <tr key={visit.id}>
                      <td>
                        <strong>{visit.client_name}</strong>
                        {visit.client_phone && (
                          <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{visit.client_phone}</div>
                        )}
                      </td>
                      <td style={{ fontSize: 13 }}>{getEmployeeName(visit.employee_id)}</td>
                      <td style={{ fontSize: 12.5 }}>{new Date(visit.device_capture_time).toLocaleString()}</td>
                      <td style={{ fontSize: 12 }}>
                        {visit.latitude.toFixed(4)}°, {visit.longitude.toFixed(4)}° (±{visit.gps_accuracy.toFixed(1)}m)
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
                      <td style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>
                        {visit.review_reason || <span style={{ color: 'var(--text-subtle)' }}>—</span>}
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
  );
};
