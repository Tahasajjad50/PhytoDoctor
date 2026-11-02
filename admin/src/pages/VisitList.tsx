import React, { useEffect, useState } from 'react';
import {
  Search,
  Filter,
  Eye,
  ShieldAlert,
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  FileCheck2,
} from 'lucide-react';
import { Header } from '../components/Header';
import { VisitDetailModal } from '../components/VisitDetailModal';
import { api } from '../services/api';
import { FieldVisit, User } from '../types';

export const VisitList: React.FC = () => {
  const [visits, setVisits] = useState<FieldVisit[]>([]);
  const [employees, setEmployees] = useState<User[]>([]);
  const [total, setTotal] = useState<number>(0);
  const [skip, setSkip] = useState<number>(0);
  const [limit] = useState<number>(15);

  // Filters
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [flaggedFilter, setFlaggedFilter] = useState<string>('ALL');
  const [employeeFilter, setEmployeeFilter] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const [selectedVisit, setSelectedVisit] = useState<FieldVisit | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async (newSkip = skip) => {
    try {
      setError(null);
      const isFlaggedParam =
        flaggedFilter === 'FLAGGED' ? true : flaggedFilter === 'CLEAN' ? false : undefined;

      const [visitsData, usersData] = await Promise.all([
        api.getVisits({
          skip: newSkip,
          limit,
          status: statusFilter !== 'ALL' ? statusFilter : undefined,
          is_flagged: isFlaggedParam,
          employee_id: employeeFilter ? employeeFilter : undefined,
        }),
        api.getUsers({ role: 'EMPLOYEE' }),
      ]);

      setVisits(visitsData.items);
      setTotal(visitsData.total);
      setSkip(newSkip);
      setEmployees(usersData.items);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch field visits list');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadData(0);
  }, [statusFilter, flaggedFilter, employeeFilter]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadData(skip);
  };

  const handleVisitUpdated = (updated: FieldVisit) => {
    setVisits((prev) =>
      prev.map((v) => (v.id === updated.id ? updated : v))
    );
  };

  // Filter local search by client name
  const filteredVisits = searchQuery.trim()
    ? visits.filter((v) =>
        v.client_name.toLowerCase().includes(searchQuery.toLowerCase().trim())
      )
    : visits;

  // Resolve employee name
  const getEmployeeName = (id: string) => {
    const emp = employees.find((e) => e.id === id);
    return emp ? `${emp.full_name} (${emp.username})` : id.substring(0, 8);
  };

  const totalPages = Math.ceil(total / limit) || 1;
  const currentPage = Math.floor(skip / limit) + 1;

  return (
    <div>
      <Header
        title="Field Visit Audit & Verification Roster"
        subtitle="Comprehensive log of all farmer/dealer on-site interactions with verified evidence"
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
            {/* Search client */}
            <div style={{ position: 'relative' }}>
              <Search
                size={15}
                style={{ position: 'absolute', left: 10, top: 9, color: 'var(--text-muted)' }}
              />
              <input
                type="text"
                placeholder="Search by client/dealer..."
                className="input-control"
                style={{ paddingLeft: 32, width: 220 }}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            {/* Status Filter */}
            <select
              className="input-control"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="ALL">All Verification Statuses</option>
              <option value="PENDING">Pending Review</option>
              <option value="VERIFIED">Verified Only</option>
              <option value="REJECTED">Rejected Visits</option>
            </select>

            {/* Review Flag Filter */}
            <select
              className="input-control"
              value={flaggedFilter}
              onChange={(e) => setFlaggedFilter(e.target.value)}
            >
              <option value="ALL">All Quality Signals</option>
              <option value="FLAGGED">Flagged for Audit Only</option>
              <option value="CLEAN">Clean GNSS Fix Only</option>
            </select>

            {/* Employee Filter */}
            <select
              className="input-control"
              value={employeeFilter}
              onChange={(e) => setEmployeeFilter(e.target.value)}
              style={{ maxWidth: 220 }}
            >
              <option value="">All Field Employees</option>
              {employees.map((emp) => (
                <option key={emp.id} value={emp.id}>
                  {emp.full_name}
                </option>
              ))}
            </select>
          </div>

          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
            Showing <strong>{filteredVisits.length}</strong> of <strong>{total}</strong> recorded visits
          </div>
        </div>

        {/* Data Table */}
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Photo Evidence</th>
                <th>Client / Dealer</th>
                <th>Field Agronomist</th>
                <th>Capture Time (PKT)</th>
                <th>GNSS Accuracy</th>
                <th>Quality Signals</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    Loading field visit records...
                  </td>
                </tr>
              ) : filteredVisits.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    No field visits match the selected filter criteria.
                  </td>
                </tr>
              ) : (
                filteredVisits.map((visit) => {
                  const photoThumb = visit.photo_url || `https://res.cloudinary.com/phytodoctor/image/upload/c_fill,w_120,h_120,g_auto,q_auto,f_auto/${visit.photo_asset_id}`;
                  return (
                    <tr key={visit.id}>
                      <td style={{ width: 60 }}>
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
                          title="Click to inspect photo evidence"
                        >
                          <img
                            src={photoThumb}
                            alt="Evidence"
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
                      <td style={{ fontSize: 13 }}>
                        {getEmployeeName(visit.employee_id)}
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
                            Normal
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
                          <span>Audit</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Toolbar */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginTop: 16,
            fontSize: 13,
            color: 'var(--text-muted)',
          }}
        >
          <div>
            Page <strong>{currentPage}</strong> of <strong>{totalPages}</strong>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              onClick={() => loadData(Math.max(0, skip - limit))}
              disabled={skip === 0 || isLoading}
              className="btn btn-secondary btn-sm"
            >
              <ChevronLeft size={14} />
              <span>Previous</span>
            </button>

            <button
              type="button"
              onClick={() => loadData(skip + limit)}
              disabled={skip + limit >= total || isLoading}
              className="btn btn-secondary btn-sm"
            >
              <span>Next</span>
              <ChevronRight size={14} />
            </button>
          </div>
        </div>
      </div>

      {/* Visit Detail & Audit Modal */}
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
