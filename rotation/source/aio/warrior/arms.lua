--- Arms Warrior Module
--- Arms playstyle strategies: Mortal Strike + Overpower + Whirlwind with stance dancing
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Arms]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Arms]|r Registry not found!")
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
-- ARMS STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local arms_state = {
    rend_active = false,
    rend_duration = 0,
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
}

local function get_arms_state(context)
    if context._arms_valid then return arms_state end
    context._arms_valid = true

    arms_state.rend_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.REND) or 0
    arms_state.rend_active = arms_state.rend_duration > 0
    arms_state.target_below_20 = context.target_hp < 20
    arms_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    arms_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    arms_state.thunder_clap_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    arms_state.demo_shout_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0

    return arms_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Maintain Rend (for Blood Frenzy talent — +4% physical damage)
local Arms_MaintainRend = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_maintain_rend then return false end
        -- Don't bother rending in execute phase
        if state.target_below_20 and context.settings.arms_execute_phase then return false end
        local refresh = context.settings.arms_rend_refresh or 4
        if state.rend_active and state.rend_duration > refresh then return false end
        -- Rend works in Battle or Defensive Stance
        return A.Rend:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Rend, icon, TARGET_UNIT,
            format("[ARMS] Rend - Duration: %.1fs", state.rend_duration))
    end,
}

-- [2] Overpower (Battle Stance only, dodge proc)
local Arms_Overpower = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_use_overpower then return false end
        local min_rage = context.settings.arms_overpower_rage or 25
        if context.rage < min_rage then return false end
        -- Overpower requires Battle Stance — IsReady handles stance check
        return A.Overpower:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Overpower, icon, TARGET_UNIT,
            format("[ARMS] Overpower - Rage: %d", context.rage))
    end,
}

-- [3] Mortal Strike (primary damage, any stance)
local Arms_MortalStrike = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_use_ms_execute then return false end
        end
        return A.MortalStrike:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.MortalStrike, icon, TARGET_UNIT, "[ARMS] Mortal Strike")
    end,
}

-- [4] Whirlwind (Berserker Stance only)
local Arms_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_use_whirlwind then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_use_ww_execute then return false end
        end
        -- Whirlwind requires Berserker Stance — IsReady handles stance check
        return A.Whirlwind:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Whirlwind, icon, TARGET_UNIT, "[ARMS] Whirlwind")
    end,
}

-- [5] Sweeping Strikes (Battle Stance, Arms talent — on GCD in TBC)
local Arms_SweepingStrikes = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_use_sweeping_strikes then return false end
        if context.sweeping_strikes_active then return false end
        -- More valuable with multiple targets
        if context.enemy_count < 2 then return false end
        -- Sweeping Strikes requires Battle Stance — IsReady handles check
        return A.SweepingStrikes:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.SweepingStrikes, icon, PLAYER_UNIT,
            format("[ARMS] Sweeping Strikes - Enemies: %d", context.enemy_count))
    end,
}

-- [6] Execute (target <20% HP, dump rage)
local Arms_Execute = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_execute_phase then return false end
        if not state.target_below_20 then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[ARMS] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [7] Sunder Armor maintenance (if configured)
local Arms_SunderMaintain = {
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

        -- Sunder Armor requires Defensive Stance; Devastate also Defensive
        -- Try Devastate first if talented, fall back to Sunder
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[ARMS] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[ARMS] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [8] Thunder Clap maintenance (Battle/Defensive Stance)
local Arms_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_thunder_clap",

    matches = function(context, state)
        if state.thunder_clap_duration > 2 then return false end
        -- TC requires Battle or Defensive Stance (not Berserker)
        return A.ThunderClap:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ThunderClap, icon, TARGET_UNIT,
            format("[ARMS] Thunder Clap - Duration: %.1fs", state.thunder_clap_duration))
    end,
}

-- [9] Demoralizing Shout maintenance (all stances)
local Arms_DemoShout = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_demo_shout",

    matches = function(context, state)
        if state.demo_shout_duration > 3 then return false end
        return A.DemoralizingShout:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, PLAYER_UNIT,
            format("[ARMS] Demo Shout - Duration: %.1fs", state.demo_shout_duration))
    end,
}

-- [10] Slam (filler, any stance)
local Arms_Slam = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.arms_use_slam then return false end
        if context.is_moving then return false end
        -- Don't Slam in execute phase (Execute is better use of rage)
        if state.target_below_20 and context.settings.arms_execute_phase then return false end
        return A.Slam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Slam, icon, TARGET_UNIT, "[ARMS] Slam")
    end,
}

-- [9] Heroic Strike / Cleave (off-GCD rage dump)
local Arms_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_hs_during_execute then return false end
        end
        local threshold = context.settings.arms_hs_rage_threshold or 55
        if context.rage < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Use Cleave if AoE threshold met
        local aoe = context.settings.aoe_threshold or 0
        if aoe > 0 and context.enemy_count >= aoe and A.Cleave:IsReady(TARGET_UNIT) then
            return try_cast(A.Cleave, icon, TARGET_UNIT,
                format("[ARMS] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count))
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return try_cast(A.HeroicStrike, icon, TARGET_UNIT,
                format("[ARMS] Heroic Strike - Rage: %d", context.rage))
        end
        return nil
    end,
}

-- [10] Victory Rush (free instant after killing blow)
local Arms_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,

    matches = function(context, state)
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[ARMS] Victory Rush")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("arms", {
    named("MaintainRend",    Arms_MaintainRend),
    named("MortalStrike",    Arms_MortalStrike),
    named("Whirlwind",       Arms_Whirlwind),
    named("SweepingStrikes", Arms_SweepingStrikes),
    named("Execute",         Arms_Execute),
    named("SunderMaintain",  Arms_SunderMaintain),
    named("ThunderClap",     Arms_ThunderClap),
    named("DemoShout",       Arms_DemoShout),
    named("Overpower",       Arms_Overpower),
    named("Slam",            Arms_Slam),
    named("VictoryRush",     Arms_VictoryRush),
    named("HeroicStrike",    Arms_HeroicStrike),
}, {
    context_builder = get_arms_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Warrior]|r Arms module loaded")
