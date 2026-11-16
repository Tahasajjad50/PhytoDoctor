# PhytoDoctor Technical Audit: 13 - External Integrations

> **Scope:** Analysis of all external APIs, third-party software services, native operating system intents, and external hardware bridges integrated into PhytoDoctor.

---

## 1. External Integrations Catalog

```
+-----------------------------------------------------------------------------------+
|                         PHYTODOCTOR EXTERNAL INTEGRATIONS                         |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [ Cloud Media Storage ] ────────► Cloudinary Programmable Media API             |
|                                    - Image hosting, optimization, signed uploads  |
|                                                                                   |
|  [ Mapping & Navigation ] ───────► Google Maps (Native OS Intent)                 |
|                                    - Direct launch with lat/lng query             |
|                                                                                   |
|  [ Social Communication ] ───────► WhatsApp / SMS Share Sheet                     |
|                                    - Subordinate account credential sharing       |
|                                                                                   |
|  [ Device Hardware ] ────────────► Android Native OS Sensors                      |
|                                    - Hardware Camera & GNSS/GPS via MethodChannel |
|                                                                                   |
|  [ CI/CD & Deployment ] ─────────► GitHub Actions & Render Platform API           |
|                                    - Automated testing, build, & deploy hooks     |
|                                                                                   |
|  [ Typography & UI ] ────────────► Google Fonts CDN                               |
|                                    - Plus Jakarta Sans font caching               |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## 2. Cloudinary Media Storage Integration

| Parameter | Configuration Value |
|-----------|---------------------|
| **Service Provider** | Cloudinary Ltd. |
| **API Protocol** | HTTPS REST / Python SDK (`cloudinary>=1.39.0`) |
| **Environment Keys** | `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` |
| **Storage Destination** | `phytodoctor/visits/` |
| **Supported File Formats** | JPEG, PNG, WEBP |
| **Maximum File Size** | 10 MB |

### Security Architecture:
- The Cloudinary API Secret is **strictly kept on the backend** and never compiled into the Flutter mobile application bundle.
- In two-step uploads, the backend generates a short-lived HMAC-SHA1 signature authorizing the mobile device to upload directly to Cloudinary edge nodes without proxying large files through Render.

### Fallback Behavior:
- When running in local development or if Cloudinary keys are omitted, the backend generates synthetic mock image URLs allowing offline and automated testing to proceed without third-party network calls.

---

## 3. Google Maps External Navigation Integration

PhytoDoctor deliberately avoids embedding costly Google Maps JavaScript/Flutter SDK map controllers inside the app, opting instead for **Native OS Geo Intents**:

```dart
final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
if (await canLaunchUrl(url)) {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
```

### Advantages:
1. **Zero Google Maps Platform API Cost:** Does not require Google Maps API billing or SDK keys.
2. **Turn-by-Turn Navigation:** Allows supervisors to tap a field visit or agronomist location and immediately enter native turn-by-turn driving directions in the Google Maps app.
3. **High Reliability:** Operates across all Android devices with Google Play Services installed.

---

## 4. WhatsApp & Android Share Sheet Integration

When a Regional Manager or CEO creates or updates a subordinate's credentials, they can dispatch login details directly via the Android native share sheet:

```dart
NativeShareService.share(
  text: credentialsText,
  title: 'Share Credentials via',
);
```

### Shared Credentials Format:
```
🌿 PhytoDoctor Account Credentials 🌿
Name: Zain Ul Abideen
Phone: 03266227772
Designation: Field Agronomist
Role: FIELD AGRONOMIST / EMPLOYEE
Assigned Portal: Field Employee Portal

Login Credentials:
Username: emp.zain
Email: zainulabideen@phytodoctor.com
Password: [Assigned Password]
```
> **Security Audit Note:** Following recent security hardening, the raw backend server URL (`https://phytodoctor-api.onrender.com`) was explicitly removed from the shared message template to prevent public discovery of the API origin.

---

## 5. Android Platform Channels (`MethodChannel`)

Declared in `mobile/lib/core/services/native_platform_service.dart`:
- **Channel Identifier:** `com.phytodoctor.fieldapp/native`
- **Native Android Handlers (Kotlin/Java):**
  - `requestPermissions`: Interacts with Android `ActivityCompat.requestPermissions`.
  - `capturePhoto`: Launches Android `MediaStore.ACTION_IMAGE_CAPTURE` intent and returns cached file URI.
  - `shareText`: Launches `Intent.createChooser` with `Intent.ACTION_SEND`.

---

## 6. Render Platform API Deployment Hook

Used by `scripts/publish_update.py`:
- Interacts with Render CLI:
  ```bash
  render deploys create srv-dbl3hk08v5cc73ak1tc0 --confirm
  ```
- Allows one-command publication from local workstation to trigger immediate live server rebuild and container deployment.

---

## 7. External Service Failure Modes & Resilience Matrix

| External Dependency | Failure Scenario | Application Behavior / Fallback |
|---------------------|------------------|---------------------------------|
| **Cloudinary** | Quota exceeded / Service outage | Upload fails; photo remains safely preserved in local SQLite queue; retried during next sync cycle. |
| **Google Maps** | Google Maps app not installed | Falls back to opening web browser URL `https://www.google.com/maps/...`. |
| **Render Cloud** | Container sleep (cold start) | Mobile client probes candidate endpoints with a resilient 25-second timeout. |
| **Android GPS** | Satellite lock unavailable (indoors) | Client warns user to step into open area; flags submission as `LOW_GPS_ACCURACY` if submitted. |
| **Google Fonts CDN** | No internet on initial install | Flutter falls back to standard Roboto system font until network connectivity is established. |
