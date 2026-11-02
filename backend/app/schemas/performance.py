from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class EmployeePerformanceSummary(BaseModel):
    employee_id: str
    employee_name: str
    period: str
    target_visits: int
    completed_today: int
    verified_visits: int
    remaining_visits: int
    pending_sync_count: int
    target_progress_percentage: float
    is_live_data: bool = True

class TrendPoint(BaseModel):
    date: date
    target_count: int
    submitted_count: int
    verified_count: int
    rejected_count: int
    completion_percentage: float

class ReviewReasonItem(BaseModel):
    visit_id: str
    client_name: str
    status: str
    review_reason: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    is_flagged: bool = False
    review_signals: Optional[str] = None

class PerformanceAnalyticsResponse(BaseModel):
    employee_id: str
    employee_name: str
    timeframe: str
    start_date: date
    end_date: date
    target_visits: int
    submitted_visits: int
    verified_visits: int
    remaining_visits: int
    rejected_visits: int
    pending_sync_count: int
    flagged_visits_count: int
    completion_percentage: float
    trend_points: List[TrendPoint] = []
    recent_reviews: List[ReviewReasonItem] = []
    is_live_data: bool = True

class TeamMemberPerformance(BaseModel):
    employee_id: str
    employee_name: str
    manager_id: Optional[str] = None
    target_visits: int
    submitted_visits: int
    verified_visits: int
    remaining_visits: int
    completion_percentage: float
    flagged_visits: int
    rejected_visits: int

class TeamComparisonResponse(BaseModel):
    manager_id: Optional[str] = None
    manager_name: Optional[str] = None
    timeframe: str
    start_date: date
    end_date: date
    team_size: int
    team_total_target: int
    team_total_verified: int
    team_average_completion_pct: float
    members: List[TeamMemberPerformance]

class CompanyPerformanceSummary(BaseModel):
    total_employees: int
    active_employees: int
    today_logged_visits: int
    today_verified_visits: int
    pending_verification_count: int
    verification_rate_percentage: float
    today_target_sum: Optional[int] = 0
    today_submitted_visits: Optional[int] = 0
    today_completion_rate: Optional[float] = 0.0
    pending_review_count: Optional[int] = 0
    flagged_visits_count: Optional[int] = 0

