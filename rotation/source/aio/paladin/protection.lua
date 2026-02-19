--- Protection Paladin Module
--- Protection playstyle strategies (spell-based tanking)
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
local Player = NS.Player
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- WoW API for creature type check (Exorcism: Undead/Demon only)
local UnitCreatureType = _G.UnitCreatureType

-- ============================================================================
-- PROTECTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local prot_state = {
    righteous_fury_active = false,
    holy_shield_active = false,
    holy_shield_duration = 0,
    target_below_20 = false,
    target_undead_or_demon = false,
    can_exorcism = false,
}

local function get_prot_state(context)
    if context._prot_valid then return prot_state end
    context._prot_valid = true

    prot_state.righteous_fury_active = context.righteous_fury_active
    prot_state.holy_shield_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.HOLY_SHIELD) or 0) > 0
    prot_state.holy_shield_duration = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.HOLY_SHIELD) or 0
    prot_state.target_below_20 = context.target_hp < 20

    -- Creature type check for Exorcism
    local ctype = UnitCreatureType(TARGET_UNIT)
    prot_state.target_undead_or_demon = (ctype == "Undead" or ctype == "Demon")

    -- Mana threshold
    prot_state.can_exorcism = context.mana_pct > Constants.MANA.EXORCISM_PCT

    return prot_state
end

-- ============================================================================
-- SEAL RESOLUTION HELPER
-- ============================================================================
-- Returns the appropriate seal Action based on prot_seal_choice setting
local function get_prot_seal(context)
    local choice = context.settings.prot_seal_choice or "righteousness"
    if choice == "vengeance" and A.SealOfVengeance then
        return A.SealOfVengeance, "Seal of Vengeance"
    elseif choice == "wisdom" then
        return A.SealOfWisdom, "Seal of Wisdom"
    end
    return A.SealOfRighteousness, "Seal of Righteousness"
end

-- Returns true if the currently configured seal is active
local function has_configured_seal(context)
    local choice = context.settings.prot_seal_choice or "righteousness"
    if choice == "vengeance" then return context.seal_vengeance_active end
    if choice == "wisdom" then return context.seal_wisdom_active end
    return context.seal_righteousness_active
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Righteous Fury check (MUST always be active for tanking)
local Prot_RighteousFuryCheck = {
    spell = A.RighteousFury,

    matches = function(context, state)
        if state.righteous_fury_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.RighteousFury, icon, PLAYER_UNIT, "[PROT] Righteous Fury (activate)")
    end,
}

-- [2] Avenging Wrath (off-GCD, optional threat burst)
local Prot_AvengingWrath = {
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
        return try_cast(A.AvengingWrath, icon, PLAYER_UNIT, "[PROT] Avenging Wrath")
    end,
}

-- [3] Trinket 1 (off-GCD)
local Prot_Trinket1 = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.Trinket1,

    matches = function(context, state)
        if not context.settings.use_trinket1 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.Trinket1:IsReady(PLAYER_UNIT) then
            return A.Trinket1:Show(icon), "[PROT] Trinket 1"
        end
        return nil
    end,
}

-- [4] Trinket 2 (off-GCD)
local Prot_Trinket2 = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.Trinket2,

    matches = function(context, state)
        if not context.settings.use_trinket2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.Trinket2:IsReady(PLAYER_UNIT) then
            return A.Trinket2:Show(icon), "[PROT] Trinket 2"
        end
        return nil
    end,
}

-- [5] Establish configured seal (ensure primary seal is always active)
local Prot_EstablishSeal = {
    requires_combat = true,

    matches = function(context, state)
        if has_configured_seal(context) then return false end
        return true
    end,

    execute = function(icon, context, state)
        local seal, name = get_prot_seal(context)
        if seal:IsReady(PLAYER_UNIT) then
            return seal:Show(icon), format("[PROT] %s", name)
        end
        return nil
    end,
}

-- [6] Holy Shield — HIGH priority (if prioritize enabled)
-- 100% uptime is critical for crushing blow prevention
local Prot_HolyShield = {
    requires_combat = true,
    spell = A.HolyShield,

    matches = function(context, state)
        if not context.settings.prot_use_holy_shield then return false end
        if not context.settings.prot_prioritize_holy_shield then return false end
        -- Refresh when buff is about to expire (< 2s remaining) or not active
        if state.holy_shield_active and state.holy_shield_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyShield, icon, PLAYER_UNIT,
            format("[PROT] Holy Shield (%.1fs remaining)", state.holy_shield_duration))
    end,
}

