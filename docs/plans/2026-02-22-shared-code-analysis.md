# Cross-Class Code Duplication Analysis

**Date**: 2026-02-22 (updated after recent changes)
**Status**: Reference document (no implementation planned yet)

This document catalogs duplicated code across all 9 class modules that could be extracted into shared utilities.

---

## What's Already Shared

Before listing what's duplicated, here's what's already consolidated:

| Shared Utility | Location | Used By |
|---|---|---|
| `S.burst()`, `S.dashboard()`, `S.debug()`, `S.trinkets()` | `common.lua` (load order 1) | All 9 schema.lua files |
| `NS.register_trinket_middleware()` | `core.lua` | All 9 middleware.lua files |
| `NS.try_cast()`, `NS.try_cast_fmt()` | `core.lua` | All strategy files |
| `NS.create_combat_strategy()` | `core.lua` | Bear, Balance, others |
| `NS.should_auto_burst()` | `core.lua` | Trinket middleware, burst strategies |
| `NS.has_phys_immunity()`, `NS.has_cc_immunity()`, etc. | `core.lua` | Available but underused |
| `ctx.combat_time` | `main.lua` `create_context()` | All classes (already shared) |
| `ctx.target_phys_immune`, `ctx.is_boss` | `main.lua` `create_context()` | All classes |
| `check_prerequisites` auto-checks | `core.lua` | `requires_combat`, `requires_enemy`, `requires_in_range`, `requires_phys_immune`, `setting_key`, `spell` |

---

## Tier 1: High Impact (9 classes, ~1600+ lines)

### 1. Recovery Item Middleware

**What**: Every class's `middleware.lua` contains near-identical blocks for Healthstone, Healing Potion, Mana Potion, and Dark/Demonic Rune.

**Scale**: ~36 lines × 9 classes = ~320 lines of pure duplication (4 middleware blocks per class)

**Files affected**: All 9 `middleware.lua` files (Druid handles recovery via form-aware action variants in `class.lua`, but the pattern is the same)

**Pattern** (Healthstone example — identical in 8/9 classes):
```lua
rotation_registry:register_middleware({
    name = "ClassName_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,
    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.healthstone_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,
    execute = function(icon, context)
        local HealthStoneObject = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HealthstoneMaster, A.HealthstoneMajor)
        if HealthStoneObject then
            return HealthStoneObject:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})
```

**Variations**:
- Warlock adds `A.HealthstoneFel` as first arg to `DetermineUsableObject`
- Druid wraps items in form-shifting logic (legitimate special case)
- `IsExists()` guard inconsistency: Shaman/Paladin use it before `IsReady()`, Mage/Warrior don't
- Hunter uses different setting key names (`use_mana_rune` instead of `use_dark_rune`)
- Warlock Healing Potion only checks `SuperHealingPotion` (no Major fallback)
- Mana Potion default threshold: 50 (Mage/Priest), 40 (Paladin)
- Dark Rune priority offset drift: `MANA_RECOVERY-5` (Shaman), `MANA_RECOVERY-10` (Warlock), base (others)

