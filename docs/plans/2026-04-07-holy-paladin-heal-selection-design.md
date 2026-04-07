# Holy Paladin Smart Heal Selection Design

**Date:** 2026-04-07
**Status:** Approved

## Problem

The current HL vs FoL decision is rudimentary — just HP% thresholds with a tank/non-tank split. No consideration of deficit vs heal amount, incoming damage, healing reduction debuffs, Light's Grace management, or downranking. Holy Shock blocks the rotation when the target is out of its 20yd range.

## Design

### 1. Rank Tables + Per-Rank Actions

Add individual Action entries and rank tables for both spells in `class.lua`, sorted high-to-low (matching druid healing pattern).

**Holy Light ranks:**

| Rank | Base Min | Base Max | Spell ID |
|------|----------|----------|----------|
| 11   | 2196     | 2446     | 27136    |
| 10   | 1773     | 1971     | 27135    |
| 9    | 1619     | 1799     | 25292    |
| 8    | 1272     | 1414     | 10329    |
| 7    | 968      | 1076     | 10328    |
| 6    | 717      | 799      | 3472     |
| 5    | 506      | 569      | 1042     |
| 4    | 322      | 368      | 1026     |
| 3    | 167      | 196      | 647      |
| 2    | 81       | 96       | 639      |
| 1    | 42       | 51       | 635      |

**Flash of Light ranks:**

| Rank | Base Min | Base Max | Spell ID |
|------|----------|----------|----------|
| 7    | 458      | 513      | 27137    |
| 6    | 356      | 396      | 19943    |
| 5    | 278      | 310      | 19942    |
| 4    | 206      | 231      | 19941    |
| 3    | 153      | 171      | 19940    |
| 2    | 102      | 117      | 19939    |
| 1    | 67       | 77       | 19759    |

**Healing coefficients (with Healing Light talent, +12%):**
- HL: `(base_avg + bonus_healing * 0.7143) * 1.12`
- FoL: `(base_avg + bonus_healing * 0.4286) * 1.12`

Bonus healing read at runtime via `GetSpellBonusHealing()`.

### 2. `select_heal()` Decision Function

Single function that returns `{spell_action, rank_label}` or nil.

**Step 1: Determine spell type (HL vs FoL)**

Evaluated in order — first match wins:

1. **Moving** → nil (can't cast either, Holy Shock handled separately)
2. **MS / healing reduction on target** → HL (FoL is useless at 50% reduced healing)
3. **Divine Favor active** → HL (maximize guaranteed crit value)
4. **High incoming DPS** → HL when `GetDMG() > max_fol_heal / 1.5` (damage per second exceeds FoL throughput)
5. **Deficit math:**
   - Compute max rank FoL expected heal and max rank HL expected heal
   - `deficit > max_fol_heal * 1.3` → HL (FoL can't cover this)
   - Otherwise → FoL
6. **Tank proactive** (in combat, HP == 100%, mana > floor) → FoL
7. **Fallback** → FoL

**Step 2: Select best rank**

Walk the chosen rank table high-to-low:
- `expected = (base_avg + bonus_healing * coefficient) * 1.12`
- If `expected > deficit * 1.3` → try lower rank (would overheal too much)
- Check `IsReady()` to confirm rank is trained
- If no rank fits (all overheal), use lowest trained rank
- If target has MS, skip overheal optimization (need raw throughput)

### 3. Light's Grace Proc Strategy

Separate strategy `Holy_LightsGraceProc`, positioned above `HealTarget`.

- Fires when: `lights_grace_active == false` AND in combat AND someone needs healing (HP < 100%)
- Safety gate: skip if any target below 30% HP (use real heal instead)
- Skip if Divine Favor active (don't waste crit on R1)
- Casts HL Rank 1 (cheapest possible, just to proc the buff)
- Uses `HolyLightR1` action (ID 635)

### 4. Holy Shock Range Fix

Add `IsSpellInRange("Holy Shock", target.unit)` check in `Holy_HolyShockHeal.matches`.
If target is out of 20yd range, return false — rotation falls through to HL/FoL immediately.

### 5. Merged HealTarget Strategy

Replace `Holy_HolyLight` and `Holy_FlashOfLight` with single `Holy_HealTarget`:

```
matches: state.lowest exists AND (lowest.hp < 100% OR (lowest.is_tank AND in_combat))
execute: calls select_heal(), returns chosen spell+rank on target
```

### 6. Healing Target Enrichment

New fields on healing target entries in `scan_healing_targets()`:

- `has_healing_reduction` — check for MS-type debuffs: "Mortal Strike", "Aimed Shot", "Wound Poison", "Mortal Cleave"
- `incoming_dps` — `Unit(unit):GetDMG()`, cached per scan

### 7. Schema Changes

**Remove:**
- `holy_holy_light_hp` (replaced by deficit math)
- `holy_hl_nontank_hp` (replaced by deficit math)
- `holy_flash_of_light_hp` (replaced by deficit math)
- `holy_holy_shock_hp` (keep or replace with deficit-based)

**Add:**
- `proactive_fol_mana_floor` (slider, default 30%, min 10, max 60) — stop proactive tank FoL below this mana %

**Keep:**
- `holy_use_holy_shock`
- All other holy settings unchanged

### 8. Strategy Priority Order

```
DivineIllumination → DivineFavor → Racial → HolyShockHeal →
LayOnHands → LightsGraceProc → HealTarget →
JudgementMaintain → SealMaintain → Cleanse
```

## Files Modified

| File | Changes |
|------|---------|
| `paladin/class.lua` | Add per-rank HL/FoL actions, rank tables, healing reduction debuff IDs |
| `paladin/holy.lua` | New `select_heal()`, `LightsGraceProc`, `HealTarget`, Holy Shock range fix, remove old HL/FoL strategies |
| `paladin/healing.lua` | Add `has_healing_reduction`, `incoming_dps` to target entries |
| `paladin/schema.lua` | Remove 3-4 threshold sliders, add `proactive_fol_mana_floor` |

## Not Changed

- `safe_heal_cast()` — still handles HE.SetTarget and icon macro injection
- `predict_effective_deficit()` — still used for target sorting (already factors incoming heals/damage)
- Cleanse logic — unchanged
- Judgement/Seal maintenance — unchanged
