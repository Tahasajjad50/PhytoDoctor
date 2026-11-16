# PhytoDoctor Technical Audit: 01 - Project Overview

> **Audit Date:** November 2026  
> **Auditor Role:** Senior Software Architect, Full-Stack Engineer, Security Auditor  
> **Target Application:** PhytoDoctor (Field Agronomist Tracking & Agricultural Verification System)  
> **Repository Root:** `d:\Projects\VS Code\PhytoDoctor`  
> **Current Version:** `1.0.0` (Build `1`)  
> **Scope:** Comprehensive Technical Inspection & Baseline Architectural Discovery (Read-Only)

---

## 1. Executive Summary

**PhytoDoctor** is an enterprise agricultural field operations management and verification platform tailored for agricultural input distributors, crop advisory services, and pesticide/fertilizer manufacturers operating primarily in Pakistan (specifically Southern Punjab agricultural belts such as Multan, Khanewal, Vehari, and Sahiwal).

The core business mission of PhytoDoctor is to:
1. **Enforce Field Accountability:** Verify that field agronomists physically visit farmer fields, crop orchards, and agri-input dealers, eliminating falsified visit logs.
2. **Collect On-Site Proof of Engagement:** Capture in-app camera photographs, tamper-aware GNSS geolocation metrics, and farmer crop diagnostic observations at the point of inspection.
3. **Streamline Supervisor Audits:** Provide Regional Managers (Admins) and Company Leadership (CEO/Owner) with a centralized verification queue where visits are either approved or flagged/rejected with auditable notes.
4. **Monitor Real-Time Quotas & Targets:** Dynamically evaluate daily, weekly, and monthly field visit quotas, eliminating hardcoded performance targets.
5. **Support Resilient Offline Operations:** Allow field agronomists to log visits without continuous mobile data coverage using an offline-first SQLite cache with deterministic background synchronization.

---

## 2. Business Objectives & Operational Domains

