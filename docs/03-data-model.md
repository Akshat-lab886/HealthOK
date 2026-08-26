# 03 · Data Model — HealthOK

> Storage engine: **SQLite via Drift, encrypted with SQLCipher** ([02 §3](02-architecture.md)). All timestamps UTC epoch-ms internally; rendered in user-local zone. Cross-ref: platform datatype mapping lives in [06 §3](06-health-platform-sync.md).

---

## 1. Entity-Relationship Overview

```
        ┌────────────┐        ┌────────────────┐
        │  sources    │1      *│  samples        │   (generic time-series:
        │  (apps/devs)├────────<  typed metrics  │    steps, hr, hrv, rhr,
        └────────────┘        └────────────────┘     spo2, weight, water…)
                                   *
        ┌────────────┐             │
        │ sync_state ├─────────────┘ (anchor token per datatype+source)
        └────────────┘
        ┌────────────┐ 1    * ┌───────────────┐ 1    * ┌──────────────┐
        │  workouts   >───────< workout_tracks? >  (route points, opt-in)│
        └────────────┘        └───────────────┘        └──────────────┘
        ┌────────────┐ 1    * ┌───────────────┐
        │sleep_session>───────< sleep_stage_row │
        └────────────┘        └───────────────┘
        ┌────────────┐        ┌───────────────┐
        │   meals     │        │ daily_summary  │ (rollups; kept forever)
        └────────────┘        └───────────────┘
        ┌────────────┐        ┌───────────────┐        ┌────────────┐
        │   player    │1     *<  quests         >*───────< xp_events    │
        └────────────┘        └───────────────┘        └────────────┘
        ┌────────────┐        ┌───────────────┐
        │coach_message│        │ insight_card   │
        └────────────┘        └───────────────┘
        ┌────────────┐        ┌───────────────┐
        │user_profile │        │ baselines      │ (rolling stats per metric)
        └────────────┘        └───────────────┘
```

## 2. Table Definitions (Drift/SQL)

### 2.1 Ingestion domain

**sources**
| col | type | notes |
|---|---|---|
| id | int PK autoincr | |
| platform_key | text unique | e.g. `hk:com.apple.health`, `hc:com.google.android.apps.fitness`, `local:healthok` |
| display_name | text | |

**samples** — one row per metric datapoint *(the workhorse)*
| col | type | notes |
|---|---|---|
| id | int PK autoincr | |
| type | text indexed | enum string: `step_count, heart_rate, resting_heart_rate, heart_rate_variability_sdnn, heart_rate_variability_rmssd, respiratory_rate, oxygen_saturation, vo2max, body_mass, body_fat_pct, water_ml, dietary_energy_kcal, dietary_protein_g, dietary_carbs_g, dietary_fat_g, active_energy_kcal, basal_energy_kcal, exercise_minutes, distance_walking_running` |
| start_at, end_at | int (epoch ms) | composite index `(type, start_at)` |
| value_num | real nullable | scalar value when applicable |
| meta | text (json) | extra fields (e.g., HR sampling context) |
| source_id | int FK→sources | |
| external_id | text nullable | platform UUID / HC record id — **dedupe key**: unique `(type, source_id, external_id)` where present; fallback hash `(type,start_at,end_at,value_num)` |
| created_at | int | ingestion time |
| *(rule)* | — | **HRV streams stay separate:** `…_sdnn` (iOS-native) and `…_rmssd` (Android-native) are stored as distinct types; baselines never mix them ([06 §5](06-health-platform-sync.md)) |

**workouts**
| col | type |
|---|---|
| id, source_id | PK / FK |
| external_id | dedupe like samples |
| type | text (`run, walk, cycle, strength, yoga, other`) |
| start_at, end_at, distance_m, energy_kcal, avg_hr, max_hr, step_count | numeric |
| intensity_meta | json (HR-zone minutes) |
| route_path | text nullable (encoded polyline; only if GPS session from us) |

**sleep_sessions** / **sleep_stages**
session: `id, source_id, external_id, start_at, end_at, total_min, efficiency_pct nullable`
stage rows: `session_id FK, stage ('awake','rem','core','deep','asleep_unspecified','in_bed'), start_at, end_at`

**sync_state**
`data_type text, store ('healthkit'|'healthconnect'), anchor text (opaque cursor/token), last_pull_at int, PRIMARY KEY(data_type, store)`

