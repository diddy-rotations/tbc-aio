# GGL Action Addon - Complete API Reference

> **Version:** Based on DateTime 17.01.2026
> **Platform:** World of Warcraft (Classic/TBC/WOTLK/Retail)

---

## Table of Contents

1. [Action Creation](#1-action-creation)
2. [Action Object Methods](#2-action-object-methods)
3. [Unit System API](#3-unit-system-api)
4. [Player System API](#4-player-system-api)
5. [Global Helper Functions](#5-global-helper-functions)
6. [MultiUnits System](#6-multiunits-system)
7. [Loss of Control System](#7-loss-of-control-system)
8. [TeamCache System](#8-teamcache-system)
9. [MetaEngine & Click System](#9-metaengine--click-system)
10. [AuraList Categories](#10-auralist-categories)
11. [Constants Reference](#11-constants-reference)

---

## 1. Action Creation

### `Action.Create(args)`

Creates an action object with specified configuration.

```lua
local MySpell = Action.Create({
    Type = "Spell",           -- Required: Action type
    ID = 12345,               -- Required: Spell/Item ID
    Color = "RED",            -- Optional: Display color
    Desc = "Description",     -- Optional: Tooltip description
    Hidden = false,           -- Optional: Hide from UI
    isTalent = true,          -- Optional: Check talent learned
    isReplacement = false,    -- Optional: Check spell replacement
    useMaxRank = true,        -- Optional: Use highest rank (Classic)
    skipRange = false,        -- Optional: Skip range checks
    QueueForbidden = false,   -- Optional: Prevent queueing
    BlockForbidden = false,   -- Optional: Prevent blocking
    MetaSlot = 3,             -- Optional: Fixed meta slot for queue
    IsAntiFake = false,       -- Optional: For slots [1],[2],[7]-[10]
    Click = { ... },          -- Optional: MetaEngine click config
    Macro = "...",            -- Optional: Custom macro string
})
```

#### Type Values

| Type | Description |
|------|-------------|
| `"Spell"` | Player spell/ability |
| `"SpellSingleColor"` | Spell with single color state |
| `"Item"` | Inventory item |
| `"ItemSingleColor"` | Item with single color state |
| `"Potion"` | Consumable potion |
| `"Trinket"` | Equipment trinket (auto-detects slot) |
| `"TrinketBySlot"` | Trinket by specific slot |
| `"SwapEquip"` | Equipment swap action |
| `"Script"` | MetaEngine script execution |

---

## 2. Action Object Methods

### Ready/Castability Checks

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **IsReady** | `:IsReady(unit?, skipRange?, skipLua?, skipShouldStop?, skipUsable?)` | `boolean` | Full ready check with all conditions |
| **IsReadyP** | `:IsReadyP(unit?, skipRange?, skipLua?, skipShouldStop?, skipUsable?)` | `boolean` | Passive ready check (skips block/queue) |
| **IsReadyM** | `:IsReadyM(unit?, skipRange?, skipUsable?)` | `boolean` | MSG system check (bypasses GCD) |
| **IsReadyByPassCastGCD** | `:IsReadyByPassCastGCD(unit?, skipRange?, skipLua?, skipUsable?)` | `boolean` | Bypasses cast/GCD blocking |
| **IsCastable** | `:IsCastable(unit?, skipRange?, skipShouldStop?, isMsg?, skipUsable?)` | `boolean` | Technical castability check |
| **IsUsable** | `:IsUsable(extraCD?, skipUsable?)` | `boolean` | Resource + cooldown check |
| **IsExists** | `:IsExists(replacementByPass?)` | `boolean` | Spell known/item available |

### Display Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **Show** | `:Show(icon)` | `true` | Display action on icon, triggers MetaEngine |
| **Hide** | `A.Hide(icon)` | `nil` | Hide the icon |

### Cooldown Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **GetCooldown** | `:GetCooldown()` | `number` | Remaining cooldown (seconds) |
| **GetSpellBaseCooldown** | `:GetSpellBaseCooldown()` | `number` | Unmodified base cooldown |
| **GetSpellCastTime** | `:GetSpellCastTime()` | `number` | Cast time (seconds) |
| **GetSpellCharges** | `:GetSpellCharges()` | `number` | Current charges |
| **GetSpellChargesMax** | `:GetSpellChargesMax()` | `number` | Maximum charges |
| **GetSpellChargesFrac** | `:GetSpellChargesFrac()` | `number` | Fractional charges |
| **GetSpellChargesFullRechargeTime** | `:GetSpellChargesFullRechargeTime()` | `number` | Time to full recharge |
| **GetItemCooldown** | `:GetItemCooldown()` | `number` | Item cooldown (seconds) |

### Range & Immunity

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **IsInRange** | `:IsInRange(unit?)` | `boolean` | Target in range |
| **HasRange** | `:HasRange()` | `boolean` | Spell has range limit |
| **AbsentImun** | `:AbsentImun(unit?, imunBuffs?)` | `boolean` | Target not immune |

### Spell Information

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **Info** | `:Info()` | `string` | Spell/item name |
| **GetSpellInfo** | `:GetSpellInfo()` | `name, rank, icon, castTime, minRange, maxRange` | Full spell info |
| **GetSpellDescription** | `:GetSpellDescription()` | `table` | Tooltip numbers (sorted) |
| **GetSpellPowerCost** | `:GetSpellPowerCost()` | `cost, powerType` | Real-time power cost |
| **GetSpellTravelTime** | `:GetSpellTravelTime(unit?)` | `number` | Projectile travel time |
| **GetSpellTimeSinceLastCast** | `:GetSpellTimeSinceLastCast()` | `number` | Seconds since last cast |
| **GetSpellCounter** | `:GetSpellCounter()` | `number` | Total casts this fight |
| **IsSpellInFlight** | `:IsSpellInFlight()` | `boolean` | Projectile in flight |
| **IsSpellLastGCD** | `:IsSpellLastGCD(byID?)` | `boolean` | Was last GCD |

### Queue & Blocker

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **IsBlocked** | `:IsBlocked()` | `boolean` | Action is blocked |
| **SetBlocker** | `:SetBlocker()` | `nil` | Toggle block status |
| **IsQueued** | `:IsQueued()` | `boolean` | Action is queued |
| **SetQueue** | `:SetQueue(args?)` | `nil` | Add/remove from queue |

### Racial Support

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| **AutoRacial** | `:AutoRacial(unit?, skipRange?)` | `boolean` | Auto-use racial with logic |
| **IsRacialReady** | `:IsRacialReady(unit?, skipRange?)` | `boolean` | Racial ready check |

---

## 3. Unit System API

Access via `A.Unit(unitID):Method()`

### Health Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `:Health()` | `number` | Current health |
| `:HealthMax()` | `number` | Maximum health |
| `:HealthPercent()` | `number` | Health percentage (0-100) |
| `:HealthDeficit()` | `number` | Missing health |
| `:HealthPercentLosePerSecond()` | `number` | HP loss rate per second |

### Status Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `:IsExists()` | `boolean` | Unit exists |
| `:IsDead()` | `boolean` | Unit is dead |
| `:IsEnemy()` | `boolean` | Unit is enemy |
| `:IsFriend()` | `boolean` | Unit is friendly |
| `:IsPlayer()` | `boolean` | Unit is a player |
| `:IsBoss()` | `boolean` | Unit is a boss |
| `:IsMounted()` | `boolean` | Unit is mounted |

### Classification

| Method | Returns | Description |
|--------|---------|-------------|
| `:Class()` | `string` | Class name (e.g., "WARRIOR") |
| `:Spec()` | `number` | Spec ID |
| `:Role()` | `string` | "TANK", "HEALER", "DAMAGER" |
| `:IsHealer()` | `boolean` | Unit is healer |
| `:IsTank()` | `boolean` | Unit is tank |
| `:IsMelee()` | `boolean` | Unit is melee |
| `:CreatureType()` | `string` | Beast, Demon, Humanoid, etc. |
| `:Classification()` | `string` | "worldboss", "elite", "rare", "" |

### Casting

| Method | Returns | Description |
|--------|---------|-------------|
| `:IsCasting()` | `name, start, end, notKickable, spellID, isChannel` | Current cast info |
| `:CastTime(spellID?)` | `total, left, percent, id, name, notKickable, isChannel` | Cast progress |
| `:CanInterrupt(kickAble?, auras?, minX?, maxX?)` | `boolean` | Can interrupt cast |
| `:IsInterruptible()` | `boolean` | Cast is interruptible |

### Auras (Buffs/Debuffs)

| Method | Returns | Description |
|--------|---------|-------------|
| `:HasBuffs(spell, caster?, byID?)` | `remain, duration` | Buff remaining time |
| `:HasBuffsStacks(spell, caster?, byID?)` | `number` | Buff stack count |
| `:HasDeBuffs(spell, caster?, byID?)` | `remain, duration` | Debuff remaining time |
| `:HasDeBuffsStacks(spell, caster?, byID?)` | `number` | Debuff stack count |
| `:PT(spell, debuff?, byID?)` | `boolean` | Pandemic threshold (<=30%) |

### Combat

| Method | Returns | Description |
|--------|---------|-------------|
| `:CombatTime()` | `number` | Seconds in combat |
| `:ThreatSituation(unit?)` | `status, percent, value` | Threat info |
| `:IsTanking(unit?, range?)` | `boolean` | Is holding threat |
| `:TimeToDie()` | `number` | Estimated TTD (seconds) |
| `:GetRealTimeDMG(index?)` | `number` | Recent damage taken |
| `:GetDR(drCat)` | `number` | Diminishing returns value |

### Range

| Method | Returns | Description |
|--------|---------|-------------|
| `:GetRange()` | `max, min` | Distance to unit |
| `:CanInterract(range?)` | `boolean` | Can interact with unit |
| `:IsMoving()` | `boolean` | Unit is moving |
| `:IsMovingIn()` | `boolean` | Moving toward player |
| `:IsMovingOut()` | `boolean` | Moving away from player |

---

## 4. Player System API

Access via `A.Player:Method()`

### Movement & State

| Method | Returns | Description |
|--------|---------|-------------|
| `:IsMoving()` | `boolean` | Player is moving |
| `:IsMovingTime()` | `number` | Seconds moving |
| `:IsStaying()` | `boolean` | Player is stationary |
| `:IsStayingTime()` | `number` | Seconds stationary |
| `:IsFalling()` | `boolean, number` | Is falling, duration |
| `:IsMounted()` | `boolean` | Is mounted |
| `:IsSwimming()` | `boolean` | Is swimming |
| `:IsStealthed()` | `boolean` | Is stealthed |

### Combat State

| Method | Returns | Description |
|--------|---------|-------------|
| `:IsCasting()` | `string or nil` | Spell name if casting |
| `:IsChanneling()` | `string or nil` | Spell name if channeling |
| `:CastRemains(spellID)` | `number` | Remaining cast time |
| `:IsAttacking()` | `boolean` | Auto-attack active |
| `:IsShooting()` | `boolean` | Auto-shot active |
| `:IsBehind(x?)` | `boolean` | Behind target (x seconds threshold) |

### Stance & Form

| Method | Returns | Description |
|--------|---------|-------------|
| `:IsStance(x)` | `boolean` | In specific stance |
| `:GetStance()` | `number` | Current stance number |

### Stats

| Method | Returns | Description |
|--------|---------|-------------|
| `:HastePct()` | `number` | Haste percentage |
| `:CritChancePct()` | `number` | Crit chance percentage |
| `:SpellHaste()` | `number` | Spell haste multiplier |
| `:GCDRemains()` | `number` | Remaining GCD time |

### Swing Timers

| Method | Returns | Description |
|--------|---------|-------------|
| `:GetSwing(inv)` | `number` | Remaining swing time |
| `:GetSwingMax(inv)` | `number` | Max swing duration |
| `:GetSwingShoot()` | `number` | Ranged swing remaining |

**Inventory slots (inv):** 1=Main, 2=Off, 3=Ranged, 4=Both, 5=All

### Resource Methods

Each resource has these methods: `Resource()`, `ResourceMax()`, `ResourcePercent()`, `ResourceDeficit()`, `ResourceDeficitPercent()`

**Available Resources:**
- `Mana`, `ManaRegen()`, `ManaTimeToMax()`, `ManaTimeToX(amount)`
- `Rage`
- `Focus`, `FocusRegen()`, `FocusTimeToMax()`, `FocusPredicted()`
- `Energy`, `EnergyRegen()`, `EnergyTimeToMax()`, `EnergyPredicted()`
- `ComboPoints(unit?)`, `ComboPointsMax()`, `ComboPointsDeficit(unit?)`
- `RunicPower`
- `Rune(presence)`, `RuneTimeToX(value)` (presence: 1=Blood, 2=Frost, 3=Unholy, 4=Death)
- `SoulShards`
- `HolyPower`
- `Chi`, `Stagger()`, `StaggerPercentage()`
- `AstralPower`
- `Maelstrom`
- `Insanity`, `Insanityrain()`
- `ArcaneCharges`
- `Fury`
- `Pain`
- `Essence`

### Equipment Tracking

| Method | Description |
|--------|-------------|
| `:HasGlyph(spell)` | Check if glyph is active |
| `:GetTotemInfo(i)` | Get totem info by slot |
| `:GetTotemTimeLeft(i)` | Totem duration remaining |
| `:IsSwapLocked()` | Weapon swap locked |
| `:HasTier(tier, count)` | Check tier set bonus |
| `:GetAmmo()` | Total ammo count (Classic) |
| `:HasShield(equipped?)` | Shield itemID |

---

## 5. Global Helper Functions

### GCD & Timing

| Function | Returns | Description |
|----------|---------|-------------|
| `A.GetGCD()` | `number` | Total GCD duration |
| `A.GetCurrentGCD()` | `number` | Remaining GCD time |
| `A.GetPing()` | `number` | Network latency (seconds) |
| `A.ShouldStop()` | `boolean` | Player is casting |
| `A.OnGCD(duration)` | `boolean` | Is duration on GCD |

### Toggles & Settings

| Function | Returns | Description |
|----------|---------|-------------|
| `A.GetToggle(tab, key)` | `any` | Get user setting |
| `A.SetToggle(arg, custom?, opposite?)` | `nil` | Set user setting |
| `A.BurstIsON(unit?)` | `boolean` | Burst mode enabled for unit |

### Mode Toggles

| Function | Description |
|----------|-------------|
| `A.ToggleMode()` | Toggle PvE/PvP mode |
| `A.ToggleAoE()` | Toggle AoE mode |
| `A.ToggleBurst(fixed?, between?)` | Toggle burst mode |
| `A.ToggleRole(fixed?, between?)` | Toggle role |

### Queue & Blocker

| Function | Returns | Description |
|----------|---------|-------------|
| `A.MacroQueue(key, args?)` | `nil` | Add/remove from queue |
| `A.MacroBlocker(key)` | `nil` | Toggle action blocker |
| `A.IsQueueRunning()` | `boolean` | Any item queued |
| `A.IsQueueRunningAuto()` | `boolean` | Auto queue active |
| `A.CancelAllQueue()` | `nil` | Clear entire queue |

### Interrupt System

| Function | Returns | Description |
|----------|---------|-------------|
| `A.InterruptIsValid(unit, toggle?, ignore?, countGCD?)` | `kick, cc, racial, notPossible, remain, doneBy` | Full interrupt validation |
| `A.InterruptEnabled(category, spellName)` | `boolean` | Spell in interrupt list |
| `A.InterruptIsBlackListed(unit, spellName)` | `boolean` | Unit/spell blacklisted |

### Unit Helpers

| Function | Returns | Description |
|----------|---------|-------------|
| `A.IsUnitEnemy(unit)` | `boolean` | Valid enemy target |
| `A.IsUnitFriendly(unit)` | `boolean` | Valid friendly target |

---

## 6. MultiUnits System

Access via `A.MultiUnits:Method()`

| Method | Returns | Description |
|--------|---------|-------------|
| `:GetByRange(range?, count?)` | `number` | Enemies in range |
| `:GetByRangeInCombat(range?, count?, upTTD?)` | `number` | In-combat enemies |
| `:GetByRangeCasting(range?, count?, kickAble?, spells?)` | `number` | Casting enemies |
| `:GetByRangeMissedDoTs(range, count, debuffs, upTTD?)` | `number` | Enemies missing DoTs |
| `:GetByRangeAppliedDoTs(range, count, debuffs, upTTD?)` | `number` | Enemies with DoTs |
| `:GetActiveEnemies(timer?, skipClear?)` | `number` | Enemies hitting same target |

---

## 7. Loss of Control System

Access via `A.LossOfControl:Method()`

| Method | Returns | Description |
|--------|---------|-------------|
| `:Get(locType, name?)` | `duration, texture` | Get CC duration |
| `:IsMissed(types)` | `boolean` | All specified CCs absent |
| `:IsValid(applied, missed, exception?)` | `valid, partial` | Full CC validation |

**CC Types:** `"STUN"`, `"ROOT"`, `"SILENCE"`, `"FEAR"`, `"POLYMORPH"`, `"SLEEP"`, `"SNARE"`, `"DISARM"`, `"SCHOOL_INTERRUPT"`

---

## 8. TeamCache System

```lua
A.TeamCache = {
    Friendly = {
        UNITs = {},           -- unitID -> GUID
        GUIDs = {},           -- GUID -> unitID
        Type = "none",        -- "raid", "party", "none"
        IndexToPLAYERs = {},  -- Indexed players
        IndexToPETs = {},     -- Indexed pets
    },
    Enemy = { ... }           -- Same structure
}
```

---

## 9. MetaEngine & Click System

### Click Table Parameters

```lua
Click = {
    -- Targeting (choose one)
    autounit = "help",    -- "help", "harm", "both"
    unit = "player",      -- Specific unitID

    -- Action type
    type = "spell",       -- "spell", "item", "toy" (NOT "macro")
    typerelease = "spell",

    -- Reference
    spell = 12345,        -- Spell ID or name
    item = 67890,         -- Item ID or name

    -- Macro wrappers
    macrobefore = "/stopcasting\n",
    macroafter = "/startattack\n",
}
```

### Meta Slot Overview

| Slot | Name | Variables | Target Resolution |
|------|------|-----------|-------------------|
| [1] | AntiFake CC | `this1`, `this1click` | mouseover, target |
| [2] | AntiFake Interrupt | `this2`, `this2click` | mouseover, target |
| [3] | Main Rotation | `this3`, `this3click` | mouseover, focus, target, targettarget |
| [4] | Secondary Rotation | `this4`, `this4click` | mouseover, focus, target, targettarget |
| [5] | Trinket Rotation | `this5`, `this5click` | target, player |
| [6] | Passive Unit1 | `this`, `thisclick6` | arena1, raid1, party1 |
| [7-10] | Passive/AntiFake | `thisN`, `thisclickN` | arena2-5, raid2-5, party2-5 |

### Keypress Chain Order

**Slots [1]-[2], [5], [7]-[10]:**
```
DOWN: Active meta-button
UP:   Passive [6]→[10] → HealingEngine
```

**Slots [3]-[4]:**
```
DOWN: Passive [6]→[10] → Active meta-button
UP:   HealingEngine
```

---

## 10. AuraList Categories

Use with `:HasBuffs()`, `:HasDeBuffs()`, `:AbsentImun()`

### Crowd Control
- `"Magic"` - Magic CCs (Polymorph, Fear, etc.)
- `"Physical"` - Physical CCs (Blind, Kidney Shot, etc.)
- `"Curse"` - Curse effects (Hex)
- `"Disease"` - Disease effects
- `"Poison"` - Poison effects

### CC Types
- `"Stuned"`, `"PhysStuned"` - Stun effects
- `"Silenced"` - Silence effects
- `"Rooted"` - Root effects
- `"Slowed"`, `"MagicSlowed"` - Slow effects
- `"Fear"` - Fear effects
- `"Incapacitated"` - Incapacitate effects
- `"Disoriented"` - Disorient effects
- `"BreakAble"` - CCs that break on damage

### Immunities
- `"TotalImun"` - Total immunity (Divine Shield, Ice Block)
- `"DamagePhysImun"` - Physical immunity (Hand of Protection)
- `"DamageMagicImun"` - Magic immunity (Cloak of Shadows)
- `"CCTotalImun"` - CC immunity (Bladestorm)
- `"CCMagicImun"` - Magic CC immunity (AMS, Grounding)
- `"KickImun"` - Interrupt immunity (Aura Mastery)
- `"FearImun"`, `"StunImun"` - Specific immunities
- `"Freedom"` - Freedom effects
- `"Reflect"` - Reflection effects

### Buffs
- `"DeffBuffs"`, `"DeffBuffsMagic"` - Defensive buffs
- `"DamageBuffs"`, `"DamageBuffs_Melee"` - Offensive buffs
- `"BurstHaste"` - Heroism/Bloodlust
- `"Speed"` - Movement speed buffs
- `"Rage"` - Enrage effects

### Utility
- `"ImportantPurje"` - High-priority dispels
- `"SecondPurje"` - Secondary dispel targets
- `"CastBarsCC"` - CC casts to monitor
- `"AllPvPKickCasts"` - Worth interrupting

---

## 11. Constants Reference

### Textures
```lua
ACTION_CONST_TRINKET1, ACTION_CONST_TRINKET2
ACTION_CONST_POTION, ACTION_CONST_HEALINGPOTION
ACTION_CONST_STOPCAST    -- Use with A:Show(icon, CONST)
ACTION_CONST_AUTOTARGET
ACTION_CONST_AUTOATTACK, ACTION_CONST_AUTOSHOOT
ACTION_CONST_LEFT, ACTION_CONST_RIGHT
```

### Class Portraits
```lua
ACTION_CONST_PORTRAIT_WARRIOR
ACTION_CONST_PORTRAIT_PALADIN
ACTION_CONST_PORTRAIT_HUNTER
-- ... etc for all classes
```

### Global Properties
```lua
A.PlayerClass          -- "WARRIOR", "MAGE", etc.
A.PlayerRace           -- "Human", "Orc", etc.
A.PlayerSpec           -- Spec ID (Retail)
A.IsInPvP              -- Boolean
A.Zone                 -- Current zone type
A.IsInitialized        -- Addon loaded
A.BuildToC             -- WoW build number
```

---

## Basic Rotation Example

```lua
Action[Action.PlayerClass] = {
    Fireball = Action.Create({
        Type = "Spell",
        ID = 133,
        Click = { autounit = "harm" }
    }),

    FrostNova = Action.Create({
        Type = "Spell",
        ID = 122,
        Click = { unit = "player" }
    }),
}

local A = setmetatable(Action[Action.PlayerClass], { __index = Action })

A[3] = function(icon)
    -- Emergency AoE
    if A.FrostNova:IsReady("player") and A.MultiUnits:GetByRange(8) >= 3 then
        return A.FrostNova:Show(icon)
    end

    -- Single target
    if A.Fireball:IsReady("target") then
        return A.Fireball:Show(icon)
    end

    A.Hide(icon)
end
```

---

*Documentation generated from GGL Action addon codebase analysis*
