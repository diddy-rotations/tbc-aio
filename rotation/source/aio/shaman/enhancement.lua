--- Enhancement Shaman Module
--- Enhancement playstyle strategies: melee DPS, Stormstrike, shock weaving, totem twisting
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Enhancement]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Diddy AIO Enhancement]|r Registry not found!")
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
local GetTime = _G.GetTime

-- ============================================================================
-- ENHANCEMENT STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local enh_state = {
    stormstrike_debuff_duration = 0,
    flame_shock_duration = 0,
    shamanistic_rage_active = false,
    shamanistic_focus_active = false,
    flurry_charges = 0,
}

local function get_enh_state(context)
    if context._enh_valid then return enh_state end
    context._enh_valid = true

    enh_state.stormstrike_debuff_duration = context.stormstrike_debuff
    enh_state.flame_shock_duration = context.flame_shock_duration
    enh_state.shamanistic_rage_active = context.shamanistic_rage_active
    enh_state.shamanistic_focus_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SHAMANISTIC_FOCUS) or 0) > 0
    enh_state.flurry_charges = Unit(PLAYER_UNIT):HasBuffsStacks(Constants.BUFF_ID.FLURRY) or 0

    return enh_state
end

-- ============================================================================
-- TOTEM TWIST STATE (module-level, persists across frames)
-- ============================================================================
-- Windfury + Grace of Air twist timing
local wf_twist = {
    last_wf_time = 0,       -- GetTime() when WF totem was last dropped
    last_default_time = 0,  -- GetTime() when default air totem was last dropped
    phase = "windfury",     -- "windfury" = WF is down, "default" = GoA/other is down
    initialized = false,
}

-- Fire Nova Totem twist timing
local fnt_twist = {
    last_drop_time = 0,     -- GetTime() when FNT was last dropped
    phase = "idle",         -- "idle" = ready for FNT, "waiting" = FNT fuse ticking, "default" = default fire totem phase
}

-- Reset twist state on combat exit
local last_combat_state = false

local function check_combat_reset(in_combat)
    if last_combat_state and not in_combat then
        -- Exiting combat: reset twist state
        wf_twist.initialized = false
        wf_twist.phase = "windfury"
        wf_twist.last_wf_time = 0
        wf_twist.last_default_time = 0
        fnt_twist.phase = "idle"
        fnt_twist.last_drop_time = 0
    end
    last_combat_state = in_combat
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Shamanistic Rage (off-GCD — mana recovery + damage reduction)
local Enh_ShamanisticRage = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.ShamanisticRage,
    setting_key = "enh_use_shamanistic_rage",

    matches = function(context, state)
        if state.shamanistic_rage_active then return false end
        local threshold = context.settings.enh_shamanistic_rage_pct or 30
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShamanisticRage, icon, PLAYER_UNIT,
            format("[ENH] Shamanistic Rage - Mana: %.0f%%", context.mana_pct))
    end,
}

-- [2] Trinkets (off-GCD)
local Enh_Trinkets = {
    requires_combat = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then return true end
        if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then
            return A.Trinket1:Show(icon), "[ENH] Trinket 1"
        end
        if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then
            return A.Trinket2:Show(icon), "[ENH] Trinket 2"
        end
        return nil
    end,
}

-- [3] Racial (off-GCD)
local Enh_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    setting_key = "use_racial",

    matches = function(context, state)
        -- Enhancement uses AP Blood Fury or Berserking
        if A.BloodFuryAP:IsReady(PLAYER_UNIT) then return true end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFuryAP:IsReady(PLAYER_UNIT) then
            return A.BloodFuryAP:Show(icon), "[ENH] Blood Fury (AP)"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[ENH] Berserking"
        end
        return nil
    end,
}

