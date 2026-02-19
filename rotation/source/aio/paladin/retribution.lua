--- Retribution Paladin Module
--- Retribution playstyle strategies including seal twisting
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Retribution]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Retribution]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local Player = NS.Player
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local SealOfBloodAction = NS.SealOfBloodAction
local SEAL_BLOOD_BUFF_ID = NS.SEAL_BLOOD_BUFF_ID
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- WoW API for creature type check (Exorcism: Undead/Demon only)
local UnitCreatureType = _G.UnitCreatureType

-- ============================================================================
-- RETRIBUTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local ret_state = {
    seal_blood_active = false,
    seal_command_active = false,
    low_mana = false,
    can_exorcism = false,
    can_consecration = false,
    target_below_20 = false,
    in_twist_window = false,
    time_to_swing = 0,
    should_twist = false,
    target_undead_or_demon = false,
}

local function get_ret_state(context)
    if context._ret_valid then return ret_state end
    context._ret_valid = true

    -- Read directly from context (set in extend_context)
    ret_state.seal_blood_active = context.seal_blood_active
    ret_state.seal_command_active = context.seal_command_active
    ret_state.in_twist_window = context.in_twist_window
    ret_state.time_to_swing = context.time_to_swing

    -- Mana thresholds (from wowsims)
    ret_state.low_mana = context.mana <= Constants.TWIST.LOW_MANA
    ret_state.can_exorcism = context.mana_pct > Constants.MANA.EXORCISM_PCT
    ret_state.can_consecration = context.mana_pct > Constants.MANA.CONSEC_PCT

    -- Execute phase
    ret_state.target_below_20 = context.target_hp < 20

    -- Twist decision: enabled by setting AND not low mana
    ret_state.should_twist = context.settings.ret_seal_twist and not ret_state.low_mana

    -- Creature type check for Exorcism
    local ctype = UnitCreatureType(TARGET_UNIT)
    ret_state.target_undead_or_demon = (ctype == "Undead" or ctype == "Demon")

    return ret_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Avenging Wrath (off-GCD, +30% damage)
local Ret_AvengingWrath = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.AvengingWrath,

    matches = function(context, state)
        if not context.settings.use_avenging_wrath then return false end
        if context.forbearance_active then return false end
        if context.avenging_wrath_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.AvengingWrath, icon, PLAYER_UNIT, "[RET] Avenging Wrath")
    end,
}

-- [2] Trinket 1 (off-GCD)
local Ret_Trinket1 = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.Trinket1,

    matches = function(context, state)
        if not context.settings.use_trinket1 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.Trinket1:IsReady(PLAYER_UNIT) then
            return A.Trinket1:Show(icon), "[RET] Trinket 1"
        end
        return nil
    end,
}

-- [3] Trinket 2 (off-GCD)
local Ret_Trinket2 = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.Trinket2,

    matches = function(context, state)
        if not context.settings.use_trinket2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.Trinket2:IsReady(PLAYER_UNIT) then
            return A.Trinket2:Show(icon), "[RET] Trinket 2"
        end
        return nil
    end,
}

-- [4] Racial (off-GCD)
local Ret_Racial = {
    requires_combat = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if not context.settings.use_racial then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[RET] Arcane Torrent"
        end
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[RET] Stoneform"
        end
        return nil
    end,
}

-- [5] Complete Seal Twist: SoC active + in twist window → cast SoB
local Ret_CompleteSealTwist = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        if not state.seal_command_active then return false end
        if not state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        if SealOfBloodAction:IsReady(PLAYER_UNIT) then
            return SealOfBloodAction:Show(icon),
                format("[RET] Twist -> SoB (swing in %.2fs)", state.time_to_swing)
        end
        return nil
    end,
}

-- [6] Judge configured seal (off-GCD — Judgement does NOT trigger GCD in TBC)
local Ret_JudgeSeal = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        if not context.settings.ret_use_judgement then return false end
        -- Check if the seal we want to judge is active
        local judge = context.settings.ret_judge_seal or "blood"
        if judge == "blood" then
            if not state.seal_blood_active then return false end
        elseif judge == "crusader" then
            if not context.seal_crusader_active then return false end
        elseif judge == "wisdom" then
            if not context.seal_wisdom_active then return false end
        elseif judge == "light" then
            if not context.seal_light_active then return false end
        else
            if not context.has_any_seal then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        local judge = context.settings.ret_judge_seal or "blood"
        return try_cast(A.Judgement, icon, TARGET_UNIT, format("[RET] Judge (%s)", judge))
    end,
}

