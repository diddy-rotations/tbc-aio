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
local MultiUnits = A.MultiUnits
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local DetermineUsableObject = A.DetermineUsableObject
local LoC = A.LossOfControl

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local CONST = A.Const

-- Pre-allocated LoC type arrays (avoid inline table creation in combat)
local LOC_FEAR_INCAP = { "FEAR", "INCAPACITATE" }
local LOC_FEAR = { "FEAR" }

-- Tactical Mastery: returns max rage preserved after stance swap (5 per rank, 0-25)
local function get_tactical_mastery_cap()
    return (A.TacticalMastery:GetTalentRank() or 0) * 5
end

-- Check if rage would be wasted by a stance swap
-- Returns true if the swap is rage-safe (won't lose significant rage)
local function is_stance_swap_safe(current_rage, ability_cost)
    local tm_cap = get_tactical_mastery_cap()
    local rage_after_swap = current_rage <= tm_cap and current_rage or tm_cap
    return rage_after_swap >= ability_cost
end

-- Expose for spec modules (arms.lua Overpower dance, etc.)
NS.is_stance_swap_safe = is_stance_swap_safe

-- ============================================================================
-- HS/CLEAVE QUEUE TRICK (highest priority — dequeue before MH swing lands)
-- In TBC, queuing HS/Cleave converts both MH and OH swings to "yellow" hits
-- (no glancing blows, better hit table). The trick: queue HS to get yellow
-- OH hit, then dequeue before MH lands if rage is insufficient.
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_HSQueueDequeue",
    priority = 999,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.hs_trick then return false end
        if not context.has_valid_enemy_target then return false end
        -- Only meaningful when dual-wielding (Fury with OH weapon)
        if not Player:HasWeaponOffHand(true) then return false end
        -- Check if HS or Cleave is currently queued
        return A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent()
    end,

    execute = function(icon, context)
        local mh_remaining = NS.get_time_until_swing()
        local should_dequeue = false
        local reason = ""

        -- 1. MH swing landing soon and not enough rage for HS cost
        --    But keep queued if OH lands first (we want the yellow OH hit)
        if mh_remaining > 0 and mh_remaining <= 0.4 then
            local hs_cost = 15  -- HS base cost in TBC
            if context.rage < hs_cost then
                local oh_remaining = Player:GetSwing(2) or 999
                -- Only dequeue if MH lands before OH (preserve yellow OH hit)
                if mh_remaining <= oh_remaining then
                    should_dequeue = true
                    reason = format("Low rage (%d)", context.rage)
                end
            end
        end

        -- 2. Target casting a kickable spell — hold rage for Pummel
        if not should_dequeue and context.has_valid_enemy_target then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                local hs_cost = 15
                local pummel_cost = 10
                if context.rage < (hs_cost + pummel_cost) then
                    should_dequeue = true
                    reason = format("Hold for interrupt (rage: %d)", context.rage)
                end
            end
        end

        -- 3. Target entered execute phase — Execute is better DPS
        if not should_dequeue then
            local target_hp = context.target_hp or 100
            if target_hp <= 20 then
                local playstyle = context.settings.playstyle or "fury"
                local exec_key = playstyle .. "_execute_phase"
                local hs_exec_key = playstyle .. "_hs_during_execute"
                if context.settings[exec_key] and not context.settings[hs_exec_key] then
                    should_dequeue = true
                    reason = "Execute phase"
                end
            end
        end

        if should_dequeue then
            return A:Show(icon, CONST.STOPCAST), format("[MW] HS Dequeue - %s", reason)
        end

        return nil
    end,
})

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
-- LOSS OF CONTROL BREAKERS (Reactive fear/incap removal)
-- ============================================================================
-- BerserkerRage breaks fear and incapacitate (Berserker Stance only).
-- DeathWish's enrage effect also breaks fear.
-- These fire reactively only when the player IS feared/incapacitated.
rotation_registry:register_middleware({
    name = "Warrior_LoCBreaker",
    priority = 485,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_loc_breaker then return false end
        -- Check if we're currently feared or incapacitated
        local ok = LoC:IsValid(LOC_FEAR_INCAP)
        return ok
    end,

    execute = function(icon, context)
        -- BerserkerRage: breaks fear + incap, requires Berserker Stance
        if context.stance == Constants.STANCE.BERSERKER and A.BerserkerRage:IsReady(PLAYER_UNIT) then
            return A.BerserkerRage:Show(icon), "[MW] Berserker Rage (FEAR/INCAP BREAK)"
        end

        -- DeathWish: enrage breaks fear (any stance, Fury talent)
        local fear_remain = LoC:Get("FEAR")
        if fear_remain and fear_remain > 0 and A.DeathWish:IsReady(PLAYER_UNIT) then
            return A.DeathWish:Show(icon), "[MW] Death Wish (FEAR BREAK)"
        end

        return nil
    end,
})

