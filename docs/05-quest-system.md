# 05 · The System — Quest & Gamification Specification

> *"You have acquired the qualifications to be a Player. Will you accept?"* — HealthOK turns that offer into a health contract. Companion docs: [03 Data Model §2.4](03-data-model.md) · engine package `quest_engine` ([02 §2](02-architecture.md)).

---

## 1. Design Philosophy

The System is modeled on Solo Leveling's game-like overseer, adapted by three rules:

1. **Strict but fair** — it demands consistency, never harm.
2. **Scaled to *you*** — Jinwoo's daily quest (100 push-ups / 100 sit-ups / 100 squats / 10 km run) is an *elite* workload. A sedentary E-rank gets E-rank numbers; the ladder does the scaling.
3. **Behavior over outcome** — quests reward actions (train, sleep on time, log meals), not scale weight. Identity is built by doing.

## 2. Canon Reference (what we adapt from)

| Solo Leveling element | Canon behavior | HealthOK adaptation |
|---|---|---|
| Daily Quest | Push-ups ×100, sit-ups ×100, squats ×100, run 10 km — canon name *"Preparation to Become Powerful"* (an acknowledged One-Punch-Man homage); failure escalates warnings → forced teleport to the Penalty Zone (Jinwoo's first: desert of giant centipedes, survive the timer) | Daily quest set generated per player level/goal; volumes anchored to WHO guidelines, scaled by rank |
| Penalty | Teleport to desert, giant centipedes — survive or die | ❌ Never. Light penalty: streak reset risk (shielded) + optional next-day penalty quest at *normal* intensity |
| Level up | XP → level, +stat points | XP from quests/logs → level, +3 allocatable stat points |
| Stats | STR / AGI / VIT / INT / PER govern combat abilities | Each stat maps to a real health domain (§5); radar chart on Character screen |
| Ranks | E→S hunter grades, re-evaluated by association | Rank gates require level **and** sustained completion rate (§6) |
| Dungeons/Keys | Timed instanced challenges with bosses | "Gate" programs (e.g., Couch-to-5K gate) + weekly Boss Battle stretch goal |
| Rewards chest | Loot on clear; monsters drop gold; **Random Reward boxes** = built-in variable reward | Cosmetic loot: titles, System themes, shields |
| Shop | Gold → potions/gear/consumables | Shields & themes bought with earned "Mana Crystals" (v1.1) |
| Titles | Achievement labels granting **permanent stat bonuses** | Milestone titles grant small capped bonuses (+1 stat, max 3 titled bonuses) from v1.1; v1 ships cosmetics-only |
| System voice | Terse, imperative, reward-focused; canon windows render with 「」 brackets | Copy tone guide (§9); we mirror the motif with `[ ]` styling |

*(Canon specifics from training knowledge — flagged for fan-review pass since live web verification was unavailable during authoring.)*

## 3. Quest Types

| Type | Cadence | Purpose |
|---|---|---|
| **Daily Quest** | every day, offered 05:00 local, expires 03:00 next | core loop; 3–4 objectives |
| **Rest Quest** | auto-inserted when readiness < 40 or user-scheduled | sleep/hydration/stretch only; **counts fully toward streak** |
| **Boss Battle ("Gate")** | weekly, accepted Sun–Mon | aggregated stretch goal; big XP + loot |
| **Penalty Quest** | day after unexcused miss (optional) | complete to restore lost streak immediately |
| **Goal Milestone** | from goal wizard (FR-G7) | program checkpoints (e.g., Week 4 of Couch-to-5K) |
| **Deload Directive** | forced every 5th week | volumes −30–40%; framed as "Mana Recovery Protocol" |

### 3.1 Daily quest generation (algorithm)

```dart
QuestSet generateDaily(Player p, Readiness r, Goal g) {
  final pool = templates.where((t) =>
      t.kind == daily &&
      t.enabledFor(p.goalType, p.equipmentFlags) &&
      !p.recentlyFailedFatigue(t.code));          // no repeat punishment loops

  // Base target scales with level, then bends to today's readiness:
  target(t) = clamp(
    t.baseTarget + t.scalePerLevel * p.level,
    t.hardMin,                                     // safety floor
    weeklyCapShare(t));                            // WHO/10%-rule ceiling

  final slots = (r.score < 40 || p.deloadWeek)
      ? [restQuest()]                              // full streak credit
      : pickBalanced(pool, domains: [strength, cardio, vit, int]);
  return QuestSet(slots, flavor: systemVoice.offer(p.rank));
}
```

Balance rule: each set contains ≤1 strength objective, ≤1 cardio objective, exactly 1 VIT objective (sleep-by-clock / hydration), and 1 micro INT objective (log all meals) — mirroring the five-stat economy.

### 3.2 Volume anchors (safety constants)

| Metric | Floor (E-rank lvl1) | Growth | Hard ceiling (any level) |
|---|---|---|---|
| Push-up reps/day | 10 | +2/lvl | 100 (canon number = cap!) |
| Sit-up reps/day | 15 | +3/lvl | 100 |
| Squat reps/day | 15 | +3/lvl | 100 |
| Walk/run km/day | 1.5 | +0.25/lvl | 10 |
| Exercise min/week | 75 | +5/lvl/wk | 300 (WHO upper band) |
| Sleep-by clock | user-chosen ±45 min window, non-negotiable slot | — | — |

Weekly totals always re-checked against WHO anchors (150 min moderate + 2× strength) and the ~10%/week progression cap before offering.

## 4. XP Economy

| Event | XP |
|---|---|
| Daily quest objective complete | 10–15 (by difficulty tier) |
| Perfect day (all objectives) | +10 bonus |
| Rest Quest completed | full normal credit (never discounted) |
| Boss Battle clear | 80–150 |
| Penalty Quest complete | restores streak, 0 XP |
| Missed daily (unshielded) | −20 (floor 0 total) |

**Level curve:** `xpToNext(n) = 100 + 25·(n−1)` (arithmetic growth). Worked example: L1→2 = 100 XP (~5 perfect days at tier-1 volumes); L10→11 = 325 XP (~2 weeks). Target pacing: **level ≈ 8–12 in month one**, S-rank territory (~lvl 40) reachable in 12–18 committed months — a real "long game."

Every XP mutation writes an `xp_events` ledger row ([03 §2.4](03-data-model.md)); `player.xp_total` is a derived cache audited post-migration.

## 5. Stat Mapping (STR · AGI · VIT · INT · PER)

| Stat | Governs in-app | Grows via |
|---|---|---|
| **STR** 💪 | Strength domain | push/pull/squat quests, strength workouts logged |
| **AGI** 🏃 | Cardio/mobility domain | run/walk/cycle km, exercise minutes |
| **VIT** ❤️ | Recovery domain | sleep-by-clock hits, hydration, rest-day compliance |
| **INT** 🧠 | Nutrition domain | full-day meal logs, macro-target adherence days |
| **PER** 👁️ | Consistency domain | logging streaks, check-in punctuality, weekly debrief reads |

+3 free points per level-up (canon's exact per-level count varies across translations [U med] — +3 is our design constant); auto-suggest button weights points toward the weakest stat vs. goal template (e.g., fat_loss suggests VIT/AGI). Radar chart renders the five stats; titles unlock at thresholds (e.g., VIT 30 = "Undead" 😄).

## 6. Rank Ladder

| Rank | Requirements (all of) | Unlocks |
|---|---|---|
| **E** | start | Daily quests, basic themes |
| **D** | Lvl 5 · 7-day completion ≥ 70% | First Gate (boss), shield crafting |
| **C** | Lvl 12 · 21-day ≥ 70% · 1 boss clear | Penalty immunity token/month, theme shop |
| **B** | Lvl 20 · 30-day ≥ 75% · 3 boss clears | Custom quest builder (self-set targets within caps) |
| **A** | Lvl 30 · 60-day ≥ 80% · 6 boss clears | Advanced programs (half-marathon gate), gold theme |
| **S** | Lvl 40 · 90-day ≥ 85% · 10 boss clears | "Sovereign" crest, legacy export certificate |

Rank review runs nightly; **completion-rate windows are rolling**, so one bad week doesn't erase three good months.

## 7. Penalties, Shields & Mercy (anti-shame design)

Failure sequence for an uncompleted accepted daily:

1. **Shield check:** consume a Streak Shield (earned: every 7-streak grants 1; boss clears grant 1) → nothing lost, System notes it stoically.
2. **No shield → Mercy Rule:** the *first* miss in any ISO-week never breaks the streak (life happens once a week).
3. **Real miss:** streak resets to 0; best_streak preserved; −20 XP; System offers a **Penalty Quest** next day (same volume, no escalation) — completing it instantly restores the previous streak length.
4. **Hard floor:** penalties never remove levels, stats, ranks, or cosmetics. Progress is sacred; only momentum is at stake.

Injury flag (Settings): pauses scaling, converts all quests to Rest tier, freezes rank-window decay until cleared.

## 8. Boss Battles ("Gates") & Programs

- Weekly Gate = aggregate objective derived from the week's actual capacity (e.g., "Clear the C-Rank Gate: 25 km walked + 3 strength sessions"). Accept Sunday; clear anytime by Saturday night.
- Program Gates = structured multi-week journeys (Couch-to-5K as "Awakening Trial", 200-push-up progression as "Iron Body Trial") with milestone loot.
- Failed Gate: no punishment beyond missing loot; may retry next week at −10% difficulty (adaptive).
- Post-v1 **Party Raid** experiments obey the anti-Habitica rule: shared glory, individual attribution, *never* collective punishment for one member's missed day. Canon "Instant Dungeon Keys" inspire on-demand difficulty-matched sessions generated anywhere.

## 9. System Voice & Copy Examples

Terse, imperative, second person, zero emojis inside System lines, reward-focused:

> **[DAILY QUEST ARRIVED]** Push-ups 0/24 · Squats 0/24 · Walk 1.5km 0/1.5 · Sleep by 23:30. Failure has consequences.
> **[QUEST COMPLETE]** You have earned 55 XP. Consistency acknowledged.
> **[LEVEL UP!]** Lv 9 → 10. +3 stat points available. Your shadow grows stronger.
> **[WARNING]** Streak at risk. Complete today's quest before 03:00 or face the consequence.
> **[REST QUEST ISSUED]** Recovery detected as optimal strategy. Sleeping is not retreating.

Localization note: System voice strings are i18n keys from day one (NFR-L10N).

## 10. Ethical Guardrails (binding on engineering)

1. **WHO-anchored ceilings** enforced in code — the generator physically cannot offer >300 exercise-min/week or unsafe progressions.
2. **Rest Quests carry full streak credit** — rest is never punished.
3. **No body-weight or calorie numbers ever appear in quest text** (ED-safe); goals express via behaviors.
4. **Deload every 5th week** automatic; skippable only forward, not backward into intensity.
5. **Notification budget respected** — the System reminds, it does not nag (max 2/day default, quiet hours honored, FR-I).
6. **Penalty asymmetry law:** losses touch only streak/XP; never levels, stats, access, or health guidance.

## 11. `quest_engine` Public Interface (sketch)

```dart
abstract class QuestEngine {
  QuestSet generateDaily({required Player p, required Readiness? r, DateTime now});
  XpResult completeObjective(Quest q, Objective o, {required double actual});
  RankReview reviewRank(Player p, RollingWindows w);
  PenaltyResolution resolveMissedDay(Player p, DateTime date);
  GatePlan planWeeklyGate(Player p, WeekHistory h);
}
```

Pure functions in → pure results out; persistence handled by repositories above it. All tunables live in one `balance.yaml` asset reviewed by tests (golden-file balance snapshots prevent accidental economy inflation).

---
*Next: [06 · Health Platform Sync](06-health-platform-sync.md)*
