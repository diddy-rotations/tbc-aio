---@meta
--- GGL Action Framework - ActionObject Stubs
--- Auto-generated with type information

---@class ActionObject
---@field Type string Action type (Spell, Item, Trinket, etc.)
---@field ID number Spell or Item ID
---@field Color string Display color
---@field Texture number Texture ID
---@field Desc string Description
---@field SubType string Sub-type info
---@field Slot number Equipment slot
local ActionObject = {}

--- Target not immune
---@param unitID? any
---@param imunBuffs? any
---@return boolean
function ActionObject:AbsentImun(unitID, imunBuffs) end

--- Auto-use racial
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipShouldStop? any
---@return boolean
function ActionObject:AutoRacial(unitID, skipRange, skipLua, skipShouldStop) end

--- Heal can complete before death
---@param unitID? any
---@param offset? any
---@return boolean
function ActionObject:CanSafetyCastHeal(unitID, offset) end

---@param owner? any
---@return any
function ActionObject:DoSpellFilterProjectileSpeed(owner) end

--- Color state data
---@return string, table
function ActionObject:GetColorTexture() end

--- Colored item texture
---@param custom? any
---@return string, table, number
function ActionObject:GetColoredItemTexture(custom) end

--- Colored texture data
---@param custom? any
---@return string, table, number
function ActionObject:GetColoredSpellTexture(custom) end

--- Colored swap texture
---@param custom? any
---@return string, table, number
function ActionObject:GetColoredSwapTexture(custom) end

--- Remaining cooldown
---@return number
function ActionObject:GetCooldown() end

--- Charges or stack count
---@return number
function ActionObject:GetCount() end

--- CC, MISC, BOTH, DPS, or DEFF
---@return string
function ActionObject:GetItemCategory() end

--- Item cooldown remaining
---@return number
function ActionObject:GetItemCooldown() end

--- Item icon texture
---@param custom? any
---@return number
function ActionObject:GetItemIcon(custom) end

--- Item info
---@param custom? any
---@return string, string, number, number, string, string, string, number, string, number, number
function ActionObject:GetItemInfo(custom) end

--- Item link
---@return string
function ActionObject:GetItemLink() end

--- spellName, spellID or nil
---@return string, number
function ActionObject:GetItemSpell() end

---@param custom? any
---@return any
function ActionObject:GetItemTexture(custom) end

--- Key name in action table
---@return string
function ActionObject:GetKeyName() end

--- Current absorb amount
---@param unitID? any
---@return number
function ActionObject:GetSpellAbsorb(unitID) end

--- Damage/healing amount
---@param unitID? any
---@param X? any
---@return number
function ActionObject:GetSpellAmount(unitID, X) end

--- autocastable, autostate
---@return boolean, boolean
function ActionObject:GetSpellAutocast() end

--- Unmodified spell cooldown in seconds
---@return number
function ActionObject:GetSpellBaseCooldown() end

--- Base duration from enum
---@return number
function ActionObject:GetSpellBaseDuration() end

--- Cast time in seconds
---@return number
function ActionObject:GetSpellCastTime() end

--- Cached cast time
---@return number
function ActionObject:GetSpellCastTimeCache() end

--- Current charges
---@return number
function ActionObject:GetSpellCharges() end

--- Fractional charges
---@return number
function ActionObject:GetSpellChargesFrac() end

--- Time to full recharge
---@return number
function ActionObject:GetSpellChargesFullRechargeTime() end

--- Maximum charges
---@return number
function ActionObject:GetSpellChargesMax() end

--- Total casts this fight
---@return number
function ActionObject:GetSpellCounter() end

--- Icon texture ID
---@return number
function ActionObject:GetSpellIcon() end

--- name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
---@return string, string, number, number, number, number, number, number
function ActionObject:GetSpellInfo() end

--- Spell link for chat
---@return string
function ActionObject:GetSpellLink() end

--- Maximum duration
---@return number
function ActionObject:GetSpellMaxDuration() end

--- Maximum available rank
---@return number
function ActionObject:GetSpellMaxRank() end

--- Pandemic threshold (30%)
---@return number
function ActionObject:GetSpellPandemicThreshold() end

--- Cached cost and power type
---@return number, number
function ActionObject:GetSpellPowerCostCache() end

