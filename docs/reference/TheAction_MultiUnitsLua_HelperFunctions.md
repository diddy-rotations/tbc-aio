# TheAction `MultiUnits.lua` helper functions

This document covers the public helpers exposed by `../action_mop/Modules/Engines/MultiUnits.lua`.

`Action.MultiUnits` is a lightweight engine used to reason about **multiple nearby units** (primarily via **nameplates**, and for some ranged specializations additionally via **CLEU-based "active enemies" tracking**).

Notes:
- Most functions operate on the set of currently active enemy nameplates (`NAME_PLATE_UNIT_ADDED/REMOVED`). If nameplates are disabled or the unit has no active nameplate, it will not be counted.
- Most counting helpers intentionally **skip totems** via `Action.Unit(namePlateUnitID):IsTotem()`.
- Several helpers are wrapped with `Action.MakeFunctionCachedDynamic(...)`, so values may be cached briefly within a frame/update window.

---

## `:GetActiveUnitPlates()`

**Signature**
- `plates = A.MultiUnits:GetActiveUnitPlates()`

**Parameters**
- None

**Return Values**
- `plates` (`table`): active **enemy** nameplate unit tokens.
  - Keys are unitIDs like `"nameplate1"`, `"nameplate2"`, ...
  - Values are the corresponding `"nameplateXtarget"` token (used internally; most callers just iterate keys).

**Logic Explanation**
- Backed by the nameplate add/remove event handlers.
- Enemy-only (uses `UnitCanAttack("player", unitID)` in the nameplate add handler).

**Usage Example**
```lua
for unitID in pairs(A.MultiUnits:GetActiveUnitPlates()) do
    -- unitID is e.g. "nameplate3"
end
```

---

## `:GetActiveUnitPlatesAny()`

**Signature**
- `platesAny = A.MultiUnits:GetActiveUnitPlatesAny()`

**Parameters**
- None

**Return Values**
- `platesAny` (`table`): active nameplates for **enemies + friendlies**.

**Logic Explanation**
- Populated by the same nameplate add/remove handlers.
- Includes friendly nameplates in addition to enemy ones.

**Usage Example**
```lua
for unitID in pairs(A.MultiUnits:GetActiveUnitPlatesAny()) do
    -- unitID is e.g. "nameplate7"
end
```

---

## `:GetActiveUnitPlatesGUID()`

**Signature**
- `platesByGUID = A.MultiUnits:GetActiveUnitPlatesGUID()`

**Parameters**
- None

**Return Values**
- `platesByGUID` (`table`): maps `unitGUID -> "nameplateXtarget"` for active **enemy** nameplates, or an empty table.

**Logic Explanation**
- Populated on nameplate add/remove.
- Disabled in PvP zones (`A.Zone == "pvp"`): GUID mapping is only maintained outside PvP.

**Usage Example**
```lua
local platesByGUID = A.MultiUnits:GetActiveUnitPlatesGUID()
-- platesByGUID["Creature-0-..."] -> "nameplate4target"
```

---

## `:GetBySpell(spell, count)`

**Signature**
- `n = A.MultiUnits:GetBySpell(spell, count)`

**Parameters**
- `spell` (`number|table`):
  - `table`: an Action object that supports `:IsInRange(unitID)`.
  - `number`: a spell identifier used by `Action.IsInRange(spell, unitID)`.
- `count` (`number|nil`): optional early-exit threshold; stops counting once `n >= count`.

**Return Values**
- `n` (`number`): number of enemy nameplates in spell range (excluding totems).

**Logic Explanation**
- Iterates enemy nameplates and checks range via:
  - `spell:IsInRange(unitID)` when `spell` is an Action object, otherwise
  - `Action.IsInRange(spell, unitID)` for numeric spell IDs.

**Usage Example**
```lua
if A.MultiUnits:GetBySpell(A.Blizzard, 3) >= 3 then
    -- at least 3 enemies are in Blizzard range
end
```

---

## `:GetBySpellIsFocused(unitID, spell, count)`

**Signature**
- `n, lastPlate = A.MultiUnits:GetBySpellIsFocused(unitID, spell, count)`

**Parameters**
- `unitID` (`string`): unit token being focused (e.g., `"player"`, `"party1"`).
- `spell` (`number|table`): same meaning as in `:GetBySpell`.
- `count` (`number|nil`): optional early-exit threshold.

**Return Values**
- `n` (`number`): number of enemy nameplates in spell range whose target is `unitID`.
- `lastPlate` (`string`): the last matching nameplate unit token, or `"none"`.

