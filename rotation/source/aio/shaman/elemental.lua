--- Elemental Shaman Module
--- Elemental playstyle strategies: Lightning Bolt spam, Chain Lightning weaving, shock rotation
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Elemental]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Elemental]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local resolve_totem_spell = NS.resolve_totem_spell
local totem_state = NS.totem_state
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- ELEMENTAL STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local ele_state = {
    clearcasting_charges = 0,
    elemental_mastery_active = false,
    flame_shock_duration = 0,
    chain_lightning_cd = 0,
}

-- Module-level LB counter for fixed_ratio mode (persists across frames, reset on CL cast)
local lb_casts_since_cl = 0

local function get_ele_state(context)
    if context._ele_valid then return ele_state end
    context._ele_valid = true

    ele_state.clearcasting_charges = context.clearcasting_charges
    ele_state.elemental_mastery_active = context.has_elemental_mastery
    ele_state.flame_shock_duration = context.flame_shock_duration
    ele_state.chain_lightning_cd = A.ChainLightning:GetCooldown() or 0

    return ele_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Elemental Mastery (off-GCD — guaranteed crit next spell)
local Ele_ElementalMastery = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.ElementalMastery,
    setting_key = "ele_use_elemental_mastery",

    matches = function(context, state)
        if state.elemental_mastery_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ElementalMastery, icon, PLAYER_UNIT, "[ELE] Elemental Mastery")
    end,
}

-- [2] Trinkets (off-GCD)
local Ele_Trinkets = {
    requires_combat = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then return true end
        if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then
            return A.Trinket1:Show(icon), "[ELE] Trinket 1"
        end
        if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then
            return A.Trinket2:Show(icon), "[ELE] Trinket 2"
        end
        return nil
    end,
}

-- [3] Racial (off-GCD)
local Ele_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    setting_key = "use_racial",

    matches = function(context, state)
        -- Caster shaman uses SP Blood Fury or Berserking
        if A.BloodFurySP:IsReady(PLAYER_UNIT) then return true end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFurySP:IsReady(PLAYER_UNIT) then
            return A.BloodFurySP:Show(icon), "[ELE] Blood Fury (SP)"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[ELE] Berserking"
        end
        return nil
    end,
}

-- [4] Totem Management — drop/refresh configured totems
local Ele_TotemManagement = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD
        -- Check each totem slot for missing or expiring
        if not context.totem_fire_active or context.totem_fire_remaining < threshold then return true end
        if not context.totem_earth_active or context.totem_earth_remaining < threshold then return true end
        if not context.totem_water_active or context.totem_water_remaining < threshold then return true end
        if not context.totem_air_active or context.totem_air_remaining < threshold then return true end
        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD

        -- Fire totem
        if not context.totem_fire_active or context.totem_fire_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_fire_totem or "totem_of_wrath", NS.FIRE_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ELE] Fire Totem"
            end
        end

        -- Earth totem
        if not context.totem_earth_active or context.totem_earth_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_earth_totem or "strength_of_earth", NS.EARTH_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ELE] Earth Totem"
            end
        end

        -- Water totem
        if not context.totem_water_active or context.totem_water_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_water_totem or "mana_spring", NS.WATER_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ELE] Water Totem"
            end
        end

        -- Air totem
        if not context.totem_air_active or context.totem_air_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_air_totem or "wrath_of_air", NS.AIR_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ELE] Air Totem"
            end
        end

        return nil
    end,
}

-- [5] Fire Elemental (long CD summon)
local Ele_FireElemental = {
    requires_combat = true,
    spell = A.FireElementalTotem,
    setting_key = "ele_use_fire_elemental",

    matches = function(context, state)
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.FireElementalTotem, icon, PLAYER_UNIT, "[ELE] Fire Elemental Totem")
    end,
}

