#!/bin/bash
# M0 scaffold: generate Flutter platform scaffolding and merge it into the
# HealthOK app shell without touching our hand-written lib/ and pubspec.yaml.
set -euo pipefail
source "$(dirname "$0")/../tooling-env.sh"

SKEL="$HEALTHOK_ROOT/.tooling/skeleton"
APP="$HEALTHOK_ROOT/apps/health_ok"

echo "== flutter doctor (toolchain sanity) =="
flutter doctor -v 2>&1 | grep -E "Flutter|Android|toolchain|✓|✗|\!" | head -12 || true

echo "== generating platform skeleton =="
rm -rf "$SKEL"
flutter create "$SKEL" --project-name health_ok --org com.healthok --platforms=android

echo "== merging android/ into app shell =="
rm -rf "$APP/android"
cp -R "$SKEL/android" "$APP/android"
rm -rf "$SKEL"

cd "$APP"
echo "== flutter pub get =="
flutter pub get

echo "--- SCAFFOLD DONE ---"
