#!/usr/bin/env python3
"""Patch the generated Android scaffold for Health Connect access.

Applies (idempotently):
  1. AndroidManifest.xml: HC <queries>, health permissions,
     ACTIVITY_RECOGNITION, rationale intent-filter on MainActivity,
     privacy-policy activity-alias.
  2. MainActivity.kt: FlutterActivity -> FlutterFragmentActivity
     (required on Android 14+ for registerForActivityResult).
  3. build.gradle.kts: minSdk = 26.
"""
import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent.parent / "apps" / "health_ok"
MANIFEST = APP / "android/app/src/main/AndroidManifest.xml"
MAIN_KT = next(
    (APP / "android/app/src/main/kotlin").rglob("MainActivity.kt"), None
)
GRADLE_KTS = APP / "android/app/build.gradle.kts"

PERMS = """\
    <!-- Health Connect (see docs/06-health-platform-sync.md) -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
"""

QUERIES = """\
    <queries>
        <package android:name="com.google.android.apps.healthdata" />
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent>
    </queries>
"""

ALIAS = """\
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
            </intent-filter>
        </activity-alias>
"""

RATIONALE_IF = """\
            <!-- Health Connect: show permissions rationale screen -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
"""


def patch_manifest() -> None:
    text = MANIFEST.read_text()
    changed = False

    if "android.permission.health.READ_STEPS" not in text:
        text = text.replace("</application>", PERMS + "</application>")
        # permissions must sit before <application>; fix ordering:
        text = text.replace(PERMS + "</application>", "</application>")
        m = re.search(r"(<application[^>]*>)", text)
        assert m, "<application> tag not found"
        text = text.replace(m.group(1), PERMS + "\n" + m.group(1), 1)
        changed = True

    if "<queries>" not in text:
        text = text.replace("<application>", QUERIES + "\n    <application>", 1) \
            if "<application>" in text else text
        if "<queries>" not in text:  # application tag has attributes
            m = re.search(r"(<application[^>]*>)", text)
            assert m
            text = text.replace(m.group(1), QUERIES + "\n    " + m.group(1), 1)
        changed = True

    if "VIEW_PERMISSION_USAGE" not in text:
        m = re.search(r"(</activity>)", text)
        assert m, "</activity> not found"
        text = text.replace(m.group(1), m.group(1) + "\n" + ALIAS, 1)
        changed = True

    if "ACTION_SHOW_PERMISSIONS_RATIONALE" not in text.split("queries>")[0] and \
       "ACTION_SHOW_PERMISSIONS_RATIONALE</action>" not in text:
        # add intent-filter INSIDE MainActivity activity block only
        m = re.search(r'(<activity\b[^>]*android:name="\.MainActivity".*?)(</activity>)',
                      text, re.S)
        assert m, "MainActivity activity block not found"
        block = m.group(1)
        patched = block.rstrip() + "\n" + RATIONALE_IF + "    "
        text = text.replace(block, patched, 1)
        changed = True

    MANIFEST.write_text(text)
    print(f"[manifest] {'patched' if changed else 'already ok'}")


def patch_main_kt() -> None:
    if MAIN_KT is None:
        sys.exit("FATAL: MainActivity.kt not found")
    text = MAIN_KT.read_text()
    if "FlutterFragmentActivity" in text:
        print("[main.kt] already ok")
        return
    text = text.replace("FlutterActivity", "FlutterFragmentActivity")
    MAIN_KT.write_text(text)
    print("[main.kt] patched -> FlutterFragmentActivity")


def patch_gradle() -> None:
    text = GRADLE_KTS.read_text()
    if re.search(r"minSdk\s*=\s*26\b", text):
        print("[gradle] minSdk already ok")
        return
    new, n = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", text)
    if n == 0:
        new, n = re.subn(r"minSdkVersion\s*=\s*\d+", "minSdk = 26", text)
    if n == 0:
        sys.exit("FATAL: could not locate minSdk line in build.gradle.kts")
    GRADLE_KTS.write_text(new)
    print("[gradle] minSdk -> 26")


if __name__ == "__main__":
    patch_manifest()
    patch_main_kt()
    patch_gradle()
    print("--- ANDROID PATCHES APPLIED ---")
