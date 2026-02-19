-- Shaman Middleware Module
-- Cross-playstyle concerns: interrupt, emergency, recovery, shields, dispels, weapon imbues

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "SHAMAN" then return end

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Shaman Middleware]|r Core module not loaded!")
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
-- EARTH SHOCK INTERRUPT (highest priority — TBC's ONLY shaman interrupt!)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Interrupt",
    priority = Priority.MIDDLEWARE.FORM_RESHIFT,  -- 500 (highest — TBC's only shaman interrupt)

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_interrupt then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            -- Use R1 for mana efficiency if setting enabled
            local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
            if spell:IsReady(TARGET_UNIT) then
                return spell:Show(icon), format("[MW] Earth Shock Interrupt - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,  -- 300

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
    name = "Shaman_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,  -- 295

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
-- MANA POTION (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_ManaPotion",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY,  -- 280

    matches = function(context)
        if not context.settings.use_mana_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_potion_pct or 50
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperManaPotion:IsReady(PLAYER_UNIT) then
            return A.SuperManaPotion:Show(icon), format("[MW] Super Mana Potion - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- DARK/DEMONIC RUNE (Mana recovery — separate CD from potion)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_DarkRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,  -- 275

    matches = function(context)
        if not context.settings.use_dark_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.dark_rune_pct or 50
        if context.mana_pct > threshold then return false end
        local min_hp = context.settings.dark_rune_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DarkRune:IsReady(PLAYER_UNIT) then
            return A.DarkRune:Show(icon), format("[MW] Dark Rune - Mana: %.0f%%", context.mana_pct)
        end
        if A.DemonicRune:IsReady(PLAYER_UNIT) then
            return A.DemonicRune:Show(icon), format("[MW] Demonic Rune - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- SHIELD MAINTENANCE (Water Shield for Ele/Resto, Lightning Shield for Enh)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_ShieldMaintain",
    priority = 250,

    matches = function(context)
        if context.is_mounted then return false end
        local shield = context.settings.shield_type or "auto"
        local playstyle = context.settings.playstyle or "elemental"

        -- Determine which shield we want
        local want_water
        if shield == "auto" then
            want_water = (playstyle ~= "enhancement")
        elseif shield == "water" then
            want_water = true
        else
            want_water = false
        end

        if want_water then
            -- Refresh if missing or charges low (1 or fewer)
            if not context.has_water_shield or context.water_shield_charges <= 1 then
                return true
            end
        else
            if not context.has_lightning_shield then
                return true
            end
        end

        return false
    end,

    execute = function(icon, context)
        local shield = context.settings.shield_type or "auto"
        local playstyle = context.settings.playstyle or "elemental"

        local want_water
        if shield == "auto" then
            want_water = (playstyle ~= "enhancement")
        elseif shield == "water" then
            want_water = true
        else
            want_water = false
        end

        if want_water then
            if A.WaterShield:IsReady(PLAYER_UNIT) then
                return A.WaterShield:Show(icon), format("[MW] Water Shield - Charges: %d", context.water_shield_charges)
            end
        else
            if A.LightningShield:IsReady(PLAYER_UNIT) then
                return A.LightningShield:Show(icon), "[MW] Lightning Shield"
            end
        end

        return nil
    end,
})

-- ============================================================================
-- CURE POISON (Self-dispel)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_CurePoison",
    priority = 200,

    matches = function(context)
        if not context.settings.use_cure_poison then return false end
        if context.is_mounted then return false end
        local hasPoison = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Poison")
        if not hasPoison then return false end
        return true
    end,

    execute = function(icon, context)
        if A.CurePoison:IsReady(PLAYER_UNIT) then
            return A.CurePoison:Show(icon), "[MW] Cure Poison"
        end
        return nil
    end,
})

-- ============================================================================
-- CURE DISEASE (Self-dispel)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_CureDisease",
    priority = 195,

    matches = function(context)
        if not context.settings.use_cure_disease then return false end
        if context.is_mounted then return false end
        local hasDisease = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Disease")
        if not hasDisease then return false end
        return true
    end,

    execute = function(icon, context)
        if A.CureDisease:IsReady(PLAYER_UNIT) then
            return A.CureDisease:Show(icon), "[MW] Cure Disease"
        end
        return nil
    end,
})

-- ============================================================================
-- PURGE (Remove enemy buffs)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Purge",
    priority = 190,

    matches = function(context)
        if not context.settings.use_purge then return false end
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        local hasStealable = A.AuraIsValid(TARGET_UNIT, "UseExpelEnrage", "Magic")
        if not hasStealable then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Purge:IsReady(TARGET_UNIT) then
            return A.Purge:Show(icon), "[MW] Purge"
        end
        return nil
    end,
})

-- ============================================================================
-- WEAPON IMBUES (Out of combat — Enhancement only)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_WeaponImbues",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC,  -- 140

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        local playstyle = context.settings.playstyle or "elemental"
        if playstyle ~= "enhancement" then return false end
        -- Check if MH or OH imbue is missing
        -- GetWeaponEnchantInfo() returns: hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, ...
        local hasMH, _, _, hasOH = _G.GetWeaponEnchantInfo()
        if not hasMH or not hasOH then return true end
        return false
    end,

    execute = function(icon, context)
        local hasMH, _, _, hasOH = _G.GetWeaponEnchantInfo()
        -- MH: Windfury Weapon
        if not hasMH and A.WindfuryWeapon:IsReady(PLAYER_UNIT) then
            return A.WindfuryWeapon:Show(icon), "[MW] Windfury Weapon (MH)"
        end
        -- OH: Flametongue Weapon
        if not hasOH and A.FlametongueWeapon:IsReady(PLAYER_UNIT) then
            return A.FlametongueWeapon:Show(icon), "[MW] Flametongue Weapon (OH)"
        end
        return nil
    end,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Shaman]|r Middleware module loaded")