-- [4] Totem Management — base totems (fire, earth, water)
-- Does NOT handle air slot if WF twist is active
local Enh_TotemManagement = {
    requires_combat = true,

    matches = function(context, state)
        check_combat_reset(context.in_combat)
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD

        -- Fire totem (skip if fire nova twist is handling it)
        local skip_fire = context.settings.enh_twist_fire_nova
        if not skip_fire then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then return true end
        end

        -- Earth totem
        if not context.totem_earth_active or context.totem_earth_remaining < threshold then return true end

        -- Water totem
        if not context.totem_water_active or context.totem_water_remaining < threshold then return true end

        -- Air totem (only if NOT twisting WF)
        if not context.settings.enh_twist_windfury then
            if not context.totem_air_active or context.totem_air_remaining < threshold then return true end
        end

        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD

        -- Fire totem (skip if FNT twist active)
        if not s.enh_twist_fire_nova then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then
                local spell = resolve_totem_spell(s.enh_fire_totem or "searing", NS.FIRE_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[ENH] Fire Totem"
                end
            end
        end

        -- Earth totem
        if not context.totem_earth_active or context.totem_earth_remaining < threshold then
            local spell = resolve_totem_spell(s.enh_earth_totem or "strength_of_earth", NS.EARTH_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ENH] Earth Totem"
            end
        end

        -- Water totem
        if not context.totem_water_active or context.totem_water_remaining < threshold then
            local spell = resolve_totem_spell(s.enh_water_totem or "mana_spring", NS.WATER_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ENH] Water Totem"
            end
        end

        -- Air totem (only if NOT twisting)
        if not s.enh_twist_windfury then
            if not context.totem_air_active or context.totem_air_remaining < threshold then
                local spell = resolve_totem_spell(s.enh_air_totem or "windfury", NS.AIR_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[ENH] Air Totem"
                end
            end
        end

        return nil
    end,
}

-- [5] Windfury Twist — cycle WF ↔ default air totem (GoA/WoA) every ~10s
-- WF buff persists ~10s on players after totem is replaced, so both buffs can be active simultaneously
local Enh_WindfuryTwist = {
    requires_combat = true,

    matches = function(context, state)
        if not context.settings.enh_twist_windfury then
            -- Not twisting: just ensure air totem is up if needed
            if not context.totem_air_active or context.totem_air_remaining < Constants.TOTEM_REFRESH_THRESHOLD then
                return true
            end
            return false
        end

        -- OOM protection: skip twist below threshold
        if context.mana_pct < Constants.TWIST.OOM_THRESHOLD * 100 then
            -- Just keep whatever air totem is up
            if not context.totem_air_active then return true end
            return false
        end

        local now = GetTime()
        local cycle = Constants.TWIST.CYCLE_TIME

        -- First time entering combat: drop WF immediately
        if not wf_twist.initialized then
            return true
        end

        -- Check if it's time to switch phases
        if wf_twist.phase == "windfury" then
            -- WF is down, time to swap to default air totem?
            local elapsed = now - wf_twist.last_wf_time
            if elapsed >= cycle then return true end
        elseif wf_twist.phase == "default" then
            -- Default air totem is down, time to swap back to WF?
            local elapsed = now - wf_twist.last_default_time
            if elapsed >= cycle then return true end
        end

        return false
    end,

    execute = function(icon, context, state)
        local now = GetTime()

        -- If not twisting, just drop configured air totem
        if not context.settings.enh_twist_windfury then
            local spell = resolve_totem_spell(context.settings.enh_air_totem or "windfury", NS.AIR_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ENH] Air Totem (no twist)"
            end
            return nil
        end

        -- Initialize: start with WF
        if not wf_twist.initialized then
            if A.WindfuryTotem:IsReady(PLAYER_UNIT) then
                wf_twist.initialized = true
                wf_twist.phase = "windfury"
                wf_twist.last_wf_time = now
                return A.WindfuryTotem:Show(icon), "[ENH] Windfury Totem (twist init)"
            end
            return nil
        end

        -- Phase transitions
        if wf_twist.phase == "windfury" then
            -- Switch to default air totem (Grace of Air typically)
            -- The WF buff will persist on party members for ~10s
            local default_key = context.settings.enh_air_totem or "grace_of_air"
            -- When twisting, the "default" air totem should be Grace of Air (not WF again)
            if default_key == "windfury" then default_key = "grace_of_air" end
            local spell = resolve_totem_spell(default_key, NS.AIR_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                wf_twist.phase = "default"
                wf_twist.last_default_time = now
                return spell:Show(icon), format("[ENH] %s (twist phase 2)", default_key)
            end
        elseif wf_twist.phase == "default" then
            -- Switch back to WF before the buff expires on party
            if A.WindfuryTotem:IsReady(PLAYER_UNIT) then
                wf_twist.phase = "windfury"
                wf_twist.last_wf_time = now
                return A.WindfuryTotem:Show(icon), "[ENH] Windfury Totem (twist refresh)"
            end
        end

        return nil
    end,
}

-- [6] Fire Nova Totem Twist — cycle FNT (AoE burst) with default fire totem
local Enh_FireNovaTotemTwist = {
    requires_combat = true,
    setting_key = "enh_twist_fire_nova",

    matches = function(context, state)
        -- OOM protection
        if context.mana_pct < Constants.TWIST.OOM_THRESHOLD * 100 then return false end

        local now = GetTime()

        if fnt_twist.phase == "idle" then
            -- Ready to drop FNT
            return true
        elseif fnt_twist.phase == "waiting" then
            -- FNT fuse is ~4s, then it explodes and disappears
            local elapsed = now - fnt_twist.last_drop_time
            if elapsed >= 5 then
                -- FNT has exploded, drop default fire totem
                fnt_twist.phase = "default"
                return true
            end
        elseif fnt_twist.phase == "default" then
            -- FNT has a 15s CD; check if it's ready again
            if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
                fnt_twist.phase = "idle"
                return true
            end
        end

        return false
    end,

    execute = function(icon, context, state)
        local now = GetTime()

        if fnt_twist.phase == "idle" then
            -- Drop Fire Nova Totem
            if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
                fnt_twist.phase = "waiting"
                fnt_twist.last_drop_time = now
                return A.FireNovaTotem:Show(icon), "[ENH] Fire Nova Totem (twist)"
            end
        elseif fnt_twist.phase == "default" then
            -- Drop default fire totem after FNT exploded
            local spell = resolve_totem_spell(context.settings.enh_fire_totem or "searing", NS.FIRE_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ENH] Fire Totem (post-FNT)"
            end
        end

        return nil
    end,
}

-- [7] Stormstrike — top melee priority, 10s CD
local Enh_Stormstrike = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Stormstrike,
    setting_key = "enh_use_stormstrike",

    matches = function(context, state)
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Stormstrike, icon, TARGET_UNIT, "[ENH] Stormstrike")
    end,
}

-- [8] Shock — Flame Shock weaving + primary shock (Earth/Frost)
local Enh_Shock = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local s = context.settings
        local primary = s.enh_primary_shock or "earth_shock"

        -- Flame Shock weaving: apply DoT when not active
        if s.enh_weave_flame_shock and state.flame_shock_duration <= 2 then
            return true
        end

        -- Primary shock filler (when FS DoT is ticking or weaving disabled)
        if primary ~= "none" then
            return true
        end

        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings

        -- Stormstrike synergy: prefer Earth Shock when SS +20% nature debuff is active
        if state.stormstrike_debuff_duration > 0 then
            local result = try_cast(A.EarthShock, icon, TARGET_UNIT, "[ENH] Earth Shock (SS synergy)")
            if result then return result end
        end

        -- Flame Shock if weaving and DoT is down
        if s.enh_weave_flame_shock and state.flame_shock_duration <= 2 then
            local result = try_cast(A.FlameShock, icon, TARGET_UNIT,
                format("[ENH] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
            if result then return result end
        end

        -- Primary shock
        local primary = s.enh_primary_shock or "earth_shock"
        if primary == "earth_shock" then
            return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ENH] Earth Shock")
        elseif primary == "frost_shock" then
            return try_cast(A.FrostShock, icon, TARGET_UNIT, "[ENH] Frost Shock")
        end

        return nil
    end,
}

-- [9] Fire Elemental (long CD summon)
local Enh_FireElemental = {
    requires_combat = true,
    spell = A.FireElementalTotem,
    setting_key = "enh_use_fire_elemental",

    matches = function(context, state)
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.FireElementalTotem, icon, PLAYER_UNIT, "[ENH] Fire Elemental Totem")
    end,
}