--- Current spell rank
---@return number
function ActionObject:GetSpellRank() end

--- TMW texture type and ID
---@param custom? any
---@return string, number
function ActionObject:GetSpellTexture(custom) end

--- Seconds since last cast
---@return number
function ActionObject:GetSpellTimeSinceLastCast() end

--- Projectile travel time
---@param unitID? any
---@return number
function ActionObject:GetSpellTravelTime(unitID) end

--- Talent rank (0-5)
---@return number
function ActionObject:GetTalentRank() end

--- Action has range requirement
---@return boolean
function ActionObject:HasRange() end

--- Blocked by any condition
---@return boolean
function ActionObject:IsBlockedByAny() end

--- Not in spellbook
---@return boolean
function ActionObject:IsBlockedBySpellBook() end

--- Core castability check
---@param unitID? any
---@param skipRange? any
---@param skipShouldStop? any
---@param isMsg? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsCastable(unitID, skipRange, skipShouldStop, isMsg, skipUsable) end

--- Spell/item active
---@return boolean
function ActionObject:IsCurrent() end

--- Spell known/item available
---@param replacementByPass? any
---@return boolean
function ActionObject:IsExists(replacementByPass) end

--- Action is offensive
---@return boolean
function ActionObject:IsHarmful() end

--- Action is friendly
---@return boolean
function ActionObject:IsHelpful() end

--- Action is in range
---@param unitID? any
---@return boolean
function ActionObject:IsInRange(unitID) end

--- Item being used
---@return boolean
function ActionObject:IsItemCurrent() end

--- Suitable for DPS
---@return boolean
function ActionObject:IsItemDamager() end

--- Suitable for tanks
---@return boolean
function ActionObject:IsItemTank() end

--- Racial ready check
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipShouldStop? any
---@return boolean
function ActionObject:IsRacialReady(unitID, skipRange, skipLua, skipShouldStop) end

--- Racial ready (passive)
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipShouldStop? any
---@return boolean
function ActionObject:IsRacialReadyP(unitID, skipRange, skipLua, skipShouldStop) end

--- Full ready check with all conditions
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipShouldStop? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable) end

--- Bypasses cast/GCD blocking
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReadyByPassCastGCD(unitID, skipRange, skipLua, skipUsable) end

--- Bypasses cast/GCD for passive slots
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReadyByPassCastGCDP(unitID, skipRange, skipLua, skipUsable) end

--- MSG system check (bypasses GCD)
---@param unitID? any
---@param skipRange? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReadyM(unitID, skipRange, skipUsable) end

--- Passive ready check (skips block/queue)
---@param unitID? any
---@param skipRange? any
---@param skipLua? any
---@param skipShouldStop? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReadyP(unitID, skipRange, skipLua, skipShouldStop, skipUsable) end

--- Simplified ready check without range
---@param unitID? any
---@param skipShouldStop? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsReadyToUse(unitID, skipShouldStop, skipUsable) end

--- Requires GCD and amount
---@return boolean, number
function ActionObject:IsRequiredGCD() end

--- Spell is active/channeling
---@return boolean
function ActionObject:IsSpellCurrent() end

--- Currently casting this spell
---@return boolean
function ActionObject:IsSpellInCasting() end

--- Projectile in flight
---@return boolean
function ActionObject:IsSpellInFlight() end

--- In range of target
---@param unitID? any
---@return boolean
function ActionObject:IsSpellInRange(unitID) end

--- Was last GCD or is casting
---@param byID? any
---@return boolean
function ActionObject:IsSpellLastCastOrGCD(byID) end

--- Was last GCD action
---@param byID? any
---@return boolean
function ActionObject:IsSpellLastGCD(byID) end

--- Rate-limited
---@param delay? any
---@param reset? any
---@return boolean
function ActionObject:IsSuspended(delay, reset) end

--- Talent has points
---@return boolean
function ActionObject:IsTalentLearned() end

--- Resource + cooldown check
---@param extraCD? any
---@param skipUsable? any
---@return boolean
function ActionObject:IsUsable(extraCD, skipUsable) end

--- Should stop due to GCD
---@return boolean
function ActionObject:ShouldStopByGCD() end
