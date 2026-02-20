-- Priest Discipline Healing Module
-- Damage prevention with PW:S, Pain Suppression, Power Infusion

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Disc]|r Core module not loaded!")
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
local has_weakened_soul = NS.has_weakened_soul
local has_renew = NS.has_renew

local PLAYER_UNIT = "player"

-- ============================================================================
-- DISCIPLINE STATE (per-frame cache)
-- ============================================================================
local disc_state = {
    lowest_unit = nil,
    lowest_hp = 100,
    tank_unit = nil,
    emergency_count = 0,
    group_damaged_count = 0,
    scan_count = 0,
    tank_has_weakened_soul = false,
    inner_focus_ready = false,
    pain_suppression_ready = false,
    power_infusion_ready = false,
    pom_ready = false,
}

local function get_disc_state(context)
    if context._disc_valid then return disc_state end
    context._disc_valid = true

    disc_state.inner_focus_ready = is_spell_available(A.InnerFocus) and A.InnerFocus:IsReady(PLAYER_UNIT)
    disc_state.pain_suppression_ready = is_spell_available(A.PainSuppression) and (A.PainSuppression:GetCooldown() or 0) < 0.5
    disc_state.power_infusion_ready = is_spell_available(A.PowerInfusion) and (A.PowerInfusion:GetCooldown() or 0) < 0.5
    disc_state.pom_ready = is_spell_available(A.PrayerOfMending) and A.PrayerOfMending:IsReady(PLAYER_UNIT)

    -- Scan healing targets
    local count, lowest, lowest_hp, tank, emerg, group_dmg = scan_healing_targets(context)
    disc_state.scan_count = count
    disc_state.lowest_unit = lowest
    disc_state.lowest_hp = lowest_hp or 100
    disc_state.tank_unit = tank
    disc_state.emergency_count = emerg
    disc_state.group_damaged_count = group_dmg

    -- Check Weakened Soul on tank
    disc_state.tank_has_weakened_soul = has_weakened_soul(tank)

    return disc_state
end

