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
---@param spellID number|string Spell ID or name
---@return string name, string rank, number icon, number castTime, number minRange, number maxRange, number spellID
function GetSpellInfo(spellID) end

--- Get spell texture
---@param spellID number Spell ID
---@return string texture Texture path
function GetSpellTexture(spellID) end

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

--- Check if unit is dead or ghost
---@param unitID string Unit ID
---@return boolean dead Unit is dead or ghost
function UnitIsDeadOrGhost(unitID) end

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

--- Check if two unit IDs refer to the same unit
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean same Units are the same
function UnitIsUnit(unit1, unit2) end

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

--- Check if unit1 can assist unit2
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean canAssist Can assist
function UnitCanAssist(unit1, unit2) end

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

--- Get unit classification (elite, worldboss, rare, etc.)
---@param unitID string Unit ID
---@return string classification Classification string
function UnitClassification(unitID) end

--- Get unit creature type
---@param unitID string Unit ID
---@return string creatureType Creature type (Beast, Demon, Humanoid, etc.)
function UnitCreatureType(unitID) end

--- Check if unit is in range
---@param unitID string Unit ID
---@return boolean inRange Unit is in range
function UnitInRange(unitID) end

--- Check if unit is visible
---@param unitID string Unit ID
---@return boolean visible Unit is visible
function UnitIsVisible(unitID) end

--- Check if unit is connected (online)
---@param unitID string Unit ID
---@return boolean connected Unit is connected
function UnitIsConnected(unitID) end

--- Check if unit is affecting combat
---@param unitID string Unit ID
---@return boolean inCombat Unit is in combat
function UnitAffectingCombat(unitID) end

--- Get unit faction group
---@param unitID string Unit ID
---@return string faction "Horde" or "Alliance"
---@return string localizedFaction Localized faction name
function UnitFactionGroup(unitID) end

--- Get unit group role
---@param unitID string Unit ID
---@return string role "TANK", "HEALER", "DAMAGER", or "NONE"
function UnitGroupRolesAssigned(unitID) end

--- Get detailed threat situation
---@param unit1 string Attacking unit
---@param unit2 string Target unit
---@return boolean isTanking Is tanking
---@return number status Threat status (0-3)
---@return number scaledPercent Threat percentage (scaled)
---@return number rawPercent Raw threat percentage
---@return number threatValue Threat value
function UnitDetailedThreatSituation(unit1, unit2) end

--- Get threat situation
---@param unit1 string Unit
---@param unit2? string Target
---@return number status Threat status (0-3)
function UnitThreatSituation(unit1, unit2) end

--- Get unit ranged attack speed
---@param unitID string Unit ID
---@return number speed Attack speed in seconds
---@return number minDamage Minimum damage
---@return number maxDamage Maximum damage
---@return number bonusPos Positive bonus
---@return number bonusNeg Negative bonus
---@return number percent Damage percentage
function UnitRangedDamage(unitID) end

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

--- Check if spell is known
---@param spellID number Spell ID
---@return boolean known Spell is known
function IsSpellKnown(spellID) end

--- Check if spell is in range of unit
---@param spell number|string Spell ID or name
---@param unit string Target unit ID
---@return number|nil inRange 1 if in range, 0 if not, nil if not applicable
function IsSpellInRange(spell, unit) end

--- Get spell cooldown
---@param spellID number Spell ID
---@return number start Start time
---@return number duration Cooldown duration
---@return number enabled Is enabled
function GetSpellCooldown(spellID) end

--- Check if player is in combat (secure)
---@return boolean inCombat Player is in combat lockdown
function InCombatLockdown() end

--- Print message
---@param ... any Messages to print
function print(...) end

--- Get number of group members
---@return number count Number of group members
function GetNumGroupMembers() end

--- Get number of raid members (removed in Anniversary client, use IsInRaid)
---@deprecated Use IsInRaid() instead
---@return number count Number of raid members
function GetNumRaidMembers() end

--- Get number of party members (removed in Anniversary client, use IsInGroup)
---@deprecated Use IsInGroup() instead
---@return number count Number of party members
function GetNumPartyMembers() end

--- Check if player is in a group
---@param groupType? number Group type
---@return boolean inGroup Player is in a group
function IsInGroup(groupType) end

--- Check if player is in a raid
---@return boolean inRaid Player is in a raid
function IsInRaid() end

