#!/bin/bash
# Self-healing finisher for the segmented Flutter download:
# resumes every undersized part via ranged appends until complete,
# then assembles, verifies size, extracts, cleans up.
set -u
cd /Users/akshatpratap/HealthOK/.tooling || exit 1

URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.1-stable.zip"
SIZE=2259049326
PARTS=12
CHUNK=$(( (SIZE + PARTS - 1) / PARTS ))

echo "== killing any lingering segment curls =="
pkill -f "curl.*flutter_macos_arm64_3.47.1-stable.zip" 2>/dev/null && echo killed || echo none-running
sleep 2

for round in $(seq 1 40); do
  TOTAL=0; INCOMPLETE=""
  for i in $(seq 0 $((PARTS-1))); do
    EXPECTED=$CHUNK
    [ $i -eq $((PARTS-1)) ] && EXPECTED=$((SIZE - CHUNK*(PARTS-1)))
    ACTUAL=$(stat -f%z "part_$i" 2>/dev/null || echo 0)
    TOTAL=$((TOTAL + ACTUAL))
    if [ "$ACTUAL" -lt "$EXPECTED" ]; then
      START=$ACTUAL; END=$((EXPECTED - 1))
      # ranged append for the missing tail of this segment
      curl -sL --max-time 300 --retry 2 -r "$START-$END" "$URL" >> "part_$i" \
        || echo "round $round: part_$i append interrupted at $(stat -f%z part_$i)"
    fi
  done
  PCT=$((TOTAL * 100 / SIZE))
  echo "round $round: $TOTAL / $SIZE ($PCT%)"
  [ "$TOTAL" -eq "$SIZE" ] && break
  # verify per-part sizes exactly before final assembly
  OK=1
  for i in $(seq 0 $((PARTS-1))); do
    EXPECTED=$CHUNK
    [ $i -eq $((PARTS-1)) ] && EXPECTED=$((SIZE - CHUNK*(PARTS-1)))
    ACTUAL=$(stat -f%z "part_$i" 2>/dev/null || echo 0)
    [ "$ACTUAL" -ne "$EXPECTED" ] && OK=0
  done
  [ $OK -eq 1 ] && { echo "all parts exact"; break; }
done

echo "== assembling =="
cat $(for i in $(seq 0 $((PARTS-1))); do echo "part_$i"; done) > flutter.zip
ACTUAL=$(stat -f%z flutter.zip)
echo "zip: $ACTUAL / $SIZE"
if [ "$ACTUAL" != "$SIZE" ]; then echo "SIZE MISMATCH — aborting"; exit 3; fi

echo "== extracting =="
unzip -q flutter.zip && rm -f flutter.zip part_* && echo "EXTRACTED OK"
ls flutter/bin | head -5