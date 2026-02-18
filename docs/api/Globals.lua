---@meta
--- GGL Action Framework - Global Systems Stubs
--- LossOfControl, TeamCache, CombatTracker, Pet, HealingEngine, BitUtils

-- ============================================================================
-- Loss of Control System
-- ============================================================================

---@class LossOfControl
local LossOfControl = {}

--- Get CC duration and texture
---@param locType string CC type: "STUN", "ROOT", "SILENCE", "FEAR", "POLYMORPH", "SLEEP", "SNARE", "DISARM", "SCHOOL_INTERRUPT"
---@param name? string Specific spell name
---@return number duration CC duration remaining
---@return number texture Spell texture ID
function LossOfControl:Get(locType, name) end

--- Check if all specified CCs are absent
---@param types string|table CC types to check
---@return boolean missed All CCs are absent
function LossOfControl:IsMissed(types) end

--- Full CC validation
---@param applied string|table CCs that should be applied
---@param missed string|table CCs that should be missed
---@param exception? string|table Exception CCs
---@return boolean valid Validation passed
---@return boolean partial Partial validation
function LossOfControl:IsValid(applied, missed, exception) end

-- ============================================================================
-- Team Cache System
-- ============================================================================

---@class TeamCacheSide
---@field UNITs table<string, string> unitID -> GUID mapping
---@field GUIDs table<string, string> GUID -> unitID mapping
---@field Type string Cache type: "raid", "party", "none"
---@field IndexToPLAYERs table Indexed player list
---@field IndexToPETs table Indexed pet list

---@class TeamCache
---@field Friendly TeamCacheSide Friendly unit cache
---@field Enemy TeamCacheSide Enemy unit cache
local TeamCache = {}

-- ============================================================================
-- Combat Tracker System
-- ============================================================================

---@class CombatTracker
local CombatTracker = {}

--- Log damage event
---@param ... any CLEU damage arguments
function CombatTracker.logDamage(...) end

--- Log environmental damage
---@param ... any CLEU environmental arguments
function CombatTracker.logEnvironmentalDamage(...) end

--- Log swing damage
---@param ... any CLEU swing arguments
function CombatTracker.logSwing(...) end

--- Log healing event
---@param ... any CLEU heal arguments
function CombatTracker.logHealing(...) end

--- Log absorb event
---@param ... any CLEU absorb arguments
function CombatTracker.logAbsorb(...) end

--- Update absorb tracking
---@param ... any Update arguments
function CombatTracker.logUpdateAbsorb(...) end

--- Update absorb on aura change
---@param ... any Aura arguments
function CombatTracker.update_logAbsorb(...) end

--- Remove absorb tracking
---@param ... any Remove arguments
function CombatTracker.remove_logAbsorb(...) end

--- Log max health change
---@param ... any Health arguments
function CombatTracker.logHealthMax(...) end

--- Log last cast
---@param ... any Cast arguments
function CombatTracker.logLastCast(...) end

--- Log unit death
---@param ... any Death arguments
function CombatTracker.logDied(...) end

--- Log diminishing returns
---@param timestamp number Event timestamp
---@param EVENT string Event type
---@param DestGUID string Destination GUID
---@param destFlags number Destination flags
---@param spellID number Spell ID
function CombatTracker.logDR(timestamp, EVENT, DestGUID, destFlags, spellID) end

-- ============================================================================
-- Pet System
-- ============================================================================

---@class Pet
local Pet = {}

--- Get pet's previous GCD spell
---@param Index number History index (1 = most recent)
---@param Spell? ActionObject Spell to compare
---@return boolean|ActionObject match Match or previous spell
function Pet:PrevGCD(Index, Spell) end

--- Get pet's previous off-GCD spell
---@param Index number History index
---@param Spell? ActionObject Spell to compare
---@return boolean|ActionObject match Match or previous spell
function Pet:PrevOffGCD(Index, Spell) end

-- ============================================================================
-- Healing Engine System
-- ============================================================================

---@class HealingEngine
local HealingEngine = {}

-- Healing engine is complex and profile-specific
-- Basic reference for the global object

-- ============================================================================
-- Bit Utilities
-- ============================================================================

---@class BitUtils
local BitUtils = {}

--- Check if flags indicate enemy
---@param Flags number Unit flags
---@return boolean isEnemy Is enemy flag set
function BitUtils.isEnemy(Flags) end

