# Shared Middleware Design

**Date:** 2025-02-25
**Status:** Approved
**Scope:** Recovery consolidation + Threat awareness + Interrupt awareness

## Overview

Three new shared modules in `rotation/source/aio/` that eliminate duplicated middleware code and add new shared PvE intelligence. All use the Factory Registration pattern — shared files provide factory functions, classes opt in explicitly from their `middleware.lua`.

### New Files

| File | Purpose | Build Order |
|------|---------|-------------|
| `recovery.lua` | Shared recovery item middleware (Healthstone, Healing Potion, Mana Potion, Dark Rune) | 6 (after core.lua, before class middleware.lua) |
| `threat.lua` | Shared threat awareness middleware with configurable behavior | 6 |
| `interrupt.lua` | Shared interrupt decision logic (priority cast database, timing) | 6 |

### Build System Changes

`rotation/build.js` needs three additions to `ORDER_MAP` and `LOAD_ORDER`:
- `recovery.lua`: Order 6, shared slot (between settings.lua and class middleware.lua)
- `threat.lua`: Order 6, shared slot
- `interrupt.lua`: Order 6, shared slot

---

## 1. Recovery Middleware Consolidation

### Problem

~336 lines of near-identical recovery item code copy-pasted across 8 classes. Healthstone, Healing Potion, Mana Potion, and Dark Rune middleware are functionally identical everywhere except Druid (form-aware).

### Solution

`recovery.lua` provides `NS.register_recovery_middleware(class_name, config)` that auto-creates standard recovery middleware entries.

### Factory API

```lua
-- Standard usage (most classes)
NS.register_recovery_middleware("Mage", {
    healthstone = true,
    healing_potion = true,
    mana_potion = true,
    dark_rune = true,
})

-- Warlock: extra healthstone tier
NS.register_recovery_middleware("Warlock", {
    healthstone = { extra_tiers = { A.HealthstoneFel } },
    healing_potion = true,
    mana_potion = true,
    dark_rune = true,
})

-- Rogue: no mana items
NS.register_recovery_middleware("Rogue", {
    healthstone = true,
    healing_potion = true,
})

-- Druid: SKIPS — keeps form-aware implementation
```

### Middleware Generated

| Item | Priority | Setting Keys | Conditions |
|------|----------|--------------|------------|
| Healthstone | `RECOVERY_ITEMS` (300) | `healthstone_hp` | In combat, HP < threshold |
| Healing Potion | 295 | `use_healing_potion`, `healing_potion_hp` | In combat, combat_time >= 2s, HP < threshold |
| Mana Potion | `MANA_RECOVERY` (280) | `use_mana_potion`, `mana_potion_pct` | In combat, combat_time >= 2s, mana% < threshold |
| Dark Rune | 275 | `use_dark_rune`, `dark_rune_pct`, `dark_rune_min_hp` | In combat, combat_time >= 2s, mana% < threshold, HP > min |

### Per-Class Registration

| Class | healthstone | healing_potion | mana_potion | dark_rune | Notes |
|-------|-------------|----------------|-------------|-----------|-------|
| Druid | SKIP | SKIP | SKIP | SKIP | Keeps form-aware system |
| Hunter | yes | yes | no | yes | Energy-like mana, uses "mana_rune" setting key |
| Mage | yes | yes | yes | yes | Standard |
| Paladin | yes | yes | yes | yes | Standard |
| Priest | yes | yes | yes | yes | Standard |
| Rogue | yes | yes | no | no | Energy-based |
| Shaman | yes | yes | yes | yes | Standard |
| Warlock | yes (+Fel) | yes | yes | yes | Extra healthstone tier |
| Warrior | yes | yes | no | no | Rage-based |

### What Stays in Class Files

All class-specific recovery stays untouched:
- Warlock: Life Tap, Dark Pact
- Mage: Mana Gem, Evocation
- Priest: Shadowfiend
- Rogue: Thistle Tea
- Warrior: Bandages
- Druid: Entire form-aware recovery system + FormReshift

---

## 2. Threat Awareness System

### Problem

No shared threat monitoring exists. Some classes have individual threat dumps (Feign Death, Soulshatter, Feint, Fade) but there's no unified "am I about to pull aggro?" awareness.

### Solution

`threat.lua` provides `NS.register_threat_middleware(class_name, config)` that creates threat awareness middleware. Uses WoW's `GetThreatSituation()` API.

### Threat Levels (WoW API)

| Level | Meaning |
|-------|---------|
| 0 | Low threat, not tanking |
| 1 | High threat (>80% of tank), not tanking |
| 2 | Over 100%, about to pull |
| 3 | Actively tanking |

### Factory API

```lua
NS.register_threat_middleware("Rogue", {
    dump_spell = A.Feint,
    dump_ready_check = function(context)
        return context.energy >= 20
    end,
})

-- Class with no threat dump
NS.register_threat_middleware("Mage", {})
```

### User Settings

New settings per DPS class:

