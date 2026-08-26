# 04 · On-Device AI Strategy — HealthOK

> Architecture context: [02 §3 ADR-002](02-architecture.md). Storage of derived stats: [03 §2.2](03-data-model.md).
> ⚠️ Authoring note: live web verification was unavailable during this pass (search API auth failure); claims below are from engineering training knowledge and are labeled **[U]** where they must be re-verified before GA. A verification checklist closes this doc.

---

## 1. Division of Labor (the hybrid contract)

| Job | Owner | Why |
|---|---|---|
| Readiness/recovery scores, sleep debt, TDEE/macros, training load, anomaly flags, XP math | **Deterministic Dart engines** | instant (<50 ms), auditable, testable, battery-free, safety-relevant |
| Conversational coach, plain-language explanations, meal-suggestion *phrasing*, weekly debrief narration | **Small quantized LLM** (bundled, offline) | natural language quality |
| Activity/sleep raw signals | **OS stores** (HealthKit/Health Connect) | sensors already aggregated by the platform |

**Iron rule:** the LLM never computes a health number. It receives engine-computed facts in its context and may only narrate, explain, motivate, or suggest among options the ranker produced.

## 2. Deterministic Engine Specifications

### 2.1 Personal baselines
Per metric m (HRV-SDNN, RHR, sleep duration): rolling **28-day median** and **MAD** computed nightly from `samples`. Robust to gaps/outliers by design.

### 2.2 Daily readiness score (0–100)

```
readiness = 100 × Σ wᵢ·fᵢ          weights: w_hrv=0.35, w_sleep=0.30,
                                            w_rhr=0.20, w_load=0.15

f_hrv  = squash( (hrv_today − median28) / MAD28 )        // positive = recovered
f_sleep= 0.6·saturation(sleep_last_night/need) + 0.4·saturation(1 − debt7/need_wk)
f_rhr  = −squash( (rhr_3day_avg − rhr_median28) / MAD )  // rising RHR = strain
f_load = 1 − saturation( ACWR_excess )                   // acute:chronic workload ratio
squash(x) = tanh(x);  saturation(x)=clamp(x,0,1)
```

Factors array stored on `readiness_daily.factors` so every score is drill-down-explainable ([01 FR-C2](01-prd.md)). Cold-start behavior (first 14 days): population-prior constants clearly labeled "learning your baseline…" — no fake precision.

### 2.3 Sleep metrics
- Debt: Σ(daily need − actual) over trailing 7 days; need = user-set or learned median of best-rested nights.
- Consistency: SD of mid-sleep times over 14 nights → grade A–F.
- Stages rendered when source provides them; never fabricated when absent.

### 2.4 Training load
Session load ≈ duration_min × intensity_factor (HR-zone based when HR present, MET-based otherwise). ACWR = 7-day total ÷ 28-day avg weekly total; band 0.8–1.3 = sweet spot; >1.5 flags "spike" insight card.

### 2.5 Energy & macros
- BMR: **Mifflin-St Jeor**; TDEE = BMR × activity factor (derived from real weekly exercise minutes, not self-report alone).
- Goal delta: fat_loss −15–20% TDEE (floor at BMR), muscle_gain +10%.
- Macros: protein 1.6–2.2 g/kg by goal, fat ≥ 0.8 g/kg, remainder carbs. Recalibrated weekly from actual weight trend (expected vs observed rate).

### 2.6 Anomaly detection
Rolling z-score per metric; |z| > 2.5 → `insight_card(kind:'anomaly')` (e.g., RHR climbing 4 nights, HRV collapsing, sleep collapsing post-travel). Rate-limited to top-2 cards/day (calmness, FR-I).

## 3. LLM Selection (bundled coach brain)

### 3.1 Candidate matrix *(all rows [U] — verify current versions/licenses)*

| Model | Params | ~RAM @Q4 | License posture for bundling | Notes |
|---|---|---|---|---|
| **Qwen3 1.7B / 0.6B** | 1.7B/0.6B | ~1.2 GB / ~0.5 GB | Apache-2.0 — cleanest commercial terms | strong instruction-following for size; multilingual (HI/EN future) |
| Llama 3.2 1B / 3B | 1B/3B | ~0.9 / ~2.1 GB | Llama Community License (fine below 700 MAU; attribution) | solid general chat |
| Gemma 3 1B / 3n-E2B | 1B/E2B(~2B eff.) | ~0.9 / ~1.5 GB | Gemma Terms (redistribution allowed w/ conditions) | 3n built mobile-first; good multilingual |
| Phi-4-mini | 3.8B | ~2.4 GB | MIT — very clean | heavier RAM; excellent reasoning |
| SmolLM2 360M/1.7B | tiny→1.7B | ~0.3 / ~1.1 GB | Apache-2.0 | weakest quality tier |

### 3.2 Recommendation (MVP)

- **Tier A (bundled):** one 1–2B-class Q4_K_M GGUF (~0.6–1.2 GB asset). Primary pick **Qwen3-1.7B-Q4** (license-cleanest + quality), fallback **Llama-3.2-1B-Q4** if size budget tightens. Target hardware floor: 4 GB RAM devices (Galaxy Tab A9 has 4–8 GB variants — validate on ours).
- **Tier B (optional download, Wi-Fi-gated):** a 3–4B Q4 for richer coaching on 8 GB+ devices.
- Decision gate at M3: measure TTFT/tok-per-s on Tab A9; drop Tier A size class if NFR-P2 (<1.2 s TTFT) fails.

### 3.3 Runtime

