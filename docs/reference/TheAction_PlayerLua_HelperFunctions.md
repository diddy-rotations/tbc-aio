# TheAction `Player.lua` helper functions

This document covers the public helper methods exposed by `../action_mop/Modules/Engines/Player.lua` through the singleton `Action.Player` (`A.Player`).

Notes:
- `A.Player` always represents unitID `"player"` (`A.Player.UnitID` is hardcoded to `"player"`).
- Several helpers are **event-driven** and depend on internal state updated by `Action.Listener` handlers (movement, casting timestamps, behind/in-front heuristics, tier/bag/inventory tracking).
- Resource helpers are grouped by the WoW `Enum.PowerType` index. Some "predicted" variants return `-1` when the underlying regen API returns `0` (meaning "prediction not supported/available").

## Stance / Form

### `:IsStance(x)`

**Signature**
- `isStance = A.Player:IsStance(x)`

**Parameters**
- `x` (`number`): stance/form index (see `:GetStance()` for the cross-class mapping).

**Return Values**
- `isStance` (`boolean`): `true` if the cached stance/form equals `x`.

**Logic Explanation**
- Compares the cached `Data.Stance` (updated from `UPDATE_SHAPESHIFT_FORM*`) to `x`.

**Intended usage**
- Form/stance gating (warrior stances, druid forms, rogue stealth form index, etc.).

**Usage Example**
```lua
if A.Player:IsStance(2) then
    -- Class-dependent meaning (e.g., Cat Form for druid, Defensive Stance for warrior).
end
```

### `:GetStance()`

**Signature**
- `stance = A.Player:GetStance()`

**Return Values**
- `stance` (`number`): stance/form index (cross-class).

**Logic Explanation**
- Returns the cached `Data.Stance` populated by `GetShapeshiftForm()` on relevant events.

**Intended usage**
- Debugging, UI, or when you need the raw stance index and will compare it yourself.

**Usage Example**
```lua
local stance = A.Player:GetStance()
```

## Movement / Position heuristics

### `:IsFalling()`

**Signature**
- `isFalling, fallingFor = A.Player:IsFalling()`

**Return Values**
- `isFalling` (`boolean`): `true` only when `IsFalling()` has been true for more than ~1.7s (attempts to ignore short jumps).
- `fallingFor` (`number`): seconds since falling started (0 when not falling or below the threshold).

**Logic Explanation**
- Tracks the first timestamp `IsFalling()` became true and only reports falling after 1.7 seconds.
- Resets its internal timestamp when `IsFalling()` becomes false.

**Intended usage**
- More stable "actually falling" detection (e.g., avoid using ground-only spells mid-fall).

**Usage Example**
```lua
local isFalling = A.Player:IsFalling()
```

### `:GetFalling()`

**Signature**
- `fallingFor = A.Player:GetFalling()`

**Return Values**
- `fallingFor` (`number`): seconds returned by `select(2, A.Player:IsFalling())`.

**Logic Explanation**
- Convenience wrapper around `:IsFalling()`.

**Usage Example**
```lua
if A.Player:GetFalling() > 0 then
    -- Player is falling (past the anti-jump threshold).
end
```

### `:IsMoving()`

**Signature**
- `isMoving = A.Player:IsMoving()`

**Return Values**
- `isMoving` (`boolean`): `true` if a `PLAYER_STARTED_MOVING` event has occurred and movement has not been stopped.

**Logic Explanation**
- Uses `Data.TimeStampMoving` / `Data.TimeStampStaying` timestamps updated by move start/stop events.

**Intended usage**
- Quick "moving now" checks for cast restrictions, etc.

**Usage Example**
```lua
if A.Player:IsMoving() then
    -- Prefer instants.
end
```

### `:IsMovingTime()`

**Signature**
- `movingFor = A.Player:IsMovingTime()`

**Return Values**
- `movingFor` (`number`): seconds since the last `PLAYER_STARTED_MOVING` (0 if not moving).

**Logic Explanation**
- `0` when not moving, otherwise `TMW.time - Data.TimeStampMoving`.

**Usage Example**
```lua
if A.Player:IsMovingTime() > 1.0 then
    -- Moving continuously for at least 1s.
end
```

### `:IsStaying()`

**Signature**
- `isStaying = A.Player:IsStaying()`

**Return Values**
- `isStaying` (`boolean`): `true` if the last movement event was `PLAYER_STOPPED_MOVING`.

**Logic Explanation**
- Uses `Data.TimeStampStaying` (0 while moving).

**Usage Example**
```lua
if A.Player:IsStaying() then
    -- Player is stationary.
end
```

### `:IsStayingTime()`

**Signature**
- `stayingFor = A.Player:IsStayingTime()`

**Return Values**
- `stayingFor` (`number`): seconds since `PLAYER_STOPPED_MOVING` (0 if currently moving).

**Logic Explanation**
- `0` when moving, otherwise `TMW.time - Data.TimeStampStaying`.

**Usage Example**
```lua
if A.Player:IsStayingTime() > 2.5 then
    -- Standing still for a while.
end
```

## Auto-attacks / facing heuristics

### `:IsShooting()`

**Signature**
- `isShooting = A.Player:IsShooting()`

**Return Values**
- `isShooting` (`boolean`): true while auto-shot is active (tracked via `START_AUTOREPEAT_SPELL` / `STOP_AUTOREPEAT_SPELL`).

**Logic Explanation**
- Returns the internal flag `Data.AutoShootActive`.

**Usage Example**
```lua
if A.Player:IsShooting() then
    -- Auto Shot / Shoot is running.
end
```

### `:GetSwingShoot()`

**Signature**
- `remains = A.Player:GetSwingShoot()`

**Return Values**
- `remains` (`number`): seconds until the next auto-shot tick, or `0`.

**Logic Explanation**
- Uses `Data.AutoShootNextTick` updated on `UNIT_SPELLCAST_SUCCEEDED` for known shoot spells.

**Usage Example**
```lua
local shootIn = A.Player:GetSwingShoot()
```

### `:IsAttacking()`

**Signature**
- `isAttacking = A.Player:IsAttacking()`

**Return Values**
- `isAttacking` (`boolean`): true while melee auto-attack is active (tracked via `PLAYER_ENTER_COMBAT` / `PLAYER_LEAVE_COMBAT`).

**Logic Explanation**
- Returns the internal flag `Data.AttackActive`.

**Usage Example**
```lua
if not A.Player:IsAttacking() then
    -- You may want to start auto attack.
end
```

### `:IsBehind(x)`

**Signature**
- `isBehind = A.Player:IsBehind(x)`

**Parameters**
- `x` (`number|nil`): seconds window (defaults to `2.5`).

**Return Values**
- `isBehind` (`boolean`): heuristic "player is behind target".

**Logic Explanation**
- Uses UI error messages (`SPELL_FAILED_NOT_BEHIND` / `SPELL_FAILED_NOT_INFRONT`) as a signal that you are *not* properly positioned.
- The timestamp is updated when the error occurs; if no error has occurred for `x` seconds, returns true.

**Intended usage**
- Very lightweight positioning heuristic for rotations that occasionally need "behind" logic, when you are already pressing abilities that can trigger those UI errors.

**Usage Example**
```lua
if A.Player:IsBehind() then
    -- Likely behind the target (no recent "not behind/in front" error).
end
```

### `:IsBehindTime()`

**Signature**
- `sinceError = A.Player:IsBehindTime()`

**Return Values**
- `sinceError` (`number`): seconds since the last "not behind/in front" UI error was seen.

**Logic Explanation**
- `TMW.time - Data.PlayerBehind`.

**Usage Example**
```lua
local secondsSinceNotBehind = A.Player:IsBehindTime()
```

### `:IsPetBehind(x)`

**Signature**
- `petIsBehind = A.Player:IsPetBehind(x)`

**Parameters**
- `x` (`number|nil`): seconds window (defaults to `2.5`).

**Return Values**
- `petIsBehind` (`boolean`): heuristic "pet is behind target".

**Logic Explanation**
- Tracks `ERR_PET_SPELL_NOT_BEHIND` UI errors; if no error for `x` seconds, returns true.

**Usage Example**
```lua
if A.Player:IsPetBehind() then
    -- Pet likely positioned correctly.
end
```

### `:IsPetBehindTime()`

**Signature**
- `sinceError = A.Player:IsPetBehindTime()`

**Return Values**
- `sinceError` (`number`): seconds since the last pet "not behind" error was seen.

**Usage Example**
```lua
local petBehindErrorAge = A.Player:IsPetBehindTime()
```

### `:TargetIsBehind(x)`

**Signature**
- `targetIsBehind = A.Player:TargetIsBehind(x)`

**Parameters**
- `x` (`number|nil`): seconds window (defaults to `2.5`).

