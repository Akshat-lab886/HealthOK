# 07 · Privacy & Security Architecture

> The brand promise is structural, not contractual: **there is no server to breach.** Related: [02 §7](02-architecture.md) · platform policy constraints in [06 §2.4](06-health-platform-sync.md).

---

## 1. Threat Model

| # | Threat | Likelihood | Mitigation |
|---|---|---|---|
| T1 | Cloud breach of health data | **eliminated** | no cloud exists |
| T2 | Device thief extracts DB/model | med | SQLCipher AES-256 + key bound to hardware keystore; app-lock gate |
| T3 | Local malware/root reads our sandbox | low-med | standard OS sandbox; nothing extra we can do honestly — documented, not overstated |
| T4 | Network interception during the *one* optional model download | low | TLS + SHA-256 manifest pinning; download disabled unless user opens Settings→Models |
| T5 | Shared-device snooping (family tablet — our own test device is exactly this!) | **high** | biometric/passcode app-lock; privacy blur on app switcher snapshot |
| T6 | Shoulder-surfing | med | readiness score masking toggle; notification redaction (content hidden on lockscreen) |
| T7 | Backup leakage (iTunes/ADB backups) | med | exclude DB key from backups (`ThisDeviceOnly` Keychain class / Keystore non-exportable); encrypted-backup-only guidance in export flow |
| T8 | LLM emitting sensitive info into system logs | low-med | release builds strip all health-content logging; coach isolate memory freed post-session |
| T9 | Malicious model file swap | low | SHA-256 verified manifests; assets in app-signed bundle for Tier A |

## 2. Data Inventory & Classification

| Class | Examples | Storage | Leaves device? |
|---|---|---|---|
| C1 Identity-lite | birth year band, sex, height | profile table, encrypted | never |
| C2 Raw biometrics | HR, HRV, sleep, steps, weight | `samples` etc., encrypted | never |
| C3 Derived insights | readiness, trends, anomalies | derived tables, encrypted | never |
| C4 Free-text | coach chats, meal notes | encrypted | never |
| C5 Media | meal photos, GPS routes | app-private files, encrypted container | never |
| C6 Model weights | GGUF files | signed asset / downloaded bundle | n/a (code-like) |

**No analytics SDKs, no ads SDKs, no crash SDKs** are linked into release builds (NFR-P4). Release binary audit greps for known SDK package signatures in CI.

## 3. At-Rest Protections

1. **DB:** Drift/SQLite wrapped in SQLCipher, AES-256, page HMAC integrity.
2. **Key custody:** random 32-byte DB key wrapped by iOS Keychain (`kSecAttrAccessibleThisDeviceOnly` — excluded from device backups) / Android Keystore (StrongBox when present; non-exportable).
3. **Files:** meal photos & exports live in an encrypted sub-container (same key hierarchy); GPS routes included (they're location history).
4. **Model assets:** integrity-checked at load ([04 §7](04-on-device-ai.md)); treated as code, not user data.
5. **Memory:** KV-cache and context packs zeroed after chat sessions; no health values in exception messages.

## 4. In-Transit Posture

Default state: **zero network endpoints compiled in.** The optional Tier-B model downloader is a lazily-registered module that activates only from Settings→Models, speaks TLS 1.3 to a fixed release-host allowlist, and validates the manifest signature + payload hash before install ([04 §7](04-on-device-ai.md)). Airplane-mode test doubles as the privacy regression test.

## 5. Access Control UX

- **App Lock:** FaceID/fingerprint/passcode gate on launch and after 5 min backgrounded; graceful tablet mode (shared device = lock ON by default, onboarding explains why).
- **Notification hygiene:** quest reminders show title only; body content suppressed on lockscreen; quiet hours honored ([01 FR-I](01-prd.md)).
- **Screenshot guard:** coach screen flagged `FLAG_SECURE` (Android) / blurred snapshot (iOS) — optional toggle.
- **Export flows require recent auth** (device credential re-prompt).

## 6. Regulatory Posture (honest minimalism)

| Regime | Position |
|---|---|
| GDPR | We are controller/processor of *nothing* (no remote processing, no telemetry). Rights to access/portability/erasure are satisfied literally by FR-H1/H2 export+delete. No DPA needed because there's no third party. |
| India DPDP Act | Same posture; consent notice at onboarding describes purely-local processing in plain language (supports planned HI localization). |
| HIPAA | Not applicable (consumer app, no covered-entity relationship) — stated plainly in FAQ to prevent confusion. |
| Apple Guideline 5.1.1(i)–(v) | Purpose limitation honored trivially; privacy-policy URL published describing local-only handling; "Data Not Collected" nutrition label. |
| Google Play | Data safety form: no collection, no sharing; Health Apps declaration completed ([06 §1](06-health-platform-sync.md)). |

## 7. Privacy Policy & Transparency Artifacts

- In-app **Privacy Ledger**: static screen enumerating every permission, what it unlocks, and a live indicator of network module state (armed/disarmed).
- Public privacy policy: short, versioned in-repo (`PRIVACY.md`), diff-auditable — marketing advantage and compliance artifact in one.
- Vulnerability disclosure: `security@` inbox + coordinated-disclosure note in README (no bug bounty v1).

## 8. Security Engineering Practices

- Dependency review gate (pub.dev scorecard + license scan) in CI; lockfiles committed.
- FFI surface minimized & fuzz-smoked (malformed GGUF header corpus) — native crashes must never corrupt DB (WAL + checkpoint discipline).
- Threat-model review checkpoint at each milestone gate ([09](09-roadmap.md)); T5/T6 validated manually on Galaxy Tab A9 (shared-tablet scenario is our daily driver).

---
*Next: [08 · Competitive Research](08-competitive-research.md)*
