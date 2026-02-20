--- Protection Warrior Module
--- Protection playstyle strategies: Shield Slam + Revenge + Devastate threat rotation
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Protection]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Protection]|r Registry not found!")
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

-- WoW APIs for taunt logic
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UnitIsPlayer = _G.UnitIsPlayer
local UnitClassification = _G.UnitClassification
local MultiUnits = A.MultiUnits

-- ============================================================================
-- TAUNT HELPER FUNCTIONS (matching Druid Growl/Challenging Roar pattern)
-- ============================================================================

-- Reliable aggro check: target is targeting us
local function has_target_aggro()
    return UnitExists("targettarget") and UnitIsUnit("targettarget", PLAYER_UNIT)
end

-- Check if target is CC'd above a threshold
local function is_target_cc_locked(threshold)
    local cc_remaining = Unit(TARGET_UNIT):InCC() or 0
    return cc_remaining > threshold
end

-- Check if target's target is a healer (for Taunt exception)
local function is_targettarget_healer()
    if not UnitExists("targettarget") then return false end
    return Unit("targettarget"):IsHealer() == true
end

-- Count nearby enemies by classification
-- @param max_range: yard radius to check
-- @param loose_only: if true, only count mobs NOT targeting us
-- @return elites, bosses, trash
local function count_nearby_enemies(max_range, loose_only)
    local plates = MultiUnits:GetActiveUnitPlates()
    local elites, bosses, trash = 0, 0, 0
    if not plates then return 0, 0, 0 end
    for unitID in pairs(plates) do
        local skip = false
        if loose_only then
            local tt = unitID .. "target"
            if not UnitExists(tt) or UnitIsUnit(tt, PLAYER_UNIT) then
                skip = true
            end
        end
        if not skip then
            local range = Unit(unitID):GetRange()
            if range and range <= max_range then
                local class = UnitClassification(unitID)
                if class == "worldboss" then
                    bosses = bosses + 1
                elseif class == "elite" or class == "rareelite" then
                    elites = elites + 1
                else
                    trash = trash + 1
                end
            end
        end
    end
    return elites, bosses, trash
end

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
    setting_key = "prot_use_shield_block",

    matches = function(context, state)
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
    spell = A.ShieldSlam,

    execute = function(icon, context, state)
        return try_cast(A.ShieldSlam, icon, TARGET_UNIT, "[PROT] Shield Slam")
    end,
}

-- [3] Revenge (proc-based, highest threat/rage, Defensive Stance)
local Prot_Revenge = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_revenge",

    matches = function(context, state)
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
    setting_key = "prot_use_devastate",

    matches = function(context, state)
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
    setting_key = "prot_use_thunder_clap",

    matches = function(context, state)
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
    setting_key = "prot_use_demo_shout",

    matches = function(context, state)
        -- Only refresh when debuff is missing or about to expire
        if state.demo_shout_debuff > 3 then return false end
        return A.DemoralizingShout:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, TARGET_UNIT,
            format("[PROT] Demoralizing Shout - Debuff: %.1fs", state.demo_shout_debuff))
    end,
}

-- [8] Taunt (single-target taunt — smart: classification filtering, CC/TTD checks)
local Prot_Taunt = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Taunt,
    setting_key = "prot_use_taunt",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        -- Only taunt NPCs, not players
        if UnitIsPlayer(TARGET_UNIT) then return false end
        -- Skip if target is CC'd (taunting wastes 10s CD)
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        -- Skip if we already have aggro
        if has_target_aggro() then return false end
        -- Only taunt elites and bosses — don't waste 10s CD on trash
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        -- TTD check: skip dying elites to save taunt CD
        -- Exception: ALWAYS taunt if elite is hitting a healer
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and context.ttd < Constants.TAUNT.MIN_TTD then return false end
        return true
    end,

    execute = function(icon, context, state)
        local targeting_healer = is_targettarget_healer()
        local reason = targeting_healer and "HEALER TARGETED" or "taunting"
        return try_cast(A.Taunt, icon, TARGET_UNIT,
            format("[PROT] Taunt - Lost aggro - %s (TTD: %.0fs)", reason, context.ttd))
    end,
}

-- [9] Challenging Shout (AoE taunt — fires when enough loose enemies by classification)
local Prot_ChallengingShout = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.ChallengingShout,
    spell_target = PLAYER_UNIT,
    setting_key = "prot_use_challenging_shout",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        local scan_range = Constants.TAUNT.CSHOUT_RANGE
        local elites, bosses, trash = count_nearby_enemies(scan_range, true)
        if elites == 0 and bosses == 0 and trash == 0 then return false end
        local min_bosses = context.settings.prot_cshout_min_bosses or Constants.TAUNT.CSHOUT_MIN_BOSSES
        local min_elites = context.settings.prot_cshout_min_elites or Constants.TAUNT.CSHOUT_MIN_ELITES
        local min_trash  = context.settings.prot_cshout_min_trash or Constants.TAUNT.CSHOUT_MIN_TRASH
        return bosses >= min_bosses or elites >= min_elites or trash >= min_trash
    end,

    execute = function(icon, context, state)
        local scan_range = Constants.TAUNT.CSHOUT_RANGE
        local elites, bosses, trash = count_nearby_enemies(scan_range, true)
        return try_cast(A.ChallengingShout, icon, PLAYER_UNIT,
            format("[PROT] Challenging Shout - EMERGENCY - %d boss, %d elite, %d trash loose", bosses, elites, trash))
    end,
}

-- [10] Mocking Blow (2-min CD taunt fallback — Battle Stance only)
-- Fires when Taunt (10s CD, Defensive Stance) has been used and warrior happens to be in Battle Stance.
-- Respects prot_no_taunt and the same classification filtering as Prot_Taunt.
local Prot_MockingBlow = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.MockingBlow,
    setting_key = "prot_use_taunt",  -- reuse the taunt toggle (Mocking Blow is also a taunt)

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        if UnitIsPlayer(TARGET_UNIT) then return false end
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        if has_target_aggro() then return false end
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and context.ttd < Constants.TAUNT.MIN_TTD then return false end
        return true
    end,

    execute = function(icon, context, state)
        local targeting_healer = is_targettarget_healer()
        local reason = targeting_healer and "HEALER TARGETED" or "taunting"
        return try_cast(A.MockingBlow, icon, TARGET_UNIT,
            format("[PROT] Mocking Blow - Lost aggro - %s (2min CD fallback)", reason))
    end,
}

-- [11] Heroic Strike / Cleave (off-GCD rage dump)
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
    named("ShieldBlock",       Prot_ShieldBlock),
    named("ShieldSlam",        Prot_ShieldSlam),
    named("Revenge",           Prot_Revenge),
    named("Devastate",         Prot_Devastate),
    named("SunderArmor",       Prot_SunderArmor),
    named("ThunderClap",       Prot_ThunderClap),
    named("DemoShout",         Prot_DemoShout),
    named("Taunt",             Prot_Taunt),
    named("ChallengingShout",  Prot_ChallengingShout),
    named("MockingBlow",       Prot_MockingBlow),
    named("HeroicStrike",      Prot_HeroicStrike),
}, {
    context_builder = get_prot_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Protection module loaded")
