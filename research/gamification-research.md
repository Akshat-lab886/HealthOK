# HealthOK Gamification Research Dossier

> Search infra note: both web_search attempts failed (API auth error ×2) → per protocol, completed from internal knowledge. Every claim labeled [U]; sources list empty because no URL was actually seen.

## 1. Solo Leveling Canon (get it right or fans riot)

- **Origin**: Sung Jinwoo, mocked as "the weakest hunter of mankind" (E-rank), survives the Cartenon Temple Double Dungeon by accepting death; he reawakens in a hospital bed facing a game-like interface — the **System** — as a "Player," the only human whose power grows by leveling while all other hunters stay locked at their awakening rank. [U high]
- **Daily Quest — "Preparation to Become Powerful"**: 100 push-ups, 100 sit-ups, 100 squats, a 10 km run. Deliberately identical to Saitama's *One Punch Man* regimen (acknowledged homage). Arrives at a fixed time daily; may be declined, but not ignored. [U high]
- **Failure = Penalty Zone**: ignoring it brings escalating warnings, then forced teleport into a hostile pocket dimension. Jinwoo's first penalty: a blazing desert infested with giant centipedes; he had to survive until the timer ran out and barely made it. Repeat offenses escalate lethality. Skipping is not guilt — it's mortal risk. [U high mechanic / U low exact timers]
- **Stats** — levels grant allocatable Ability Points (exact per-level count varies across translations/adaptations [U med]) across five stats:
  - **STR** — raw physical force: melee damage, lifting, feats of strength.
  - **AGI** — speed, reflexes, movement/attack tempo.
  - **VIT (Stamina)** — HP pool, endurance, regeneration.
  - **INT** — mana pool + mana regeneration, magic potency.
  - **PER (Perception)** — sensory acuity: spotting hidden threats, reading situations, evasion awareness.
  [U high on domains]
