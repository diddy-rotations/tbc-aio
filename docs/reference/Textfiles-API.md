# Textfiles (The Action) API Reference

**Version:** 17.01.2026
**Global Namespace:** `Action`
**TMW Integration:** `TMW.CNDT.Env.Action`
**Main File:** Action.lua (911KB)

---

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Global Action API](#global-action-api)
4. [Unit Engine](#unit-engine)
5. [Player Engine](#player-engine)
6. [Team Engines](#team-engines)
7. [Spell/Item Objects](#spellitem-objects)
8. [MultiUnits System](#multiunits-system)
9. [Integration with TMW](#integration-with-tmw)
10. [Embedded Libraries](#embedded-libraries)
11. [Constants and Enumerations](#constants-and-enumerations)
12. [Examples](#examples)

---

## Overview

Textfiles (branded as "The Action") is a comprehensive rotation scripting framework that integrates with TellMeWhen addon. It provides:

- **Global Action table** for addon-wide functions
- **Unit engine** with 100+ methods for unit manipulation
- **Player-specific API** for character state
- **Cache:Wrap pattern** for performance optimization
- **Object-oriented spell/item API**
- **Team/Group management** with role filtering
- **MultiUnits AoE detection**

### Purpose

Action provides a complete scripting environment for creating WoW combat rotations. It abstracts complex API calls, caches expensive operations, and provides rotation-specific utilities like queue systems, toggles, and interrupt/dispel management.

### Dependencies

- **TellMeWhen** (required)
- Embedded libraries (see section below)
- Compatible with Classic through Retail (build-specific code)

---

## Core Concepts

### Cache:Wrap Performance Pattern

The framework uses a caching system to avoid expensive repeated API calls:

```lua
local Cache = {
    bufer = {},
    Wrap = function(this, func, name)
        -- Caches function results with TMW.time-based expiration
        -- Default cache timer: CACHE_DEFAULT_TIMER_UNIT
    end,
}
```

**Key Features:**
- Time-based cache expiration (default ~0.1s)
- Per-unit caching using UnitID or GUID
- Memory-efficient table reuse
- Can be disabled with `CONST.CACHE_DISABLE`

### Unit Engine Architecture

Units are accessed through a pseudo-class pattern:

```lua
local unit = Action.Unit("target")
local unit = Unit("target")  -- Also available globally in TMW.CNDT.Env

-- All methods are cached and return fresh data based on TMW.time
if unit:Health() < 50000 then
    -- do something
end
```

### Action Object Model

Spells and items are represented as action objects:

```lua
-- Creating action objects (from Modules/Actions.lua)
local Spell = Action.Create({ Type = "Spell", ID = 12345 })
local Item = Action.Create({ Type = "Item", ID = 67890 })

-- Using action objects
if Spell:IsReady("target") then
    -- spell is off cooldown, in range, usable
end
```

---

## Global Action API

### Player Information

```lua
Action.PlayerRace           -- string: Player race (e.g., "Human")
Action.PlayerClassName      -- string: Localized class name
Action.PlayerClass          -- string: Class token (e.g., "WARRIOR")
Action.PlayerClassID        -- number: Class ID
Action.PlayerLevel          -- number: Current level
Action.BuildToC             -- number: Game build/version (e.g., 30000 for WotLK)
Action.DateTime             -- string: Framework version date "17.01.2026"
```

### Toggle System

Toggles provide UI/macro-controllable boolean states for rotations.

#### `Action.ToggleBurst([fixed], [between])`
Toggle burst mode (offensive cooldowns).

**Parameters:**
- `fixed` (string, optional): Force state to "Everything", "Auto", or "Off"
- `between` (string, optional): Alternate state

**States:**
- `"Everything"` - Use all cooldowns on cooldown
- `"Auto"` - Use on bosses or players
- `"Off"` - Disabled

**Returns:** None

**Usage:**
```lua
-- Toggle through states
Action.ToggleBurst()

-- Force to specific state
Action.ToggleBurst("Everything")

-- Macro example
/run Action.ToggleBurst()
```

#### `Action.ToggleAoE()`
Toggle AoE mode on/off.

**Returns:** None

**Usage:**
```lua
Action.ToggleAoE()

-- Check state
if Action.GetToggle(2, "AoE") then
    -- AoE is enabled
end
```

#### `Action.ToggleMode()`
Toggle between PvE and PvP mode.

**Returns:** None

**Usage:**
```lua
Action.ToggleMode()  -- Switches PvE <-> PvP
```

#### `Action.ToggleRole([fixed], [between])`
Toggle role (Tank/Healer/Damager).

**Parameters:**
- `fixed` (string, optional): Force role to "Tank", "Healer", or "Damager"
- `between` (string, optional): Alternate role

**Returns:** None

#### `Action.SetToggle(arg, custom, opposite)`
Low-level toggle setter.

**Parameters:**
- `arg` (table): Toggle configuration
- `custom` (any, optional): Custom value
- `opposite` (boolean, optional): Invert value

**Returns:** None

#### `Action.GetToggle(n, toggle)`
Get toggle state.

**Parameters:**
- `n` (number): Toggle category (1=profile, 2=general)
- `toggle` (string): Toggle name (e.g., "AoE", "Burst")

**Returns:** (any) Toggle value

**Usage:**
```lua
local burstMode = Action.GetToggle(1, "Burst")  -- "Everything", "Auto", or "Off"
local aoeEnabled = Action.GetToggle(2, "AoE")   -- boolean
```

### Queue System

The queue system allows rotation actions to be prioritized via macros.

#### `Action.MacroQueue(key, args)`
Queue an action for execution.

**Parameters:**
- `key` (string): Action key from Actions tab
- `args` (table, optional): Additional conditions
  - `Priority` (number): Queue priority (1 = highest)
  - `CP` (number): Combo points requirement
  - Other rotation-specific keys

**Returns:** None

**Usage:**
```lua
-- Queue with priority
Action.MacroQueue("Backstab", { Priority = 1 })

-- Queue with combo point requirement
Action.MacroQueue("Eviscerate", { Priority = 1, CP = 5 })

-- Macro example
/run Action.MacroQueue("Backstab")
```

#### `Action.IsQueueRunning()`
Check if queue system has active entries.

**Returns:** (boolean) True if queue is active

#### `Action.IsQueueRunningAuto()`
Check if auto-queue is running.

**Returns:** (boolean)

#### `Action.CancelAllQueue()`
Clear all queued actions.

**Returns:** None

### Blocker System

#### `Action.MacroBlocker(key)`
Block/unblock an action from rotation.

**Parameters:**
- `key` (string): Action key from Actions tab

**Returns:** None

**Usage:**
```lua
-- Macro to toggle blocking
/run Action.MacroBlocker("Bloodlust")
```

### Macro Utilities

#### `Action.CraftMacro(macroName, macroBody, perCharacter, useQuestionIcon, leaveNewLine, isHidden)`
Create a WoW macro programmatically.

**Parameters:**
- `macroName` (string): Macro name
- `macroBody` (string): Macro text (max 255 bytes)
- `perCharacter` (boolean): Character-specific vs account-wide
- `useQuestionIcon` (boolean): Use question mark icon
- `leaveNewLine` (boolean): Leave newline at end
- `isHidden` (boolean): Hide from macro UI

**Returns:** (boolean) Success

**Limitations:**
- 255 byte limit
- Cannot create in combat
- Will fail if macro limit reached

#### `Action.ConvertSpellNameToID(spellName)`
Convert spell name to spell ID.

**Parameters:**
- `spellName` (string): Localized spell name

**Returns:** (number|nil) Spell ID or nil

### Localization

#### `Action.GetLocalization()`
Get localization table.

**Returns:** (table) Localization strings

#### `Action.GetCL()`
Get current language code.

**Returns:** (string) Language code (e.g., "enUS")

**Usage:**
```lua
local L = Action.GetLocalization()
print(L.CREATED)  -- "created"
```

### Utility Functions

#### `Action.GetMouseFocus()`
Backwards-compatible mouse focus getter.

**Returns:** (frame) Frame under mouse

#### `Action.PlaySound(sound)`
Play a sound file.

**Parameters:**
- `sound` (string|number): Sound file path or ID

**Returns:** None

**Usage:**
```lua
Action.PlaySound("Interface\\AddOns\\Action\\Sounds\\alert.ogg")
```

#### `Action.Print(text, bool, ignore)`
Print to chat frame.

**Parameters:**
- `text` (string): Message text
- `bool` (boolean, optional): Color/formatting flag
- `ignore` (boolean, optional): Ignore disable print setting

**Returns:** None

### UI Management

#### `Action.ToggleMainUI()`
Show/hide main configuration UI.

**Returns:** None

#### `Action.ToggleMinimap([state])`
Show/hide minimap icon.

**Parameters:**
- `state` (boolean, optional): Explicit state

**Returns:** None

#### `Action.MinimapIsShown()`
Check if minimap icon is visible.

**Returns:** (boolean)

### Global Cooldown (GCD)

#### `Action.GetGCD()`
Get GCD duration.

**Returns:** (number) GCD in seconds (typically 1.5 / (1 + haste%))

**Usage:**
```lua
local gcd = Action.GetGCD()  -- e.g., 1.2 seconds
```

#### `Action.GetCurrentGCD()`
Get remaining GCD time.

**Returns:** (number) Time left on GCD in seconds, 0 if not active

**Usage:**
```lua
if Action.GetCurrentGCD() == 0 then
    -- GCD is ready
end
```

#### `Action.IsActiveGCD()`
Check if GCD is active.

**Returns:** (boolean)

#### `Action.OnGCD(duration)`
Check if duration represents GCD.

**Parameters:**
- `duration` (number): Cooldown duration

**Returns:** (boolean) True if duration is a GCD

### Network/Performance

#### `Action.GetPing()`
Get network latency.

**Returns:** (number) Latency in seconds

**Usage:**
```lua
local ping = Action.GetPing()  -- e.g., 0.05 (50ms)
```

#### `Action.GetLatency()`
Get total latency (ping + spell queue window).

**Returns:** (number) Total delay in seconds

### Specialization API

#### `Action.GetNumSpecializations()`
Get number of specializations.

**Returns:** (number)

#### `Action.GetCurrentSpecialization()`
Get active specialization index.

**Returns:** (number) 1-4

#### `Action.GetCurrentSpecializationID()`
Get active specialization ID.

**Returns:** (number) Spec ID

#### `Action.GetCurrentSpecializationRole()`
Get current role.

**Returns:** (string) "TANK", "HEALER", or "DAMAGER"

#### `Action.GetCurrentSpecializationRoles()`
Get all available roles.

**Returns:** (table) Array of role strings

### Line of Sight (LOS)

#### `Action.UnitInLOS(unitID, unitGUID)`
Check if unit is in line of sight.

**Parameters:**
- `unitID` (string): Unit token
- `unitGUID` (string, optional): Unit GUID for validation

**Returns:** (boolean) True if in LOS

**Note:** Requires LOS System enabled in settings.

#### `Action.SetTimerLOS(timer, isTarget)`
Set LOS timer for unit.

**Parameters:**
- `timer` (number): Duration in seconds
- `isTarget` (boolean): Is main target

**Returns:** None

### Interrupt System

#### `Action.InterruptIsON(toggleOrCategory)`
Check if interrupts are enabled.

**Parameters:**
- `toggleOrCategory` (string): "Interrupt" or category name

**Returns:** (boolean)

#### `Action.InterruptIsBlackListed(unitID, spellName)`
Check if spell is blacklisted.

**Parameters:**
- `unitID` (string): Unit token
- `spellName` (string): Spell name

**Returns:** (boolean)

#### `Action.InterruptEnabled(category, spellName)`
Check if spell interrupt is enabled.

**Parameters:**
- `category` (string): Interrupt category
- `spellName` (string): Spell name

**Returns:** (boolean)

#### `Action.InterruptIsValid(unitID, toggle, ignoreToggle, countGCD)`
Comprehensive interrupt validation.

**Parameters:**
- `unitID` (string): Unit token
- `toggle` (string): Toggle name
- `ignoreToggle` (boolean): Skip toggle check
- `countGCD` (number): GCD timing offset

**Returns:** (boolean) True if interrupt should fire

### Aura/Dispel System

#### `Action.AuraIsON(Toggle)`
Check if aura dispel is enabled.

**Parameters:**
- `Toggle` (string): Toggle name

**Returns:** (boolean)

#### `Action.AuraGetCategory(Category)`
Get aura category configuration.

**Parameters:**
- `Category` (string): Category name

**Returns:** (table) Category data

#### `Action.AuraIsBlackListed(unitID)`
Check if unit is dispel blacklisted.

**Parameters:**
- `unitID` (string): Unit token

**Returns:** (boolean)

#### `Action.AuraIsValid(unitID, Toggle, Category)`
Comprehensive aura validation.

**Parameters:**
- `unitID` (string): Unit token
- `Toggle` (string): Toggle name
- `Category` (string): Category name

**Returns:** (boolean) True if dispel should fire

### Burst/Racial Utilities

#### `Action.BurstIsON(unitID)`
Check if burst should be used on unit.

**Parameters:**
- `unitID` (string, optional): Unit token (defaults to "target")

**Returns:** (boolean) True if burst should be used

**Usage:**
```lua
if Action.BurstIsON("target") then
    -- Use offensive cooldowns
end
```

#### `Action.RacialIsON(self)`
Check if racial should be used (respects toggles).

**Returns:** (boolean)

### Helper Functions

#### `Action.GetActionTableByKey(key)`
Get action table entry by key.

**Parameters:**
- `key` (string): Action key

**Returns:** (table|nil) Action data

#### `Action.WipeTableKeyIdentify()`
Clear action key identification cache.

**Returns:** None

---

## Unit Engine

The Unit engine provides 100+ methods for querying unit state. All methods are cached for performance.

### Creating Unit Objects

```lua
local unit = Action.Unit("target")
local unit = Unit("target")  -- Also available in TMW environment

-- Valid unitIDs: "player", "target", "focus", "mouseover", "boss1-5",
--                "arena1-5", "party1-5", "raid1-40", "nameplate1-40", etc.
```

### Instantiation

#### `Action.Unit(unitID)`
Create/retrieve a unit object.

**Parameters:**
- `unitID` (string): WoW unit token

**Returns:** (Unit) Unit object with all methods

**Properties:**
- `UnitID` (string): The unit token
- `Refresh` (number): Cache refresh timer

---

### Existence & State Methods

#### `:Exists()`
Check if unit exists.

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):Exists() then
    -- target exists
end
```

#### `:IsDead()`
Check if unit is dead.

**Returns:** (boolean)

#### `:IsDeadOrGhost()`
Check if unit is dead or ghost.

**Returns:** (boolean)

#### `:IsGhost()`
Check if unit is a ghost.

**Returns:** (boolean)

#### `:IsAPlayer()`
Check if unit is a player.

**Returns:** (boolean)

#### `:IsPlayer()`
Check if unit is THE player.

**Returns:** (boolean) True only for "player" unit

#### `:IsPlayerControlled()`
Check if player-controlled (player or pet).

**Returns:** (boolean)

#### `:InCombat()`
Check if unit is in combat.

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):InCombat() then
    -- target is in combat
end
```

#### `:CombatTime()`
Get time unit has been in combat.

**Returns:** (number) Seconds in combat, 0 if not in combat

#### `:IsVisible()`
Check if unit is visible.

**Returns:** (boolean)

#### `:IsConnected()`
Check if unit is connected (online).

**Returns:** (boolean)

#### `:IsCharmed()`
Check if unit is mind controlled.

**Returns:** (boolean)

#### `:InVehicle()`
Check if unit is in a vehicle.

**Returns:** (boolean)

#### `:IsFeignDeath()`
Check if unit is feigning death.

**Returns:** (boolean)

---

### Health Methods

#### `:Health()`
Get current health.

**Returns:** (number) Current HP

**Usage:**
```lua
local hp = Unit("target"):Health()
```

#### `:HealthMax()`
Get maximum health.

**Returns:** (number) Max HP

#### `:HealthPercent()`
Get health percentage.

**Returns:** (number) 0-100

**Usage:**
```lua
if Unit("target"):HealthPercent() < 20 then
    -- execute range
end
```

#### `:HealthDeficit()`
Get missing health.

**Returns:** (number) MaxHP - CurrentHP

#### `:HealthDeficitPercent()`
Get missing health percentage.

**Returns:** (number) 0-100

#### `:HealthPredicted()`
Get health including incoming heals.

**Returns:** (number)

#### `:HealthPredictedPercent()`
Get predicted health percentage.

**Returns:** (number) 0-100

#### `:HealthPredictedDeficit()`
Get missing health after incoming heals.

**Returns:** (number)

#### `:IncomingHeal()`
Get incoming heal amount.

**Returns:** (number)

#### `:IncomingHealOverTime()`
Get incoming HoT amount.

**Returns:** (number)

#### `:IsHealingAbsorbed()`
Check if unit has heal absorption.

**Returns:** (boolean)

#### `:HealAbsorb()`
Get heal absorption amount.

**Returns:** (number)

#### `:HasIncomingResurrection()`
Check if unit has pending resurrection.

**Returns:** (boolean)

#### `:TimeToDie([offset], [minValue])`
Estimate time until death.

**Parameters:**
- `offset` (number, optional): Time offset for calculation
- `minValue` (number, optional): Minimum TTD to return

**Returns:** (number) Estimated seconds to death, 99999 if not dying

**Usage:**
```lua
local ttd = Unit("target"):TimeToDie()
if ttd > 0 and ttd < 10 then
    -- Target will die in 10 seconds
end
```

#### `:TimeToDieX(X)`
Estimate time until health reaches X%.

**Parameters:**
- `X` (number): Health percentage threshold

**Returns:** (number) Seconds until health reaches X%

---

### Power Methods

#### `:Power([type])`
Get current power.

**Parameters:**
- `type` (number, optional): Power type enum

**Returns:** (number) Current power

#### `:PowerMax([type])`
Get maximum power.

**Parameters:**
- `type` (number, optional): Power type enum

**Returns:** (number) Max power

#### `:PowerPercent([type])`
Get power percentage.

**Parameters:**
- `type` (number, optional): Power type enum

**Returns:** (number) 0-100

#### `:PowerDeficit([type])`
Get missing power.

**Parameters:**
- `type` (number, optional): Power type enum

**Returns:** (number)

#### `:PowerRegen([inv])`
Get power regeneration rate.

**Parameters:**
- `inv` (number, optional): Power type

**Returns:** (number) Power per second

#### `:PowerType()`
Get unit's power type.

**Returns:** (number) Power type enum

**Power Types:**
- `0` - Mana
- `1` - Rage
- `2` - Focus
- `3` - Energy
- `4` - ComboPoints
- `6` - RunicPower
- `7` - SoulShards
- `8` - LunarPower
- `9` - HolyPower
- `11` - Maelstrom
- `12` - Chi
- `13` - Insanity
- `16` - ArcaneCharges
- `17` - Fury
- `18` - Pain
- `19` - Essence

---

### Aura Methods (Buffs & Debuffs)

#### `:HasBuffs(spell, [sourceUnit])`
Check if unit has buff.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean)

**Usage:**
```lua
-- Single spell
if Unit("player"):HasBuffs(774) then  -- Rejuvenation
    -- has buff
end

-- Multiple spells (OR logic)
if Unit("player"):HasBuffs({774, 8936, 33763}) then
    -- has any of these buffs
end

-- From specific caster
if Unit("target"):HasBuffs(774, "player") then
    -- target has YOUR Rejuvenation
end
```

#### `:HasDeBuffs(spell, [sourceUnit])`
Check if unit has debuff.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):HasDeBuffs(8921) then  -- Moonfire
    -- has debuff
end
```

#### `:GetBuffs(spell, [sourceUnit])`
Get buff details.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (number, number, number, string, number)
- count (number): Stack count
- duration (number): Total duration
- expires (number): Expiration time
- caster (string): Source unitID
- spellID (number): Matched spell ID

**Usage:**
```lua
local count, duration, expires, caster, spellID = Unit("player"):GetBuffs(774)
if expires and expires > 0 then
    local remaining = expires - TMW.time
    print("Rejuvenation expires in", remaining, "seconds")
end
```

#### `:GetDeBuffs(spell, [sourceUnit])`
Get debuff details.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** Same as `:GetBuffs()`

#### `:HasBuffsStacks(spell, [count], [sourceUnit])`
Check buff stack count.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `count` (number, optional): Minimum stacks (default 1)
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean)

**Usage:**
```lua
if Unit("player"):HasBuffsStacks(93622, 3) then  -- Mana Tea, 3+ stacks
    -- has 3 or more stacks
end
```

#### `:HasDeBuffsStacks(spell, [count], [sourceUnit])`
Check debuff stack count.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `count` (number, optional): Minimum stacks
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean)

#### `:BuffRemains(spell, [sourceUnit])`
Get buff remaining duration.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (number) Seconds remaining, 0 if not present

**Usage:**
```lua
local remaining = Unit("player"):BuffRemains(774)
if remaining < 5 then
    -- Rejuvenation expires in less than 5 seconds
end
```

#### `:DeBuffRemains(spell, [sourceUnit])`
Get debuff remaining duration.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (number) Seconds remaining

#### `:BuffRemainsDuration(spell, [sourceUnit])`
Get buff total duration.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (number) Total duration

#### `:DeBuffRemainsDuration(spell, [sourceUnit])`
Get debuff total duration.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (number) Total duration

#### `:HasBuffsRefreshable(spell, [pandemic], [sourceUnit])`
Check if buff should be refreshed.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `pandemic` (number, optional): Pandemic threshold in seconds
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean) True if missing or in pandemic window

**Usage:**
```lua
if Unit("player"):HasBuffsRefreshable(774, 5.4) then
    -- Rejuvenation missing or <5.4s remaining (pandemic window)
end
```

#### `:HasDeBuffsRefreshable(spell, [pandemic], [sourceUnit])`
Check if debuff should be refreshed.

**Parameters:**
- `spell` (number|string|table): Spell ID, name, or array
- `pandemic` (number, optional): Pandemic threshold
- `sourceUnit` (string, optional): Required caster unit

**Returns:** (boolean)

#### `:SortBuffs(option, [...spells])`
Get auras sorted by specified criteria.

**Parameters:**
- `option` (string): Sort option
  - `"COUNT"` - By stack count (highest first)
  - `"REMAINS"` - By remaining time (highest first)
  - `"DURATION"` - By total duration (highest first)
- `...spells` (vararg): Spell IDs to check

**Returns:** (table) Sorted array of {spellID, count, duration, expires, caster}

**Usage:**
```lua
-- Get HoTs sorted by remaining time
local hots = Unit("target"):SortBuffs("REMAINS", 774, 8936, 33763)
for i, aura in ipairs(hots) do
    print("Spell", aura[1], "expires in", aura[4] - TMW.time, "seconds")
end
```

#### `:SortDeBuffs(option, [...spells])`
Get debuffs sorted by criteria.

**Parameters:**
- `option` (string): Sort option (same as SortBuffs)
- `...spells` (vararg): Spell IDs

**Returns:** (table) Sorted debuff array

---

### Casting Methods

#### `:IsCasting([spell])`
Check if unit is casting.

**Parameters:**
- `spell` (number|string, optional): Specific spell to check

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):IsCasting() then
    -- target is casting something
end

if Unit("target"):IsCasting(2136) then  -- Fire Blast
    -- target is casting Fire Blast
end
```

#### `:IsChanneling([spell])`
Check if unit is channeling.

**Parameters:**
- `spell` (number|string, optional): Specific spell to check

**Returns:** (boolean)

#### `:IsCastingOrChanneling([spell])`
Check if casting or channeling.

**Parameters:**
- `spell` (number|string, optional): Specific spell to check

**Returns:** (boolean)

#### `:CastRemains([spell])`
Get cast time remaining.

**Parameters:**
- `spell` (number|string, optional): Specific spell

**Returns:** (number) Seconds remaining

**Usage:**
```lua
local castRemaining = Unit("target"):CastRemains()
if castRemaining > 0 and castRemaining < 0.5 then
    -- Interrupt window
end
```

#### `:CastPercentage()`
Get cast progress percentage.

**Returns:** (number) 0-100

#### `:CastTime([spell])`
Get total cast time.

**Parameters:**
- `spell` (number|string, optional): Specific spell

**Returns:** (number) Total cast time in seconds

#### `:CastID()`
Get spell ID being cast.

**Returns:** (number|nil) Spell ID or nil

#### `:CastName()`
Get name of spell being cast.

**Returns:** (string|nil) Spell name or nil

#### `:CastInterruptible()`
Check if current cast is interruptible.

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):IsCasting() and Unit("target"):CastInterruptible() then
    -- Can interrupt this cast
end
```

#### `:IsCastingBreakAble()`
Check if casting a breakable CC (Polymorph, etc).

**Returns:** (boolean)

---

### Range & Position Methods

#### `:GetRange()`
Get distance to unit.

**Returns:** (number) Distance in yards, 9999 if unknown

**Usage:**
```lua
local range = Unit("target"):GetRange()
if range <= 5 then
    -- Melee range
end
```

#### `:InRange([distance])`
Check if unit is within range.

**Parameters:**
- `distance` (number, optional): Max distance in yards

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):InRange(30) then
    -- Within 30 yards
end
```

#### `:CanInterract([range])`
Check if unit can be interacted with.

**Parameters:**
- `range` (number, optional): Max range

**Returns:** (boolean) True if in range and can interact

#### `:IsInRangeOf(spell)`
Check if spell is in range of unit.

**Parameters:**
- `spell` (number|string|table): Spell ID/name or action object

**Returns:** (boolean)

**Usage:**
```lua
-- With spell ID
if Unit("target"):IsInRangeOf(8921) then  -- Moonfire
    -- In range
end

-- With action object
local Moonfire = Action.Create({ Type = "Spell", ID = 8921 })
if Unit("target"):IsInRangeOf(Moonfire) then
    -- In range
end
```

#### `:IsMoving()`
Check if unit is moving.

**Returns:** (boolean)

#### `:GetUnitSpeed()`
Get unit movement speed.

**Returns:** (number) Speed in yards/second

---

### Target & Focus Methods

#### `:IsTarget()`
Check if unit is current target.

**Returns:** (boolean)

#### `:IsFocus()`
Check if unit is current focus.

**Returns:** (boolean)

#### `:IsFocused([sourceUnit])`
Check if unit is focused by another unit.

**Parameters:**
- `sourceUnit` (string, optional): Unit to check (default "target")

**Returns:** (boolean) True if unit's target matches sourceUnit

**Usage:**
```lua
if Unit("arena1"):IsFocused("player") then
    -- arena1 is targeting player
end
```

#### `:GetUnitID()`
Get the original unitID.

**Returns:** (string) Unit token

---

### Crowd Control Methods

#### `:InCC([school])`
Check if unit is in crowd control.

**Parameters:**
- `school` (string, optional): CC type
  - `"CONTROL"` - Loss of control
  - `"ROOT"` - Rooted
  - `"STUN"` - Stunned
  - `"DISORIENT"` - Disoriented
  - `"INCAPACITATE"` - Incapacitated
  - `"SILENCE"` - Silenced

**Returns:** (boolean)

**Usage:**
```lua
if Unit("target"):InCC() then
    -- Target is CCed
end

if Unit("target"):InCC("STUN") then
    -- Target is stunned
end
```

#### `:InLossOfControl()`
Check if unit has loss of control.

**Returns:** (boolean)

#### `:HasBreakAbleDebuff()`
Check if unit has a breakable CC debuff (Polymorph, etc).

**Returns:** (boolean)

---

### Role & Classification Methods

#### `:IsHealer()`
Check if unit is a healer.

**Returns:** (boolean)

#### `:IsTank()`
Check if unit is a tank.

**Returns:** (boolean)

#### `:IsDamager()`
Check if unit is a DPS.

**Returns:** (boolean)

#### `:IsMelee()`
Check if unit is melee DPS.

**Returns:** (boolean)

#### `:IsBoss()`
Check if unit is a boss.

**Returns:** (boolean)

#### `:IsElite()`
Check if unit is elite.

**Returns:** (boolean)

#### `:IsRareElite()`
Check if unit is rare elite.

**Returns:** (boolean)

#### `:IsTotem()`
Check if unit is a totem.

**Returns:** (boolean)

#### `:Classification()`
Get unit classification.

**Returns:** (string) "normal", "elite", "rare", "rareelite", "worldboss"

---

### Unit Information Methods

#### `:Name()`
Get unit name.

**Returns:** (string) Unit name

#### `:GUID()`
Get unit GUID.

**Returns:** (string) Unit GUID

#### `:Level()`
Get unit level.

**Returns:** (number) Unit level

#### `:Class()`
Get unit class.

**Returns:** (string) Class token (e.g., "WARRIOR")

#### `:ClassLocalizedName()`
Get localized class name.

**Returns:** (string)

#### `:Race()`
Get unit race.

**Returns:** (string) Race token

#### `:CreatureType()`
Get creature type.

**Returns:** (string) "Beast", "Dragonkin", "Demon", "Elemental", etc.

#### `:CreatureFamily()`
Get creature family (pets).

**Returns:** (string) Pet family

---

### Attack & Threat Methods

#### `:CanAttack([fromUnit])`
Check if unit can be attacked.

**Parameters:**
- `fromUnit` (string, optional): Source unit (default "player")

**Returns:** (boolean)

#### `:IsEnemy([fromUnit])`
Check if unit is hostile.

**Parameters:**
- `fromUnit` (string, optional): Source unit (default "player")

**Returns:** (boolean)

#### `:CanCooperate([fromUnit])`
Check if unit is friendly/neutral.

**Parameters:**
- `fromUnit` (string, optional): Source unit (default "player")

**Returns:** (boolean)

#### `:ThreatSituation([mobUnit])`
Get threat situation.

**Parameters:**
- `mobUnit` (string, optional): Target mob

**Returns:** (number) Threat status
- `0` - No threat
- `1` - Not tanking, higher than tank
- `2` - Insecurely tanking
- `3` - Securely tanking

#### `:ThreatPercent([mobUnit])`
Get threat percentage.

**Parameters:**
- `mobUnit` (string, optional): Target mob

**Returns:** (number) 0-100+

---

### Group & Raid Methods

#### `:IsInRaid()`
Check if unit is in raid.

**Returns:** (boolean)

#### `:IsInGroup()`
Check if unit is in group.

**Returns:** (number) Group type (0=none, 1=party, 2=raid)

#### `:IsInParty()`
Check if unit is in party.

**Returns:** (boolean)

#### `:IsGroupLeader()`
Check if unit is group leader.

**Returns:** (boolean)

---

### Special Methods

#### `:IsToT()`
Check if unit is target of target.

**Returns:** (boolean)

#### `:HasStagger()`
Check if unit has stagger (Brewmaster monks).

**Returns:** (boolean)

#### `:Stagger()`
Get stagger amount.

**Returns:** (number) Stagger damage

#### `:StaggerPercent()`
Get stagger percentage of max health.

**Returns:** (number) 0-100

---

## Player Engine

The Player engine extends Unit with player-specific methods. Access via `Action.Player` or `Player()` in TMW environment.

```lua
local player = Action.Player
-- or
local player = Player  -- In TMW.CNDT.Env
```

**Note:** Player inherits all Unit methods, so `Player:Health()` works identically to `Unit("player"):Health()`.

---

### Stance & Form Methods

#### `Player:IsStance(x)`
Check if in specific stance/form.

**Parameters:**
- `x` (number): Stance index

**Returns:** (boolean)

**Stance Indexes:**
- **Warrior:** 1=Battle, 2=Defensive, 3=Berserker
- **Druid:** 1=Bear, 2=Cat, 3=Travel/Flight, 4+=Moonkin/Tree/Stag
- **Priest:** 1=Shadowform
- **Rogue:** 1=Stealth, 2=Vanish/Shadow Dance
- **Shaman:** 1=Ghost Wolf
- **Warlock:** 1=Metamorphosis
- **Death Knight:** 1=Blood, 2=Frost, 3=Unholy

**Usage:**
```lua
if Player:IsStance(2) then
    -- Warrior in Defensive Stance or Druid in Cat Form
end
```

#### `Player:GetStance()`
Get current stance index.

**Returns:** (number) Stance index (0 if none)

---

### Movement Methods

#### `Player:IsMoving()`
Check if player is moving.

**Returns:** (boolean)

#### `Player:IsMovingTime()`
Get time spent moving.

**Returns:** (number) Seconds

#### `Player:IsStaying()`
Check if player is stationary.

**Returns:** (boolean)

#### `Player:IsStayingTime()`
Get time spent stationary.

**Returns:** (number) Seconds

#### `Player:IsFalling()`
Check if player is falling (excludes jumps).

**Returns:** (boolean, number)
- boolean: True if falling >1.7s
- number: Fall duration

#### `Player:GetFalling()`
Get fall duration.

**Returns:** (number) Seconds

#### `Player:IsSwimming()`
Check if player is swimming.

**Returns:** (boolean)

#### `Player:IsMounted()`
Check if player is mounted.

**Returns:** (boolean)

---

### Stealth & Behind Methods

#### `Player:IsStealthed()`
Check if player is stealthed.

**Returns:** (boolean)

**Note:** Includes Stealth, Vanish, Prowl, Shadowmeld, Invisibility.

#### `Player:IsBehind(x)`
Check if player is behind target.

**Parameters:**
- `x` (number): Time threshold in seconds

**Returns:** (boolean) True if "not behind" error within x seconds

#### `Player:IsBehindTime()`
Get time since last "not behind" error.

**Returns:** (number) Seconds

#### `Player:IsPetBehind(x)`
Check if pet is behind target.

**Parameters:**
- `x` (number): Time threshold

**Returns:** (boolean)

#### `Player:IsPetBehindTime()`
Get time since pet "not behind" error.

**Returns:** (number) Seconds

#### `Player:TargetIsBehind(x)`
Check if target is behind player.

**Parameters:**
- `x` (number): Time threshold

**Returns:** (boolean)

#### `Player:TargetIsBehindTime()`
Get time since target "not behind" error.

**Returns:** (number) Seconds

---

### Casting Methods

#### `Player:IsCasting()`
Check if player is casting.

**Returns:** (boolean)

#### `Player:IsChanneling()`
Check if player is channeling.

**Returns:** (boolean)

#### `Player:CastTimeSinceStart()`
Get time since cast/channel started.

**Returns:** (number) Seconds

#### `Player:CastRemains([spellID])`
Get remaining cast time.

**Parameters:**
- `spellID` (number, optional): Specific spell

**Returns:** (number) Seconds remaining

#### `Player:CastCost()`
Get power cost of current cast.

**Returns:** (number) Power cost

#### `Player:CastCostCache()`
Get cached power cost of current cast.

**Returns:** (number) Power cost

#### `Player:CancelBuff(buffName)`
Cancel a player buff.

**Parameters:**
- `buffName` (string): Buff name to cancel

**Returns:** (boolean) Success

**Usage:**
```lua
-- Cancel Stealth
Player:CancelBuff(GetSpellInfo(1784))
```

---

### Auto-Attack & Shooting

#### `Player:IsShooting()`
Check if auto-shooting (hunters/wands).

**Returns:** (boolean)

#### `Player:GetSwingShoot()`
Get time until next auto-shot.

**Returns:** (number) Seconds until next shot

#### `Player:IsAttacking()`
Check if auto-attacking.

**Returns:** (boolean)

---

### Aura Counting

#### `Player:GetBuffsUnitCount(...)`
Count units with player's buff.

**Parameters:**
- `...` (vararg): Spell IDs or names

**Returns:** (number) Count of units with buff

**Usage:**
```lua
local hotCount = Player:GetBuffsUnitCount(774, 8936, 33763)  -- Rejuv, Regrowth, Lifebloom
print(hotCount, "units have my HoTs")
```

#### `Player:GetDeBuffsUnitCount(...)`
Count units with player's debuff.

**Parameters:**
- `...` (vararg): Spell IDs or names

**Returns:** (number) Count of units with debuff

---

### Glyph Methods (WotLK - BFA)

#### `Player:HasGlyph(spell)`
Check if glyph is active.

**Parameters:**
- `spell` (number|string): Spell ID or name

**Returns:** (boolean)

**Usage:**
```lua
if Player:HasGlyph(54825) then  -- Glyph of Moonfire
    -- glyph active
end
```

---

### Totem Methods (Shaman)

#### `Player:GetTotemInfo(i)`
Get totem information.

**Parameters:**
- `i` (number): Totem slot (1-4)

**Returns:** (boolean, string, number, number, string)
- haveTotem (boolean)
- name (string)
- startTime (number)
- duration (number)
- icon (string)

#### `Player:GetTotemTimeLeft(i)`
Get totem time remaining.

**Parameters:**
- `i` (number): Totem slot

**Returns:** (number) Seconds remaining

---

### Stats Methods

#### `Player:CritChancePct()`
Get critical strike chance.

**Returns:** (number) 0-100

#### `Player:HastePct()`
Get haste percentage.

**Returns:** (number) Haste%

#### `Player:SpellHaste()`
Get spell haste modifier.

**Returns:** (number) Multiplier (e.g., 1.15 = 15% haste)

#### `Player:Execute_Time(spellID)`
Calculate execute time for spell.

**Parameters:**
- `spellID` (number): Spell ID

**Returns:** (number) Cast time adjusted for haste

---

### GCD Methods

#### `Player:GCDRemains()`
Get remaining GCD time.

**Returns:** (number) Seconds

**Usage:**
```lua
if Player:GCDRemains() == 0 then
    -- GCD ready
end
```

---

### Swing Timer Methods

#### `Player:GetSwing([inv])`
Get time until next melee swing.

**Parameters:**
- `inv` (boolean, optional): Off-hand slot

**Returns:** (number) Seconds until swing

#### `Player:GetSwingMax([inv])`
Get swing timer duration.

**Parameters:**
- `inv` (boolean, optional): Off-hand

**Returns:** (number) Swing speed in seconds

#### `Player:GetSwingStart([inv])`
Get swing start time.

**Parameters:**
- `inv` (boolean, optional): Off-hand

**Returns:** (number) TMW.time when swing started

#### `Player:ReplaceSwingDuration(inv, dur)`
Override swing duration (for abilities that reset swing).

**Parameters:**
- `inv` (boolean): Off-hand
- `dur` (number): New duration

**Returns:** None

#### `Player:GetWeaponMeleeDamage(inv, mod)`
Get weapon damage.

**Parameters:**
- `inv` (boolean): Off-hand
- `mod` (number, optional): Damage modifier

**Returns:** (number) Weapon damage

#### `Player:AttackPowerDamageMod([offHand])`
Get attack power damage modifier.

**Parameters:**
- `offHand` (boolean, optional): Off-hand

**Returns:** (number) AP damage contribution

---

### Equipment Methods

#### `Player:IsSwapLocked()`
Check if equipment swap is locked (in progress).

**Returns:** (boolean)

#### `Player:AddTier(tier, items)`
Register tier set pieces.

**Parameters:**
- `tier` (string): Tier name (e.g., "T19")
- `items` (table): Array of item IDs

**Returns:** None

**Usage:**
```lua
Player:AddTier("T19", {138327, 138329, 138332, 138334, 138338})
```

#### `Player:GetTier(tier)`
Get equipped tier count.

**Parameters:**
- `tier` (string): Tier name

**Returns:** (number) Number of pieces equipped

#### `Player:HasTier(tier, count)`
Check tier bonus.

**Parameters:**
- `tier` (string): Tier name
- `count` (number): Required pieces

**Returns:** (boolean)

**Usage:**
```lua
if Player:HasTier("T19", 4) then
    -- 4-piece T19 bonus active
end
```

#### `Player:RemoveTier(tier)`
Unregister tier set.

**Parameters:**
- `tier` (string): Tier name

**Returns:** None

---

### Bag/Inventory Methods

#### `Player:AddBag(name, data)`
Register item to search for in bags.

**Parameters:**
- `name` (string): Lookup key
- `data` (table): Search criteria
  - `itemID` (number, optional)
  - `itemEquipLoc` (string, optional)
  - `itemClassID` (number, optional)
  - `itemSubClassID` (number, optional)
  - `isEquippableItem` (boolean, optional)

**Returns:** None

**Usage:**
```lua
Player:AddBag("HealthPotion", { itemClassID = 0, itemSubClassID = 1 })
```

#### `Player:GetBag(name)`
Get bag item info.

**Parameters:**
- `name` (string): Lookup key

**Returns:** (table|nil)
- `count` (number)
- `itemID` (number)

#### `Player:RemoveBag(name)`
Unregister bag item.

**Parameters:**
- `name` (string): Lookup key

**Returns:** None

#### `Player:AddInv(name, slot, data)`
Register equipped item.

**Parameters:**
- `name` (string): Lookup key
- `slot` (number, optional): Inventory slot (nil = search all)
- `data` (table): Search criteria (same as AddBag)

**Returns:** None

#### `Player:GetInv(name)`
Get equipped item info.

**Parameters:**
- `name` (string): Lookup key

**Returns:** (table|nil)
- `slot` (number)
- `itemID` (number)

#### `Player:RemoveInv(name)`
Unregister equipped item.

**Parameters:**
- `name` (string): Lookup key

**Returns:** None

---

### Weapon/Ammo Registration

These methods register specific item types for quick lookups.

#### `Player:RegisterAmmo()`
Register ammo (arrows/bullets).

**Returns:** None

#### `Player:RegisterThrown()`
Register thrown weapon.

**Returns:** None

#### `Player:RegisterShield()`
Register shield.

**Returns:** None

#### `Player:RegisterWeaponOffHand()`
Register off-hand weapon.

**Returns:** None

#### `Player:RegisterWeaponTwoHand()`
Register two-handed weapon.

**Returns:** None

#### `Player:RegisterWeaponMainOneHandDagger()`
Register main-hand dagger.

**Returns:** None

#### `Player:RegisterWeaponMainOneHandSword()`
Register main-hand sword.

**Returns:** None

#### `Player:RegisterWeaponOffOneHandSword()`
Register off-hand sword.

**Returns:** None

---

### Weapon/Ammo Getters

#### `Player:GetAmmo()`
Get ammo item ID.

**Returns:** (number|nil) Item ID

#### `Player:GetArrow()`
Get arrow item ID.

**Returns:** (number|nil) Item ID

#### `Player:GetBullet()`
Get bullet item ID.

**Returns:** (number|nil) Item ID

#### `Player:GetThrown()`
Get thrown weapon ID.

**Returns:** (number|nil) Item ID

#### `Player:HasShield([isEquiped])`
Check for shield.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

#### `Player:HasWeaponOffHand([isEquiped])`
Check for off-hand weapon.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

#### `Player:HasWeaponTwoHand([isEquiped])`
Check for two-handed weapon.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

#### `Player:HasWeaponMainOneHandDagger([isEquiped])`
Check for main-hand dagger.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

#### `Player:HasWeaponMainOneHandSword([isEquiped])`
Check for main-hand sword.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

#### `Player:HasWeaponOffOneHandSword([isEquiped])`
Check for off-hand sword.

**Parameters:**
- `isEquiped` (boolean, optional): Must be equipped

**Returns:** (boolean)

---

### Power Methods (Player-Specific)

Player has additional power methods beyond Unit:

#### Mana

```lua
Player:ManaMax()                    -- Max mana
Player:Mana()                       -- Current mana
Player:ManaPercentage()             -- Mana %
Player:ManaDeficit()                -- Missing mana
Player:ManaDeficitPercentage()      -- Missing mana %
Player:ManaRegen()                  -- Mana regen/sec
Player:ManaCastRegen(CastTime)      -- Mana regen during cast
Player:ManaTimeToMax()              -- Time to full mana
Player:ManaTimeToX(Amount)          -- Time to reach amount
Player:ManaP()                      -- Mana (pooling adjusted)
Player:ManaPercentageP()            -- Mana % (pooling)
Player:ManaDeficitP()               -- Deficit (pooling)
Player:ManaDeficitPercentageP()     -- Deficit % (pooling)
```

#### Rage

```lua
Player:RageMax()                    -- Max rage
Player:Rage()                       -- Current rage
Player:RagePercentage()             -- Rage %
Player:RageDeficit()                -- Missing rage
Player:RageDeficitPercentage()      -- Missing rage %
```

#### Focus

```lua
Player:FocusMax()                   -- Max focus
Player:Focus()                      -- Current focus
Player:FocusRegen()                 -- Focus regen/sec
Player:FocusPercentage()            -- Focus %
Player:FocusDeficit()               -- Missing focus
Player:FocusDeficitPercentage()     -- Missing focus %
Player:FocusRegenPercentage()       -- Regen as %
Player:FocusTimeToMax()             -- Time to full
Player:FocusTimeToX(Amount)         -- Time to amount
```

#### Energy

```lua
Player:EnergyMax()                  -- Max energy
Player:Energy()                     -- Current energy
Player:EnergyRegen()                -- Energy regen/sec
Player:EnergyPercentage()           -- Energy %
Player:EnergyDeficit()              -- Missing energy
Player:EnergyDeficitPercentage()    -- Missing energy %
Player:EnergyRegenPercentage()      -- Regen as %
Player:EnergyTimeToMax()            -- Time to full
Player:EnergyTimeToX(Amount)        -- Time to amount
Player:EnergyPredicted()            -- Predicted energy
Player:EnergyPredictedPercentage()  -- Predicted %
```

#### Combo Points

```lua
Player:ComboPoints()                -- Current combo points
Player:ComboPointsMax()             -- Max combo points
Player:ComboPointsDeficit()         -- Missing combo points
```

#### Runes (Death Knight)

```lua
Player:Runes(presence)              -- Runes of type available
Player:RunesMax(presence)           -- Max runes of type
Player:RunesCooldown(presence)      -- Time to next rune
Player:RunesArray()                 -- Array of rune states
```

**Rune Presence Types:**
- `1` or `"Blood"`
- `2` or `"Frost"`
- `3` or `"Unholy"`
- `4` or `"Death"`

#### Holy Power (Paladin)

```lua
Player:HolyPower()                  -- Current holy power
Player:HolyPowerMax()               -- Max holy power
Player:HolyPowerDeficit()           -- Missing holy power
```

#### Soul Shards (Warlock)

```lua
Player:SoulShards()                 -- Current soul shards
Player:SoulShardsMax()              -- Max soul shards
Player:SoulShardsDeficit()          -- Missing shards
```

---

## Team Engines

Team engines provide filtered unit lists by role for friendly/enemy units.

### Friendly Team

#### `Action.FriendlyTeam(ROLE)`
Get friendly team with role filter.

**Parameters:**
- `ROLE` (string, optional): Role filter
  - `"TANK"`
  - `"HEALER"`
  - `"DAMAGER"`
  - `"DAMAGER_MELEE"`
  - `nil` - All friendly units

**Returns:** (table) Team object with iteration methods

**Usage:**
```lua
-- Iterate all friendly units
for _, unitID in pairs(Action.FriendlyTeam():GetCache()) do
    if Unit(unitID):HealthPercent() < 50 then
        -- Unit needs healing
    end
end

-- Iterate only healers
for _, unitID in pairs(Action.FriendlyTeam("HEALER"):GetCache()) do
    -- Healer units
end
```

### Enemy Team

#### `Action.EnemyTeam(ROLE)`
Get enemy team with role filter.

**Parameters:**
- `ROLE` (string, optional): Same roles as FriendlyTeam

**Returns:** (table) Team object

**Usage:**
```lua
-- Iterate enemy DPS
for _, unitID in pairs(Action.EnemyTeam("DAMAGER"):GetCache()) do
    if Unit(unitID):IsCasting() then
        -- Enemy DPS is casting
    end
end
```

### Team Methods

Both FriendlyTeam and EnemyTeam share these methods:

#### `:GetCache()`
Get unit list.

**Returns:** (table) Array of unitIDs

#### `:Iterate([func])`
Iterate units with function.

**Parameters:**
- `func` (function, optional): Callback(unitID, index)

**Returns:** None or iterator

**Usage:**
```lua
-- With callback
Action.FriendlyTeam():Iterate(function(unitID)
    print(unitID, Unit(unitID):Health())
end)

-- As iterator
for unitID in Action.FriendlyTeam():Iterate() do
    print(unitID)
end
```

---

## Spell/Item Objects

Action objects represent spells, items, and macros with a unified API.

### Creating Action Objects

```lua
-- From Modules/Actions.lua
local Spell = Action.Create({ Type = "Spell", ID = 12345 })
local Item = Action.Create({ Type = "Item", ID = 67890 })
local Macro = Action.Create({ Type = "Macro", Name = "MyMacro" })
```

**Common Pattern in Rotations:**
```lua
local A = setmetatable({}, { __index = Action })

-- Define spells
A.Spell = Action.Create({ Type = "Spell", ID = 8921 })  -- Moonfire
A.Item = Action.Create({ Type = "Item", ID = 5512 })    -- Healthstone

-- Use in rotation
if A.Spell:IsReady("target") then
    return A.Spell
end
```

---

### Action Object Properties

```lua
object.Type         -- "Spell", "Item", "Macro", "Potion", "Trinket"
object.ID           -- Spell ID or Item ID
object.Name         -- Name (for macros)
object.SlotID       -- Inventory slot (for trinkets/items)
```

---

### Readiness Methods

#### `:IsReady(unitID, [skipRange], [skipLua], [skipShouldStop], [skipUsable])`
Check if action is ready to use.

**Parameters:**
- `unitID` (string): Target unit
- `skipRange` (boolean, optional): Skip range check
- `skipLua` (boolean, optional): Skip Lua condition check
- `skipShouldStop` (boolean, optional): Skip casting check
- `skipUsable` (boolean, optional): Skip usable check

**Returns:** (boolean) True if ready

**Checks:**
- Cooldown ready
- In range (unless skipped)
- Usable (unless skipped)
- Not casting (unless skipped)
- Custom Lua conditions (unless skipped)
- Not blocked by Queue/Blocker

**Usage:**
```lua
local Moonfire = Action.Create({ Type = "Spell", ID = 8921 })

if Moonfire:IsReady("target") then
    -- Moonfire is off CD, in range, usable, not blocked
    return Moonfire
end
```

#### `:IsReadyP(unitID, [skipRange], [skipLua], [skipShouldStop], [skipUsable])`
IsReady with GCD pooling (waits for GCD).

**Returns:** (boolean)

#### `:IsReadyM(unitID, [skipRange], [skipUsable])`
IsReady for mouseover macros.

**Returns:** (boolean)

#### `:IsReadyByPassCastGCD(unitID, [skipRange], [skipLua], [skipUsable])`
IsReady bypassing cast and GCD checks.

**Returns:** (boolean)

#### `:IsReadyByPassCastGCDP(unitID, [skipRange], [skipLua], [skipUsable])`
IsReadyP bypassing cast and GCD checks.

**Returns:** (boolean)

#### `:IsReadyToUse(unitID, [skipShouldStop], [skipUsable])`
IsReady ignoring range.

**Returns:** (boolean)

---

### Usability Methods

#### `:IsUsable([extraCD], [skipUsable])`
Check if action is usable.

**Parameters:**
- `extraCD` (number, optional): Extra CD offset
- `skipUsable` (boolean, optional): Skip API usable check

**Returns:** (boolean)

**Checks:**
- Spell/item exists
- Learned/in bags
- Cooldown ready (with extraCD offset)
- API usable (mana, reagents, etc)

#### `:IsHarmful()`
Check if action is harmful (offensive).

**Returns:** (boolean)

#### `:IsHelpful()`
Check if action is helpful (friendly).

**Returns:** (boolean)

#### `:IsCurrent()`
Check if action is currently active (auto-attack, etc).

**Returns:** (boolean)

#### `:HasRange()`
Check if action has a range.

**Returns:** (boolean)

#### `:IsInRange(unitID)`
Check if action is in range of unit.

**Parameters:**
- `unitID` (string): Target unit

**Returns:** (boolean)

**Usage:**
```lua
if Spell:IsInRange("target") then
    -- In range
end
```

---

### Cooldown Methods

#### `:GetCooldown()`
Get cooldown remaining.

**Returns:** (number) Seconds on CD, 0 if ready

**Usage:**
```lua
local cd = Spell:GetCooldown()
if cd > 0 and cd < 10 then
    -- Coming off CD soon
end
```

#### `:GetSpellBaseCooldown()`
Get unmodified base CD.

**Returns:** (number) Base CD in seconds

---

### Spell-Specific Methods

#### `:GetSpellCharges()`
Get current charges.

**Returns:** (number) Current charges

#### `:GetSpellChargesMax()`
Get max charges.

**Returns:** (number) Max charges

#### `:GetSpellChargesFrac()`
Get fractional charges.

**Returns:** (number) Charges with partial recharge (e.g., 1.75)

#### `:GetSpellChargesFullRechargeTime()`
Get time to full charges.

**Returns:** (number) Seconds to max charges

#### `:GetSpellCastTime()`
Get cast time.

**Returns:** (number) Cast time in seconds

#### `:GetSpellCastTimeCache()`
Get cached cast time (static).

**Returns:** (number) Base cast time

#### `:GetSpellPowerCost()`
Get current power cost (realtime).

**Returns:** (number, number)
- cost (number)
- type (number) PowerType enum

#### `:GetSpellPowerCostCache()`
Get cached power cost (static).

**Returns:** (number, number)

#### `:GetSpellBaseDuration()`
Get base aura duration.

**Returns:** (number) Seconds

#### `:GetSpellMaxDuration()`
Get max pandemic-extended duration.

**Returns:** (number) Seconds

#### `:GetSpellPandemicThreshold()`
Get pandemic refresh threshold.

**Returns:** (number) Seconds (typically duration * 0.3)

#### `:GetSpellTravelTime(unitID)`
Get projectile travel time.

**Parameters:**
- `unitID` (string): Target unit

**Returns:** (number) Travel time in seconds

#### `:IsSpellInFlight()`
Check if spell projectile is in flight.

**Returns:** (boolean)

#### `:IsSpellInCasting()`
Check if spell is being cast.

**Returns:** (boolean)

#### `:IsSpellCurrent()`
Check if spell is current cast.

**Returns:** (boolean)

#### `:IsSpellLastGCD([byID])`
Check if spell was last GCD.

**Parameters:**
- `byID` (boolean, optional): Match by ID vs name

**Returns:** (boolean)

#### `:GetSpellTimeSinceLastCast()`
Get time since last cast (in combat).

**Returns:** (number) Seconds

#### `:GetSpellCounter()`
Get total casts (in combat).

**Returns:** (number) Cast count

#### `:GetSpellAmount(unitID, [X])`
Get damage/healing done by spell.

**Parameters:**
- `unitID` (string): Target unit
- `X` (number, optional): Time window in seconds

**Returns:** (number) Total amount

#### `:GetSpellAbsorb(unitID)`
Get current absorb from spell.

**Parameters:**
- `unitID` (string): Target unit

**Returns:** (number) Absorb amount

#### `:GetSpellAutocast()`
Get autocast state (pet abilities).

**Returns:** (boolean, boolean)
- autocastable (boolean)
- enabled (boolean)

#### `:GetSpellRank()`
Get spell rank.

**Returns:** (number|nil) Rank or nil

#### `:GetSpellMaxRank()`
Get max rank available.

**Returns:** (number) Max rank

#### `:GetTalentRank()`
Get talent rank.

**Returns:** (number) 0-5

#### `:IsTalentLearned()`
Check if talent is learned.

**Returns:** (boolean)

---

### Item-Specific Methods

#### `:GetItemCooldown()`
Get item cooldown.

**Returns:** (number) Seconds on CD

#### `:GetItemSpell()`
Get spell granted by item.

**Returns:** (string|nil) Spell name

#### `:GetItemCategory()`
Get item category.

**Returns:** (string) "CC", "HEAL", "BOTH", etc.

#### `:IsItemTank()`
Check if item is for tanks.

**Returns:** (boolean)

#### `:IsItemDamager()`
Check if item is for DPS.

**Returns:** (boolean)

#### `:IsItemCurrent()`
Check if item is currently active.

**Returns:** (boolean)

#### `:GetCount()`
Get item count.

**Returns:** (number) Item count in bags

---

### Immunity & Blocking

#### `:AbsentImun(unitID, [imunBuffs])`
Check if target lacks immunity.

**Parameters:**
- `unitID` (string): Target unit
- `imunBuffs` (table, optional): Custom immunity list

**Returns:** (boolean) True if can hit target

**Usage:**
```lua
if Spell:AbsentImun("target") then
    -- Target has no immunity to this spell school
end
```

#### `:IsBlockedByAny()`
Check if blocked by Queue/Blocker.

**Returns:** (boolean)

#### `:IsSuspended([delay], [reset])`
Check/set suspension timer.

**Parameters:**
- `delay` (number, optional): Suspend for N seconds
- `reset` (boolean, optional): Reset suspension

**Returns:** (boolean) True if suspended

---

### Racial Methods

#### `:IsRacialReady(unitID, [skipRange], [skipLua], [skipShouldStop])`
Check if racial is ready.

**Returns:** (boolean)

#### `:IsRacialReadyP(unitID, [skipRange], [skipLua], [skipShouldStop])`
IsRacialReady with pooling.

**Returns:** (boolean)

#### `:AutoRacial(unitID, [skipRange], [skipLua], [skipShouldStop])`
Auto-use racial based on toggles.

**Returns:** (boolean|action) Action if should use

---

### Information Methods

#### `:GetSpellInfo()`
Get spell info.

**Returns:** (string, number, string, number, number, number, number, number, boolean)
- name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon, isHarmful

#### `:GetSpellLink()`
Get spell link.

**Returns:** (string) Spell link

#### `:GetSpellIcon()`
Get spell icon path.

**Returns:** (string) Icon path

#### `:GetSpellTexture([custom])`
Get spell texture.

**Parameters:**
- `custom` (string, optional): Custom texture

**Returns:** (string) Texture path

#### `:GetColoredSpellTexture([custom])`
Get colored texture.

**Parameters:**
- `custom` (string, optional): Custom texture

**Returns:** (string) Colored texture string

#### `:GetItemInfo([custom])`
Get item info.

**Parameters:**
- `custom` (boolean, optional): Return full info

**Returns:** (varies) Item data

#### `:GetItemLink()`
Get item link.

**Returns:** (string) Item link

#### `:GetItemIcon([custom])`
Get item icon.

**Parameters:**
- `custom` (string, optional): Custom icon

**Returns:** (string) Icon path

#### `:GetItemTexture([custom])`
Get item texture.

**Parameters:**
- `custom` (string, optional): Custom texture

**Returns:** (string) Texture path

#### `:GetKeyName()`
Get action key name.

**Returns:** (string) Key from Actions tab

---

## MultiUnits System

MultiUnits provides AoE detection and enemy tracking via nameplates and combat log.

### Accessing MultiUnits

```lua
local MultiUnits = Action.MultiUnits
```

---

### Nameplate Methods

#### `MultiUnits:GetActiveUnitPlates()`
Get active enemy nameplates.

**Returns:** (table) Table of enemy unitIDs

**Usage:**
```lua
local nameplates = MultiUnits:GetActiveUnitPlates()
for unitID in pairs(nameplates) do
    print(unitID)  -- "nameplate1", "nameplate2", etc.
end
```

#### `MultiUnits:GetActiveUnitPlatesAny()`
Get all nameplates (enemy + friendly).

**Returns:** (table) All nameplate unitIDs

#### `MultiUnits:GetActiveUnitPlatesGUID()`
Get enemy nameplates by GUID.

**Returns:** (table) GUID-indexed nameplates (nil in PvP)

---

### AoE Detection Methods

#### `MultiUnits:GetBySpell(spell, [count])`
Count enemies in range of spell.

**Parameters:**
- `spell` (number|table): Spell ID or action object
- `count` (number, optional): Stop counting at N

**Returns:** (number) Enemy count

**Usage:**
```lua
local Swipe = Action.Create({ Type = "Spell", ID = 779 })
local enemies = MultiUnits:GetBySpell(Swipe, 3)
if enemies >= 3 then
    -- 3+ enemies in Swipe range
end
```

#### `MultiUnits:GetByRange(range, [count])`
Count enemies within range.

**Parameters:**
- `range` (number): Max range in yards
- `count` (number, optional): Stop at N

**Returns:** (number) Enemy count

**Usage:**
```lua
local nearbyEnemies = MultiUnits:GetByRange(8)
```

#### `MultiUnits:GetByRangeInCombat(range, [count], [upTTD])`
Count enemies in range and in combat.

**Parameters:**
- `range` (number): Max range
- `count` (number, optional): Stop at N
- `upTTD` (number, optional): Min time-to-die

**Returns:** (number) Enemy count

**Usage:**
```lua
local combatEnemies = MultiUnits:GetByRangeInCombat(5, nil, 6)
-- Enemies within 5yd, in combat, living >6s
```

#### `MultiUnits:GetBySpellIsFocused(unitID, spell, [count])`
Count enemies targeting unitID.

**Parameters:**
- `unitID` (string): Focus target
- `spell` (number|table): Range check spell
- `count` (number, optional): Stop at N

**Returns:** (number, string)
- count (number)
- unitID (string) One enemy targeting

**Usage:**
```lua
local focusing, enemy = MultiUnits:GetBySpellIsFocused("player", Swipe)
if focusing >= 2 then
    -- 2+ enemies attacking player
end
```

---

## Integration with TMW

Action extends TellMeWhen's condition environment (`TMW.CNDT.Env`).

### Globals Injected into TMW

```lua
TMW.CNDT.Env.Action         = _G.Action
TMW.CNDT.Env.Unit           = _G.Action.Unit
TMW.CNDT.Env.Player         = _G.Action.Player
TMW.CNDT.Env.MultiUnits     = _G.Action.MultiUnits
```

**Usage in TMW Conditions:**
```lua
-- TMW icon Lua condition
Unit("target"):HealthPercent() < 20 and Player:ComboPoints() >= 5
```

### TMW API Extensions

Action hooks and extends TMW functions:

#### GCD Fixes (Classic)

For Classic versions, Action implements GCD detection:

```lua
TMW.GetGCD()            -- Returns GCD duration
TMW.OnGCD(duration)     -- Check if duration is GCD
```

#### Spell Cooldown

```lua
TMW.CNDT.Env.CooldownDuration(spell, gcdAsUnusable)
```

Returns spell cooldown, treating GCD as 0 unless `gcdAsUnusable=true`.

#### Item Cooldown

```lua
TMW.CNDT.Env.ItemCooldownDuration(itemID)
```

Returns item cooldown.

---

## Embedded Libraries

Action embeds these libraries (via `LibStub`):

### UI Libraries

- **StdUi** - Standard UI framework
- **LibSharedMedia-3.0** - Media library (fonts, textures, sounds)
- **LibDBIcon-1.0** - Minimap icon management

### Combat Libraries

- **LibRangeCheck-3.0** - Accurate range detection
- **LibSpellLock** - Interrupt/lockout tracking
- **LibAuraTypes** - Aura classification (CC types, etc)
- **LibBossIDs-1.0** - Boss identification
- **LibClassicCasterino** - Classic cast bar detection
- **LibHealComm-4.0** - Incoming heal prediction
- **LibThreatClassic2** - Threat calculation (Classic)

### Data Libraries

- **DRList-1.0** - Diminishing returns tracking
- **LibClassicDurations** - Aura duration tracking (Classic)

### Custom Libraries

- **Toaster** - Notification system
- **PetLibrary** - Pet ability management

**Access:**
```lua
local LibStub = _G.LibStub
local LSM = LibStub("LibSharedMedia-3.0")
local RangeCheck = LibStub("LibRangeCheck-3.0")
```

---

## Constants and Enumerations

### Action.Const

Core constants:

```lua
Action.Const.ADDON_NAME                 -- "ActionUI" or similar
Action.Const.CACHE_DEFAULT_TIMER        -- Default cache duration
Action.Const.CACHE_DEFAULT_TIMER_UNIT   -- Unit cache duration
Action.Const.CACHE_DISABLE              -- Disable caching (debug)
Action.Const.CACHE_MEM_DRIVE            -- Memory-efficient caching

-- Inventory Slots
Action.Const.TRINKET1                   -- 13
Action.Const.TRINKET2                   -- 14
Action.Const.INVSLOT_LAST_EQUIPPED      -- 19

-- Spell IDs
Action.Const.SPELLID_FREEZING_TRAP      -- 3355

-- Death Knight
Action.Const.DEATHKNIGHT_BLOOD          -- "Blood"
Action.Const.DEATHKNIGHT_FROST          -- "Frost"
Action.Const.DEATHKNIGHT_UNHOLY         -- "Unholy"
```

### Action.Enum

Enumerations for spells:

```lua
-- Trigger GCD duration
Action.Enum.TriggerGCD[spellID] = 1.5   -- GCD duration in seconds

-- Spell duration (for auras)
Action.Enum.SpellDuration[spellID] = 18 -- Duration in seconds

-- Projectile speed
Action.Enum.SpellProjectileSpeed[spellID] = 20  -- Yards per second
```

### Action.DateTime

Framework version date:

```lua
Action.DateTime  -- "17.01.2026"
```

---

## Examples

### Basic Rotation Example

```lua
local A = setmetatable({}, { __index = Action })

-- Define abilities
local Moonfire = Action.Create({ Type = "Spell", ID = 8921 })
local Wrath = Action.Create({ Type = "Spell", ID = 5176 })
local Starfire = Action.Create({ Type = "Spell", ID = 2912 })

-- Rotation function
local function Rotation()
    -- Apply Moonfire if missing or refreshable
    if Moonfire:IsReady("target") and
       Unit("target"):HasDeBuffsRefreshable(8921, 5.4, "player") then
        return Moonfire
    end

    -- Use Starfire during Eclipse
    if Starfire:IsReady("target") and
       Player:HasBuffs(48517) then  -- Eclipse (Solar)
        return Starfire
    end

    -- Default: Wrath
    if Wrath:IsReady("target") then
        return Wrath
    end
end

-- TMW integration
A[1] = function()
    if Unit("player"):IsStealthed() or not Unit("target"):Exists() then
        return
    end

    return Rotation()
end
```

### AoE Detection Example

```lua
local Swipe = Action.Create({ Type = "Spell", ID = 779 })
local Thrash = Action.Create({ Type = "Spell", ID = 77758 })

local function AOERotation()
    local enemies = Action.MultiUnits:GetBySpell(Swipe)

    -- AoE mode enabled and 3+ enemies
    if Action.GetToggle(2, "AoE") and enemies >= 3 then
        if Thrash:IsReady("target") then
            return Thrash
        end

        if Swipe:IsReady("target") then
            return Swipe
        end
    end
end
```

### Burst Management Example

```lua
local Bloodlust = Action.Create({ Type = "Spell", ID = 2825 })
local TigersFury = Action.Create({ Type = "Spell", ID = 50213 })

local function UseCooldowns()
    if not Action.BurstIsON("target") then
        return  -- Burst disabled
    end

    -- Use Tiger's Fury on cooldown during burst
    if TigersFury:IsReady() then
        return TigersFury
    end
end
```

### Interrupt Example

```lua
local Kick = Action.Create({ Type = "Spell", ID = 1766 })

local function Interrupts()
    if not Action.InterruptIsON("Interrupt") then
        return  -- Interrupts disabled
    end

    if Action.InterruptIsValid("target", "Interrupt") then
        if Kick:IsReady("target") then
            return Kick
        end
    end
end
```

### Healing Example

```lua
local Rejuvenation = Action.Create({ Type = "Spell", ID = 774 })
local Regrowth = Action.Create({ Type = "Spell", ID = 8936 })

local function HealingRotation()
    -- Iterate friendly team
    for _, unitID in pairs(Action.FriendlyTeam():GetCache()) do
        local unit = Unit(unitID)

        -- Emergency Regrowth
        if unit:HealthPercent() < 40 and Regrowth:IsReady(unitID) then
            return Regrowth
        end

        -- Maintain Rejuvenation
        if unit:HealthPercent() < 90 and
           unit:HasDeBuffsRefreshable(774, 5.4, "player") and
           Rejuvenation:IsReady(unitID) then
            return Rejuvenation
        end
    end
end
```

### Queue System Example

```lua
-- Create macro:
-- /run Action.MacroQueue("Eviscerate", { Priority = 1, CP = 5 })

local Eviscerate = Action.Create({ Type = "Spell", ID = 2098 })

local function Finishers()
    -- Queue system will force Eviscerate when ready
    if Eviscerate:IsReady("target") and Player:ComboPoints() >= 5 then
        return Eviscerate
    end
end
```

### Tier Set Bonus Example

```lua
-- Register tier
Player:AddTier("T19", {138327, 138329, 138332, 138334, 138338})

local function Rotation()
    local has4pc = Player:HasTier("T19", 4)

    if has4pc then
        -- Modified rotation with 4-piece bonus
    else
        -- Standard rotation
    end
end
```

---

## Appendix: Version Compatibility

Action supports multiple WoW versions through build detection:

```lua
if Action.BuildToC >= 50000 then
    -- Retail (Shadowlands+)
elseif Action.BuildToC >= 40000 then
    -- Cataclysm
elseif Action.BuildToC >= 30000 then
    -- WotLK
elseif Action.BuildToC >= 20000 then
    -- TBC
else
    -- Classic (Vanilla)
end
```

Build-specific code handles:
- API differences (UnitAura, power types, etc.)
- Spell/aura lists
- GCD calculation
- Class mechanics

---

## Appendix: Performance Optimization

### Caching Best Practices

1. **Avoid unnecessary calls:** Cache is automatic but still costs memory
2. **Use specific cache timers:** Override default for expensive operations
3. **Disable in debug:** Set `CONST.CACHE_DISABLE = true` for testing
4. **Clear on zone change:** Framework auto-clears on PLAYER_ENTERING_WORLD

### Memory Management

- **MultiUnits:** Auto-wipes on combat end
- **Aura tracking:** Cleaned on PLAYER_ENTERING_WORLD
- **Team cache:** Refreshed on group changes

### Common Pitfalls

- **Don't spam Unit() creation:** Reuse unit objects
- **Avoid nested loops:** Use Team iteration methods
- **Check existence first:** `Unit:Exists()` before expensive calls
- **Use action object caching:** Create once, reuse

---

**End of Documentation**

*Generated from Textfiles framework dated 17.01.2026*
*This documentation covers core API. Individual rotations may extend with custom functions.*
