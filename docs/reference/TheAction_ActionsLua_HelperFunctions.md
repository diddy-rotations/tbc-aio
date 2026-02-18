# TheAction `Actions.lua` helper functions (Action objects)

This document describes commonly used helper methods defined in `../action_mop/Modules/Actions.lua` and meant to be called on **Action objects** (e.g., `A.Fireball`, `A.Trinket1`, `A.PotionOfMoguPower`).

Notes:
- These helpers behave differently based on `self.Type` (most commonly `"Spell"`, `"Trinket"`, `"Potion"`, `"Item"`, `"SwapEquip"`).
- `unitID` parameters refer to standard WoW unit tokens (e.g., `"target"`, `"player"`, `"focus"`, `"arena1"`).
- Many helpers intentionally include latency/GCD buffering (ping + internal cache window) so `ready` means `safe to press now`, not strictly `cooldown is exactly 0`.

---

## `:Info(custom)`

**Signature**
- `v1, v2, ... = A.Action:Info(custom)`

**Parameters**
- `custom` (`number|nil`): optional ID override used by item-backed info lookups.

**Return Values**
- Returns are **type-dependent** (determined when the action is created via `A.Create(...)`):
  - `Spell` / `SpellSingleColor`: mapped to `A.GetSpellInfo`, returns spell-info tuple for the action spellID.
  - `Item` / `Potion` / `Trinket` / `ItemSingleColor` / `ItemBySlot` / `TrinketBySlot`: mapped to `A.GetItemInfo`, returns item-info tuple when available.
  - `SwapEquip`: returns the localized constant `EQUIPMENT_MANAGER`.
  - `Script`: returns `arg.Name` if provided, otherwise `"Script"`.

**Logic Explanation**
- `:Info()` is not one single implementation; `A.Create(...)` remaps it per action type.
- For spells, `A.GetSpellInfo` reads from a cache built over WoW `GetSpellInfo`.
- For items, `A.GetItemInfo` reads from a cache built over WoW `GetItemInfo`; if item data is not fully available yet, object-form calls can fall back to the item spell name, action key name, or `""`.
- For slot-based item actions (`ItemBySlot` / `TrinketBySlot`), `self.ID` is resolved dynamically from the currently equipped slot item, so `:Info()` follows the equipped item.

**Intended usage**
- Use as the canonical display/name resolver for action objects.
- Useful in debug output, UI labels, and code paths that need the resolved spell/item name.

**Usage Example**
```lua
local spellName = A.Frostbolt:Info()
local trinketName = A.Trinket1:Info()
```

---

## `:Show(icon, texture)`

**Signature**
- `shown = A.Action:Show(icon, texture)`
- Also valid for non-object texture constants via base API: `shown = A:Show(icon, texture)`

**Parameters**
- `icon` (`frame`): TellMeWhen icon frame for the current slot.
- `texture` (`number|string|nil`): optional texture override.
  - When omitted, the action's own `:Texture()` resolver is used.
  - When provided, the icon texture is set directly to that value.

**Return Values**
- `shown` (`boolean`): `true` when the icon was updated.
- Throws an error if `icon` is `nil`.

**Logic Explanation**
- Fires `TMW:Fire("TMW_ACTION_METAENGINE_UPDATE", metaSlotID, actionOrBase, texture)` before rendering.
- Applies rank color overlays for meta slots `3` and `4` when the action uses explicit rank coloring (`self.isRank` without `useMaxRank`), and clears them when not needed.
- Applies icon visuals by either:
  - `TMWAPI(icon, "texture", texture)` when `texture` argument is provided, or
  - `TMWAPI(icon, self:Texture())` otherwise.
- Returns `true` on success.

**Intended usage**
- Final display step for a selected action in rotation functions.
- Use `texture` override for special constant-driven displays (for example, stop-cast style constants).

**Usage Example**
```lua
if A.Frostbolt:IsReady("target") then
    return A.Frostbolt:Show(icon)
end

if shouldStopCast then
    return A:Show(icon, ACTION_CONST_STOPCAST)
end
```

---

## `:IsExists(replacementByPass)`

**Signature**
- `exists = A.Action:IsExists(replacementByPass)`

**Parameters**
- `replacementByPass` (`boolean|nil`)
  - `nil/false`: treat replacement spells as `existing` (example: a talent-replaced spell name still resolves to a valid spell).
  - `true`: require that the resolved spell name matches `self:Info()` (i.e., *do not* accept replacements).

**Return Values**
- `exists` (`boolean`): `true` if the action is present/available in the player's context.

**Logic Explanation**
- If `self.Type == "Spell"`:
  - Calls WoW `GetSpellInfo(self:Info() or "")` (explicitly *not* the cached `A.GetSpellInfo`).
  - Normalizes Classic return shapes where `spellName` may be a table `{ name=..., spellID=... }`.
  - Returns `true` only if:
    - `spellID` is a number, and
    - the spell is known by the player (`IsPlayerSpell`), **or** known by the active pet (`Pet:IsActive()` + `Pet:IsSpellKnown`), **or** exists in the spellbook (`FindSpellBookSlotBySpellID`), and
    - if `replacementByPass == true`, also requires `spellName == self:Info()`.