--- Get raid roster info
---@param index number Raid member index
---@return string name, number rank, number subgroup, number level, string class, string fileName, string zone, boolean online, boolean isDead, string role, boolean isML, string combatRole
function GetRaidRosterInfo(index) end

--- Get totem information
---@param slot number Totem slot (1=Fire, 2=Earth, 3=Water, 4=Air)
---@return boolean haveTotem Totem exists
---@return string totemName Totem name
---@return number startTime Start timestamp
---@return number duration Duration in seconds
---@return number icon Texture ID
function GetTotemInfo(slot) end

--- Get weapon enchant info (imbues)
---@return boolean hasMainHandEnchant Has main hand enchant
---@return number mainHandExpiration Main hand expiration time
---@return number mainHandCharges Main hand charges
---@return number mainHandEnchantID Main hand enchant ID
---@return boolean hasOffHandEnchant Has off hand enchant
---@return number offHandExpiration Off hand expiration time
---@return number offHandCharges Off hand charges
---@return number offHandEnchantID Off hand enchant ID
function GetWeaponEnchantInfo() end

--- Get inventory item ID
---@param unit string Unit ID
---@param slot number Inventory slot
---@return number|nil itemID Item ID or nil
function GetInventoryItemID(unit, slot) end

--- Get inventory item texture
---@param unit string Unit ID
---@param slot number Inventory slot
---@return string|nil texture Texture path or nil
function GetInventoryItemTexture(unit, slot) end

--- Get item count in bags
---@param itemID number Item ID
---@param includeBank? boolean Include bank
---@param includeCharges? boolean Count charges instead
---@return number count Item count
function GetItemCount(itemID, includeBank, includeCharges) end

--- Get combat log event info
---@return number timestamp, string subevent, boolean hideCaster, string sourceGUID, string sourceName, number sourceFlags, number sourceRaidFlags, string destGUID, string destName, number destFlags, number destRaidFlags, ...
function CombatLogGetCurrentEventInfo() end

--- Clear a table (WoW global utility)
---@param tbl table Table to clear
---@return table tbl The cleared table
function wipe(tbl) end

--- Format date/time string
---@param formatString? string Date format string
---@param time? number Unix timestamp
---@return string formatted Formatted date string
function date(formatString, time) end

-- ============================================================================
-- WoW Frame API
-- ============================================================================

--- Create a UI frame
---@param frameType string Frame type ("Frame", "Button", "EditBox", "ScrollFrame", etc.)
---@param name? string Global frame name
---@param parent? any Parent frame
---@param template? string XML template name (e.g., "BackdropTemplate")
---@return table frame The created frame
function CreateFrame(frameType, name, parent, template) end

--- Main UI parent frame
---@type table
UIParent = {}

--- Game tooltip frame
---@type table
GameTooltip = {}

--- Hide game tooltip
function GameTooltip_Hide() end

-- ============================================================================
-- WoW Timer API
-- ============================================================================

---@class C_Timer_NS
C_Timer = {}

--- Schedule a callback after a delay
---@param seconds number Delay in seconds
---@param callback function Function to call
function C_Timer.After(seconds, callback) end

--- Create a new ticker
---@param seconds number Interval in seconds
---@param callback function Function to call each tick
---@param iterations? number Max iterations (nil = infinite)
---@return table ticker Ticker handle with :Cancel() method
function C_Timer.NewTicker(seconds, callback, iterations) end

--- Create a one-shot timer
---@param seconds number Delay in seconds
---@param callback function Function to call
---@return table timer Timer handle with :Cancel() method
function C_Timer.NewTimer(seconds, callback) end

-- ============================================================================
-- WoW Constants & Global Tables
-- ============================================================================

--- Slash command handler table
---@type table<string, function>
SlashCmdList = {}

--- Class colors indexed by class token
---@type table<string, {r: number, g: number, b: number}>
RAID_CLASS_COLORS = {}

--- Inventory slot constants
---@type number
INVSLOT_HEAD = 1

-- ============================================================================
-- TellMeWhen Globals (TMW addon)
-- ============================================================================

---@class TMW
---@field GetSpellTexture fun(spellID: number): string|nil
TMW = {}

-- ============================================================================
-- Third-Party Addon Globals
-- ============================================================================

--- Toaster notification addon (optional)
---@type table|nil
Toaster = nil
