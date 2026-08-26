#!/bin/bash
# Flutter SDK fetcher v2 — strict integrity throughout.
# - fails on any HTTP error body (-f)
# - asserts each segment's exact byte size
# - canary-checks each segment's first 16 bytes against a fresh ranged GET
# - gates extraction on the official sha256
set -u
cd /Users/akshatpratap/HealthOK/.tooling || exit 1

PATH_SUFFIX="stable/macos/flutter_macos_arm64_3.47.1-stable.zip"
U1="https://storage.googleapis.com/flutter_infra_release/releases/$PATH_SUFFIX"
U2="https://storage.flutter-io.cn/flutter_infra_release/releases/$PATH_SUFFIX"

echo "== official metadata =="
META=$(curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
h=d['current_release']['stable']
r=[x for x in d['releases'] if x['hash']==h and x.get('dart_sdk_arch')=='arm64' and x['channel']=='stable'][0]
print('SIZE='+str(r.get('size') or ''))
print('SHA='+str(r.get('sha256') or ''))
")
SIZE=$(printf '%s\n' "$META" | awk -F= '/^SIZE=/{print $2}')
SHA=$(printf '%s\n' "$META" | awk -F= '/^SHA=/{print $2}')
if [ -z "$SIZE" ]; then
  SIZE=$(curl -sIL "$U1" | awk 'tolower($1)=="content-length:"{v=$2} END{printf "%d", v}' | tr -d '\r')
fi
if [ -z "${SIZE:-}" ] || [ -z "${SHA:-}" ]; then
  echo "FATAL: could not resolve official size/sha"; exit 1
fi
case "$SIZE" in ''|*[!0-9]*) echo "FATAL: SIZE not numeric: $SIZE"; exit 1;; esac
echo "SIZE=$SIZE SHA=$SHA"

rm -f flutter.zip   # known-corrupt artifact

PARTS=12
CHUNK=$(( (SIZE + PARTS - 1) / PARTS ))

seg_url() { # alternate mirror per attempt for diversity
  case $(( $1 % 2 )) in 0) echo "$U1";; 1) echo "$U2";; esac
}

fetch_seg() {
  local i=$1 START=$2 END=$3 EXPECTED=$((END - START + 1)) attempt out="seg_$1"
  for attempt in 1 2 3 4 5 6; do
    local U; U=$(seg_url $((i + attempt)))
    echo "seg_$i attempt $attempt ($START-$END) via ${U%%/flutter_infra*}"
    curl -fsL --max-time 900 --retry 2 -r "$START-$END" -o "$out" "$U" || { sleep 3; continue; }
    ACT=$(stat -f%z "$out" 2>/dev/null || echo 0)
    [ "$ACT" -eq "$EXPECTED" ] || { echo "  size $ACT != $EXPECTED"; continue; }
    # canary: first 16 bytes of this range, freshly fetched, must match ours
    if cmp -s <(curl -fsL --retry 2 -r "$START-$((START+15))" "$U" 2>/dev/null) \
              <(head -c 16 "$out"); then
      echo "  seg_$i OK (${EXPECTED} B)"
      return 0
    fi
    echo "  canary mismatch"
  done
  return 1
}

PIDS=()
for i in $(seq 0 $((PARTS-1))); do
  S=$((i*CHUNK)); E=$(( (i+1)*CHUNK - 1 )); [ $E -ge $SIZE ] && E=$((SIZE-1))
  fetch_seg "$i" "$S" "$E" & PIDS+=($!)
done
FAIL=0; for p in "${PIDS[@]}"; do wait "$p" || FAIL=1; done
[ $FAIL -eq 1 ] && { echo "FATAL: segment failures remain"; exit 2; }

cat $(for i in $(seq 0 $((PARTS-1))); do echo "seg_$i"; done) > flutter.zip
ACTUAL_SHA=$(shasum -a 256 flutter.zip | awk '{print $1}')
echo "sha256 actual:   $ACTUAL_SHA"
echo "sha256 official: $SHA"
if [ "$ACTUAL_SHA" != "$SHA" ]; then echo "FATAL: HASH MISMATCH"; exit 4; fi
echo "HASH VERIFIED"

unzip -q flutter.zip && rm -f flutter.zip seg_* && echo "EXTRACTED OK" && ./flutter/bin/flutter --version