**Proposed solution**: `NS.register_recovery_middleware(config)` factory in `core.lua`, analogous to existing `NS.register_trinket_middleware()`. Config would accept:
- `healthstone_extras` (optional array of extra healthstone tiers, e.g. Warlock's Fel)
- `include_mana` (boolean — false for Warrior/Rogue/Hunter)
- `healing_potion_fallback` (boolean — Warlock skips Major)

---

### 2. Recovery Item Schema Sections

**What**: The "Recovery Items" settings block is copy-pasted into all 9 `schema.lua` files.

**Scale**: ~15-25 lines × 9 classes

**Files affected**: All 9 `schema.lua` files

**Pattern**:
```lua
{ header = "Recovery Items", settings = {
    { type = "slider", key = "healthstone_hp", default = 35, min = 0, max = 100, step = 5,
      label = "Healthstone HP %", tooltip = "Use Healthstone below this HP% (0 = disabled)" },
    { type = "checkbox", key = "use_healing_potion", default = true,
      label = "Use Healing Potion", tooltip = "Use healing potions in emergencies" },
    { type = "slider", key = "healing_potion_hp", default = 25, min = 10, max = 50, step = 5,
      label = "Healing Potion HP %", tooltip = "HP threshold for healing potion use" },
    -- mana classes also include: use_mana_potion, mana_potion_pct, use_dark_rune, dark_rune_pct, dark_rune_min_hp
}}
```

**Existing precedent**: `S.burst()`, `S.dashboard()`, `S.debug()`, `S.trinkets()` already exist as shared section factories in `common.lua`.

**Proposed solution**: `S.recovery_items(options)` factory in `common.lua` with `include_mana` flag.

---

### 3. Move `is_moving` and `is_mounted` into `create_context()` in `main.lua`

**What**: 7 classes copy-paste `is_moving` and `is_mounted` at the top of their `extend_context`. These are universal player state — not class-specific — and belong in `create_context()` alongside `hp`, `mana`, `combat_time`, etc.

**Note**: `combat_time` is **already in `create_context()`** (main.lua). Classes that also set it in `extend_context` are redundantly overwriting the same value. Only `is_moving` and `is_mounted` actually need to move.

**Scale**: 3 lines × 7 classes removed from `extend_context`; 3 lines added once to `create_context`

**Files affected**:
- `main.lua` — add `is_moving` and `is_mounted` to `create_context()`
- Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior `class.lua` — remove `is_moving`, `is_mounted`, and redundant `combat_time` from `extend_context`
- Druid — already does NOT set these in `extend_context` (calls them inline where needed or relies on `create_context`)

**Currently duplicated in 7 classes' `extend_context`**:
```lua
local moving = Player:IsMoving()
ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime() or 0  -- redundant: already in create_context
```

**Move to `create_context()` in `main.lua`** (once, alongside existing fields):
```lua
-- Already in create_context:
ctx.combat_time = Unit(PLAYER_UNIT):CombatTime() or 0

-- Add these:
local moving = Player:IsMoving()
ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
ctx.is_mounted = Player:IsMounted()
```

**After this change, `extend_context` only contains**:
1. Class-specific fields (e.g. `ctx.pet_hp`, `ctx.soul_shards`, `ctx.stance`, `ctx.energy`)
2. Per-playstyle cache invalidation flags (`ctx._fire_valid = false`, etc.)

**Inconsistency this fixes**: Hunter assigns `ctx.is_moving = Player:IsMoving()` directly without the triple nil-guard that the other 6 classes use.

---

## Tier 2: Medium Impact (4-6 classes)

### 4. Healing Target Scanner

**What**: 4 independent implementations of party/raid healing scan. Each healer class defines its own `scan_healing_targets()` and exports it to the same `NS.scan_healing_targets` key — meaning the **last loaded class wins** (load order dependent, not intentional sharing).

**Scale**: ~80 lines × 4 implementations = ~320 lines

**Files affected**:
- `druid/healing.lua` — the original, exports to `NS.scan_healing_targets`
- `paladin/healing.lua` — "adapted from Druid", adds dispel tracking, exports to same NS key
- `priest/healing.lua` — incompatible return signature (6 values instead of table+count), exports to same NS key
- `shaman/restoration.lua` — local only, does NOT export to NS

**Core logic** (same in all 4):
1. Detect party vs. raid via `GetNumGroupMembers()`
2. Iterate units with `prefix .. i` pattern
3. Filter: `UnitExists`, `not IsDead`, range check via `IsSpellInRange`
4. Pre-allocated entry table, manual insertion sort ascending by HP

**Differences**:
| Feature | Druid | Paladin | Priest | Shaman |
|---|---|---|---|---|
| Range spell | Rejuvenation | Flash of Light | GetRange()<=40 | Chain Heal |
| Return type | (table, count) | (table, count) | 6 separate values | (table, count) |
| Dispel tracking | No | Yes (poison/disease/magic) | No | No |
| HoT tracking | Yes (rejuv/regrowth) | No | No | No |
| Tank detection | Threat-based | Threat-based | Threat-based | Threat-based |
| Exported to NS | Yes (overwrites) | Yes (overwrites) | Yes (overwrites) | No (local) |

**Proposed solution**: Shared `NS.scan_healing_targets(context, options)` in a new shared `healing.lua` module or in `core.lua`. Options: `range_spell`, `track_dispels`, `track_hots`. Classes extend entries with class-specific fields after the scan.

**Also duplicated within Priest**: The party/raid iteration loop appears 3 times in Priest alone — once in `healing.lua` and twice in `middleware.lua` (DispelMagic, AbolishDisease).

---

### 5. Racial Strategy

**What**: Nearly every playstyle across all 9 classes defines its own Racial strategy checking Berserking/BloodFury/ArcaneTorrent. Only Warrior consolidates this into middleware (shared across all 3 specs).

**Scale**: ~20 lines × 22+ playstyles = ~440 lines

**Files affected**: Every playstyle file except Warrior specs (Warrior does it right — racial is in middleware, shared across all specs)

**Pattern** (identical body, only log prefix differs):
```lua
local Spec_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",
    matches = function(context, state)
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        if A.BloodFury:IsReady(PLAYER_UNIT) then return true end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
        return false
    end,
    execute = function(icon, context, state)
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[PREFIX] Berserking"
        end
        -- etc.
    end,
}
```

**Inconsistencies**:
- Melee classes check `BloodFury` (AP variant), casters check `BloodFurySP` (SP variant) — correct behavior but not obvious
- Paladin Ret: manual `context.settings.use_racial` check inside `matches()` — redundant with `setting_key` auto-check
- Paladin Holy: **missing `use_racial` gate entirely** — racial fires regardless of setting
- Priest shadow/smite: manual `context.settings.use_racial` check in `matches()`; Priest holy/discipline: use `setting_key = "use_racial"` — inconsistent within same class
- Paladin uses different racials than most (Stoneform, Gift of the Naaru instead of BloodFury)
- Shaman Ele/Resto use `BloodFurySP`; Shaman Enhancement uses `BloodFuryAP` — legitimate per-spec difference

**Proposed solution**: Two factory functions:
- `NS.build_racial_strategy(prefix, type)` — `type` is `"melee"` (BloodFury AP) or `"caster"` (BloodFurySP). For most classes.
- Paladin stays custom (different racial set: Stoneform, GoTN). Could still use a factory but with different spell list.

---

### 6. Interrupt Middleware

**What**: 6+ classes implement interrupt logic with the same core flow. The simple cases are near-identical; Shaman and Hunter are genuinely specialized.

**Scale**: ~15-25 lines × 6 classes (simple pattern)

**Files affected**:

| Class | Pattern | Spells | Special Logic |
|---|---|---|---|
| Mage | Simple | Counterspell | None |
| Paladin | Simple | Hammer of Justice | None |
| Priest | Simple | Silence | `is_spell_available()` gate (talent) |
| Rogue | Simple | Kick | Energy gate in `matches` |
| Warrior | Multi-spell | Pummel / ShieldBash | Stance-dependent; also has SpellReflection (separate MW, no `notKickAble` check) |
| Shaman | Complex state machine | Earth Shock (R1 option) | Nameplate scanning, priority spell ID filter, target-switch seek/return phases |
| Hunter | Different API | SilencingShot / ScatterShot | `IsReadyByPassCastGCD` + explicit `IsInRange()` |

**Simple pattern** (Mage, Paladin, Priest, Rogue — 4 classes, identical structure):
```lua
execute = function(icon, context)
    local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
    if castLeft and castLeft > 0 and not notKickAble then
        if A.InterruptSpell:IsReady(TARGET_UNIT) then
            return A.InterruptSpell:Show(icon), format("[MW] SpellName - Cast: %.1fs", castLeft)
        end
    end
    return nil
end,
```

**Not shareable**: Shaman (nameplate-scanning state machine with seek/return phases, priority spell ID whitelist) and Hunter (`IsReadyByPassCastGCD` + `IsInRange()` API).

**Proposed solution**: `NS.try_interrupt(icon, spells, options)` helper in `core.lua`.

Parameters:
- `icon` — the TMW icon
- `spells` — ordered array of interrupt spell configs: `{ spell = A.Spell, name = "SpellName", guard = optional_fn }`. The `guard` function receives `(context)` and returns `true/false` — for stance gates (Warrior) or talent checks (Priest).
- `options` — pre-allocated table:
  - `options.target` — unit to check casting on (default `TARGET_UNIT`)
  - `options.spell_ids` — optional set of spell IDs to interrupt (priority filtering)
  - `options.min_cast` — optional minimum `castLeft` threshold

Returns: `result, log_message` or `nil`.

**Usage examples**:
```lua
-- Simple (Mage): one spell, no options
local interrupt_spells = { { spell = A.Counterspell, name = "Counterspell" } }
local interrupt_opts = {}
return NS.try_interrupt(icon, interrupt_spells, interrupt_opts)

-- Multi-spell with guard (Warrior):
local interrupt_spells = {
    { spell = A.Pummel, name = "Pummel", guard = function(ctx) return ctx.stance == BERSERKER end },
    { spell = A.ShieldBash, name = "Shield Bash", guard = function(ctx) return ctx.stance == DEFENSIVE end },
}
local interrupt_opts = {}
return NS.try_interrupt(icon, interrupt_spells, interrupt_opts)
```

---

## Tier 3: Within-Class Duplication

### 7. Rogue — 6 duplicated strategies across 3 playstyles

| Strategy | combat.lua | assassination.lua | subtlety.lua | Notes |
|---|---|---|---|---|
| check_prerequisites | Identical | Identical | Identical | Also matches druid/cat |
| StealthOpener | Identical | Identical | Extended (adds Premeditation) | Combat+Assassination could share |
| MaintainSnD | Setting key differs | Setting key differs | Setting key differs | Factory candidate |
| Racial | Identical | Identical | Identical | See Tier 2 #5 |
| ExposeArmor | Identical | Identical | Identical | Define once in class.lua |
| Rupture | Setting keys differ | Setting keys differ | min_cp differs (4 vs 5) | Factory candidate |

**Proposed solution**: Define shared strategies in `rogue/class.lua` and reference them in each playstyle's registration.

---

### 8. Warrior — Arms == Fury for 3 strategies

| Strategy | arms.lua | fury.lua | Notes |
|---|---|---|---|
| SunderMaintain | Identical | Identical | Same setting, same logic |
| ThunderClap | Identical | Identical | Only log prefix differs; Prot uses different threshold constant |
| DemoShout | Identical | Identical | Only log prefix differs; Prot uses different setting key |

Note: Warrior racial is already in middleware (correctly shared).

**Proposed solution**: Define once in `warrior/class.lua`, reference in both arms and fury strategy arrays.

---

### 9. Warlock — 3 identical copies of 4 strategies

| Strategy | affliction.lua | demonology.lua | destruction.lua | Notes |
|---|---|---|---|---|
| Racial | Identical | Identical | Identical | See Tier 2 #5 |
| LifeTap fallback | Identical | Identical | Identical | Define once |
| AoE (SoC) | Identical | Identical | Identical | Define once |
| MaintainCurse | Extended | Identical | Identical | Aff has AmplifyCurse path |

**Proposed solution**: Define `Warlock_Racial`, `Warlock_LifeTapFallback`, `Warlock_AoE` once in `warlock/class.lua`.

---

### 10. Shaman — TotemManagement (3 near-identical, ~80 lines each)

All three specs implement the same 4-slot totem refresh loop. Only differences:
- Setting key prefix (`ele_`, `enh_`, `resto_`)
- Enhancement has air-slot twist bypass
- Default totem choices differ per spec

The Tremor Totem guard block appears 6 times (matches + execute in all 3 specs).

**Proposed solution**: `build_totem_management_strategy(prefix, slot_defaults)` factory in `shaman/class.lua`.

---

### 11. Mage — Movement and AoE (3 copies each)

- Movement spell strategy: identical structure across fire/frost/arcane, only setting keys differ
- AoE matches function: identical `threshold == 0` / `enemy_count < threshold` / `is_moving` guard

**Proposed solution**: Shared `matches` closure or factory in `mage/class.lua`.

---

## Inconsistencies Found

| Issue | Where | Impact |
|---|---|---|
| `IsExists()` before `IsReady()` on items | Shaman/Paladin use it; Mage/Warrior don't | Low — `IsReady` likely handles non-existent items |
| Mana potion default threshold | 50 (Mage/Priest), 40 (Paladin) | Low — may be intentional per-class tuning |
| Dark rune priority offset | `MANA_RECOVERY-5` (Shaman), `MANA_RECOVERY-10` (Warlock), base (others) | Low — probably unintentional drift |
| `is_moving` computation | Hunter: raw `Player:IsMoving()`; Others: triple nil-guard | Fixed by #3 — move to `create_context` |
| `combat_time` in `extend_context` | 7 classes redundantly set it (already in `create_context`) | Low — harmless overwrite, cleaned up by #3 |
| Paladin Holy racial | **Missing `use_racial` gate entirely** — fires regardless of setting | Medium — bug |
| Priest shadow/smite racial | Manual `context.settings.use_racial` check; holy/disc use `setting_key` | Low — inconsistent but functional |
| Paladin Ret racial | Duplicates `setting_key` check manually in `matches()` | Low — harmless double-check |
| Hunter setting key names | `use_mana_rune` instead of `use_dark_rune` | Low — diverged naming |
| Healing scanner NS export collision | Druid, Paladin, Priest all export to `NS.scan_healing_targets` — last loaded wins | Medium — fragile, load-order dependent |

---

## Implementation Priority (if/when pursued)

1. **Move `is_moving`/`is_mounted` to `create_context`; remove redundant `combat_time`** — trivial, zero-risk, fixes `is_moving` inconsistency, cleans up all `extend_context` functions
2. **Recovery middleware factory** — highest ROI, proven pattern (`register_trinket_middleware`), affects all 9 classes
3. **Recovery schema factory** — companion to #2, proven pattern (`S.burst()`/`S.dashboard()`)
4. **AoE CC protection** — new shared feature, prevents breaking crowd control (see Appendix A)
5. **Racial strategy factory** — 22+ copies, trivial factory, huge line reduction. Fix Paladin Holy bug.
6. **Within-class dedup** (Rogue, Warrior, Warlock, Shaman, Mage) — define shared strategies per class
7. **Healing scanner consolidation** — largest single-function dedup, but requires API design for different return shapes. Also fixes NS export collision.
8. **Interrupt helper** — moderate benefit, some classes have complex multi-spell interrupt logic

---

## Appendix A: AoE CC Protection

### Problem

AoE abilities can break crowd control on nearby enemies. Currently only Bear Druid has CC-avoidance logic (Swipe gates). Every other class fires AoE blindly. Additionally, `enemy_count` includes CC'd mobs in the count, so a threshold of 3 can be met by "2 real targets + 1 Polymorph'd sheep" — firing AoE that immediately breaks the CC.

### Current State

| Class | CC Avoidance | Notes |
|---|---|---|
| Bear Druid | Full | `has_breakable_cc_nearby()` nameplate scan, `swipe_cc_check` setting — local to `bear.lua`, NOT shared |
| Hunter | Partial | `protect_freeze` auto-switches off trapped target (not AoE-related) |
| All others | None | AoE fires freely, `enemy_count` counts CC'd mobs |

Bear's implementation (`bear.lua:120-148`):
- `BREAKABLE_CC_NAMES` — array of 11 debuff name strings (missing Banish, Fear, Entangling Roots, Psychic Scream, Turn Undead)
- `has_breakable_cc_nearby()` — iterates `GetActiveUnitPlates()`, checks `GetRange() <= 10`, scans each for any CC debuff name
- `is_target_breakable_cc()` — checks current target only (used for tab-targeting)
- Gated by `swipe_cc_check` setting (default `true`)

### Design Decisions

1. **Spell-name strings** for CC detection (not framework `"BreakAble"` category). More control, we know exactly what's checked, and it works regardless of framework definitions which may be PvP-tuned.

2. **Both boolean block AND adjusted count**. Reasoning:
   - Adjusted count alone is insufficient: 4 enemies, 1 CC'd → count = 3, threshold = 2 → AoE fires and breaks CC
   - Boolean block alone is sufficient for safety but makes the count misleading
   - Both together: accurate count for threshold decisions AND a hard safety gate

### Proposed Implementation

#### Shared CC utilities in `core.lua`

```lua
-- Pre-allocated at load time (no combat allocation)
local BREAKABLE_CC_NAMES = {
    "Polymorph",            -- Mage
    "Freezing Trap Effect", -- Hunter
    "Repentance",           -- Paladin
    "Blind",                -- Rogue
    "Sap",                  -- Rogue
    "Gouge",                -- Rogue
    "Hibernate",            -- Druid
    "Wyvern Sting",         -- Hunter
    "Scatter Shot",         -- Hunter
    "Shackle Undead",       -- Priest
    "Seduction",            -- Warlock (Succubus)
    "Banish",               -- Warlock
    "Fear",                 -- Warlock
    "Entangling Roots",     -- Druid
    "Psychic Scream",       -- Priest
    "Turn Undead",          -- Paladin
}
local NUM_BREAKABLE_CC = #BREAKABLE_CC_NAMES

-- Pre-allocated result table
local cc_scan_result = { has_cc = false, cc_count = 0 }

--- Scan nameplates within `range` yards for breakable CC debuffs.
--- Returns the pre-allocated result table (do NOT cache — overwritten each call).
--- @param range number  AoE splash radius to check
--- @return table  { has_cc = bool, cc_count = number }
function NS.scan_breakable_cc(range)
    cc_scan_result.has_cc = false
    cc_scan_result.cc_count = 0
    local plates = A.MultiUnits:GetActiveUnitPlates()
    for unitID in pairs(plates) do
        if Unit(unitID):GetRange() <= range then
            for i = 1, NUM_BREAKABLE_CC do
                if (Unit(unitID):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
                    cc_scan_result.has_cc = true
                    cc_scan_result.cc_count = cc_scan_result.cc_count + 1
                    break  -- one CC per unit is enough, move to next plate
                end
            end
        end
    end
    return cc_scan_result
end

--- Quick boolean check: is any breakable CC within range?
--- @param range number
--- @return boolean
function NS.has_breakable_cc_nearby(range)
    return NS.scan_breakable_cc(range).has_cc
end

--- Check if a specific unit has any breakable CC debuff.
--- @param unit string  Unit ID (e.g. "target", "nameplate3")
--- @return boolean
function NS.unit_has_breakable_cc(unit)
    for i = 1, NUM_BREAKABLE_CC do
        if (Unit(unit):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
            return true
        end
    end
    return false
end
```

#### Evaluation approach: Lazy (per-strategy, on demand)

Strategies call `NS.has_breakable_cc_nearby(range)` directly in their `matches()`. No context field needed. Not every class needs this every frame — the scan only runs when an AoE strategy's `matches()` is actually reached. The scan is cheap (nameplate iteration + HasDeBuffs string check).

#### Per-strategy integration

Strategies that deal AoE damage add a CC check in `matches()`:

```lua
-- Before (e.g. Warlock Seed of Corruption):
matches = function(context, state)
    local threshold = context.settings.aoe_threshold or 0
    if threshold == 0 then return false end
    if context.enemy_count < threshold then return false end
    return true
end,

-- After:
matches = function(context, state)
    local threshold = context.settings.aoe_threshold or 0
    if threshold == 0 then return false end
    if context.enemy_count < threshold then return false end
    if context.settings.aoe_cc_check and NS.has_breakable_cc_nearby(30) then return false end
    return true
end,
```

The range parameter matches the AoE's actual splash radius:
- Point-blank melee AoE (Swipe, Consecration, Whirlwind, Arcane Explosion, Thunder Clap): `8-10`
- Targeted/channeled ground AoE (Blizzard, Flamestrike, Hurricane): `10-15`
- Cleave/bounce AoE (Multi-Shot, Chain Lightning, Seed of Corruption): `30`

#### Schema setting

Add to `common.lua` as a new shared schema section:

```lua
function S.aoe_cc_check()
    return {
        type = "checkbox",
        key = "aoe_cc_check",
        default = true,
        label = "AoE CC Safety",
        tooltip = "Skip AoE abilities when a nearby enemy has breakable crowd control (Polymorph, Trap, Sap, etc). Prevents accidentally breaking CC."
    }
end
```

Include in each class's General tab schema, near the existing `aoe_threshold` setting.

#### Bear migration

Bear's existing `has_breakable_cc_nearby()` and `BREAKABLE_CC_NAMES` in `bear.lua` replaced by calls to `NS.has_breakable_cc_nearby(range)` and `NS.unit_has_breakable_cc("target")`. The `swipe_cc_check` setting migrated to the shared `aoe_cc_check` key (check both keys during transition for backward compatibility).

### AoE Abilities That Need the CC Check

| Class | AoE Ability | Type | Range Param |
|---|---|---|---|
| Mage | Arcane Explosion | Point-blank | 10 |
| Mage | Flamestrike | Targeted ground | 10 |
| Mage | Blizzard | Targeted channeled | 10 |
| Mage | Cone of Cold | Frontal cone | 10 |
| Mage | Blast Wave | Point-blank | 10 |
| Mage | Dragon's Breath | Frontal cone | 10 |
| Warlock | Seed of Corruption | Targeted (explodes AoE) | 30 |
| Warlock | Shadowfury | Targeted AoE stun | 10 |
| Shaman | Chain Lightning | Bounce (3 targets) | 30 |
| Shaman | Fire Nova Totem | Point-blank totem | 10 |
| Shaman | Magma Totem | Point-blank totem | 10 |
| Paladin | Consecration | Point-blank ground | 10 |
| Warrior | Whirlwind | Point-blank | 10 |
| Warrior | Cleave | Melee cleave | 10 |
| Warrior | Thunder Clap | Point-blank | 10 |
| Druid | Hurricane | Targeted channeled | 10 |
| Druid | Swipe | Point-blank | 10 |
| Hunter | Multi-Shot | Ranged cleave | 30 |
| Rogue | Blade Flurry | Passive cleave | 10 |

### Abilities that should NOT get the check

- **Demoralizing Shout / Demoralizing Roar** — debuff only, no damage, doesn't break CC
- **Battle Shout** — buff only
- **Challenging Shout / Challenging Roar** — taunt only, no damage
- **Consecration (Prot Paladin tank)** — debatable. Prot is tanking; CC near a tank is usually already broken. Could gate behind the setting but default off for prot.

### Open Questions

1. **Should `enemy_count` itself be adjusted?** The boolean gate is sufficient for safety. Adjusting `enemy_count` is more "correct" but adds a nameplate scan to every frame for every class. Recommendation: start with boolean gate only; add adjusted count later if count inflation causes practical issues.

2. **Backward compatibility for Bear's `swipe_cc_check` setting**: Existing Bear users have this saved. Recommendation: check both `aoe_cc_check` and `swipe_cc_check` keys during a transition period.

3. **Shadowfury**: Deals damage (breaks Poly), should NOT be exempt from the CC check.

4. **Blade Flurry (Rogue)**: Check before activating BF; accept that BF already active is not controllable.
