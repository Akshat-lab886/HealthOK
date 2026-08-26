# 09 · Roadmap, Testing Strategy & Risk Register

> Scope source: [01 PRD](01-prd.md) (priorities + §8 MVP cut-line). Test device reality: Samsung Galaxy Tab A9 (`SM-X115`) over adb; iOS toolchain (Xcode/CocoaPods) **not yet installed** on this machine — required before M4.

---

## 1. Milestone Plan

| Phase | Duration* | Contents | Exit criteria |
|---|---|---|---|
| **M0 · Foundations** | 1 wk | Install Flutter SDK + Android SDK/Xcode; repo scaffold per [02 §2](02-architecture.md); melos workspace; CI skeleton (analyze/test); Drift schema v1 + SQLCipher wiring; `sync` adapter spike reading steps from Health Connect on Tab A9 | `flutter test` green in CI; first real step-count row lands in encrypted DB from the tablet |
| **M1 · Data Path MVP** | 2–3 wk | Full ingestion FR-A1/A2/A4; dashboard read-only cards; manual quick-log (FR-B3); permission manager; freshness indicators | 7-day dual-source dup-free run; airplane-mode audit passes |
| **M2 · Engines + The System** | 3–4 wk | health_engine (baselines/readiness/sleep/load [04 §2](04-on-device-ai.md)); nutrition targets (FR-D1/D2); quest_engine core: daily quests, XP/levels/ranks E→C, shields/mercy/penalty (FR-G1–G4); Character screen radar | Engine coverage ≥80%; 14-day self-dogfood on tablet with believable quest pacing; balance goldens stable |
| **M3 · Coach Brain** | 3 wk | llama.cpp FFI binding + isolate service; model bake-off **gate on Tab A9** (TTFT/tok-s/RAM vs NFR-P2/P budgets); guardrail pipeline + red-team CI; coach chat UI; insight cards (FR-E3, FR-F1) | Chosen Tier-A model passes budgets at p50/p95; red-team ≥95%; scripted-fallback mode proven |
| **M4 · Delight & Hardening** | 2–3 wk | Weekly debrief (FR-F2); Gates/boss battles (FR-G5/G6); meal suggestions (FR-D3); app-lock + privacy ledger ([07 §5](07-privacy-security.md)); System theme pack; deload automation | All P0+P1 acceptance criteria checked both platforms; accessibility pass |
| **M5 · Launch Prep** | 2 wk | Soak test protocol (§3 below); Play Health-apps declaration + Data safety; Apple 5.1.1 compliance review; PRIVACY.md; export/wipe drills | Store submissions filed; crash-free ≥99.5% across soak |

\* Solo developer working with heavy AI-agent assistance; calendar time ≈ 3.5–4 months. M3 is the riskiest gate — see §4 R1.

**Sequencing principle:** the deterministic product (M1+M2) must be *fully valuable without any LLM*; the coach upgrades it in M3. If model budgets fail, we ship M3's fallback mode without blocking launch.

## 2. Testing Strategy (pyramid)

1. **Unit (fast majority):** engines are pure Dart — exhaustive property tests (readiness monotonicity, XP-ledger invariant `Σ(xp_events)=player.xp_total`, quest generator never exceeds WHO caps, penalty asymmetry law).
2. **Golden tests:** balance.yaml snapshots (quest sets at representative level/goal/readiness combos); prompt-context packs (byte-stable fixtures).
3. **Integration:** repository+DB against real SQLCipher instance; migration goldens.
4. **Device:** adb-driven flows on SM-X115 (grant/revoke permissions, background freshness, deletion propagation — full matrix in [06 §8](06-health-platform-sync.md)).
5. **LLM QA:** 60-prompt red-team set + tone rubric + numeric-grounding post-check runs in CI on every model-manifest bump ([04 §4.2](04-on-device-ai.md)).
6. **Privacy regression:** proxy-capture airplane-mode audit each release candidate (NFR-P4).

## 3. Soak Protocol (pre-launch, M5)

- Device: Galaxy Tab A9, factory-state profile, real usage + synthetic writers for HRV/sleep.
- 7 consecutive days: battery delta ≤3%/day (NFR-P3); zero ANRs; zero dup rows; memory steady-state <250 MB without chat, <2 GB peak during chat; readiness card current each morning.
- Automated nightly `adb` collectors: `dumpsys batterystats`, `dumpsys meminfo`, logcat ring buffer, DB integrity pragma.

## 4. Risk Register

| ID | Risk | Prob. | Impact | Mitigation / trigger |
|---|---|---|---|---|
| R1 | Bundled model misses TTFT/RAM budget on 4 GB devices | med | high | Bake-off gate M3; drop class to Qwen3-0.6B/SmolLM2; ship scripted-insights fallback (already built for offline mode) |
| R2 | `health` plugin gap blocks a P0 (e.g., iOS background delivery) | med | med | Private `HKObserverPlugin` channel behind adapter interface ([06 §4](06-health-platform-sync.md)); worst case periodic BGTask refresh |
| R3 | Health Connect rate limits degrade sync freshness | low | med | Changelog-first design already mandated ([06 §3.3](06-health-platform-sync.md)); pull-on-open guarantees UX floor |
| R4 | Gamification feels punishing → churn (the exact failure mode of hard streaks) | med | high | Mercy rule + Rest Quests + shield economy shipped in M2, not bolted on; completion-rate telemetry is local-only so instrument via optional user-visible stats screen |
| R5 | iOS toolchain absent delays parity testing | certain-now | med | Install Xcode/CocoaPods during M0; until then iOS validated on simulators via CI or deferred to M3 |
| R6 | Scope creep (social, wearables, vision) | high | med | PRD §8 cut-line is binding; new ideas land in backlog section below |
| R7 | Solo-developer bus factor | n/a | med | This documentation set *is* the mitigation; ADR discipline continues in-repo (`docs/adr/`) |

## 5. Environment Setup Backlog (start of M0)

1. `flutter sdk` install + PATH; Android SDK licenses; signing keys.
2. Xcode + CocoaPods install (iOS build path) — currently missing on this Mac.
3. Verify Tab A9 Android version (`adb shell getprop ro.build.version.release`) → pins HC behavior matrix ([06 §8](06-health-platform-sync.md)).
4. Create GitHub repo + branch protection; enable Actions (analyze/test/format gates).
5. Model bake-off harness scaffold (bench script driving FFI binding with 3 candidate GGUFs).

## 6. Post-v1 Backlog (ordered by pull, not push)

1. Tier-B downloadable models (3–4B) for flagship phones.
2. Gemma 3n vision: photo → portion estimate (FR-D4) via flutter_gemma bundles.
3. Voice logging (whisper.cpp-tiny/Moonshine) + voice-coach replies.
4. Party Raids (anti-Habitica rules) + opt-in leagues.
5. Hindi localization (i18n strings ready from day one).
6. Watch/Wear OS companion (tiles for today's quest).
7. Mana-Crystal shop expansion, title stat bonuses rollout (v1.1 items from [05](05-quest-system.md)).
8. Optional *end-to-end-encrypted* multi-device sync (user-held key) — only if demanded; violates nothing if done right.

---
*Complete index back in [README](../README.md).*