-- [10] AoE rotation (when enough enemies)
local Enh_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if (context.enemy_count or 1) < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Fire Nova Totem for burst AoE
        if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
            return try_cast(A.FireNovaTotem, icon, PLAYER_UNIT, "[ENH] Fire Nova Totem (AoE)")
        end
        -- Magma Totem for sustained AoE
        if A.MagmaTotem:IsReady(PLAYER_UNIT) then
            return try_cast(A.MagmaTotem, icon, PLAYER_UNIT, "[ENH] Magma Totem (AoE)")
        end
        -- Chain Lightning if available
        if A.ChainLightning:IsReady(TARGET_UNIT) then
            return try_cast(A.ChainLightning, icon, TARGET_UNIT, "[ENH] Chain Lightning (AoE)")
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("enhancement", {
    named("ShamanisticRage",     Enh_ShamanisticRage),
    named("Trinkets",            Enh_Trinkets),
    named("Racial",              Enh_Racial),
    named("TotemManagement",     Enh_TotemManagement),
    named("AoE",                 Enh_AoE),
    named("Stormstrike",         Enh_Stormstrike),
    named("Shock",               Enh_Shock),
    named("WindfuryTwist",       Enh_WindfuryTwist),
    named("FireNovaTotemTwist",  Enh_FireNovaTotemTwist),
    named("FireElemental",       Enh_FireElemental),
}, {
    context_builder = get_enh_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Shaman]|r Enhancement module loaded")
