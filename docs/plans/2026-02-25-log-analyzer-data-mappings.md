# WCL Log Analyzer — Data Mappings Reference

> What useful databases, mappings, and analyses can we build from combat log data?

Each section describes: **what raw data we have**, **what we derive from it**, and **how it maps to rotation code**.

---

## 1. Spell Priority Validation

**Raw data:** Cast events with timestamps, ordered chronologically per player

**What we derive:**
- **Transition matrix** — spell A → spell B frequency. "After Mangle, top players Shred 82% of the time, Rip 12%, Rake 6%"
- **Priority violations** — cases where a lower-priority ability was used when a higher-priority one was available (e.g., used Shred when Rip was about to fall off)
- **Opener sequences** — first 10-15 casts of every fight, aggregated across top parsers to find the consensus opener
- **Phase-specific priorities** — how priority ordering shifts during execute phase (<25% HP), bloodlust, or AoE phases

**Maps to code:**
- Strategy ordering in `rotation_registry:register(playstyle, strategies)` — the array position IS the priority
- `matches()` conditions (thresholds, gates)
- Burst alignment in `should_auto_burst()`

---

## 2. DoT/Debuff Uptime Analysis

**Raw data:** `applydebuff`, `refreshdebuff`, `removedebuff` events with timestamps

**What we derive:**
- **Uptime percentage** per debuff per fight — "top cat druids maintain 96% Rip uptime on Gruul"
- **Refresh timing** — average time remaining when debuff is refreshed (pandemic window usage)
- **Drop count & duration** — how many times the debuff fell off and for how long
- **Clip count** — refreshes that overwrote significant remaining duration (wasted ticks)
- **Refresh-under-pressure** — does uptime drop during movement phases or add spawns?