--- Check if flags indicate player
---@param Flags number Unit flags
---@return boolean isPlayer Is player flag set
function BitUtils.isPlayer(Flags) end

--- Check if flags indicate pet
---@param Flags number Unit flags
---@return boolean isPet Is pet flag set
function BitUtils.isPet(Flags) end

-- ============================================================================
-- WoW Global API Stubs (commonly used)
-- ============================================================================

--- Get current time
---@return number time Current time in seconds
function GetTime() end

--- Get spell info
---@param spellID number Spell ID
---@return string name, string rank, number icon, number castTime, number minRange, number maxRange, number spellID
function GetSpellInfo(spellID) end

--- Get unit health
---@param unitID string Unit ID
---@return number health Current health
function UnitHealth(unitID) end

--- Get unit max health
---@param unitID string Unit ID
---@return number health Maximum health
function UnitHealthMax(unitID) end

--- Get unit power
---@param unitID string Unit ID
---@param powerType? number Power type
---@return number power Current power
function UnitPower(unitID, powerType) end

--- Get unit max power
---@param unitID string Unit ID
---@param powerType? number Power type
---@return number power Maximum power
function UnitPowerMax(unitID, powerType) end

--- Check if unit exists
---@param unitID string Unit ID
---@return boolean exists Unit exists
function UnitExists(unitID) end

--- Check if unit is dead
---@param unitID string Unit ID
---@return boolean dead Unit is dead
function UnitIsDead(unitID) end

--- Get unit name
---@param unitID string Unit ID
---@return string name Unit name
---@return string realm Realm name
function UnitName(unitID) end

--- Get unit GUID
---@param unitID string Unit ID
---@return string guid Global unique identifier
function UnitGUID(unitID) end

--- Check if unit is player controlled
---@param unitID string Unit ID
---@return boolean isPlayer Is player
function UnitIsPlayer(unitID) end

--- Check if unit is enemy
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean isEnemy Units are enemies
function UnitIsEnemy(unit1, unit2) end

--- Check if unit is friend
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean isFriend Units are friends
function UnitIsFriend(unit1, unit2) end

--- Get unit class
---@param unitID string Unit ID
---@return string className Localized class name
---@return string classToken Class token (e.g., "WARRIOR")
---@return number classID Class ID
function UnitClass(unitID) end

--- Get unit level
---@param unitID string Unit ID
---@return number level Unit level
function UnitLevel(unitID) end

--- Check if unit is in range
---@param unitID string Unit ID
---@return boolean inRange Unit is in range
function UnitInRange(unitID) end

--- Get unit casting info
---@param unitID string Unit ID
---@return string|nil name, string text, number texture, number startTime, number endTime, boolean isTradeSkill, string castID, boolean notInterruptible, number spellID
function UnitCastingInfo(unitID) end

--- Get unit channel info
---@param unitID string Unit ID
---@return string|nil name, string text, number texture, number startTime, number endTime, boolean isTradeSkill, boolean notInterruptible, number spellID
function UnitChannelInfo(unitID) end

--- Get unit buff
---@param unitID string Unit ID
---@param index number Buff index
---@param filter? string Filter (e.g., "PLAYER")
---@return string name, number icon, number count, string debuffType, number duration, number expirationTime, string source, boolean isStealable, boolean nameplateShowPersonal, number spellID
function UnitBuff(unitID, index, filter) end

--- Get unit debuff
---@param unitID string Unit ID
---@param index number Debuff index
---@param filter? string Filter
---@return string name, number icon, number count, string debuffType, number duration, number expirationTime, string source, boolean isStealable, boolean nameplateShowPersonal, number spellID
function UnitDebuff(unitID, index, filter) end

--- Check if spell is usable
---@param spellID number Spell ID
---@return boolean usable Spell is usable
---@return boolean noMana Not enough resources
function IsUsableSpell(spellID) end

--- Get spell cooldown
---@param spellID number Spell ID
---@return number start Start time
---@return number duration Cooldown duration
---@return number enabled Is enabled
function GetSpellCooldown(spellID) end

--- Check if player is in combat
---@return boolean inCombat Player is in combat
function InCombatLockdown() end

--- Print message
---@param ... any Messages to print
function print(...) end

-- ============================================================================
-- TellMeWhen Globals (TMW addon)
-- ============================================================================

---@class TMW
TMW = {}