```
+-----------------------------------------------------------------------------------+
|                              PHYTODOCTOR ECOSYSTEM                                |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [ Field Agronomist / Employee ]                                                  |
|   - Daily visit target progress (e.g. 6 visits/day)                               |
|   - On-site evidence logging: Client name, phone, notes, GPS coordinates          |
|   - Mandatory in-app camera shutter capture (Cloudinary media hosting)            |
|   - Daily shift attendance (Clock In / Clock Out broadcast to supervisors)        |
|   - Real-time visit history and performance analytics                             |
|   - 1-on-1 direct messaging and company-wide announcements                       |
|                                                                                   |
|  [ Regional Manager / Branch Admin ]                                              |
|   - Supervised verification queue: View submitted visits with photo & map coords  |
|   - One-tap Google Maps external inspection of captured GPS coordinates           |
|   - Visit verification (Approve or Flag/Reject with audit notes)                  |
|   - Customer & dealer territory registration                                      |
|   - Subordinate credential management & WhatsApp/SMS sharing                      |
|   - Daily team attendance roster monitoring                                       |
|                                                                                   |
|  [ Company CEO / Business Owner ]                                                 |
|   - Company-wide oversight: Total visits, verification percentage, active team     |
|   - Global supervision transfer & credential overrides                            |
|   - Quota configuration (company-wide daily visit quota, monthly targets)         |
|   - Universal audit log access across all company operations                      |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## 3. High-Level Architectural Anatomy

PhytoDoctor consists of four distinct architectural sub-systems:

| Sub-System | Primary Technology | Hosting / Target | Repository Location | Primary Function |
|------------|-------------------|------------------|---------------------|------------------|
| **Mobile Client** | Flutter / Dart | Android OS (APK/AAB) | `/mobile` | Field employee handheld interface, camera, GNSS, offline sync |
| **Backend API** | FastAPI / Python 3.11 | Render.com Web Service | `/backend` | REST API, JWT auth, business logic, verification engine |
| **Admin Web App** | React / Vite / TypeScript | Static Build (`/admin/dist`) | `/admin` | Auxiliary administrative web dashboard |
| **CI/CD & Automation** | GitHub Actions / Python | GitHub / Render CLI | `/.github`, `/scripts` | Automated release builder, version publisher, keep-alive |

---

## 4. Key Actors and User Personas

### 4.1. Field Agronomist (`UserRole.EMPLOYEE`)
- **Profile:** Mobile field worker traveling across rural villages and farm clusters.
- **Access Portal:** Field Employee Portal (`portal="employee"`).
- **Core Needs:** Lightweight interface, offline data logging, camera capture, clear daily quota progress, shift attendance.

### 4.2. Regional Manager (`UserRole.MANAGER`)
- **Profile:** Field supervisor managing a territory team (e.g., Punjab Field Team).
- **Access Portal:** Administrator Portal (`portal="admin"`).
- **Core Needs:** Rapid verification workflow, evidence scrutiny (photo preview, Google Maps coordinates), staff attendance roster, credential sharing.

### 4.3. Business Owner / CEO (`UserRole.OWNER`)
- **Profile:** Executive leadership (e.g., Mehmood Ayyaz).
- **Access Portal:** Administrator Portal (`portal="admin"`).
- **Core Needs:** Global company metrics, supervisory hierarchy transfers, system-wide audit logs, quota settings.

---

## 5. Primary Value Propositions vs. Technical Constraints

| Value Proposition | Implementation Mechanism | Inherent Technical Constraint / Finding |
|-------------------|--------------------------|-----------------------------------------|
| **Evidence Immutability** | `photo_asset_id` uniqueness check in database; UUID idempotency keys. | Database currently runs on SQLite (`aiosqlite`) on Render's ephemeral disk. |
| **Anti-Fraud Signals** | Backend checks GNSS accuracy (>50m), Android mock location flags, clock drift (>5 min / >24h). | Signals generate `review_signals` for supervisor review; does not automatically block submission. |
| **Offline Resilience** | Mobile SQLite table (`local_field_visits`) with exponential backoff sync. | Local SQLite rows are held in memory/cache; app restart sync recovery is partially mocked. |
| **Zero Infrastructure Cost** | Render.com Free Tier + Cloudinary Free Plan (25 credits/mo). | Render free tier sleeps after 15 min; cold starts take 30-50s; ephemeral storage wipes DB on redeploy. |

---

## 6. Audit Roadmap & Document Index

This audit report is divided into 18 specialized documentation files:

- [00_MASTER_TECHNICAL_AUDIT.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/00_MASTER_TECHNICAL_AUDIT.md) — Comprehensive Master Index and Executive Findings
- [01_PROJECT_OVERVIEW.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/01_PROJECT_OVERVIEW.md) — Current Document: Business, Domains, & Personas
- [02_PROJECT_STRUCTURE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/02_PROJECT_STRUCTURE.md) — Directory Tree, File Dictionary, & Interdependencies
- [03_TECH_STACK_AND_DEPENDENCIES.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/03_TECH_STACK_AND_DEPENDENCIES.md) — Languages, Frameworks, Libraries, & Versions
- [04_FRONTEND_ARCHITECTURE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/04_FRONTEND_ARCHITECTURE.md) — Flutter Architecture, Screen Inventory, & Navigation
- [05_ROLE_AND_FEATURE_INVENTORY.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/05_ROLE_AND_FEATURE_INVENTORY.md) — Role-Based Feature Matrix & Implementation Status
- [06_BACKEND_ARCHITECTURE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/06_BACKEND_ARCHITECTURE.md) — FastAPI Framework, Routers, Middleware, & Request Lifecycle
- [07_COMPLETE_API_REFERENCE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/07_COMPLETE_API_REFERENCE.md) — Complete REST Endpoint Specifications & Payloads
- [08_DATABASE_SCHEMA.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/08_DATABASE_SCHEMA.md) — SQLAlchemy Models, ER Diagram, Constraints, & Indexes
- [09_AUTHENTICATION_AND_SECURITY.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/09_AUTHENTICATION_AND_SECURITY.md) — JWT, Refresh Tokens, RBAC, Passwords, & Vulnerabilities
- [10_GPS_CAMERA_CLOUDINARY.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/10_GPS_CAMERA_CLOUDINARY.md) — Hardware Sensors, Location Services, & Media Pipeline
- [11_OFFLINE_AND_SYNC_ARCHITECTURE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/11_OFFLINE_AND_SYNC_ARCHITECTURE.md) — SQLite Local Queue, Sync Engine, & Idempotency
- [12_SERVER_AND_DEPLOYMENT.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/12_SERVER_AND_DEPLOYMENT.md) — Render Hosting, Free-Tier Sleep, Keep-Alive, & CI/CD
- [13_EXTERNAL_INTEGRATIONS.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/13_EXTERNAL_INTEGRATIONS.md) — Cloudinary, Google Maps Intents, Android Platform Channels
- [14_EXISTING_TESTING_INFRASTRUCTURE.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/14_EXISTING_TESTING_INFRASTRUCTURE.md) — Pytest Suite, Flutter Unit Tests, CI Validation
- [15_ARCHITECTURE_DIAGRAMS.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/15_ARCHITECTURE_DIAGRAMS.md) — System, Entity-Relationship, Sequence, & State Diagrams
- [16_TECHNICAL_ISSUES_AND_RISKS.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/16_TECHNICAL_ISSUES_AND_RISKS.md) — Prioritized Defect & Architectural Risk Register
- [17_AUDIT_LIMITATIONS_AND_UNVERIFIED_ITEMS.md](file:///d:/Projects/VS%20Code/PhytoDoctor/PHYTODOCTOR_TECHNICAL_AUDIT/17_AUDIT_LIMITATIONS_AND_UNVERIFIED_ITEMS.md) — Inspection Boundaries & Recommendations
