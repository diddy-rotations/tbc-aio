-- Priest Healing Utilities
-- Shared healing target scanning for Holy and Discipline playstyles
-- Load order 5 (same as druid healing.lua)

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Healing]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local Constants = NS.Constants

local PLAYER_UNIT = "player"
local GetNumGroupMembers = _G.GetNumGroupMembers

-- ============================================================================
-- HEALING TARGET SCANNING
-- ============================================================================
-- Pre-allocated scan results (no inline table creation in combat)
local scan_results = {}
local MAX_SCAN = 40

-- Pre-allocate scan entry slots
for i = 1, MAX_SCAN do
    scan_results[i] = { unit = nil, hp = 100, is_tank = false }
end

local scan_count = 0

-- Determine if a unit is likely the tank (focus target, or has most threat)
local function is_tank_unit(unit)
    -- If we have a focus target and the unit matches it, consider it the tank
    if _G.UnitExists("focus") and _G.UnitIsUnit(unit, "focus") then
        return true
    end
    return false
end

--- Scan party/raid for healing targets
--- Populates scan_results with unit, hp, is_tank sorted by HP ascending
--- Returns: count, lowest_unit, lowest_hp, tank_unit, emergency_count, group_damaged_count
local function scan_healing_targets(context)
    scan_count = 0

    local emergency_hp = context.settings.holy_emergency_hp or context.settings.disc_emergency_hp or 30
    local aoe_hp = context.settings.holy_aoe_hp or 80
    local emergency_count = 0
    local group_damaged_count = 0
    local lowest_unit = nil
    local lowest_hp = 100
    local tank_unit = nil

    -- Always include self
    local self_hp = context.hp
    if self_hp and self_hp < 100 then
        scan_count = scan_count + 1
        local entry = scan_results[scan_count]
        entry.unit = PLAYER_UNIT
        entry.hp = self_hp
        entry.is_tank = false
        if self_hp < lowest_hp then
            lowest_hp = self_hp
            lowest_unit = PLAYER_UNIT
        end
        if self_hp < emergency_hp then emergency_count = emergency_count + 1 end
        if self_hp < aoe_hp then group_damaged_count = group_damaged_count + 1 end
    end

    local members = GetNumGroupMembers() or 0
    if members > 0 then
        local prefix = members > 5 and "raid" or "party"
        local count = members > 5 and members or (members - 1)
        for i = 1, count do
            if scan_count >= MAX_SCAN then break end
            local unit = prefix .. i
            if _G.UnitExists(unit) and not Unit(unit):IsDead() and Unit(unit):IsConnected() then
                local range = Unit(unit):GetRange()
                if range and range <= 40 then
                    local hp = Unit(unit):HealthPercent()
                    if hp and hp < 100 then
                        scan_count = scan_count + 1
                        local entry = scan_results[scan_count]
                        entry.unit = unit
                        entry.hp = hp
                        entry.is_tank = is_tank_unit(unit)

                        if entry.is_tank then
                            tank_unit = unit
                        end
                        if hp < lowest_hp then
                            lowest_hp = hp
                            lowest_unit = unit
                        end
                        if hp < emergency_hp then emergency_count = emergency_count + 1 end
                        if hp < aoe_hp then group_damaged_count = group_damaged_count + 1 end
                    else
                        -- Full HP but might be tank
                        if is_tank_unit(unit) then
                            tank_unit = unit
                        end
                    end
                end
            end
        end
    end

    -- If no tank found via focus, use lowest HP melee or self
    if not tank_unit then
        tank_unit = "focus"
        if not _G.UnitExists("focus") or Unit("focus"):IsDead() then
            tank_unit = PLAYER_UNIT
        end
    end

    return scan_count, lowest_unit, lowest_hp, tank_unit, emergency_count, group_damaged_count
end

NS.scan_healing_targets = scan_healing_targets

-- ============================================================================
-- WEAKENED SOUL CHECK
-- ============================================================================
local function has_weakened_soul(unit)
    if not unit or not _G.UnitExists(unit) then return true end
    return (Unit(unit):HasDeBuffs(Constants.DEBUFF_ID.WEAKENED_SOUL) or 0) > 0
end

NS.has_weakened_soul = has_weakened_soul

-- ============================================================================
-- HAS RENEW CHECK
-- ============================================================================
local function has_renew(unit)
    if not unit or not _G.UnitExists(unit) then return false end
    -- Check for Renew buff (base ID 139, max rank 25222)
    return (Unit(unit):HasBuffs(A.Renew.ID, "player") or 0) > 0
end

NS.has_renew = has_renew

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Healing utilities loaded")
