# Phyto Doctor — Phased Implementation Plan & Roadmap

## 1. Project Overview & Guiding Principles

This implementation plan outlines the incremental construction of the **Phyto Doctor** employee field-tracking platform. 

### Guiding Principles:
1. **Zero Premature Complexity:** Monolithic backend (FastAPI), single relational database (PostgreSQL), and unified offline-first mobile client.
2. **Offline-First Resilience:** Rural field operations must never fail due to missing cellular signal.
3. **Data Integrity Over Speed:** Performance calculations only bind to verified on-site visits with tamper-resistant photo and GPS proof.
4. **Lean Operational Overhead:** Target $0–$7/month hosting cost using free/starter tiers.

---

## 2. Phased Implementation Roadmap

```
Phase 1: Project Scaffolding, RBAC & Core Backend Foundation
   |
Phase 2: Database Schema & REST API (Users, Clients, Visits, Targets)
   |
Phase 3: Flutter Mobile App — Core UI, In-App Camera & Location Engine
   |
Phase 4: Mobile Offline Cache, SQLite & Synchronization Engine
   |
Phase 5: Web Admin Dashboard (Owner & Manager Views, Verification Flow)
   |
Phase 6: Hardening, GPS Anti-Spoofing, End-to-End Testing & Deployment
```

---

### Phase 1: Project Scaffolding & Core Backend Foundation
* **Objective:** Establish the repository structure, Dockerized local environment, and secure authentication flow.
* **Deliverables:**
  1. Standard repository layout: `/backend`, `/mobile`, `/dashboard`, `/docs`.
  2. FastAPI project layout with Pydantic v2 settings, Alembic database migrations, and CORS configurations.
  3. User model, Password hashing (Argon2 / BCrypt), and JWT token handling (Access & Refresh tokens).
  4. Role-based access control (RBAC) middleware for `OWNER`, `MANAGER`, `EMPLOYEE`.
  5. Initial seed script creating the default Owner account.

---

### Phase 2: Database Schema & REST API Endpoints
* **Objective:** Implement full business logic for teams, clients, visits, and targets.
* **Deliverables:**
  1. **User Management API:**
     * Create employee/manager accounts (Owner/Admin only).
     * Assign employees to managers and sales territories.
  2. **Client Management API:**
     * CRUD for agricultural dealers, distributors, and registered farmers.
  3. **Field Visit API:**
     * Endpoint for visit submissions with GPS coordinates, client snapshot, and notes.
     * Batch synchronization endpoint `/api/v1/visits/sync-batch` with idempotency key deduplication.
     * Visit review and verification endpoint `/api/v1/visits/{id}/verify`.
  4. **Performance & Target API:**
     * Daily and monthly target creation and automated verification-based progress aggregation.
  5. **Cloudinary Integration:**
     * Presigned upload signature generation or secure direct upload handler.

---

### Phase 3: Flutter Mobile App — UI, Camera & GPS Engine
* **Objective:** Build the core Android field application UI with strict hardware constraints.
* **Deliverables:**
  1. Flutter clean architecture setup: Presentation, Domain, Data layers (Bloc or Riverpod).
  2. **Strict In-App Camera:** Custom camera view using `camera` plugin; gallery picker completely disabled.
  3. **Location Service:** Geolocator integration capturing high-accuracy coordinates, altitude, accuracy radius, and mock-location flags.
  4. **Visit Creation Form:**
     * Select or search registered client / dealer (or add new on the fly).
     * Live photo capture preview with burned timestamp & coordinate watermark.
     * Visit purpose (sales order, recovery, crop inspection, demonstration).
     * Notes and visit submission.

---

### Phase 4: Mobile Offline Engine & Background Synchronization
* **Objective:** Guarantee reliable offline data collection and background sync.
* **Deliverables:**
  1. Local database schema with **Drift (SQLite)**.
  2. Cache client directory on device for offline lookup.
  3. Local transactional visit saving with status `DRAFT` $\rightarrow$ `QUEUED` $\rightarrow$ `SYNCED`.
  4. Compressed photo caching in private app storage.
  5. **Background Sync Worker:**
     * Network status observer (`connectivity_plus`).
     * Sequential queue processor with exponential retry backoff.
     * Automatic reconciliation of sync states.

---

### Phase 5: Admin Web Dashboard (Owner & Manager)
* **Objective:** Provide a fast, responsive desktop management interface.
* **Deliverables:**
  1. React + TypeScript + Vite project scaffolding with Tailwind CSS.
  2. Authentication with persistent session and role routing.
  3. **Owner Portal:**
     * Executive analytics: Daily visit count, team quota progress, coverage map.
     * User administration: Create/edit staff, assign managers and territories.
     * Target setting: Monthly and daily visit quotas.
  4. **Manager Portal:**
     * Subordinate team member view.
     * Verification queue: Review submitted field visits, check location radius against client address, view full photo proof, and mark `VERIFIED` or `REJECTED`.
  5. **Reports & Export:** Export filtered visit logs to Excel/CSV.

---

### Phase 6: Hardening, Anti-Spoofing & Deployment
* **Objective:** Secure the platform against manipulation and launch production hosting.
* **Deliverables:**
  1. GPS anti-spoofing verification and server-side coordinate validation.
  2. Render Web Service deployment configuration (`render.yaml` or Dockerfile).
  3. Managed PostgreSQL configuration (Neon / Render / Supabase).
  4. Vercel or Netlify deployment for Admin Dashboard.
  5. Android APK build script and signing setup.

---

## 3. Work Breakdown & Status Tracker

| Phase | Milestone | Priority | Status |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Architecture Specification & Project Plan | Critical | **Completed** |
| **Phase 1** | Backend Scaffolding, Models & JWT RBAC Auth | Critical | Ready to start |
| **Phase 2** | Visits, Clients & Targets API Endpoints | High | Queued |
| **Phase 3** | Flutter Mobile App (Camera + GPS Engine) | High | Queued |
| **Phase 4** | SQLite Offline Queue & Sync Engine | Critical | Queued |
| **Phase 5** | React/Vite Admin Web Dashboard | High | Queued |
| **Phase 6** | End-to-End Testing & Production Deployment | Medium | Queued |

---

## 4. Key Decisions & Approvals Needed from Business Owner

Before implementing Phase 1 and Phase 2 code, the following decisions should be aligned:

1. **Client / Farmer Master List:**
   * Will the client list (dealers, distributors, farmers) be pre-seeded by the Owner via Excel/CSV import, or should field officers also be allowed to register new clients while offline in the field?
2. **Visit Geofence Tolerance:**
   * If a client has a registered shop/farm GPS coordinate, what is the acceptable distance radius (e.g., within 200 meters or 500 meters) to qualify for auto-flagging during manager review?
3. **Photo Storage Policy:**
   * Is Cloudinary free tier (25GB/month managed bandwidth) sufficient for your initial pilot? (With WebP compression at ~300KB/photo, this supports ~25,000 to 30,000 photos/month for free).
4. **State Management Preference for Flutter:**
   * Recommendation: **flutter_bloc** (standard enterprise-grade predictability for offline state machines) or **Riverpod**.
