# 16 – NOT TESTED & BLOCKED CASES

To maintain technical integrity, the following edge cases were not tested or could not be verified in this cycle:

1. **Hardware Bluetooth Beacon Proximity:** Physical BLE beacons in dealer shops were not physically present; simulated via GNSS coordinate radius.
2. **Real Cloudinary Quota Exhaustion:** Live Cloudinary billable plan was not pushed to quota exhaustion to avoid incurring unnecessary costs.
3. **High-Concurrency Load Testing (>500 simultaneous users):** Load testing against the live production server `https://phytodoctor-api.onrender.com` was strictly excluded to prevent denial-of-service on free tier resources.
4. **Physical iOS Hardware Build:** iOS IPA build was not compiled as verification was conducted on Android and Web environments.
