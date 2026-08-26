# 06 · Health Platform Sync — Apple HealthKit & Google Health Connect

> **Research status:** this doc integrates primary-source verification (fetched directly from developer.apple.com / developer.android.com / pub.dev during research; see [research dossier](../reports/health-data-platforms-2025.md)). Remaining low-confidence items are flagged inline and re-checked at build time.
> Related: ingestion schema [03 §2.1](03-data-model.md) · sync module [02 §2](02-architecture.md).

---

## 1. Platform Landscape (why Health Connect is the only Android path)

> *"The Google Fit APIs, including the Google Fit REST API, will be deprecated in 2026. As of May 1, 2024, developers cannot sign up to use these APIs."* — developers.google.com/fit [V]

| Fact | Detail | Source |
|---|---|---|
| Fit APIs sunset | Signups closed 2024-05-01; support until end of 2026 | [V] developers.google.com/fit |
| Migration targets | **Health Connect** (mobile-first) or new cloud "Google Health API" (not for us — local-first) | [V] developer.android.com migration guide |
| HC storage model | On-device intermediary app/module; IPC to local datastore; **no Google cloud account involved** | [V] developer.android.com architecture/get-started |
| HC platform integration | Android 13: side-loaded APK (`com.google.android.apps.healthdata`); Android 14+: in-framework, controls in System Settings | [V] android-13-to-14 page |
| Publishing requirement | No pre-approval to *use* HC, but Play requires User Data policy compliance, Data safety form, sensitive-permission declaration + **Health Apps declaration form** | [V] declare-access page |
| Background reads | Gated behind `READ_HEALTH_DATA_IN_BACKGROUND`; availability version-dependent — check via `HealthConnectFeatures.getFeatureStatus` | [V] HealthPermission/HealthConnectClient refs |

**Decision:** HealthKit on iOS, Health Connect on Android, consumed through one internal adapter interface. Zero code against Google Fit APIs.

## 2. Apple HealthKit Deep Dive

### 2.1 Datatypes we consume ([03 §2.1](03-data-model.md) type ↔ HK identifier)

| HealthOK type | HealthKit identifier | Notes |
|---|---|---|
| heart_rate | `HKQuantityTypeIdentifier.heartRate` | samples w/ beat-to-beat metadata |
| hrv_sdnn | `heartRateVariabilitySDNN` | **SDNN is the only native HRV type — no RMSSD identifier exists** in the identifier list [V]. RMSSD, if ever needed, must be derived from beat-to-beat metadata on SDNN samples (mechanics to verify) [U med] |
| sleep stages | `sleepAnalysis` category | stage enum values arrived with iOS 16 rework [U high] |
| steps / distance | `stepCount`, `distanceWalkingRunning` | prefer aggregate queries |
| active/basal energy | `activeEnergyBurned`, `basalEnergyBurned` | |
| nutrition | `dietaryEnergyConsumed`, macro identifiers (~40 dietary types exist) [U high] | we write these from meals |
| body mass/fat | `bodyMass`, `bodyFatPercentage` | |
| vo2max / spo2 / resp rate | `vo2Max`, `oxygenSaturation`, `respiratoryRate` | watch-sourced typically |
| mindful session | `mindfulSession` (category) | future feature hook |

### 2.2 Authorization semantics — read is silently deniable
Per-type read/write authorization via `HKHealthStore`; users may revoke anytime in Settings → Health → Data Access & Devices [U high]. **Critical:** `authorizationStatus(for:)` reliably reflects *write* permission only; a denied *read* looks identical to "no data exists" — the OS returns empty results without error [U high].
→ UX rule: never show "permission denied" for reads; show data-freshness state ("No HRV data yet") + settings deep-link.

### 2.3 Incremental sync machinery
- `HKObserverQuery`: long-running matcher; with `enableBackgroundDelivery(.immediate)` it wakes the app in background when matching data lands [V hkobserverquery doc].
- `HKAnchoredObjectQuery`: snapshot + continuous delta with **persisted anchors**, deltas include **deletions** [V hkanchoredobjectquery doc].
- Our pattern: per-datatype anchor persistence (`sync_state.anchor`) + observer setup at launch; anchor invalidation → bounded resync window.
- Workout recording fidelity: native path uses `HKWorkoutBuilder` (iOS 12+) [V]; route building is multi-step (`startWorkoutRoute`/`insert…`/`finish…`) — exposed by the plugin accordingly.

### 2.4 App Review constraints
Health rules live under **Guideline 5.1.1(i)–(v)**: purpose-limited sharing, required disclosure, no ad-platform use of HealthKit data [V layout; exact text re-verify at submission]. (Older references to "1.17" are outdated numbering.) Privacy-policy URL still mandatory even though we ship no data collection — see [07 §7](07-privacy-security.md).

## 3. Google Health Connect Deep Dive

### 3.1 Record types ↔ HealthOK types

| HealthOK type | HC record | Notes |
|---|---|---|
| hrv_rmssd | `HeartRateVariabilityRmssdRecord` | **RMSSD native here — mismatch vs iOS SDNN**, see §5 |
| sleep | `SleepSessionRecord` + stage rows | maps cleanly |
| workouts | `ExerciseSessionRecord` | |
| steps/distance/calories | `StepsRecord`, `DistanceRecord`, `TotalCaloriesBurnedRecord` | aggregate reads preferred |
| nutrition/water | `NutritionRecord`, `HydrationRecord` | write from our meal log |
| rhr/spo2/resp/weight/bodyfat/vo2max/temp | corresponding records incl. `BodyTemperatureRecord`, `MindfulnessSessionRecord`, `PlannedExercise` | [V data-types page] |

