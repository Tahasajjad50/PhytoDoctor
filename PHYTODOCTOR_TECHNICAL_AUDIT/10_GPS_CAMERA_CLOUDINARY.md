# PhytoDoctor Technical Audit: 10 - GPS, Camera & Cloudinary Integration

> **Domain:** Hardware Sensor Integration, Geolocation Integrity, Media Storage, and Anti-Fraud Pipeline.

---

## 1. Hardware Sensor Pipeline & Native Bridge

```
[Android Hardware]
 ├── Hardware Camera Sensor
 └── GNSS / GPS Satellite Receiver
          │
          │ Android OS Runtime Permissions (ACCESS_FINE_LOCATION, CAMERA)
          v
[Native Platform MethodChannel (com.phytodoctor.fieldapp/native)]
          │
          ├── capturePhoto() -> Launches hardware camera, stores raw JPEG in cache
          ├── checkPermissions() -> Verifies runtime permission state
          └── requestPermissions() -> Prompts Android OS permission request
          │
          v
[Flutter Client Services]
 ├── LocationService (mobile/lib/core/services/location_service.dart)
 ├── PhotoStorageService (mobile/lib/core/storage/photo_storage_service.dart)
 └── CloudinaryUploadService (mobile/lib/core/storage/cloudinary_upload_service.dart)
```

---

## 2. Geolocation Acquisition & Verification Architecture

### 2.1. GPS Accuracy Standards
- **Threshold:** `50.0 meters` (Configured as `GPS_ACCURACY_THRESHOLD_METERS` in `visits.py`).
- **Policy:** Transparently published to clients via `GET /api/v1/visits/evidence-policy`.
- **Handling in Mobile Client:**
  - If `accuracy <= 50.0m`: Interface displays high-precision green badge.
  - If `accuracy > 50.0m`: Prompts user with alert: *"Reported accuracy (±Xm) exceeds the 50m threshold. Please step into an open area away from tin roofs and tap Retry GPS."*
  - **Critical Finding:** The mobile client allows the user to proceed with submission even if accuracy exceeds 50m; in this case, the backend flags the record with `is_flagged_for_review=True` and records signal `LOW_GPS_ACCURACY`.

### 2.2. Anti-Spoofing & Mock Location Detection
- In Android, mock location providers set the `isFromMockProvider` flag.
- The mobile client extracts `is_mock_location: bool` and transmits it in `VisitCreate`.
- If `is_mock_location == True`, the backend flags the visit and attaches signal: `"REPORTED_MOCK_LOCATION: Device reported a mock or simulated location signal."`

### 2.3. Google Maps External Intent Launch
Supervisors evaluating visits in `manager_dashboard_screen.dart` can tap the GPS coordinate string to launch the native Google Maps app via:
```dart
final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
await launchUrl(url, mode: LaunchMode.externalApplication);
```

---

## 3. In-App Camera Evidence Pipeline

### 3.1. Camera Capture Requirements
- **In-App Only:** Submissions strictly prohibit selecting pre-existing gallery photographs.
- **Evidence Shutter:** Photos must be taken live through the in-app camera viewfinder (`camera_capture_screen.dart` or native `capturePhoto`).
- **Device Timestamp:** The shutter capture time is recorded in UTC as `device_capture_time`.

### 3.2. Local Photo File Management
Managed by `mobile/lib/core/storage/photo_storage_service.dart`:
- Saved locally to the application documents directory under `/photos/visit_{uuid}.jpg`.
- Retained until confirmed synchronized with the cloud backend.
- Pruning policy: Files are safely pruned only after 30 days of confirmed synchronization.

---

## 4. Cloudinary Cloud Media Integration

### 4.1. Configuration & Constraints
Defined in `backend/app/core/config.py`:
- `CLOUDINARY_FOLDER`: `"phytodoctor/visits"`
- `CLOUDINARY_MAX_FILE_SIZE_BYTES`: `10 * 1024 * 1024` (10 MB maximum)
- `CLOUDINARY_ALLOWED_EXTENSIONS`: `["jpg", "jpeg", "png", "webp"]`
- `CLOUDINARY_ALLOWED_MIME_TYPES`: `["image/jpeg", "image/png", "image/webp"]`

### 4.2. Upload Workflows Supported

The architecture supports two distinct upload models:

1. **Direct Backend Streaming (`POST /api/v1/media/visits/{id}/photo`):**
   - Client sends multipart file stream directly to FastAPI backend with Bearer token.
   - Backend streams file to Cloudinary using Python SDK with server-side API credentials.
   - Saves `photo_url`, `photo_asset_id` (Cloudinary `public_id`), and dimensions in database.
2. **Two-Step Client Signed Upload (`POST /api/v1/media/visits/{id}/photo-upload-authorization`):**
   - Client requests upload signature from backend.
   - Backend generates HMAC-SHA1 signature using Cloudinary API Secret.
   - Client uploads directly to Cloudinary edge servers without exposing secrets.
   - Client confirms association via `POST /api/v1/media/visits/{id}/confirm-photo`.

### 4.3. Dynamic Image Transformations
Configured in `CloudinaryUploadService`:
- **Thumbnail Variant:** `c_fill,w_300,h_300,g_auto,q_auto,f_auto` (Used for fast-loading list cards in manager verification queue).
- **Preview Variant:** `q_auto,f_auto` (Automatic WebP/AVIF compression with quality optimization for full-screen inspection).

### 4.4. Cloudinary Usage & Plan Tier Analysis
Documented in `app/schemas/media.py:CloudinaryUsageEstimateResponse`:
- Current Operational Tier: **Cloudinary Free Plan** (25 monthly credits).
- Average monthly credit consumption: ~6.8 credits (~27% utilization for a 20-officer field team submitting ~5,200 visits/month).
- Paid upgrade policy: Upgrades to Plus ($89/mo) or Advanced ($224/mo) are only required if field team exceeds 75 active officers.

---

## 5. Backend Fraud-Aware Review Signals

During `POST /api/v1/visits`, the backend evaluates four non-blocking integrity checks:

| Signal Identifier | Condition | Threshold | Supervisor Review Signal Attached |
|-------------------|-----------|-----------|-----------------------------------|
| `LOW_GPS_ACCURACY` | Reported GNSS radius | `> 50.0 meters` | `"LOW_GPS_ACCURACY: Reported accuracy {x}m exceeds 50.0m threshold."` |
| `REPORTED_MOCK_LOCATION` | Device mock provider | `True` | `"REPORTED_MOCK_LOCATION: Device reported a mock or simulated location signal."` |
| `IMPLAUSIBLE_DEVICE_CLOCK`| Device capture vs Server UTC | `< -300 seconds` (>5m in future) | `"IMPLAUSIBLE_DEVICE_CLOCK: Device capture time is {x}s in the future."` |
| `SUSPICIOUS_UPLOAD_DELAY` | Device capture vs Server UTC | `> 86,400 seconds` (>24h delay) | `"SUSPICIOUS_UPLOAD_DELAY: Photo capture occurred {x}h prior to server upload."` |

> **Audit Clarification:** These review signals do not block visit submission; rather, they mark `is_flagged_for_review = True`, drawing the supervisor's attention in the verification queue.
