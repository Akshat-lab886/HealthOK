# 02 · System Architecture — HealthOK

> Companion docs: [03 Data Model](03-data-model.md) · [04 On-Device AI](04-on-device-ai.md) · [06 Platform Sync](06-health-platform-sync.md)

---

## 1. Architectural Style

**Modular monolith on-device.** One Flutter process, internally split into strict, dependency-directed layers and pure-Dart engine packages. No backend exists; the "server" is the OS health store (HealthKit / Health Connect). Every box below lives inside the user's phone.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HEALTHOK APP PROCESS                          │
│                                                                     │
│  ┌─────────────────────────── Presentation ──────────────────────┐  │
│  │  Flutter Widgets · go_router · Riverpod providers · themes    │  │
│  └──────────────┬────────────────────────────────────────────────┘  │
│                 │ state streams / intents                           │
│  ┌──────────────▼──────────────── Application ────────────────────┐  │
│  │  Use-cases: SyncToday · GetReadiness · AcceptQuest · AskCoach   │  │
│  │  Notification scheduler · Exporter                              │  │
│  └──────┬──────────────┬───────────────┬──────────────────────────┘  │
│         │              │               │                             │
│  ┌──────▼─────┐ ┌──────▼──────┐ ┌──────▼────────┐                    │
│  │  sync      │ │ engines     │ │ llm_gateway   │                    │
│  │  (adapters)│ │ (pure Dart) │ │ (isolate)     │                    │
│  └──────┬─────┘ └─────────────┘ └──────┬────────┘                    │
│         │                       ┌──────▼────────┐                    │
│  ┌──────▼──────────────────┐    │ llama.cpp     │  GGUF Q4 model     │
│  │ storage (Drift+SQLCipher)│    │ (dart:ffi)    │  file in app dir   │
│  └──────┬──────────────────┘    └───────────────┘                    │
└─────────┼───────────────────────────────────────────────────────────┘
          │ platform channels / plugin
┌─────────▼───────────────────────────────────────────────────────────┐
│  OS HEALTH STORES:  Apple HealthKit (iOS)   Google Health Connect    │
│  GPS / motion sensors · Keychain/Keystore · notifications            │
└──────────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** arrows point inward/downward only. Engines and domain never import Flutter or plugins → they are plain Dart packages, unit-testable at 100% speed, runnable in CI without a device.

## 2. Repository & Package Layout

```
healthok/
├── apps/
│   └── health_ok/                # Flutter shell: UI, DI wiring, platform config
├── packages/
│   ├── core_domain/              # Entities, value objects, result types (zero deps)
│   ├── health_engine/            # Readiness, sleep debt, baselines, training load, anomalies
│   ├── quest_engine/             # XP curve, level/rank logic, quest generator, penalties
│   ├── nutrition_engine/         # BMR/TDEE, macro targets, suggestion ranker
│   ├── insight_engine/           # Trend builders, weekly debrief composer
│   ├── llm_gateway/              # Chat sessions, prompt templates, context packer, guardrails
│   ├── sync/                     # HealthKit/HC adapter interface + change-token bookkeeping
│   └── storage/                  # Drift schema, DAOs, SQLCipher setup, migrations
├── docs/                         # This documentation set
└── melos.yaml                    # Package orchestration
```

Rationale: the *engines* (readiness math, XP math, quest rules) are the crown jewels of the product. Isolating them as pure packages makes them exhaustively testable (NFR-Q ≥80%) and lets us evolve game balance without touching UI.

## 3. Technology Stack & Decisions

| Concern | Choice | Why | Alternatives rejected |
|---|---|---|---|
| App framework | **Flutter + Dart** | single codebase both platforms; strong health-plugin ecosystem; FFI story for llama.cpp is first-class (`dart:ffi`) | RN/Expo (weaker health-plugin maturity); KMP (smaller plugin pool, two UIs) |
| State management | **Riverpod 2.x** | compile-safe DI, testable providers, works without BuildContext | Bloc (more boilerplate for this shape), setState (unmanageable at scale) |
| Navigation | go_router | declarative deep links (notifications → quest screen) | Navigator 1.0 |
| Local DB | **Drift (SQLite) + SQLCipher** | relational fits time-series + queries; drift gives typed DAOs, migrations; SQLCipher = AES-256 at rest | Hive/Isar (weaker ad-hoc querying, encryption story thinner); raw sqflite (no type safety) |
| Health stores | **`health` plugin** — pub.dev, MIT, maintained by CARP (carp.dk), v13.x line | one API surface both platforms; verified active maintenance (v13.3.2, 160/160 score, ~138k downloads/30d — profile in [06 §4](06-health-platform-sync.md)) | per-platform channels from scratch (months of work) — thin fallback wrappers kept behind our `sync` interface in case we must patch |
| On-device LLM runtime | **llama.cpp compiled per-platform, bound via dart:ffi**, GGUF models (Q4_K_M) | full control, no cloud, runs on both Metal & OpenCL/CPU; mature quantization ecosystem | MediaPipe GenAI (Android-leaning, model-format lock-in), MLC (heavier toolchain), ExecuTorch (youngest) |
| Classical ML (later: pose/vision) | LiteRT (TensorFlow Lite) via plugin | standard path for BlazePose etc. when FR-D4 arrives | Core ML only (iOS-only) |
| Background work | iOS: HK background delivery + BGTaskScheduler; Android: Health Connect change notifications + WorkManager periodic | platform-native freshness guarantees | polling timers (battery-hostile, unreliable) |
| Notifications | flutter_local_notifications + zone-aware scheduling | quiet-hours control (FR-I) | Firebase (cloud dep — banned by pillar) |
| Charts | fl_chart or custom painter | local, no deps on webviews | — |
| Melos | package orchestration for the workspace above | standard Flutter monorepo tooling | hand scripts |

