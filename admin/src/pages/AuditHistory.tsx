import React, { useEffect, useState } from 'react';
import { History, Shield, Filter, Search, AlertCircle, FileCode } from 'lucide-react';
import { Header } from '../components/Header';
import { api } from '../services/api';
import { AuditEvent } from '../types';

export const AuditHistory: React.FC = () => {
  const [logs, setLogs] = useState<AuditEvent[]>([]);
  const [total, setTotal] = useState(0);
  const [actionFilter, setActionFilter] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setError(null);
      const res = await api.getAuditLogs({
        limit: 50,
        action: actionFilter || undefined,
      });
      setLogs(res.items);
      setTotal(res.total);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch audit logs');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [actionFilter]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadData();
  };

  const filteredLogs = searchQuery.trim()
    ? logs.filter(
        (l) =>
          l.action.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (l.affected_record_id && l.affected_record_id.includes(searchQuery))
      )
    : logs;

  return (
    <div>
      <Header
        title="Operations & Security Audit History"
        subtitle="Immutable server log of administrative modifications, verification decisions, and authentication events"
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
            <div style={{ position: 'relative' }}>
              <Search
                size={15}
                style={{ position: 'absolute', left: 10, top: 9, color: 'var(--text-muted)' }}
              />
              <input
                type="text"
                placeholder="Search action or record ID..."
                className="input-control"
                style={{ paddingLeft: 32, width: 260 }}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            <select
              className="input-control"
              value={actionFilter}
              onChange={(e) => setActionFilter(e.target.value)}
            >
              <option value="">All Audit Actions</option>
              <option value="LOGIN_SUCCESS">LOGIN_SUCCESS</option>
              <option value="LOGIN_FAILED">LOGIN_FAILED</option>
              <option value="VISIT_CREATED">VISIT_CREATED</option>
              <option value="VISIT_VERIFIED">VISIT_VERIFIED</option>
              <option value="VISIT_REJECTED">VISIT_REJECTED</option>
              <option value="TARGET_CREATED">TARGET_CREATED</option>
              <option value="TARGET_BATCH_ASSIGNED">TARGET_BATCH_ASSIGNED</option>
              <option value="USER_CREATED">USER_CREATED</option>
              <option value="USER_UPDATED">USER_UPDATED</option>
              <option value="MEDIA_PHOTO_UPLOADED">MEDIA_PHOTO_UPLOADED</option>
              <option value="MEDIA_PHOTO_CONFIRMED">MEDIA_PHOTO_CONFIRMED</option>
            </select>
          </div>

          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
            Total Audit Records: <strong>{total}</strong>
          </div>
        </div>

        {/* Audit Log Table */}
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Timestamp (PKT)</th>
                <th>Action</th>
                <th>Actor Role / ID</th>
                <th>Target Record</th>
                <th>Audit Context / Metadata</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    Loading audit trail...
                  </td>
                </tr>
              ) : filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', padding: 36, color: 'var(--text-muted)' }}>
                    No audit records match the current filter.
                  </td>
                </tr>
              ) : (
                filteredLogs.map((log) => {
                  const isSecurityAction = log.action.includes('LOGIN') || log.action.includes('USER');
                  return (
                    <tr key={log.id}>
                      <td style={{ fontSize: 12.5, whiteSpace: 'nowrap' }}>
                        {new Date(log.timestamp).toLocaleString()}
                      </td>
                      <td>
                        <span
                          className={`badge ${
                            log.action.includes('VERIFIED')
                              ? 'badge-verified'
                              : log.action.includes('REJECTED') || log.action.includes('FAILED')
                              ? 'badge-rejected'
                              : isSecurityAction
                              ? 'badge-flagged'
                              : 'badge-pending'
                          }`}
                        >
                          <Shield size={10} />
                          {log.action}
                        </span>
                      </td>
                      <td style={{ fontSize: 13 }}>
                        <strong>{log.actor_role || 'SYSTEM'}</strong>
                        {log.actor_id && (
                          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            ID: {log.actor_id.substring(0, 8)}...
                          </div>
                        )}
                      </td>
                      <td style={{ fontSize: 12.5 }}>
                        <div>{log.affected_record_type || '—'}</div>
                        {log.affected_record_id && (
                          <code style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            {log.affected_record_id.substring(0, 12)}...
                          </code>
                        )}
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--text-main)', maxWidth: 320 }}>
                        {log.metadata ? (
                          <pre
                            style={{
                              fontFamily: 'monospace',
                              backgroundColor: 'var(--surface-subtle)',
                              padding: '4px 8px',
                              borderRadius: 4,
                              overflowX: 'auto',
                              fontSize: 11,
                            }}
                          >
                            {JSON.stringify(log.metadata, null, 1)}
                          </pre>
                        ) : (
                          <span style={{ color: 'var(--text-muted)' }}>—</span>
                        )}
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
  );
};
