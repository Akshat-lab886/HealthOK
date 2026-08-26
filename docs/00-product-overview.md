# 00 · Product Overview — HealthOK

> **One-liner:** A private, local-first health tracker with an on-device AI coach and a Solo Leveling-style quest system that makes self-improvement feel like leveling up.

---

## 1. Vision Statement

Most fitness apps either (a) harvest your health data into someone else's cloud, or (b) show you charts without telling you what to *do*. HealthOK rejects both compromises.

**Vision:** Every person gets a tireless, private health mentor that lives inside their phone — one that reads their real body signals (heart rate, sleep, activity, meals), explains them in plain language, and then gives them a clear, game-like path to become stronger than yesterday.

The metaphor is deliberate: Solo Leveling's protagonist starts as the *weakest hunter* (E-rank) and becomes sovereign (S-rank) through nothing but consistent daily quests and incremental stat gains. That is exactly the psychology of fitness adherence: **small daily wins, visibly compounded.**

## 2. Problem Space

| Problem in today's market | Evidence / Consequence |
|---|---|
| Health apps ship intimate data (HRV, sleep, location, cycles) to ad-backed clouds | Users increasingly distrust cloud fitness platforms; Apple/Google both moved health storage *onto device* (HealthKit since 2014; Health Connect stores locally on Android) |
| AI coaches are subscription clouds (Whoop Coach, Oura Advisor) — expensive, privacy-hostile, useless offline | A 1–3B param LLM now runs comfortably on modern phones at 4-bit quantization, making a private coach feasible |
| Trackers show data but give no direction ("you slept 6h12m… so what?") | Retention collapses after week 2; users need *prescription*, not dashboards |
| Habit apps punish relapse brutally (dead streaks) causing churn and shame-spirals | Behavioral science favors flexible recovery mechanics (streak freezes, adaptive goals) |
| Fitness gamification exists (rings, badges) but rarely has narrative stakes or progression depth | RPG progression (levels, ranks, stats) creates long-horizon identity investment |

## 3. Value Proposition

**For the privacy-conscious user:** zero account creation, zero network calls for core function, full export/delete — verifiable, because the app functions identically in airplane mode.

**For the motivated self-improver:** The System converts WHO-guideline-anchored daily actions into quests with XP, levels, ranks (E→S), and allocated stats — turning "did I work out?" into "am I about to hit Level 20?"

**For the data-curious:** a hybrid engine (deterministic math + on-device LLM) explains *why* readiness is 62% — HRV down 14%, sleep debt 90 min — without sending a byte anywhere.

## 4. Design Pillars

1. **Local-first, always.** If a feature can't run offline, it doesn't ship. Network is used only for optional model downloads and OS-provided services.
2. **Deterministic where lives depend on it.** Scores, calories, training loads come from auditable formulas; the LLM *narrates* results, never *computes* safety-relevant numbers.
3. **The System is a strict but fair master.** Penalties exist (flavor + light friction) but can never damage health: no "run 10km injured" quests, mandatory rest-day mechanics, adaptive difficulty.
4. **Zero-config onboarding.** Grant HealthKit / Health Connect permission → the dashboard populates itself. Manual logging is always available as fallback.
5. **Explain every number.** Tap any metric → plain-language explanation, trend, and one suggested action.

## 5. Target Users (Personas)

### 🎮 "Arjun" — The Gamer Seeking Discipline (primary)
- 22, student, loves anime/games, tried gym 3 times, always quits by week 3.
- Pain: boredom, no visible progress, no external accountability.
- Hook: The System's quests, XP bars, rank-ups. He doesn't want a fitness app; he wants a character sheet for his own body.

### 🧑‍💼 "Priya" — The Busy Professional (secondary)
- 31, consultant, sleeps badly, eats irregularly, owns a smartwatch she barely reads.
- Pain: privacy anxiety, notification fatigue, guilt-driven apps.
- Hook: silent local analysis, calm weekly debrief, meal suggestions that fit her calendar, no social pressure.

### 🏃 "Dev" — The Beginner Athlete (secondary)
- 19, wants to go from sedentary to 5K.
- Pain: generic plans ignore his recovery; he overtrains and stalls.
- Hook: readiness score gates quest intensity; progressive overload handled by the engine; deload weeks appear as "Rest Quests."

## 6. Product Pillars → Feature Mapping

| Pillar | Features (see PRD §4) |
|---|---|
| Track | Activity dashboard, workout sessions (GPS + sensor), manual logs, sleep view, nutrition log |
| Analyze | Readiness score, sleep debt, training load, TDEE calculator, trends & anomaly alerts |
| Coach | On-device LLM chat grounded in personal context; insight cards with explanations; meal suggestions |
| Gamify | Daily quests, weekly boss battle, penalty mechanic, XP/level curve, E→S ranks, stat allocation, titles |
| Own | Full export (JSON/CSV), wipe-all, permission manager, offline-first everything |

## 7. What HealthOK Is *Not* (Non-Goals v1)

- ❌ Not a medical device; no diagnosis, no medication guidance (disclaimer + safe-completion behavior in the LLM).
- ❌ No social graph/feed in v1 (leaderboard between *you-past vs you-now* instead).
- ❌ No proprietary wearable firmware integration — we consume HealthKit / Health Connect, which already aggregates watches (Apple Watch, Galaxy Watch, Pixel Watch, Garmin, Mi Band).
- ❌ No cloud account, no analytics SDKs, no ads. Ever. That's the brand.

## 8. Success Criteria (Product)

| Metric | Target @ 90 days post-launch |
|---|---|
| D30 retention | ≥ 25% (industry median ~8–12%) |
| Quest completion rate | ≥ 55% of assigned daily quests |
| Coach messages per active week | ≥ 5 |
| Crash-free sessions | ≥ 99.5% |
| Battery overhead vs baseline | ≤ 3%/day typical use |
| Offline functionality | 100% of core features |

## 9. Open Questions (tracked in Roadmap §7)

1. Bundled-model size budget: ship ~450MB model in-app vs first-run download with Wi-Fi gate?
2. iOS: adopt Apple's Foundation Models framework (free, OS-provided, iOS 26+) alongside bundled GGUF for older devices?
3. Monetization: paid-upfront ("buy the game") fits the Solo Leveling identity better than a subscription — decide by M3.

---

*Next: [01 · Product Requirements](01-prd.md)*
