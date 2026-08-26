# 08 · Competitive Research — AI Features Across Health Trackers

> ⚠️ **Verification status:** authored from engineering/product training knowledge with `[U]` confidence labels because live search infra failed this session; a dedicated retrieval agent was dispatched to verify against official pages — its confirmed facts get merged inline (`[V url]`) when it reports. Treat price points and ship-state of newest features (esp. Apple/Google 2025–26 items) as provisional.

---

## A. Product-by-Product Feature Blocks

### Whoop (band + subscription)
- **Recovery score** each morning from HRV, resting HR, respiratory rate, skin temp vs personal baseline [U high]
- **Strain** 0–21 cardiovascular-load scale for day/workouts; **Sleep Coach** with debt + consistency recommendations [U high]
- **Whoop Coach**: conversational LLM chat over your own metrics (cloud GPT-class) [U high]
- Journal behavior-correlation insights; strength/HR-zone workouts; no screen on device by design [U high]

### Oura (ring + subscription)
- **Readiness score** blending HRV, RHR, body temperature, sleep, activity balance [U high]
- Sleep staging (PPG+accelerometer derived), sleep debt, chronotype; **Symptom Radar** illness-onset flags [U high]
- **Oura Advisor** LLM chat over personal trends (rolled out 2024+) [U high]
- Meal/experiment features incl. photo-based meal logging trials [U med]

### Fitbit / Google
- **Daily Readiness** (Premium): sleep + HRV + recent load composite [U high]
- **Fitbit Labs** Gemini-era experiments: Personal AI Coach conversational rollout for Premium users, richer weekly insights, auto-generated advanced health reports (shareable PDFs) [U med — fast-moving]
- Sleep profile (animal archetypes), Stress Management Score, EDA scans [U high]

### Samsung Health (+ Galaxy Watch/Ring)
- **Energy Score** powered by on-device Galaxy AI: sleep time/readiness, HR, activity → single daily number [U high]
- **Wellness Tips** contextual AI suggestions; Bixby voice interactions [U med]
- Deep integration with Galaxy Ring for passive multi-signal capture [U high]

### Garmin (Connect ecosystem)
- **Body Battery** (HRV/stress-derived energy 0–100), **Training Readiness** (sleep + recovery + acute load + history), **Sleep Coach** [U high]
- Training Status/Load Focus, Endurance & Hill scores; Morning Report digest [U high]
- Connect+ tier adding AI narrative summaries of training data [U med]

### Apple (Watch + Health app)
- **Training Load** (watchOS 11): ratio-style 7-day vs 90-day load with "well above usual" flags — validates our ACWR approach [U high]
- **Vitals app** (watchOS 11): nightly HR, RHR, wrist temp, SpO2, respiratory rate vs range → out-of-band notifications [U high]
- Sleep apnea probability feature; **Workout Buddy** (Apple Intelligence workout narration, watchOS 26 era) [U med]
- Long-rumored generative AI health coach for the Health app — **not verifiably shipped** as of authoring [U low-med]

### MyFitnessPal
- Massive food DB; **AI Meal Scan** photo logging, voice logging (Premium), macro plans, weekly digest insights [U high]

### Ultrahuman / Bevel / others
- Ultrahuman: ring + Dynamic Recovery + CGM-glucose-coupled meal guidance; metabolic marketplace [U med]
- Bevel: HRV-coaching app positioning [U med]
- Plan-generating coaches (Freeletics/Fitbod/Runna): adaptive periodized programs from logged performance — closest analog to our quest generator [U high]

## B. The 2025–26 Baseline (what users now expect)

Essentially every AI health tracker ships:
1. A **daily composite score** (readiness/recovery/energy/body battery)
2. **Sleep staging + debt + consistency**
3. **Training load** with acute-vs-chronic framing
4. **HRV as the hero signal** underneath most scores
5. A **conversational AI coach** over personal data
6. **Weekly report/digest** with plain-language takeaways
7. **Trend charts + anomaly alerts**
8. **Streaks/goals/habit mechanics** for adherence
9. Nutrition logging with barcode/photo shortcuts

→ HealthOK's PRD covers all nine *without a wearable and without the cloud* — scores degrade gracefully to activity/sleep signals where HRV is absent ([01 FR-C](01-prd.md)).

## C. Wearable-Dependent vs Phone-Only

| Feature | Needs wearable | Works phone-only |
|---|---|---|
| HRV-driven readiness | ✅ typically | degraded version via sleep+activity only |
| Sleep *staging* | ✅ | duration/consistency only |
| Skin-temp illness signals | ✅ | ❌ |
| Steps/distance/GPS workouts/calories | ❌ | ✅ |
| Training load (MET/duration based) | ❌ | ✅ |
| Nutrition logging | ❌ | ✅ |

Competitors assume their own hardware; HealthOK consumes whatever the user *already owns* through HealthKit/Health Connect ([06 §7](06-health-platform-sync.md)).

## D. Documented User Complaints → Our Opportunities

1. **Subscription fatigue** — $5–13/mo per service stacks up across band+ring+app [U high]
2. **Cloud privacy distrust** — intimate data leaving the device to ad-adjacent clouds [U high]
3. **Generic/hallucinated advice** from first-gen LLM coaches [U med]
4. **Data silos** — vendor ecosystems don't interoperate; switching devices loses continuity [U high]
5. **Offline uselessness** — most coaches are dead without internet [U high]

HealthOK answers: local-only architecture, deterministic grounded numbers (LLM narrates, never invents), platform-store interoperability, full offline function, ownership-friendly monetization.

## E. Monetization Norms

| Product | Model | Typical price point [U] |
|---|---|---|
| Whoop | Hardware included w/ annual membership | ~$200–350/yr tiers |
| Oura | Hardware + optional membership | ring ~$300 + ~$70/yr |
| Fitbit Premium | Freemium sub | ~$80/yr |
| Garmin Connect+ | Sub on free base | ~$60–100/yr |
| MyFitnessPal | Freemium | ~$240/yr street |

Open question for HealthOK (tracked [00 §9](00-product-overview.md)): **paid-upfront "buy the game"** fits the Solo Leveling identity and the ownership brand; decide by M3 gate ([09 §1](09-roadmap.md)).

## F. Sources

None seen live during authoring (search outage) — every claim above is `[U]`. The dispatched retrieval agent's fetched URLs will be appended here and inline-labeled `[V]` upon merge.