**Return Values**
- `targetIsBehind` (`boolean`): heuristic "target is behind the player" (i.e., not in front).

**Logic Explanation**
- Uses the `SPELL_FAILED_UNIT_NOT_INFRONT` UI error as a signal.
- Tracks the GUID of the target that caused the error; if the target changed, it clears the timestamp.
- Returns true while `TMW.time <= Data.TargetBehind + x`.

**Usage Example**
```lua
if A.Player:TargetIsBehind() then
    -- Target is (probably) not in front of you right now.
end
```

### `:TargetIsBehindTime()`

**Signature**
- `sinceError = A.Player:TargetIsBehindTime()`

**Return Values**
- `sinceError` (`number`): seconds since the last target "not in front" error for the current target GUID.

**Usage Example**
```lua
local tBehindAge = A.Player:TargetIsBehindTime()
```

## Character state

### `:IsMounted()`

**Signature**
- `isMounted = A.Player:IsMounted()`

**Return Values**
- `isMounted` (`boolean`): true for real mounts; attempts to exclude some class "mounted-like" auras (e.g., druid Travel Form).

**Logic Explanation**
- `IsMounted()` AND (no class exclusion list OR the excluded aura list is not present on the player).

**Usage Example**
```lua
if A.Player:IsMounted() then
    -- Rotation should usually stop.
end
```

### `:IsSwimming()`

**Signature**
- `isSwimming = A.Player:IsSwimming()`

**Return Values**
- `isSwimming` (`boolean`): true if `IsSwimming()` OR `IsSubmerged()`.

**Usage Example**
```lua
if A.Player:IsSwimming() then
    -- Apply swimming-specific logic.
end
```

### `:IsStealthed()`

**Signature**
- `isStealthed = A.Player:IsStealthed()`

**Return Values**
- `isStealthed` (`boolean`): true if any supported stealth state is detected.

**Logic Explanation**
- True if:
  - WoW `IsStealthed()` is true, OR
  - Night Elf `Shadowmeld` buff is present, OR
  - a class-specific stealth aura (e.g., Rogue Stealth/Vanish ranks, Druid Prowl ranks) is present.

**Usage Example**
```lua
if A.Player:IsStealthed() then
    -- Opener logic.
end
```

## Casting (player only)

### `:IsCasting()`

**Signature**
- `castNameOrNil = A.Player:IsCasting()`

**Return Values**
- `castNameOrNil` (`string|nil`): cast name if the player is casting a normal (non-channel) spell, otherwise `nil`.

**Logic Explanation**
- Uses `Action.Unit("player"):IsCasting()` and returns the cast name only when `isChannel` is false.

**Usage Example**
```lua
if A.Player:IsCasting() then
    -- Player is hard-casting.
end
```

### `:IsChanneling()`

**Signature**
- `channelNameOrNil = A.Player:IsChanneling()`

**Return Values**
- `channelNameOrNil` (`string|nil`): channel name if the player is channeling, otherwise `nil`.

**Logic Explanation**
- Uses `Action.Unit("player"):IsCasting()` and returns the cast name only when `isChannel` is true.

**Usage Example**
```lua
if A.Player:IsChanneling() then
    -- Player is channeling.
end
```

### `:CastTimeSinceStart()`

**Signature**
- `seconds = A.Player:CastTimeSinceStart()`

**Return Values**
- `seconds` (`number`): seconds since the last cast-start event was recorded for the player.

**Logic Explanation**
- `Data.TimeStampCasting` is updated by `UNIT_SPELLCAST_START` and `UNIT_SPELLCAST_CHANNEL_START` for `"player"`.

**Usage Example**
```lua
local sinceCastStart = A.Player:CastTimeSinceStart()
```

### `:CastRemains(spellID)`

**Signature**
- `remains = A.Player:CastRemains(spellID)`

**Parameters**
- `spellID` (`number|nil`): optional spellID to validate against the current cast/channel (passed through to `Unit:IsCastingRemains`).

**Return Values**
- `remains` (`number`): remaining cast/channel time in seconds (0 if not casting).

**Logic Explanation**
- Delegates to `Action.Unit("player"):IsCastingRemains(spellID)`.

**Usage Example**
```lua
if A.Player:CastRemains() > 0.2 then
    -- Consider not interrupting your own cast.
end
```

### `:CastCost()`

**Signature**
- `cost = A.Player:CastCost()`

**Return Values**
- `cost` (`number`): the (uncached) power cost of the spell currently being cast/channelled, or `0` if not casting.

**Logic Explanation**
- Reads the current cast spellID via `Action.Unit("player"):IsCasting()`, then queries `Action.GetSpellPowerCost(spellID)`.

**Usage Example**
```lua
local currentCastCost = A.Player:CastCost()
```

### `:CastCostCache()`

**Signature**
- `cost = A.Player:CastCostCache()`

**Return Values**
- `cost` (`number`): the cached power cost of the spell currently being cast/channelled, or `0` if not casting.

**Logic Explanation**
- Same as `:CastCost()`, but calls `Action.GetSpellPowerCostCache(spellID)`.

**Usage Example**
```lua
local currentCastCost = A.Player:CastCostCache()
```

## Auras / Glyphs / Totems

### `:CancelBuff(buffName)`

**Signature**
- `A.Player:CancelBuff(buffName)`

**Parameters**
- `buffName` (`string`): the buff name to cancel (as accepted by `CancelSpellByName`).

**Return Values**
- (no return)

**Logic Explanation**
- If `not InCombatLockdown()` OR `issecure()` then calls `CancelSpellByName(buffName)`.
- Does nothing in normal combat lockdown conditions.

**Intended usage**
- Utility/automation for out-of-combat buff toggles (e.g., cancel procs for testing).

**Usage Example**
```lua
A.Player:CancelBuff("Slow Fall")
```

### `:GetBuffsUnitCount(...)`

**Signature**
- `units, found = A.Player:GetBuffsUnitCount(...)`

**Parameters**
- `...` (`number|string|table`): one or more aura identifiers:
  - `number`: spellID (converted via `Action.GetSpellInfo` to a name),
  - `string`: spell name,
  - `table`: an Action object (uses `aura:Info()`).

**Return Values**
- `units` (`number`): total number of units currently counted as having *any* of the provided buffs applied by the player (sum of per-buff counters).
- `found` (`number`): how many of the provided buffs had a non-zero unit count.

**Logic Explanation**
- Uses CLEU (`COMBAT_LOG_EVENT_UNFILTERED`) to maintain `Data.AuraBuffUnitCount[spellName]`.
- Summation across the requested auras.

**Intended usage**
- Multi-target logic such as "how many active buff applications do I have out".

**Usage Example**
```lua
local unitsWithMyBuff, buffsFound = A.Player:GetBuffsUnitCount(12345, A.SomeBuffAction)
```

### `:GetDeBuffsUnitCount(...)`

**Signature**
- `units, found = A.Player:GetDeBuffsUnitCount(...)`

**Parameters**
- `...` (`number|string|table`): one or more debuff identifiers (spellID, name, or Action object).

**Return Values**
- `units` (`number`): total number of units currently counted as having *any* of the provided debuffs applied by the player.
- `found` (`number`): how many of the provided debuffs had a non-zero unit count.

**Logic Explanation**
- Uses CLEU to maintain `Data.AuraDeBuffUnitCount[spellName]`.

**Usage Example**
```lua
local unitsWithMyDots = A.Player:GetDeBuffsUnitCount("Rip", "Rake")
```

### `:HasGlyph(spell)`

**Signature**
- `has = A.Player:HasGlyph(spell)`

**Parameters**
- `spell` (`number|string`): glyphID, spellID, or spellName (for glyph spell, not the base ability spell).

**Return Values**
- `has` (`boolean|nil`): true if the glyph is present in the cached glyph table.

**Logic Explanation**
- Uses `Data.Glyphs` populated by `Data.UpdateGlyphs()` (WotLK through BFA build ranges in this code).

**Usage Example**
```lua
if A.Player:HasGlyph(1234) then
    -- Glyph is installed.
end
```

### `:GetTotemInfo(i)`

**Signature**
- `haveTotem, totemName, startTime, duration, icon = A.Player:GetTotemInfo(i)`

**Parameters**
- `i` (`number`): totem slot index (1..4).

**Return Values**
- Exact returns of WoW `GetTotemInfo(i)`:
  - `haveTotem` (`boolean`)
  - `totemName` (`string|nil`)
  - `startTime` (`number`)
  - `duration` (`number`)
  - `icon` (`number`)

**Usage Example**
```lua
local haveTotem = A.Player:GetTotemInfo(1)
```

### `:GetTotemTimeLeft(i)`

**Signature**
- `seconds = A.Player:GetTotemTimeLeft(i)`

**Parameters**
- `i` (`number`): totem slot index (1..4).

