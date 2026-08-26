#!/usr/bin/env python3
"""Flutter SDK fetcher v3 (Python) — segmented, integrity-checked, self-verifying."""
import concurrent.futures as cf
import hashlib
import io
import json
import sys
import urllib.request
from pathlib import Path

TOOLING = Path("/Users/akshatpratap/HealthOK/.tooling")
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


def official_meta() -> tuple[int, str]:
    d = json.loads(http("https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json", timeout=60))
    h = d["current_release"]["stable"]
    rel = next(r for r in d["releases"]
               if r["hash"] == h and r.get("dart_sdk_arch") == "arm64" and r["channel"] == "stable")
    req = urllib.request.Request(MIRRORS[0], headers={**UA, "Range": "bytes=0-0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        cr = r.headers.get("Content-Range", "")  # e.g. "bytes 0-0/2259049326"
        size = int(cr.rsplit("/", 1)[-1])
    return size, rel["sha256"]


def fetch_segment(idx: int, start: int, end: int) -> tuple[int, bytes]:
    expected = end - start + 1
    last_err: Exception | None = None
    for attempt in range(6):
        url = MIRRORS[(idx + attempt) % len(MIRRORS)]
        try:
            data = http(url, f"{start}-{end}")
            if len(data) != expected:
                raise IOError(f"short read {len(data)} != {expected}")
            canary = http(url, f"{start}-{start+15}", timeout=120)
            if data[:16] != canary:
                raise IOError("canary mismatch")
            print(f"seg_{idx}: OK ({expected} B, attempt {attempt+1}, mirror {(idx+attempt)%2})", flush=True)
            return idx, data
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"seg_{idx}: attempt {attempt+1} failed: {e}", flush=True)
    raise RuntimeError(f"seg_{idx} exhausted retries: {last_err}")


def main() -> None:
    size, want_sha = official_meta()
    print(f"official size={size} sha256={want_sha[:16]}…")
    chunk = (size + PARTS - 1) // PARTS
    jobs = [(i, i * chunk, min((i + 1) * chunk - 1, size - 1)) for i in range(PARTS)]

    blob = bytearray(size)
    done = 0
    with cf.ThreadPoolExecutor(max_workers=PARTS) as ex:
        for idx, data in ex.map(lambda j: fetch_segment(*j), jobs):
            s = jobs[idx][1]
            blob[s:s + len(data)] = data
            done += 1
            print(f"progress: {done}/{PARTS} segments placed", flush=True)

    actual_sha = hashlib.sha256(blob).hexdigest()
    print(f"sha256 actual:   {actual_sha}")
    if actual_sha != want_sha:
        sys.exit(f"FATAL HASH MISMATCH (want {want_sha})")
    print("HASH VERIFIED ✔")

    zip_path = TOOLING / "flutter.zip"
    zip_path.write_bytes(blob)
    print(f"wrote {zip_path} ({zip_path.stat().st_size} B)")

    import zipfile
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(TOOLING)
    zip_path.unlink()
    print("EXTRACTED OK")


if __name__ == "__main__":
    main()