**`threat_mode`** (dropdown):

| Value | Behavior |
|-------|----------|
| `"dump"` (default) | Use threat dump at level 2+. If dump unavailable, suppress DPS |
| `"stop"` | Suppress DPS rotation at level 2+. No dump attempt |
| `"off"` | Ignore threat entirely |

**`threat_scope`** (dropdown) — unit classification filter:

| Value | Behavior |
|-------|----------|
| `"all"` | Manage threat on all targets |
| `"elite"` (default) | Only manage threat on elites and bosses |
| `"boss"` | Only manage threat on bosses |

Uses `UnitClassification("target")` → `"worldboss"`, `"elite"`, `"rareelite"`, `"normal"`, `"trivial"`. The `"elite"` scope includes `"worldboss"`, `"elite"`, and `"rareelite"`.

### TTD Awareness

Don't waste threat dumps on dying targets. If `context.ttd` is available and below a threshold (e.g., 3s), skip threat management — the mob will die before it matters. This prevents wasting long-cooldown abilities like Soulshatter (5m CD) or Feign Death (30s CD) on targets that are about to die anyway.

### Enemy Classification Counting

The threat system scans nameplates to count enemies targeting the player, broken down by classification:
- `threat_bosses` — worldboss units targeting player
- `threat_elites` — elite/rareelite units targeting player
- `threat_trash` — normal/trivial units targeting player
- `threat_total` — total enemies targeting player

This enables smarter decisions: "1 boss on me = definitely dump" vs "3 trash mobs on me = probably fine." The Priest already has a `count_mobs_targeting_me()` implementation for Fade — this gets promoted to the shared threat module so all classes benefit.

These counts are populated on the context object by the threat module so strategies can also reference them if needed.

### Middleware Behavior

- **Priority:** ~350 (below emergency defensives, above DPS strategies)
- **Trigger:** Threat level >= 2 (configurable)
- **Actions:**
  1. If `threat_mode == "dump"` and dump_spell available → fire dump, continue rotation
  2. If `threat_mode == "dump"` and dump unavailable → suppress rotation (return wait/GCD)
  3. If `threat_mode == "stop"` → suppress rotation
  4. If `threat_mode == "off"` → skip entirely

### Per-Class Registration

| Class | Dump Spell | Extra Conditions | Notes |
|-------|-----------|------------------|-------|
| Hunter | Feign Death | none | Removes Hunter_FeignDeath MW |
| Rogue | Feint | energy >= 20 | Removes Rogue_Feint MW |
| Warlock | Soulshatter | soul_shards > 0 | Removes Warlock_Soulshatter MW |
| Priest | Fade | none | Removes Priest_Fade MW |
| Mage | none | — | Can only stop DPS |
| Shaman (Ele/Enh) | none | — | Can only stop DPS |
| Paladin (Ret) | none | — | Can only stop DPS |
| Druid (Cat/Balance) | Cower (Cat) | stance == 3 | Cat-only dump |
| Warrior (Arms/Fury) | none | — | DPS warriors have no threat dump |
| Tank specs | NOT REGISTERED | — | Tanks don't need threat suppression |

### What Gets Removed from Class Files

- `Hunter_FeignDeath` middleware → replaced by shared threat
- `Rogue_Feint` middleware → replaced by shared threat
- `Warlock_Soulshatter` middleware → replaced by shared threat
- `Priest_Fade` middleware → replaced by shared threat

---

## 3. Interrupt Awareness System

### Problem

All interrupt logic is "target casting + not unkickable → kick." No priority awareness, no cast time optimization, no shared dangerous-spell database. The Shaman has a 58-spell priority list but it's trapped in Shaman middleware.

### Solution

`interrupt.lua` provides:
1. A shared priority cast database (`NS.INTERRUPT_PRIORITY`)
2. A decision function (`NS.should_interrupt(context)`)
3. Capability registration (`NS.register_interrupt_capability`)

### Priority Cast Database

```lua
NS.INTERRUPT_PRIORITY = {
    -- Category: "heal" — always interrupt
    [2054]  = "heal",    -- Healing Wave (R1)
    [25314] = "heal",    -- Greater Heal (max rank)
    [10917] = "heal",    -- Flash Heal (max rank)
    -- ... (migrated from Shaman's 58-spell list + expanded)

    -- Category: "cc" — always interrupt
    [118]   = "cc",      -- Polymorph
    [5782]  = "cc",      -- Fear
    [339]   = "cc",      -- Entangling Roots

    -- Category: "damage" — interrupt if possible
    [16005] = "damage",  -- Chain Lightning (NPC)
    [38263] = "damage",  -- Arcane Nova

    -- Spells NOT in table = "normal" (low priority)
}
```

### Decision Function