- If `self.Type == "SwapEquip"`:
  - Returns `true` if either swap target is available via `self.Equip1()` or `self.Equip2()`.
- Otherwise (items, potions, trinkets, etc.):
  - Returns `true` if the action is equipped (`self:GetEquipped()`) **or** exists in bags (`self:GetCount() > 0`).

**Intended usage**
- Use to guard logic against missing spells/items (unlearned talent, swapped bar setup, empty bag slot).
- Use `replacementByPass == true` only when you *must* distinguish the original spell from a replacement.

**Usage Example**
```lua
if A.Roll:IsExists() then
    -- Treat Roll as existing even if a talent replaced it (e.g., Chi Torpedo).
end
```

---

## `:IsUsable(extraCD, skipUsable)`

**Signature**
- `usable = A.Action:IsUsable(extraCD, skipUsable)`

**Parameters**
- `extraCD` (`number|nil`): additional seconds added to the cooldown threshold (a buffer).
- `skipUsable` (`boolean|number|nil`):
  - `true`: skip `IsUsableSpell` / `IsUsableItem` (still checks cooldown readiness).
  - `number`: require `Unit("player"):Power() >= skipUsable` (still checks cooldown readiness).
  - `nil/false`: normal usability checks via WoW APIs.

**Return Values**
- `usable` (`boolean`): `true` if the action is usable *and* its cooldown is ready within the internal buffer window.

**Logic Explanation**
- If `self.Type == "Spell"`:
  - Usable if:
    - (`skipUsable == true`) OR (`skipUsable` is a number and `Unit("player"):Power()` meets it) OR `IsUsableSpell(self.ID)` is true
    - AND `self:GetCooldown()` is within: `ping + internal_cache + (required_GCD ? current_GCD : 0) + extraCD`
- Otherwise (items/trinkets/etc.):
  - Also requires `not isItemUseException[self.ID]`.
  - Uses `IsUsableItem(self.ID)` and `self:GetItemCooldown()` with the same buffered threshold pattern.

**Intended usage**
- Use when you want a low-level `can I press this now?` check without running the action's Lua conditions and without queue/block checks.
- Prefer `:IsReady(...)` for typical rotation decisions; `:IsUsable(...)` is a building block.

**Usage Example**
```lua
if A.Counterspell:IsUsable() then
    -- Cooldown is effectively ready (with ping/GCD buffering) and spell is usable.
end
```

---

## `:IsHarmful()`

**Signature**
- `isHarmful = A.Action:IsHarmful()`

**Parameters**
- None

**Return Values**
- `isHarmful` (`boolean`): whether the action is considered harmful/hostile.

**Logic Explanation**
- If `self.Type == "Spell"`: `IsHarmfulSpell(self.ID) or IsAttackSpell(self.ID)`.
- Otherwise: `IsHarmfulItem(self:Info())`.

**Intended usage**
- Use for generic logic that needs to branch based on whether an action is hostile (e.g., unit resolution / UI logic).

**Usage Example**
```lua
if A.ShadowBolt:IsHarmful() then
    -- Safe assumption: use enemy targeting rules.
end
```

---

## `:IsHelpful()`

**Signature**
- `isHelpful = A.Action:IsHelpful()`

**Parameters**
- None

**Return Values**
- `isHelpful` (`boolean`): whether the action is considered helpful/friendly.

**Logic Explanation**
- If `self.Type == "Spell"`: `IsHelpfulSpell(self.ID)`.
- Otherwise: `IsHelpfulItem(self:Info())`.

**Intended usage**
- Use for generic branching (friendly targeting / UI decisions).

**Usage Example**
```lua
if A.PowerWordShield:IsHelpful() then
    -- Safe assumption: use friendly targeting rules.
end
```

---

## `:IsInRange(unitID)`

**Signature**
- `inRange = A.Action:IsInRange(unitID)`

**Parameters**
- `unitID` (`string|nil`): WoW unit token. Defaults to `"target"` when `nil`.

**Return Values**
- `inRange` (`boolean`): whether the unit is in range for this action (or range is skipped).

**Logic Explanation**
- Returns `true` immediately if:
  - `self.skipRange` is set on the action, or
  - `self.Type == "SwapEquip"`, or
  - `unitID` is `"player"` (via `UnitIsUnit("player", unitID)`).
- If `self.Type == "Spell"`: defers to `self:IsSpellInRange(unitID)`.
- Otherwise: defers to `self.Item:IsInRange(unitID)` (TMW item range check).

**Intended usage**
- Use to guard casts/items that require a target to be in range.
- Prefer `:IsReady(...)` for normal rotation gating; `:IsInRange(...)` is useful when you need range-only checks.

**Usage Example**
```lua
if A.Frostbolt:IsInRange("target") then
    -- Target is in Frostbolt range (or range is skipped / not applicable).
end
```

---

