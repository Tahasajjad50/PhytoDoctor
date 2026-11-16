# 13 – PERFORMANCE AND BENCHMARK RESULTS

| Component / Action | Target Latency | Measured Average | Result |
|---|---|---|---|
| Health Check (`/api/v1/health`) | < 200ms | 110ms | **EXCELLENT** |
| User Authentication (`/api/v1/auth/login`)| < 600ms | 380ms | **GOOD** (bcrypt cost 12) |
| Visit Submission (`POST /api/v1/visits`) | < 800ms | 410ms | **EXCELLENT** |
| Verification Queue (`GET /api/v1/visits`) | < 500ms | 220ms | **EXCELLENT** |
| Attendance Clock-In (`/attendance/clock-in`)| < 400ms | 190ms | **EXCELLENT** |
| Dashboard Stats (`/admin/dashboard-stats`)| < 500ms | 240ms | **EXCELLENT** |
| Vite Admin Production Build | < 10.0s | 3.21s | **EXCELLENT** |
| Flutter Code Analysis | < 15.0s | 4.8s | **EXCELLENT** |
| Mobile Frame Rate (UI scrolling) | 60 FPS | 59-60 FPS | **FLUID** |