**Logic Explanation**
- Checks both:
  - spell range (same rules as `:GetBySpell`), and
  - `UnitIsUnit(namePlateUnitID .. "target", unitID)`.

**Usage Example**
```lua
local n = select(1, A.MultiUnits:GetBySpellIsFocused("player", A.Counterspell))
if n >= 2 then
    -- 2+ enemies in Counterspell range are targeting the player
end
```

---

## `:GetByRange(range, count)`

**Signature**
- `n = A.MultiUnits:GetByRange(range, count)`

**Parameters**
- `range` (`number|nil`): distance in yards; if `nil`, counts all active enemy nameplates (still excludes totems).
- `count` (`number|nil`): optional early-exit threshold.

**Return Values**
- `n` (`number`): number of enemy nameplates within range.

**Logic Explanation**
- Counts enemy nameplates where `Action.Unit(namePlateUnitID):CanInterract(range)` is true.
- Fallback: if none were counted from nameplates but `"target"` is in range, increments count by 1 (covers cases where target has no active nameplate).
- Cached dynamically via `Action.MakeFunctionCachedDynamic`.

**Usage Example**
```lua
if A.MultiUnits:GetByRange(8) >= 3 then
    -- 3+ enemies within 8 yards
end
```

---

## `:GetByRangeInCombat(range, count, upTTD)`

**Signature**
- `n = A.MultiUnits:GetByRangeInCombat(range, count, upTTD)`

**Parameters**
- `range` (`number|nil`): interact/range check in yards.
- `count` (`number|nil`): optional early-exit threshold.
- `upTTD` (`number|nil`): optional minimum `TimeToDie()` requirement.

**Return Values**
- `n` (`number`): number of enemy nameplates in range and in combat (and optionally with TTD >= `upTTD`).

**Logic Explanation**
- Filters by:
  - `Action.Unit(unitID):CombatTime() > 0`
  - range via `:CanInterract(range)` (if provided)
  - `:TimeToDie() >= upTTD` (if provided)
  - excludes totems
- Fallback: counts `"target"` if it is in combat and in range.
- Cached dynamically.

**Usage Example**
```lua
if A.MultiUnits:GetByRangeInCombat(10, 4) >= 4 then
    -- 4+ enemies within 10 yards and currently in combat
end
```

---

## `:GetByRangeCasting(range, count, kickAble, spells)`

**Signature**
- `n = A.MultiUnits:GetByRangeCasting(range, count, kickAble, spells)`

**Parameters**
- `range` (`number|nil`): interact/range check in yards.
- `count` (`number|nil`): optional early-exit threshold.
- `kickAble` (`boolean|nil`): if `true`, only counts casts that are interruptible.
- `spells` (`table|number|string|nil`): optional cast filter:
  - `table`: list of spell IDs (`number`) and/or cast names (`string`)
  - `number`: single spellID
  - `string`: single cast name

**Return Values**
- `n` (`number`): number of enemies casting in range (and optionally interruptible / matching the spell filter).

**Logic Explanation**
- Uses `Action.Unit(namePlateUnitID):IsCasting()` to detect casts and obtain `(castName, ..., notInterruptable, spellID)`.
- Applies:
  - range check (if provided)
  - interruptible check (if `kickAble`)
  - spell filter (if provided)
- Note: explicitly allows counting casts even if the caster is a totem ("totems can casting" comment), but later logic does not exclude totems here; the totem exclusion is not applied in this function.
- Cached dynamically.

**Usage Example**
```lua
-- Count interruptible casts within 30 yards:
if A.MultiUnits:GetByRangeCasting(30, 2, true) >= 2 then
    -- 2+ interruptible casters nearby
end
```

---

## `:GetByRangeTaunting(range, count, upTTD)`

**Signature**
- `n = A.MultiUnits:GetByRangeTaunting(range, count, upTTD)`

**Parameters**
- `range` (`number|nil`)
- `count` (`number|nil`)
- `upTTD` (`number|nil`)

**Return Values**
- `n` (`number`): number of enemies that look like valid taunt targets (for tanking logic).

**Logic Explanation**
- Counts enemies that are:
  - in combat
  - not players
  - not bosses
  - whose current target is not a tank
  - in range / TTD filters (if provided)
  - excluding totems
- Cached dynamically.

**Usage Example**
```lua
if A.MultiUnits:GetByRangeTaunting(10, 1) > 0 then
    -- there is at least 1 nearby non-boss NPC targeting a non-tank
end
```

---

