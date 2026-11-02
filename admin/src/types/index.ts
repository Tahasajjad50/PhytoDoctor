export type UserRole = 'OWNER' | 'MANAGER' | 'EMPLOYEE';

export interface User {
  id: string;
  full_name: string;
  email: string;
  username: string;
  role: UserRole;
  is_active: boolean;
  manager_id?: string | null;
  created_at?: string;
  updated_at?: string;
}

export type VisitStatus = 'PENDING' | 'VERIFIED' | 'REJECTED';

export interface FieldVisit {
  id: string;
  employee_id: string;
  client_name: string;
  client_phone?: string | null;
  notes?: string | null;
  latitude: number;
  longitude: number;
  gps_accuracy: number;
  is_mock_location: boolean;
  device_capture_time: string;
  server_receipt_time: string;
  photo_asset_id: string;
  photo_url?: string | null;
  photo_metadata?: string | null;
  photo_uploaded_at?: string | null;
  status: VisitStatus;
  is_flagged_for_review: boolean;
  review_signals?: string | null;
  clock_drift_seconds?: number | null;
  review_reason?: string | null;
  reviewed_by_id?: string | null;
  reviewed_at?: string | null;
  created_at: string;
}

export interface PaginatedVisits {
  items: FieldVisit[];
  total: number;
  skip: number;
  limit: number;
}

export interface EmployeeTarget {
  id: string;
  employee_id: string;
  target_count: number;
  period_type: string;
  start_date: string;
  end_date?: string | null;
  is_active: boolean;
  created_by_id?: string | null;
  created_at: string;
}

export interface TrendPoint {
  date: string;
  target: number;
  verified_visits: number;
  submitted_visits: number;
}

export interface ReviewReasonItem {
  visit_id: string;
  client_name: string;
  status: string;
  review_reason?: string | null;
  reviewed_at?: string | null;
}

export interface PerformanceAnalytics {
  period_type: string;
  start_date: string;
  end_date: string;
  target_visits: number;
  verified_visits: number;
  remaining_visits: number;
  completion_percentage: number;
  total_submitted_visits: number;
  pending_sync_count: number;
  rejected_visits: number;
  flagged_visits_count: number;
  trend: TrendPoint[];
  review_reasons: ReviewReasonItem[];
}

export interface TeamMemberPerformance {
  employee_id: string;
  employee_name: string;
  employee_email: string;
  target_visits: number;
  verified_visits: number;
  total_submitted_visits: number;
  remaining_visits: number;
  completion_percentage: number;
  rejected_visits: number;
  flagged_visits: number;
}

export interface TeamComparison {
  manager_id: string;
  date_from: string;
  date_to: string;
  team_size: number;
  team_target_total: number;
  team_verified_total: number;
  team_average_completion: number;
  members: TeamMemberPerformance[];
}

export interface AuditEvent {
  id: string;
  actor_id?: string | null;
  actor_role?: string | null;
  action: string;
  affected_record_id?: string | null;
  affected_record_type?: string | null;
  timestamp: string;
  metadata?: Record<string, any> | null;
}

export interface CloudinaryUsageEstimate {
  plan_name: string;
  monthly_credit_allowance: number;
  estimated_monthly_credits_used: number;
  utilization_percentage: number;
  cost_current_usd: number;
  active_employees: number;
  estimated_visits_per_month: number;
  estimated_storage_gb_per_month: number;
  paid_upgrade_required: boolean;
  paid_tier_options: Record<string, any>;
  policy_note: string;
}
