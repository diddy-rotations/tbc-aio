# TheAction `Unit.lua` helper functions

This document covers the public helpers exposed by `../action_mop/Modules/Engines/Unit.lua`.

It includes:
- `Action.GetAuraList`, `Action.IsUnitFriendly`, `Action.IsUnitEnemy`
- `Action.Unit(unitID[, refresh])` and the methods on the Unit pseudo-class
- `Action.FriendlyTeam(role[, refresh])` and `Action.EnemyTeam(role[, refresh])`

## Critical design notes (read first)

### Pseudo-class objects are mutable singletons

`Action.Unit`, `Action.FriendlyTeam`, and `Action.EnemyTeam` are implemented as pseudo-classes with a `__call` metamethod that mutates and returns the same table each time:

- `A.Unit("target")` sets `A.Unit.UnitID = "target"` and returns `A.Unit`
- the next call `A.Unit("player")` overwrites `A.Unit.UnitID`

Because of this, **do not store unit objects** (and do not create object shortcuts), or you will end up calling methods on the wrong unit:

```lua
-- BAD: u will silently change when Unit(...) is called elsewhere
-- local u = Unit("target")
-- if u:HealthPercent() < 50 then ... end

-- GOOD: call Unit("target") each time
if Unit("target"):HealthPercent() < 50 then
    -- ...
end
```

### Caching and the `refresh` argument

Most Unit/Team helpers are wrapped by an internal cache (`Cache:Wrap`/`Cache:Pass`) keyed by unit identity and function arguments.

- `refresh` (`number|nil`) is a cache TTL (seconds) stored on the pseudo-class object as `self.Refresh`.
- If `refresh` is `nil`, internal helpers fall back to `Action.Const.CACHE_DEFAULT_TIMER_UNIT`.
- Some helpers cache by `"UnitID"`, others by `"UnitGUID"` (to keep results stable across unitID aliases in some cases).
- Line-of-sight naming gotcha: `Unit(unitID):InLOS()` returns `Action.UnitInLOS(...)`, which is `true` when the unit is **out of LOS**. Use `not Unit(unitID):InLOS()` to mean "in LOS".
- Range return order gotcha: `Unit(unitID):GetRange()` returns `(maxRange, minRange)` (note order), and may return `math.huge` when range cannot be determined. `:CanInterract(range)` uses the first return (maxRange) as a conservative "definitely in range" check.

## Core helpers (global `Action.*`)

### `Action.GetAuraList(key)`

**Signature**
- `list = A.GetAuraList(key)`

**Parameters**
- `key` (`string`): key in the internal `AuraList` table (e.g., `"DamageBuffs"`, `"KickImun"`, `"CastBarsCC"`).

**Return Values**
- `list` (`table|nil`): the underlying array table for that key, or `nil` if the key is unknown.

**Logic Explanation**
- Direct table lookup: returns `AuraList[key]`.

**Usage Example**
```lua
local kickImmunList = A.GetAuraList("KickImun")
```

### `Action.IsUnitFriendly(unitID)`

**Signature**
- `ok = A.IsUnitFriendly(unitID)`

**Parameters**
- `unitID` (`string`): unit token (e.g., `"mouseover"`, `"targettarget"`, `"party1"`, `"raid5"`).

**Return Values**
- `ok` (`boolean`): whether the unit token should be treated as a valid friendly unit under the engine rules.

**Logic Explanation**
- Special cases:
  - `"mouseover"` requires `GetToggle(2, "mouseover")`, `MouseHasFrame()`, and `not Unit("mouseover"):IsEnemy()`.
  - `"targettarget"` requires `GetToggle(2, "targettarget")`, `Unit("target"):IsEnemy()`, `"targettarget"` exists, `"targettarget"` is not enemy, and a LOS check (`not Action.UnitInLOS(unitID)`).
- Default case:
  - Requires mouseover not being enabled/valid/enemy, and the unit exists and is not enemy.
- Wrapped by `Action.MakeFunctionCachedDynamic` in the same file (same signature/behavior, just cached).

**Usage Example**
```lua
if A.IsUnitFriendly("mouseover") then
    -- Can treat mouseover as a friendly unit.
end
```

### `Action.IsUnitEnemy(unitID)`

**Signature**
- `ok = A.IsUnitEnemy(unitID)`

**Parameters**
- `unitID` (`string`): unit token (e.g., `"mouseover"`, `"targettarget"`, `"arena1"`).

**Return Values**
- `ok` (`boolean`): whether the unit token should be treated as a valid enemy unit under the engine rules.

**Logic Explanation**
- Special cases:
  - `"mouseover"` requires `GetToggle(2, "mouseover")` and `Unit("mouseover"):IsEnemy()`.
  - `"targettarget"` requires `GetToggle(2, "targettarget")`, `Unit("target")` is not enemy, `"targettarget"` is enemy, `"targettarget"` has `CombatTime() > 0`, and LOS check (`not Action.UnitInLOS(unitID)`).
- Default case:
  - Requires mouseover not being enabled/active and the unit being enemy.
- Wrapped by `Action.MakeFunctionCachedDynamic` in the same file (same signature/behavior, just cached).

**Usage Example**
```lua
if A.IsUnitEnemy("targettarget") then
    -- Treat targettarget as an enemy unit token.
end
```

## Unit pseudo-class (`Action.Unit`)

### `Action.Unit:New(UnitID, Refresh)`

**Signature**
- `A.Unit:New(UnitID, Refresh)`

**Parameters**
- `UnitID` (`string`): required unit token. Passing `nil` throws with a debugstack snippet.
- `Refresh` (`number|nil`): cache TTL in seconds (stored as `self.Refresh`).

**Return Values**
- (no return)

**Logic Explanation**
- Sets `self.UnitID = UnitID` and `self.Refresh = Refresh`.
- Throws an error if `UnitID` is nil (this is the primary guard against `Unit(nil)` bugs).

**Usage Example**
```lua
-- Normally you do not call :New() directly; you call Unit("target") or A.Unit("target").
local name = Unit("target"):Name()
```

### `Unit(unitID[, refresh])` / `A.Unit(unitID[, refresh])`

**Signature**
- `u = Unit(unitID[, refresh])` (TellMeWhen/Action environment)
- `u = A.Unit(unitID[, refresh])` (direct)

**Parameters**
- `unitID` (`string`)
- `refresh` (`number|nil`): cache TTL override (seconds)

**Return Values**
- `u` (`table`): the Unit pseudo-class object, mutated to point at `unitID`.

**Usage Example**
```lua
if Unit("target"):IsEnemy() and Unit("target"):InRange() then
    -- ...
end
```

### `A.Unit.HasDeBuffs` (alias)

**Signature**
- `remain, total = Unit(unitID):HasDeBuffs(spell, caster, byID)`

**Notes**
- In `Unit.lua`, `A.Unit.HasDeBuffs` is assigned as an alias for `A.Unit.SortDeBuffs`.

**Usage Example**
```lua
local ripRemain = Unit("target"):HasDeBuffs("Rip", true)
```

## Unit identity / classification

### `:Name()`

**Signature**
- `name = Unit(unitID):Name()`

**Return Values**
- `name` (`string`): `UnitName(unitID)` or `"none"`.

**Logic Explanation**
- Wrapper around WoW `UnitName`.

**Usage Example**
```lua
local name = Unit("target"):Name()
```

### `:Race()`

**Signature**
- `race = Unit(unitID):Race()`

**Return Values**
- `race` (`string`): localized race token (2nd return from `UnitRace`), or `"none"`.

**Logic Explanation**
- For `"player"` returns `A.PlayerRace`; otherwise uses `UnitRace(unitID)`.

**Usage Example**
```lua
local race = Unit("arena1"):Race()
```

### `:Class()`

**Signature**
- `class = Unit(unitID):Class()`

**Return Values**
- `class` (`string`): English class token (2nd return from `UnitClass`), or `"none"`.

**Logic Explanation**
- For `"player"` returns `A.PlayerClass`; otherwise uses `UnitClass(unitID)`.

**Usage Example**
```lua
local class = Unit("arena1"):Class()
```

### `:Role(hasRole)`

**Signature**
- `roleOrBool = Unit(unitID):Role(hasRole)`

**Parameters**
- `hasRole` (`"TANK"|"HEALER"|"DAMAGER"|"NONE"|nil`):
  - when provided, returns a boolean answering "is this unit that role?"
  - when nil, returns the unit role string.

**Return Values**
- If `hasRole` is provided: `isRole` (`boolean`)
- If `hasRole` is nil: `role` (`"TANK"|"HEALER"|"DAMAGER"|"NONE"`)

**Logic Explanation**
- Starts from `UnitGroupRolesAssigned(unitID)`.
- Special-cases Proving Grounds (`A.ZoneID == 480`) by inferring role from known NPC IDs.
- If role is `"NONE"` and `hasRole` is provided, delegates to `:IsHealer()`, `:IsTank()`, `:IsDamager()`, etc.
- If role is `"NONE"` and `hasRole` is nil, falls back to `:IsHealer()`/`:IsTank()` inference.

**Usage Example**
```lua
if Unit("party2"):Role("HEALER") then
    -- party2 is (or is inferred to be) a healer.
end
```

### `:Classification()`

**Signature**
- `cls = Unit(unitID):Classification()`

**Return Values**
- `cls` (`string`): result of `UnitClassification(unitID)` or `"none"`.

**Usage Example**
```lua
local cls = Unit("target"):Classification()
```

### `:CreatureType()`

**Signature**
- `ctype = Unit(unitID):CreatureType()`

**Return Values**
- `ctype` (`string`): internal normalized creature type string, or empty string.

**Logic Explanation**
- Reads `UnitCreatureType(unitID)` and maps via `Info.CreatureType`.

**Usage Example**
```lua
local ctype = Unit("target"):CreatureType()
```

### `:CreatureFamily()`

**Signature**
- `family = Unit(unitID):CreatureFamily()`

**Return Values**
- `family` (`string`): internal normalized creature family string, or empty string.

**Logic Explanation**
- Reads `UnitCreatureFamily(unitID)` and maps via `Info.CreatureFamily`.

**Usage Example**
```lua
local family = Unit("pet"):CreatureFamily()
```

### `:InfoGUID(unitGUID)`

**Signature**
- `utype, zero, serverID, instanceID, zoneUID, npcID, spawnUID = Unit(unitID):InfoGUID(unitGUID)`

**Parameters**
- `unitGUID` (`string|nil`): optional GUID to parse; if nil, calls `UnitGUID(unitID)`.

**Return Values**
- `utype` (`string|nil`): `"Player"|"Creature"|"Pet"|"GameObject"|"Vehicle"|"Vignette"` (English) or nil.
- `zero` (`number|nil`): numeric conversion of GUID field 2.
- `serverID` (`number|nil`): numeric conversion of GUID field 3 (or player UID for players).
- `instanceID` (`number|nil`)
- `zoneUID` (`number|nil`)
- `npcID` (`number|nil`)
- `spawnUID` (`number|nil`)

**Logic Explanation**
- Splits the GUID by `"-"` and converts numeric fields via `Action.toNum`.

**Usage Example**
```lua
local _, _, _, _, _, npcID = Unit("target"):InfoGUID()
```

---

## Group / LOS / existence / basic state

### `:InLOS(unitGUID)`

**Signature**
- `outOfLOS = Unit(unitID):InLOS(unitGUID)`

**Parameters**
- `unitGUID` (`string|nil`): optional GUID override; if nil, the LOS engine will query via `unitID`.

**Return Values**
- `outOfLOS` (`boolean`): `true` when the unit is **out of line of sight** according to the Action LOS engine.

**Logic Explanation**
- Delegates to `Action.UnitInLOS(unitID, unitGUID)`.

**Intended usage**
- LOS gating. Typical "in LOS" checks should be written as `not Unit(unitID):InLOS()`.

**Usage Example**
```lua
if Unit("target"):IsExists() and not Unit("target"):InLOS() then
    -- Target exists and is in LOS.
end
```

---

### `:InGroup(includeAnyGroups, unitGUID)`

**Signature**
- `inGroup = Unit(unitID):InGroup(includeAnyGroups, unitGUID)`

**Parameters**
- `includeAnyGroups` (`boolean|nil`):
  - `true`: uses WoW `UnitInAnyGroup(unitID)` (party/raid style grouping).
  - `nil/false`: uses Action team caches (`Action.TeamCache`) and checks by GUID.
- `unitGUID` (`string|nil`): optional GUID override when `includeAnyGroups` is `nil/false`.

