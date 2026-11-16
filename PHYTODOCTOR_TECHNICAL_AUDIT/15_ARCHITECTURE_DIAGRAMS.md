# PhytoDoctor Technical Audit: 15 - Architecture Diagrams

> **Format:** GitHub Flavored Markdown with Native Mermaid Diagrams.

---

## 1. High-Level System Context Diagram

```mermaid
flowchart TD
    subgraph Users["System Actors"]
        Emp["Field Agronomist (Employee)"]
        Mgr["Regional Manager (Admin)"]
        Ceo["Company CEO (Owner)"]
    end

    subgraph MobileApp["PhytoDoctor Mobile Handheld (Flutter Android)"]
        UI["Presentation Layer (18 Screens)"]
        Sync["OfflineSyncManager & Local SQLite"]
        Native["Native Platform Channels (Camera & GPS)"]
    end

    subgraph BackendAPI["PhytoDoctor API (FastAPI on Render.com)"]
        Gateway["CORS & Rate Limiter Pipeline"]
        Routers["12 Domain REST Routers (/api/v1)"]
        AuthModule["JWT & RBAC Dependency Guard"]
        AuditService["Immutable Audit Service"]
    end

    subgraph DataStorage["Persistence & Cloud Services"]
        SQLiteDB[("SQLite Database Engine (phyto_doctor.db)")]
        CloudinaryCDN[("Cloudinary Media CDN (phytodoctor/visits)")]
        GMaps["Google Maps External App Intent"]
    end

    Emp -->|"Logs Visits, GPS & Attendance"| UI
    Mgr -->|"Audits Queue & Staff Roster"| UI
    Ceo -->|"Oversees Quotas & System Metrics"| UI

    UI <--> Native
    UI <--> Sync
    Sync <-->|"REST HTTPS (Bearer JWT)"| Gateway

    Gateway --> AuthModule
    AuthModule --> Routers
    Routers --> AuditService
    Routers <-->|"Async ORM (aiosqlite)"| SQLiteDB
    Routers <-->|"Signed Media Uploads"| CloudinaryCDN
    UI -.->|"External Navigation Intent"| GMaps
```

---

## 2. End-to-End Field Visit Submission & Verification Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Agronomist as Field Agronomist
    participant Mobile as Mobile App (Flutter)
    participant LocalDB as Local SQLite
    participant API as FastAPI Backend
    participant Cloudinary as Cloudinary Edge
    participant DB as Backend SQLite
    actor Manager as Regional Manager

    Agronomist->>Mobile: Captures photo & logs farmer visit
    Mobile->>Mobile: Locks GNSS Coordinates (accuracy, mock check)
    Mobile->>LocalDB: Enqueue Visit (status="pendingSync", client UUID)
    
    alt Device is Online
        Mobile->>Cloudinary: Upload Photo Evidence (Multipart/Signed)
        Cloudinary-->>Mobile: Return photo_url & photo_asset_id
        Mobile->>API: POST /api/v1/visits (VisitCreate + UUID)
        API->>DB: Check UUID Idempotency & Photo Asset Uniqueness
        API->>API: Calculate Clock Drift & Accuracy Review Signals
        API->>DB: Insert FieldVisit (status="PENDING")
        API->>DB: Log AuditEvent("VISIT_CREATED")
        API-->>Mobile: HTTP 201 Created (VisitResponse)
        Mobile->>LocalDB: Update status="synced"
    end

    Manager->>Mobile: Opens Verification Queue
    Mobile->>API: GET /api/v1/visits?status=PENDING
    API->>DB: Query pending visits for supervised team
    API-->>Mobile: Return pending visit list
    Manager->>Mobile: Inspects Photo & Reviews GPS accuracy
    Manager->>Mobile: Taps "Approve" (or "Flag/Reject")
    Mobile->>API: POST /api/v1/visits/{id}/verify {status="VERIFIED"}
    API->>DB: Update FieldVisit status to VERIFIED
    API->>DB: Log AuditEvent("VISIT_VERIFIED")
    API-->>Mobile: HTTP 200 OK
    Manager->>Mobile: Visit counter updates; employee quota achieved