```lua
-- Returns: "priority" | "normal" | false
NS.should_interrupt = function(context)
    -- 1. Basic checks
    if not context.target_is_casting then return false end
    if context.not_kickable then return false end

    -- 2. Check priority database
    local cast_spell_id = ... -- get current cast spell ID
    local category = NS.INTERRUPT_PRIORITY[cast_spell_id]

    -- 3. Cast time awareness (optional delay)
    local delay = context.settings.interrupt_delay or 0
    if cast_elapsed < delay then return false end

    -- 4. Return decision
    if category == "heal" or category == "cc" then
        return "priority"
    elseif category == "damage" then
        return "priority"
    else
        return "normal"  -- interruptible but not priority
    end
end
```

### Capability Registration (Informational)

```lua
NS.register_interrupt_capability("Rogue", {
    lockout_duration = 5,
    cooldown = 10,
    range = "melee",
})
```

Used by the decision function for smart timing (e.g., don't waste a 10s CD kick on a 1.5s filler cast if a heal is likely coming).

### Class Integration

Each class's existing interrupt middleware changes its `matches` function:

```lua
-- Before (dumb)
matches = function(context)
    return context.in_combat
        and context.target_is_casting
        and not context.not_kickable
end

-- After (smart)
matches = function(context)
    if not context.in_combat then return false end
    local decision = NS.should_interrupt(context)
    if decision == "priority" then return true end
    if decision == "normal" then
        return not context.settings.interrupt_priority_only
    end
    return false
end
```

### New Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `interrupt_priority_only` | toggle | false | Only kick priority casts (heals, CC, big damage) |
| `interrupt_delay` | slider (0-1s) | 0 | Delay before kicking (0 = instant) |
| `interrupt_scope` | dropdown | `"all"` | Unit classification filter: `"all"` / `"elite"` / `"boss"` |

### Unit Classification Awareness

The `interrupt_scope` setting controls which targets get interrupted:
- `"all"` (default) — Interrupt any interruptible cast
- `"elite"` — Only interrupt elites and bosses (skip trash casts)
- `"boss"` — Only interrupt bosses

Uses `UnitClassification("target")` for scoping. Within scope, the priority database still applies — so `interrupt_scope = "all"` + `interrupt_priority_only = true` means "interrupt priority casts from any target."

### TTD Awareness

Don't waste a kick on a target about to die. If `context.ttd` < threshold (e.g., 2s), skip the interrupt — the mob will die before the cast completes anyway. This preserves kick CDs for targets that matter.

### What Stays in Class Files

ALL class interrupt mechanics stay:
- Warrior stance-dance (Pummel vs Shield Bash)
- Shaman tab-target state machine (references shared priority DB instead of its own copy)
- Rogue energy gating
- Priest Shadow-only gating
- Paladin HoJ stun
- Each class's execute function is untouched

### What Changes

- Shaman's 58-spell priority list → migrated to shared `NS.INTERRUPT_PRIORITY`
- Each class's interrupt `matches` → calls `NS.should_interrupt()` instead of raw casting check
- New settings added to schemas

---

## Schema Changes Summary

### New Settings Per Class

| Setting | Type | Default | Classes | Section |
|---------|------|---------|---------|---------|
| `threat_mode` | dropdown | "dump" | All DPS specs | Threat |
| `threat_scope` | dropdown | "elite" | All DPS specs | Threat |
| `interrupt_priority_only` | toggle | false | Classes with interrupts | Interrupt |
| `interrupt_delay` | slider (0-1s) | 0 | Classes with interrupts | Interrupt |
| `interrupt_scope` | dropdown | "all" | Classes with interrupts | Interrupt |

### Existing Settings (No Change)

Recovery item settings (`healthstone_hp`, `use_healing_potion`, etc.) remain in per-class schemas. The shared factory reads them via `context.settings` as before.

---

## Migration Plan

### Phase 1: Recovery Consolidation (Safe Refactor)
1. Create `recovery.lua` with factory function
2. Update `build.js` to include new shared files
3. For each class (except Druid): replace copy-pasted middleware with factory call
4. Verify no behavioral changes

### Phase 2: Threat Awareness (New Feature)
1. Create `threat.lua` with threat middleware factory
2. Add `threat_mode` to schemas
3. Register each DPS class
4. Remove old class-specific threat dumps (FeignDeath, Feint, Soulshatter, Fade)
5. Test in-game with threat meter

### Phase 3: Interrupt Awareness (Enhancement)
1. Create `interrupt.lua` with priority database + decision function
2. Migrate Shaman's spell list to shared DB, expand for all dungeon/raid content
3. Add new settings to schemas
4. Update each class's interrupt `matches` to use `NS.should_interrupt()`
5. Verify Shaman tab-target still works with shared DB

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Recovery refactor changes behavior | Exact same logic, just moved. Test each class individually |
| Threat suppression too aggressive | Default to "dump" mode, "off" option always available |
| Priority interrupt DB incomplete | Start with Shaman's existing 58 spells, expand iteratively |
| Build order issues | Order 6 shared files load after core.lua (4) and class.lua (5), before class middleware (7) |
| Druid form-aware system conflicts | Druid explicitly skips recovery factory, no interaction |