**Maps to code:**
- Refresh threshold constants (e.g., "refresh Rip when < 2s remaining")
- Strategy `matches()` conditions checking debuff duration
- Pandemic window logic (TBC doesn't have pandemic, but early refresh = wasted energy)

---

## 3. Buff Tracking & Snapshotting

**Raw data:** `applybuff`, `refreshbuff`, `removebuff` events

**What we derive:**
- **Self-buff uptime** — Inner Fire, Lightning Shield, Slice and Dice, Battle Shout, etc.
- **Proc tracking** — Clearcasting, Flurry, Nightfall, Backlash proc rates and utilization
- **Proc waste** — how often a proc expires unused (Clearcasting that times out = wasted free cast)
- **External buff awareness** — Bloodlust, Innervate, Power Infusion timing and alignment
- **Snapshot analysis** — DoTs applied during Tiger's Fury or trinket procs (TBC DoTs snapshot on application for some spells)

**Maps to code:**
- Self-buff middleware priority
- Proc-reactive strategy ordering (e.g., "if Clearcasting, prioritize expensive spell")
- Burst CD alignment with external buffs

---

## 4. Resource Management Profiles

**Raw data:** Cast events + resource events (energize, drain), spell cost data

**What we derive:**
- **Resource at time of each cast** — "top players average 52 energy when casting Rip"
- **Pooling patterns** — GCD gaps where the player intentionally waited for resources
- **Pooling thresholds** — energy/mana level at which pooling starts and ends
- **Resource waste** — time spent at max energy/mana (capped = wasting generation)
- **Finisher timing** — combo points and energy when finishers are used
- **Mana efficiency** — for casters, mana/damage ratio and conservation patterns

**Maps to code:**
- Energy/mana threshold constants in strategy `matches()` conditions
- Pooling gate logic (e.g., `cat_state.pooling` flag)
- Resource-based ability gating

---

## 5. Cooldown Usage Patterns

**Raw data:** Cast events for CD abilities + buff/debuff events for their effects

**What we derive:**
- **CD timing relative to fight start** — when each CD is first used
- **CD stacking** — which CDs are paired (Adrenaline Rush + Blade Flurry, Death Wish + Recklessness)
- **CD alignment with external buffs** — Tiger's Fury during Bloodlust, trinkets during Heroism
- **CD usage count** — are they using it on cooldown or holding it?
- **Execute phase CD usage** — do top players save CDs for execute?
- **Wasted CD duration** — CD buff active during downtime (running, target immune, etc.)

**Maps to code:**
- `should_auto_burst()` condition tuning (burst_on_pull, burst_on_bloodlust, burst_on_execute)
- `is_burst = true` strategy/middleware tagging
- CD stacking logic in offensive cooldown middleware

---

## 6. Interrupt Intelligence Database

**Raw data:** `SPELL_INTERRUPT` events (interrupter spell + interrupted spell), `SPELL_CAST_START` events on targets

**What we derive:**
- **Priority interrupt spell list** — which enemy casts top players actually interrupt, aggregated across many logs
- **Ignore list** — casts that are never interrupted (filler damage, instant casts)
- **Interrupt reaction time** — time between cast start and interrupt landing
- **Interrupt success rate** — kicks that landed vs wasted (target already finished casting)
- **Tab-target interrupt patterns** — when players switch targets to interrupt a priority cast, then switch back
- **Per-boss interrupt priority** — "on High Astromancer Solarian: always kick Arcane Missiles, ignore Blinding Light"
- **School lockout awareness** — which school gets locked, does it matter for subsequent casts?

**Maps to code:**
- `NS.INTERRUPT_PRIORITY` spell database (from shared middleware design)
- `NS.should_interrupt()` decision function tuning
- Tab-target interrupt state machine thresholds
- Per-encounter interrupt rules

---

## 7. Resistance & Immunity Database

**Raw data:** `SPELL_MISSED` events with miss type (IMMUNE, RESIST, DODGE, PARRY, BLOCK, MISS, ABSORB)

**What we derive:**
- **Taunt immune bosses** — targets where Growl/Taunt always returns IMMUNE
- **Bleed immune targets** — mobs immune to Rip, Rake, Rupture, Rend, Deep Wounds
- **Spell resist rates by target** — partial resist rates for specific spells on specific bosses
- **Fear immune targets** — relevant for Warlock, Warrior Intimidating Shout
- **CC immune targets** — Polymorph, Entangling Roots, etc.
- **Dodge/parry rates** — positional awareness (high parry = attacking from front)
- **Miss rates** — hit cap validation (miss rate > expected = need more hit rating)

**Output format:**
```json
{
  "target_database": {
    "Gruul the Dragonkiller": {
      "encounter_id": 649,
      "immunities": {
        "taunt": { "sample_size": 50, "immune_rate": 1.0, "confirmed": true },
        "bleed": { "sample_size": 50, "immune_rate": 0.0, "confirmed": false }
      },
      "resist_rates": {
        "Faerie Fire (Feral)": { "attempts": 200, "resists": 0, "rate": 0.00 }
      }
    }
  }
}
```

**Maps to code:**
- Skip Growl/Challenging Roar on taunt-immune bosses
- Skip bleed abilities on bleed-immune targets
- `NS.has_total_immunity()` / `NS.has_phys_immunity()` could reference this
- Could generate a Lua lookup table for the rotation to check at runtime

---

## 8. Opener Sequences

**Raw data:** First 15-20 seconds of every fight's cast events

**What we derive:**
- **Consensus opener** — the most common opening sequence across top parsers
- **Opener variations** — alternative openers and their DPS impact
- **Pre-pull actions** — buffs/items used before pull timer hits
- **First GCD timing** — how quickly top players get the first cast off
- **Spec-specific opener benchmarks** — "Cat: Mangle → Shred → Shred → Shred → Shred → Rip"

**Output format:**
```json
{
  "opener_analysis": {
    "consensus_sequence": ["Mangle", "Shred", "Shred", "Shred", "Shred", "Rip"],
    "frequency": 0.72,
    "variants": [
      { "sequence": ["Mangle", "Shred", "Rake", "Shred", "Shred", "Rip"], "frequency": 0.18 },
      { "sequence": ["Mangle", "Tiger's Fury", "Shred", "Shred", "Shred", "Rip"], "frequency": 0.10 }
    ],
    "avg_first_gcd_delay": 0.15,
    "avg_time_to_first_finisher": 6.2
  }
}
```

**Maps to code:**
- Validates or informs the opener section of each spec's strategy ordering
- Confirms whether the rotation's natural priority produces the optimal opener

---

## 9. AoE / Cleave Decision Patterns

**Raw data:** Cast events + damage events with target counts, `enemy_count` from multi-target spells

**What we derive:**
- **AoE threshold** — at how many targets do top players switch from single-target to AoE abilities?
- **Cleave ability usage** — when do they use Cleave vs Heroic Strike, Swipe vs single-target, etc.
- **DoT spreading** — multi-dotting patterns (how many targets get DoTs maintained)
- **AoE vs priority target balance** — time spent on boss vs adds during add phases

**Maps to code:**
- `enemy_count` threshold constants in AoE strategy `matches()` conditions
- AoE vs single-target strategy switching logic

---

## 10. Defensive Cooldown Analysis

**Raw data:** Cast events for defensive abilities, damage taken events, death events

**What we derive:**
- **Defensive CD timing** — when are Shield Wall, Barkskin, Divine Shield, etc. used?
- **Pre-emptive vs reactive** — used before big hit (planned) or after (panic)?
- **Health at time of defensive** — what HP% triggers defensive usage?
- **Deaths vs defensives available** — did the player die with unused defensives?
- **Healthstone/potion timing** — HP threshold when consumables are used
- **Healer dependency** — correlation between self-healing/defensives and survival

**Maps to code:**
- Defensive middleware HP thresholds
- `is_defensive = true` middleware trigger conditions
- Recovery item HP% settings (healthstone_hp, healing_potion_hp)

---

## 11. Tank-Specific Analysis (Bear/Prot)

**Raw data:** Damage taken events, threat events (taunt casts), buff uptimes, target-of-target

**What we derive:**
- **Active mitigation uptime** — Shield Block, Maul queue, Demo Roar uptime
- **Taunt usage patterns** — when and why taunts are used (target switch, loose add, resist recovery)
- **Taunt success rate** — per target, per encounter
- **Demo Roar timing** — how quickly into the fight it's applied, uptime percentage
- **Ability priority under threat pressure** — does the priority shift when multiple mobs are active?
- **Rage/mana efficiency** — resource management for tanks specifically
- **Hit table coverage** — dodge + parry + block + miss from the boss's perspective (requires damage taken analysis)

**Maps to code:**
- Bear/Prot strategy ordering
- Demo Roar refresh threshold
- Maul vs other rage dump priority
- `bear_no_taunt` setting validation

---

## 12. Healing Spec Analysis

**Raw data:** Healing events, overhealing events, buff events, mana events

**What we derive:**
- **Heal priority** — which heals are used most and when
- **Overheal percentage** — per spell, identifying inefficient healing
- **Downranking patterns** — which heal ranks are used at which HP deficits
- **Mana management** — Innervate/mana pot timing, OOM frequency
- **Assignment adherence** — tank healer vs raid healer spell selection
- **Reaction time** — time between damage taken and heal landing

**Maps to code:**
- Healing spell rank selection logic
- Heal target priority (`scan_healing_targets()` in healing.lua)
- Mana conservation thresholds
- Emergency heal HP% triggers

---

## 13. Form/Stance Management (Druid, Warrior)

**Raw data:** Cast events for form/stance changes, buff events for form buffs

**What we derive:**
- **Powershift frequency** — how often cat druids shift out and back for energy
- **Powershift timing** — at what energy level they powershift (Wolfshead Helm gives 20)
- **Stance dance patterns** — Warrior switching between Battle/Berserker/Defensive
- **Form time distribution** — % of fight in each form
- **Unintended form time** — time in caster form during combat (bad)

**Maps to code:**
- Powershift energy threshold in cat state
- `is_auto_form` strategy behavior
- Form suggestion logic (A[1] icon)

---

## 14. Totem Twist Analysis (Enhancement Shaman)

**Raw data:** Cast events for totem spells, buff events for totem buffs (WF, GoA, etc.)

**What we derive:**
- **Twist cycle timing** — WF → GoA twist phase durations
- **FNT twist success rate** — Fire Nova Totem placement timing within rotation
- **Totem uptime** — per-slot totem uptime percentages
- **Twist efficiency** — GCDs spent on twisting vs damage abilities
- **Optimal twist window** — when in the attack swing cycle totems are placed

**Maps to code:**
- `wf_twist` / `fnt_twist` state table tuning
- Twist phase duration constants
- FNT single-target bypass settings

---

## 15. Seal Twist Analysis (Retribution Paladin)

**Raw data:** Cast events for Seal of Command, Seal of Blood/Martyr, Judgement, buff events

**What we derive:**
- **Twist success rate** — % of swings where both SoC and SoB proc
- **Twist window timing** — how far before the swing SoC is applied
- **Twist DPS gain** — damage from twisting vs non-twisting swings
- **Judgement timing** — when Judgement is used relative to seal swaps
- **Seal uptime** — % of fight with no seal active (gap)

**Maps to code:**
- `in_twist_window` threshold tuning
- Seal priority ordering
- Judgement strategy timing

---

## 16. Pet Management (Hunter, Warlock)

**Raw data:** Pet cast events, pet damage events, pet death events, pet buff events

**What we derive:**
- **Pet uptime** — % of fight pet is alive and attacking
- **Pet ability usage** — auto-cast vs manual ability firing
- **Pet positioning deaths** — pet dying to AoE/cleave
- **Kill Command timing** — (Hunter) alignment with pet crits

**Maps to code:**
- Pet management middleware
- `pet_hp` / `pet_active` threshold logic

---

## 17. Cross-Log Aggregation

When we pull many logs (10-25 per boss), we can aggregate:

| Aggregation | Output |
|------------|--------|
| **Spell CPM averages** | "Top cat druids average 17.2 Shred CPM on Gruul (σ=1.8)" |
| **Uptime benchmarks** | "95th percentile Rip uptime is 96.4%" |
| **Opener consensus** | "72% of top parsers open with Mangle→Shred×4→Rip" |
| **Resistance database** | "Gruul: 100% taunt immune (50 samples), 0% bleed immune" |
| **Interrupt priority list** | "Healing Wave interrupted 94% of attempts, Shadow Bolt only 12%" |
| **Resource thresholds** | "Median energy at Rip cast: 52 (IQR 42-65)" |
| **CD alignment rates** | "Tiger's Fury used during Bloodlust: 89% of opportunities" |

This moves from "what one player did" to "what the best players consistently do" — much more reliable for rotation tuning.

---

## Output Files Summary

| File | Contents | Updates |
|------|----------|---------|
| `data/fights/<boss>-<player>-<spec>.json` | Per-fight enriched data | Per fetch |
| `data/comparisons/<boss>-comparison.json` | Two-fight diff | Per compare |
| `data/aggregates/<boss>-<spec>-aggregate.json` | Multi-log averages | After batch fetch |
| `data/databases/interrupt-priority.json` | Interrupt spell database | Accumulated |
| `data/databases/immunity-resistance.json` | Target immunity/resist data | Accumulated |
| `data/databases/opener-sequences.json` | Per-spec opener consensus | Accumulated |
| `data/databases/resource-thresholds.json` | Resource benchmarks per spell | Accumulated |