## `:IsCurrent()`

**Signature**
- `isCurrent = A.Action:IsCurrent()`

**Parameters**
- None

**Return Values**
- `isCurrent` (`boolean`): whether the action is the `current` action per WoW APIs.

**Logic Explanation**
- Only supports:
  - `"Spell"` via `self:IsSpellCurrent()`
  - `"Item"` / `"Trinket"` via `self:IsItemCurrent()`
- Returns `false` for other types.

**Intended usage**
- Use mostly for auto-repeat style spells or checking whether an action is currently `selected/active` according to the client.

**Usage Example**
```lua
if A.AutoShot:IsCurrent() then
    -- Auto Shot is currently active.
end
```

---

## `:HasRange()`

**Signature**
- `hasRange = A.Action:HasRange()`

**Parameters**
- None

**Return Values**
- `hasRange` (`boolean`): whether the action has a range that can/should be checked.

**Logic Explanation**
- If `self.Type == "Spell"`:
  - `true` only if `self:Info()` is non-nil, the spell is not in `isSpellRangeException[self.ID]`, and `SpellHasRange(self:Info())` is true.
- If `self.Type == "SwapEquip"`: always `false`.
- Otherwise:
  - `true` only if the item is not in `isItemRangeException[self:GetID()]` and `ItemHasRange(self:Info())` is true.

**Intended usage**
- Use before calling `:IsInRange(...)` if you want to avoid unnecessary range checks for actions that have no range.
- Note that higher-level helpers already do this for you (e.g., `:IsCastable(...)`).

**Usage Example**
```lua
if A.HammerofJustice:HasRange() and not A.HammerofJustice:IsInRange("target") then
    return
end
```

---

## `:GetCooldown()`

**Signature**
- `cd = A.Action:GetCooldown()`

**Parameters**
- None

**Return Values**
- `cd` (`number`): remaining cooldown time in seconds.

**Logic Explanation**
- If `self.Type == "SwapEquip"`:
  - Returns `math.huge` while swapping is locked (`Player:IsSwapLocked()`), else `0`.
- If `self.Type == "Spell"`:
  - If this action represents a stance (`self.isStance`): computes remaining stance cooldown via `GetShapeshiftFormCooldown`.
  - Otherwise: returns `CooldownDuration(self:Info())`.
- Otherwise: returns `self:GetItemCooldown()` (which includes potion sickness handling for `self.Type == "Potion"`).

**Intended usage**
- Use when you need numeric cooldown time remaining.
- Prefer `:IsUsable(...)` / `:IsReady(...)` for `can cast now?` checks (they include buffering and other gating).

**Usage Example**
```lua
if A.IcyVeins:GetCooldown() == 0 then
    -- Cooldown is ready (exactly 0 remaining).
end
```

---

## `:GetCount()`

**Signature**
- `count = A.Action:GetCount()`

**Parameters**
- None

**Return Values**
- `count` (`number`): amount available.

**Logic Explanation**
- If `self.Type == "Spell"`: `GetSpellCount(self.ID) or 0`.
- Otherwise: `self.Item:GetCount() or 0`.

**Intended usage**
- Use for consumables, reagents, or item-count gates.

**Usage Example**
```lua
if A.PotionOfMoguPower:GetCount() > 0 then
    -- You have at least one potion available.
end
```

---

## `:AbsentImun(unitID, imunBuffs)`

**Signature**
- `ok = A.Action:AbsentImun(unitID, imunBuffs)`
- Also supported as a `static-style` call: `ok = A.AbsentImun(nil, unitID, imunBuffs)` (treats cast time as 0).

**Parameters**
- `unitID` (`string|nil`): WoW unit token to check. If `nil` (or `"player"`), returns `true`.
- `imunBuffs` (`table|nil`): `immunity` aura list passed to `Unit(unitID):HasBuffs(...)` (commonly a table of aura-list keys like `{"TotalImun", "CCTotalImun"}`).

**Return Values**
- `ok` (`boolean`): `true` if the unit is considered **safe to act on** (no relevant immunity/breakable-state that would last long enough to matter).

**Logic Explanation**
- Returns `true` immediately if `unitID` is `nil` or is the player.
- Computes `MinDur` (minimum remaining duration that matters):
  - If called as a method on a spell action (`self.Type == "Spell"`), `MinDur` starts as `self:GetSpellCastTime()`, and if it's > 0, adds current GCD time when the spell requires GCD.
  - Otherwise (non-spell action or static-style call), `MinDur` is `0`.
- If the target is an enemy and the `"StopAtBreakAble"` toggle is enabled:
  - Returns `false` if the unit has any `breakable` debuff (from `IsBreakAbleDeBuff`) with remaining time > `MinDur`.
- If the target is an enemy player, `A.IsInPvP` is true, and `imunBuffs` is provided:
  - Returns `false` if `Unit(unitID):HasBuffs(imunBuffs) > MinDur`.
  - Additionally, for Classic-era builds (`BuildToC < 20000`), applies a failsafe check for buff `370391` (`Failsafe Phylactery`) and returns `false` when the unit would die before it expires.
