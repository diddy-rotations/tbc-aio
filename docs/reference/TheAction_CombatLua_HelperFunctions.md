# TheAction `Combat.lua` helper functions

This document covers the public helpers exposed by `../action_mop/Modules/Engines/Combat.lua`:

- `Action.CombatTracker` (`A.CombatTracker`): combat-log-driven health/damage/heal/TTD tracking.
- `Action.UnitCooldown` (`A.UnitCooldown`): enemy/friendly cooldown + in-flight spell tracking.
- `Action.LossOfControl` (`A.LossOfControl`): loss-of-control (CC/interrupt) state for UI and logic.

Notes:
- Most values here are **event-driven** (CLEU + unit events). If the engine has not observed the needed data, functions often return `0`, `math.huge`, or a large fallback (`500` for TTD).
- Several methods include **recency gates** (example: only report values if the last relevant hit happened within ~5 seconds) to avoid using stale data.
- `unitID` parameters refer to WoW unit tokens such as `"player"`, `"target"`, `"arena1"`, `"party2"`, `"nameplate3"`.

---

## CombatTracker (`A.CombatTracker`)

### `:UnitHealthMax(unitID)`

**Signature**
- `maxHP = A.CombatTracker:UnitHealthMax(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `maxHP` (`number`): "real" unit max health if available/derivable; otherwise `0`.

**Logic Explanation**
- If `UnitHasRealHealth(unitID)` is true, returns WoW `UnitHealthMax(unitID)`.
- Otherwise, attempts to reconstruct max HP from CombatTracker caches:
  - "Pre out" cached max HP (`RealUnitHealthCachedHealthMax[GUID]`)
  - "Post out" cached max HP (`RealUnitHealthCachedHealthMaxTemprorary[GUID]`)
  - "Broken out" estimate based on tracked damage taken and current health percent.

**Intended usage**
- Use when `UnitHealthMax` is not directly reliable for a unit (engine-specific environments such as nameplates).

**Usage Example**
```lua
local maxHP = A.CombatTracker:UnitHealthMax("target")
```

---

### `:UnitHealth(unitID)`

**Signature**
- `hp = A.CombatTracker:UnitHealth(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `hp` (`number`): "real" unit health if available/derivable; otherwise `0`.

**Logic Explanation**
- If `UnitHasRealHealth(unitID)` is true, returns WoW `UnitHealth(unitID)`.
- Otherwise:
  - Requires that the tracker has recorded damage taken for the unit GUID (`RealUnitHealthDamageTaken[GUID]`).
  - If a cached max HP exists:
    - In combat: `cachedMaxHP - trackedDamageTaken`
    - Out of combat: `UnitHealth(unitID) * cachedMaxHP / 100` (treats WoW `UnitHealth` as percent)
  - If only damage taken exists, uses a "broken out" estimation formula derived from current HP percent and tracked damage.

**Intended usage**
- Use for units where WoW returns percent-style health (engine-defined), but you need absolute HP.

**Usage Example**
```lua
local hp = A.CombatTracker:UnitHealth("target")
```

---

### `:UnitHasRealHealth(unitID)`

**Signature**
- `ok = A.CombatTracker:UnitHasRealHealth(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `ok` (`boolean`)

**Logic Explanation**
- Direct wrapper around the internal `UnitHasRealHealth(unitID)` helper used by the engine.

**Usage Example**
```lua
if A.CombatTracker:UnitHasRealHealth("target") then end
```

---

### `:CombatTime(unitID)`

**Signature**
- `combatFor, guid = A.CombatTracker:CombatTime(unitID)`

**Parameters**
- `unitID` (`string|nil`): defaults to `"player"`.

**Return Values**
- `combatFor` (`number`): seconds since the unit entered combat (0 when not in combat or unknown).
- `guid` (`string|nil`): GUID used by the tracker.

**Logic Explanation**
- Uses `GetGUID(unitID)` and the tracker entry `CombatTrackerData[GUID].combat_time`.
- Resets stored combat state when the unit is no longer in combat.

**Usage Example**
```lua
if A.CombatTracker:CombatTime("player") > 0 then end
```

---

### `:GetLastTimeDMGX(unitID, X)`

**Signature**
- `amount = A.CombatTracker:GetLastTimeDMGX(unitID, X)`

**Parameters**
- `unitID` (`string`)
- `X` (`number|nil`): seconds window (defaults to `5`).

**Return Values**
- `amount` (`number`): summed incoming damage amount in the window, or `0`.

**Logic Explanation**
- If `CombatTrackerData[GUID].DS` exists, sums the table by time via `CombatTrackerSummTableByTime(...)`.

**Usage Example**
```lua
local last5 = A.CombatTracker:GetLastTimeDMGX("player", 5)
```

---

### `:GetRealTimeDMG(unitID)`

**Signature**
- `avgHit, hits, avgPhys, avgMagic, avgSwing = A.CombatTracker:GetRealTimeDMG(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `avgHit` (`number`)
- `hits` (`number`)
- `avgPhys` (`number`)
- `avgMagic` (`number`)
- `avgSwing` (`number`)

**Logic Explanation**
- Requires:
  - `combatTime > 0`, and
  - last hit taken is recent (`now - DMG_lastHit_taken <= A.GetGCD() * 2 + 1`).
- Computes per-hit averages from `RealDMG_*` totals by dividing by `RealDMG_hits_taken`.

**Intended usage**
- Very recent "average hit size taken" signal (not a long-term DPS average).

**Usage Example**
```lua
local avgHit = A.CombatTracker:GetRealTimeDMG("player")
```

---

### `:GetRealTimeDPS(unitID)`

**Signature**
- `avgHit, hits, avgPhys, avgMagic, avgSwing = A.CombatTracker:GetRealTimeDPS(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- Same shape as `:GetRealTimeDMG`, but for damage done.

**Logic Explanation**
- Uses `RealDMG_*_done` and `RealDMG_hits_done` with the same recency gate.

**Usage Example**
```lua
local avgHit = A.CombatTracker:GetRealTimeDPS("player")
```

---

### `:GetDMG(unitID)`

**Signature**
- `dmgPerSec, hits, physPerSec, magicPerSec = A.CombatTracker:GetDMG(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `dmgPerSec` (`number`): average damage taken per second since combat started (0 if stale/unknown).
- `hits` (`number`)
- `physPerSec` (`number`)
- `magicPerSec` (`number`)

**Logic Explanation**
- Requires `combatTime > 0` and last hit taken within 5 seconds.
- Divides accumulated taken totals by `combatTime`.

**Usage Example**
```lua
local dmgPerSec = A.CombatTracker:GetDMG("player")
```

---

### `:GetDPS(unitID)`

**Signature**
- `avgHit, hits, avgPhys, avgMagic = A.CombatTracker:GetDPS(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `avgHit` (`number`): average damage done per hit (0 if stale/unknown).
- `hits` (`number`)
- `avgPhys` (`number`)
- `avgMagic` (`number`)

**Logic Explanation**
- Requires a tracker entry and last hit done within 5 seconds.
- Divides accumulated done totals by `hits`.

**Usage Example**
```lua
local avgHit = A.CombatTracker:GetDPS("player")
```

---

### `:GetHEAL(unitID)`

**Signature**
- `avgHeal, hits = A.CombatTracker:GetHEAL(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `avgHeal` (`number`): average healing received per hit (0 if stale/unknown).
- `hits` (`number`)

**Logic Explanation**
- Requires last heal received within 5 seconds.
- Divides accumulated healing taken totals by `hits`.

**Usage Example**
```lua
local avgHeal = A.CombatTracker:GetHEAL("player")
```

---

### `:GetHPS(unitID)`

**Signature**
- `avgHeal, hits = A.CombatTracker:GetHPS(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `avgHeal` (`number`): average healing done per hit (0 if unknown).
- `hits` (`number`)

**Logic Explanation**
- Divides accumulated healing done totals by `hits` (no strict recency gate in the current implementation).

**Usage Example**
```lua
local avgHeal = A.CombatTracker:GetHPS("player")
```

---

### `:GetSchoolDMG(unitID)`

**Signature**
- `holy, fire, nature, frost, shadow, arcane = A.CombatTracker:GetSchoolDMG(unitID)`

**Parameters**
- `unitID` (`string`)

**Return Values**
- `holy`..`arcane` (`number`): per-school damage taken per second since combat started (0 for schools without recent hits).

**Logic Explanation**
- Requires `combatTime > 0` and `CombatTrackerData[GUID].School` to exist.
- For each school, only reports if the last hit time for that school is within 5 seconds.

**Usage Example**
```lua
local holy, fire = A.CombatTracker:GetSchoolDMG("player")
```

---

### `:GetSpellAmountX(unitID, spell, X)`

**Signature**
- `amount = A.CombatTracker:GetSpellAmountX(unitID, spell, X)`

**Parameters**
- `unitID` (`string`)
- `spell` (`string|number`): spell name or spellID.
- `X` (`number|nil`): seconds window (defaults to `5`).

**Return Values**
- `amount` (`number`): amount taken attributed to the spell in the window, or 0.

**Logic Explanation**
- Reads `CombatTrackerData[GUID].spell_value[spell].Amount` if its `TIME` is within the window.

**Usage Example**
```lua
local amount = A.CombatTracker:GetSpellAmountX("player", 116, 5)
```

---

### `:GetSpellAmount(unitID, spell)`

**Signature**
- `amount = A.CombatTracker:GetSpellAmount(unitID, spell)`

**Parameters**
- `unitID` (`string`)
- `spell` (`string|number`)

**Return Values**
- `amount` (`number`): last recorded amount attributed to the spell (no time check), or 0.

**Usage Example**
```lua
local amount = A.CombatTracker:GetSpellAmount("player", "Frostbolt")
```

---

### `:GetSpellLastCast(unitID, spell)`

**Signature**
- `since, start = A.CombatTracker:GetSpellLastCast(unitID, spell)`

**Parameters**
- `unitID` (`string`)
- `spell` (`string|number`)

**Return Values**
- `since` (`number`): seconds since the last tracked cast.
- `start` (`number`): cast start timestamp.

**Logic Explanation**
- Uses `CombatTrackerData[GUID].spell_lastcast_time[spell]` when present.
- If unknown, returns `math.huge, 0`.

**Intended usage**
- "Last cast time" for spells that the CLEU observed as applied/missed/reflected.
- For projectile spells that are still in-flight and have not been observed on the destination yet, prefer `A.UnitCooldown:IsSpellInFly`.

**Usage Example**
```lua
local since = A.CombatTracker:GetSpellLastCast("arena1", "Polymorph")
```

---

### `:GetSpellCounter(unitID, spell)`

**Signature**
- `count = A.CombatTracker:GetSpellCounter(unitID, spell)`

**Parameters**
- `unitID` (`string`)
- `spell` (`string|number`)

**Return Values**
- `count` (`number`): number of casts observed in the tracked window, or 0.

**Usage Example**
```lua
local count = A.CombatTracker:GetSpellCounter("arena1", "Polymorph")
```

---

### `:GetAbsorb(unitID, spell)`

**Signature**
- `amount = A.CombatTracker:GetAbsorb(unitID, spell)`

**Parameters**
- `unitID` (`string`)
- `spell` (`string|number|nil`): optional filter.

**Return Values**
- `amount` (`number`): absorb amount taken (total or filtered by spell), or 0.

**Logic Explanation**
- For a specific spell, prefers `CombatTrackerData[GUID].absorb_spells[spell]`.
- If the stored value is `<= 0`, attempts a fallback from `Unit(unitID):AuraVariableNumber(spell, "HELPFUL")` (absolute value).

**Usage Example**
```lua
local absorb = A.CombatTracker:GetAbsorb("player")
```

---

### `:GetDR(unitID, drCat)`

**Signature**
- `tick, remain, applications, maxApplications = A.CombatTracker:GetDR(unitID, drCat)`

**Parameters**
- `unitID` (`string`)
- `drCat` (`string`): DR category key (examples: `"stun"`, `"root"`, `"fear"`, `"cyclone"`, etc).

**Return Values**
- `tick` (`number`): DR tick (100 -> 50 -> 25 -> 0; taunt uses a different progression).
- `remain` (`number`): seconds until DR reset (0 when not in DR window).
- `applications` (`number`): applied stack count in the category.
- `maxApplications` (`number`): category application cap.

**Logic Explanation**
- Reads `CombatTrackerData[GUID].DR[drCat]`.
- If the DR entry exists and `reset >= now`, returns the stored values; otherwise returns `100, 0, 0, 0`.

**Usage Example**
```lua
local tick = A.CombatTracker:GetDR("arena1", "stun")
```

---

### `:TimeToDieX(unitID, X)`

**Signature**
- `ttd = A.CombatTracker:TimeToDieX(unitID, X)`

**Parameters**
- `unitID` (`string|nil`): defaults to `"target"`.
- `X` (`number`): percent-of-max threshold (example: `20` means "time to reach 20% HP").

**Return Values**
- `ttd` (`number`): predicted seconds until the unit reaches `X%` of max health, or `500` when unknown/unreliable.

**Logic Explanation**
- Uses `health = A.CombatTracker:UnitHealth(unitID)` and `dmgPerSec, hits = A.CombatTracker:GetDMG(unitID)`.
- If `health <= 0`, returns `0`.
- If `dmgPerSec >= 1` and `hits > 1`, estimates:
  - `(health - (maxHP * (X / 100))) / dmgPerSec`
- Returns `500` when it cannot compute a stable positive value.

**Usage Example**
```lua
if A.CombatTracker:TimeToDieX("target", 20) < 6 then end
```

---

### `:TimeToDie(unitID)`

**Signature**
- `ttd = A.CombatTracker:TimeToDie(unitID)`

**Parameters**
- `unitID` (`string|nil`): defaults to `"target"`.

**Return Values**
- `ttd` (`number`): predicted seconds until death, or `500` when unknown/unreliable.

**Logic Explanation**
- Same approach as `:TimeToDieX`, but uses `health / dmgPerSec`.

**Usage Example**
```lua
local ttd = A.CombatTracker:TimeToDie("target")
```

---

### `:TimeToDieMagicX(unitID, X)`

**Signature**
- `ttd = A.CombatTracker:TimeToDieMagicX(unitID, X)`

**Parameters**
- `unitID` (`string|nil`)
- `X` (`number`)

**Return Values**
- `ttd` (`number`): predicted seconds until `X%` HP if only the tracked magic DPS taken continues (fallback `500`).

**Logic Explanation**
- Uses magic DPS taken as the 4th return from `:GetDMG(unitID)` (`magicPerSec`).

**Usage Example**
```lua
local ttd = A.CombatTracker:TimeToDieMagicX("player", 50)
```

---

### `:TimeToDieMagic(unitID)`

**Signature**
- `ttd = A.CombatTracker:TimeToDieMagic(unitID)`

**Parameters**
- `unitID` (`string|nil`)

**Return Values**
- `ttd` (`number`): predicted seconds until death if only the tracked magic DPS taken continues (fallback `500`).

**Usage Example**
```lua
local ttd = A.CombatTracker:TimeToDieMagic("player")
```

---

### `:Debug(command)`

**Signature**
- `result = A.CombatTracker:Debug(command)`

**Parameters**
- `command` (`string`): supported values:
  - `"wipe"`: clears "real health" caches for the current `"target"`.
  - `"data"`: returns the internal `RealUnitHealth` table.

**Return Values**
- `result` (`table|nil`): only for `"data"`.

**Usage Example**
```lua
-- A.CombatTracker:Debug("wipe")
-- local data = A.CombatTracker:Debug("data")
```

---

## UnitCooldown (`A.UnitCooldown`)

### `:Register(spellName, timer, isFriendlyArg, inPvPArg, CLEUbl)`

**Signature**
- `A.UnitCooldown:Register(spellName, timer, isFriendlyArg, inPvPArg, CLEUbl)`

**Parameters**
- `spellName` (`string|number`): spell name or spellID to register for tracking.
- `timer` (`number`): cooldown duration (seconds) used as the tracked baseline.
- `isFriendlyArg` (`boolean|nil`): optional registration metadata (engine-defined).
- `inPvPArg` (`boolean|nil`): optional registration metadata (engine-defined).
- `CLEUbl` (`table|nil`): blacklist of CLEU events that should not reset in-flight tracking for the spell.

**Return Values**
- (no return)

**Logic Explanation**
- Converts spellID to spell name when needed.
- Refuses to register Blink/Shimmer (tracked separately) and prints an error.
- Stores the registration in `UnitTracker.isRegistered[spellName]`.

**Usage Example**
```lua
-- Track an enemy cooldown by spellID with a 30s timer
A.UnitCooldown:Register(3355, 30) -- example: Freezing Trap
```

---

### `:UnRegister(spellName)`

**Signature**
- `A.UnitCooldown:UnRegister(spellName)`

**Parameters**
- `spellName` (`string|number`)

**Return Values**
- (no return)

**Logic Explanation**
- Removes the spell from `UnitTracker.isRegistered` and wipes the tracking table.

**Usage Example**
```lua
A.UnitCooldown:UnRegister(3355)
```

---

### `:GetCooldown(unit, spellName)`

**Signature**
- `remain, start = A.UnitCooldown:GetCooldown(unit, spellName)`

**Parameters**
- `unit` (`string`):
  - specific unit token (e.g., `"arena1"`, `"target"`), or
  - `"any"|"enemy"|"friendly"` to search across tracked entries, or
  - `"arena"|"party"|"raid"` to scan those groups.
- `spellName` (`string|number`)

**Return Values**
- `remain` (`number`): remaining cooldown (seconds), or 0.
- `start` (`number`): start timestamp, or 0.

**Usage Example**
```lua
local cd = A.UnitCooldown:GetCooldown("arena", "Counter Shot")
```

---

### `:GetMaxDuration(unit, spellName)`

**Signature**
- `maxCD = A.UnitCooldown:GetMaxDuration(unit, spellName)`

**Parameters**
- `unit` (`string`)
- `spellName` (`string|number`)

**Return Values**
- `maxCD` (`number`): tracked cooldown duration (`expire - start`), or 0.

**Usage Example**
```lua
local maxCD = A.UnitCooldown:GetMaxDuration("arena1", "Counter Shot")
```

---

### `:GetUnitID(unit, spellName)`

**Signature**
- `unitID = A.UnitCooldown:GetUnitID(unit, spellName)`

**Parameters**
- `unit` (`string`): same selector rules as `:GetCooldown`.
- `spellName` (`string|number`)

**Return Values**
- `unitID` (`string|nil`): unit token corresponding to a tracked entry with an active cooldown.

**Logic Explanation**
- For `"any"|"enemy"|"friendly"`, finds a matching GUID entry with `expire - now >= 0` and attempts to map GUID back to:
  - a visible enemy nameplate token (PvE), or
  - an arena unit token (PvP), or
  - a friendly team member token.

**Usage Example**
```lua
local who = A.UnitCooldown:GetUnitID("enemy", "Counter Shot")
```

---

### `:GetBlinkOrShrimmer(unit)`

**Signature**
- `charges, cooldown, summary = A.UnitCooldown:GetBlinkOrShrimmer(unit)`

**Parameters**
- `unit` (`string`): same selector rules as `:GetCooldown` (`"any"|"enemy"|"friendly"` are commonly used).

**Return Values**
- `charges` (`number`)
- `cooldown` (`number`)
- `summary` (`number`)

**Logic Explanation**
- Tracks Blink (single cooldown) and Shimmer (2 charges) separately in `UnitTrackerData`.

**Usage Example**
```lua
local charges = A.UnitCooldown:GetBlinkOrShrimmer("enemy")
```

---

### `:IsSpellInFly(unit, spellName)`

**Signature**
- `isFlying = A.UnitCooldown:IsSpellInFly(unit, spellName)`

**Parameters**
- `unit` (`string`)
- `spellName` (`string|number`)

**Return Values**
- `isFlying` (`boolean|nil`)

**Logic Explanation**
- Returns true while the tracker marks the spell as in-flight.
- Auto-resets `isFlying` to false when the start time is older than `UnitTrackerMaxResetFlyingTimer`.

**Usage Example**
```lua
if A.UnitCooldown:IsSpellInFly("arena1", "Counter Shot") then end
```

---

## LossOfControl (`A.LossOfControl`)

### `:Get(locType, name)`

**Signature**
- `remain, textureID = A.LossOfControl:Get(locType, name)`

**Parameters**
- `locType` (`string`): loss-of-control type key used by the engine (example categories are configured in the file's internal tables).
- `name` (`string|nil`): optional sub-key for `locType` when the data is stored per-name.

**Return Values**
- `remain` (`number`): remaining duration (seconds), clamped at `>= 0`.
- `textureID` (`number`): texture ID for display, or 0.

**Logic Explanation**
- Looks up `LossOfControlData[locType]` (and optionally `LossOfControlData[locType][name]`) and returns `Result - now` plus `TextureID`.

**Usage Example**
```lua
local remain, texture = A.LossOfControl:Get("STUN")
```

---

### `:IsMissed(MustBeMissed)`

**Signature**
- `ok = A.LossOfControl:IsMissed(MustBeMissed)`

**Parameters**
- `MustBeMissed` (`string|table`): a single `locType` or an array of `locType`s.

**Return Values**
- `ok` (`boolean`): true if all queried `locType`s return 0 duration.

**Usage Example**
```lua
if A.LossOfControl:IsMissed({ "STUN", "SILENCE" }) then end
```

---

### `:IsValid(MustBeApplied, MustBeMissed, Exception)`

**Signature**
- `ok, isApplied = A.LossOfControl:IsValid(MustBeApplied, MustBeMissed, Exception)`

**Parameters**
- `MustBeApplied` (`table`): array of `locType`s; at least one must be active to set `isApplied=true`.
- `MustBeMissed` (`table|nil`): array of `locType`s that invalidate the result when active.
- `Exception` (`boolean|nil`): enables special-case logic (example: dwarf poison handling).

**Return Values**
- `ok` (`boolean`): true when an applied type is active and no missed types are active.
- `isApplied` (`boolean`): true when any applied type is active (even if invalidated by missed types).

**Logic Explanation**
- Scans `MustBeApplied` for any active control.
- Optional Exception: when nothing is applied and `A.PlayerRace == "Dwarf"`, treats having a poison debuff as "applied".
- If applied and `MustBeMissed` is provided, rejects if any missed type is active.

**Usage Example**
```lua
local ok = A.LossOfControl:IsValid({ "STUN" }, { "IMMUNE" })
```

---

### `GetExtra` (table)

**Signature**
- `extra = A.LossOfControl.GetExtra`

**Type**
- `extra` (`table`): preset `Applied`/`Missed` lists for certain races (e.g., `"Dwarf"`, `"Gnome"`).

**Intended usage**
- Use as input to `:IsValid(...)` when you want built-in defaults.

**Usage Example**
```lua
local dwarf = A.LossOfControl.GetExtra["Dwarf"]
-- dwarf.Applied, dwarf.Missed
```

---

### `:UpdateFrameData()`

**Signature**
- `A.LossOfControl:UpdateFrameData()`

**Return Values**
- (no return)

**Logic Explanation**
- Resets frame state (`LossOfControlFrameData`) and re-sorts via `LossOfControl:OnFrameSortData()`.

**Intended usage**
- Call when enabling the loss-of-control UI while an effect is already active, to force the frame to update.

**Usage Example**
```lua
A.LossOfControl:UpdateFrameData()
```

---

### `:GetFrameData()`

**Signature**
- `textureID, remain, expirationTime = A.LossOfControl:GetFrameData()`

**Return Values**
- `textureID` (`number`)
- `remain` (`number`)
- `expirationTime` (`number`): absolute expiration timestamp stored by the engine.

**Intended usage**
- Used by UI elements that show the current highest-priority loss-of-control effect.

**Usage Example**
```lua
local textureID, remain = A.LossOfControl:GetFrameData()
```

---

### `:GetFrameOrder()`

**Signature**
- `order = A.LossOfControl:GetFrameOrder()`

**Return Values**
- `order` (`number`): priority order (1 heavy, 2 medium, 3 light, 0 none).

**Usage Example**
```lua
local order = A.LossOfControl:GetFrameOrder()
```

---

### `:IsEnabled(frame_type)`

**Signature**
- `ok = A.LossOfControl:IsEnabled(frame_type)`

**Parameters**
- `frame_type` (`string`): `"PlayerFrame"` or other (treated as rotation frame).

**Return Values**
- `ok` (`boolean|nil`): nil when `A.IsInitialized` is false; otherwise returns the corresponding toggle.

**Logic Explanation**
- When initialized, reads UI toggles:
  - `"LossOfControlPlayerFrame"` or
  - `"LossOfControlRotationFrame"`.

**Usage Example**
```lua
if A.LossOfControl:IsEnabled("PlayerFrame") then end
```