- **llama.cpp compiled per-platform (Metal on iOS; CPU+XNNPACK/OpenCL path on Android), driven through `dart:ffi`.** Pub.dev wrappers exist (`llama_cpp_dart` et al.) but skew single-maintainer/lagging [U]; if none passes review at build time we own a thin binding (~300 lines FFI + CMake/ndk-build + xcframework) — deliberately small surface: `load/context/completion_stream/free`. Secondary backend behind the same `InferenceEngine` interface: **flutter_gemma / MediaPipe AI Edge `.task`/`.litertlm` bundles** (GPU delegate; Gemma-family only) adopted later for Gemma 3n vision+audio capabilities.
- Long-lived isolate owns the loaded model; serialized command queue; unload on memory-pressure callbacks ([02 §5](02-architecture.md)).
- Context budget: 2048 tokens default (system+context pack ≤ ~1.5k, replies ≤ ~400) keeps KV-cache RAM bounded.
- Opportunistic upgrades (post-v1, both [U]): Apple Foundation Models framework (iOS 26+, OS-provided ~3B model) for Apple devices; Android AICore/Gemini Nano where available. Bundled GGUF remains the guaranteed floor.

## 4. Prompting & Guardrails

### 4.1 System prompt skeleton (v1)

```
You are the Coach inside HealthOK, a private on-device health app.
Voice: terse, encouraging, slightly game-like ("The System"), max 120 words unless asked.
FACTS below are computed by the health engine and are the ONLY numbers you may cite.
Never diagnose, never mention medications, never invent numbers not in FACTS.
If asked medical questions: advise consulting a professional, offer what the app can do.
[FACTS]
user_profile: {age_band, sex, height_cm, weight_trend_30d}
readiness: {score, factors[]}
sleep_7d: {avg_min, debt_min, consistency_grade}
activity_7d: {steps_avg, exercise_min, acwr}
nutrition_yesterday: {kcal_in vs target, protein_pct}
quests: {today_status, streak, rank}
[STYLE CARD]
3 example exchanges demonstrating tone…
```

### 4.2 Safety pipeline

1. **Preflight classifier (rules):** regex/keyword classes for medical-diagnosis, medication, self-harm, pregnancy-risk topics → canned safe response + professional-care redirect, LLM skipped entirely.
2. **Post-check:** scan output tokens for numerals not present in the context pack → strip or replace with "[engine value]" placeholder; log `safety_flagged=true`.
3. **Red-team set:** ~60 adversarial prompts run in CI against every model-candidate change; rubric pass ≥95% required (PRD release criterion).

### 4.3 Context packer rules
Compact structured lines (not prose) ≤ ~1.5k tokens; only aggregates (never raw minute-by-minute samples); rebuilt per turn from `daily_summary` + live quest state; nothing persisted verbatim ([03 §2.5](03-data-model.md)).

## 5. Meal Suggestion Pipeline (FR-D3)

```
ranker(nutrition_engine): candidates from local food history + template library
  scored by: remaining kcal/macro fit (40%), time-of-day appropriateness (20%),
  user history preference (25%), prep simplicity tag (15%)
→ top 3 candidates passed to LLM purely for presentation copy
→ fallback if model disabled: deterministic template strings
```

Food database v1 = bundled offline list (~2k common items w/ per-100g macros, public-domain-derived sources [U]) + user-created meals. Photo recognition explicitly out of scope until FR-D4 validation; preferred path then is **Gemma 3n E2B via MediaPipe/flutter_gemma** (built-in vision in `.task` bundles) ahead of a standalone Food101 MobileNetV3 classifier (<10 MB int8) [U]. Voice logging (post-v1): whisper.cpp-tiny / Moonshine-tiny for short utterances [U].

## 6. Performance Budgets & Measurement

| Metric | Budget | Measured via |
|---|---|---|
| TTFT (Tier A, mid-range) | < 1.2 s p50 | debug perf marks on Tab A9 soak |
| Generation speed | ≥ 12 tok/s p50 | same |

*Research-sourced envelope [U]: 1B-Q4 ≈ 15–25 tok/s on A15-class, ≈ 10–20 on Snapdragon 7-series; TTFT is prompt-bound (keep context packs ≤ ~1k tokens where possible); expect 20–40% thermal throttling after minutes of continuous generation; ~1 GB RSS residency budget for 1B class. Re-benchmark on Galaxy Tab A9 before freezing specs.*
| Model RAM residency | ≤ 1.6 GB incl. KV cache | platform memory traces |
| Score engine compute | < 50 ms full morning pipeline | stopwatch tests |
| Battery delta with chat use | ≤ 3%/day typical | soak protocol ([09 §5](09-roadmap.md)) |

## 7. Model Lifecycle

- Bundled Tier A ships inside app assets; SHA-256 verified at first load; corrupt → auto-disable chat + re-extract button.
- Optional Tier B downloads only from Settings→Models, over Wi-Fi by default, checksummed, deletable (FR-H3).
- Model swaps are config-gated (`model_manifest.json`: id, file, ctx_len, chat_template, sha256) — no code changes to swap brains; red-team CI gates every manifest bump.

## 8. Verification Checklist (run when network research returns)

1. Confirm current license text/redistribution clauses: Qwen3 (Apache-2.0), Llama 3.2 Community License, Gemma Terms.
2. Confirm best-in-class 2025 small-model ranking (Gemma 3n vs Qwen3 vs newer releases) and any phone-specific distills.
3. Audit pub.dev llama.cpp wrapper packages (maintenance, iOS Metal support) — buy-vs-bind decision.
4. Verify Apple Foundation Models / Gemini Nano third-party access status from official docs.
5. Validate food-database licensing source choice.