**Return Values**
- `inGroup` (`boolean`): whether the unit is considered part of a tracked group/team.

**Logic Explanation**
- If `includeAnyGroups` is true: `UnitInAnyGroup(unitID)`.
- Otherwise: resolves GUID (argument or internal `GetGUID(unitID)`) and checks if it exists in `TeamCacheFriendly.GUIDs` or `TeamCacheEnemy.GUIDs`.

**Intended usage**
- Use `includeAnyGroups=true` when you only care about party/raid membership.
- Use the default behavior when you want "tracked by the engine" semantics (including enemy team caching).

**Usage Example**
```lua
if Unit("arena1"):InGroup() then
    -- arena1 is tracked as part of the current enemy team cache.
end
```

---

### `:InParty()`

**Signature**
- `inParty = Unit(unitID):InParty()`

**Return Values**
- `inParty` (`boolean`): whether the unit is a player/pet in the player's party.

**Logic Explanation**
- Wrapper around WoW `UnitPlayerOrPetInParty(unitID)`.

**Usage Example**
```lua
if Unit("party2"):InParty() then
    -- party2 exists in party context.
end
```

---

### `:InRaid()`

**Signature**
- `inRaid = Unit(unitID):InRaid()`

**Return Values**
- `inRaid` (`boolean`): whether the unit is a player/pet in the player's raid.

**Logic Explanation**
- Wrapper around WoW `UnitPlayerOrPetInRaid(unitID)`.

**Usage Example**
```lua
if Unit("raid5"):InRaid() then
    -- raid5 exists in raid context.
end
```

---

### `:InRange()`

**Signature**
- `inRange = Unit(unitID):InRange()`

**Return Values**
- `inRange` (`boolean`): `true` if the unit is `"player"` or WoW `UnitInRange(unitID)` is true.

**Logic Explanation**
- `UnitIsUnit(unitID, "player") or UnitInRange(unitID)`.