```

---

## 3. Offline Synchronization State Machine

```mermaid
stateDiagram-v2
    [*] --> FormInput : Field officer enters visit
    FormInput --> Enqueued : Shutter pressed & coordinates acquired
    
    state Enqueued {
        [*] --> pendingSync
        pendingSync --> syncing : SyncNow triggered & concurrency unlocked
        syncing --> pendingSync : Interrupted by app termination
        syncing --> synced : Server responds HTTP 200/201
        syncing --> syncFailed : Network socket failure / Server 500
        syncFailed --> syncing : Exponential backoff elapsed (2^n sec)
    }

    synced --> [*] : Verified evidence persisted on server
```

---

## 4. User Authentication & Portal Access Control

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Officer or Admin)
    participant Client as Mobile App
    participant AuthAPI as /api/v1/auth/login
    participant Limiter as In-Memory Rate Limiter
    participant DB as SQLite DB

    User->>Client: Selects Portal ("Field Employee" or "Admin")
    User->>Client: Enters Username/Email & Password
    Client->>AuthAPI: POST /api/v1/auth/login {user, pass, portal}
    AuthAPI->>Limiter: check_rate_limit(user)
    
    alt In Rate Limit Window (>5 failed attempts)
        Limiter-->>AuthAPI: Rate limit exceeded
        AuthAPI-->>Client: HTTP 429 Too Many Requests (15m Lockout)
    else Limit OK
        AuthAPI->>DB: Query User by username or email
        alt User not found OR bcrypt fails
            AuthAPI->>Limiter: record_failed_attempt(user)
            AuthAPI-->>Client: HTTP 401 Unauthorized
        else Credentials Valid
            alt Portal == "admin" AND User is EMPLOYEE
                AuthAPI-->>Client: HTTP 403 Forbidden (Employee blocked from Admin)
            else Portal Verification Passes
                AuthAPI->>DB: Insert RefreshToken (SHA-256 hash)
                AuthAPI-->>Client: HTTP 200 {access_token, refresh_token, role}
                Client->>Client: Store tokens in EncryptedSharedPreferences
                Client->>Client: Route to role-specific dashboard
            end
        end
    end
```

---

## 5. Shift Attendance State Machine

```mermaid
stateDiagram-v2
    [*] --> OffDuty : Initial state on fresh day

    OffDuty --> ActiveDuty : POST /api/v1/attendance/clock-in
    ActiveDuty --> OffDuty : POST /api/v1/attendance/clock-out
    ActiveDuty --> ActiveDuty : Idempotent repeat clock-in

    state ActiveDuty {
        [*] --> OnSiteTracking
        OnSiteTracking --> ActiveOnRoster : Manager views roster
    }

    state OffDuty {
        [*] --> ShiftEnded
        ShiftEnded --> InactiveOnRoster : Manager views roster
    }
```

---

## 6. Mandatory In-App Update Verification Sequence

```mermaid
sequenceDiagram
    autonumber
    actor User as Mobile App User
    participant App as Mobile Handheld
    participant VersionAPI as /api/v1/system/version
    participant BinaryAPI as /api/v1/system/download-apk

    App->>VersionAPI: GET /api/v1/system/version (on boot)
    VersionAPI-->>App: {latest_version, min_required_build_number, force_update}
    
    alt Client buildNumber < min_required_build_number AND force_update == true
        App->>App: Render non-dismissible modal: "Update Required"
        User->>App: Taps "Update Now"
        App->>BinaryAPI: Browser intent downloads PhytoDoctor-release.apk
        App->>App: Application execution blocked until package installed
    else Client Up-to-Date
        App->>App: Continues to normal authentication screen
    end
```