**Return Values**
- `seconds` (`number`): exact return of WoW `GetTotemTimeLeft(i)`.

**Usage Example**
```lua
if A.Player:GetTotemTimeLeft(1) < 3 then
    -- Consider refreshing a totem.
end
```

## Stats / GCD

### `:CritChancePct()`

**Signature**
- `critPct = A.Player:CritChancePct()`

**Return Values**
- `critPct` (`number`): value returned by WoW `GetCritChance()`.

**Usage Example**
```lua
local crit = A.Player:CritChancePct()
```

### `:HastePct()`

**Signature**
- `hastePct = A.Player:HastePct()`

**Return Values**
- `hastePct` (`number`): value returned by WoW `GetHaste()`.

**Usage Example**
```lua
local haste = A.Player:HastePct()
```

### `:SpellHaste()`

**Signature**
- `mult = A.Player:SpellHaste()`

**Return Values**
- `mult` (`number`): `1 / (1 + hastePct/100)` (a cast-time multiplier).

**Intended usage**
- Multiply a base cast time by this to apply haste scaling.

**Usage Example**
```lua
local hastedCastTime = 2.0 * A.Player:SpellHaste()
```

### `:Execute_Time(spellID)`

**Signature**
- `seconds = A.Player:Execute_Time(spellID)`

**Parameters**
- `spellID` (`number`): spellID to query cast time for.

**Return Values**
- `seconds` (`number`): `max(GCD, cast_time(spellID))`.

**Logic Explanation**
- Reads `Action.GetGCD()` and `Action.Unit("player"):CastTime(spellID)` and returns the larger.

**Intended usage**
- APL-style "execute time" (how long the next action will lock you).

**Usage Example**
```lua
local executeTime = A.Player:Execute_Time(A.Fireball.ID)
```

### `:GCDRemains()`

**Signature**
- `seconds = A.Player:GCDRemains()`

**Return Values**
- `seconds` (`number`): value returned by `Action.GetCurrentGCD()`.

**Usage Example**
```lua
if A.Player:GCDRemains() == 0 then
    -- Ready to cast a GCD ability.
end
```

## Swing timers (melee/ranged)

### `:GetSwing(inv)`

**Signature**
- `duration = A.Player:GetSwing(inv)`

**Parameters**
- `inv` (`number|nil`): inventory slot selector:
  - `1` = mainhand, `2` = offhand, `3` = ranged,
  - `4` = max(mainhand, offhand),
  - `5` = max(mainhand, offhand, ranged),
  - or a raw inventory slot constant such as `CONST.INVSLOT_MAINHAND`.

**Return Values**
- `duration` (`number`): swing duration in seconds (from `Env.SwingDuration`).

**Usage Example**
```lua
local mhSwing = A.Player:GetSwing(1)
```

### `:GetSwingMax(inv)`

**Signature**
- `duration = A.Player:GetSwingMax(inv)`

**Parameters**
- `inv` (`number|nil`): same selector as `:GetSwing(inv)`.

**Return Values**
- `duration` (`number`): the last recorded swing duration from `TMW.COMMON.SwingTimerMonitor.SwingTimers`.

**Usage Example**
```lua
local lastSwing = A.Player:GetSwingMax(CONST.INVSLOT_MAINHAND)
```

### `:GetSwingStart(inv)`

**Signature**
- `startTime = A.Player:GetSwingStart(inv)`

**Parameters**
- `inv` (`number|nil`): same selector as `:GetSwing(inv)`.

**Return Values**
- `startTime` (`number`): the last recorded swing start timestamp from `SwingTimers`, or `0`.

**Usage Example**
```lua
local mhStart = A.Player:GetSwingStart(1)
```

### `:ReplaceSwingDuration(inv, dur)`

**Signature**
- `A.Player:ReplaceSwingDuration(inv, dur)`

**Parameters**
- `inv` (`number`): same selector as `:GetSwing(inv)` (1..5 or slot constant).
- `dur` (`number`): new duration in seconds.

**Return Values**
- (no return)

**Logic Explanation**
- Mutates the `SwingTimers[slot].duration` field(s) in place.

**Intended usage**
- Niche overrides when the swing monitor is known to misreport (use carefully; affects downstream calculations).

**Usage Example**
```lua
-- Force mainhand swing duration to 2.6s.
A.Player:ReplaceSwingDuration(1, 2.6)
```

## Weapon damage helpers

### `:GetWeaponMeleeDamage(inv, mod)`

**Signature**
- `avgDamage, avgDPS = A.Player:GetWeaponMeleeDamage(inv, mod)`

**Parameters**
- `inv` (`number|nil`): `1` mainhand, `2` offhand, `nil`/omitted = both (sums).
- `mod` (`number|nil`): custom multiplier applied to swing speed in the DPS calculation (defaults to `1`).

**Return Values**
- `avgDamage` (`number`): sum of average white-hit damage for selected weapon(s).
- `avgDPS` (`number`): sum of average white-hit DPS for selected weapon(s).

**Logic Explanation**
- Uses `UnitDamage()` and `UnitAttackSpeed()` to compute average hit damage and divides by speed (optionally scaled by `mod`) for DPS.

**Usage Example**
```lua
local mhAvgDamage, mhDPS = A.Player:GetWeaponMeleeDamage(1)
```

### `:AttackPowerDamageMod(offHand)`

**Signature**
- `value = A.Player:AttackPowerDamageMod(offHand)`

**Parameters**
- `offHand` (`boolean|nil`): when true, computes using offhand values (and applies a 0.5 multiplier in the final result).

**Return Values**
- `value` (`number`): a derived value using `UnitAttackPower`, `UnitDamage`, `UnitAttackSpeed`, and haste.

**Logic Explanation**
- Derives a weapon DPS component and recombines it with attack power using a `* 6` convention, with a `0.5` penalty for offhand.

**Intended usage**
- Tooltip-style scaling where you need an AP-derived damage baseline.

**Usage Example**
```lua
local mhValue = A.Player:AttackPowerDamageMod()
```

## Swap lock / equipment tracking

### `:IsSwapLocked()`

**Signature**
- `locked = A.Player:IsSwapLocked()`

**Return Values**
- `locked` (`boolean`): true while the UI has an item lock active (tracked via `ITEM_LOCKED/UNLOCKED`).

**Intended usage**
- Always guard equip-swap actions with this check to avoid blocked swaps.

**Usage Example**
```lua
if not A.Player:IsSwapLocked() then
    -- Safe to attempt a swap equip action.
end
```

### `:RemoveTier(tier)`

**Signature**
- `A.Player:RemoveTier(tier)`

**Parameters**
- `tier` (`string`): tier key name (e.g., `"Tier21"`).

**Return Values**
- (no return)

**Logic Explanation**
- Removes the tier from internal watch lists. If nothing is watched anymore, unregisters the equipment change listener.

**Usage Example**
```lua
A.Player:RemoveTier("Tier21")
```

### `:AddTier(tier, items)`

**Signature**
- `A.Player:AddTier(tier, items)`

**Parameters**
- `tier` (`string`): tier key name (e.g., `"Tier16"`).
- `items` (`table<number>`): list of itemIDs that count for the tier.

**Return Values**
- (no return)

**Logic Explanation**
- Adds the tier to `Data.CheckItems` and initializes/updates its equipped-count via `IsEquippedItem(itemID)` on `PLAYER_EQUIPMENT_CHANGED`.

**Usage Example**
```lua
A.Player:AddTier("Tier16", { 99200, 99201, 99202, 99203, 99204 })
```

### `:GetTier(tier)`

**Signature**
- `count = A.Player:GetTier(tier)`

**Parameters**
- `tier` (`string`): tier key name.

**Return Values**
- `count` (`number`): how many watched items for that tier are currently equipped.

**Usage Example**
```lua
local t16 = A.Player:GetTier("Tier16")
```

### `:HasTier(tier, count)`

**Signature**
- `has = A.Player:HasTier(tier, count)`

**Parameters**
- `tier` (`string`): tier key name.
- `count` (`number`): required equipped piece count.

**Return Values**
- `has` (`boolean`): true if `GetTier(tier) >= count` and you are not in Proving Grounds (`A.ZoneID ~= 480`).

**Usage Example**
```lua
if A.Player:HasTier("Tier16", 2) then
    -- 2-piece bonus active (outside Proving Grounds).
end
```

## Bags / Inventory tracking

### `:RemoveBag(name)`

**Signature**
- `A.Player:RemoveBag(name)`

**Parameters**
- `name` (`string`): key used when calling `:AddBag`.

**Return Values**
- (no return)

**Logic Explanation**
- Removes the bag query entry and unregisters bag listeners when no entries remain.

**Usage Example**
```lua
A.Player:RemoveBag("HEALTH_POT")
```

