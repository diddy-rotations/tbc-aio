-- Warrior Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, shouts, cooldowns

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Warrior Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local DetermineUsableObject = A.DetermineUsableObject

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- LAST STAND (Emergency — highest priority, Prot talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_LastStand",
    priority = 500,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.last_stand_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.LastStand:IsReady(PLAYER_UNIT) then
            return A.LastStand:Show(icon), format("[MW] Last Stand - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- SHIELD WALL (Emergency DR)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_ShieldWall",
    priority = 490,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.shield_wall_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        -- Shield Wall requires Defensive Stance
        if context.stance ~= Constants.STANCE.DEFENSIVE then return false end
        return true
    end,

    execute = function(icon, context)
        if A.ShieldWall:IsReady(PLAYER_UNIT) then
            return A.ShieldWall:Show(icon), format("[MW] Shield Wall - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- SPELL REFLECTION (Proactive defense)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_SpellReflection",
    priority = 400,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_spell_reflection then return false end
        if not context.has_valid_enemy_target then return false end
        -- Spell Reflection works in Battle or Defensive Stance
        if context.stance == Constants.STANCE.BERSERKER then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 then
            if A.SpellReflection:IsReady(PLAYER_UNIT) then
                return A.SpellReflection:Show(icon), format("[MW] Spell Reflection - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.healthstone_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local HealthStoneObject = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HealthstoneMaster, A.HealthstoneMajor)
        if HealthStoneObject then
            return HealthStoneObject:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALING POTION (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,

    matches = function(context)
        if not context.settings.use_healing_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.healing_potion_hp or 25
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperHealingPotion:IsReady(PLAYER_UNIT) then
            return A.SuperHealingPotion:Show(icon), format("[MW] Super Healing Potion - HP: %.0f%%", context.hp)
        end
        if A.MajorHealingPotion:IsReady(PLAYER_UNIT) then
            return A.MajorHealingPotion:Show(icon), format("[MW] Major Healing Potion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- INTERRUPT (Pummel in Berserker, Shield Bash in Defensive)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Interrupt",
    priority = 250,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_interrupt then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if not castLeft or castLeft <= 0 or notKickAble then return nil end

        -- Try Pummel first (Berserker Stance)
        if context.stance == Constants.STANCE.BERSERKER and A.Pummel:IsReady(TARGET_UNIT) then
            return A.Pummel:Show(icon), format("[MW] Pummel - Cast: %.1fs", castLeft)
        end

        -- Try Shield Bash (Defensive Stance, requires shield)
        if context.stance == Constants.STANCE.DEFENSIVE and A.ShieldBash:IsReady(TARGET_UNIT) then
            return A.ShieldBash:Show(icon), format("[MW] Shield Bash - Cast: %.1fs", castLeft)
        end

        return nil
    end,
})

-- ============================================================================
-- BLOODRAGE (Rage generation)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Bloodrage",
    priority = 200,
    is_gcd_gated = false,

    matches = function(context)
        if not context.settings.use_bloodrage then return false end
        if not context.in_combat then return false end
        -- Don't waste Bloodrage if rage is already high
        if context.rage > 70 then return false end
        -- Bloodrage costs HP, don't use at low HP
        local min_hp = context.settings.bloodrage_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Bloodrage:IsReady(PLAYER_UNIT) then
            return A.Bloodrage:Show(icon), format("[MW] Bloodrage - Rage: %d", context.rage)
        end
        return nil
    end,
})

-- ============================================================================
-- STANCE CORRECTION (Switch to spec's home stance when in melee)
-- ============================================================================
-- Pre-allocated lookup: stance ID → stance spell action
local STANCE_SPELL = {
    [Constants.STANCE.BATTLE]    = A.BattleStance,
    [Constants.STANCE.DEFENSIVE] = A.DefensiveStance,
    [Constants.STANCE.BERSERKER] = A.BerserkerStance,
}

rotation_registry:register_middleware({
    name = "Warrior_StanceCorrection",
    priority = 195,

    matches = function(context)
        if context.is_mounted then return false end
        if not context.has_valid_enemy_target then return false end
        -- Don't fight AutoCharge for stance — let it handle pre-charge stance swaps
        if context.settings.use_auto_charge and not context.in_melee_range then return false end
        local spec = context.settings.playstyle or "fury"
        local preferred = Constants.PREFERRED_STANCE[spec]
        if not preferred then return false end
        if context.stance == preferred then return false end
        return true
    end,

    execute = function(icon, context)
        local spec = context.settings.playstyle or "fury"
        local preferred = Constants.PREFERRED_STANCE[spec]
        local spell = STANCE_SPELL[preferred]
        if spell and spell:IsReady(PLAYER_UNIT) then
            return spell:Show(icon), format("[MW] Stance → %s", preferred == 1 and "Battle" or preferred == 2 and "Defensive" or "Berserker")
        end
        return nil
    end,
})

-- ============================================================================
-- BERSERKER RAGE (Rage gen + Fear immunity)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_BerserkerRage",
    priority = 150,
    is_burst = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_berserker_rage then return false end
        -- Berserker Rage requires Berserker Stance
        if context.stance ~= Constants.STANCE.BERSERKER then return false end
        if context.berserker_rage_active then return false end
        return true
    end,

    execute = function(icon, context)
        if A.BerserkerRage:IsReady(PLAYER_UNIT) then
            return A.BerserkerRage:Show(icon), "[MW] Berserker Rage"
        end
        return nil
    end,
})

-- ============================================================================
-- SHOUT MAINTAIN (Battle Shout / Commanding Shout)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_ShoutMaintain",
    priority = 140,

    matches = function(context)
        if not context.settings.auto_shout then return false end
        if context.is_mounted then return false end
        local shout_type = context.settings.shout_type or "battle"
        if shout_type == "none" then return false end

        -- Refresh if missing or duration < 30s (2 min buff, refresh early)
        if shout_type == "battle" then
            if not context.has_battle_shout then return true end
            local dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.BATTLE_SHOUT) or 0
            if dur < 30 then return true end
        end
        if shout_type == "commanding" then
            if not context.has_commanding_shout then return true end
            local dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.COMMANDING_SHOUT) or 0
            if dur < 30 then return true end
        end
        return false
    end,

    execute = function(icon, context)
        local shout_type = context.settings.shout_type or "battle"

        if shout_type == "battle" and A.BattleShout:IsReady(PLAYER_UNIT) then
            return A.BattleShout:Show(icon), "[MW] Battle Shout"
        end

        if shout_type == "commanding" and A.CommandingShout:IsReady(PLAYER_UNIT) then
            return A.CommandingShout:Show(icon), "[MW] Commanding Shout"
        end

        return nil
    end,
})