-- ============================================================================
-- EXTERNAL BUFF CANCELAURA (Remove rage-blocking / attack-preventing buffs)
-- ============================================================================
-- PW:S blocks rage generation from damage taken.
-- BoP prevents attacking entirely.
rotation_registry:register_middleware({
    name = "Warrior_CancelExternalBuff",
    priority = 475,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        return true
    end,

    execute = function(icon, context)
        -- Cancel Power Word: Shield when rage is low (blocks rage from damage taken)
        if context.settings.cancel_pws then
            local pws_dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.POWER_WORD_SHIELD) or 0
            if pws_dur > 0 and context.rage < 30 then
                Player:CancelBuff((A.PowerWordShield:Info()))
                return A.PowerWordShield:Show(icon), format("[MW] Cancel PW:S - Rage: %d", context.rage)
            end
        end

        -- Cancel Blessing of Protection when HP is safe (prevents all attacks)
        if context.settings.cancel_bop then
            local bop_dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.BLESSING_OF_PROT) or 0
            if bop_dur > 0 and context.hp > 50 then
                Player:CancelBuff((A.BlessingOfProtection:Info()))
                return A.BlessingOfProtection:Show(icon), format("[MW] Cancel BoP - HP: %.0f%%", context.hp)
            end
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
        -- Check if target is casting
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if not castLeft or castLeft <= 0 then return false end
        -- Spell Reflect works in Battle or Defensive Stance
        if context.stance == Constants.STANCE.BERSERKER then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SpellReflection:IsReady(PLAYER_UNIT) then
            local castLeft = Unit(TARGET_UNIT):IsCastingRemains()
            return A.SpellReflection:Show(icon), format("[MW] Spell Reflection - Cast: %.1fs", castLeft or 0)
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
-- INTERRUPT (Pummel / Shield Bash — with stance dancing)
-- ============================================================================
-- Pummel: Berserker Stance only. If in Battle Stance, dance to Berserker first.
-- Shield Bash: Defensive Stance only (requires shield equipped).
-- Priority: Pummel > stance dance for Pummel > Shield Bash (no dance to Defensive).
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

        -- Already in Berserker → Pummel directly
        if context.stance == Constants.STANCE.BERSERKER and A.Pummel:IsReady(TARGET_UNIT) then
            return A.Pummel:Show(icon), format("[MW] Pummel - Cast: %.1fs", castLeft)
        end

        -- Already in Defensive → Shield Bash (requires shield)
        if context.stance == Constants.STANCE.DEFENSIVE and A.ShieldBash:IsReady(TARGET_UNIT) then
            return A.ShieldBash:Show(icon), format("[MW] Shield Bash - Cast: %.1fs", castLeft)
        end

        -- In Battle Stance: dance to Berserker for Pummel (enough time to swap + kick)
        if context.stance == Constants.STANCE.BATTLE and castLeft > 0.5 then
            -- Check Pummel CD before committing to the stance swap
            local pummel_cd = A.Pummel:GetCooldown() or 0
            if pummel_cd <= 0 and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), format("[MW] → Berserker (for Pummel) - Cast: %.1fs", castLeft)
            end
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
        if context.rage > 80 then return false end
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
        -- Out of combat at range: don't correct stance — let AutoCharge or manual approach handle it
        if not context.in_combat and not context.in_melee_range then return false end
        local spec = context.settings.playstyle or "fury"
        local preferred = Constants.PREFERRED_STANCE[spec]
        if not preferred then return false end
        if context.stance == preferred then return false end
        -- TM check: don't swap if we'd lose significant rage
        local tm_cap = get_tactical_mastery_cap()
        -- Arms needs to return to Battle often (MS/Overpower) — tolerate more rage waste
        local waste_tolerance = spec == "arms" and 20 or 5
        if context.rage > tm_cap + waste_tolerance then return false end
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
-- RACIAL (Blood Fury / Berserking / War Stomp / etc.)
-- ============================================================================
-- Offensive racials (Blood Fury, Berserking) fire as burst CDs.
-- Stoneform / Will of the Forsaken / Escape Artist fire as defensives.
-- War Stomp fires as a defensive interrupt (PBAoE stun).
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
        -- Offensive racials (burst)
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
-- RETALIATION (AoE counter-attack, Battle Stance only, 5 min CD)
-- ============================================================================
-- Reflects 30 melee attacks over 15s. Best when surrounded by many enemies.
rotation_registry:register_middleware({
    name = "Warrior_Retaliation",
    priority = 265,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_retaliation then return false end
        if not context.has_valid_enemy_target then return false end
        -- Only worth using when surrounded
        local min_enemies = context.settings.retaliation_min_enemies or 3
        if context.enemy_count < min_enemies then return false end
        -- Retaliation requires Battle Stance
        if context.stance ~= Constants.STANCE.BATTLE then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Retaliation:IsReady(PLAYER_UNIT) then
            return A.Retaliation:Show(icon), format("[MW] Retaliation - %d enemies", context.enemy_count)
        end
        return nil
    end,
})