### `:AddBag(name, data)`

**Signature**
- `A.Player:AddBag(name, data)`

**Parameters**
- `name` (`string`): query key used for retrieval.
- `data` (`table`): item filter criteria. At least one of these should be set:
  - `itemID` (`number|nil`)
  - `itemEquipLoc` (`string|nil`)
  - `itemClassID` (`number|nil`)
  - `itemSubClassID` (`number|nil`)
  - `isEquippableItem` (`boolean|nil`)

**Return Values**
- (no return)

**Logic Explanation**
- Registers bag event listeners when first used.
- Scans bags on updates; for each query key that matches any item, stores:
  - `Data.InfoBags[name].itemID`
  - `Data.InfoBags[name].count` (via `GetItemCount(itemID, nil, true)`).

**Intended usage**
- Lightweight "do I have X in my bags?" or "do I have an equippable item of type Y?" checks with caching driven by bag events.

**Usage Example**
```lua
A.Player:AddBag("HEALTH_POT", { itemID = 76097 })
```

### `:GetBag(name)`

**Signature**
- `info = A.Player:GetBag(name)`

**Parameters**
- `name` (`string`): query key.

**Return Values**
- `info` (`table|nil`): `{ count = number, itemID = number }` for the last scan, or `nil` if nothing matched.

**Usage Example**
```lua
local potInfo = A.Player:GetBag("HEALTH_POT")
```

### `:RemoveInv(name)`

**Signature**
- `A.Player:RemoveInv(name)`

**Parameters**
- `name` (`string`): key used when calling `:AddInv`.

**Return Values**
- (no return)

**Usage Example**
```lua
A.Player:RemoveInv("TRINKET1")
```

### `:AddInv(name, slot, data)`

**Signature**
- `A.Player:AddInv(name, slot, data)`

**Parameters**
- `name` (`string`): query key used for retrieval.
- `slot` (`number`): inventory slot ID (commonly from `Action.Const`, e.g. `CONST.INVSLOT_OFFHAND`).
- `data` (`table`): item filter criteria (same fields as `:AddBag`), plus `slot` is set internally.

**Return Values**
- (no return)

**Logic Explanation**
- Registers `PLAYER_EQUIPMENT_CHANGED` listener when first used.
- Stores `Data.InfoInv[name] = { slot = slot, itemID = itemID }` when a match exists.

**Usage Example**
```lua
A.Player:AddInv("OFFHAND_SHIELD", CONST.INVSLOT_OFFHAND, { itemSubClassID = LE_ITEM_ARMOR_SHIELD })
```

### `:GetInv(name)`

**Signature**
- `info = A.Player:GetInv(name)`

**Parameters**
- `name` (`string`): query key.

**Return Values**
- `info` (`table|nil`): `{ slot = number, itemID = number }` from the last scan, or `nil`.

**Usage Example**
```lua
local offhand = A.Player:GetInv("OFFHAND_SHIELD")
```

## Registration helpers (bags/inventory)

These are convenience wrappers that call `:AddBag(...)` and/or `:AddInv(...)` with prebuilt filters.

### `:RegisterAmmo()`

**Signature**
- `A.Player:RegisterAmmo()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers two bag queries:
  - `"AMMO1"`: projectile subclass 2 (arrows),
  - `"AMMO2"`: projectile subclass 3 (bullets).

**Usage Example**
```lua
A.Player:RegisterAmmo()
```

### `:RegisterThrown()`

**Signature**
- `A.Player:RegisterThrown()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers `"THROWN"` bag query using `itemEquipLoc = "INVTYPE_THROWN"`.

**Usage Example**
```lua
A.Player:RegisterThrown()
```

### `:RegisterShield()`

**Signature**
- `A.Player:RegisterShield()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers:
  - `"SHIELD"` bag query for equippable shields,
  - `"SHIELD"` inventory query in `CONST.INVSLOT_OFFHAND`.

**Usage Example**
```lua
A.Player:RegisterShield()
```

### `:RegisterWeaponOffHand()`

**Signature**
- `A.Player:RegisterWeaponOffHand()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers several `"WEAPON_OFFHAND_X"` bag queries for different 1H weapon subclasses and an offhand inventory query `"WEAPON_OFFHAND"`.

**Usage Example**
```lua
A.Player:RegisterWeaponOffHand()
```

### `:RegisterWeaponTwoHand()`

**Signature**
- `A.Player:RegisterWeaponTwoHand()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers several `"WEAPON_TWOHAND_X"` bag and inventory queries for common 2H weapon subclasses (axe2h/mace2h/polearm/sword2h/staff).

**Usage Example**
```lua
A.Player:RegisterWeaponTwoHand()
```

### `:RegisterWeaponMainOneHandDagger()`

**Signature**
- `A.Player:RegisterWeaponMainOneHandDagger()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers bag/inventory queries for a mainhand dagger.

**Usage Example**
```lua
A.Player:RegisterWeaponMainOneHandDagger()
```

### `:RegisterWeaponMainOneHandSword()`