## `:GetByRangeMissedDoTs(range, count, deBuffs, upTTD)`

**Signature**
- `n = A.MultiUnits:GetByRangeMissedDoTs(range, count, deBuffs, upTTD)`

**Parameters**
- `range` (`number|nil`)
- `count` (`number|nil`)
- `deBuffs` (`table|number|string`): debuff(s) passed to `Unit(unitID):HasDeBuffs(deBuffs, true)`.
- `upTTD` (`number|nil`)

**Return Values**
- `n` (`number`): enemies in combat (and in range/TTD filters) that are **missing** the specified debuff(s).

**Logic Explanation**
- Filters to:
  - PvE: any enemy
  - PvP: only counts enemy players (`A.IsInPvP` gate)
- Requires `Unit(unitID):HasDeBuffs(deBuffs, true) == 0`.
- Excludes totems.
- Cached dynamically.

**Usage Example**
```lua
if A.MultiUnits:GetByRangeMissedDoTs(40, 1, A.FrostFever.ID, 6) > 0 then
    -- at least one enemy in range/combat/TTD is missing Frost Fever
end
```

---

## `:GetByRangeAppliedDoTs(range, count, deBuffs, upTTD)`

**Signature**
- `n = A.MultiUnits:GetByRangeAppliedDoTs(range, count, deBuffs, upTTD)`

**Parameters**
- `range` (`number|nil`)
- `count` (`number|nil`)
- `deBuffs` (`table|number|string`)
- `upTTD` (`number|nil`)

**Return Values**
- `n` (`number`): enemies in combat (and in range/TTD filters) that **have** the specified debuff(s).

**Logic Explanation**
- Requires `Unit(unitID):HasDeBuffs(deBuffs, true) > 0`.
- Excludes totems.
- Cached dynamically.

**Usage Example**
```lua
local n = A.MultiUnits:GetByRangeAppliedDoTs(40, nil, {A.Corruption.ID, A.Immolate.ID})
```

---

## `:GetByRangeIsFocused(unitID, range, count)`

**Signature**
- `n, lastPlate = A.MultiUnits:GetByRangeIsFocused(unitID, range, count)`

**Parameters**
- `unitID` (`string`)
- `range` (`number|nil`)
- `count` (`number|nil`)

**Return Values**
- `n` (`number`)
- `lastPlate` (`string`): last matching nameplate unit token, or `"none"`.

**Logic Explanation**
- Counts enemy nameplates whose target is `unitID` and that pass the range check.
- Excludes totems.
- Cached dynamically.

**Usage Example**
```lua
local focused, last = A.MultiUnits:GetByRangeIsFocused("player", 40, 1)
if focused > 0 then
    -- someone in range is targeting the player; `last` is a nameplate unitID
end
```

---

## `:GetByRangeAreaTTD(range)`

**Signature**
- `avgTTD = A.MultiUnits:GetByRangeAreaTTD(range)`

**Parameters**
- `range` (`number|nil`)

**Return Values**
- `avgTTD` (`number`): average `TimeToDie()` of enemies in range, or `0` if none.

**Logic Explanation**
- Sums `Unit(unitID):TimeToDie()` across enemy nameplates in range, divides by count.
- Excludes totems.
- Cached dynamically.

**Usage Example**
```lua
local avgTTD = A.MultiUnits:GetByRangeAreaTTD(10)
```

---

## `:GetActiveEnemies(timer, skipClear)`

**Signature**
- `n = A.MultiUnits:GetActiveEnemies(timer, skipClear)`

**Parameters**
- `timer` (`number|nil`): seconds window for counting CLEU "active enemies" (default `5`).
- `skipClear` (`boolean|nil`): if `true`, does not clear old CLEU destinations while counting.

**Return Values**
- `n` (`number`): best estimate of how many enemies are currently being cleaved/hit in the window.

**Logic Explanation**
- Intended for ranged specs (`A.IamRanger`); prints an error if used otherwise.
- If CLEU tracking has data and current `"target"` is an enemy:
  - Finds a source GUID that recently hit the current target, counts how many distinct destination GUIDs were hit within the `timer` window, and returns the **highest** such count.
- Fallback: if result is `<= 0`, uses `:GetByRangeInCombat(nil, 10)` as a backup.
- Cached dynamically with `CONST.CACHE_DEFAULT_TIMER_MULTIUNIT_CLEU`.

**Usage Example**
```lua
-- Ranged specs only:
if A.MultiUnits:GetActiveEnemies(5) >= 3 then
    -- treat as 3+ active targets
end
```
