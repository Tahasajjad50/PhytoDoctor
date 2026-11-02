import {
  AuditEvent,
  CloudinaryUsageEstimate,
  EmployeeTarget,
  FieldVisit,
  PaginatedVisits,
  PerformanceAnalytics,
  TeamComparison,
  User,
} from '../types';

const API_BASE = (import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1').replace(/\/$/, '');

function getAuthHeader(): Record<string, string> {
  const token = localStorage.getItem('phyto_admin_token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const url = `${API_BASE}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
  const headers = {
    'Content-Type': 'application/json',
    ...getAuthHeader(),
    ...options.headers,
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    localStorage.removeItem('phyto_admin_token');
    localStorage.removeItem('phyto_admin_user');
    if (!window.location.pathname.includes('/login')) {
      window.location.href = '/login';
    }
    throw new Error('Session expired or unauthorized. Please log in again.');
  }

  if (!response.ok) {
    let errorDetail = 'Request failed';
    try {
      const errJson = await response.json();
      errorDetail = errJson.detail || JSON.stringify(errJson);
    } catch {
      errorDetail = await response.text();
    }
    throw new Error(errorDetail || `HTTP error ${response.status}`);
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return {} as T;
  }

  return response.json() as Promise<T>;
}

export const api = {
  // Authentication
  async login(usernameOrEmail: string, password: string): Promise<{ access_token: string; refresh_token: string; user: User }> {
    return request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username_or_email: usernameOrEmail,
        password,
        portal: 'admin',
      }),
    });
  },

  async logout(): Promise<void> {
    try {
      await request('/auth/logout', { method: 'POST' });
    } finally {
      localStorage.removeItem('phyto_admin_token');
      localStorage.removeItem('phyto_admin_user');
    }
  },

  async getCurrentUser(): Promise<User> {
    return request('/auth/me');
  },

  // Users / Employees
  async getUsers(params: { role?: string; is_active?: boolean; manager_id?: string } = {}): Promise<{ items: User[]; total: number }> {
    const query = new URLSearchParams();
    if (params.role) query.append('role', params.role);
    if (params.is_active !== undefined) query.append('is_active', String(params.is_active));
    if (params.manager_id) query.append('manager_id', params.manager_id);
    return request(`/users/?${query.toString()}`);
  },

  async createUser(userData: {
    username: string;
    email: string;
    password: string;
    full_name: string;
    role: string;
    manager_id?: string | null;
  }): Promise<User> {
    return request('/users/', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  },

  async updateUser(userId: string, updateData: Partial<User>): Promise<User> {
    return request(`/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(updateData),
    });
  },

  async resetPassword(userId: string, newPassword: string): Promise<{ message: string }> {
    return request(`/users/${userId}/reset-password`, {
      method: 'POST',
      body: JSON.stringify({ new_password: newPassword }),
    });
  },

  // Field Visits
  async getVisits(params: {
    skip?: number;
    limit?: number;
    status?: string;
    is_flagged?: boolean;
    employee_id?: string;
  } = {}): Promise<PaginatedVisits> {
    const query = new URLSearchParams();
    if (params.skip !== undefined) query.append('skip', String(params.skip));
    if (params.limit !== undefined) query.append('limit', String(params.limit));
    if (params.status && params.status !== 'ALL') query.append('status', params.status);
    if (params.is_flagged !== undefined) query.append('is_flagged', String(params.is_flagged));
    if (params.employee_id) query.append('employee_id', params.employee_id);
    return request(`/visits/?${query.toString()}`);
  },

  async getVisitDetail(visitId: string): Promise<FieldVisit> {
    return request(`/visits/${visitId}`);
  },

  async verifyVisit(visitId: string, status: 'VERIFIED' | 'REJECTED', reviewReason?: string): Promise<FieldVisit> {
    return request(`/visits/${visitId}/verify`, {
      method: 'POST',
      body: JSON.stringify({
        status,
        review_reason: reviewReason || null,
      }),
    });
  },

  async getSecurePhotoAccess(visitId: string): Promise<{ secure_view_url: string; thumbnail_url: string; expires_in_seconds: number }> {
    return request(`/media/visits/${visitId}/photo-access`);
  },

  // Targets
  async getTargets(params: { employee_id?: string; is_active?: boolean } = {}): Promise<EmployeeTarget[]> {
    const query = new URLSearchParams();
    if (params.employee_id) query.append('employee_id', params.employee_id);
    if (params.is_active !== undefined) query.append('is_active', String(params.is_active));
    return request(`/targets/?${query.toString()}`);
  },

  async createTarget(data: {
    employee_id: string;
    target_count: number;
    period_type: string;
    start_date: string;
    end_date?: string | null;
  }): Promise<EmployeeTarget> {
    return request('/targets/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  async batchAssignTargets(data: {
    employee_ids: string[];
    target_count: number;
    period_type: string;
    start_date: string;
    end_date?: string | null;
  }): Promise<{ message: string; created_targets: EmployeeTarget[] }> {
    return request('/targets/batch', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  // Performance Analytics
  async getEmployeeAnalytics(employeeId: string, period: 'daily' | 'weekly' | 'monthly' = 'daily'): Promise<PerformanceAnalytics> {
    return request(`/performance/employee/${employeeId}/analytics?period=${period}`);
  },

  async getTeamComparison(params: { manager_id?: string; date_from?: string; date_to?: string } = {}): Promise<TeamComparison> {
    const query = new URLSearchParams();
    if (params.manager_id) query.append('manager_id', params.manager_id);
    if (params.date_from) query.append('date_from', params.date_from);
    if (params.date_to) query.append('date_to', params.date_to);
    return request(`/performance/team-comparison?${query.toString()}`);
  },

  async getCompanyOverview(): Promise<{
    date: string;
    active_employees: number;
    today_target_sum: number;
    today_verified_visits: number;
    today_submitted_visits: number;
    pending_review_count: number;
    flagged_visits_count: number;
    today_completion_rate: number;
  }> {
    return request('/performance/company-overview');
  },

  // Audit Logs
  async getAuditLogs(params: { skip?: number; limit?: number; action?: string } = {}): Promise<{ items: AuditEvent[]; total: number }> {
    const query = new URLSearchParams();
    if (params.skip !== undefined) query.append('skip', String(params.skip));
    if (params.limit !== undefined) query.append('limit', String(params.limit));
    if (params.action) query.append('action', params.action);
    return request(`/admin/audit-logs?${query.toString()}`);
  },

  // Settings & Media Usage
  async getCloudinaryUsage(activeEmployees: number = 20): Promise<CloudinaryUsageEstimate> {
    return request(`/media/usage-and-costs?active_employees=${activeEmployees}`);
  },
};
