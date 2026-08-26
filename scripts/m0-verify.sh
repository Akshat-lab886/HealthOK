#!/bin/bash
# M0 device verification: install spike APK on Galaxy Tab A9, launch it,
# and surface Health Connect / plugin logs for evidence.
set -euo pipefail
source "$(dirname "$0")/../tooling-env.sh"

APK="$HEALTHOK_ROOT/apps/health_ok/build/app/outputs/flutter-apk/app-debug.apk"
[ -f "$APK" ] || { echo "FATAL: APK missing: $APK"; exit 1; }

echo "== target device =="
adb devices -l | grep -v "^List"

echo "== install =="
adb install -r "$APK"

echo "== clear logcat & launch =="
adb logcat -c
adb shell am force-stop com.healthok.health_ok || true
adb shell monkey -p com.healthok.health_ok -c android.intent.category.LAUNCHER 1 >/dev/null

echo "== follow relevant logs for 15s (Ctrl-C safe) =="
timeout 15 adb logcat -v time | grep -iE "healthok|health_connect|HealthConnect|flutter|ActivityTask.*healthok" | head -60 || true

echo "== app foreground check =="
adb shell dumpsys activity activities | grep -m1 "topResumedActivity" || true

echo "--- VERIFY SCRIPT DONE (grant HC permission on-device, then press SYNC) ---"