### Decision Records (summary)

- **ADR-001 Flutter over dual-native:** team size of one; plugin coverage verified in [06](06-health-platform-sync.md).
- **ADR-002 Hybrid AI over LLM-centric:** scores must be auditable & instant (NFR-P1); LLM only narrates/explains/suggests. See [04 §1](04-on-device-ai.md).
- **ADR-003 SQLCipher over plaintext DB:** health data is maximally sensitive; at-rest encryption is cheap insurance ([07 §4](07-privacy-security.md)).
- **ADR-004 Bundled small model + optional re-download:** ship a 1–2B-class Q4 GGUF in-app for the guaranteed offline coach — primary pick **Qwen3-1.7B-Instruct Q4_K_M (~1 GB, Apache-2.0)**; larger tier downloadable via Wi-Fi gate (FR-H3). Selection matrix in [04 §3](04-on-device-ai.md); all LLM backends sit behind one backend-agnostic `InferenceEngine` interface so llama.cpp FFI and (later) MediaPipe/Gemma-3n bundles are swappable.
- **ADR-005 All LLM work in a dedicated isolate:** inference blocks threads; UI isolate must never see a blocked frame. `llm_gateway` exposes an async API over a long-lived isolate holding the loaded GGUF.

## 4. Core Runtime Flows

### 4.1 Morning readiness flow (the heartbeat of the product)

```
OS wakes app (HK delivery / HC change / alarm ~07:00 user-local)
   → sync pulls delta rows since last stored token (per-datatype anchors)
   → dedup & upsert into Drift
   → health_engine.recomputeBaselines(28d window)
   → health_engine.readiness(today inputs: HRV dev, RHR dev, sleep debt,
                              yesterday load)  → Score{value, factors[]}
   → insight_engine.phraseCard(score.factors)      [deterministic text skeleton]
   → if chat enabled: llm_gateway.rephrase(skeleton) [optional flavor]
   → Riverpod stream updates Dashboard; notification (if within budget)
```

Every step is synchronous-pure after sync; total compute < 50 ms except optional LLM phrasing.

### 4.2 Coach chat turn

```
user message
   → ContextPacker: last 14d aggregates + today's readiness + open quests +
     last 3 meals  → compact structured block (≤ ~1.5k tokens)
   → Guardrails.preflight(userMsg)         # medical/self-harm classes → canned safe reply
   → llama.cpp streaming completion (system prompt + context + few-shot style card)
   → PostCheck: regex-scan output for fabricated numerals not present in context;
     strip/red-flag violations → render tokens live
```

### 4.3 Workout recording

Foreground-only in v1 (simplification): GPS session uses a foreground service (Android) / background location-when-in-use (iOS) while screen is on; on save, workout entity writes to Drift **and** the platform store (FR-A3), tagged `source: HealthOK`.

## 5. Concurrency Model

| Worker | Runs in | Notes |
|---|---|---|
| UI | root isolate | never touches DB directly; consumes provider streams |
| DB | Drift's background executor | batched writes during sync bursts |
| LLM inference | dedicated long-lived isolate owning the loaded model | requests serialized through a command queue; model loads lazily on first chat open, unloads on memory pressure (didReceiveMemoryWarning / onTrimMemory) |
| Sync | short-lived isolate per pull | JSON decode off main isolate |
| Engines | caller isolate (pure, <50ms) | no isolate hop needed |

## 6. Error Handling & Resilience

- **Sync failures are silent + retried** with exponential backoff; UI shows data freshness timestamp ("synced 14 min ago"), never error modals.
- **Model missing/corrupt:** coach chip turns grey, cards fall back to deterministic skeletons — product degrades gracefully, never breaks (FR-H3).
- **DB migrations:** drift stepwise migrations with golden-file tests on every schema change.
- **Crash reporting:** none (no network!). Local crash log ring buffer exported only if the user opts to share manually.

## 7. Security Architecture (summary)

Full detail in [07-privacy-security.md](07-privacy-security.md): SQLCipher DB keyed by Keychain (iOS) / Android Keystore-wrapped key; GGUF model files treated as assets (integrity check on load); zero HTTP clients linked into release build except the optional model downloader module, which is disabled unless user opens Settings→Models.

## 8. Observability (local-only)

Debug builds: structured logs + perf marks (sync duration, TTFT, score compute). Release: opt-in diagnostic bundle the user can export and send us *manually*. No SDKs, ever (NFR-P4).

---
*Next: [03 · Data Model](03-data-model.md)*
