-- Hunter Middleware Module

local _G = _G
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

local PLAYER_UNIT = "player"

-- ============================================================================
-- SHARED RECOVERY ITEMS (Healthstone, Healing Potion, Dark Rune)
-- ============================================================================
NS.register_recovery_middleware("Hunter", {
    healthstone = {
        tiers = { A.HSMaster1, A.HSMaster2, A.HSMaster3 },
        extra_match = function(context) return not Player:IsStealthed() end,
    },
    healing_potion = { default_hp = 35 },
    dark_rune = {
        setting_toggle = "use_mana_rune",
        setting_threshold = "mana_rune_mana",
        default_pct = 20,
        default_min_hp = 0,
    },
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
