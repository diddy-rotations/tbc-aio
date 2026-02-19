--- Fury Warrior Module
--- Fury playstyle strategies: Bloodthirst + Whirlwind + Rampage + rage dumping
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Fury]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Fury]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- FURY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local fury_state = {
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
}

local function get_fury_state(context)
    if context._fury_valid then return fury_state end
    context._fury_valid = true

    fury_state.target_below_20 = context.target_hp < 20
    fury_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    fury_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0

    return fury_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Rampage maintenance (Fury 41-point talent)
-- Activate after melee crit, refresh when duration is low (stacks build naturally via refreshes)
local Fury_Rampage = {
    requires_combat = true,

    matches = function(context, state)
        if not is_spell_available(A.Rampage) then return false end
        local threshold = context.settings.fury_rampage_threshold or 5
        -- Activate if buff not present
        if not context.rampage_active then
            return A.Rampage:IsReady(PLAYER_UNIT)
        end
        -- Refresh when duration running low (also adds a stack)
        if context.rampage_duration < threshold then
            return A.Rampage:IsReady(PLAYER_UNIT)
        end
        return false
    end,

    execute = function(icon, context, state)
        return try_cast(A.Rampage, icon, PLAYER_UNIT,
            format("[FURY] Rampage - Stacks: %d, Duration: %.1fs", context.rampage_stacks, context.rampage_duration))
    end,
}

-- [2] Bloodthirst (primary damage, any stance)
local Fury_Bloodthirst = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_bt_during_execute then return false end
        end
        -- If WW is prioritized, BT runs at lower position (handled by registration order)
        if context.settings.fury_prioritize_ww then return false end
        return A.Bloodthirst:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Bloodthirst, icon, TARGET_UNIT, "[FURY] Bloodthirst")
    end,
}

-- [3] Whirlwind (Berserker Stance)
local Fury_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_use_whirlwind then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_ww_during_execute then return false end
        end
        -- Whirlwind requires Berserker Stance — IsReady handles check
        return A.Whirlwind:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Whirlwind, icon, TARGET_UNIT, "[FURY] Whirlwind")
    end,
}

-- [4] Bloodthirst (lower priority — when WW is prioritized, BT falls here)
local Fury_BloodthirstLow = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- Only runs when WW is prioritized
        if not context.settings.fury_prioritize_ww then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_bt_during_execute then return false end
        end
        return A.Bloodthirst:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Bloodthirst, icon, TARGET_UNIT, "[FURY] Bloodthirst")
    end,
}

-- [5] Execute (target <20% HP)
local Fury_Execute = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_execute_phase then return false end
        if not state.target_below_20 then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[FURY] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [6] Sunder Armor maintenance (if configured)
local Fury_SunderMaintain = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local mode = context.settings.sunder_armor_mode or "none"
        if mode == "none" then return false end

        if mode == "help_stack" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS then return false end
        elseif mode == "maintain" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS
                and state.sunder_duration > Constants.SUNDER_REFRESH_WINDOW then
                return false
            end
        end

        -- Sunder/Devastate require Defensive Stance
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[FURY] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[FURY] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [7] Slam (filler, any stance)
local Fury_Slam = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_use_slam then return false end
        if context.is_moving then return false end
        -- Don't Slam in execute phase
        if state.target_below_20 and context.settings.fury_execute_phase then return false end
        return A.Slam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Slam, icon, TARGET_UNIT, "[FURY] Slam")
    end,
}

-- [8] Overpower (Battle Stance only, dodge proc)
local Fury_Overpower = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_use_overpower then return false end
        local min_rage = context.settings.fury_overpower_rage or 25
        if context.rage < min_rage then return false end
        -- Overpower requires Battle Stance — IsReady handles check
        return A.Overpower:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Overpower, icon, TARGET_UNIT,
            format("[FURY] Overpower - Rage: %d", context.rage))
    end,
}

-- [9] Hamstring weave (for Sword Spec procs)
local Fury_Hamstring = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_use_hamstring then return false end
        local min_rage = context.settings.fury_hamstring_rage or 50
        if context.rage < min_rage then return false end
        return A.Hamstring:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Hamstring, icon, TARGET_UNIT,
            format("[FURY] Hamstring - Rage: %d", context.rage))
    end,
}

-- [10] Heroic Strike / Cleave (off-GCD rage dump)
local Fury_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if not context.settings.fury_use_heroic_strike then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_hs_during_execute then return false end
        end
        local threshold = context.settings.fury_hs_rage_threshold or 50
        if context.rage < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Use Cleave if AoE threshold met
        local aoe = context.settings.aoe_threshold or 0
        if aoe > 0 and context.enemy_count >= aoe and A.Cleave:IsReady(TARGET_UNIT) then
            return try_cast(A.Cleave, icon, TARGET_UNIT,
                format("[FURY] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count))
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return try_cast(A.HeroicStrike, icon, TARGET_UNIT,
                format("[FURY] Heroic Strike - Rage: %d", context.rage))
        end
        return nil
    end,
}

-- [11] Victory Rush (free instant after killing blow)
local Fury_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,

    matches = function(context, state)
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[FURY] Victory Rush")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("fury", {
    named("Rampage",         Fury_Rampage),
    named("Bloodthirst",     Fury_Bloodthirst),
    named("Whirlwind",       Fury_Whirlwind),
    named("BloodthirstLow",  Fury_BloodthirstLow),
    named("Execute",         Fury_Execute),
    named("SunderMaintain",  Fury_SunderMaintain),
    named("Slam",            Fury_Slam),
    named("Overpower",       Fury_Overpower),
    named("VictoryRush",     Fury_VictoryRush),
    named("Hamstring",       Fury_Hamstring),
    named("HeroicStrike",    Fury_HeroicStrike),
}, {
    context_builder = get_fury_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Warrior]|r Fury module loaded")
