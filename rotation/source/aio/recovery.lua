-- Flux AIO - Shared Recovery Item Middleware
-- Provides factory for common consumable middleware (Healthstone, Healing Potion, Mana Potion, Dark Rune)
-- Classes call NS.register_recovery_middleware() from their middleware.lua

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Recovery]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local DetermineUsableObject = A.DetermineUsableObject
local format = string.format

local PLAYER_UNIT = "player"

-- ============================================================================
-- RECOVERY MIDDLEWARE FACTORY
-- ============================================================================

--- Register standard recovery item middleware for a class.
--- @param class_name string  Class display name (e.g. "Mage", "Warrior")
--- @param config table       Items to register. Keys: healthstone, healing_potion, mana_potion, dark_rune
---   Each value is `true` (use defaults) or a table with overrides:
---     healthstone:    { tiers = {spell1, spell2, ...}, extra_match = function(ctx) }
---     healing_potion: { default_hp = number }
---     mana_potion:    { default_pct = number, tiers = {spell1, ...}, priority_offset = number }
---     dark_rune:      { default_pct = number, default_min_hp = number, priority_offset = number,
---                       setting_toggle = string, setting_threshold = string, setting_min_hp = string }
function NS.register_recovery_middleware(class_name, config)
    if not config then return end

    -- HEALTHSTONE
    if config.healthstone then
        local hs_cfg = type(config.healthstone) == "table" and config.healthstone or {}
        local tiers = hs_cfg.tiers or { A.HealthstoneMaster, A.HealthstoneMajor }
        local extra_match = hs_cfg.extra_match

        rotation_registry:register_middleware({
            name = class_name .. "_Healthstone",
            priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

            matches = function(context)
                if not context.in_combat then return false end
                if extra_match and not extra_match(context) then return false end
                local threshold = context.settings.healthstone_hp or 0
                if threshold <= 0 then return false end
                if context.hp > threshold then return false end
                return true
            end,

            execute = function(icon, context)
                local obj = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil, unpack(tiers))
                if obj then
                    return obj:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
                end
                return nil
            end,
        })
    end

    -- HEALING POTION
    if config.healing_potion then
        local hp_cfg = type(config.healing_potion) == "table" and config.healing_potion or {}
        local default_hp = hp_cfg.default_hp or 25

        rotation_registry:register_middleware({
            name = class_name .. "_HealingPotion",
            priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,
            setting_key = "use_healing_potion",

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings.healing_potion_hp or default_hp
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
    end

    -- MANA POTION
    if config.mana_potion then
        local mp_cfg = type(config.mana_potion) == "table" and config.mana_potion or {}
        local default_pct = mp_cfg.default_pct or 50
        local priority_offset = mp_cfg.priority_offset or 0
        local tiers = mp_cfg.tiers or { A.SuperManaPotion }

        rotation_registry:register_middleware({
            name = class_name .. "_ManaPotion",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY + priority_offset,
            setting_key = "use_mana_potion",

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings.mana_potion_pct or default_pct
                if context.mana_pct > threshold then return false end
                return true
            end,

            execute = function(icon, context)
                for i = 1, #tiers do
                    if tiers[i]:IsReady(PLAYER_UNIT) then
                        return tiers[i]:Show(icon), format("[MW] Mana Potion - Mana: %.0f%%", context.mana_pct)
                    end
                end
                return nil
            end,
        })
    end

    -- DARK / DEMONIC RUNE
    if config.dark_rune then
        local dr_cfg = type(config.dark_rune) == "table" and config.dark_rune or {}
        local default_pct = dr_cfg.default_pct or 50
        local default_min_hp = dr_cfg.default_min_hp or 50
        local priority_offset = dr_cfg.priority_offset or -5
        local setting_toggle = dr_cfg.setting_toggle or "use_dark_rune"
        local setting_threshold = dr_cfg.setting_threshold or "dark_rune_pct"
        local setting_min_hp = dr_cfg.setting_min_hp or "dark_rune_min_hp"

        rotation_registry:register_middleware({
            name = class_name .. "_DarkRune",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY + priority_offset,
            setting_key = setting_toggle,

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings[setting_threshold] or default_pct
                if context.mana_pct > threshold then return false end
                if default_min_hp > 0 then
                    local min_hp = context.settings[setting_min_hp] or default_min_hp
                    if context.hp < min_hp then return false end
                end
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
    end
end