**Signature**
- `A.Player:RegisterWeaponMainOneHandSword()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers bag/inventory queries for a mainhand 1H sword.

**Usage Example**
```lua
A.Player:RegisterWeaponMainOneHandSword()
```

### `:RegisterWeaponOffOneHandSword()`

**Signature**
- `A.Player:RegisterWeaponOffOneHandSword()`

**Return Values**
- (no return)

**Logic Explanation**
- Registers bag/inventory queries for an offhand 1H sword.

**Usage Example**
```lua
A.Player:RegisterWeaponOffOneHandSword()
```

## Ammo / Weapon-type queries

### `:GetAmmo()`

**Signature**
- `count = A.Player:GetAmmo()`

**Return Values**
- `count` (`number|nil`): ammo count for arrows first, then bullets; `nil` if neither query exists/has data.

**Prerequisites**
- Call `A.Player:RegisterAmmo()` first.

**Usage Example**
```lua
local ammo = A.Player:GetAmmo() or 0
```

### `:GetArrow()`

**Signature**
- `count = A.Player:GetArrow()`

**Return Values**
- `count` (`number`): arrow count, or `0`.

**Prerequisites**
- Call `A.Player:RegisterAmmo()` first.

**Usage Example**
```lua
local arrows = A.Player:GetArrow()
```

### `:GetBullet()`

**Signature**
- `count = A.Player:GetBullet()`

**Return Values**
- `count` (`number`): bullet count, or `0`.

**Prerequisites**
- Call `A.Player:RegisterAmmo()` first.

**Usage Example**
```lua
local bullets = A.Player:GetBullet()
```

### `:GetThrown()`

**Signature**
- `count = A.Player:GetThrown()`

**Return Values**
- `count` (`number`): thrown weapon count, or `0`.

**Prerequisites**
- Call `A.Player:RegisterThrown()` first.

**Usage Example**
```lua
local thrown = A.Player:GetThrown()
```

### `:HasShield(isEquiped)`

**Signature**
- `itemID = A.Player:HasShield(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching shield itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterShield()` first.

**Usage Example**
```lua
local equippedShield = A.Player:HasShield(true)
```

### `:HasWeaponOffHand(isEquiped)`

**Signature**
- `itemID = A.Player:HasWeaponOffHand(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching offhand weapon itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterWeaponOffHand()` first.

**Usage Example**
```lua
local offhandInBags = A.Player:HasWeaponOffHand(false)
```

### `:HasWeaponTwoHand(isEquiped)`

**Signature**
- `itemID = A.Player:HasWeaponTwoHand(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching 2H weapon itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterWeaponTwoHand()` first.

**Usage Example**
```lua
local twoHandEquipped = A.Player:HasWeaponTwoHand(true)
```

### `:HasWeaponMainOneHandDagger(isEquiped)`

**Signature**
- `itemID = A.Player:HasWeaponMainOneHandDagger(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching dagger itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterWeaponMainOneHandDagger()` first.

**Usage Example**
```lua
local daggerEquipped = A.Player:HasWeaponMainOneHandDagger(true)
```

### `:HasWeaponMainOneHandSword(isEquiped)`

**Signature**
- `itemID = A.Player:HasWeaponMainOneHandSword(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching 1H sword itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterWeaponMainOneHandSword()` first.

**Usage Example**
```lua
local swordEquipped = A.Player:HasWeaponMainOneHandSword(true)
```

### `:HasWeaponOffOneHandSword(isEquiped)`

**Signature**
- `itemID = A.Player:HasWeaponOffOneHandSword(isEquiped)`

**Parameters**
- `isEquiped` (`boolean|nil`): when true, checks inventory; otherwise checks bags.

**Return Values**
- `itemID` (`number|nil`): a matching offhand 1H sword itemID, or `nil`.

**Prerequisites**
- Call `A.Player:RegisterWeaponOffOneHandSword()` first.

**Usage Example**
```lua
local swordOffhandInBags = A.Player:HasWeaponOffOneHandSword(false)
```

## Resources (power)

All resource helpers use the unitID `"player"` and WoW `UnitPower`/`UnitPowerMax`/`GetPowerRegen` APIs.

### `:ManaMax()`

**Signature**
- `max = A.Player:ManaMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Mana)`.

**Usage Example**
```lua
local manaMax = A.Player:ManaMax()
```

### `:Mana()`

**Signature**
- `mana = A.Player:Mana()`

**Return Values**
- `mana` (`number`): `UnitPower("player", Enum.PowerType.Mana)`.

**Usage Example**
```lua
local mana = A.Player:Mana()
```

### `:ManaPercentage()`

**Signature**
- `pct = A.Player:ManaPercentage()`

**Return Values**
- `pct` (`number`): `(Mana / ManaMax) * 100`.

**Usage Example**
```lua
if A.Player:ManaPercentage() < 20 then end
```

### `:ManaDeficit()`

**Signature**
- `deficit = A.Player:ManaDeficit()`

**Return Values**
- `deficit` (`number`): `ManaMax - Mana`.

**Usage Example**
```lua
local missingMana = A.Player:ManaDeficit()
```

### `:ManaDeficitPercentage()`

**Signature**
- `pct = A.Player:ManaDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(ManaDeficit / ManaMax) * 100`.

**Usage Example**
```lua
local manaMissingPct = A.Player:ManaDeficitPercentage()
```

### `:ManaRegen()`

**Signature**
- `regen = A.Player:ManaRegen()`

**Return Values**
- `regen` (`number`): `floor(GetPowerRegen("player"))`.

**Usage Example**
```lua
local manaRegen = A.Player:ManaRegen()
```

### `:ManaCastRegen(CastTime)`

**Signature**
- `regen = A.Player:ManaCastRegen(CastTime)`

**Parameters**
- `CastTime` (`number`): seconds.

**Return Values**
- `regen` (`number`): `ManaRegen * CastTime`, or `-1` if `ManaRegen()` returns `0`.

**Usage Example**
```lua
local regenDuring2s = A.Player:ManaCastRegen(2.0)
```

### `:ManaRemainingCastRegen(Offset)`

**Signature**
- `regen = A.Player:ManaRemainingCastRegen(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the "remaining cast" window.

**Return Values**
- `regen` (`number`): mana expected to regenerate until end of current cast, or until end of the current GCD if not casting; `-1` if regen is `0`.

**Logic Explanation**
- If casting: `ManaRegen * (CastRemains + Offset)`.
- Else: `ManaRegen * (CurrentGCD + Offset)`.

**Usage Example**
```lua
local regenSoon = A.Player:ManaRemainingCastRegen()
```

### `:ManaTimeToMax()`

**Signature**
- `seconds = A.Player:ManaTimeToMax()`

**Return Values**
- `seconds` (`number`): `ManaDeficit / ManaRegen`, or `-1` if regen is `0`.

**Usage Example**
```lua
local ttm = A.Player:ManaTimeToMax()
```

### `:ManaTimeToX(Amount)`

**Signature**
- `seconds = A.Player:ManaTimeToX(Amount)`

**Parameters**
- `Amount` (`number`): desired mana value.

**Return Values**
- `seconds` (`number`): time to reach `Amount` at current regen, `0` if already above, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:ManaTimeToX(20000)
```

### `:ManaP()`

**Signature**
- `futureMana = A.Player:ManaP()`

**Return Values**
- `futureMana` (`number`): predicted mana at the end of the current cast/GCD window.

**Logic Explanation**
- Starts from `Mana - CastCost()` and adds `ManaRemainingCastRegen()` if not already at max; clamps to `ManaMax`.

**Usage Example**
```lua
local manaAfterCast = A.Player:ManaP()
```

### `:ManaPercentageP()`

**Signature**
- `pct = A.Player:ManaPercentageP()`

**Return Values**
- `pct` (`number`): `(ManaP / ManaMax) * 100`.

**Usage Example**
```lua
local manaPctAfterCast = A.Player:ManaPercentageP()
```

### `:ManaDeficitP()`

**Signature**
- `deficit = A.Player:ManaDeficitP()`

**Return Values**
- `deficit` (`number`): `ManaMax - ManaP`.

**Usage Example**
```lua
local missingAfterCast = A.Player:ManaDeficitP()
```

### `:ManaDeficitPercentageP()`

**Signature**
- `pct = A.Player:ManaDeficitPercentageP()`

**Return Values**
- `pct` (`number`): `(ManaDeficitP / ManaMax) * 100`.

**Usage Example**
```lua
local missingPctAfterCast = A.Player:ManaDeficitPercentageP()
```

### `:RageMax()`

**Signature**
- `max = A.Player:RageMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Rage)`.

**Usage Example**
```lua
local rageMax = A.Player:RageMax()
```

### `:Rage()`

**Signature**
- `rage = A.Player:Rage()`

**Return Values**
- `rage` (`number`): `UnitPower("player", Enum.PowerType.Rage)`.

**Usage Example**
```lua
local rage = A.Player:Rage()
```

### `:RagePercentage()`

**Signature**
- `pct = A.Player:RagePercentage()`

**Return Values**
- `pct` (`number`): `(Rage / RageMax) * 100`.

**Usage Example**
```lua
local ragePct = A.Player:RagePercentage()
```

### `:RageDeficit()`

**Signature**
- `deficit = A.Player:RageDeficit()`

**Return Values**
- `deficit` (`number`): `RageMax - Rage`.

**Usage Example**
```lua
local missingRage = A.Player:RageDeficit()
```

### `:RageDeficitPercentage()`

**Signature**
- `pct = A.Player:RageDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(RageDeficit / RageMax) * 100`.

**Usage Example**
```lua
local missingRagePct = A.Player:RageDeficitPercentage()
```

### `:FocusMax()`

**Signature**
- `max = A.Player:FocusMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Focus)`.

**Usage Example**
```lua
local focusMax = A.Player:FocusMax()
```

### `:Focus()`

**Signature**
- `focus = A.Player:Focus()`

**Return Values**
- `focus` (`number`): `UnitPower("player", Enum.PowerType.Focus)`.

**Usage Example**
```lua
local focus = A.Player:Focus()
```

### `:FocusRegen()`

**Signature**
- `regen = A.Player:FocusRegen()`

**Return Values**
- `regen` (`number`): `floor(GetPowerRegen("player"))`.

**Usage Example**
```lua
local focusRegen = A.Player:FocusRegen()
```

### `:FocusPercentage()`

**Signature**
- `pct = A.Player:FocusPercentage()`

**Return Values**
- `pct` (`number`): `(Focus / FocusMax) * 100`.

**Usage Example**
```lua
local focusPct = A.Player:FocusPercentage()
```

### `:FocusDeficit()`

**Signature**
- `deficit = A.Player:FocusDeficit()`

**Return Values**
- `deficit` (`number`): `FocusMax - Focus`.

**Usage Example**
```lua
local missingFocus = A.Player:FocusDeficit()
```

### `:FocusDeficitPercentage()`

**Signature**
- `pct = A.Player:FocusDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(FocusDeficit / FocusMax) * 100`.

**Usage Example**
```lua
local missingFocusPct = A.Player:FocusDeficitPercentage()
```

### `:FocusRegenPercentage()`

**Signature**
- `pct = A.Player:FocusRegenPercentage()`

**Return Values**
- `pct` (`number`): `(FocusRegen / FocusMax) * 100`.

**Usage Example**
```lua
local focusRegenPct = A.Player:FocusRegenPercentage()
```

### `:FocusTimeToMax()`

**Signature**
- `seconds = A.Player:FocusTimeToMax()`

**Return Values**
- `seconds` (`number`): `FocusDeficit / FocusRegen`, or `-1` if regen is `0`.

**Usage Example**
```lua
local ttf = A.Player:FocusTimeToMax()
```

### `:FocusTimeToX(Amount)`

**Signature**
- `seconds = A.Player:FocusTimeToX(Amount)`

**Parameters**
- `Amount` (`number`): desired focus value.

**Return Values**
- `seconds` (`number`): time to reach `Amount` at current regen, `0` if already above, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:FocusTimeToX(50)
```

### `:FocusTimeToXPercentage(Amount)`

**Signature**
- `seconds = A.Player:FocusTimeToXPercentage(Amount)`

**Parameters**
- `Amount` (`number`): desired focus percentage (0..100).

**Return Values**
- `seconds` (`number`): time to reach that percentage at current regen, `0` if already above, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:FocusTimeToXPercentage(80)
```

### `:FocusCastRegen(CastTime)`

**Signature**
- `regen = A.Player:FocusCastRegen(CastTime)`

**Parameters**
- `CastTime` (`number`): seconds.

**Return Values**
- `regen` (`number`): `FocusRegen * CastTime`, or `-1` if regen is `0`.

**Usage Example**
```lua
local regenDuringGCD = A.Player:FocusCastRegen(A.Player:GCDRemains())
```

### `:FocusRemainingCastRegen(Offset)`

**Signature**
- `regen = A.Player:FocusRemainingCastRegen(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the remaining cast/GCD window.

**Return Values**
- `regen` (`number`): focus expected to regenerate until end of cast if currently casting, otherwise until end of the remaining GCD; `-1` if regen is `0`.

**Usage Example**
```lua
local regenSoon = A.Player:FocusRemainingCastRegen()
```

### `:FocusLossOnCastEnd()`

**Signature**
- `cost = A.Player:FocusLossOnCastEnd()`

**Return Values**
- `cost` (`number`): power cost of the current cast spell (via `Action.GetSpellPowerCost`), or `0` if not casting.

**Logic Explanation**
- Reads `spellID` from `Action.Unit("player"):IsCasting()` and queries its power cost.

**Usage Example**
```lua
local focusSpent = A.Player:FocusLossOnCastEnd()
```

### `:FocusPredicted(Offset)`

**Signature**
- `futureFocus = A.Player:FocusPredicted(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the regen window.

**Return Values**
- `futureFocus` (`number`): predicted focus at end of cast/GCD window, clamped to `FocusMax`, or `-1` if regen is `0`.

**Usage Example**
```lua
local focusAfterCast = A.Player:FocusPredicted()
```

### `:FocusDeficitPredicted(Offset)`

**Signature**
- `futureDeficit = A.Player:FocusDeficitPredicted(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the regen window.

**Return Values**
- `futureDeficit` (`number`): `FocusMax - FocusPredicted`, or `-1` if regen is `0`.

**Usage Example**
```lua
local deficitAfterCast = A.Player:FocusDeficitPredicted()
```

### `:FocusTimeToMaxPredicted()`

**Signature**
- `seconds = A.Player:FocusTimeToMaxPredicted()`

**Return Values**
- `seconds` (`number`): predicted time-to-max after accounting for current cast window, or `-1` if regen is `0`.

**Usage Example**
```lua
local ttf = A.Player:FocusTimeToMaxPredicted()
```

### `:EnergyMax()`

**Signature**
- `max = A.Player:EnergyMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Energy)`.

**Usage Example**
```lua
local energyMax = A.Player:EnergyMax()
```

### `:Energy()`

**Signature**
- `energy = A.Player:Energy()`

**Return Values**
- `energy` (`number`): `UnitPower("player", Enum.PowerType.Energy)`.

**Usage Example**
```lua
local energy = A.Player:Energy()
```

### `:EnergyRegen()`

**Signature**
- `regen = A.Player:EnergyRegen()`

**Return Values**
- `regen` (`number`): `floor(GetPowerRegen("player"))`.

**Usage Example**
```lua
local energyRegen = A.Player:EnergyRegen()
```

### `:EnergyPercentage()`

**Signature**
- `pct = A.Player:EnergyPercentage()`

**Return Values**
- `pct` (`number`): `(Energy / EnergyMax) * 100`.

**Usage Example**
```lua
local energyPct = A.Player:EnergyPercentage()
```

### `:EnergyDeficit()`

**Signature**
- `deficit = A.Player:EnergyDeficit()`

**Return Values**
- `deficit` (`number`): `EnergyMax - Energy`.

**Usage Example**
```lua
local missingEnergy = A.Player:EnergyDeficit()
```

### `:EnergyDeficitPercentage()`

**Signature**
- `pct = A.Player:EnergyDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(EnergyDeficit / EnergyMax) * 100`.

**Usage Example**
```lua
local missingEnergyPct = A.Player:EnergyDeficitPercentage()
```

### `:EnergyRegenPercentage()`

**Signature**
- `pct = A.Player:EnergyRegenPercentage()`

**Return Values**
- `pct` (`number`): `(EnergyRegen / EnergyMax) * 100`.

**Usage Example**
```lua
local energyRegenPct = A.Player:EnergyRegenPercentage()
```

### `:EnergyTimeToMax()`

**Signature**
- `seconds = A.Player:EnergyTimeToMax()`

**Return Values**
- `seconds` (`number`): `EnergyDeficit / EnergyRegen`, or `-1` if regen is `0`.

**Usage Example**
```lua
local tte = A.Player:EnergyTimeToMax()
```

### `:EnergyTimeToX(Amount, Offset)`

**Signature**
- `seconds = A.Player:EnergyTimeToX(Amount, Offset)`

**Parameters**
- `Amount` (`number`): desired energy value.
- `Offset` (`number|nil`): fractional regen penalty (used as `regen * (1 - Offset)`).

**Return Values**
- `seconds` (`number`): time to reach `Amount`, `0` if already above, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:EnergyTimeToX(60)
```

### `:EnergyTimeToXPercentage(Amount)`

**Signature**
- `seconds = A.Player:EnergyTimeToXPercentage(Amount)`

**Parameters**
- `Amount` (`number`): desired energy percentage (0..100).

**Return Values**
- `seconds` (`number`): time to reach that percentage, `0` if already above, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:EnergyTimeToXPercentage(80)
```

### `:EnergyRemainingCastRegen(Offset)`

**Signature**
- `regen = A.Player:EnergyRemainingCastRegen(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the remaining cast/GCD window.

**Return Values**
- `regen` (`number`): energy expected to regenerate until end of cast/channel if currently casting/channeling, otherwise until end of remaining GCD; `-1` if regen is `0`.

**Usage Example**
```lua
local regenSoon = A.Player:EnergyRemainingCastRegen()
```

### `:EnergyPredicted(Offset)`

**Signature**
- `futureEnergy = A.Player:EnergyPredicted(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the regen window.

**Return Values**
- `futureEnergy` (`number`): predicted energy at end of cast/GCD window, clamped to `EnergyMax`, or `-1` if regen is `0`.

**Usage Example**
```lua
local energyAfter = A.Player:EnergyPredicted()
```

### `:EnergyDeficitPredicted(Offset)`

**Signature**
- `futureDeficit = A.Player:EnergyDeficitPredicted(Offset)`

**Parameters**
- `Offset` (`number|nil`): extra seconds added to the regen window.

**Return Values**
- `futureDeficit` (`number`): `max(EnergyDeficit - EnergyRemainingCastRegen(Offset), 0)`, or `-1` if regen is `0`.

**Usage Example**
```lua
local deficitAfter = A.Player:EnergyDeficitPredicted()
```

### `:EnergyTimeToMaxPredicted()`

**Signature**
- `seconds = A.Player:EnergyTimeToMaxPredicted()`

**Return Values**
- `seconds` (`number`): predicted time-to-max after accounting for current cast window, or `-1` if regen is `0`.

**Usage Example**
```lua
local t = A.Player:EnergyTimeToMaxPredicted()
```

### `:ComboPointsMax()`

**Signature**
- `max = A.Player:ComboPointsMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.ComboPoints)`.

**Usage Example**
```lua
local cpMax = A.Player:ComboPointsMax()
```

### `:ComboPoints(unitID)`

**Signature**
- `cp = A.Player:ComboPoints(unitID)`

**Parameters**
- `unitID` (`string|nil`): target unit token (defaults to `"target"`).

**Return Values**
- `cp` (`number`): `GetComboPoints("player", unitID)`.

**Usage Example**
```lua
local cpOnTarget = A.Player:ComboPoints("target")
```

### `:ComboPointsDeficit(unitID)`

**Signature**
- `deficit = A.Player:ComboPointsDeficit(unitID)`

**Parameters**
- `unitID` (`string|nil`): target unit token (defaults to `"target"`).

**Return Values**
- `deficit` (`number`): `ComboPointsMax - ComboPoints(unitID)`.

**Usage Example**
```lua
local cpMissing = A.Player:ComboPointsDeficit()
```

### `:RunicPowerMax()`

**Signature**
- `max = A.Player:RunicPowerMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.RunicPower)`.

**Usage Example**
```lua
local rpMax = A.Player:RunicPowerMax()
```

### `:RunicPower()`

**Signature**
- `rp = A.Player:RunicPower()`

**Return Values**
- `rp` (`number`): `UnitPower("player", Enum.PowerType.RunicPower)`.

**Usage Example**
```lua
local rp = A.Player:RunicPower()
```

### `:RunicPowerPercentage()`

**Signature**
- `pct = A.Player:RunicPowerPercentage()`

**Return Values**
- `pct` (`number`): `(RunicPower / RunicPowerMax) * 100`.

**Usage Example**
```lua
local rpPct = A.Player:RunicPowerPercentage()
```

### `:RunicPowerDeficit()`

**Signature**
- `deficit = A.Player:RunicPowerDeficit()`

**Return Values**
- `deficit` (`number`): `RunicPowerMax - RunicPower`.

**Usage Example**
```lua
local rpMissing = A.Player:RunicPowerDeficit()
```

### `:RunicPowerDeficitPercentage()`

**Signature**
- `pct = A.Player:RunicPowerDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(RunicPowerDeficit / RunicPowerMax) * 100`.

**Usage Example**
```lua
local rpMissingPct = A.Player:RunicPowerDeficitPercentage()
```

### `:Rune(presence)`

**Signature**
- `count = A.Player:Rune(presence)`

**Parameters**
- `presence` (`number|string|nil`): rune presence/type selector:
  - can be an `Action.Const.DEATHKNIGHT_*` constant,
  - or `"Blood"`, `"Frost"`, `"Unholy"`, `"Death"`,
  - or a raw rune type number as returned by `GetRuneType`.

**Return Values**
- `count` (`number`): number of ready runes matching that type (Death runes count as matching any specific type).

**Logic Explanation**
- Counts runes where computed cooldown is 0 and runeType matches `presenceType` or is Death (`4`).

**Usage Example**
```lua
local bloodRunesReady = A.Player:Rune("Blood")
```

### `:RuneTimeToX(Value)`

**Signature**
- `seconds = A.Player:RuneTimeToX(Value)`

**Parameters**
- `Value` (`number`): integer 1..6 (which rune readiness threshold you want).

**Return Values**
- `seconds` (`number`): cooldown (seconds) for the `Value`-th soonest rune to become ready.

**Logic Explanation**
- Computes cooldown for all 6 rune slots, sorts ascending, returns the `Value`-th element.
- Includes latency/GCD recovery offset via `RecoveryOffset()`.

**Usage Example**
```lua
local timeTo2Runes = A.Player:RuneTimeToX(2)
```

### `:SoulShardsMax()`

**Signature**
- `max = A.Player:SoulShardsMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.SoulShards)`.

**Usage Example**
```lua
local ssMax = A.Player:SoulShardsMax()
```

### `:SoulShards()`

**Signature**
- `ss = A.Player:SoulShards()`

**Return Values**
- `ss` (`number`): `UnitPower("player", Enum.PowerType.SoulShards)`.

**Usage Example**
```lua
local ss = A.Player:SoulShards()
```

### `:SoulShardsP()`

**Signature**
- `ss = A.Player:SoulShardsP()`

**Return Values**
- `ss` (`number`): current soul shards (same as `:SoulShards()` in the base engine).

**Notes**
- The comment indicates this is intended to be overridden per-spec if needed.

**Usage Example**
```lua
local ssPredicted = A.Player:SoulShardsP()
```

### `:SoulShardsDeficit()`

**Signature**
- `deficit = A.Player:SoulShardsDeficit()`

**Return Values**
- `deficit` (`number`): `SoulShardsMax - SoulShards`.

**Usage Example**
```lua
local ssMissing = A.Player:SoulShardsDeficit()
```

### `:AstralPowerMax()`

**Signature**
- `max = A.Player:AstralPowerMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.LunarPower)` (mapped here as Astral Power).

**Usage Example**
```lua
local apMax = A.Player:AstralPowerMax()
```

### `:AstralPower(OverrideFutureAstralPower)`

**Signature**
- `ap = A.Player:AstralPower(OverrideFutureAstralPower)`

**Parameters**
- `OverrideFutureAstralPower` (`number|nil`): if provided, returned directly instead of reading current `UnitPower`.

**Return Values**
- `ap` (`number`): current astral power (or override).

**Usage Example**
```lua
local ap = A.Player:AstralPower()
```

### `:AstralPowerPercentage(OverrideFutureAstralPower)`

**Signature**
- `pct = A.Player:AstralPowerPercentage(OverrideFutureAstralPower)`

**Return Values**
- `pct` (`number`): `(AstralPower / AstralPowerMax) * 100`.

**Usage Example**
```lua
local apPct = A.Player:AstralPowerPercentage()
```

### `:AstralPowerDeficit(OverrideFutureAstralPower)`

**Signature**
- `deficit = A.Player:AstralPowerDeficit(OverrideFutureAstralPower)`

**Return Values**
- `deficit` (`number`): `AstralPowerMax - AstralPower`.

**Usage Example**
```lua
local apMissing = A.Player:AstralPowerDeficit()
```

### `:AstralPowerDeficitPercentage(OverrideFutureAstralPower)`

**Signature**
- `pct = A.Player:AstralPowerDeficitPercentage(OverrideFutureAstralPower)`

**Return Values**
- `pct` (`number`): `(AstralPowerDeficit / AstralPowerMax) * 100`.

**Usage Example**
```lua
local apMissingPct = A.Player:AstralPowerDeficitPercentage()
```

### `:HolyPowerMax()`

**Signature**
- `max = A.Player:HolyPowerMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.HolyPower)`.

**Usage Example**
```lua
local hpMax = A.Player:HolyPowerMax()
```

### `:HolyPower()`

**Signature**
- `hp = A.Player:HolyPower()`

**Return Values**
- `hp` (`number`): `UnitPower("player", Enum.PowerType.HolyPower)`.

**Usage Example**
```lua
local hp = A.Player:HolyPower()
```

### `:HolyPowerPercentage()`

**Signature**
- `pct = A.Player:HolyPowerPercentage()`

**Return Values**
- `pct` (`number`): `(HolyPower / HolyPowerMax) * 100`.

**Usage Example**
```lua
local hpPct = A.Player:HolyPowerPercentage()
```

### `:HolyPowerDeficit()`

**Signature**
- `deficit = A.Player:HolyPowerDeficit()`

**Return Values**
- `deficit` (`number`): `HolyPowerMax - HolyPower`.

**Usage Example**
```lua
local hpMissing = A.Player:HolyPowerDeficit()
```

### `:HolyPowerDeficitPercentage()`

**Signature**
- `pct = A.Player:HolyPowerDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(HolyPowerDeficit / HolyPowerMax) * 100`.

**Usage Example**
```lua
local hpMissingPct = A.Player:HolyPowerDeficitPercentage()
```

### `:MaelstromMax()`

**Signature**
- `max = A.Player:MaelstromMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Maelstrom)`.

**Usage Example**
```lua
local mMax = A.Player:MaelstromMax()
```

### `:Maelstrom()`

**Signature**
- `m = A.Player:Maelstrom()`

**Return Values**
- `m` (`number`): `UnitPower("player", Enum.PowerType.Maelstrom)`.

**Usage Example**
```lua
local m = A.Player:Maelstrom()
```

### `:MaelstromPercentage()`

**Signature**
- `pct = A.Player:MaelstromPercentage()`

**Return Values**
- `pct` (`number`): `(Maelstrom / MaelstromMax) * 100`.

**Usage Example**
```lua
local mPct = A.Player:MaelstromPercentage()
```

### `:MaelstromDeficit()`

**Signature**
- `deficit = A.Player:MaelstromDeficit()`

**Return Values**
- `deficit` (`number`): `MaelstromMax - Maelstrom`.

**Usage Example**
```lua
local mMissing = A.Player:MaelstromDeficit()
```

### `:MaelstromDeficitPercentage()`

**Signature**
- `pct = A.Player:MaelstromDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(MaelstromDeficit / MaelstromMax) * 100`.

**Usage Example**
```lua
local mMissingPct = A.Player:MaelstromDeficitPercentage()
```

### `:ChiMax()`

**Signature**
- `max = A.Player:ChiMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Chi)`.

**Usage Example**
```lua
local chiMax = A.Player:ChiMax()
```

### `:Chi()`

**Signature**
- `chi = A.Player:Chi()`

**Return Values**
- `chi` (`number`): `UnitPower("player", Enum.PowerType.Chi)`.

**Usage Example**
```lua
local chi = A.Player:Chi()
```

### `:ChiPercentage()`

**Signature**
- `pct = A.Player:ChiPercentage()`

**Return Values**
- `pct` (`number`): `(Chi / ChiMax) * 100`.

**Usage Example**
```lua
local chiPct = A.Player:ChiPercentage()
```

### `:ChiDeficit()`

**Signature**
- `deficit = A.Player:ChiDeficit()`

**Return Values**
- `deficit` (`number`): `ChiMax - Chi`.

**Usage Example**
```lua
local chiMissing = A.Player:ChiDeficit()
```

### `:ChiDeficitPercentage()`

**Signature**
- `pct = A.Player:ChiDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(ChiDeficit / ChiMax) * 100`.

**Usage Example**
```lua
local chiMissingPct = A.Player:ChiDeficitPercentage()
```

### `:StaggerMax()`

**Signature**
- `max = A.Player:StaggerMax()`

**Return Values**
- `max` (`number`): `Action.Unit("player"):HealthMax()` (used as the base for percentage calculations).

**Usage Example**
```lua
local staggerBase = A.Player:StaggerMax()
```

### `:Stagger()`

**Signature**
- `amount = A.Player:Stagger()`

**Return Values**
- `amount` (`number`): `UnitStagger("player")`.

**Usage Example**
```lua
local stagger = A.Player:Stagger()
```

### `:StaggerPercentage()`

**Signature**
- `pct = A.Player:StaggerPercentage()`

**Return Values**
- `pct` (`number`): `(Stagger / StaggerMax) * 100`.

**Usage Example**
```lua
local staggerPct = A.Player:StaggerPercentage()
```

### `:InsanityMax()`

**Signature**
- `max = A.Player:InsanityMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Insanity)`.

**Usage Example**
```lua
local iMax = A.Player:InsanityMax()
```

### `:Insanity()`

**Signature**
- `i = A.Player:Insanity()`

**Return Values**
- `i` (`number`): `UnitPower("player", Enum.PowerType.Insanity)`.

**Usage Example**
```lua
local i = A.Player:Insanity()
```

### `:InsanityPercentage()`

**Signature**
- `pct = A.Player:InsanityPercentage()`

**Return Values**
- `pct` (`number`): `(Insanity / InsanityMax) * 100`.

**Usage Example**
```lua
local iPct = A.Player:InsanityPercentage()
```

### `:InsanityDeficit()`

**Signature**
- `deficit = A.Player:InsanityDeficit()`

**Return Values**
- `deficit` (`number`): `InsanityMax - Insanity`.

**Usage Example**
```lua
local iMissing = A.Player:InsanityDeficit()
```

### `:InsanityDeficitPercentage()`

**Signature**
- `pct = A.Player:InsanityDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(InsanityDeficit / InsanityMax) * 100`.

**Usage Example**
```lua
local iMissingPct = A.Player:InsanityDeficitPercentage()
```

### `:Insanityrain()`

**Signature**
- `drainPerSecond = A.Player:Insanityrain()`

**Return Values**
- `drainPerSecond` (`number`): 0 if no Voidform stacks, otherwise `6 + 0.68 * stacks`.

**Logic Explanation**
- Reads Voidform stack count via `Action.Unit("player"):HasBuffsStacks(194249, true)`.

**Usage Example**
```lua
local drain = A.Player:Insanityrain()
```

### `:ArcaneChargesMax()`

**Signature**
- `max = A.Player:ArcaneChargesMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.ArcaneCharges)`.

**Usage Example**
```lua
local acMax = A.Player:ArcaneChargesMax()
```

### `:ArcaneCharges()`

**Signature**
- `ac = A.Player:ArcaneCharges()`

**Return Values**
- `ac` (`number`): `UnitPower("player", Enum.PowerType.ArcaneCharges)`.

**Usage Example**
```lua
local ac = A.Player:ArcaneCharges()
```

### `:ArcaneChargesPercentage()`

**Signature**
- `pct = A.Player:ArcaneChargesPercentage()`

**Return Values**
- `pct` (`number`): `(ArcaneCharges / ArcaneChargesMax) * 100`.

**Usage Example**
```lua
local acPct = A.Player:ArcaneChargesPercentage()
```

### `:ArcaneChargesDeficit()`

**Signature**
- `deficit = A.Player:ArcaneChargesDeficit()`

**Return Values**
- `deficit` (`number`): `ArcaneChargesMax - ArcaneCharges`.

**Usage Example**
```lua
local acMissing = A.Player:ArcaneChargesDeficit()
```

### `:ArcaneChargesDeficitPercentage()`

**Signature**
- `pct = A.Player:ArcaneChargesDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(ArcaneChargesDeficit / ArcaneChargesMax) * 100`.

**Usage Example**
```lua
local acMissingPct = A.Player:ArcaneChargesDeficitPercentage()
```

### `:FuryMax()`

**Signature**
- `max = A.Player:FuryMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Fury)`.

**Usage Example**
```lua
local fMax = A.Player:FuryMax()
```

### `:Fury()`

**Signature**
- `f = A.Player:Fury()`

**Return Values**
- `f` (`number`): `UnitPower("player", Enum.PowerType.Fury)`.

**Usage Example**
```lua
local f = A.Player:Fury()
```

### `:FuryPercentage()`

**Signature**
- `pct = A.Player:FuryPercentage()`

**Return Values**
- `pct` (`number`): `(Fury / FuryMax) * 100`.

**Usage Example**
```lua
local fPct = A.Player:FuryPercentage()
```

### `:FuryDeficit()`

**Signature**
- `deficit = A.Player:FuryDeficit()`

**Return Values**
- `deficit` (`number`): `FuryMax - Fury`.

**Usage Example**
```lua
local fMissing = A.Player:FuryDeficit()
```

### `:FuryDeficitPercentage()`

**Signature**
- `pct = A.Player:FuryDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(FuryDeficit / FuryMax) * 100`.

**Usage Example**
```lua
local fMissingPct = A.Player:FuryDeficitPercentage()
```

### `:PainMax()`

**Signature**
- `max = A.Player:PainMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Pain)`.

**Usage Example**
```lua
local pMax = A.Player:PainMax()
```

### `:Pain()`

**Signature**
- `p = A.Player:Pain()`

**Return Values**
- `p` (`number`): `UnitPower("player", Enum.PowerType.Pain)`.

**Usage Example**
```lua
local p = A.Player:Pain()
```

### `:PainPercentage()`

**Signature**
- `pct = A.Player:PainPercentage()`

**Return Values**
- `pct` (`number`): `(Pain / PainMax) * 100`.

**Usage Example**
```lua
local pPct = A.Player:PainPercentage()
```

### `:PainDeficit()`

**Signature**
- `deficit = A.Player:PainDeficit()`

**Return Values**
- `deficit` (`number`): `PainMax - Pain`.

**Usage Example**
```lua
local pMissing = A.Player:PainDeficit()
```

### `:PainDeficitPercentage()`

**Signature**
- `pct = A.Player:PainDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(PainDeficit / PainMax) * 100`.

**Usage Example**
```lua
local pMissingPct = A.Player:PainDeficitPercentage()
```

### `:EssenceMax()`

**Signature**
- `max = A.Player:EssenceMax()`

**Return Values**
- `max` (`number`): `UnitPowerMax("player", Enum.PowerType.Essence)`.

**Usage Example**
```lua
local eMax = A.Player:EssenceMax()
```

### `:Essence()`

**Signature**
- `e = A.Player:Essence()`

**Return Values**
- `e` (`number`): `UnitPower("player", Enum.PowerType.Essence)`.

**Usage Example**
```lua
local e = A.Player:Essence()
```

### `:EssenceDeficit()`

**Signature**
- `deficit = A.Player:EssenceDeficit()`

**Return Values**
- `deficit` (`number`): `EssenceMax - Essence`.

**Usage Example**
```lua
local eMissing = A.Player:EssenceDeficit()
```

### `:EssenceDeficitPercentage()`

**Signature**
- `pct = A.Player:EssenceDeficitPercentage()`

**Return Values**
- `pct` (`number`): `(EssenceDeficit / EssenceMax) * 100`.

**Usage Example**
```lua
local eMissingPct = A.Player:EssenceDeficitPercentage()
```

## Resource helper maps

`Player.lua` also defines two exported tables intended for generic UI/engine usage.

### `A.Player.PredictedResourceMap`

**Type**
- `table<number, function>`

**Usage**
- Maps a power type index to a function that returns the "best" current or predicted value for that resource type.

**Notes**
- `[-2]` maps to player health (`Action.Unit("player"):Health()`).
- `[-1]` maps to the constant `100`.
- `0` (mana) uses `A.Player:ManaP()`.
- `2` (focus) uses `A.Player:FocusPredicted()`.
- `3` (energy) uses `A.Player:EnergyPredicted()`.
- Other entries generally return the current value.

**Usage Example**
```lua
local manaPred = A.Player.PredictedResourceMap[0]()
```

### `A.Player.TimeToXResourceMap`

**Type**
- `table<number, function>`

**Usage**
- Maps a power type index to a function that returns "time to reach X" for that resource type, when supported.

**Notes**
- Mana uses `A.Player:ManaTimeToX(Value)`.
- Focus uses `A.Player:FocusTimeToX(Value)`.
- Energy uses `A.Player:EnergyTimeToX(Value)`.
- Runes uses `A.Player:RuneTimeToX(Value)`.
- Many entries are `function() return nil end` placeholders.

**Usage Example**
```lua
local timeTo60Energy = A.Player.TimeToXResourceMap[3](60)
```
