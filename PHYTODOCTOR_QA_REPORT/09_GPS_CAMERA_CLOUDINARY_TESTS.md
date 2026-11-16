# 09 – GPS, CAMERA & CLOUDINARY INTEGRATION TESTS

## 1. GPS Accuracy Verification (<50 Meters)
- **Threshold Rule:** In-app visits require GNSS accuracy <= 50.0 meters.
- **Test Case 1 (Accuracy = 8.5m):** Passed without review flags.
- **Test Case 2 (Accuracy = 82.0m):** Automatically set `is_flagged_for_review = true` and recorded `review_signals = ["LOW_GPS_ACCURACY_82M"]`.

## 2. Mock Location Provider Detection
- Android `Location.isFromMockProvider()` signal is extracted and passed to backend.
- Visits with mock location detected are flagged for supervisor scrutiny. Verified via `test_mock_location_and_clock_drift_detection`.

## 3. In-App Camera Shutter & Watermark
- Mobile app prevents selecting gallery images for field visit evidence.
- Shutter captures embed date, UTC time, agronomist ID, and GPS coordinates into evidence payload.

## 4. Cloudinary Cloud Image Storage
- In development/test environments, asset keys are simulated idempotently.
- In production, signed multipart upload stores compressed image assets under folder `phytodoctor/visits` with delivery URLs mapped to `FieldVisit.photo_url`.