-- ============================================================================
-- DEATH WISH (+20% damage, Arms/Fury only)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_DeathWish",
    priority = 100,
    is_burst = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if context.death_wish_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end

        local ps = context.settings.playstyle or "fury"
        if ps == "arms" and not context.settings.arms_use_death_wish then return false end
        if ps == "fury" and not context.settings.fury_use_death_wish then return false end
        if ps == "protection" then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DeathWish:IsReady(PLAYER_UNIT) then
            return A.DeathWish:Show(icon), "[MW] Death Wish"
        end
        return nil
    end,
})

-- ============================================================================
-- RECKLESSNESS (+100% crit, Fury only, Berserker Stance)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Recklessness",
    priority = 90,
    is_burst = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if context.recklessness_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local ps = context.settings.playstyle or "fury"
        if ps ~= "fury" then return false end
        if not context.settings.fury_use_recklessness then return false end
        -- Recklessness requires Berserker Stance
        if context.stance ~= Constants.STANCE.BERSERKER then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Recklessness:IsReady(PLAYER_UNIT) then
            return A.Recklessness:Show(icon), "[MW] Recklessness"
        end
        return nil
    end,
})

-- ============================================================================
-- RACIAL (Blood Fury / Berserking / etc.)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Racial",
    priority = 70,
    is_burst = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.settings.use_racial then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context)
        if A.BloodFury:IsReady(PLAYER_UNIT) then
            return A.BloodFury:Show(icon), "[MW] Blood Fury"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[MW] Berserking"
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO CHARGE / INTERCEPT (Gap closer)
-- ============================================================================
-- Suppress Intercept after a recent Charge to avoid intercepting mid-flight.
-- Two signals: timestamp (addon-triggered) + Charge CD state (catches manual charges too).
local last_charge_time = 0
local CHARGE_INTERCEPT_COOLDOWN = 3  -- seconds
local CHARGE_TOTAL_CD = 15           -- Charge base CD in TBC

local function recently_charged(now)
    -- Signal 1: addon set the timestamp when it fired Charge
    if (now - last_charge_time) < CHARGE_INTERCEPT_COOLDOWN then return true end
    -- Signal 2: Charge is on CD with most of its duration left → just used (handles manual charges)
    local charge_cd = A.Charge:GetCooldown() or 0
    if charge_cd > (CHARGE_TOTAL_CD - CHARGE_INTERCEPT_COOLDOWN) then return true end
    return false
end

rotation_registry:register_middleware({
    name = "Warrior_AutoCharge",
    priority = 160,
    setting_key = "use_auto_charge",

    matches = function(context)
        if context.is_mounted then return false end
        if not context.has_valid_enemy_target then return false end
        -- Don't charge if already in melee range
        if context.in_melee_range then return false end
        return true
    end,

    execute = function(icon, context)
        local now = _G.GetTime()
        -- Charge: Battle Stance, out of combat
        if not context.in_combat then
            -- Need Battle Stance for Charge — swap first if needed
            if context.stance ~= Constants.STANCE.BATTLE and A.BattleStance:IsReady(PLAYER_UNIT) then
                return A.BattleStance:Show(icon), "[MW] Battle Stance (for Charge)"
            end
            if A.Charge:IsReady(TARGET_UNIT) then
                last_charge_time = now
                return A.Charge:Show(icon), "[MW] Charge"
            end
        end
        -- Intercept: Berserker Stance, in combat
        -- Suppress after a recent Charge (travel time + landing) to avoid intercepting mid-flight
        if context.in_combat and not recently_charged(now) then
            -- Need Berserker Stance for Intercept — swap first if needed
            if context.stance ~= Constants.STANCE.BERSERKER and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), "[MW] Berserker Stance (for Intercept)"
            end
            if A.Intercept:IsReady(TARGET_UNIT) then
                return A.Intercept:Show(icon), format("[MW] Intercept - Rage: %d", context.rage)
            end
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Middleware module loaded")