- **Ranks**: hunters and gates graded E < D < C < B < A < S. E ≈ barely above civilian; S = national-asset rarity, single digits per country early on. The hook: Jinwoo's license still reads E while he grows without ceiling. [U high]
- **Rewards & economy**: quests pay EXP plus items (sometimes Random Reward boxes — built-in variable reward); monsters drop gold and loot. The System **Shop** sells potions, gear, and consumables for gold. [U high]
- **Keys & Instant Dungeons**: keys open private pocket dungeons scaled to him — safe, repeatable grinding grounds invisible to outsiders (where he farmed loot such as Kasaka's venom fang). Design meaning: personalized, difficulty-matched practice spaces on demand. [U high mechanic / U med named instance]
- **Titles**: achievement labels (milestones, kill counts) granting permanent stat bonuses — identity badges with mechanical teeth. [U high]
- **System voice**: bracketed windows, terse second-person imperative, zero warmth: "「Daily Quest has arrived.」" … "「Warning: you have not accepted the Daily Quest. Failure to complete it will result in a penalty.」" Cold, procedural, unarguable — never chatty, never cute. [U high]

## 2. Proven Patterns from Shipped Products

| Product | Core mechanics | Primary motivator |
|---|---|---|
| Duolingo | Streak counter; purchasable **Streak Freeze** buffer; weekly Leagues (Bronze→Diamond) with promotion/demotion cut lines; XP and gem chests | Loss aversion + social comparison + variable rewards [U high] |
| Habitica | Missed dailies deal HP damage; death costs a level + gear; party quests where a boss damages **every** member for each member's missed daily | Loss aversion weaponized socially [U high] |
| Apple Watch rings | Move/Exercise/Stand rings; closing all three as a daily ritual; sharing, competitions, awards | Identity ("I close my rings") + visible competence [U high] |
| Zombies, Run! | Audio drama mid-run; surprise zombie chases = spontaneous sprints; collected supplies build a base | Narrative immersion + fear-driven interval variability [U high] |
| Strava | Segment leaderboards/KOMs; monthly distance challenges with badges; kudos feed | Social status + athlete identity [U high] |

Synthesis: loss aversion produces sharp short-term engagement but needs relief valves; variable rewards fight habituation; identity is the stickiest long-term glue; social layers amplify whatever core loop exists — healthy or toxic. [U high]

## 3. Behavioral-Science Guardrails

- **Self-Determination Theory** (autonomy, competence, relatedness): quest *choice* feeds autonomy; clean progression and stat feedback feed competence; parties/guilds feed relatedness. Heavy external punishment can crowd out intrinsic motivation (overjustification effect) — make penalties dramatic in fiction, mild in consequence. [U high]
- **Hard streaks churn users**: streaks demonstrably boost engagement, but rigid ones create anxiety and shame-quitting after an inevitable break; forgiving designs (freezes, grace days, weekly-minute goals instead of binary daily gates) retain better. [U med]
- **Loss aversion cuts both ways**: Penalty-Zone dread is a great hook and a churn engine if failure ever feels unfair. Every threat needs a rescue mechanic. [U high]
- **Injury risk**: gamified pressure makes people train through pain — tendinopathy, stress fractures, rhabdomyolysis. Never reward intensity spikes without load context. [U high]
- **WHO anchors**: ≥150 min moderate (or ≥75 min vigorous) aerobic activity weekly, muscle-strengthening ≥2 days/week, plus balance work for older adults — adopt these as HealthOK's canonical "Guild Standards." [U high]
- **Conservative progression**: cap volume growth near 10%/week; schedule deload weeks and rest days as first-class mechanics that still count. [U med]

## 4. Existing RPG/Anime Fitness Apps

- **Habitica** — generic RPG habit tracker; no fitness intelligence; HP punishment shames some users into quitting. [U high]
- **Fitness RPG, Wokamon, Walkr** — step-counter wrappers: walking grows a character, pet, or spaceship. Charming but shallow: cardio-only, no strength programming, no adaptive difficulty. [U high category / U med details]
- **Solo Leveling space**: official SL titles (e.g., *Solo Leveling: Arise*) are combat ARPGs, not fitness; fan-made "hunter system" workout spreadsheets and subreddit trackers exist, but no polished licensed SL-fitness product ships adaptive load or safety rails. [U med]
- **Gaps HealthOK can own**: (1) canon-grade fantasy framing with real exercise science underneath; (2) Instant-Dungeon Keys generating difficulty-scaled sessions anywhere; (3) rest-day mechanics protecting streaks *and* joints; (4) wearable-informed auto-deload; (5) party raids with fair individual attribution instead of collective punishment.

## Design Principles for HealthOK

1. **Canon first** — the Daily Quest *is* push/sit/squat ×100 + 10 km run in lore; ship rank-scaled versions ("E-rank: 10/10/10 + 1 km") so fans see fidelity and beginners see feasibility. Start everyone at E-rank, honestly.
2. **The System speaks in brackets** — terse imperative window copy, no exclamation marks, no mascot warmth. The tone *is* the product.
3. **Teeth in fiction, rails in fact** — warnings escalate exactly like canon, but the "Penalty Zone" is a redemption quest (a make-up session), never injury risk or a shame spiral.
4. **Five stats, honest mapping** — STR/AGI/VIT/INT/PER ↔ strength / mobility-speed / cardio-endurance / recovery-knowledge / body-awareness; level-ups grant allocatable points (autonomy).
5. **Keys, not grind** — Instant Dungeon Keys spawn personalized, difficulty-matched workouts anywhere; the Shop turns effort into meaningful choices, with occasional random boxes for variable reward.
6. **Rest is a quest** — sleep, mobility, and deloads pay EXP and hold streaks; WHO 150 min + 2×strength is the Guild Standard; enforce ≤~10% weekly volume growth.
7. **Titles over trophies** — identity-granting achievements with permanent stat bonuses beat public leaderboards; leagues/competition strictly opt-in.
8. **Parties share glory, not damage** — co-op bosses credit carried teammates; never punish the group for one member's missed day (the anti-Habitica rule).

## Sources

None. Both web_search attempts failed with API authentication errors; no URLs were seen, so per instructions the list contains only what was actually viewed: nothing.