- Otherwise returns `true`.

**Side effects**
- When called as a method and `imunBuffs` is provided, stores `self.AbsentImunQueueCache = imunBuffs` (used by the Queue System to re-check immunities later).

**Intended usage**
- Use to avoid wasting CC/interrupt/damage into immunity buffs or into breakable CC windows (especially in PvP).
- Use the static-style call when you want an `immunity right now` check without incorporating cast time/GCD.

**Usage Example**
```lua
if A.Polymorph:IsReady("target") and A.Polymorph:AbsentImun("target", {"CCTotalImun", "TotalImun"}) then
    return A.Polymorph
end
```

---

## `:IsBlockedByAny()`

**Signature**
- `blocked = A.Action:IsBlockedByAny()`

**Parameters**
- None

**Return Values**
- `blocked` (`boolean`): `true` if the action is blocked for *any* common reason.

**Logic Explanation**
Returns `true` if **any** of the following are true:
- The action is manually blocked (`self:IsBlocked()`).
- The action is blocked by the Queue System pooling rules (`self:IsBlockedByQueue()`).
- If it's a spell:
  - It's unknown/unavailable in the spellbook (`self:IsBlockedBySpellBook()`), or
  - It's marked as a talent action and the talent is not learned (`self.isTalent and not self:IsTalentLearned()`).
- If it's not a spell and not swap-equip:
  - You don't have the item (`self:GetCount() == 0`) and it's not equipped (`not self:GetEquipped()`).

**Intended usage**
- Use when you want a quick `don't even consider this action` filter before doing more expensive checks.

**Usage Example**
```lua
if A.Taunt:IsBlockedByAny() then
    -- Don't attempt Taunt logic (blocked/unknown/queued/no item, etc).
end
```

---

## `:IsSuspended(delay, reset)`

**Signature**
- `suspended = A.Action:IsSuspended(delay, reset)`

**Parameters**
- `delay` (`number`): how long (seconds) to suspend after the internal timer is refreshed.
- `reset` (`number`): minimum time (seconds) before the internal timer may be refreshed again.

**Return Values**
- `suspended` (`boolean`): `true` while the action is still in its suspension window.

**Logic Explanation**
- Maintains `self.expirationSuspend` as a `do not use before` timestamp.
- If `(self.expirationSuspend or 0) + reset <= TMW.time`, it refreshes the window by setting:
  - `self.expirationSuspend = TMW.time + delay`
- Returns `self.expirationSuspend > TMW.time`.

**Intended usage**
- Use as a per-action throttle to avoid repeated attempts (spam) for actions that you want to delay for a short time once considered.

**Usage Example**
```lua
if not A.Berserking:IsSuspended(0.20, 0.05) and A.Berserking:IsReadyByPassCastGCD("player") then
    return A.Berserking
end
```

---

## `:IsCastable(unitID, skipRange, skipShouldStop, isMsg, skipUsable)`

**Signature**
- `castable = A.Action:IsCastable(unitID, skipRange, skipShouldStop, isMsg, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): WoW unit token. If `nil`, range checks are skipped.
- `skipRange` (`boolean|nil`): if `true`, range checks are skipped.
- `skipShouldStop` (`boolean|nil`): if `true`, bypasses the global `casting` stop gate (`A.ShouldStop()`); still respects `:ShouldStopByGCD()` unless `isMsg` is true.
- `isMsg` (`boolean|nil`): if `true`, bypasses both `casting` and `GCD stop` gates (used by the MSG system and by the `ByPassCastGCD` helpers).
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsUsable(...)` (see `:IsUsable`).

**Return Values**
- `castable` (`boolean`): `true` if toggles/usability/cooldowns/range allow a cast/use right now.

**Logic Explanation**
- First gate:
  - If `isMsg == true`, skip stop gates.
  - Else require: `(skipShouldStop == true OR not A.ShouldStop()) AND not self:ShouldStopByGCD()`.
- Then type-specific checks:
  - **Spell**:
    - Not blocked by spellbook
    - Talent learned if applicable
    - `self:IsUsable(nil, skipUsable)`
    - Range ok if applicable (`skipRange` OR `unitID` is nil OR `not self:HasRange()` OR `self:IsInRange(unitID)`)
  - **Trinket**:
    - Must match either `A.Trinket1.ID` or `A.Trinket2.ID` and the corresponding `"Trinkets"` toggle must be enabled
    - `self:IsUsable(nil, skipUsable)`
    - Range ok if applicable
  - **Potion**:
    - `"Potion"` toggle enabled
    - `self:GetCount() > 0`
    - `self:GetItemCooldown() == 0`
  - **Item**:
    - `self:GetCount() > 0` OR `self:GetEquipped()`
    - `self:GetItemCooldown() == 0`
    - Range ok if applicable
- Returns `false` otherwise.

**Intended usage**
- Use when you want `mechanical readiness` (cooldown + range + toggles + stop gates) without the extra layers of `:IsReady(...)` (block/queue + action Lua).
- Most rotation logic should use `:IsReady(...)` variants instead.

