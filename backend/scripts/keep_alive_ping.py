"""
PhytoDoctor - Render Server Keep-Alive Service
Sends an HTTP GET request to Render every 10 minutes to prevent the free instance from spinning down.
"""
import time
import urllib.request
from datetime import datetime

TARGET_URL = "https://phytodoctor-api.onrender.com/api/v1/health"
INTERVAL_SECONDS = 600  # 10 minutes (Render sleeps after 15 min)

print("=" * 60)
print("  PHYTO DOCTOR - RENDER KEEP-ALIVE PINGER")
print(f"  Target: {TARGET_URL}")
print(f"  Interval: Every {INTERVAL_SECONDS // 60} minutes")
print("=" * 60)

while True:
    try:
        req = urllib.request.Request(
            TARGET_URL,
            headers={"User-Agent": "PhytoDoctor-KeepAlive/1.0"}
        )
        with urllib.request.urlopen(req, timeout=20) as res:
            status = res.getcode()
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] PING SUCCESS: Status {status}")
    except Exception as e:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] PING WARNING: {e}")
    
    time.sleep(INTERVAL_SECONDS)

