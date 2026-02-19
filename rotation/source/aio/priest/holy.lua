-- Priest Holy Healing Module
-- Reactive healing with Circle of Healing, Prayer of Mending, proc management

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Priest Holy]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named
local scan_healing_targets = NS.scan_healing_targets
local has_renew = NS.has_renew

local PLAYER_UNIT = "player"

-- ============================================================================
-- HOLY STATE (per-frame cache)
-- ============================================================================
local holy_state = {
    lowest_unit = nil,
    lowest_hp = 100,
    tank_unit = nil,
    emergency_count = 0,
    group_damaged_count = 0,
    scan_count = 0,
    surge_of_light = false,
    clearcasting = false,
    pom_ready = false,
    coh_ready = false,
}

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    holy_state.surge_of_light = context.has_surge_of_light
    holy_state.clearcasting = context.has_clearcasting
    holy_state.pom_ready = is_spell_available(A.PrayerOfMending) and A.PrayerOfMending:IsReady(PLAYER_UNIT)
    holy_state.coh_ready = is_spell_available(A.CircleOfHealing) and A.CircleOfHealing:IsReady(PLAYER_UNIT)

    -- Scan healing targets
    local count, lowest, lowest_hp, tank, emerg, group_dmg = scan_healing_targets(context)
    holy_state.scan_count = count
    holy_state.lowest_unit = lowest
    holy_state.lowest_hp = lowest_hp or 100
    holy_state.tank_unit = tank
    holy_state.emergency_count = emerg
    holy_state.group_damaged_count = group_dmg

    return holy_state
end

-- ============================================================================
-- HOLY STRATEGIES
-- ============================================================================
rotation_registry:register("holy", {

    -- [1] Prayer of Mending (instant, 10s CD, best HPM)
    named("PrayerOfMending", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.pom_ready then return false end
            -- Cast on tank if available, otherwise lowest
            return state.tank_unit ~= nil or state.lowest_unit ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.tank_unit or state.lowest_unit
            if target and A.PrayerOfMending:IsReady(target) then
                return A.PrayerOfMending:Show(icon), format("[HOLY] Prayer of Mending -> %s", target)
            end
            return nil
        end,
    }),

    -- [2] Surge of Light Smite (free instant Smite if no urgent healing)
    named("SurgeOfLightSmite", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.surge_of_light then return false end
            if not context.has_valid_enemy_target then return false end
            -- Only if nobody is critically low
            if state.lowest_hp < (context.settings.holy_flash_heal_hp or 50) then return false end
            return true
        end,
        execute = function(icon, context, state)
            return try_cast(A.Smite, icon, "target", "[HOLY] Surge of Light Smite")
        end,
    }),

    -- [3] Circle of Healing (instant, group damage)
    named("CircleOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.holy_use_coh then return false end
            if not state.coh_ready then return false end
            local min_count = context.settings.holy_aoe_count or 3
            return state.group_damaged_count >= min_count
        end,
        execute = function(icon, context, state)
            -- Cast on lowest target (CoH smart-heals 5 lowest in their party)
            local target = state.lowest_unit or state.tank_unit
            if target and A.CircleOfHealing:IsReady(target) then
                return A.CircleOfHealing:Show(icon), format("[HOLY] Circle of Healing -> %s (%d hurt)", target, state.group_damaged_count)
            end
            return nil
        end,
    }),

    -- [4] Emergency Flash Heal (target below emergency HP)
    named("EmergencyFlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            local threshold = context.settings.holy_emergency_hp or 30
            return state.lowest_hp < threshold and state.lowest_unit ~= nil
        end,
        execute = function(icon, context, state)
            if A.FlashHeal:IsReady(state.lowest_unit) then
                return A.FlashHeal:Show(icon), format("[HOLY] Emergency FH -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [5] Binding Heal (self + target both damaged)
    named("BindingHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_use_binding_heal then return false end
            local self_threshold = context.settings.holy_binding_self_hp or 80
            if context.hp > self_threshold then return false end
            -- Need a heal target too
            if not state.lowest_unit then return false end
            if state.lowest_unit == PLAYER_UNIT then return false end
            return is_spell_available(A.BindingHeal)
        end,
        execute = function(icon, context, state)
            if A.BindingHeal:IsReady(state.lowest_unit) then
                return A.BindingHeal:Show(icon), format("[HOLY] Binding Heal -> %s (self: %.0f%%)", state.lowest_unit, context.hp)
            end
            return nil
        end,
    }),

    -- [6] Clearcasting Greater Heal (free heal from Holy Concentration)
    named("ClearcastingGreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.clearcasting then return false end
            if not state.lowest_unit then return false end
            return state.lowest_hp < 90
        end,
        execute = function(icon, context, state)
            if A.GreaterHeal:IsReady(state.lowest_unit) then
                return A.GreaterHeal:Show(icon), format("[HOLY] Clearcasting GH -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [7] Renew on tank (maintain HoT)
    named("RenewTank", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.tank_unit then return false end
            if Unit(state.tank_unit):IsDead() then return false end
            local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
            local threshold = context.settings.holy_renew_hp or 90
            if tank_hp > threshold then return false end
            if has_renew(state.tank_unit) then return false end
            return true
        end,
        execute = function(icon, context, state)
            if A.Renew:IsReady(state.tank_unit) then
                return A.Renew:Show(icon), format("[HOLY] Renew -> %s (tank)", state.tank_unit)
            end
            return nil
        end,
    }),

    -- [8] Renew on injured (HoT spread — instant, before cast-time heals)
    named("RenewSpread", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.lowest_unit then return false end
            local threshold = context.settings.holy_renew_hp or 90
            if state.lowest_hp > threshold then return false end
            if has_renew(state.lowest_unit) then return false end
            return true
        end,
        execute = function(icon, context, state)
            if A.Renew:IsReady(state.lowest_unit) then
                return A.Renew:Show(icon), format("[HOLY] Renew -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [9] Greater Heal (sustained healing, target above flash threshold)
    named("GreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest_unit then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            -- GH for targets between flash threshold and renew threshold
            return state.lowest_hp < (context.settings.holy_renew_hp or 90) and state.lowest_hp >= flash_hp
        end,
        execute = function(icon, context, state)
            if A.GreaterHeal:IsReady(state.lowest_unit) then
                return A.GreaterHeal:Show(icon), format("[HOLY] Greater Heal -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [10] Flash Heal (urgent healing)
    named("FlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest_unit then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            return state.lowest_hp < flash_hp
        end,
        execute = function(icon, context, state)
            if A.FlashHeal:IsReady(state.lowest_unit) then
                return A.FlashHeal:Show(icon), format("[HOLY] Flash Heal -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [11] Prayer of Healing (group damage)
    named("PrayerOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_use_poh then return false end
            local min_count = context.settings.holy_aoe_count or 3
            return state.group_damaged_count >= min_count
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.PrayerOfHealing) and A.PrayerOfHealing:IsReady(PLAYER_UNIT) then
                return A.PrayerOfHealing:Show(icon), format("[HOLY] Prayer of Healing (%d hurt)", state.group_damaged_count)
            end
            return nil
        end,
    }),

}, {
    context_builder = get_holy_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Priest]|r Holy rotation loaded")