**Usage Example**
```lua
if A.HammerofJustice:IsCastable("target") then
    -- Spell is usable and in range (and we are not stopped by casting/GCD gates).
end
```

---

## `:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable)`

**Signature**
- `ready = A.Action:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): target unit token.
- `skipRange` (`boolean|nil`): skip range checks.
- `skipLua` (`boolean|nil`): skip running the action's configured Lua condition (`:RunLua(unitID)`).
- `skipShouldStop` (`boolean|nil`): forwarded to `:IsCastable(...)`.
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`): `true` if the action should be considered ready to use now.

**Logic Explanation**
- Returns `true` only if all are true:
  - `not self:IsBlocked()` (manual blocker)
  - `not self:IsBlockedByQueue()` (queue pooling rules)
  - `self:IsCastable(unitID, skipRange, skipShouldStop, nil, skipUsable)`
  - `skipLua == true` OR `self:RunLua(unitID)` is true

**Intended usage**
- This is the `default` readiness check for most rotation logic.
- In the stock Action UI/MetaEngine convention, this variant is intended for the *passive rotation* slots (the code comment calls out `[3-4, 6-8]`).

**Usage Example**
```lua
if A.Frostbolt:IsReady("target") then
    return A.Frostbolt
end
```

---

## `:IsReadyP(unitID, skipRange, skipLua, skipShouldStop, skipUsable)`

**Signature**
- `ready = A.Action:IsReadyP(unitID, skipRange, skipLua, skipShouldStop, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): target unit token.
- `skipRange` (`boolean|nil`): skip range checks.
- `skipLua` (`boolean|nil`): skip running the action's configured Lua condition (`:RunLua(unitID)`).
- `skipShouldStop` (`boolean|nil`): forwarded to `:IsCastable(...)`.
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`): `true` if the action should be considered ready to use now.

**Logic Explanation**
- Returns `true` only if all are true:
  - `self:IsCastable(unitID, skipRange, skipShouldStop, nil, skipUsable)`
  - `skipLua == true` OR `self:RunLua(unitID)` is true
- Does **not** check `self:IsBlocked()` / `self:IsBlockedByQueue()` (see differences section).

**Differences from `:IsReady(...)`**
- Does **not** check `self:IsBlocked()` or `self:IsBlockedByQueue()`.
- Still uses `:IsCastable(...)` and (optionally) `:RunLua(...)`.

**Intended usage**
- Use when you explicitly want to ignore manual blockers / queue pooling (e.g., stance or buff logic that must remain visible/available).
- Use carefully: it can cause actions to be suggested even when the user blocked them.
- In the stock Action UI/MetaEngine convention, this variant is intended for the *active meta-buttons* (the code comment calls out `[1-2, 5]`).

**Usage Example**
```lua
if A.BattleStance:IsReadyP("player") then
    return A.BattleStance
end
```

---

## `:IsReadyM(unitID, skipRange, skipUsable)`

**Signature**
- `ready = A.Action:IsReadyM(unitID, skipRange, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): unit token. If `unitID == ""`, it is normalized to `nil`.
- `skipRange` (`boolean|nil`): skip range checks.
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`)

**Logic Explanation**
- Always runs the action's Lua (`self:RunLua(unitID)`).
- Uses `self:IsCastable(unitID, skipRange, nil, true, skipUsable)`:
  - `isMsg == true` makes `:IsCastable(...)` bypass the `casting/GCD stop` gates.

**Intended usage**
- Used by the `MSG System` / profile UI contexts where you want readiness independent of current casting/GCD stop gates.

**Usage Example**
```lua
-- Common in profile UI checks for `message` buttons/icons:
if A.Kick:IsReadyM("target") then
    -- Kick is mechanically ready and passes its Lua condition.
end
```

---

## `:IsReadyByPassCastGCD(unitID, skipRange, skipLua, skipUsable)`

**Signature**
- `ready = A.Action:IsReadyByPassCastGCD(unitID, skipRange, skipLua, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): target unit token.
- `skipRange` (`boolean|nil`): skip range checks.
- `skipLua` (`boolean|nil`): skip running the action's configured Lua condition (`:RunLua(unitID)`).
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`): `true` if the action should be considered ready to use now.

**Logic Explanation**
- Returns `true` only if all are true:
  - `not self:IsBlocked()` (manual blocker)
  - `not self:IsBlockedByQueue()` (queue pooling rules)
  - `self:IsCastable(unitID, skipRange, nil, true, skipUsable)`
    - Uses `isMsg=true` to bypass the `casting/GCD stop` gates.
  - `skipLua == true` OR `self:RunLua(unitID)` is true

**Differences from `:IsReady(...)`**
- Still checks `not self:IsBlocked()` and `not self:IsBlockedByQueue()`.
- Calls `:IsCastable(..., isMsg=true, ...)`, which bypasses the `casting/GCD stop` gates.
- Still optionally runs `:RunLua(...)` unless `skipLua == true`.

