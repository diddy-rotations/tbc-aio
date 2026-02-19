--- Holy Paladin Module
--- Holy playstyle strategies (tank/party healing)
--- Part of the modular AIO rotation system
--- Loads after: core.lua, paladin/class.lua, paladin/healing.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Holy]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Holy]|r Registry not found!")
    return
end

if not NS.scan_healing_targets then
    print("|cFFFF0000[Diddy AIO Holy]|r Healing module not loaded!")
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

-- Import from Healing module
local scan_healing_targets = NS.scan_healing_targets
local get_tank_target = NS.get_tank_target
local get_lowest_hp_target = NS.get_lowest_hp_target
local all_members_above_hp = NS.all_members_above_hp
local get_cleanse_target = NS.get_cleanse_target

-- ============================================================================
-- HOLY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local holy_state = {
    lights_grace_active = false,
    divine_favor_active = false,
    divine_illumination_active = false,
    lowest = nil,           -- lowest HP target entry from scan
    tank = nil,             -- tank target entry
    emergency_count = 0,    -- targets below critical threshold
    cleanse_target = nil,   -- first target needing dispel
}

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    -- Buff tracking
    holy_state.lights_grace_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.LIGHTS_GRACE) or 0) > 0
    holy_state.divine_favor_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.DIVINE_FAVOR) or 0) > 0
    holy_state.divine_illumination_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.DIVINE_ILLUMINATION) or 0) > 0

    -- Scan party/raid
    local targets, count = scan_healing_targets()

    -- Reset
    holy_state.lowest = nil
    holy_state.tank = nil
    holy_state.emergency_count = 0
    holy_state.cleanse_target = nil

    for i = 1, count do
        local entry = targets[i]
        if entry then
            -- Lowest HP (targets sorted ascending, first = lowest)
            if not holy_state.lowest then
                holy_state.lowest = entry
            end

            -- Tank detection
            if not holy_state.tank and entry.is_tank then
                holy_state.tank = entry
            end

            -- Emergency count (below 40% HP)
            if entry.hp < 40 then
                holy_state.emergency_count = holy_state.emergency_count + 1
            end

            -- Cleanse target (first needing dispel)
            if not holy_state.cleanse_target and entry.needs_cleanse then
                holy_state.cleanse_target = entry
            end
        end
    end

    return holy_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Divine Illumination (off-GCD, -50% mana cost 15s)
local Holy_DivineIllumination = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.DivineIllumination,

    matches = function(context, state)
        if not context.settings.holy_use_divine_illumination then return false end
        if state.divine_illumination_active then return false end
        -- Use when mana is getting low to save on HL spam
        if context.mana_pct > 80 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DivineIllumination, icon, PLAYER_UNIT,
            format("[HOLY] Divine Illumination - Mana: %.0f%%", context.mana_pct))
    end,
}

-- [2] Divine Favor (off-GCD, next heal guaranteed crit)
local Holy_DivineFavor = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.DivineFavor,

    matches = function(context, state)
        if not context.settings.holy_use_divine_favor then return false end
        if state.divine_favor_active then return false end
        -- Use when someone needs a big heal (emergency)
        if state.emergency_count <= 0 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DivineFavor, icon, PLAYER_UNIT, "[HOLY] Divine Favor (guaranteed crit)")
    end,
}

-- [3] Holy Shock heal (instant, 15s CD)
local Holy_HolyShockHeal = {
    requires_combat = true,
    spell = A.HolyShock,

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_holy_shock_hp or 50
        if state.lowest.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        if A.HolyShock:IsReady(target.unit) then
            return A.HolyShock:Show(icon),
                format("[HOLY] Holy Shock -> %s (%.0f%%)", target.unit, target.hp)
        end
        return nil
    end,
}

-- [4] Lay on Hands (emergency, full heal, drains all mana)
local Holy_LayOnHands = {
    requires_combat = true,
    spell = A.LayOnHands,

    matches = function(context, state)
        if not state.lowest then return false end
        if state.lowest.hp > 15 then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        if A.LayOnHands:IsReady(target.unit) then
            return A.LayOnHands:Show(icon),
                format("[HOLY] Lay on Hands -> %s (%.0f%%)", target.unit, target.hp)
        end
        return nil
    end,
}

-- [5] Holy Light (big heal, 2.5s cast / 2.0s with Light's Grace)
local Holy_HolyLight = {
    requires_combat = true,
    spell = A.HolyLight,

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_holy_light_hp or 60
        if state.lowest.hp > threshold then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        if A.HolyLight:IsReady(target.unit) then
            return A.HolyLight:Show(icon),
                format("[HOLY] Holy Light -> %s (%.0f%%)", target.unit, target.hp)
        end
        return nil
    end,
}

-- [6] Flash of Light (efficient heal, 1.5s cast)
local Holy_FlashOfLight = {
    requires_combat = true,
    spell = A.FlashOfLight,

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_flash_of_light_hp or 90
        if state.lowest.hp > threshold then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        if A.FlashOfLight:IsReady(target.unit) then
            return A.FlashOfLight:Show(icon),
                format("[HOLY] Flash of Light -> %s (%.0f%%)", target.unit, target.hp)
        end
        return nil
    end,
}

-- [7] Judgement maintain (off-GCD, keep JoL/JoW on boss when safe)
local Holy_JudgementMaintain = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        local judge_type = context.settings.holy_judge_debuff or "light"
        if judge_type == "none" then return false end
        -- Don't judge if anyone needs healing urgently
        if state.lowest and state.lowest.hp < 80 then return false end
        -- Check if judgement debuff is already on target
        if judge_type == "light" then
            local has_jol = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.JUDGEMENT_LIGHT) or 0) > 0
            if has_jol then return false end
        elseif judge_type == "wisdom" then
            local has_jow = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.JUDGEMENT_WISDOM) or 0) > 0
            if has_jow then return false end
        end
        -- Need a seal active to judge
        if not context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Judgement, icon, TARGET_UNIT, "[HOLY] Judgement (maintain debuff)")
    end,
}

-- [8] Seal maintain (keep Seal of Wisdom active for mana)
local Holy_SealMaintain = {
    requires_combat = true,

    matches = function(context, state)
        if context.seal_wisdom_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.SealOfWisdom:IsReady(PLAYER_UNIT) then
            return A.SealOfWisdom:Show(icon), "[HOLY] Seal of Wisdom"
        end
        return nil
    end,
}

-- [9] Cleanse party members
local Holy_Cleanse = {
    requires_combat = true,
    spell = A.Cleanse,

    matches = function(context, state)
        if not context.settings.holy_use_cleanse then return false end
        if not state.cleanse_target then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.cleanse_target
        if A.Cleanse:IsReady(target.unit) then
            return A.Cleanse:Show(icon),
                format("[HOLY] Cleanse -> %s", target.unit)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("holy", {
    named("DivineIllumination",  Holy_DivineIllumination),
    named("DivineFavor",         Holy_DivineFavor),
    named("HolyShockHeal",       Holy_HolyShockHeal),
    named("LayOnHands",          Holy_LayOnHands),
    named("HolyLight",           Holy_HolyLight),
    named("FlashOfLight",        Holy_FlashOfLight),
    named("JudgementMaintain",   Holy_JudgementMaintain),
    named("SealMaintain",        Holy_SealMaintain),
    named("Cleanse",             Holy_Cleanse),
}, {
    context_builder = get_holy_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Paladin]|r Holy module loaded")
