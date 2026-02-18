---@meta
--- GGL Action Framework - MultiUnits System Stubs
--- Auto-generated with type information

---@class MultiUnits
local MultiUnits = {}

--- Active enemies (CLEU)
---@param timer? any
---@param skipClear? any
---@return number
function MultiUnits:GetActiveEnemies(timer, skipClear) end

--- Enemy nameplates
---@return table
function MultiUnits:GetActiveUnitPlates() end

--- All nameplates
---@return table
function MultiUnits:GetActiveUnitPlatesAny() end

--- Nameplates by GUID
---@return table
function MultiUnits:GetActiveUnitPlatesGUID() end

--- Enemies in range
---@param range? any
---@param count? any
---@return number
function MultiUnits:GetByRange(range, count) end

--- Enemies with DoTs
---@param range? any
---@param count? any
---@param deBuffs? any
---@param upTTD? any
---@return number
function MultiUnits:GetByRangeAppliedDoTs(range, count, deBuffs, upTTD) end

--- Average TTD
---@param range? any
---@return number
function MultiUnits:GetByRangeAreaTTD(range) end

--- Casting enemies
---@param range? any
---@param count? any
---@param kickAble? any
---@param spells? any
---@return number
function MultiUnits:GetByRangeCasting(range, count, kickAble, spells) end

--- Combat enemies in range
---@param range? any
---@param count? any
---@param upTTD? any
---@return number
function MultiUnits:GetByRangeInCombat(range, count, upTTD) end

--- Enemies focusing, unitID
---@param unitID? any
---@param range? any
---@param count? any
---@return number, string
function MultiUnits:GetByRangeIsFocused(unitID, range, count) end

--- Enemies missing DoTs
---@param range? any
---@param count? any
---@param deBuffs? any
---@param upTTD? any
---@return number
function MultiUnits:GetByRangeMissedDoTs(range, count, deBuffs, upTTD) end

--- Enemies needing taunt
---@param range? any
---@param count? any
---@param upTTD? any
---@return number
function MultiUnits:GetByRangeTaunting(range, count, upTTD) end

--- Enemies in spell range
---@param spell? any
---@param count? any
---@return number
function MultiUnits:GetBySpell(spell, count) end

--- In range focusing
---@param unitID? any
---@param spell? any
---@param count? any
---@return number, string
function MultiUnits:GetBySpellIsFocused(unitID, spell, count) end
