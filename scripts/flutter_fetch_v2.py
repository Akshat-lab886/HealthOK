#!/usr/bin/env python3
"""Flutter SDK fetcher v4 — segmented, RESUMABLE (segments cached to disk),
canary-checked, sha256-gated. Re-run safely: finished segments are skipped."""
import concurrent.futures as cf
import hashlib
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

TOOLING = Path("/Users/akshatpratap/HealthOK/.tooling")
SEG_DIR = TOOLING / "segs"
ZIP_PATH = TOOLING / "flutter.zip"
FLUTTER_BIN = TOOLING / "flutter" / "bin" / "flutter"
PATH_SUFFIX = "stable/macos/flutter_macos_arm64_3.47.1-stable.zip"
MIRRORS = [
    f"https://storage.googleapis.com/flutter_infra_release/releases/{PATH_SUFFIX}",
    f"https://storage.flutter-io.cn/flutter_infra_release/releases/{PATH_SUFFIX}",
]
PARTS = 12
UA = {"User-Agent": "HealthOK-M0/1.0"}


def http(url: str, rng: str | None = None, timeout: int = 600) -> bytes:
    req = urllib.request.Request(url, headers={**UA, **({"Range": f"bytes={rng}"} if rng else {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def official_sha() -> str:
    d = json.loads(http("https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json", timeout=60))
    h = d["current_release"]["stable"]
    rel = next(r for r in d["releases"]
               if r["hash"] == h and r.get("dart_sdk_arch") == "arm64" and r["channel"] == "stable")
    return rel["sha256"]


def official_size() -> int:
    req = urllib.request.Request(MIRRORS[0], headers={**UA, "Range": "bytes=0-0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return int(r.headers["Content-Range"].rsplit("/", 1)[-1])


def fetch_segment(idx: int, start: int, end: int) -> None:
    out = SEG_DIR / f"seg_{idx}"
    expected = end - start + 1
    if out.exists() and out.stat().st_size == expected:
        print(f"seg_{idx}: cached ✔", flush=True)
        return
    tmp = SEG_DIR / f"seg_{idx}.part"
    last_err: Exception | None = None
    for attempt in range(8):
        url = MIRRORS[(idx + attempt) % len(MIRRORS)]
        try:
            data = http(url, f"{start}-{end}")
            if len(data) != expected:
                raise IOError(f"short read {len(data)} != {expected}")
            canary = http(url, f"{start}-{start+15}", timeout=120)
            if data[:16] != canary:
                raise IOError("canary mismatch")
            tmp.write_bytes(data)
            tmp.replace(out)
            print(f"seg_{idx}: OK ({expected} B, attempt {attempt+1})", flush=True)
            return
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"seg_{idx}: attempt {attempt+1} failed: {e}", flush=True)
    raise RuntimeError(f"seg_{idx} exhausted retries: {last_err}")


def main() -> None:
    SEG_DIR.mkdir(parents=True, exist_ok=True)
    size = official_size()
    want_sha = official_sha()
    print(f"official size={size} sha256={want_sha[:16]}…", flush=True)

    chunk = (size + PARTS - 1) // PARTS
    jobs = [(i, i * chunk, min((i + 1) * chunk - 1, size - 1)) for i in range(PARTS)]

    failed = False
    with cf.ThreadPoolExecutor(max_workers=PARTS) as ex:
        for fut in cf.as_completed([ex.submit(fetch_segment, *j) for j in jobs]):
            try:
                fut.result()
            except RuntimeError as e:
                failed = True
                print(f"SEGMENT FAILED: {e}", flush=True)

    # resumability: incomplete run just exits nonzero; re-run to top up
    missing = [i for i, s, e in jobs
               if not (SEG_DIR / f"seg_{i}").exists()
               or (SEG_DIR / f"seg_{i}").stat().st_size != e - s + 1]
    if failed or missing:
        sys.exit(f"INCOMPLETE — re-run to resume. missing={missing}")

    sha = hashlib.sha256()
    with ZIP_PATH.open("wb") as zf:
        for i, s, _e in jobs:
            data = (SEG_DIR / f"seg_{i}").read_bytes()
            sha.update(data)
            zf.write(data)
    actual = sha.hexdigest()
    print(f"sha256 actual:   {actual}", flush=True)
    if actual != want_sha:
        sys.exit(f"FATAL HASH MISMATCH (want {want_sha}) — delete segs/ and retry")
    print("HASH VERIFIED ✔", flush=True)

    with zipfile.ZipFile(ZIP_PATH) as z:
        z.extractall(TOOLING)
    ZIP_PATH.unlink()
    print("EXTRACTED OK", flush=True)


if __name__ == "__main__":
    main()
