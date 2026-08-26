# Mobile Health-Data Platform APIs — State of the Union for HealthOK (Flutter, local-first)

**Method note:** the delegated `web_search` tool failed on every call ("api key invalid"), so this research was done by direct HTTP retrieval of primary sources (developer.apple.com JSON docs, developer.android.com/developers.google.com pages, pub.dev APIs, GitHub raw files), Aug 26 2026. Where a claim below rests on a source I could not parse/verify, it is flagged **[UNVERIFIED]**.

## 1. Apple HealthKit

**Data types relevant to HealthOK (all `HKQuantityTypeIdentifier` unless noted):** heart rate; HRV as SDNN (`heartRateVariabilitySDNN`, iOS 11+) — there is **no first-class RMSSD identifier** anywhere in Apple's identifier list, so RMSSD must be computed from the beat-to-beat metadata list on SDNN samples (**[UNVERIFIED] exact metadata-key mechanics; absence of RMSSD verified by grep of the full type list**); step count; walking/running distance; active energy; dietary types incl. `dietaryEnergyConsumed`, `dietarySugar` etc.; body mass; body fat percentage; VO2 max (`vo2Max`); oxygen saturation (`oxygenSaturation`); respiratory rate; sleeping-wrist temperature; mindful sessions as a **category type** (`mindfulSession`) alongside sleep analysis (`sleepAnalysis`) (https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier, https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier). Sleep stages (awake/core/deep/REM) were added with iOS 16's sleep-analysis rework **[UNVERIFIED — the enum doc pages returned server errors; could not confirm "iOS 16" from Apple's servers this session]**.

**Permission model:** per-type, per-purpose read/write authorization requested by your app via `HKHealthStore`; users can change grants anytime in Settings → Health → Data Access & Devices, so re-check before reads **[behavior widely known; requestAuthorization doc page could not be fetched — UNVERIFIED]**.

**Background delivery:** `HKObserverQuery` is "a long-running query that monitors the HealthKit store and updates your app when the HealthKit store saves or deletes a matching sample" (https://developer.apple.com/documentation/healthkit/hkobserverquery); combined with `enableBackgroundDelivery` it wakes the app on saves/deletes. For efficient incremental pulls, `HKAnchoredObjectQuery` "returns changes to the HealthKit store, including a snapshot of new changes and continuous monitoring as a long-running query" — i.e., snapshot + delta pattern with a persisted anchor (https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery).

**App Review constraints:** App Review Guideline 5.1.1(i)–(v) covers health data: apps may share health data to third parties only for the user's consented purpose, must have a privacy policy, and can't use HealthKit data for advertising or selling data **[guideline number/wording from memory — my scrape of developer.apple.com/app-store/review/guidelines did not surface the section text; UNVERIFIED]**. The user asked about "1.17": that numbering does not exist in the current guidelines layout I retrieved; the health rules live under 5.1.1 — treat any internal doc citing "1.17" as outdated.

## 2. Google: Fit deprecation vs Health Connect

Google's own pages now state: "The Google Fit APIs, including the Google Fit REST API, will be deprecated in 2026. As of May 1, 2024, developers cannot sign up to use these APIs" (https://developers.google.com/fit), and the migration FAQ says the Fit APIs "will be supported until the end of 2026" with recommended paths: **Health Connect** for mobile-first apps or the new cloud-oriented "Google Health API" (https://developer.android.com/guide/health-and-fitness/health-connect-guidelines/migrate/migration-guide, https://developer.android.com/health-and-fitness/health-connect/migration/fit/faq). The Flutter plugin dropped Google Fit support in v11.0.0 for this reason (https://github.com/carp-dk/carp-health-flutter).

**Storage model:** Health Connect is an on-device intermediary app/framework; your client "allows the app to use the datastore in the Health Connect app," which handles all IPC/serialization to the underlying storage layer — data lives locally with the Health Connect module, not in a Google cloud account (https://developer.android.com/health-and-fitness/guides/health-connect/plan/get-started; architecture overview: https://developer.android.com/health-and-fitness/health-connect/architecture).

**Permissions / Android 14+:** On Android 13 HC ships as a side-loaded APK (`com.google.android.apps.healthdata`); on Android 14 it's part of the framework with privacy controls inside System Settings and OEM theming overlays (https://developer.android.com/health-and-fitness/health-connect/migration/android-13-to-14). Runtime permission flow is standard Android: `PermissionController.createRequestPermissionResultContract()` requesting per-type read/write permissions via Jetpack `androidx.health.connect` (https://developer.android.com/health-and-fitness/guides/health-connect/plan/get-started).

**Approval requirements:** No pre-approval to *use* HC APIs; publishing requires Play Console compliance items: User Data policy, "Permissions and APIs that access sensitive information (including additional requirements for Health Connect)," Data Safety form, and a **Health Apps declaration form** in Play Console (https://developer.android.com/health-and-fitness/guides/health-connect/publish/declare-access).

**Types:** record classes include SleepSessionRecord (with stage detail), HeartRateVariabilityRmssdRecord (RMSSD is native here, unlike HealthKit), NutritionRecord, ExerciseSessionRecord, BodyFatRecord, Vo2MaxRecord, RespiratoryRateRecord, RestingHeartRateRecord, OxygenSaturationRecord, TotalCaloriesBurned, Distance, Steps, Weight, Hydration, BodyTemperature, MindfulnessSessionRecord, PlannedExercise (https://developer.android.com/health-and-fitness/health-connect/data-types).

**Background rules:** background reads exist behind `READ_HEALTH_DATA_IN_BACKGROUND` / constant `PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND` (reference: https://developer.android.com/reference/kotlin/androidx/health/connect/client/permission/HealthPermission). Availability is version-dependent ("This feature is dependent on the version of HealthConnect installed on the device" — check via `HealthConnectFeatures.getFeatureStatus`) (https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient). **[UNVERIFIED] which Android/HC versions gate it and whether Play approval is needed for it.**

## 3. Flutter plugin ecosystem

**`health` (pub.dev):** v13.3.2, published 2026-08-14, publisher **carp.dk**, repo **github.com/carp-dk/carp-health-flutter** — i.e., maintained by the CARP community, **not** Cycling74 and **not** appinio. Score 160/160 points, 676 likes, 138,457 downloads/30d, MIT (https://pub.dev/packages/health, https://pub.dev/api/packages/health/score). Self-described: "Wrapper for Apple's HealthKit on iOS and Google's Health Connect on Android." Plugin needs **iOS ≥15**, ships SwiftPM+CocoaPods; Dart ≥3.8 (README, https://raw.githubusercontent.com/carp-dk/carp-health-flutter/main/README.md).

API shape (from README): `requestAuthorization` per-type read/write; `getHealthDataFromTypes` (interval reads returning `HealthDataPoint`s with sourceId/deviceId/platform); aggregates like `getTotalStepsInInterval`; writes incl. `writeHealthData` (with `RecordingMethod` manual/automatic/active…), `writeMeal` (nutrition), `writeBloodPressure`, audiograms, workout writing via `writeWorkoutData`, and a full **workout-route builder** (`startWorkoutRoute`/`insertWorkoutRouteData`/`finishWorkoutRoute`). It also exposes HC background-read helpers (`isHealthDataInBackgroundAvailable/Authorized`, `requestHealthDataInBackgroundAuthorization`) and `removeDuplicates(points)` for post-fetch in-memory dedup (same README).

Known limitations seen in-repo/docs: HC aggregate support is narrower than raw reads; iOS recording methods only automatic/manual; route building is multi-step. Native HealthKit **recording** (live sessions) is exposed by Apple via HKWorkoutBuilder (iOS 12+) (https://developer.apple.com/documentation/healthkit/hkworkoutbuilder); watchOS-only `HKWorkoutSession` **[UNVERIFIED this session]**. Alternatives found on pub.dev search: `health_kit_wrapper` (iOS-only), `huawei_health`, `health_connector` (popularity unverified beyond existence) (https://pub.dev/api/search?q=health%20kit%20connect).

## 4. How wearable data reaches the stores

Apple Watch writes straight into HealthKit on-device; third-party apps see it via observer/background delivery within seconds-to-minutes **[latency: general knowledge, no official figure — UNVERIFIED]**. On Android, watches sync through vendor apps into Health Connect: Google markets that "Fitbit and Pixel Watch" integrate with Health Connect (https://health.google/health-connect-android/). Samsung Health, Garmin Connect and Xiaomi Mi Fitness are commonly used HC sources **[UNVERIFIED — official support articles for Samsung/Garmin/Mi Band→HC sync could not be reached this session]**. Practical freshness rule: phone stores update when each vendor app syncs (typically after activity ends / periodic BLE sync), so expect minutes-level staleness on Android vs near-real-time on Apple Watch **[UNVERIFIED]**.

## 5. Conflicts, dedup, sync patterns

- Double-count risk: if HealthOK logs a workout AND later reads everything in a window, its own entries return. Filter by `sourceRevision`/source id on HealthKit and `dataOrigin` package name on HC, or tag own writes with custom metadata and exclude it.
- The `health` plugin offers `removeDuplicates` but that is only for duplicate points inside one fetched batch (README above).
- HealthKit incremental pull: persist `HKAnchoredObjectQuery` anchors; the query returns new **and removed** objects, giving delete-propagation (https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery).
- HC incremental pull: use the Changes API/change tokens — Google explicitly warns reads are throttled by "fixed request rate quotas" varying by foreground/background and tells you to "utilize changelog handling to synchronize your database … rather than over-relying on raw read requests"; aggregate endpoints exist separately (https://developer.android.com/health-and-fitness/guides/health-connect/plan/rate-limiting, https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data, https://developer.android.com/guide/health-and-fitness/health-connect/develop/aggregate-data).
- Recommended HealthOK pattern: local-first DB keyed by (type, start, end, source, hash); one anchor/cursor table per platform store; prefer aggregates for steps/calories, anchored/token deltas for everything else; never rewrite derived insights back into HealthKit/HC under your app's source unless intentionally (that's how duplicates happen).

## Explicitly unverified items
Sleep-stage "iOS 16" availability; guideline "1.17"/5.1.1 exact text; HealthKit auto-merge of identical saved samples; RMSSD metadata computation path; HC background-read gating versions/approval; Samsung/Garmin/Mi Fitness→HC sync dates and latency figures; `HKWorkoutSession` watchOS-only claim.

## Sources
- https://developers.google.com/fit
- https://developer.android.com/guide/health-and-fitness/health-connect-guidelines/migrate/migration-guide
- https://developer.android.com/health-and-fitness/health-connect/migration/fit/faq
- https://developer.android.com/health-and-fitness/health-connect/migration/android-13-to-14
- https://developer.android.com/health-and-fitness/guides/health-connect/plan/get-started
- https://developer.android.com/health-and-fitness/health-connect/architecture
- https://developer.android.com/health-and-fitness/health-connect/data-types
- https://developer.android.com/health-and-fitness/guides/health-connect/publish/declare-access
- https://developer.android.com/reference/kotlin/androidx/health/connect/client/permission/HealthPermission
- https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient
- https://developer.android.com/health-and-fitness/guides/health-connect/plan/rate-limiting
- https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data
- https://developer.android.com/guide/health-and-fitness/health-connect/develop/aggregate-data
- https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier
- https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier
- https://developer.apple.com/documentation/healthkit/hkobserverquery
- https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery
- https://developer.apple.com/documentation/healthkit/hkworkoutbuilder
- https://pub.dev/packages/health (+ /score API)
- https://github.com/carp-dk/carp-health-flutter (README)
- https://health.google/health-connect-android/
- https://pub.dev/api/search?q=health%20kit%20connect