-- Defensive racials: Stoneform (Dwarf), WotF (Undead), Escape Artist (Gnome)
rotation_registry:register_middleware({
    name = "Warrior_RacialDefensive",
    priority = 260,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_racial then return false end
        return true
    end,

    execute = function(icon, context)
        -- Stoneform: removes bleed/poison/disease + 10% armor for 8s
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[MW] Stoneform"
        end
        -- Will of the Forsaken: removes fear/sleep/charm
        if A.WillOfTheForsaken:IsReady(PLAYER_UNIT) then
            return A.WillOfTheForsaken:Show(icon), "[MW] Will of the Forsaken"
        end
        -- Escape Artist: removes snare/root (useful when not in melee)
        if not context.in_melee_range and A.EscapeArtist:IsReady(PLAYER_UNIT) then
            return A.EscapeArtist:Show(icon), "[MW] Escape Artist"
        end
        return nil
    end,
})

-- War Stomp: PBAoE stun (Tauren) — useful as interrupt/CC
rotation_registry:register_middleware({
    name = "Warrior_WarStomp",
    priority = 245,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_racial then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        -- Use War Stomp as an interrupt when target is casting and other kicks unavailable
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0.5 and not notKickAble then
            -- Only if Pummel is on CD and we're in melee range
            local pummel_cd = A.Pummel:GetCooldown() or 0
            if pummel_cd > 0 and context.in_melee_range and A.WarStomp:IsReady(PLAYER_UNIT) then
                return A.WarStomp:Show(icon), format("[MW] War Stomp (interrupt) - Cast: %.1fs", castLeft)
            end
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
    -- NOTE: setting_key is NOT auto-checked for middleware (only strategies).
    -- Must check manually in matches().

    matches = function(context)
        if not context.settings.use_auto_charge then return false end
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
            if context.stance ~= Constants.STANCE.BERSERKER then
                -- Check TM: Intercept costs 10 rage, don't swap if we'd lose too much
                if is_stance_swap_safe(context.rage, 10) and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                    return A.BerserkerStance:Show(icon), "[MW] Berserker Stance (for Intercept)"
                end
            end
            if A.Intercept:IsReady(TARGET_UNIT) then
                return A.Intercept:Show(icon), format("[MW] Intercept - Rage: %d", context.rage)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO BANDAGE (Out of combat healing)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_AutoBandage",
    priority = 50,

    matches = function(context)
        if context.in_combat then return false end
        if not context.settings.use_auto_bandage then return false end
        if context.is_mounted then return false end
        if context.is_moving then return false end
        local threshold = context.settings.bandage_hp or 70
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local bandage = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HeavyNetherweaveBandage, A.NetherweaveBandage,
            A.HeavyRuneclothBandage, A.RuneclothBandage,
            A.HeavyMageweaveBandage, A.MageweaveBandage,
            A.HeavySilkBandage, A.SilkBandage,
            A.HeavyWoolBandage, A.WoolBandage,
            A.HeavyLinenBandage, A.LinenBandage)
        if bandage then
            return bandage:Show(icon), format("[MW] Bandage - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO TAB TARGET (Smart target switching)
-- ============================================================================
-- Tabs to nearby enemy when current target is dead, missing, or out of range.
-- Optional: prioritize executable (<20% HP) targets for Execute kills.
local UnitExists = _G.UnitExists
local UnitIsDead = _G.UnitIsDead
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit

-- Scan nameplates for the best target to tab to
-- Returns true if an execute-priority target was found (else nil)
local function has_execute_target_nearby()
    local plates = MultiUnits:GetActiveUnitPlates()
    if not plates then return false end
    for unitID in pairs(plates) do
        if unitID
            and UnitExists(unitID)
            and not UnitIsDead(unitID)
            and not UnitIsPlayer(unitID)
            and not UnitIsUnit(unitID, TARGET_UNIT)
            and Unit(unitID):CombatTime() > 0
            and A.Rend:IsInRange(unitID) == true
        then
            local hp = Unit(unitID):HealthPercent()
            if hp and hp > 0 and hp < 20 then
                return true
            end
        end
    end
    return false
end

rotation_registry:register_middleware({
    name = "Warrior_AutoTab",
    priority = 55,

    matches = function(context)
        if not context.settings.use_auto_tab then return false end
        if context.is_mounted then return false end
        if not context.in_combat then return false end

        -- Always tab if no valid target
        if not context.has_valid_enemy_target then return true end

        -- Tab if current target is out of melee range and enemies are nearby
        if not context.in_melee_range and context.enemy_count >= 1 then return true end

        -- Execute-priority tabbing: switch if a nearby mob is executable and current isn't
        if context.settings.auto_tab_execute
            and context.target_hp >= 20
            and has_execute_target_nearby()
        then
            return true
        end

        return false
    end,

    execute = function(icon, context)
        return A:Show(icon, CONST.AUTOTARGET), "[MW] Auto Tab"
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Middleware module loaded")