-- [7] Consecration (primary AoE threat, 8s CD)
local Prot_Consecration = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Consecration,

    matches = function(context, state)
        if not context.settings.prot_use_consecration then return false end
        if context.mana_pct < Constants.MANA.PROT_CONSEC_PCT then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Consecration, icon, PLAYER_UNIT, "[PROT] Consecration")
    end,
}

-- [8] Judgement (off-GCD, threat + seal refresh cycle)
local Prot_Judgement = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        if not context.settings.prot_use_judgement then return false end
        if not context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Judgement, icon, TARGET_UNIT, "[PROT] Judgement")
    end,
}

-- [9] Exorcism (Undead/Demon, mana > 40%)
local Prot_Exorcism = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Exorcism,

    matches = function(context, state)
        if not context.settings.prot_use_exorcism then return false end
        if not state.target_undead_or_demon then return false end
        if not state.can_exorcism then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Exorcism, icon, TARGET_UNIT, "[PROT] Exorcism")
    end,
}

-- [10] Holy Shield — LOW priority (fallback if not prioritized above)
local Prot_HolyShieldFallback = {
    requires_combat = true,
    spell = A.HolyShield,

    matches = function(context, state)
        if not context.settings.prot_use_holy_shield then return false end
        -- Only fire if NOT prioritized (handled by [6] if prioritized)
        if context.settings.prot_prioritize_holy_shield then return false end
        if state.holy_shield_active and state.holy_shield_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyShield, icon, PLAYER_UNIT,
            format("[PROT] Holy Shield fallback (%.1fs remaining)", state.holy_shield_duration))
    end,
}

-- [11] Hammer of Wrath (execute phase, target < 20%)
local Prot_HammerOfWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HammerOfWrath,

    matches = function(context, state)
        if not context.settings.prot_use_hammer_of_wrath then return false end
        if not state.target_below_20 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HammerOfWrath, icon, TARGET_UNIT, "[PROT] Hammer of Wrath")
    end,
}

-- [12] Avenger's Shield (pull/snap threat, early combat only)
local Prot_AvengersShield = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.AvengersShield,

    matches = function(context, state)
        if not context.settings.prot_use_avengers_shield then return false end
        -- Only use as a pull ability (first 3 seconds of combat)
        if context.combat_time > 3 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.AvengersShield, icon, TARGET_UNIT, "[PROT] Avenger's Shield")
    end,
}

-- [13] Righteous Defense (taunt — target a friendly being attacked)
local Prot_RighteousDefense = {
    requires_combat = true,
    spell = A.RighteousDefense,
    setting_key = "prot_use_righteous_defense",

    matches = function(context, state)
        if not context.settings.prot_use_righteous_defense then return false end
        -- Check if focus target exists and is being attacked by our target
        if not _G.UnitExists("focus") then return false end
        if Unit("focus"):IsDead() then return false end
        -- Focus must be under attack (focus's target is attacking them, not us)
        local focus_target = "focustarget"
        if not _G.UnitExists(focus_target) then return false end
        -- If focus's attacker is NOT targeting us, they need a taunt
        if Unit(focus_target):IsUnit(PLAYER_UNIT) then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.RighteousDefense:IsReady("focus") then
            return A.RighteousDefense:Show(icon), "[PROT] Righteous Defense (taunt)"
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("protection", {
    named("RighteousFuryCheck",  Prot_RighteousFuryCheck),
    named("AvengersShield",      Prot_AvengersShield),
    named("AvengingWrath",       Prot_AvengingWrath),
    named("Trinket1",            Prot_Trinket1),
    named("Trinket2",            Prot_Trinket2),
    named("RighteousDefense",    Prot_RighteousDefense),
    named("EstablishSeal",       Prot_EstablishSeal),
    named("HolyShield",          Prot_HolyShield),
    named("Consecration",        Prot_Consecration),
    named("Judgement",           Prot_Judgement),
    named("Exorcism",            Prot_Exorcism),
    named("HolyShieldFallback",  Prot_HolyShieldFallback),
    named("HammerOfWrath",       Prot_HammerOfWrath),
}, {
    context_builder = get_prot_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Paladin]|r Protection module loaded")