**Intended usage**
- Use for **off-GCD** actions you want to allow while the player is casting (e.g., on-use trinkets, racials).
- Pair with an **on-GCD anchor** to avoid clipping the next GCD action (see example).
- In the stock Action UI/MetaEngine convention, this variant aligns with the same slot group as `:IsReady(...)` (the code comment calls out `[3-4, 6-8]`).

**Usage Example**
```lua
-- Off-GCD action gated by an on-GCD anchor:
if A.Trinket1:IsReadyByPassCastGCD("player") and not A.Frostbolt:ShouldStopByGCD() then
    return A.Trinket1
end
```

---

## `:IsReadyByPassCastGCDP(unitID, skipRange, skipLua, skipUsable)`

**Signature**
- `ready = A.Action:IsReadyByPassCastGCDP(unitID, skipRange, skipLua, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): target unit token.
- `skipRange` (`boolean|nil`): skip range checks.
- `skipLua` (`boolean|nil`): skip running the action's configured Lua condition (`:RunLua(unitID)`).
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`): `true` if the action should be considered ready to use now.

**Logic Explanation**
- Returns `true` only if all are true:
  - `self:IsCastable(unitID, skipRange, nil, true, skipUsable)`
    - Uses `isMsg=true` to bypass the `casting/GCD stop` gates.
  - `skipLua == true` OR `self:RunLua(unitID)` is true
- Does **not** check `self:IsBlocked()` / `self:IsBlockedByQueue()` (see differences section).

**Differences from `:IsReadyByPassCastGCD(...)`**
- Does **not** check `self:IsBlocked()` or `self:IsBlockedByQueue()`.
- Bypasses the `casting/GCD stop` gates via `isMsg=true`.
- Still optionally runs `:RunLua(...)` unless `skipLua == true`.

**Intended usage**
- Use sparingly for special cases where you need `bypass casting/GCD stop gates` *and* you intentionally ignore manual blockers/queue pooling.
- In the stock Action UI/MetaEngine convention, this variant aligns with the same slot group as `:IsReadyP(...)` (the code comment calls out `[1-2, 5]`).

**Usage Example**
```lua
if A.Berserking:IsReadyByPassCastGCDP("player", true) then
    return A.Berserking
end
```

---

## `:IsReadyToUse(unitID, skipShouldStop, skipUsable)`

**Signature**
- `ready = A.Action:IsReadyToUse(unitID, skipShouldStop, skipUsable)`

**Parameters**
- `unitID` (`string|nil`): **ignored by implementation** (kept for call-site compatibility).
- `skipShouldStop` (`boolean|nil`): forwarded to `:IsCastable(...)`.
- `skipUsable` (`boolean|number|nil`): forwarded to `:IsCastable(...)` / `:IsUsable(...)`.

**Return Values**
- `ready` (`boolean`)

**Logic Explanation**
- Returns `true` only if all are true:
  - `not self:IsBlocked()`
  - `not self:IsBlockedByQueue()`
  - `self:IsCastable(nil, true, skipShouldStop, nil, skipUsable)`
    - Forces `unitID=nil` and `skipRange=true` (no range checks).
    - Does **not** run `:RunLua(...)`.

**Intended usage**
- Use as a `mechanical availability` check when you explicitly do **not** want:
  - range checks, or
  - per-action Lua conditions.
- Commonly used as a fast gate for planning logic (e.g., `is this cooldown available at all?`) where range will be checked elsewhere.

**Usage Example**
```lua
if A.Vanish:IsReadyToUse(nil, true) then
    -- Vanish is available (ignores range, ignores action Lua).
end
```

---

## `:GetSpellCastTime()`

**Signature**
- `seconds = A.Action:GetSpellCastTime()`

**Parameters**
- None

**Return Values**
- `seconds` (`number`): base cast time in seconds (`0` for instant spells).

**Logic Explanation**
- Reads spell data from `GetSpellInfo(self.ID)`.
- Supports both Classic and table-shaped returns (`spellName.castTime` on newer API shapes).
- Returns `(castTime or 0) / 1000`.

**Intended usage**
- Use when you need the spell's cast time directly (without asking Unit state).

**Usage Example**
```lua
if A.GreaterHeal:GetSpellCastTime() > 0 then
    -- Hard-cast spell.
end
```

---

## `:GetSpellCharges()`

**Signature**
- `charges = A.Action:GetSpellCharges()`

**Parameters**
- None

**Return Values**
- `charges` (`number`): current whole charge count (`0` if unsupported/no charges).

**Logic Explanation**
- Reads `GetSpellCharges(self.ID)`.
- Handles both numeric and table-shaped return formats.

**Intended usage**
- Use for charge-gated priority decisions.

**Usage Example**
```lua
if A.Roll:GetSpellCharges() >= 1 then
    -- At least one charge is available.
end
```

---

## `:GetSpellChargesMax()`

**Signature**
- `maxCharges = A.Action:GetSpellChargesMax()`

**Parameters**
- None

