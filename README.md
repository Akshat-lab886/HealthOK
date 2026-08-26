# HealthOK 🗡️📱

> *"You are no longer a weak player. The System has acknowledged you."*

**HealthOK** is a **local-first, privacy-preserving health tracker** for iOS and Android that turns your phone into a private AI health coach. Your health data flows in from **Apple HealthKit** and **Google Health Connect**, is analyzed **entirely on-device** by a hybrid intelligence engine — deterministic scoring models plus a small quantized LLM — and **never leaves your phone**.

On top of that sits **The System**: a gamified self-improvement layer inspired by Solo Leveling's Sung Jinwoo — daily quests, penalties, level-ups, E→S ranks, and stat allocation across Strength / Agility / Vitality / Intelligence / Perception.

---

## Product Thesis

1. **Own your data.** No account. No cloud. Works fully offline. Export anytime.
2. **Hybrid on-device AI.** Fast, deterministic math computes your scores (readiness, sleep, TDEE); a tiny 4-bit LLM (~0.5–3B params) powers the conversational coach, insight explanations, and meal suggestions.
3. **Gamification with teeth.** Quests, streaks, boss fights, and rank progression make consistency feel like leveling up — with ethical guardrails (adaptive difficulty, deload weeks, no harmful penalties).
4. **The complete loop:** Track → Analyze → Coach → Quest → Level Up.

## Core Feature Set

| Feature | Description |
|---|---|
| 🏃 Activity Tracking | Steps, distance, workouts, active calories via HealthKit / Health Connect + in-app GPS session recorder |
| 😴 Sleep Analysis | Stage breakdown, sleep debt, consistency score |
| ❤️ Recovery & Readiness | HRV (SDNN/RMSSD), resting HR trends → daily readiness score |
| 🍽️ Nutrition | Meal logging, macro/calorie targets, on-device meal suggestions |
| 🤖 AI Coach | Fully offline conversational coach grounded in *your* data context |
| 🗡️ The System (Quests) | Daily quests, weekly boss battles, penalty rules, XP, levels E→S, stat allocation |
| 📊 Insights Feed | Trend detection, anomaly alerts, weekly debrief reports |
| 🔒 Privacy Engine | Everything local, encrypted at rest, one-tap full export/delete |

## Document Map

All planning documents live in [`docs/`](docs/):

| # | Document | Purpose |
|---|---|---|
| 00 | [Product Overview](docs/00-product-overview.md) | Vision, personas, value proposition, pillars |
| 01 | [Product Requirements (PRD)](docs/01-prd.md) | Functional/non-functional requirements, scope, priorities |
| 02 | [System Architecture](docs/02-architecture.md) | Layers, modules, tech stack rationale, data flow |
| 03 | [Data Model](docs/03-data-model.md) | Local schema, entities, storage engines, retention |
| 04 | [On-Device AI Strategy](docs/04-on-device-ai.md) | Model selection, runtimes, quantization, pipelines, prompts |
| 05 | [Quest System Spec](docs/05-quest-system.md) | Solo Leveling mechanics → app design, XP math, guardrails |
| 06 | [Health Platform Sync](docs/06-health-platform-sync.md) | HealthKit & Health Connect deep dive, permissions, conflict resolution |
| 07 | [Privacy & Security](docs/07-privacy-security.md) | Threat model, encryption, store policies, GDPR posture |
| 08 | [Competitive Research](docs/08-competitive-research.md) | Whoop / Oura / Fitbit / Garmin / Samsung / Apple feature benchmark |
| 09 | [Roadmap](docs/09-roadmap.md) | Milestones M0–M5, MVP cut-line, risks, testing plan |

## Target Environment

- **Platforms:** Android 10+ (Health Connect via Play services module) and iOS 16+.
- **Primary test device:** Samsung Galaxy Tab A9 (`SM_X115`), connected over adb — used for all hands-on validation during the build phase.
- **Stack decision:** Flutter + Dart (single codebase), `health` plugin for platform stores, llama.cpp via dart:ffi for the bundled coach model, SQLite (Drift) for local storage.
- **AI decision:** Hybrid — deterministic Dart engines for scores/math; small GGUF Q4 LLM only for chat/explanations/meal suggestions.

## Build Status

| Item | Status |
|---|---|
| Planning documentation | ✅ This repository |
| Research dossiers | ✅ [platform sync (source-verified)](reports/health-data-platforms-2025.md) · [on-device LLM](docs/on_device_llm_fact_report_2025.md) · [gamification/Solo Leveling](research/gamification-research.md) · competitor benchmark (in progress) |
| Flutter SDK install | ⬜ Pending (build phase) |
| Android toolchain | ⚠️ adb + device ready; Android SDK setup pending |
| iOS toolchain (Xcode/CocoaPods) | ⬜ Pending |

---
*Researched and authored with multi-agent web research; every factual claim in the technical docs carries its source URL.*