-- [6] Flame Shock — maintain DoT (instant, works while moving)
local Ele_FlameShock = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.FlameShock,
    setting_key = "ele_use_flame_shock",

    matches = function(context, state)
        -- Only apply if DoT is not active
        if state.flame_shock_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.FlameShock, icon, TARGET_UNIT,
            format("[ELE] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
    end,
}

-- [7] Chain Lightning — per rotation type setting
local Ele_ChainLightning = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ChainLightning,

    matches = function(context, state)
        if context.is_moving then return false end
        local rot = context.settings.ele_rotation_type or "cl_clearcast"
        if rot == "lb_only" then return false end

        -- CL must be off cooldown
        if state.chain_lightning_cd > 0 then return false end

        if rot == "cl_on_cd" then
            return true
        elseif rot == "cl_clearcast" then
            -- Use CL when we have clearcasting charges
            return state.clearcasting_charges >= 2
        elseif rot == "fixed_ratio" then
            local ratio = context.settings.ele_fixed_lb_per_cl or 3
            return lb_casts_since_cl >= ratio
        end

        return false
    end,

    execute = function(icon, context, state)
        lb_casts_since_cl = 0  -- Reset counter on CL cast
        return try_cast(A.ChainLightning, icon, TARGET_UNIT, "[ELE] Chain Lightning")
    end,
}

-- [8] Earth Shock — filler shock when FS DoT is ticking
local Ele_EarthShock = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.EarthShock,
    setting_key = "ele_use_earth_shock",

    matches = function(context, state)
        -- Only use as filler when FS DoT is already active
        if state.flame_shock_duration <= 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ELE] Earth Shock (filler)")
    end,
}

-- [9] AoE rotation (when enough enemies)
local Ele_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if (context.enemy_count or 1) < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- CL is our primary AoE (3 targets)
        if state.chain_lightning_cd <= 0 then
            lb_casts_since_cl = 0
            return try_cast(A.ChainLightning, icon, TARGET_UNIT, "[ELE] Chain Lightning (AoE)")
        end
        -- Fire Nova Totem for burst AoE
        if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
            return try_cast(A.FireNovaTotem, icon, PLAYER_UNIT, "[ELE] Fire Nova Totem (AoE)")
        end
        -- Magma Totem for sustained AoE
        if A.MagmaTotem:IsReady(PLAYER_UNIT) then
            return try_cast(A.MagmaTotem, icon, PLAYER_UNIT, "[ELE] Magma Totem (AoE)")
        end
        -- Fall through to LB on primary target
        return nil
    end,
}

-- [10] Movement spell (instant while moving)
local Ele_MovementSpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Flame Shock if DoT is down
        if state.flame_shock_duration <= 2 and context.settings.ele_use_flame_shock then
            local result = try_cast(A.FlameShock, icon, TARGET_UNIT, "[ELE] Flame Shock (moving)")
            if result then return result end
        end
        -- Earth Shock as filler while moving
        if context.settings.ele_use_earth_shock then
            return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ELE] Earth Shock (moving)")
        end
        return nil
    end,
}

-- [11] Lightning Bolt — primary filler (majority of casts)
local Ele_LightningBolt = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.LightningBolt,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        lb_casts_since_cl = lb_casts_since_cl + 1
        return try_cast(A.LightningBolt, icon, TARGET_UNIT, "[ELE] Lightning Bolt")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("elemental", {
    named("ElementalMastery", Ele_ElementalMastery),
    named("Trinkets",         Ele_Trinkets),
    named("Racial",           Ele_Racial),
    named("TotemManagement",  Ele_TotemManagement),
    named("AoE",              Ele_AoE),
    named("FlameShock",       Ele_FlameShock),
    named("ChainLightning",   Ele_ChainLightning),
    named("EarthShock",       Ele_EarthShock),
    named("FireElemental",    Ele_FireElemental),
    named("MovementSpell",    Ele_MovementSpell),
    named("LightningBolt",    Ele_LightningBolt),
}, {
    context_builder = get_ele_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Shaman]|r Elemental module loaded")