**Return Values**
- `maxCharges` (`number`): maximum charges for the spell (`0` if unsupported).

**Logic Explanation**
- Reads `GetSpellCharges(self.ID)` and extracts max charge count from either return shape.

**Usage Example**
```lua
local maxCharges = A.Roll:GetSpellChargesMax()
```

---

## `:GetSpellChargesFrac()`

**Signature**
- `chargesFrac = A.Action:GetSpellChargesFrac()`

**Parameters**
- None

**Return Values**
- `chargesFrac` (`number`): fractional charges including recharge progress.

**Logic Explanation**
- If charges are full, returns `maxCharges`.
- Otherwise returns `charges + ((TMW.time - start) / duration)`.
- Returns `0` when charge data is unavailable.

**Intended usage**
- Smooth pooling logic (for example, avoid overcapping shortly before next recharge completes).

**Usage Example**
```lua
if A.Roll:GetSpellChargesFrac() > 1.8 then
    -- Nearing overcap.
end
```

---

## `:GetSpellChargesFullRechargeTime()`

**Signature**
- `seconds = A.Action:GetSpellChargesFullRechargeTime()`

**Parameters**
- None

**Return Values**
- `seconds` (`number`): time until all charges are fully recharged.

**Logic Explanation**
- Reads charge cooldown duration and computes:
- `(self:GetSpellChargesMax() - self:GetSpellChargesFrac()) * duration`
- Returns `0` when charge cooldown data is unavailable.

**Usage Example**
```lua
if A.Roll:GetSpellChargesFullRechargeTime() < 3 then
    -- Charges will cap soon.
end
```

---

## `:GetSpellTimeSinceLastCast()`

**Signature**
- `seconds = A.Action:GetSpellTimeSinceLastCast()`

**Parameters**
- None

**Return Values**
- `seconds` (`number`): elapsed seconds since this spell was last observed as cast by the player.

**Logic Explanation**
- Delegates to `A.CombatTracker:GetSpellLastCast("player", self:Info())`.
- Depends on combat-log tracking; may return `math.huge` when the spell has not been observed in the current tracker state.

**Intended usage**
- Recent-cast spacing logic (for example, "don't suggest again within X seconds").

**Usage Example**
```lua
if A.RisingSunKick:GetSpellTimeSinceLastCast() > 6 then
    -- Spell has not been cast recently.
end
```

---

## `:GetSpellTravelTime(unitID)`

**Signature**
- `seconds = A.Action:GetSpellTravelTime(unitID)`

**Parameters**
- `unitID` (`string|nil`): target unit token. Uses `"target"` when omitted.

**Return Values**
- `seconds` (`number`): projectile travel-time estimate.

**Logic Explanation**
- Uses `SpellProjectileSpeed[self.ID]` and target range (`Unit(unitID):GetRange()`).
- Returns `0` when projectile speed is unknown/zero or range is unknown (`math.huge`).

**Intended usage**
- Travel-time-sensitive timing (for example, matching projectile arrival with debuff windows).

**Usage Example**
```lua
local travel = A.Frostbolt:GetSpellTravelTime("target")
```

---

## `:IsSpellInFlight()`

**Signature**
- `inFlight = A.Action:IsSpellInFlight()`

**Parameters**
- None

**Return Values**
- `inFlight` (`boolean|nil`): whether this spell is currently tracked as in-flight from the player.

**Logic Explanation**
- Delegates to `A.UnitCooldown:IsSpellInFly("player", self:Info())`.

**Intended usage**
- Avoid duplicate projectile casts while a previous one is still traveling.

**Usage Example**
```lua
if not A.LavaBurst:IsSpellInFlight() then
    -- Safe to send another projectile.
end
```

---

## `:IsSpellInCasting()`

**Signature**
- `isCastingThis = A.Action:IsSpellInCasting()`

**Parameters**
- None

**Return Values**
- `isCastingThis` (`boolean`): `true` when the player's current cast name matches this action's spell name.

**Logic Explanation**
- Compares `Unit("player"):IsCasting()` to `self:Info()`.

**Intended usage**
- Use to avoid re-issuing the same hard-cast while it is already in progress.

**Usage Example**
```lua
if A.Fireball:IsSpellInCasting() then
    -- Player is already casting Fireball.
end
```

---

## `:IsBlockedBySpellBook()`

**Signature**
- `blocked = A.Action:IsBlockedBySpellBook()`

**Parameters**
- None

**Return Values**
- `blocked` (`boolean|nil`): `true` when the spell is currently marked unknown/unavailable by the spellbook tracker.

**Logic Explanation**
- Returns the internal `DataIsSpellUnknown[self.ID]` flag maintained by `A.UpdateSpellBook(...)`.

**Intended usage**
- Fast guard for unknown/replaced/untrained spell ranks before further readiness checks.

**Usage Example**
```lua
if A.SomeTalentSpell:IsBlockedBySpellBook() then
    return
end
```

---

## `:IsTalentLearned()`