### 2.2 Derived/analytics domain

**daily_summary** (rebuilt idempotently from samples)
`date (yyyy-mm-dd PK-ish), steps, distance_m, active_kcal, exercise_min, sleep_main_min, sleep_efficiency, water_ml, kcal_in, protein_g, carbs_g, fat_g, weight_kg_latest, resting_hr_latest, hrv_latest, computed_at`

**baselines**
`metric, kind ('median28','mad28'), value, computed_at, PRIMARY KEY(metric,kind)` — personal rolling stats feeding z-scores ([04 §4](04-on-device-ai.md)).

**readiness_daily**
`date PK, score int, factors json [{name, contribution}], inputs_hash, computed_at`

**insight_card**
`id PK, for_date, kind ('readiness','anomaly','weekly','tip'), priority int, body_title, body_text, data_ref json, created_at, read_at nullable`

### 2.3 Nutrition domain

**meals**
`id PK, eaten_at, slot ('breakfast','lunch','dinner','snack'), name, photo_path nullable, kcal, protein_g, carbs_g, fat_g, source ('manual','suggestion_accepted'), note`
Targets are *computed*, not stored, except overrides in **settings** (`k=v`).

### 2.4 Gamification domain (The System)

**player** (singleton row id=1)
`level, xp_total, unspent_points, str, agi, vit, intel, per, rank ('E'…'S'), streak_days, best_streak, shields (streak-freeze count), active_theme, titles json, goal_type, goal_started_at, created_at`

**quest_templates**
`code PK, kind ('daily','boss','penalty','rest','goal_milestone'), title_flavor, description_template, metric ('pushup_reps','situp_reps','squat_reps','walk_run_km','exercise_min','steps','sleep_by_clock','water_ml','no_snack_window','custom_checklist'), base_target real, scale_per_level real, stat_reward ('str'|'agi'|…|null), who_anchor text nullable`

**quests**
`id PK, template_code FK, quest_date, kind, target real, progress real, unit, status ('offered','accepted','completed','failed','waived'), accepted_at, completed_at, expires_at, is_rest_day bool`

**xp_events**
`id PK, at, amount, reason ('quest_complete','boss_clear','streak_bonus','penalty','level_up_adjust'), quest_id nullable FK` — append-only ledger; `player.xp_total` is a cache that must equal `SUM(amount)`.

### 2.5 Coach domain

**coach_thread** `id, created_at, title`
**coach_message**
`id PK, thread_id FK, role ('user','assistant','system_ctx'), content, token_count, ttft_ms nullable, model_id, safety_flagged bool, created_at`
Context packs are *not* persisted verbatim (privacy minimization) — only the message text + a reference hash of inputs used.

### 2.6 Profile & prefs

**user_profile** (singleton): `birth_date, sex ('m','f','x','unspecified'), height_cm, goal_type ('fat_loss','muscle_gain','endurance','sleep','general'), target_weight_kg nullable, activity_factor real nullable (else derived), sleep_need_min nullable (else learned), units ('metric'|'imperial')`

## 3. Retention & Rollup Policy (default, user-adjustable)

| Data | Raw retained | Then |
|---|---|---|
| samples (all types) | 180 days | nightly job rolls into `daily_summary`; raw rows purged |
| sleep stages | 90 days | stage split kept on summary as percentages |
| GPS routes | until user deletes | never auto-purged (they're small + user's memories) |
| coach messages | forever (user-owned) | manual purge button |
| everything | — | full wipe via FR-H2 |

## 4. Query Patterns → Index Plan

- Dashboard today card: `(type, start_at)` covers all range scans.
- Baseline recompute: same index; batched single pass over 28-day window.
- Quest history heatmap: `(status, quest_date)` index.
- Weekly debrief: reads `daily_summary` directly (no raw scans).
- Export: streaming join per-domain into CSV writers; JSON export walks FK graph.

## 5. Migration Strategy

- Drift stepwise migrations `vN → vN+1` with unit-tested golden schemas.
- Ship v1 at schema v1; every release adds migrations forward-only; downgrades unsupported.
- Post-migration integrity check recomputes `player.xp_total` vs XP-ledger sum and repairs cache if drifted.

---
*Next: [04 · On-Device AI Strategy](04-on-device-ai.md)*
