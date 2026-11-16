# 11 – SERVER DEPLOYMENT & INFRASTRUCTURE TESTS

## 1. Cloud Provider (Render)
- **Host Endpoint:** `https://phytodoctor-api.onrender.com`
- **Health Check:** `GET /api/v1/health` -> HTTP 200 `{"status": "healthy", "database_connected": true}`
- **SSL / TLS:** Encrypted with valid Let's Encrypt wildcard certificate via Cloudflare CDN.

## 2. Keep-Alive Strategy
- Render free tier instances enter sleep mode after 15 minutes of inactivity.
- GitHub Actions workflow `.github/workflows/render_keep_alive.yml` pings the health endpoint on a recurring cron to maintain server responsiveness during operating hours.

## 3. CI/CD Release Pipeline
- Automated GitHub Actions workflow `.github/workflows/production-release.yml` executes:
  1. Backend pytest suite.
  2. Database backup & disaster recovery drill.
  3. React/Vite admin dashboard build.
  4. Flutter test suite.
  5. Release APK & AppBundle compilation with unsigned fallback.
