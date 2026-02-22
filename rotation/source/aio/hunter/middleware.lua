-- Hunter Middleware Module
-- Recovery items: Healthstone, Healing Potion, Dark/Demonic Rune

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local DetermineUsableObject = A.DetermineUsableObject

local PLAYER_UNIT = "player"

-- ============================================================================
-- HEALTHSTONE MIDDLEWARE
-- ============================================================================
rotation_registry:register_middleware({
    name = "Hunter_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

    matches = function(context)
        if Player:IsStealthed() then return false end
        local threshold = context.settings.healthstone_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local HealthStoneObject = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HSMaster1, A.HSMaster2, A.HSMaster3)
        if HealthStoneObject then
            return HealthStoneObject:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALING POTION MIDDLEWARE
-- ============================================================================
rotation_registry:register_middleware({
    name = "Hunter_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,

    matches = function(context)
        if not context.settings.use_healing_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.healing_potion_hp or 35
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
-- MANA RUNE MIDDLEWARE
-- ============================================================================
rotation_registry:register_middleware({
    name = "Hunter_ManaRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY,

    matches = function(context)
        if not context.settings.use_mana_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_rune_mana or 20
        if context.mana_pct > threshold then return false end
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
-- FEIGN DEATH (Threat management)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Hunter_FeignDeath",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE,
    is_defensive = true,
    setting_key = "use_feign_death",

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if not A.FeignDeath:IsReady(PLAYER_UNIT) then return false end
        -- Only feign when we have aggro
        local is_tanking = _G.UnitIsUnit("targettarget", PLAYER_UNIT)
        return is_tanking
    end,

    execute = function(icon, context)
        return A.FeignDeath:Show(icon), "[MW] Feign Death (threat)"
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Hunter]|r Middleware module loaded")