**Intended usage**
- Quick "is close enough to interact/heal" approximation (WoW's `UnitInRange` is not a precise yard check).

**Usage Example**
```lua
if Unit("party1"):InRange() then
    -- party1 is in the generic UnitInRange window.
end
```

---

### `:InVehicle()`

**Signature**
- `inVehicle = Unit(unitID):InVehicle()`

**Return Values**
- `inVehicle` (`boolean`): whether the unit is in a vehicle.

**Logic Explanation**
- Wrapper around WoW `UnitInVehicle(unitID)`.

**Usage Example**
```lua
if Unit("player"):InVehicle() then
    -- Player is in a vehicle.
end
```

---

### `:InCC(index)`

**Signature**
- `remain = Unit(unitID):InCC(index)`

**Parameters**
- `index` (`number|nil`): starting index into the internal `InfoAllCC` list (defaults to `1`).

**Return Values**
- `remain` (`number`): remaining CC duration (seconds) for the first matching aura in `InfoAllCC`, or `0`.

**Logic Explanation**
- Iterates `InfoAllCC` starting at `index` and returns the first non-zero `Unit(unitID):HasDeBuffs(InfoAllCC[i])`.

**Intended usage**
- Generic "is crowd controlled" check without needing to specify the exact CC.

**Usage Example**
```lua
if Unit("arena1"):InCC() > 0 then
    -- arena1 is currently CC'd by something in InfoAllCC.
end
```

---

### `:IsEnemy(isPlayer)`

**Signature**
- `isEnemy = Unit(unitID):IsEnemy(isPlayer)`

**Parameters**
- `isPlayer` (`boolean|nil`): when true, requires `UnitIsPlayer(unitID)`.

**Return Values**
- `isEnemy` (`boolean`): whether the unit is attackable/hostile (optionally restricted to players).

**Logic Explanation**
- `UnitCanAttack("player", unitID) or UnitIsEnemy("player", unitID)`.
- If `isPlayer` is true, also requires `UnitIsPlayer(unitID)`.

**Usage Example**
```lua
if Unit("mouseover"):IsEnemy(true) then
    -- Mouseover is an enemy player.
end
```

---

### `:IsHealer(class)`

**Signature**
- `isHealer = Unit(unitID):IsHealer(class)`

**Parameters**
- `class` (`string|nil`): optional class token (e.g., `"PRIEST"`). When nil, uses `Unit(unitID):Class()`.

**Return Values**
- `isHealer` (`boolean|nil`): `true` if the unit is inferred to be a healer. Returns `nil` when the unit's class cannot be a healer.

**Logic Explanation**
- Only runs when `InfoClassCanBeHealer[class]` is true.
- Prefers cached role markers (`TeamCacheFriendlyHEALER` / `TeamCacheEnemyHEALER`) and spec inference (`:HasSpec(InfoSpecIs.HEALER)`).
- Uses `UnitGroupRolesAssigned` and party assignments to disqualify obvious non-healers (e.g., maintank/mainassist).
- Class-specific fallbacks use power type, weapon/offhand heuristics, `UnitStagger` (monk), and "tank buff" presence to separate healer vs non-healer for hybrid classes.
- In PvE (not PvP), disqualifies units that appear to be tanking a boss (unit is the target of its target and its target is a boss).
- Final fallback compares CombatTracker metrics: healer if `HPS > DMG_taken` and `HPS > DPS_done`.

**Intended usage**
- Healer detection for arena opponents and groups where role metadata is missing/unreliable.

**Usage Example**
```lua
if Unit("arena2"):IsHealer() then
    -- Treat arena2 as a healer for targeting/CC logic.
end
```

---

### `:IsHealerClass()`

**Signature**
- `canHeal = Unit(unitID):IsHealerClass()`

**Return Values**
- `canHeal` (`boolean|nil`): value from `InfoClassCanBeHealer[class]`.

**Logic Explanation**
- Checks `InfoClassCanBeHealer[Unit(unitID):Class()]`.

**Usage Example**
```lua
if Unit("arena1"):IsHealerClass() then
    -- arena1's class can be a healer.
end
```

---

### `:IsTank(class)`

**Signature**
- `isTank = Unit(unitID):IsTank(class)`

**Parameters**
- `class` (`string|nil`): optional class token; when nil uses `Unit(unitID):Class()`.

**Return Values**
- `isTank` (`boolean|nil`): `true` if the unit is inferred to be a tank. Returns `nil` when the unit's class cannot be a tank.

**Logic Explanation**
- Only runs when `InfoClassCanBeTank[class]` exists (may be a table of tank-form/tank-buff auras).
- Prefers cached role markers (`TeamCacheFriendlyTANK` / `TeamCacheEnemyTANK`) and spec inference (`:HasSpec(InfoSpecIs.TANK)`).
- Uses `UnitGroupRolesAssigned`, `GetPartyAssignment("maintank")`, and PvP/arena gating to reduce false positives.
- Class-specific fallbacks use power type, offhand/shield heuristics, stance/buff checks, `UnitStagger`, and threat data.
- In PvE (not PvP), if the unit appears to be tanking a boss (unit is the target of its target and its target is a boss), it is treated as a tank.
- Final fallback compares CombatTracker metrics: tank if `DMG_taken > DPS_done` and `DMG_taken > HPS_done`.

**Intended usage**
- Tank detection for friendly/hostile players when you do not have reliable spec/role info.

**Usage Example**
```lua
if Unit("party2"):IsTank() then
    -- party2 is treated as a tank.
end
```

---

### `:IsTankClass()`

**Signature**
- `canTank = Unit(unitID):IsTankClass()`

**Return Values**
- `canTank` (`boolean`): true if the unit's class is capable of tanking.

**Logic Explanation**
- Returns `InfoClassCanBeTank[class] and true` to force a boolean (since the map may store a table of tank buffs).

**Usage Example**
```lua
if Unit("arena1"):IsTankClass() then
    -- arena1's class can be a tank.
end
```

---

### `:IsDamager(class)`

**Signature**
- `isDPS = Unit(unitID):IsDamager(class)`

**Parameters**
- `class` (`string|nil`): optional class token; when nil uses `Unit(unitID):Class()`.

**Return Values**
- `isDPS` (`boolean`): `true` if the unit is inferred to be a damage dealer.

**Logic Explanation**
- Prefers cached markers (`TeamCacheFriendlyDAMAGER` / `TeamCacheEnemyDAMAGER`) and spec inference (`:HasSpec(InfoSpecIs.DAMAGER)`).
- Uses `UnitGroupRolesAssigned` to disqualify non-damagers when known.
- Class-specific fallbacks use power type and weapon/offhand heuristics for hybrids.
- In PvE (not PvP), disqualifies units that appear to be tanking a boss.
- Final fallback compares CombatTracker metrics: damager if `DPS_done > DMG_taken` and `DPS_done > HPS_done`.

**Usage Example**
```lua
if Unit("arena3"):IsDamager() then
    -- arena3 is treated as DPS.
end
```

---

### `:IsMelee(class)`

**Signature**
- `isMelee = Unit(unitID):IsMelee(class)`

**Parameters**
- `class` (`string|nil`): optional class token; when nil uses `Unit(unitID):Class()`.

**Return Values**
- `isMelee` (`boolean|nil`): `true` if the unit is inferred to be a melee damager. Returns `nil` when the unit's class cannot be melee.

**Logic Explanation**
- Only runs when `InfoClassCanBeMelee[class]` is true.
- Prefers cached markers (`TeamCacheFriendlyDAMAGER_MELEE` / `TeamCacheEnemyDAMAGER_MELEE`) and spec inference (`:HasSpec(InfoSpecIs.MELEE)`).
- Uses `UnitGroupRolesAssigned` with special-cases for hybrid melee-capable classes.
- Class-specific fallbacks use:
  - power type + shield/offhand heuristics for paladin,
  - used-spell detection for hunter melee abilities (via `:GetSpellCounter(spellID)`),
  - offhand speed for shaman (dual wield),
  - power type/stagger heuristics for monk,
  - power type for druid (energy/rage),
  - default true for always-melee classes.

**Intended usage**
- Identify melee threats (for kiting/defensives, DR categories, etc.).

**Usage Example**
```lua
if Unit("arena1"):IsMelee() then
    -- arena1 is likely a melee.
end
```

---

### `:IsMeleeClass()`

**Signature**
- `canMelee = Unit(unitID):IsMeleeClass()`

**Return Values**
- `canMelee` (`boolean|nil`): value from `InfoClassCanBeMelee[class]`.

**Usage Example**
```lua
if Unit("arena2"):IsMeleeClass() then
    -- arena2's class has at least one melee spec/playstyle.
end
```

---

### `:IsDead()`

**Signature**
- `isDead = Unit(unitID):IsDead()`

**Return Values**
- `isDead` (`boolean`): true if `UnitIsDeadOrGhost(unitID)` and not `UnitIsFeignDeath(unitID)`.

**Usage Example**
```lua
if Unit("target"):IsDead() then
    -- Target is dead (ignores feign death).
end
```

---

### `:IsGhost()`

**Signature**
- `isGhost = Unit(unitID):IsGhost()`

**Return Values**
- `isGhost` (`boolean`): `UnitIsGhost(unitID)`.

**Usage Example**
```lua
if Unit("player"):IsGhost() then
    -- Player is a ghost.
end
```

---

### `:IsPlayer()`

**Signature**
- `isPlayer = Unit(unitID):IsPlayer()`

**Return Values**
- `isPlayer` (`boolean`): `UnitIsPlayer(unitID)`.

**Usage Example**
```lua
if Unit("arena1"):IsPlayer() then
    -- arena1 is a player unit.
end
```

---

### `:IsPet()`

**Signature**
- `isPet = Unit(unitID):IsPet()`

**Return Values**
- `isPet` (`boolean`): true when the unit is player-controlled but not a player (`not UnitIsPlayer(unitID) and UnitPlayerControlled(unitID)`).

**Usage Example**
```lua
if Unit("arena1pet"):IsPet() then
    -- arena1pet is a player-controlled pet/companion.
end
```

---

### `:IsPlayerOrPet()`

**Signature**
- `isPlayerOrPet = Unit(unitID):IsPlayerOrPet()`

**Return Values**
- `isPlayerOrPet` (`boolean`): `UnitIsPlayer(unitID) or UnitPlayerControlled(unitID)`.

**Usage Example**
```lua
if Unit("target"):IsPlayerOrPet() then
    -- Target is a player or player-controlled unit.
end
```

---

### `:IsNPC()`

**Signature**
- `isNPC = Unit(unitID):IsNPC()`

**Return Values**
- `isNPC` (`boolean`): `not UnitPlayerControlled(unitID)`.

**Usage Example**
```lua
if Unit("target"):IsNPC() then
    -- Target is not player-controlled.
end
```

---

### `:IsVisible()`

**Signature**
- `isVisible = Unit(unitID):IsVisible()`

**Return Values**
- `isVisible` (`boolean`): `UnitIsVisible(unitID)`.

**Usage Example**
```lua
if Unit("arena1"):IsVisible() then
    -- arena1 is visible.
end
```

---

### `:IsExists()`

**Signature**
- `exists = Unit(unitID):IsExists()`

**Return Values**
- `exists` (`boolean`): `UnitExists(unitID)`.

**Usage Example**
```lua
if Unit("focus"):IsExists() then
    -- Focus exists.
end
```

---

### `:IsNameplate()`

**Signature**
- `isNameplated, nameplateUnitID = Unit(unitID):IsNameplate()`

**Return Values**
- `isNameplated` (`boolean|nil`): true if the unit matches an active **enemy** nameplate.
- `nameplateUnitID` (`string|nil`): the matching `"nameplateX"` token.

**Logic Explanation**
- Iterates `Action.MultiUnits:GetActiveUnitPlates()` and uses `UnitIsUnit(unitID, nameplateUnitID)`.

**Intended usage**
- Bridge from an arbitrary unit token (e.g., `"target"`) to its active enemy nameplate token (`"nameplateX"`), when present.

**Usage Example**
```lua
local ok, plate = Unit("target"):IsNameplate()
if ok then
    -- plate is the enemy nameplate token (e.g., "nameplate3").
end
```

---

### `:IsNameplateAny()`

**Signature**
- `isNameplated, nameplateUnitID = Unit(unitID):IsNameplateAny()`

**Return Values**
- `isNameplated` (`boolean|nil`): true if the unit matches an active nameplate (enemy or friendly).
- `nameplateUnitID` (`string|nil`): the matching `"nameplateX"` token.

**Logic Explanation**
- Iterates `Action.MultiUnits:GetActiveUnitPlatesAny()`.

**Usage Example**
```lua
local ok, plate = Unit("mouseover"):IsNameplateAny()
if ok then
    -- mouseover currently has a nameplate.
end
```

---

### `:IsConnected()`

**Signature**
- `isConnected = Unit(unitID):IsConnected()`

**Return Values**
- `isConnected` (`boolean`): `UnitIsConnected(unitID)`.

**Usage Example**
```lua
if Unit("party3"):IsConnected() then
    -- party3 is connected.
end
```

---

### `:IsCharmed()`

**Signature**
- `isCharmed = Unit(unitID):IsCharmed()`

**Return Values**
- `isCharmed` (`boolean`): `UnitIsCharmed(unitID)`.

**Usage Example**
```lua
if Unit("target"):IsCharmed() then
    -- Target is charmed.
end
```

---

### `:IsMounted()`

**Signature**
- `isMounted = Unit(unitID):IsMounted()`

**Return Values**
- `isMounted` (`boolean`): whether the unit is considered mounted.

**Logic Explanation**
- For `"player"`: delegates to `A.Player:IsMounted()`.
- For others: treats the unit as mounted when its maximum speed is at least `200%` (`select(2, Unit(unitID):GetCurrentSpeed()) >= 200`).

**Usage Example**
```lua
if Unit("arena1"):IsMounted() then
    -- arena1 is likely mounted (or has mount-speed movement).
end
```

---

## Movement / casting / control

### `:IsMovingOut(snap_timer)`

**Signature**
- `movingOut = Unit(unitID):IsMovingOut(snap_timer)`

**Parameters**
- `snap_timer` (`number|nil`): seconds between range snapshots (defaults to `0.2`). The comment calls it "milliseconds" but the code treats it as seconds.

**Return Values**
- `movingOut` (`boolean|nil`): `true` when the unit is inferred to be moving away from you; `false` during sampling; `nil` when the unit is not moving (speed is `0`).

**Logic Explanation**
- For `"player"`: always returns `true` (special-cased).
- For others:
  - Requires `Unit(unitID):GetCurrentSpeed() > 0`.
  - Uses a per-GUID cache (`InfoCacheMoveOut[GUID]`) storing:
    - `Range` (min-range snapshot from `:GetRange()`),
    - `Snapshot` counter,
    - `Result` boolean,
    - `TimeStamp` for throttling.
  - If min-range increased across snapshots, increments `Snapshot`; otherwise decrements it.
  - Returns `true` after `Snapshot >= 3` (and clamps back to 2 to avoid runaway growth).

**Intended usage**
- Kiting logic, "is target running away" heuristics, or movement-based prediction for gap closers.
- Must be called repeatedly over time to build snapshot history.

**Usage Example**
```lua
if Unit("target"):IsMovingOut(0.2) then
    -- Target is likely moving away.
end
```

---

### `:IsMovingIn(snap_timer)`

**Signature**
- `movingIn = Unit(unitID):IsMovingIn(snap_timer)`

**Parameters**
- `snap_timer` (`number|nil`): seconds between range snapshots (defaults to `0.2`).

**Return Values**
- `movingIn` (`boolean|nil`): `true` when the unit is inferred to be moving toward you; `false` during sampling; `nil` when the unit is not moving.

**Logic Explanation**
- Same snapshot system as `:IsMovingOut`, but considers min-range decreasing as "moving in".

**Usage Example**
```lua
if Unit("target"):IsMovingIn() then
    -- Target is likely moving toward you.
end
```

---

### `:IsMoving()`

**Signature**
- `isMoving = Unit(unitID):IsMoving()`

**Return Values**
- `isMoving` (`boolean`):
  - `"player"`: `A.Player:IsMoving()`
  - others: `Unit(unitID):GetCurrentSpeed() ~= 0`

**Usage Example**
```lua
if Unit("player"):IsMoving() then
    -- Player is moving (event-driven movement tracking).
end
```

---

### `:IsMovingTime()`

**Signature**
- `movingFor = Unit(unitID):IsMovingTime()`

**Return Values**
- `movingFor` (`number`):
  - `"player"`: `A.Player:IsMovingTime()`
  - others: seconds since movement started, or `-1` when not moving.

**Logic Explanation**
- For non-player units, tracks a per-GUID timestamp while `:IsMoving()` is true.

**Usage Example**
```lua
local movingFor = Unit("target"):IsMovingTime()
if movingFor > 1 then
    -- Target has been moving for more than 1 second.
end
```

---

### `:IsStaying()`

**Signature**
- `isStaying = Unit(unitID):IsStaying()`

**Return Values**
- `isStaying` (`boolean`):
  - `"player"`: `A.Player:IsStaying()`
  - others: `Unit(unitID):GetCurrentSpeed() == 0`

**Usage Example**
```lua
if Unit("focus"):IsStaying() then
    -- Focus is stationary.
end
```

---

### `:IsStayingTime()`

**Signature**
- `stayingFor = Unit(unitID):IsStayingTime()`

**Return Values**
- `stayingFor` (`number`):
  - `"player"`: `A.Player:IsStayingTime()`
  - others: seconds since the unit became stationary, or `-1` when moving.

**Logic Explanation**
- For non-player units, tracks a per-GUID timestamp while `:IsMoving()` is false.

**Usage Example**
```lua
local stayingFor = Unit("target"):IsStayingTime()
if stayingFor >= 0 and stayingFor < 0.5 then
    -- Target just stopped moving.
end
```

---

### `:IsCasting()`

**Signature**
- `castName, castStartMS, castEndMS, notInterruptable, spellID, isChannel = Unit(unitID):IsCasting()`

**Return Values**
- `castName` (`string|nil`)
- `castStartMS` (`number|nil`): start timestamp (milliseconds)
- `castEndMS` (`number|nil`): end timestamp (milliseconds)
- `notInterruptable` (`boolean`): `false` means interruptable
- `spellID` (`number|nil`)
- `isChannel` (`boolean|nil`)

**Logic Explanation**
- Reads `UnitCastingInfo(unitID)`; if no cast, reads `UnitChannelInfo(unitID)` and sets `isChannel=true`.
- Overrides interruptability using Action aura lists:
  - If a cast exists and `AuraList.KickImun` is non-empty, sets `notInterruptable = (Unit(unitID):HasBuffs("KickImun") ~= 0)`.
  - Otherwise sets `notInterruptable = false`.

**Intended usage**
- Generic cast detection that respects Action's "kick immunity" aura list.

**Usage Example**
```lua
local castName, _, _, notInterruptable = Unit("target"):IsCasting()
if castName and not notInterruptable then
    -- Target is casting and can be interrupted (per Action rules).
end
```

---

### `:IsCastingRemains(argSpellID)`

**Signature**
- `leftSeconds, donePercent, spellID, spellName, notInterruptable, isChannel = Unit(unitID):IsCastingRemains(argSpellID)`

**Parameters**
- `argSpellID` (`number|nil`): optional spellID filter.

**Return Values**
- `leftSeconds` (`number`)
- `donePercent` (`number`)
- `spellID` (`number|nil`)
- `spellName` (`string|nil`)
- `notInterruptable` (`boolean|nil`)
- `isChannel` (`boolean|nil`)

**Logic Explanation**
- Returns `select(2, Unit(unitID):CastTime(argSpellID))`.

**Usage Example**
```lua
local left = Unit("target"):IsCastingRemains()
if left > 0 and left < 0.3 then
    -- Cast is nearly finished.
end
```

---

### `:CastTime(argSpellID)`

**Signature**
- `total, left, donePercent, spellID, spellName, notInterruptable, isChannel = Unit(unitID):CastTime(argSpellID)`

**Parameters**
- `argSpellID` (`number|nil`): optional spellID to match against the current cast by name (`A.GetSpellInfo(argSpellID) == castName`).

**Return Values**
- `total` (`number`): total cast/channel duration in seconds (0 if unknown).
- `left` (`number`): seconds remaining (0 if not casting).
- `donePercent` (`number`): percent completed (0-100).
- `spellID` (`number|nil`)
- `spellName` (`string|nil`)
- `notInterruptable` (`boolean|nil`)
- `isChannel` (`boolean|nil`)

**Logic Explanation**
- Uses `:IsCasting()` for the live cast/channel data.
- For `"player"`, when a spellID is available (argument or current spell), reads `GetSpellInfo` to get the base cast time using real-time data, then overrides when an active cast matches.

**Usage Example**
```lua
local _, left, done = Unit("target"):CastTime()
if left > 0 and done >= 50 then
    -- Target is at least halfway through the current cast.
end
```

---

### `:MultiCast(spells, range)`

**Signature**
- `total, left, donePercent, spellID, spellName, notInterruptable = Unit(unitID):MultiCast(spells, range)`

**Parameters**
- `spells` (`table|nil`): list of spellIDs (or spell references) to match. If nil, uses `AuraList.CastBarsCC`.
- `range` (`number|nil`): only returns a match if `Unit(unitID):GetRange() <= range`.

**Return Values**
- On match: the same fields as `:CastTime()` (without `isChannel`).
- On no match: `0, 0, 0`.

**Logic Explanation**
- Reads the current cast via `:CastTime()`.
- If a cast is active and within `range` (if provided), checks whether the current cast spellID or spellName matches the query list.

**Intended usage**
- Filtered casting detection (e.g., only track casts that are relevant for CC/kicks).

**Usage Example**
```lua
local _, left = Unit("target"):MultiCast(nil, 30)
if left > 0 then
    -- Target is casting something in AuraList.CastBarsCC and is within 30y (per GetRange).
end
```

---

## Diminishing returns / creature flags / threat

### `:IsControlAble(drCat, DR_Tick)`

**Signature**
- `ok = Unit(unitID):IsControlAble(drCat, DR_Tick)`

**Parameters**
- `drCat` (`string|nil`): DR category string (examples seen in codebase: `"stun"`, `"root"`, `"fear"`, `"taunt"`, `"cyclone"`, etc). When nil, only the basic "is controlable" checks apply.
- `DR_Tick` (`number|nil`): minimum DR tick required (0-100). When nil, any non-immune state passes.

**Return Values**
- `ok` (`boolean`): whether the unit is considered controlable under the given DR category and tick threshold.

**Logic Explanation**
- In PvE (`not A.IsInPvP`):
  - Rejects bosses (`not Unit(unitID):IsBoss()`).
  - Requires an allowed classification (`InfoControlAbleClasssification[Unit(unitID):Classification()]`).
- If `drCat` is provided, requires `Unit(unitID):GetDR(drCat) > (DR_Tick or 0)`.
- If `drCat == "fear"`, also rejects targets with fear-immunity debuffs from `AuraList.FearImunDeBuffs`.

**Intended usage**
- Gate CC usage by DR state and immunity rules.

**Usage Example**
```lua
if Unit("arena1"):IsControlAble("stun", 25) then
    -- arena1 is not fully DR-immune to stuns (tick > 25) and passes other checks.
end
```

---

### `:IsUndead()`

**Signature**
- `isUndead = Unit(unitID):IsUndead()`

**Return Values**
- `isUndead` (`boolean`): `Unit(unitID):CreatureType() == "Undead"`.

**Usage Example**
```lua
if Unit("target"):IsUndead() then
    -- Target is undead (per normalized creature type mapping).
end
```

---

### `:IsDemon()`

**Signature**
- `isDemon = Unit(unitID):IsDemon()`

**Return Values**
- `isDemon` (`boolean`): `Unit(unitID):CreatureType() == "Demon"`.

**Usage Example**
```lua
if Unit("target"):IsDemon() then end
```

---

### `:IsHumanoid()`

**Signature**
- `isHumanoid = Unit(unitID):IsHumanoid()`

**Return Values**
- `isHumanoid` (`boolean`): `Unit(unitID):CreatureType() == "Humanoid"`.

**Usage Example**
```lua
if Unit("target"):IsHumanoid() then end
```

---

### `:IsElemental()`

**Signature**
- `isElemental = Unit(unitID):IsElemental()`

**Return Values**
- `isElemental` (`boolean`): `Unit(unitID):CreatureType() == "Elemental"`.

**Usage Example**
```lua
if Unit("target"):IsElemental() then end
```

---

### `:IsTotem()`

**Signature**
- `isTotem = Unit(unitID):IsTotem()`

**Return Values**
- `isTotem` (`boolean`): `Unit(unitID):CreatureType() == "Totem"`.

**Intended usage**
- Skip totems in multi-unit logic and "real target" selection.

**Usage Example**
```lua
if Unit("nameplate1"):IsTotem() then
    -- Often excluded from AoE targeting logic.
end
```

---

### `:IsDummy()`

**Signature**
- `isDummy = Unit(unitID):IsDummy()`

**Return Values**
- `isDummy` (`boolean|nil`): true when the unit's NPC ID is in the internal `InfoIsDummy` map.

**Logic Explanation**
- Parses `npcID` via `Unit(unitID):InfoGUID()` and checks `InfoIsDummy[npcID]`.

**Usage Example**
```lua
if Unit("target"):IsDummy() then
    -- Target is a training dummy (per NPC ID map).
end
```

---

### `:IsBoss()`

**Signature**
- `isBoss = Unit(unitID):IsBoss()`

**Return Values**
- `isBoss` (`boolean|nil`): true when the engine identifies the unit as a boss.

**Logic Explanation**
- Parses `npcID` via `:InfoGUID()`.
- Rejects known "not boss" IDs via `InfoIsNotBoss`.
- Accepts if:
  - `InfoIsBoss[npcID]` or `LibBossIDs[npcID]` is true, or
  - `Unit(unitID):GetLevel() == -1`, or
  - the unit matches any `"boss1"`..`"bossN"` unit frame.

**Usage Example**
```lua
if Unit("target"):IsBoss() then
    -- Boss-like enemy detected.
end
```

---

### `:ThreatSituation(otherunitID)`

**Signature**
- `status, scaledPercent, threatValue = Unit(unitID):ThreatSituation(otherunitID)`

**Parameters**
- `otherunitID` (`string|nil`): unit token to evaluate threat against (defaults to `"target"` in the non-ThreatLib path).

**Return Values**
- `status` (`number`): threat situation (0-3).
- `scaledPercent` (`number`): percent of threat (0-100). May be 0 if unsupported.
- `threatValue` (`number`): raw threat value. May be 0 if unsupported.

**Logic Explanation**
- If `ThreatLib` is present, prefers cached threat data in `TeamCachethreatData[GUID]` and falls back to `UnitDetailedThreatSituation`.
- If `ThreatLib` is absent, calls `UnitDetailedThreatSituation(unitID, otherunitID or "target")` and returns `UnitThreatSituation(unitID)` plus the percent/value from the detailed call.

**Intended usage**
- Tanking/threat logic and heuristics for role detection.

**Usage Example**
```lua
local status = Unit("player"):ThreatSituation("target")
if status >= 3 then
    -- Player has solid aggro on target.
end
```

---

### `:IsTanking(otherunitID, range)`

**Signature**
- `isTanking = Unit(unitID):IsTanking(otherunitID, range)`

**Parameters**
- `otherunitID` (`string|nil`): optional unit token to check threat against (passed through to `:ThreatSituation()`).
- `range` (`number|nil`): optional range gate forwarded to `:IsTankingAoE(range)`.

**Return Values**
- `isTanking` (`boolean|nil`)

**Logic Explanation**
- Returns true if any of the following:
  - In PvP: the unit is the target of `(otherunitID or "target") .. "target"`.
  - In PvE: `Unit(unitID):ThreatSituation(otherunitID) >= 3`.
  - `Unit(unitID):IsTankingAoE(range)` is true.

**Usage Example**
```lua
if Unit("player"):IsTanking() then
    -- Treat player as tanking at least one enemy (or being targeted in PvP).
end
```

---

### `:IsTankingAoE(range)`

**Signature**
- `isTanking = Unit(unitID):IsTankingAoE(range)`

**Parameters**
- `range` (`number|nil`): when provided, only counts enemies whose target is within `range` according to `Unit(unit .. "target"):CanInterract(range)`.

**Return Values**
- `isTanking` (`boolean|nil`)

**Logic Explanation**
- Iterates active enemy nameplates (`ActiveUnitPlates`).
- For each, checks threat situation (PvE) or "is being targeted" (PvP), and optionally range-gates by the enemy's target.

**Usage Example**
```lua
if Unit("player"):IsTankingAoE(8) then
    -- Likely tanking multiple nearby enemies.
end
```

---

### `:IsPenalty()`

**Signature**
- `hasPenalty = Unit(unitID):IsPenalty()`

**Return Values**
- `hasPenalty` (`boolean`): true when `UnitLevel(unitID)` is more than 10 levels below the player (`unitLevel > 0 and unitLevel < A.PlayerLevel - 10`).

**Intended usage**
- Heuristic for healing/damage penalty handling against very low-level units.

**Usage Example**
```lua
if Unit("target"):IsPenalty() then
    -- Target is much lower level than player.
end
```

---

### `:GetLevel()`

**Signature**
- `level = Unit(unitID):GetLevel()`

**Return Values**
- `level` (`number`): `UnitLevel(unitID)` (or `0` if nil).

**Usage Example**
```lua
local level = Unit("target"):GetLevel()
```

---

### `:GetCurrentSpeed()`

**Signature**
- `currentPct, maxPct = Unit(unitID):GetCurrentSpeed()`

**Return Values**
- `currentPct` (`number`): current move speed as an integer percent (base run speed assumed as 7).
- `maxPct` (`number`): max move speed as an integer percent.

**Logic Explanation**
- Uses WoW `GetUnitSpeed(unitID)` and converts via `floor(speed / 7 * 100)`.

**Usage Example**
```lua
local currentPct = Unit("player"):GetCurrentSpeed()
```

---

### `:GetMaxSpeed()`

**Signature**
- `maxPct = Unit(unitID):GetMaxSpeed()`

**Return Values**
- `maxPct` (`number`): second return from `:GetCurrentSpeed()`.

**Usage Example**
```lua
local maxPct = Unit("target"):GetMaxSpeed()
```

---

### `:GetTotalHealAbsorbs()`

**Signature**
- `amount = Unit(unitID):GetTotalHealAbsorbs()`

**Return Values**
- `amount` (`number`): total healing absorb amount (0 if the WoW API is unavailable).

**Logic Explanation**
- Uses `UnitGetTotalHealAbsorbs(unitID)` when available.

**Usage Example**
```lua
local absorbs = Unit("player"):GetTotalHealAbsorbs()
```

---

### `:GetTotalHealAbsorbsPercent()`

**Signature**
- `pct = Unit(unitID):GetTotalHealAbsorbsPercent()`

**Return Values**
- `pct` (`number`): healing absorbs as a percent of max health.

**Usage Example**
```lua
local pct = Unit("player"):GetTotalHealAbsorbsPercent()
```

---

### `:GetDR(drCat)`

**Signature**
- `tick, remain, applications, maxApplications = Unit(unitID):GetDR(drCat)`

**Parameters**
- `drCat` (`string`): DR category string (see `:IsControlAble` notes).

**Return Values**
- `tick` (`number`): DR tick (commonly 100 -> 50 -> 25 -> 0, where 0 is fully immune).
- `remain` (`number`): seconds until DR resets (commonly 0-18).
- `applications` (`number`): how many DR applications currently counted.
- `maxApplications` (`number`): how many applications are possible in the category.

**Logic Explanation**
- Delegates to `Action.CombatTracker:GetDR(unitID, drCat)`.

**Intended usage**
- DR-aware CC planning.

**Usage Example**
```lua
local tick = Unit("arena1"):GetDR("stun")
if tick <= 25 then
    -- Heavy stun DR.
end
```

---

## Cooldowns / combat tracking / prediction

### `:GetCooldown(spellName)`

**Signature**
- `remain, start = Unit(unitID):GetCooldown(spellName)`

**Parameters**
- `spellName` (`string|number`): spell name or spellID to query (spellIDs are converted to names internally).

**Return Values**
- `remain` (`number`): remaining cooldown time (seconds), clamped at `>= 0`.
- `start` (`number`): timestamp when the cooldown was started (0 when unknown).

**Logic Explanation**
- Delegates to `A.UnitCooldown:GetCooldown(unitID, spellName)`.

**Intended usage**
- Read cooldowns tracked by the Action `UnitCooldown` engine (CLEU/UNIT_SPELLCAST* driven).

**Usage Example**
```lua
local cd = Unit("arena1"):GetCooldown("Counter Shot")
if cd > 0 then
    -- arena1's Counter Shot is on cooldown per UnitCooldown tracking.
end
```

---

### `:GetMaxDuration(spellName)`

**Signature**
- `maxCD = Unit(unitID):GetMaxDuration(spellName)`

**Parameters**
- `spellName` (`string|number`): spell name or spellID.

**Return Values**
- `maxCD` (`number`): max cooldown duration (seconds) for the tracked record (0 when unknown).

**Logic Explanation**
- Delegates to `A.UnitCooldown:GetMaxDuration(unitID, spellName)`.

**Usage Example**
```lua
local maxCD = Unit("arena1"):GetMaxDuration("Counter Shot")
```

---

### `:GetUnitID(spellName)`

**Signature**
- `casterUnitID = Unit(unitID):GetUnitID(spellName)`

**Parameters**
- `spellName` (`string|number`)

**Return Values**
- `casterUnitID` (`string|nil`): unit token of who last cast `spellName` (and is still tracked as having an active cooldown), or nil.

**Logic Explanation**
- Delegates to `A.UnitCooldown:GetUnitID(unitID, spellName)`.

**Usage Example**
```lua
local who = Unit("enemy"):GetUnitID("Counter Shot")
if who then
    -- who is the unit token that last used it (e.g., "arena2" or "nameplate5").
end
```

---

### `:GetBlinkOrShrimmer()`

**Signature**
- `charges, currentCD, sumCD = Unit(unitID):GetBlinkOrShrimmer()`

**Return Values**
- `charges` (`number`): current charge count (0-2 depending on tracking).
- `currentCD` (`number`): remaining cooldown on the next charge (seconds).
- `sumCD` (`number`): sum of remaining cooldown across all missing charges (seconds).

**Logic Explanation**
- Delegates to `A.UnitCooldown:GetBlinkOrShrimmer(unitID)`.

**Intended usage**
- Enemy mage mobility tracking (Blink/Shimmer style charge logic).

**Usage Example**
```lua
local charges = Unit("arena1"):GetBlinkOrShrimmer()
```

---

### `:IsSpellInFly(spellName)`

**Signature**
- `isFlying = Unit(unitID):IsSpellInFly(spellName)`

**Parameters**
- `spellName` (`string|number`): spell name or spellID.

**Return Values**
- `isFlying` (`boolean|nil`): true if the `UnitCooldown` tracker considers the spell "in flight".

**Logic Explanation**
- Delegates to `A.UnitCooldown:IsSpellInFly(unitID, spellName)`.

**Usage Example**
```lua
if Unit("arena1"):IsSpellInFly("Counter Shot") then
    -- Counter Shot projectile is considered in flight by the tracker.
end
```

---

### `:CombatTime()`

**Signature**
- `combatFor, unitGUID = Unit(unitID):CombatTime()`

**Return Values**
- `combatFor` (`number`): seconds since the unit entered combat (0 when not in combat or unknown).
- `unitGUID` (`string|nil`): GUID used by the combat tracker.

**Logic Explanation**
- Delegates to `A.CombatTracker:CombatTime(unitID)`.

**Usage Example**
```lua
if Unit("target"):CombatTime() > 0 then
    -- Target is in combat.
end
```

---

### `:GetLastTimeDMGX(x)`

**Signature**
- `taken = Unit(unitID):GetLastTimeDMGX(x)`

**Parameters**
- `x` (`number`): seconds window.

**Return Values**
- `taken` (`number`): damage taken amount in the last `x` seconds (engine-defined).

**Logic Explanation**
- Delegates to `A.CombatTracker:GetLastTimeDMGX(unitID, x)`.

**Usage Example**
```lua
local taken5 = Unit("player"):GetLastTimeDMGX(5)
```

---

### `:GetRealTimeDMG(index)`

**Signature**
- `a, b, c, d, e = Unit(unitID):GetRealTimeDMG(index)`

**Parameters**
- `index` (`number|nil`): when provided, returns only that index from `A.CombatTracker:GetRealTimeDMG(...)`.

**Return Values**
- When `index` is nil: values from `A.CombatTracker:GetRealTimeDMG(unitID)` (comment indicates: total, hits, physical, magic, swing).
- When `index` is provided: a single number.

**Usage Example**
```lua
local totalTaken = Unit("player"):GetRealTimeDMG(1)
```

---

### `:GetRealTimeDPS(index)`

**Signature**
- `a, b, c, d, e = Unit(unitID):GetRealTimeDPS(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetRealTimeDPS(unitID)` (comment indicates: total, hits, physical, magic, swing), or a single index when requested.

**Usage Example**
```lua
local totalDone = Unit("player"):GetRealTimeDPS(1)
```

---

### `:GetDMG(index)`

**Signature**
- `a, b, c, d = Unit(unitID):GetDMG(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetDMG(unitID)` (comment indicates: total, hits, physical, magic), or a single index when requested.

**Usage Example**
```lua
local takenTotal = Unit("player"):GetDMG(1)
```

---

### `:GetDPS(index)`

**Signature**
- `a, b, c, d = Unit(unitID):GetDPS(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetDPS(unitID)` (comment indicates: total, hits, physical, magic), or a single index when requested.

**Usage Example**
```lua
local doneTotal = Unit("player"):GetDPS(1)
```

---

### `:GetHEAL(index)`

**Signature**
- `a, b = Unit(unitID):GetHEAL(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetHEAL(unitID)` (comment indicates: total, hits), or a single index when requested.

**Usage Example**
```lua
local healTaken = Unit("player"):GetHEAL(1)
```

---

### `:GetHPS(index)`

**Signature**
- `a, b = Unit(unitID):GetHPS(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetHPS(unitID)` (comment indicates: total, hits), or a single index when requested.

**Usage Example**
```lua
local healDone = Unit("player"):GetHPS(1)
```

---

### `:GetSchoolDMG(index)`

**Signature**
- `a, b, c, d, e, f = Unit(unitID):GetSchoolDMG(index)`

**Parameters**
- `index` (`number|nil`)

**Return Values**
- Values from `A.CombatTracker:GetSchoolDMG(unitID)` (comment indicates: Holy, Fire, Nature, Frost, Shadow, Arcane). Intended "by player only".
- When `index` is provided: a single number.

**Usage Example**
```lua
local shadow = Unit("player"):GetSchoolDMG(5)
```

---

### `:GetSpellAmountX(spell, x)`

**Signature**
- `amount = Unit(unitID):GetSpellAmountX(spell, x)`

**Parameters**
- `spell` (`string|number`): spell name or spellID.
- `x` (`number`): seconds window.

**Return Values**
- `amount` (`number`): amount taken in the last `x` seconds attributed to `spell` (engine-defined).

**Logic Explanation**
- Delegates to `A.CombatTracker:GetSpellAmountX(unitID, spell, x)`.

**Usage Example**
```lua
local last10 = Unit("player"):GetSpellAmountX(116, 10) -- e.g., Frostbolt by spellID
```

---

### `:GetSpellAmount(spell)`

**Signature**
- `amount = Unit(unitID):GetSpellAmount(spell)`

**Parameters**
- `spell` (`string|number`)

**Return Values**
- `amount` (`number`): total amount taken during the tracked window attributed to `spell`.

**Logic Explanation**
- Delegates to `A.CombatTracker:GetSpellAmount(unitID, spell)`.

**Usage Example**
```lua
local total = Unit("player"):GetSpellAmount("Frostbolt")
```

---

### `:GetSpellLastCast(spell)`

**Signature**
- `since, start = Unit(unitID):GetSpellLastCast(spell)`

**Parameters**
- `spell` (`string|number`)

**Return Values**
- `since` (`number`): seconds since last cast (engine-defined).
- `start` (`number`): timestamp of that cast start (engine-defined).

**Logic Explanation**
- Delegates to `A.CombatTracker:GetSpellLastCast(unitID, spell)`.

**Usage Example**
```lua
local since = Unit("arena1"):GetSpellLastCast("Polymorph")
```

---

### `:GetSpellCounter(spell)`

**Signature**
- `count = Unit(unitID):GetSpellCounter(spell)`

**Parameters**
- `spell` (`string|number`)

**Return Values**
- `count` (`number`): number of times `spell` was cast in the tracked fight/window (engine-defined).

**Logic Explanation**
- Delegates to `A.CombatTracker:GetSpellCounter(unitID, spell)`.

**Usage Example**
```lua
if Unit("arena1"):GetSpellCounter("Penance") > 0 then
    -- arena1 has cast Penance at least once (useful for spec inference heuristics).
end
```

---

### `:GetAbsorb(spell)`

**Signature**
- `amount = Unit(unitID):GetAbsorb(spell)`

**Parameters**
- `spell` (`string|number|nil`): optional filter.

**Return Values**
- `amount` (`number`): absorb amount taken (total or filtered by spell).

**Logic Explanation**
- Delegates to `A.CombatTracker:GetAbsorb(unitID, spell)`.

**Usage Example**
```lua
local absorbs = Unit("player"):GetAbsorb()
```

---

### `:TimeToDieX(x)`

**Signature**
- `ttd = Unit(unitID):TimeToDieX(x)`

**Parameters**
- `x` (`number`): seconds window used by the tracker for slope estimation.

**Return Values**
- `ttd` (`number`): predicted time to die (seconds), engine-defined.

**Logic Explanation**
- Delegates to `A.CombatTracker:TimeToDieX(unitID, x)`.

**Usage Example**
```lua
if Unit("target"):TimeToDieX(20) < 8 then
    -- Target is predicted to die soon (based on last 20s).
end
```

---

### `:TimeToDie()`

**Signature**
- `ttd = Unit(unitID):TimeToDie()`

**Return Values**
- `ttd` (`number`): predicted time to die (seconds), engine-defined.

**Logic Explanation**
- Delegates to `A.CombatTracker:TimeToDie(unitID)`.

**Usage Example**
```lua
local ttd = Unit("target"):TimeToDie()
```

---

### `:TimeToDieMagicX(x)`

**Signature**
- `ttd = Unit(unitID):TimeToDieMagicX(x)`

**Parameters**
- `x` (`number`)

**Return Values**
- `ttd` (`number`): predicted time to die based on magic damage tracking, engine-defined.

**Logic Explanation**
- Delegates to `A.CombatTracker:TimeToDieMagicX(unitID, x)`.

**Usage Example**
```lua
local ttdMagic = Unit("player"):TimeToDieMagicX(10)
```

---

### `:TimeToDieMagic()`

**Signature**
- `ttd = Unit(unitID):TimeToDieMagic()`

**Return Values**
- `ttd` (`number`): predicted time to die based on magic damage tracking, engine-defined.

**Logic Explanation**
- Delegates to `A.CombatTracker:TimeToDieMagic(unitID)`.

**Usage Example**
```lua
local ttdMagic = Unit("player"):TimeToDieMagic()
```

---

### `:GetIncomingResurrection()`

**Signature**
- `hasIncRes = Unit(unitID):GetIncomingResurrection()`

**Return Values**
- `hasIncRes` (`boolean`): `UnitHasIncomingResurrection(unitID)`.

**Usage Example**
```lua
if Unit("player"):GetIncomingResurrection() then
    -- Someone is ressing the player.
end
```

---

### `:GetIncomingHeals(castTime, unitGUID)`

**Signature**
- `amount = Unit(unitID):GetIncomingHeals(castTime, unitGUID)`

**Parameters**
- `castTime` (`number|nil`): time horizon in seconds; if nil or `<= 0`, returns `0`.
- `unitGUID` (`string|nil`): optional GUID override.

**Return Values**
- `amount` (`number`): predicted incoming heals from others during the horizon.

**Logic Explanation**
- If `HealComm` is not available: returns `UnitGetIncomingHeals(unitID) or 0`.
- If `HealComm` is available:
  - requires `castTime > 0` and a valid GUID,
  - returns `HealComm:GetOthersHealAmount(GUID, ALL_HEALS, now + castTime) * HealComm:GetHealModifier(GUID)`.

**Intended usage**
- Healing decision-making for casts with a known time-to-land.

**Usage Example**
```lua
local inc = Unit("party1"):GetIncomingHeals(1.5)
```

---

### `:GetIncomingHealsIncSelf(castTime, unitGUID)`

**Signature**
- `amount = Unit(unitID):GetIncomingHealsIncSelf(castTime, unitGUID)`

**Parameters**
- `castTime` (`number|nil`)
- `unitGUID` (`string|nil`)

**Return Values**
- `amount` (`number`): predicted incoming heals including self during the horizon.

**Logic Explanation**
- Same as `:GetIncomingHeals`, but uses `HealComm:GetHealAmount(...)` (includes self heals).

**Usage Example**
```lua
local inc = Unit("party1"):GetIncomingHealsIncSelf(1.5)
```

---

## Range / interrupt helpers

### `:GetRange()`

**Signature**
- `maxRange, minRange = Unit(unitID):GetRange()`

**Return Values**
- `maxRange` (`number`): maximum estimated distance (yards). May be `math.huge` when unknown/out of range.
- `minRange` (`number`): minimum estimated distance (yards). May be `math.huge` when unknown.

**Logic Explanation**
- Uses `LibRangeCheck:GetRange(unitID)` (which returns `min, max`) and then returns `(max, min)` (order swapped).
- When `max` is nil: returns `math.huge, (min or math.huge)`.
- If the unit has an active nameplate and `max` is abnormally large, clamps `maxRange` to `CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE` and clamps `minRange` to not exceed that.

**Intended usage**
- Approximate yard-range checks for units (more granular than `UnitInRange`).

**Usage Example**
```lua
local maxRange, minRange = Unit("target"):GetRange()
```

---

### `:CanInterract(range, orBooleanInRange)`

**Signature**
- `ok = Unit(unitID):CanInterract(range, orBooleanInRange)`

**Parameters**
- `range` (`number|nil`): desired maximum range (yards).
- `orBooleanInRange` (`boolean|nil`): fallback "I already know I'm in range" boolean.

**Return Values**
- `ok` (`boolean`): true when the unit is definitely in range under the conservative engine check.

**Logic Explanation**
- Reads `maxRange` via `Unit(unitID):GetRange()` (first return value).
- Returns true when:
  - `maxRange > 0`, and
  - either:
    - `range` is provided and `maxRange <= range`, or
    - `orBooleanInRange` is true.

**Intended usage**
- Conservative "safe to press" gating for melee-range interactions, taunts, etc.

**Usage Example**
```lua
if Unit("target"):CanInterract(5) then
    -- Target is confidently within 5 yards (per GetRange maxRange).
end
```

---

### `:CanInterrupt(kickAble, auras, minX, maxX)`

**Signature**
- `ok = Unit(unitID):CanInterrupt(kickAble, auras, minX, maxX)`

**Parameters**
- `kickAble` (`boolean|nil`): when true, requires the cast to be interruptable (`notInterruptable == false`).
- `auras` (`any|nil`): when provided, blocks interrupts if `Unit(unitID):HasBuffs(auras) > 0` (commonly an immunity list).
- `minX` (`number|nil`): min percent threshold (default `34`).
- `maxX` (`number|nil`): max percent threshold (default `68`).

**Return Values**
- `ok` (`boolean|nil`): true when the unit is casting and the random interrupt threshold has been reached.

**Logic Explanation**
- Reads cast info via `:IsCasting()`.
- Uses a per-GUID cache (`InfoCacheInterrupt[GUID]`) to store:
  - `LastCast` and a random `Timer` percent threshold.
- Resets the random threshold when a new cast name is observed.
- Returns true when `castPercent >= Timer`.

**Intended usage**
- Interrupt logic that avoids always interrupting at a fixed percent (humanized random timing).

**Usage Example**
```lua
if Unit("target"):CanInterrupt(true, "KickImun") then
    -- Target is casting and is past the randomized interrupt threshold.
end
```

---

### `:CanCooperate(otherunit)`

**Signature**
- `ok = Unit(unitID):CanCooperate(otherunit)`

**Parameters**
- `otherunit` (`string`): unit token to test cooperation with.

**Return Values**
- `ok` (`boolean`): `UnitCanCooperate(unitID, otherunit)`.

**Usage Example**
```lua
if Unit("player"):CanCooperate("party1") then
    -- party1 is cooperative with player.
end
```

---

## Specs / flags / health / power

### `:HasSpec(specID)`

**Signature**
- `ok = Unit(unitID):HasSpec(specID)`

**Parameters**
- `specID` (`number|table`): a specialization ID (or an array of specIDs).

**Return Values**
- `ok` (`boolean|nil`): true if the unit is inferred to match one of the provided specIDs.

**Logic Explanation**
- For `"player"`:
  - Compares against `A.PlayerSpec`.
  - If `specID` is a table, returns true if any entry matches.
- For other units:
  - Resolves `UnitName(unitID)` (including `name-server`).
  - If `UnitSpecsMap[name]` exists, compares against that.
  - Otherwise tries heuristics:
    - Buff-based inference via `InfoClassSpecBuffs[class][specID]` and `:HasBuffs(...)`.
    - Spell-usage inference via `InfoClassSpecSpells[class][specID]` and `:GetSpellCounter(spellID) > 0` (comment notes this is intended for PvP and may not work in PvE).

**Intended usage**
- Spec inference for enemy players when direct spec inspection is not available.

**Usage Example**
```lua
if Unit("arena1"):HasSpec(1) then
    -- arena1 matches specID 1 by the engine's inference rules.
end
```

---

### `:HasFlags()`

**Signature**
- `hasFlags = Unit(unitID):HasFlags()`

**Return Values**
- `hasFlags` (`boolean`): `Unit(unitID):HasBuffs(AuraList.Flags) > 0`.

**Intended usage**
- Battleground flag carrier detection (engine-defined aura list).

**Usage Example**
```lua
if Unit("player"):HasFlags() then
    -- Player is carrying a flag (per AuraList.Flags).
end
```

---

### `:Health()`

**Signature**
- `hp = Unit(unitID):Health()`

**Return Values**
- `hp` (`number`): unit health, as provided by `A.CombatTracker:UnitHealth(unitID)`.

**Logic Explanation**
- Delegates to the combat tracker (not directly to `UnitHealth`).

**Usage Example**
```lua
local hp = Unit("target"):Health()
```

---

### `:HealthMax()`

**Signature**
- `maxHP = Unit(unitID):HealthMax()`

**Return Values**
- `maxHP` (`number`): unit max health, as provided by `A.CombatTracker:UnitHealthMax(unitID)`.

**Usage Example**
```lua
local maxHP = Unit("target"):HealthMax()
```

---

### `:HealthDeficit()`

**Signature**
- `missing = Unit(unitID):HealthDeficit()`

**Return Values**
- `missing` (`number`): `HealthMax() - Health()`.

**Usage Example**
```lua
local missing = Unit("party1"):HealthDeficit()
```

---

### `:HealthDeficitPercent()`

**Signature**
- `missingPct = Unit(unitID):HealthDeficitPercent()`

**Return Values**
- `missingPct` (`number`): `100 - HealthPercent()`.

**Usage Example**
```lua
local missingPct = Unit("party1"):HealthDeficitPercent()
```

---

### `:HealthPercent()`

**Signature**
- `hpPct = Unit(unitID):HealthPercent()`

**Return Values**
- `hpPct` (`number`): health percent (0-100) when the tracker considers the unit to have real health; otherwise returns `UnitHealth(unitID)` directly.

**Logic Explanation**
- If `A.CombatTracker:UnitHasRealHealth(unitID)`:
  - Computes `UnitHealth(unitID) * 100 / UnitHealthMax(unitID)` (guarding against maxHP==0).
- Else returns `UnitHealth(unitID)` (used as a fallback in some environments).

**Usage Example**
```lua
if Unit("player"):HealthPercent() < 30 then
    -- Low health.
end
```

---

### `:HealthPercentLosePerSecond()`

**Signature**
- `losePerSec = Unit(unitID):HealthPercentLosePerSecond()`

**Return Values**
- `losePerSec` (`number`): net percent lost per second (>=0), computed as `max((DMG%/sec) - (HEAL%/sec), 0)`.

**Logic Explanation**
- Uses `GetDMG()` and `GetHEAL()` as tracker-provided per-second rates.

**Usage Example**
```lua
local lose = Unit("player"):HealthPercentLosePerSecond()
```

---

### `:HealthPercentGainPerSecond()`

**Signature**
- `gainPerSec = Unit(unitID):HealthPercentGainPerSecond()`

**Return Values**
- `gainPerSec` (`number`): net percent gained per second (>=0), computed as `max((HEAL%/sec) - (DMG%/sec), 0)`.

**Usage Example**
```lua
local gain = Unit("player"):HealthPercentGainPerSecond()
```

---

### `:Power()`

**Signature**
- `power = Unit(unitID):Power()`

**Return Values**
- `power` (`number`): `UnitPower(unitID)`.

**Usage Example**
```lua
local power = Unit("player"):Power()
```

---

### `:PowerType()`

**Signature**
- `powerToken = Unit(unitID):PowerType()`

**Return Values**
- `powerToken` (`string`): second return from `UnitPowerType(unitID)` (e.g., `"MANA"`, `"RAGE"`, `"ENERGY"`).

**Usage Example**
```lua
local powerToken = Unit("player"):PowerType()
```

---

### `:PowerMax()`

**Signature**
- `maxPower = Unit(unitID):PowerMax()`

**Return Values**
- `maxPower` (`number`): `UnitPowerMax(unitID)`.

**Usage Example**
```lua
local maxPower = Unit("player"):PowerMax()
```

---

### `:PowerDeficit()`

**Signature**
- `missing = Unit(unitID):PowerDeficit()`

**Return Values**
- `missing` (`number`): `PowerMax() - Power()`.

**Usage Example**
```lua
local missing = Unit("player"):PowerDeficit()
```

---

### `:PowerDeficitPercent()`

**Signature**
- `missingPct = Unit(unitID):PowerDeficitPercent()`

**Return Values**
- `missingPct` (`number`): `(PowerDeficit() * 100) / PowerMax()`.

**Usage Example**
```lua
local missingPct = Unit("player"):PowerDeficitPercent()
```

---

### `:PowerPercent()`

**Signature**
- `pct = Unit(unitID):PowerPercent()`

**Return Values**
- `pct` (`number`): `(Power() * 100) / PowerMax()`.

**Usage Example**
```lua
local pct = Unit("player"):PowerPercent()
```

---

## Aura helpers (buffs / debuffs)

### `:AuraTooltipNumberByIndex(spell, filter, caster, byID, kindKey, requestedIndex)`

**Signature**
- `n = Unit(unitID):AuraTooltipNumberByIndex(spell, filter, caster, byID, kindKey, requestedIndex)`

**Parameters**
- `spell` (`any`): spell selector used with the internal associative tables (commonly a spellID, spell name, or a prebuilt list).
- `filter` (`string|nil`): aura filter string passed to `UnitAura` (defaults to `"HELPFUL"`).
- `caster` (`string|nil`): value forwarded to `AuraTooltipNumberPacked` (used to identify the correct aura instance in some cases).
- `byID` (`boolean|nil`): whether to match by spellID instead of spell name.
- `kindKey` (`string|nil`): key used by `AuraTooltipNumberPacked` to identify the aura instance (defaults based on `filter`).
- `requestedIndex` (`number|nil`): tooltip number index (defaults to `1`).

**Return Values**
- `n` (`number`): parsed tooltip number (0 if not found).

**Logic Explanation**
- Iterates auras via `UnitAura(unitID, i, filter)` and finds the first aura that matches `spell` (via `IsAuraEqual` + `AssociativeTables`).
- Calls `AuraTooltipNumberPacked(unitID, auraNameLower, kindKey, caster, requestedIndex)` to read a number from the aura tooltip.

**Intended usage**
- Extract numeric values from aura tooltips (absorb amounts, special aura values) when the value is not exposed via standard API fields.

**Usage Example**
```lua
local absorb = Unit("player"):AuraTooltipNumberByIndex("Power Word: Shield", "HELPFUL")
```

---

### `:AuraVariableNumber(spell, filter, caster, byID)`

**Signature**
- `n = Unit(unitID):AuraVariableNumber(spell, filter, caster, byID)`

**Parameters**
- `spell` (`any`)
- `filter` (`string|nil`): defaults to `"HELPFUL"`.
- `caster` (`boolean|nil`): when true, only accepts auras where `sourceUnit` is `"player"`.
- `byID` (`boolean|nil`)

**Return Values**
- `n` (`number`): first positive value found in the aura's `points[]` array, or `0`.

**Logic Explanation**
- Finds the first matching aura via `UnitAura`.
- When `caster` is true, requires `UnitIsUnit("player", aura.sourceUnit)`.
- Returns the first `> 0` value in `aura.points`.

**Usage Example**
```lua
local v = Unit("player"):AuraVariableNumber("Some Proc", "HELPFUL", true)
```

---

### `:DeBuffCyclone()`

**Signature**
- `remain = Unit(unitID):DeBuffCyclone()`

**Return Values**
- `remain` (`number`): currently always `0` (placeholder; comment notes it may change in future).

**Usage Example**
```lua
local cyclone = Unit("arena1"):DeBuffCyclone()
```

---

### `:GetDeBuffInfo(auraTable, caster)`

**Signature**
- `rank, remain, total, stacks = Unit(unitID):GetDeBuffInfo(auraTable, caster)`

**Parameters**
- `auraTable` (`table`): map of `spellID/spellName -> rank` (example: `{ [12345] = 1, ["Some Debuff"] = 2 }`).
- `caster` (`boolean|nil`): when true, uses `"HARMFUL PLAYER"` filtering (debuffs applied by player).

**Return Values**
- `rank` (`number`)
- `remain` (`number`): seconds remaining (may be `math.huge` for permanent/unknown duration).
- `total` (`number`): total aura duration.
- `stacks` (`number`): aura stack count.

**Logic Explanation**
- Iterates `UnitAura(unitID, i, filter)` and returns the first match by spellID or spellName present in `auraTable`.

**Usage Example**
```lua
local rank, remain = Unit("target"):GetDeBuffInfo({ ["Shadow Word: Pain"] = 1 }, true)
```

---

### `:GetDeBuffInfoByName(auraName, caster)`

**Signature**
- `spellID, remain, total, stacks = Unit(unitID):GetDeBuffInfoByName(auraName, caster)`

**Parameters**
- `auraName` (`string`): exact aura name match.
- `caster` (`boolean|nil`): when true, uses `"HARMFUL PLAYER"`.

**Return Values**
- `spellID` (`number`)
- `remain` (`number`)
- `total` (`number`)
- `stacks` (`number`)

**Logic Explanation**
- Iterates debuffs and matches by exact `spellName == auraName`.

**Usage Example**
```lua
local spellID, remain = Unit("target"):GetDeBuffInfoByName("Shadow Word: Pain", true)
```

---

### `:IsDeBuffsLimited()`

**Signature**
- `limited, count = Unit(unitID):IsDeBuffsLimited()`

**Return Values**
- `limited` (`boolean`): true when the unit appears to be at/over `CONST.AURAS_MAX_LIMIT`.
- `count` (`number`): number of debuffs observed up to the limit.

**Logic Explanation**
- Counts `UnitDebuff(unitID, i)` up to `CONST.AURAS_MAX_LIMIT`.

**Intended usage**
- Detect when the aura limit may hide additional debuffs (important for reliable debuff scanning).

**Usage Example**
```lua
local limited = Unit("target"):IsDeBuffsLimited()
```

---

### `:SortDeBuffs(spell, caster, byID)` (alias: `:HasDeBuffs(...)`)

**Signature**
- `remain, total = Unit(unitID):SortDeBuffs(spell, caster, byID)`
- `remain, total = Unit(unitID):HasDeBuffs(spell, caster, byID)` (alias)

**Parameters**
- `spell` (`any`): spell selector (single or list; used with `AssociativeTables`).
- `caster` (`boolean|nil`): when true, uses `"HARMFUL PLAYER"`.
- `byID` (`boolean|nil`): match by spellID instead of spell name.

**Return Values**
- `remain` (`number`): highest remaining duration found (may be `math.huge`).
- `total` (`number`): corresponding total duration.

**Logic Explanation**
- Iterates debuffs and checks membership in `AssociativeTables[spell]`.
- Keeps the match with the largest remaining duration.
- Stops early when:
  - it finds a permanent aura (`remain == math.huge`), or
  - it has updated the "best" match enough times (1 for single spell, up to 3 for list-style queries).

**Intended usage**
- Fast debuff checks that handle duplicates and return a stable "best" duration.

**Usage Example**
```lua
local remain = Unit("target"):HasDeBuffs("Shadow Word: Pain", true)
```

---

### `:HasDeBuffsStacks(spell, caster, byID)`

**Signature**
- `stacks = Unit(unitID):HasDeBuffsStacks(spell, caster, byID)`

**Parameters**
- `spell` (`any`)
- `caster` (`boolean|nil`)
- `byID` (`boolean|nil`)

**Return Values**
- `stacks` (`number`): stack count (returns `1` when the aura exists with `0` stacks, else the stack count). Returns `0` if the aura is missing.

**Usage Example**
```lua
local stacks = Unit("target"):HasDeBuffsStacks("Weakened Armor")
```

---

### `:PT(spell, debuff, byID)` (Pandemic threshold)

**Signature**
- `ok = Unit(unitID):PT(spell, debuff, byID)`

**Parameters**
- `spell` (`any`)
- `debuff` (`boolean|nil`):
  - `true`: checks `"HARMFUL PLAYER"` (player-applied debuff).
  - `nil/false`: checks `"HELPFUL"` (buff).
- `byID` (`boolean|nil`)

**Return Values**
- `ok` (`boolean`): true when the aura is missing or has `remaining/total <= 0.3`.

**Logic Explanation**
- Computes the remaining ratio for the matching aura and returns true when it is `<= 0.3`.
- If the aura is not found, the function returns true (treated as "refreshable").

**Usage Example**
```lua
if Unit("target"):PT("Shadow Word: Pain", true) then
    -- SW:P is missing or in pandemic window.
end
```

---

### `:GetBuffInfo(auraTable, caster)`

**Signature**
- `rank, remain, total, stacks = Unit(unitID):GetBuffInfo(auraTable, caster)`

**Parameters**
- `auraTable` (`table`): map of `spellID/spellName -> rank`.
- `caster` (`boolean|nil`): when true, uses `"HELPFUL PLAYER"`.

**Return Values**
- `rank` (`number`)
- `remain` (`number`)
- `total` (`number`)
- `stacks` (`number`)

**Usage Example**
```lua
local rank, remain = Unit("player"):GetBuffInfo({ ["Power Infusion"] = 1 }, true)
```

---

### `:GetBuffInfoByName(auraName, caster)`

**Signature**
- `spellID, remain, total, stacks = Unit(unitID):GetBuffInfoByName(auraName, caster)`

**Parameters**
- `auraName` (`string`)
- `caster` (`boolean|nil`): when true, uses `"HELPFUL PLAYER"`.

**Return Values**
- `spellID` (`number`)
- `remain` (`number`)
- `total` (`number`)
- `stacks` (`number`)

**Usage Example**
```lua
local spellID, remain = Unit("player"):GetBuffInfoByName("Power Infusion", true)
```

---

### `:HasBuffs(spell, caster, byID)`

**Signature**
- `remain, total = Unit(unitID):HasBuffs(spell, caster, byID)`

**Parameters**
- `spell` (`any`)
- `caster` (`boolean|nil`): when true, uses `"HELPFUL PLAYER"`.
- `byID` (`boolean|nil`)

**Return Values**
- `remain` (`number`)
- `total` (`number`)

**Logic Explanation**
- Scans auras and returns the first match (not sorted).

**Usage Example**
```lua
local remain = Unit("player"):HasBuffs("Power Infusion", true)
```

---

### `:SortBuffs(spell, caster, byID)`

**Signature**
- `remain, total = Unit(unitID):SortBuffs(spell, caster, byID)`

**Parameters**
- `spell` (`any`)
- `caster` (`boolean|nil`)
- `byID` (`boolean|nil`)

**Return Values**
- `remain` (`number`): highest remaining duration found.
- `total` (`number`): corresponding total duration.

**Logic Explanation**
- Similar to `:SortDeBuffs`, but scans `"HELPFUL"` auras.

**Usage Example**
```lua
local remain = Unit("player"):SortBuffs("Power Infusion", true)
```

---

### `:HasBuffsStacks(spell, caster, byID)`

**Signature**
- `stacks = Unit(unitID):HasBuffsStacks(spell, caster, byID)`

**Parameters**
- `spell` (`any`)
- `caster` (`boolean|nil`)
- `byID` (`boolean|nil`)

**Return Values**
- `stacks` (`number`): stack count (returns `1` when aura exists with `0` stacks). Returns `0` if missing.

**Usage Example**
```lua
local stacks = Unit("player"):HasBuffsStacks("Evocation", true)
```

---

## Focus / burst / defensives heuristics

### `:IsFocused(burst, deffensive, range, isMelee)`

**Signature**
- `focused = Unit(unitID):IsFocused(burst, deffensive, range, isMelee)`

**Parameters**
- `burst` (`number|nil`): minimum remaining duration of `"DamageBuffs"` on the focuser (seconds).
- `deffensive` (`number|nil`): maximum allowed remaining duration of `"DeffBuffs"` on `unitID` (seconds).
- `range` (`number|nil`): maximum allowed `Unit(focuser):GetRange()` (yards).
- `isMelee` (`boolean|nil`): when true, only considers melee focusers (`:IsMelee()`); otherwise uses `:IsDamager()`.

**Return Values**
- `focused` (`boolean|nil`): true when a valid focuser is found.

**Logic Explanation**
- If `unitID` is enemy:
  - Iterates friendly team members (from `TeamCacheFriendly`) that are not `"player"`.
  - A member "focuses" when `member .. "target"` is `unitID` and role filters pass.
- If `unitID` is friendly:
  - Iterates enemy arena units (from `TeamCacheEnemy`) or active nameplates as a fallback.
  - A focuser "focuses" when `arena .. "target"` is `unitID` and role filters pass.
- Optional gates:
  - Focuser must be damager/melee as selected.
  - Focuser must have `"DamageBuffs" >= burst` (if provided).
  - Target must have `"DeffBuffs" <= deffensive` (if provided).
  - Focuser must be within `range` per `GetRange` (if provided).

**Intended usage**
- Identify when a unit is being trained by damage dealers (PvP focus detection).

**Usage Example**
```lua
if Unit("player"):IsFocused(3, 0, 20, true) then
    -- Player is likely being focused by melee with at least 3s of DamageBuffs remaining,
    -- and player has <= 0s of DeffBuffs remaining.
end
```

---

### `:IsExecuted()`

**Signature**
- `executed = Unit(unitID):IsExecuted()`

**Return Values**
- `executed` (`boolean`): true when `Unit(unitID):TimeToDieX(20) <= A.GetGCD() + A.GetCurrentGCD()`.

**Intended usage**
- "About to die" heuristic used to trigger burst heals/defensives.

**Usage Example**
```lua
if Unit("player"):IsExecuted() then
    -- Player is predicted to die very soon.
end
```

---

### `:UseBurst(pBurst)`

**Signature**
- `ok = Unit(unitID):UseBurst(pBurst)`

**Parameters**
- `pBurst` (`boolean|nil`): when true, also allows bursting when the player has `"DamageBuffs"` active for at least `3 * GCD`.

**Return Values**
- `ok` (`boolean|nil`): whether the engine recommends using "burst" logic on this unit.

**Logic Explanation**
- If `unitID` is enemy:
  - Requires `Unit(unitID):IsPlayer()`.
  - Returns true when any of the following are true (engine heuristics):
    - non-PvP zone (`A.Zone == "none"`),
    - short time-to-die windows,
    - healer vulnerability signals (no defensives, silence/stun debuffs),
    - focus/CC conditions (enemy healer CC, focus detection),
    - optional player-burst gate (`pBurst` + player damage buffs).
- If the player is a healer (`A.IamHealer`) and `unitID` is friendly:
  - Uses a different heuristic intended for healing burst (executed/focused/flag-carrier pressure).

**Intended usage**
- High-level "should I press burst cooldowns now for this target?" gate.
- Note that this is a heuristic; its exact conditions are tuned for the engine's PvP/PvE assumptions.

**Usage Example**
```lua
if Unit("arena1"):UseBurst(true) then
    -- Recommended to burst into arena1.
end
```

---

### `:UseDeff()`

**Signature**
- `ok = Unit(unitID):UseDeff()`

**Return Values**
- `ok` (`boolean`): whether the engine recommends using defensives on this unit.

**Logic Explanation**
- Returns true when any of:
  - `Unit(unitID):IsExecuted()`
  - `Unit(unitID):IsFocused(4)`
  - `Unit(unitID):TimeToDie() < 8` and `Unit(unitID):IsFocused()` (any focus)

**Usage Example**
```lua
if Unit("player"):UseDeff() then
    -- Use defensives.
end
```

---

## Team helpers (`Action.FriendlyTeam` / `Action.EnemyTeam`)

These are pseudo-class singletons like `Action.Unit`: do not store them in locals. Always call `A.FriendlyTeam(role)` / `A.EnemyTeam(role)` inline.

### `Action.FriendlyTeam:New(ROLE, Refresh)`

**Signature**
- `A.FriendlyTeam:New(ROLE, Refresh)`

**Parameters**
- `ROLE` (`string|nil`): role filter used by the helper methods. Accepted values (as implemented by `CheckUnitByRole`):
  - `nil` (no filter)
  - `"HEALER"`, `"TANK"`, `"DAMAGER"`, `"DAMAGER_MELEE"`, `"DAMAGER_RANGE"`
- `Refresh` (`number|nil`): cache TTL in seconds (defaults to `0.05`).

**Return Values**
- (no return)

**Logic Explanation**
- Stores `self.ROLE = ROLE` and `self.Refresh = Refresh or 0.05`.

**Usage Example**
```lua
-- Normally you call A.FriendlyTeam("HEALER") and then a method.
local unitID = A.FriendlyTeam("HEALER"):GetUnitID()
```

### `A.FriendlyTeam(role[, refresh])`

**Signature**
- `t = A.FriendlyTeam(role[, refresh])`

**Parameters**
- `role` (`string|nil`)
- `refresh` (`number|nil`)

**Return Values**
- `t` (`table`): the FriendlyTeam pseudo-class object mutated to use that role filter.

**Usage Example**
```lua
local unitID = A.FriendlyTeam("TANK"):GetUnitID()
```

---

### `:GetUnitID(range)`

**Signature**
- `unitID = A.FriendlyTeam(role):GetUnitID(range)`

**Parameters**
- `range` (`number|nil`): optional max range (yards).

**Return Values**
- `unitID` (`string`): first matching friendly member unit token, or `"none"`.

**Logic Explanation**
- Iterates cached friendly player members (`TeamCacheFriendlyIndexToPLAYERs`).
- Requires:
  - role filter match (`CheckUnitByRole`),
  - not dead,
  - `:InRange()` true,
  - optional `:GetRange() <= range`.

**Usage Example**
```lua
local healer = A.FriendlyTeam("HEALER"):GetUnitID(40)
```

---

### `:GetCC(spells)`

**Signature**
- `remain, unitID = A.FriendlyTeam(role):GetCC(spells)`

**Parameters**
- `spells` (`any|nil`): if provided, checks `Unit(unitID):HasDeBuffs(spells)`. If nil, uses `Unit(unitID):InCC()`.

**Return Values**
- `remain` (`number`): CC remaining duration (seconds), or 0.
- `unitID` (`string`): member token, or `"none"`.

**Usage Example**
```lua
local remain, who = A.FriendlyTeam(nil):GetCC()
```

---

### `:GetBuffs(spells, range, source)`

**Signature**
- `remain, unitID = A.FriendlyTeam(role):GetBuffs(spells, range, source)`

**Parameters**
- `spells` (`any`): passed to `Unit(unitID):HasBuffs(spells, source)`.
- `range` (`number|nil`)
- `source` (`boolean|nil`): forwarded to `:HasBuffs(...)` as its `caster` flag (`true` means "PLAYER" filtering).

**Return Values**
- `remain` (`number`): remaining duration (seconds), or 0.
- `unitID` (`string`): member token, or `"none"`.

**Usage Example**
```lua
local remain, who = A.FriendlyTeam("DAMAGER"):GetBuffs("DamageBuffs", 40)
```

---

### `:GetDeBuffs(spells, range)`

**Signature**
- `remain, unitID = A.FriendlyTeam(role):GetDeBuffs(spells, range)`

**Parameters**
- `spells` (`any`): passed to `Unit(unitID):HasDeBuffs(spells)`.
- `range` (`number|nil`)

**Return Values**
- `remain` (`number`)
- `unitID` (`string`)

**Usage Example**
```lua
local remain, who = A.FriendlyTeam("HEALER"):GetDeBuffs("Stuned", 40)
```

---

### `:GetTTD(count, seconds, range)`

**Signature**
- `ok, n, unitID = A.FriendlyTeam(role):GetTTD(count, seconds, range)`

**Parameters**
- `count` (`number`): how many members must meet the condition.
- `seconds` (`number`): TTD threshold.
- `range` (`number|nil`)

**Return Values**
- `ok` (`boolean`): true when at least `count` members have `TimeToDie() <= seconds`.
- `n` (`number`): how many members matched.
- `unitID` (`string`): the unitID of the last matching member (or `"none"`).

**Usage Example**
```lua
local ok, n = A.FriendlyTeam(nil):GetTTD(2, 8, 40)
```

---

### `:AverageTTD(range)`

**Signature**
- `avg, n = A.FriendlyTeam(role):AverageTTD(range)`

**Parameters**
- `range` (`number|nil`)

**Return Values**
- `avg` (`number`): average `TimeToDie()` across matching members.
- `n` (`number`): number of members considered.

**Usage Example**
```lua
local avg, n = A.FriendlyTeam("DAMAGER"):AverageTTD()
```

---

### `:MissedBuffs(spells, source)`

**Signature**
- `ok, unitID = A.FriendlyTeam(role):MissedBuffs(spells, source)`

**Parameters**
- `spells` (`any`): passed to `Unit(unitID):HasBuffs(spells, source)`.
- `source` (`boolean|nil`): forwarded as `caster` flag.

**Return Values**
- `ok` (`boolean`): true if a matching member is missing the buff.
- `unitID` (`string`): member token, or `"none"`.

**Usage Example**
```lua
local ok, who = A.FriendlyTeam(nil):MissedBuffs("DeffBuffs")
```

---

### `:PlayersInCombat(range, combatTime)`

**Signature**
- `ok, unitID = A.FriendlyTeam(role):PlayersInCombat(range, combatTime)`

**Parameters**
- `range` (`number|nil`)
- `combatTime` (`number|nil`): if provided, also requires `CombatTime() <= combatTime` (i.e., "recently entered combat").

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Usage Example**
```lua
local ok, who = A.FriendlyTeam(nil):PlayersInCombat(40, 10)
```

---

### `:HealerIsFocused(burst, deffensive, range, isMelee)`

**Signature**
- `ok, unitID = A.FriendlyTeam(role):HealerIsFocused(burst, deffensive, range, isMelee)`

**Parameters**
- `burst` (`number|nil`)
- `deffensive` (`number|nil`)
- `range` (`number|nil`)
- `isMelee` (`boolean|nil`)

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Logic Explanation**
- Ignores the instance's `ROLE` and instead searches for friendly healers (`CheckUnitByRole("HEALER", member)`).
- Returns the first healer that is in range and satisfies `Unit(member):IsFocused(...)`.

**Usage Example**
```lua
local ok, healer = A.FriendlyTeam(nil):HealerIsFocused(3, 0, 40, true)
```

---

### `Action.EnemyTeam:New(ROLE, Refresh)`

**Signature**
- `A.EnemyTeam:New(ROLE, Refresh)`

**Parameters**
- `ROLE` (`string|nil`): same accepted values as `FriendlyTeam`.
- `Refresh` (`number|nil`): cache TTL in seconds (defaults to `0.05`).

**Return Values**
- (no return)

**Logic Explanation**
- Stores `self.ROLE = ROLE` and `self.Refresh = Refresh or 0.05`.

**Usage Example**
```lua
local unitID = A.EnemyTeam("HEALER"):GetUnitID()
```

### `A.EnemyTeam(role[, refresh])`

**Signature**
- `t = A.EnemyTeam(role[, refresh])`

**Usage Example**
```lua
local unitID = A.EnemyTeam("HEALER"):GetUnitID(40)
```

---

### `:GetUnitID(range)`

**Signature**
- `unitID = A.EnemyTeam(role):GetUnitID(range)`

**Parameters**
- `range` (`number|nil`): optional max range (yards). Requires `GetRange() > 0` when range filtering is used.

**Return Values**
- `unitID` (`string`): first matching enemy arena unitID, or `"none"`.

**Usage Example**
```lua
local healer = A.EnemyTeam("HEALER"):GetUnitID(40)
```

---

### `:GetCC(spells)`

**Signature**
- `remain, unitID = A.EnemyTeam(role):GetCC(spells)`

**Parameters**
- `spells` (`any|nil`): if provided, checks `:HasDeBuffs(spells)`, otherwise `:InCC()`.

**Return Values**
- `remain` (`number`)
- `unitID` (`string`)

**Logic Explanation**
- If `ROLE == "HEALER"`, skips the healer if it is the current `"target"` (engine rule to avoid counting kill target).

**Usage Example**
```lua
local remain, who = A.EnemyTeam("HEALER"):GetCC()
```

---

### `:GetBuffs(spells, range, source)`

**Signature**
- `remain, unitID = A.EnemyTeam(role):GetBuffs(spells, range, source)`

**Parameters**
- `spells` (`any`)
- `range` (`number|nil`)
- `source` (`boolean|nil`): forwarded as the `caster` flag to `:HasBuffs(...)`.

**Return Values**
- `remain` (`number`)
- `unitID` (`string`)

**Usage Example**
```lua
local remain, who = A.EnemyTeam(nil):GetBuffs("DeffBuffs", 40)
```

---

### `:GetDeBuffs(spells, range)`

**Signature**
- `remain, unitID = A.EnemyTeam(role):GetDeBuffs(spells, range)`

**Parameters**
- `spells` (`any`)
- `range` (`number|nil`)

**Return Values**
- `remain` (`number`)
- `unitID` (`string`)

**Usage Example**
```lua
local remain, who = A.EnemyTeam(nil):GetDeBuffs("Stuned", 40)
```

---

### `:GetTTD(count, seconds, range)`

**Signature**
- `ok, n, unitID = A.EnemyTeam(role):GetTTD(count, seconds, range)`

**Parameters**
- `count` (`number`)
- `seconds` (`number`)
- `range` (`number|nil`)

**Return Values**
- `ok` (`boolean`)
- `n` (`number`)
- `unitID` (`string`)

**Usage Example**
```lua
local ok, n = A.EnemyTeam(nil):GetTTD(2, 10, 40)
```

---

### `:AverageTTD(range)`

**Signature**
- `avg, n = A.EnemyTeam(role):AverageTTD(range)`

**Parameters**
- `range` (`number|nil`)

**Return Values**
- `avg` (`number`)
- `n` (`number`)

**Logic Explanation**
- Sums `TimeToDie()` across matching enemies and divides by the count.
- Note: In the current implementation, the counter variable is named `arenas` (not declared locally in the function), which may cause a runtime error if `arenas` is nil.

**Usage Example**
```lua
local avg, n = A.EnemyTeam("DAMAGER"):AverageTTD(40)
```

---

### `:IsBreakAble(range)`

**Signature**
- `ok, unitID = A.EnemyTeam(role):IsBreakAble(range)`

**Parameters**
- `range` (`number|nil`)

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Logic Explanation**
- Finds an enemy player (arena or nameplate fallback) with `:HasDeBuffs("BreakAble") ~= 0` that is not your current `"target"`.

**Usage Example**
```lua
local ok, who = A.EnemyTeam(nil):IsBreakAble(40)
```

---

### `:PlayersInRange(stop, range)`

**Signature**
- `ok, count, unitID = A.EnemyTeam(role):PlayersInRange(stop, range)`

**Parameters**
- `stop` (`number|nil`): stop and return true when `count >= stop`. If nil, returns true on the first match.
- `range` (`number|nil`)

**Return Values**
- `ok` (`boolean`)
- `count` (`number`)
- `unitID` (`string`)

**Usage Example**
```lua
local ok, count = A.EnemyTeam("DAMAGER"):PlayersInRange(2, 40)
```

---

### `:FocusingUnitIDByClasses(unitID, stop, range, ...)`

**Signature**
- `ok, count, who = A.EnemyTeam(role):FocusingUnitIDByClasses(unitID, stop, range, ...)`

**Parameters**
- `unitID` (`string`): unit being focused (the enemy's `arena .. "target"` must equal this).
- `stop` (`number|nil`)
- `range` (`number|nil`)
- `...` (`string`): one or more class tokens (e.g., `"WARRIOR"`, `"ROGUE"`).

**Return Values**
- `ok` (`boolean`)
- `count` (`number`)
- `who` (`string`): last focuser found, or `"none"`.

**Usage Example**
```lua
local ok, count = A.EnemyTeam(nil):FocusingUnitIDByClasses("player", 2, 40, "WARRIOR", "ROGUE")
```

---

### `:HasInvisibleUnits(checkVisible)`

**Signature**
- `ok, unitID, class = A.EnemyTeam(role):HasInvisibleUnits(checkVisible)`

**Parameters**
- `checkVisible` (`boolean|nil`): when true, only returns rogues/druids that are not visible.

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`): enemy unit token, or `"none"`.
- `class` (`string`): class token, or `"none"`.

**Usage Example**
```lua
local ok, who, class = A.EnemyTeam(nil):HasInvisibleUnits(true)
```

---

### `:IsTauntPetAble(object, range)`

**Signature**
- `ok, unitID = A.EnemyTeam(role):IsTauntPetAble(object, range)`

**Parameters**
- `object` (`table|nil`): an Action object with `:IsInRange(unitID)` (typically a taunt spell).
- `range` (`number|nil`): present in the signature but not used by the current implementation.

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`): pet unit token, or `"none"`.

**Usage Example**
```lua
local ok, pet = A.EnemyTeam(nil):IsTauntPetAble(A.Taunt)
```

---

### `:IsCastingBreakAble(offset)`

**Signature**
- `ok, unitID = A.EnemyTeam(role):IsCastingBreakAble(offset)`

**Parameters**
- `offset` (`number|nil`): seconds before cast end to consider (defaults to `0.5`).

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Logic Explanation**
- Finds an enemy whose cast is about to finish and matches entries in `AuraList.Premonition` (by cast name and a per-entry range check).

**Usage Example**
```lua
local ok, who = A.EnemyTeam(nil):IsCastingBreakAble(0.3)
```

---

### `:IsReshiftAble(offset)`

**Signature**
- `ok, unitID = A.EnemyTeam(role):IsReshiftAble(offset)`

**Parameters**
- `offset` (`number|nil`): additional seconds added to the cast-end window (defaults to `0.05`).

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Logic Explanation**
- If the player is not focused (engine check), finds an enemy cast that matches `AuraList.Reshift` and is within the per-entry range.

**Usage Example**
```lua
local ok, who = A.EnemyTeam(nil):IsReshiftAble()
```

---

### `:IsPremonitionAble(offset)`

**Signature**
- `ok, unitID = A.EnemyTeam(role):IsPremonitionAble(offset)`

**Parameters**
- `offset` (`number|nil`): additional seconds added to the window (defaults to `0.05`).

**Return Values**
- `ok` (`boolean`)
- `unitID` (`string`)

**Logic Explanation**
- Finds an enemy cast that matches `AuraList.Premonition` within `A.GetGCD() + offset` and is in range.

**Usage Example**
```lua
local ok, who = A.EnemyTeam(nil):IsPremonitionAble()
```