-- ============================================================================
-- DISCIPLINE STRATEGIES
-- ============================================================================
rotation_registry:register("discipline", {

    -- [1] Pain Suppression (tank critically low, off-GCD)
    named("PainSuppression", {
        is_gcd_gated = false,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_pain_suppression then return false end
            if not state.pain_suppression_ready then return false end
            if not state.tank_unit then return false end
            local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
            local threshold = context.settings.disc_pain_suppression_hp or 20
            return tank_hp < threshold
        end,
        execute = function(icon, context, state)
            if A.PainSuppression:IsReady(state.tank_unit) then
                local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
                return A.PainSuppression:Show(icon), format("[DISC] Pain Suppression -> %s (%.0f%%)", state.tank_unit, tank_hp)
            end
            return nil
        end,
    }),

    -- [2] Emergency Flash Heal (critically low target)
    named("EmergencyFlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            local threshold = context.settings.disc_emergency_hp or 25
            return state.lowest_hp < threshold and state.lowest_unit ~= nil
        end,
        execute = function(icon, context, state)
            if A.FlashHeal:IsReady(state.lowest_unit) then
                return A.FlashHeal:Show(icon), format("[DISC] Emergency FH -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [3] PW:S on tank (if no Weakened Soul)
    named("ShieldTank", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.tank_unit then return false end
            if state.tank_has_weakened_soul then return false end
            local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
            local threshold = context.settings.disc_shield_hp or 90
            return tank_hp < threshold
        end,
        execute = function(icon, context, state)
            if A.PowerWordShield:IsReady(state.tank_unit) then
                local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
                return A.PowerWordShield:Show(icon), format("[DISC] PW:S -> %s (tank, %.0f%%)", state.tank_unit, tank_hp)
            end
            return nil
        end,
    }),

    -- [4] Prayer of Mending (instant, 10s CD)
    named("PrayerOfMending", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.pom_ready then return false end
            return state.tank_unit ~= nil or state.lowest_unit ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.tank_unit or state.lowest_unit
            if target and A.PrayerOfMending:IsReady(target) then
                return A.PrayerOfMending:Show(icon), format("[DISC] Prayer of Mending -> %s", target)
            end
            return nil
        end,
    }),

    -- [5] Inner Focus + Greater Heal (off-GCD trigger + free GH)
    named("InnerFocusGreaterHeal", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_inner_focus then return false end
            if not state.inner_focus_ready then return false end
            if context.has_inner_focus then return false end
            -- Only if someone needs healing
            if not state.lowest_unit then return false end
            return state.lowest_hp < 80
        end,
        execute = function(icon, context, state)
            if A.InnerFocus:IsReady(PLAYER_UNIT) then
                return A.InnerFocus:Show(icon), "[DISC] Inner Focus (+ Greater Heal)"
            end
            return nil
        end,
    }),

    -- [6] Power Infusion (off-GCD, self or focus)
    named("PowerInfusion", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_power_infusion then return false end
            if not state.power_infusion_ready then return false end
            if context.has_power_infusion then return false end
            return true
        end,
        execute = function(icon, context, state)
            -- Cast on self for healing throughput
            if A.PowerInfusion:IsReady(PLAYER_UNIT) then
                return A.PowerInfusion:Show(icon), "[DISC] Power Infusion (self)"
            end
            return nil
        end,
    }),

    -- [7] Trinkets (off-GCD)
    named("Trinkets", {
        is_gcd_gated = false,
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then return true end
            if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then return true end
            return false
        end,
        execute = function(icon, context, state)
            if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then
                return A.Trinket1:Show(icon), "[DISC] Trinket 1"
            end
            if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then
                return A.Trinket2:Show(icon), "[DISC] Trinket 2"
            end
            return nil
        end,
    }),

    -- [8] Racial (off-GCD)
    named("Racial", {
        is_gcd_gated = false,
        setting_key = "use_racial",
        matches = function(context, state)
            if not context.in_combat then return false end
            if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then return true end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
            return false
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then
                return A.Berserking:Show(icon), "[DISC] Berserking"
            end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
                return A.ArcaneTorrent:Show(icon), "[DISC] Arcane Torrent"
            end
            return nil
        end,
    }),

    -- [9] PW:S on non-tank (if not tank-only mode)
    named("ShieldOthers", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.settings.disc_shield_tank_only then return false end
            if not state.lowest_unit then return false end
            -- Don't re-shield tank (handled above)
            if state.lowest_unit == state.tank_unit then return false end
            if has_weakened_soul(state.lowest_unit) then return false end
            local threshold = context.settings.disc_shield_hp or 90
            return state.lowest_hp < threshold
        end,
        execute = function(icon, context, state)
            if A.PowerWordShield:IsReady(state.lowest_unit) then
                return A.PowerWordShield:Show(icon), format("[DISC] PW:S -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [10] Renew on tank (maintain HoT)
    named("RenewTank", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.tank_unit then return false end
            if Unit(state.tank_unit):IsDead() then return false end
            local tank_hp = Unit(state.tank_unit):HealthPercent() or 100
            local threshold = context.settings.disc_renew_hp or 85
            if tank_hp > threshold then return false end
            if has_renew(state.tank_unit) then return false end
            return true
        end,
        execute = function(icon, context, state)
            if A.Renew:IsReady(state.tank_unit) then
                return A.Renew:Show(icon), format("[DISC] Renew -> %s (tank)", state.tank_unit)
            end
            return nil
        end,
    }),

    -- [11] Greater Heal (sustained healing, with Inner Focus buff if active)
    named("GreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest_unit then return false end
            local flash_hp = context.settings.disc_flash_heal_hp or 50
            return state.lowest_hp < (context.settings.disc_renew_hp or 85) and state.lowest_hp >= flash_hp
        end,
        execute = function(icon, context, state)
            if A.GreaterHeal:IsReady(state.lowest_unit) then
                return A.GreaterHeal:Show(icon), format("[DISC] Greater Heal -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [12] Flash Heal (moderate urgency)
    named("FlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest_unit then return false end
            local flash_hp = context.settings.disc_flash_heal_hp or 50
            return state.lowest_hp < flash_hp
        end,
        execute = function(icon, context, state)
            if A.FlashHeal:IsReady(state.lowest_unit) then
                return A.FlashHeal:Show(icon), format("[DISC] Flash Heal -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [13] Renew on injured (HoT spread)
    named("RenewSpread", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.lowest_unit then return false end
            local threshold = context.settings.disc_renew_hp or 85
            if state.lowest_hp > threshold then return false end
            if has_renew(state.lowest_unit) then return false end
            return true
        end,
        execute = function(icon, context, state)
            if A.Renew:IsReady(state.lowest_unit) then
                return A.Renew:Show(icon), format("[DISC] Renew -> %s (%.0f%%)", state.lowest_unit, state.lowest_hp)
            end
            return nil
        end,
    }),

    -- [14] Prayer of Healing (group damage)
    named("PrayerOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            return state.group_damaged_count >= (context.settings.disc_aoe_count or 3)
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.PrayerOfHealing) and A.PrayerOfHealing:IsReady(PLAYER_UNIT) then
                return A.PrayerOfHealing:Show(icon), format("[DISC] Prayer of Healing (%d hurt)", state.group_damaged_count)
            end
            return nil
        end,
    }),

}, {
    context_builder = get_disc_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Discipline rotation loaded")