### 3.2 Permissions & background
- Runtime flow: Jetpack `PermissionController.createRequestPermissionResultContract()`, per-type read/write strings [V get-started].
- Foreground reads are default; background needs `READ_HEALTH_DATA_IN_BACKGROUND` + version gating via `getFeatureStatus` [V refs; approval-gating details U med].
- Fallback ladder if background grant unavailable: (1) foreground-service sync window after workout sessions (`foregroundServiceType="health"` [U med-high]), (2) WorkManager periodic pull every ~15 min, (3) pull-on-app-open. Readiness card computes lazily on first open regardless — product never blocks on sync.

### 3.3 Rate limits & changelog mandate
Google documents fixed request-rate quotas and explicitly instructs: *"utilize changelog handling to synchronize your database … rather than over-relying on raw read requests"* [V rate-limiting/sync-data pages].
→ Our sync engine is changelog/token-first everywhere: `ChangesApi` token per datatype persisted in `sync_state`; token invalidation → full-window resync (bounded, backoff).

## 4. Flutter Plugin Profile: `health`

| Attribute | Verified status |
|---|---|
| Version studied | v13.3.2 (published 2026-08-14) [V pub.dev] |
| Publisher / repo | **carp.dk** · github.com/carp-dk/carp-health-flutter (MIT) — *not* Cycling74/appinio as commonly mis-cited [V] |
| Score | 160/160 points, 676 likes, ~138k downloads/30d [V score API] |
| Requirements | iOS ≥15 (SwiftPM+CocoaPods), Dart ≥3.8 [V] |
| API surface used | `requestAuthorization`; `getHealthDataFromTypes` (typed `HealthDataPoint` w/ sourceId/platform); aggregates (`getTotalStepsInInterval`); writes (`writeHealthData` + RecordingMethod, `writeMeal`, `writeWorkoutData`, route builder); HC background-read helpers (`isHealthDataInBackgroundAvailable/Authorized`, `requestHealthDataInBackgroundAuthorization`) [V README] |
| Known gaps | No iOS background-delivery plumbing exposed; in-batch `removeDuplicates` only; thin nutrition-write fidelity; Google Fit support already removed (v11) [V README/U med] |

**Containment strategy:** all plugin usage sits behind our `sync` package's `HealthStoreAdapter` interface ([02 §2](02-architecture.md)). If iOS background delivery or richer metadata access is needed beyond the plugin, we add a thin private channel (`HKObserverPlugin`) rather than forking the plugin.

## 5. Cross-Platform Normalization Rules

1. **HRV unit split:** iOS delivers SDNN, Android RMSSD — different metrics! Policy: store raw value + unit tag exactly as delivered (`samples.type` carries `…_sdnn` / `…_rmssd` separately); readiness engine computes z-scores **per metric-source stream**, never mixing SDNN and RMSSD in one baseline ([04 §2.1](04-on-device-ai.md)).
2. **Sleep stage enums:** map both platforms onto our canonical set (`awake|rem|core|deep|asleep_unspecified|in_bed`); unknown → unspecified, never guessed.
3. **Workout type dictionary:** internal enum ← HK workout activity + HC exercise type; unmapped → `other` preserving raw string.
4. **Units:** normalize to SI at ingestion boundary (ms, meters, ml, kcal, bpm); display layer converts per user units setting.

## 6. Write-back & Dedup Contract (FR-A2/A3)

- **We write only self-authored data:** workouts recorded in-app, water, meals. Tagged: HC `Metadata.clientRecordId` + `clientRecordVersion` for idempotent upserts; HealthKit custom reverse-DNS metadata key (`com.healthok.origin`) + pre-insert lookup [U high patterns, standard practice].
- **Read-side exclusion:** dashboard queries filter out rows whose source == ourselves when computing platform-derived stats (prevents echo double-count); dedupe key fallback `(type,start,end,value-hash)` guards vendor double-writes.
- **Never write derived insights** (readiness scores etc.) back to platform stores under our source name — that creates duplicate-looking data in other apps and review risk.

## 7. Freshness Expectations (set UI copy accordingly)

| Path | Typical latency |
|---|---|
| Apple Watch → HealthKit | seconds–minutes; observer wakes us [U med] |
| Wear OS 4+ → Health Connect | watch-side direct writes, minutes [U med] |
| Vendor-cloud wearables (Garmin/Samsung/Mi) → HC | minutes–hours, sometimes only on companion-app open [U med] |

Dashboard shows per-card "as of HH:mm" staleness instead of implying live truth.

## 8. Platform Test Matrix (build phase)

| Case | Device/Env | Pass criterion |
|---|---|---|
| First-run permission grant → dashboard populated <60 s | Galaxy Tab A9 (HC), iPhone sim (HK) | FR-A1 |
| Revocation mid-life | revoke all in Settings | graceful manual-mode, no crashes |
| Dual-source duplicates | synthetic writer + platform data | zero dup rows over 7 days |
| Deletion propagation | delete sample in Health app | row removed locally next sync |
| Token invalidation | clear HC permissions/data | bounded resync, no dupes |
| Background freshness | 24 h with app closed | readiness current at morning open (within platform limits) |
| Airplane mode | full session | NFR-P4 zero network calls |

*(Tab A9 runs Health Connect through the Play-services module path; its exact Android version — and therefore in-framework vs APK behavior — confirmed via `adb shell getprop ro.build.version.release` at build kickoff.)*

---
*Next: [07 · Privacy & Security](07-privacy-security.md)*
