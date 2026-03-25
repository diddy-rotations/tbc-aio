# Warrior DPS Improvements Design

**Date:** 2026-03-25
**Branch:** `feature/warrior-dps-improvements`
**Scope:** Arms, Fury, and new Kebab (DW Arms) playstyles — rage management, AoE priority, execute phase, Sweeping Strikes pooling

## Problem Statement

The warrior rotation has several DPS gaps identified by comparing against the wowsims TBC warrior sim and the omni rotation:

1. **HS/Cleave starves WW of rage** — No check prevents HS queue when WW is about to come off CD
2. **Execute phase pools too high** — Requires 25 rage instead of base cost; HS stays enabled (wastes rage that Execute converts to damage at 21 per point)
3. **Arms AoE priority wrong** — MS always fires before WW regardless of target count; WW hits 4 targets and should take priority in AoE
4. **No Sweeping Strikes rage pooling** — WW/fillers spend rage right before SS comes off CD, causing SS to be missed or fired without WW to amplify it
5. **No Kebab (DW Arms) playstyle** — Dual-wield Arms warriors have no dedicated rotation

## Changes

### 1. HS/Cleave WW Starvation Fix

**Files:** `arms.lua`, `fury.lua`, `kebab.lua`

Add `would_starve_ww()` / `would_starve_core()` checks to HS/Cleave `matches()`. If WW CD <= 1.5s and `(rage - hs_cost) < ww_cost`, skip the queue. Same for MS/BT.

### 2. Execute Phase — Match Sim

**Files:** `arms.lua`, `fury.lua`, `kebab.lua`, `schema.lua`

- Change Execute threshold from `rage < 25` to spell's actual base cost (use `GetSpellPowerCostCache()`)
- Default `hs_during_execute` to `false` for all DPS specs (sim disables HS during execute)

### 3. AoE Priority — WW Above MS for Arms

**File:** `arms.lua`

In `Arms_MortalStrike.matches()`, yield to WW when `enemy_count >= 2` and WW is ready — mirrors Fury's existing `fury_ww_prio_count` pattern.

### 4. Sweeping Strikes Rage Pooling

**Files:** `arms.lua`, `fury.lua`, `kebab.lua`

New `should_reserve_for_sweeping()` function per file. When `enemy_count >= 2`, SS CD <= 2s, and `rage < 60`, hold WW and fillers. Applied to WW `matches()` and Slam `matches()`.

### 5. HS Threshold Defaults

**File:** `schema.lua`

- Arms: 50 → 45
- Fury: 50 → 40
- Kebab: 40 (new)

### 6. Kebab Playstyle

**New file:** `kebab.lua` (auto-discovered at order 7 by build.js)
**Modified files:** `class.lua`, `schema.lua`

#### Detection
Explicit dropdown entry "Kebab (DW Arms)" in playstyle selector. User selects it manually.

#### Stance Management
- Home stance: Berserker (for WW access + 3% crit)
- Dance to Battle for Overpower procs (rage protection, skip if rage > 50)
- Swap back to Berserker when no OP proc and WW ready or rage > 25

#### Single Target Priority
1. Execute (< 20%, fire at base cost)
2. Whirlwind (above MS — DW benefits more)
3. Mortal Strike
4. Overpower (only if already in Battle Stance with proc)
5. Victory Rush
6. Sunder maintenance (if configured)
7. Thunder Clap / Demo Shout (if configured)
8. HS/Cleave dump (with WW starvation check)

#### AoE Priority
1. Sweeping Strikes (with rage pooling)
2. Whirlwind (guarded by SS reserve)
3. Mortal Strike
4. Cleave dump

#### What Kebab Does NOT Have (vs regular Arms)
- No Slam (DW doesn't weave — no swing timer reset benefit)
- No Rend (no Blood Frenzy synergy assumed)
- WW above MS always, not just in AoE
- Berserker is home stance, not Battle

#### Schema — New Tab 7: "Kebab (DW Arms)"
Settings: `kebab_use_overpower`, `kebab_use_whirlwind`, `kebab_use_sweeping_strikes`, `kebab_execute_phase`, `kebab_use_ms_execute`, `kebab_use_ww_execute`, `kebab_hs_rage_threshold` (default 40), `kebab_hs_during_execute` (default false), `kebab_use_victory_rush`, `kebab_use_death_wish`

#### class.lua Changes
- Add `"kebab"` to `playstyles` array
- Add `kebab = 3` to `PREFERRED_STANCE` (Berserker)
- Add `playstyle_spells.kebab` entry
- Add dashboard entries for kebab (cooldowns, buffs, debuffs)

## Out of Scope
- Protection spec (unaffected by these changes)
- Berserker Rage timing (off-GCD, middleware approach is correct)
- HS rage buffer on ability costs (complex, deferred — WW starvation fix addresses the main symptom)
