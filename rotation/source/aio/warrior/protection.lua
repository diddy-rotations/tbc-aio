--- Protection Warrior Module
--- Protection playstyle strategies: Shield Slam + Revenge + Devastate threat rotation
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Protection]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Protection]|r Registry not found!")
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
-- PROTECTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local prot_state = {
    revenge_available = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_debuff = 0,
    demo_shout_debuff = 0,
    target_below_20 = false,
}

local function get_prot_state(context)
    if context._prot_valid then return prot_state end
    context._prot_valid = true

    prot_state.revenge_available = A.Revenge:IsReady(TARGET_UNIT)
    prot_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    prot_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    prot_state.thunder_clap_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    prot_state.demo_shout_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    prot_state.target_below_20 = context.target_hp < 20

    return prot_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Shield Block (crush prevention, off-GCD, Defensive Stance)
local Prot_ShieldBlock = {
    requires_combat = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if not context.settings.prot_use_shield_block then return false end
        if context.shield_block_active then return false end
        -- Shield Block requires Defensive Stance — IsReady handles check
        return A.ShieldBlock:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShieldBlock, icon, PLAYER_UNIT, "[PROT] Shield Block")
    end,
}

-- [2] Shield Slam (highest single-target threat, 6s CD)
local Prot_ShieldSlam = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- Shield Slam is a Prot talent — IsReady + is_spell_available handle checks
        return A.ShieldSlam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShieldSlam, icon, TARGET_UNIT, "[PROT] Shield Slam")
    end,
}

-- [3] Revenge (proc-based, highest threat/rage, Defensive Stance)
local Prot_Revenge = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.prot_use_revenge then return false end
        -- Revenge requires Defensive Stance + block/dodge/parry proc
        return state.revenge_available
    end,

    execute = function(icon, context, state)
        return try_cast(A.Revenge, icon, TARGET_UNIT, "[PROT] Revenge")
    end,
}

-- [4] Devastate (filler, applies Sunder Armor, Prot 41-point talent)
local Prot_Devastate = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.prot_use_devastate then return false end
        if not is_spell_available(A.Devastate) then return false end
        -- Devastate requires Defensive Stance
        return A.Devastate:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Devastate, icon, TARGET_UNIT,
            format("[PROT] Devastate - Sunder: %d stacks", state.sunder_stacks))
    end,
}

-- [5] Sunder Armor (if Devastate not available, build/maintain stacks)
local Prot_SunderArmor = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- Only use if Devastate is not available (not talented or not learned)
        if is_spell_available(A.Devastate) then return false end
        -- Maintain up to 5 stacks, refresh at low duration
        if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS
            and state.sunder_duration > Constants.SUNDER_REFRESH_WINDOW then
            return false
        end
        -- Sunder Armor requires Defensive Stance
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[PROT] Sunder Armor - Stacks: %d, Duration: %.1fs", state.sunder_stacks, state.sunder_duration))
    end,
}

-- [6] Thunder Clap maintenance (Battle Stance only)
local Prot_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.prot_use_thunder_clap then return false end
        -- Only refresh when debuff is missing or about to expire
        if state.thunder_clap_debuff > Constants.TC_REFRESH_WINDOW then return false end
        -- Thunder Clap requires Battle Stance — only fires when warrior is in Battle
        return A.ThunderClap:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ThunderClap, icon, TARGET_UNIT,
            format("[PROT] Thunder Clap - Debuff: %.1fs", state.thunder_clap_debuff))
    end,
}

-- [7] Demoralizing Shout maintenance
local Prot_DemoShout = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.prot_use_demo_shout then return false end
        -- Only refresh when debuff is missing or about to expire
        if state.demo_shout_debuff > 3 then return false end
        return A.DemoralizingShout:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, TARGET_UNIT,
            format("[PROT] Demoralizing Shout - Debuff: %.1fs", state.demo_shout_debuff))
    end,
}

-- [8] Heroic Strike / Cleave (off-GCD rage dump)
local Prot_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        local threshold = context.settings.prot_hs_rage_threshold or 60
        if context.rage < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Use Cleave if AoE threshold met
        local aoe = context.settings.aoe_threshold or 0
        if aoe > 0 and context.enemy_count >= aoe and A.Cleave:IsReady(TARGET_UNIT) then
            return try_cast(A.Cleave, icon, TARGET_UNIT,
                format("[PROT] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count))
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return try_cast(A.HeroicStrike, icon, TARGET_UNIT,
                format("[PROT] Heroic Strike - Rage: %d", context.rage))
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("protection", {
    named("ShieldBlock",    Prot_ShieldBlock),
    named("ShieldSlam",     Prot_ShieldSlam),
    named("Revenge",        Prot_Revenge),
    named("Devastate",      Prot_Devastate),
    named("SunderArmor",    Prot_SunderArmor),
    named("ThunderClap",    Prot_ThunderClap),
    named("DemoShout",      Prot_DemoShout),
    named("HeroicStrike",   Prot_HeroicStrike),
}, {
    context_builder = get_prot_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Warrior]|r Protection module loaded")