-- [7] Crusader Strike (6s CD)
local Ret_CrusaderStrike = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.CrusaderStrike,

    matches = function(context, state)
        if not context.settings.ret_use_crusader_strike then return false end
        -- When twisting: don't CS if in twist window or swing imminent
        if state.should_twist and state.seal_command_active then
            if state.in_twist_window then return false end
            if state.time_to_swing > 0 and state.time_to_swing < 1.5 then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.CrusaderStrike, icon, TARGET_UNIT, "[RET] Crusader Strike")
    end,
}

-- [8] Prep Seal Twist: cast SoC R1 to set up next twist
local Ret_PrepSealTwist = {
    requires_combat = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        -- Only prep if SoC is not already active
        if state.seal_command_active then return false end
        -- Don't prep if in twist window (too late)
        if state.in_twist_window then return false end
        -- Don't prep if swing is very imminent
        if state.time_to_swing > 0 and state.time_to_swing < 0.5 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.SealOfCommandR1:IsReady(PLAYER_UNIT) then
            return A.SealOfCommandR1:Show(icon),
                format("[RET] Prep SoC R1 (swing in %.2fs)", state.time_to_swing)
        end
        return nil
    end,
}

-- [9] Hammer of Wrath (execute phase, target < 20%)
local Ret_HammerOfWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HammerOfWrath,

    matches = function(context, state)
        if not context.settings.ret_use_hammer_of_wrath then return false end
        if not state.target_below_20 then return false end
        -- Don't clip twist
        if state.should_twist and state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HammerOfWrath, icon, TARGET_UNIT, "[RET] Hammer of Wrath")
    end,
}

-- [10] Exorcism (Undead/Demon only, mana > 40%)
local Ret_Exorcism = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Exorcism,

    matches = function(context, state)
        if not context.settings.ret_use_exorcism then return false end
        if not state.target_undead_or_demon then return false end
        if not state.can_exorcism then return false end
        -- Don't clip twist window
        if state.should_twist and state.in_twist_window then return false end
        -- Need enough time before next swing for the 1.5s cast
        if state.should_twist and state.time_to_swing > 0 and state.time_to_swing < 2.0 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Exorcism, icon, TARGET_UNIT, "[RET] Exorcism")
    end,
}

-- [11] Consecration (filler, mana > 60%)
local Ret_Consecration = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Consecration,

    matches = function(context, state)
        if not context.settings.ret_use_consecration then return false end
        if not state.can_consecration then return false end
        -- AoE threshold check
        local aoe_thresh = context.settings.ret_aoe_threshold or 0
        if aoe_thresh > 0 and context.enemy_count < aoe_thresh then return false end
        -- Don't clip twist window
        if state.should_twist and state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Consecration, icon, PLAYER_UNIT, "[RET] Consecration")
    end,
}

-- [12] Maintain Seal fallback (no seal active — catch-all)
local Ret_MaintainSealFallback = {
    requires_combat = true,

    matches = function(context, state)
        if context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        if SealOfBloodAction:IsReady(PLAYER_UNIT) then
            return SealOfBloodAction:Show(icon), "[RET] Re-seal SoB (fallback)"
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("retribution", {
    named("AvengingWrath",       Ret_AvengingWrath),
    named("Trinket1",            Ret_Trinket1),
    named("Trinket2",            Ret_Trinket2),
    named("Racial",              Ret_Racial),
    named("CompleteSealTwist",   Ret_CompleteSealTwist),
    named("JudgeSeal",           Ret_JudgeSeal),
    named("CrusaderStrike",      Ret_CrusaderStrike),
    named("PrepSealTwist",       Ret_PrepSealTwist),
    named("HammerOfWrath",       Ret_HammerOfWrath),
    named("Exorcism",            Ret_Exorcism),
    named("Consecration",        Ret_Consecration),
    named("MaintainSealFallback", Ret_MaintainSealFallback),
}, {
    context_builder = get_ret_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Paladin]|r Retribution module loaded")