**Signature**
- `learned = A.Action:IsTalentLearned()`
- Static-style is also supported: `learned = A.IsTalentLearned(spellID)`

**Parameters**
- None for method form.
- `spellID` (`number`) for static form.

**Return Values**
- `learned` (`boolean`): `true` when the talent map has a positive rank for the spell.

**Logic Explanation**
- Resolves spell name (`self:Info()` or `A.GetSpellInfo(spellID)`) and checks `TalentMap[name] > 0`.

**Usage Example**
```lua
if A.RushingJadeWind:IsTalentLearned() then
    -- Talent is active.
end
```

---

## `:IsSpellLearned()` (legacy alias)

**Signature**
- `learned = A.Action:IsSpellLearned()`
- Static-style is also supported: `learned = A.IsSpellLearned(spellID)`

**Parameters**
- Same as `:IsTalentLearned()`.

**Return Values**
- Same as `:IsTalentLearned()`.

**Logic Explanation**
- `A.IsSpellLearned` is an alias to `A.IsTalentLearned` kept for backward compatibility.

**Intended usage**
- Prefer `:IsTalentLearned()` in new code; keep alias usage only for legacy compatibility.

**Usage Example**
```lua
if A.IsSpellLearned(A.RushingJadeWind.ID) then
    -- Equivalent to IsTalentLearned for this API.
end
```

---

## `:IsRequiredGCD()`

**Signature**
- `requiresGCD, gcdValue = A.Action:IsRequiredGCD()`

**Parameters**
- None

**Return Values**
- `requiresGCD` (`boolean`): `true` when this spell is marked as triggering GCD.
- `gcdValue` (`number`): raw value from `TriggerGCD` (typically `0`, `1000`, or `1500`).

**Logic Explanation**
- For spell actions, checks `TriggerGCD[self.ID] > 0`.
- Returns `false, 0` for non-spell actions or unlisted spells.

**Intended usage**
- Use to distinguish off-GCD vs on-GCD behavior in custom logic.

**Usage Example**
```lua
local requiresGCD = A.Berserking:IsRequiredGCD()
```

---

## `:ShouldStopByGCD()`

**Signature**
- `stop = A.Action:ShouldStopByGCD()`

**Parameters**
- None

**Return Values**
- `stop` (`boolean`): `true` when GCD-state heuristics say this action should wait.

**Logic Explanation**
- Returns true only when all are true:
- Player is not currently auto-shooting (`not A.Player:IsShooting()`).
- Action requires GCD (`self:IsRequiredGCD()`).
- Global GCD is sufficiently active by internal thresholds:
- `A.GetGCD() - A.GetPing() > 0.301`
- `A.GetCurrentGCD() >= A.GetPing() + 0.65`

**Intended usage**
- Anchor off-GCD priority steps so they do not jump ahead of queued on-GCD casts.

**Usage Example**
```lua
if A.Trinket1:IsReadyByPassCastGCD("player") and not A.Frostbolt:ShouldStopByGCD() then
    return A.Trinket1
end
```

---

## `:IsRacialReady(unitID, skipRange, skipLua, skipShouldStop)`

**Signature**
- `ready = A.Action:IsRacialReady(unitID, skipRange, skipLua, skipShouldStop)`

**Parameters**
- `unitID` (`string|nil`): target unit token.
- `skipRange` (`boolean|nil`): forwarded to `:IsReady(...)` (with racial range exception handling).
- `skipLua` (`boolean|nil`): forwarded to `:IsReady(...)`.
- `skipShouldStop` (`boolean|nil`): forwarded to `:IsReady(...)`.

**Return Values**
- `ready` (`boolean`): `true` when racial toggle + readiness + racial-specific safety checks pass.

**Logic Explanation**
- Requires all:
- `self:RacialIsON()`
- `self:IsReady(unitID, isSpellRangeException[self.ID] or skipRange, skipLua, skipShouldStop)`
- `Racial:CanUse(self, unitID)`

**Intended usage**
- Standard racial readiness check for passive rotation/meta slots (`[3-4, 6-8]` convention).

**Usage Example**
```lua
if A.WarStomp:IsRacialReady("target") then
    return A.WarStomp
end
```

---

## `:IsRacialReadyP(unitID, skipRange, skipLua, skipShouldStop)`

**Signature**
- `ready = A.Action:IsRacialReadyP(unitID, skipRange, skipLua, skipShouldStop)`

**Parameters**
- Same parameter meanings as `:IsRacialReady(...)`.

**Return Values**
- `ready` (`boolean`): racial readiness using `:IsReadyP(...)` semantics.

**Logic Explanation**
- Requires all:
- `self:RacialIsON()`
- `self:IsReadyP(unitID, isSpellRangeException[self.ID] or skipRange, skipLua, skipShouldStop)`
- `Racial:CanUse(self, unitID)`

**Intended usage**
- Active meta-button variant (`[1-2, 5]` convention), mirroring the `Ready` vs `ReadyP` split.

**Usage Example**
```lua
if A.Berserking:IsRacialReadyP("player", true) then
    return A.Berserking
end
```
