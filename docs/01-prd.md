# 01 · Product Requirements Document (PRD) — HealthOK v1

> Status: Draft for build phase · Owner: Product/Eng · Sources: see [08-competitive-research](08-competitive-research.md)

---

## 1. Purpose & Scope

HealthOK v1 is a **local-first health tracking + coaching app** for Android 10+ and iOS 16+, with:

1. Automated ingestion of health data from **Apple HealthKit** (iOS) and **Google Health Connect** (Android).
2. On-device analysis via a **hybrid engine** (deterministic scoring + small quantized LLM).
3. An **AI coach** chat, **insight feed**, and **meal suggestions**.
4. Activity tracking (passive sensor data + in-app workout recorder).
5. **The System**: a gamified quest/goal engine inspired by Solo Leveling.
6. Full data ownership: export, delete, offline-everything.

Out of scope for v1: social features, cloud backup, wearable firmware integration, medical advice. See [00 §7](00-product-overview.md).

## 2. Platform & Device Requirements

| Requirement | Android | iOS |
|---|---|---|
| Minimum OS | Android 10 (API 29); Health Connect features degrade gracefully on <14 via the Health Connect APK module | iOS 16+ (sleep stages API), iOS 17+ recommended |
| Target devices | Phones + tablets; primary test device Samsung Galaxy Tab A9 (SM-X115) | iPhone SE 2nd gen as low-end baseline |
| Permissions | `ACTIVITY_RECOGNITION`, Health Connect read/write roles, optional `ACCESS_FINE_LOCATION` (workouts only, foreground), notifications (quest reminders) | HealthKit authorization UI, Motion & Fitness, optional location-when-in-use, notifications |
| Store policy compliance | Health apps policy; Health Connect terms + Health Apps declaration form | App Review Guideline **5.1.1(i)–(v)** health rules ([verified](06-health-platform-sync.md) — older "1.17" numbering is outdated); privacy nutrition labels = "Data Not Collected" |

## 3. Personas → Requirement Traceability

Personas defined in [00 §5](00-product-overview.md). Arjun drives FR-G (gamification depth); Priya drives NFR-P (privacy/perf) and FR-I (insights calmness); Dev drives FR-A (adaptive activity) and guardrails.

## 4. Functional Requirements

Priorities: **P0** = MVP-blocking · **P1** = v1.0 GA · **P2** = post-v1.

### FR-A — Data Ingestion & Sync (P0)
- **FR-A1** Read steps, distance, active energy, heart rate, HRV, sleep sessions/stages, workouts, body mass, body fat %, VO2max, SpO2, respiratory rate, water, dietary energy/macros where available — via HealthKit (iOS) or Health Connect (Android). *Acceptance: dashboard populates within 60s of permission grant without user input.*
- **FR-A2** Incremental background ingestion using anchored queries (HKAnchoredObjectQuery / HC changes token); dedupe by source+start+end+type. *Acceptance: no duplicate rows after 7 days of dual-source testing.*
- **FR-A3** Write-back: workouts recorded in-app and water/meals logged manually are saved to the platform store so other apps see them. *Acceptance: workout recorded in HealthOK appears in Apple Health / Health Connect.*
- **FR-A4** Permission manager screen showing per-datatype grant state, deep-linking to system settings; app remains functional with zero grants (manual-only mode).

### FR-B — Activity Tracking (P0)
- **FR-B1** Passive dashboard: today's steps/distance/calories vs quest targets, hourly bars, 30-day trend.
- **FR-B2** In-app workout recorder (outdoor run/walk/cycle with GPS; indoor modes timer-only) that writes to platform store on save.
- **FR-B3** Manual quick-log: generic activity with duration + perceived intensity (maps to MET values for calorie estimate).

### FR-C — Sleep & Recovery Intelligence (P0)
- **FR-C1** Nightly sleep card: duration, stage split (if source provides), consistency (mid-sleep variance), sleep debt (7-day window vs personal need estimate).
- **FR-C2** **Readiness score 0–100** computed each morning from HRV baseline deviation, resting-HR trend, sleep debt, and previous-day training load. Formula documented in [04-on-device-ai §3](04-on-device-ai.md). *Acceptance: score updates by first app open after wake; explainable breakdown shown.*
- **FR-C3** Personal baselines learned locally per-user (rolling 28-day median + MAD) — no population averages shipped.

### FR-D — Nutrition & Meal Suggestions (P0 logging / P1 suggestions)
- **FR-D1** Meal log: name/portion/time/manual macros; photo attach stored locally (v1 photo is reference only).
- **FR-D2** Daily targets: BMR (Mifflin-St Jeor) × activity factor ± goal delta → calories; macro split per goal template. Recomputed weekly from weight trend.
- **FR-D3** (P1) **Meal suggestions:** rule-based candidate ranking (calorie/macro fit, time of day, history preference) + LLM-generated presentation ("You've got 640 kcal left — here are 3 dinners that fit"). No web calls.
- **FR-D4** (P2) Photo portion estimation via on-device vision model — explicitly deferred until accuracy validated.

