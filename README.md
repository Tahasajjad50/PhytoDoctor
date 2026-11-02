# Phyto Doctor — Employee Field Tracking Platform

Phyto Doctor is an offline-first Android employee field-tracking and visit-verification system built for agricultural inputs, fertilizers, and pesticide distribution operations.

## Technology Stack

* **Mobile App:** Flutter & Dart (Android targeting, offline-first SQLite cache, in-app camera only, GPS locking)
* **Backend API:** Python FastAPI with SQLAlchemy 2.0 (Async) & Alembic
* **Database:** PostgreSQL
* **Admin Dashboard:** React 18, TypeScript, and Vite
* **Media Storage:** Cloudinary (compressed WebP delivery with metadata watermarks)
* **Backend Hosting:** Render
* **Source Control:** GitHub

---

## Repository Structure

```
PhytoDoctor/
├── backend/            # FastAPI Python service
│   ├── app/            # API routes, models, schemas, core security & rate limiting
│   ├── alembic/        # Database migration scripts
│   ├── scripts/        # Backup & disaster recovery utilities
│   ├── tests/          # Comprehensive pytest test suite (43 passing tests)
│   └── requirements.txt
├── admin/              # React 19 + TypeScript + Vite Administration Dashboard
│   ├── src/            # Components, pages, RBAC context, API client
│   └── package.json
├── mobile/             # Flutter & Dart Android App (Offline-First)
│   ├── lib/            # Dual login, visit tracking, offline sync, camera, GPS
│   └── pubspec.yaml
├── .github/workflows/  # Automated CI/CD release and testing pipeline
├── render.yaml         # Render Infrastructure-as-Code deployment blueprint
└── docs/               # System architecture and operational runbooks
    ├── ARCHITECTURE.md # Detailed technical specification (Sections 1-12)
    ├── HANDOVER.md     # Production handover, audit verification & QA checklist
    └── PROJECT_PLAN.md # Implementation roadmap
```

---

## Documentation

* [System Architecture & Technical Specification](docs/ARCHITECTURE.md)
* [Production Handover & Audit Report](docs/HANDOVER.md)
* [Phased Implementation Plan & Decisions](docs/PROJECT_PLAN.md)