### FR-E — AI Coach (P1 for GA; P0-lite = scripted insights at MVP)
- **FR-E1** Chat UI streaming tokens from bundled on-device model; context injected: last 14 days summary stats, current readiness, active quests, recent meals (structured, compact prompt ≤ 2k tokens).
- **FR-E2** Guardrails: refuse diagnosis/drug/medical advice class prompts with safe redirect; no numbers invented — coach cites engine-computed stats only; temperature low (≤0.7).
- **FR-E3** Proactive insight cards (non-chat): daily readiness explanation, weekly debrief, anomaly alerts (e.g., "RHR up 8 bpm over 4 nights"), generated deterministically then phrased by the LLM.
- **FR-E4** Voice input via OS keyboard dictation (no bundled ASR in v1).

### FR-F — Insights & Reports (P0 basic / P1 weekly)
- **FR-F1** Trend lines 7/30/90d for core metrics; anomaly detection via rolling z-score (|z| > 2.5 flags).
- **FR-F2** Weekly debrief page: training load balance, sleep consistency grade, quest completion %, one focus suggestion.

### FR-G — The System: Quests & Gamification (P0)
Full spec in [05-quest-system.md](05-quest-system.md). Requirements-level commitments:
- **FR-G1** Daily Quest auto-generated from user's level & readiness (e.g., push-ups / squats / walk-or-run / sleep-before-time), WHO-anchored volumes, adaptive difficulty.
- **FR-G2** XP awards on completion → level curve; each level grants stat points allocatable to STR/AGI/VIT/INT/PER (mapped to real metric domains).
- **FR-G3** Rank ladder E→D→C→B→A→S gated by level + sustained consistency (not raw grind).
- **FR-G4** Penalty mechanic for failed daily quests: light, non-harmful (XP decay shielded by earned "Streak Shields"; extra "penalty quest" next day at normal intensity). Never blocks app usage.
- **FR-G5** Weekly Boss Battle: a single stretched goal (e.g., "Conquer: 25km week"); victory yields bonus chest (cosmetic titles/themes).
- **FR-G6** Titles & cosmetic System themes unlocked at rank/stat milestones.
- **FR-G7** Goal-setting wizard: user picks a goal (lose fat / gain strength / sleep better / 5K) → System converts to quest program with milestones.

### FR-H — Data Ownership (P0)
- **FR-H1** One-tap export: full JSON + per-domain CSV to user-chosen location.
- **FR-H2** Delete-all with typed confirmation; uninstall leaves nothing behind (no server-side anything).
- **FR-H3** Model management screen: shows bundled model size; optional re-download; delete-model switch that disables coach chat but keeps all deterministic features.

### FR-I — Settings & Calmness (P0)
Quiet hours, notification budget (max 2/day default), units (metric/imperial), theme (System dark default + "System" amber-on-black theme pack).

## 5. Non-Functional Requirements

| ID | Requirement | Budget / Target |
|---|---|---|
| NFR-P1 | Cold start to interactive dashboard | < 2.0s p50 on Galaxy Tab A9 / iPhone SE2 |
| NFR-P2 | Coach first token latency | < 1.2s on mid-range (8GB RAM) with Q4 1–2B model |
| NFR-P3 | Battery: passive tracking day | ≤ 3% additional drain |
| NFR-P4 | Network calls (core features) | **Zero.** Verifiable in airplane mode |
| NFR-S1 | Local DB encryption at rest | SQLCipher/AES-256; keys in Keychain/Keystore |
| NFR-S2 | Crash-free sessions | ≥ 99.5% |
| NFR-A1 | Accessibility | Dynamic type, screen-reader labels on all interactive elements, WCAG AA contrast (System theme included) |
| NFR-L10N | Localization architecture | i18n-ready strings from day one (EN first; HI next) |
| NFR-Q | Test coverage | ≥ 80% line coverage on engine packages (scores, XP math, sync dedup) |

## 6. Key Screens (v1 information architecture)

1. **Today / Dashboard** — readiness ring, quest panel ("Daily Quest — accept?"), activity/sleep/nutrition cards, insight strip.
2. **Quests** — daily quest detail, boss battle progress, penalty status, streak shields inventory.
3. **Character** — level, rank crest, radar chart of STR/AGI/VIT/INT/PER, titles, theme shop.
4. **Coach** — chat thread + proactive cards; model status chip.
5. **Nutrition** — diary, targets, meal suggestions.
6. **Trends** — metric explorer, weekly debrief.
7. **Settings** — permissions, data export/delete, model manager, quiet hours.

## 7. Release Criteria (v1.0 GA)

- All P0 + P1 requirements pass acceptance on both platforms.
- Zero network calls audit passes (proxy capture test).
- 7-day soak test on Galaxy Tab A9 with synthetic + real Health Connect data: no dup rows, no ANRs, battery within NFR-P3.
- LLM red-team set (medical misuse, self-harm adjacency, number fabrication) passes safe-response rubric ≥ 95%.

## 8. MVP Cut-Line (what ships FIRST if time compresses)

Keep: FR-A1/A2/A3, FR-B1/B3, FR-C1/C2/C3, FR-D1/D2, FR-F1, FR-G1/G2/G3/G4 (simple penalties), FR-H*, FR-I, scripted insight cards.
Defer: GPS recorder polish, chat coach (replace with cards), boss battles, themes.

---
*Next: [02 · System Architecture](02-architecture.md)*
