-- Rogue Class Module
-- Defines all Rogue spells, constants, helper functions, and registers Rogue as a class

local _G, setmetatable, pairs, ipairs, tostring, select, type = _G, setmetatable, pairs, ipairs, tostring, select, type
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "ROGUE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Rogue]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials (self-cast)
    BloodFury         = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    Berserking        = Create({ Type = "Spell", ID = 26297, Click = { unit = "player", type = "spell", spell = 26297 } }),
    ArcaneTorrent     = Create({ Type = "Spell", ID = 25046, Click = { unit = "player", type = "spell", spell = 25046 } }),
    WilloftheForsaken = Create({ Type = "Spell", ID = 7744, Click = { unit = "player", type = "spell", spell = 7744 } }),
    EscapeArtist      = Create({ Type = "Spell", ID = 20589, Click = { unit = "player", type = "spell", spell = 20589 } }),
    Stoneform         = Create({ Type = "Spell", ID = 20594, Click = { unit = "player", type = "spell", spell = 20594 } }),

    -- Builders
    SinisterStrike = Create({ Type = "Spell", ID = 1752, useMaxRank = true }),
    Backstab       = Create({ Type = "Spell", ID = 53, useMaxRank = true }),
    Mutilate       = Create({ Type = "Spell", ID = 34413 }),
    Hemorrhage     = Create({ Type = "Spell", ID = 16511, useMaxRank = true }),
    GhostlyStrike  = Create({ Type = "Spell", ID = 14278 }),
    Shiv           = Create({ Type = "Spell", ID = 5938 }),

    -- Finishers
    SliceAndDice = Create({ Type = "Spell", ID = 5171, useMaxRank = true }),
    Eviscerate   = Create({ Type = "Spell", ID = 2098, useMaxRank = true }),
    Rupture      = Create({ Type = "Spell", ID = 1943, useMaxRank = true }),
    Envenom      = Create({ Type = "Spell", ID = 32645, useMaxRank = true }),
    ExposeArmor  = Create({ Type = "Spell", ID = 8647, useMaxRank = true }),
    KidneyShot   = Create({ Type = "Spell", ID = 408, useMaxRank = true }),

    -- Stealth Openers
    Ambush        = Create({ Type = "Spell", ID = 8676, useMaxRank = true }),
    Garrote       = Create({ Type = "Spell", ID = 703, useMaxRank = true }),
    CheapShot     = Create({ Type = "Spell", ID = 1833 }),
    Premeditation = Create({ Type = "Spell", ID = 14183, Click = { unit = "player", type = "spell", spell = 14183 } }),

    -- Defensive / Utility (self-cast where applicable)
    Evasion        = Create({ Type = "Spell", ID = 5277, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    Sprint         = Create({ Type = "Spell", ID = 2983, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    CloakOfShadows = Create({ Type = "Spell", ID = 31224, Click = { unit = "player", type = "spell", spell = 31224 } }),
    Vanish         = Create({ Type = "Spell", ID = 1856, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    Kick           = Create({ Type = "Spell", ID = 1766, useMaxRank = true }),
    Feint          = Create({ Type = "Spell", ID = 1966, useMaxRank = true }),
    Gouge          = Create({ Type = "Spell", ID = 1776, useMaxRank = true }),
    Blind          = Create({ Type = "Spell", ID = 2094 }),

    -- Cooldowns (self-cast)
    BladeFlurry    = Create({ Type = "Spell", ID = 13877, Click = { unit = "player", type = "spell", spell = 13877 } }),
    AdrenalineRush = Create({ Type = "Spell", ID = 13750, Click = { unit = "player", type = "spell", spell = 13750 } }),
    ColdBlood      = Create({ Type = "Spell", ID = 14177, Click = { unit = "player", type = "spell", spell = 14177 } }),
    Preparation    = Create({ Type = "Spell", ID = 14185, Click = { unit = "player", type = "spell", spell = 14185 } }),
    Shadowstep     = Create({ Type = "Spell", ID = 36554 }),

    -- Items
    HastePotion        = Create({ Type = "Item", ID = 22838, Click = { unit = "player", type = "item", item = 22838 } }),
    ThistleTea         = Create({ Type = "Item", ID = 7676, Click = { unit = "player", type = "item", item = 7676 } }),
    SuperHealingPotion = Create({ Type = "Item", ID = 22829, Click = { unit = "player", type = "item", item = 22829 } }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446, Click = { unit = "player", type = "item", item = 13446 } }),
    HealthstoneMaster  = Create({ Type = "Item", ID = 22105, Click = { unit = "player", type = "item", item = 22105 } }),
    HealthstoneMajor   = Create({ Type = "Item", ID = 22104, Click = { unit = "player", type = "item", item = 22104 } }),

    -- Trinkets
    Trinket1 = Create({ Type = "Trinket", ID = 13 }),
    Trinket2 = Create({ Type = "Trinket", ID = 14 }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local is_spell_known = NS.is_spell_known
local check_spell_availability = NS.check_spell_availability
local unavailable_spells = NS.unavailable_spells
local PLAYER_UNIT = NS.PLAYER_UNIT
local TARGET_UNIT = NS.TARGET_UNIT

-- Framework helpers
local MultiUnits = A.MultiUnits
local DetermineUsableObject = A.DetermineUsableObject

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    BUFF_ID = {
        SLICE_AND_DICE      = 6774,
        BLADE_FLURRY        = 13877,
        ADRENALINE_RUSH     = 13750,
        COLD_BLOOD          = 14177,
        EVASION             = 26669,   -- R2 buff
        SPRINT              = 26023,   -- buff ID (differs from cast ID 11305)
        CLOAK_OF_SHADOWS    = 31224,
        STEALTH             = 1787,    -- R4 buff
        SHADOWSTEP_BUFF     = 36563,   -- +20% damage (differs from cast ID 36554)
        REMORSELESS_ATTACKS = 14143,
        MASTER_OF_SUBTLETY  = 31665,
    },

    DEBUFF_ID = {
        RUPTURE        = 26867,
        EXPOSE_ARMOR   = 26866,
        GARROTE        = 26884,
        HEMORRHAGE     = 26864,
        DEADLY_POISON  = 27187,   -- proc/debuff ID (NOT application ID 27186)
        WOUND_POISON   = 27189,
        FIND_WEAKNESS  = 31234,
    },

    ENERGY = {
        SINISTER_STRIKE = 45,
        BACKSTAB        = 60,
        MUTILATE        = 60,
        HEMORRHAGE      = 35,
        GHOSTLY_STRIKE  = 40,
        SHIV            = 20,
        SLICE_AND_DICE  = 25,
        EVISCERATE      = 35,
        RUPTURE         = 25,
        ENVENOM         = 35,
        EXPOSE_ARMOR    = 25,
        KICK            = 25,
        FEINT           = 20,
        AMBUSH          = 60,
        GARROTE         = 50,
        CHEAP_SHOT      = 60,
    },

    ROGUE = {
        SND_MIN_DURATION      = 2,
        DP_REFRESH_THRESHOLD  = 2,
    },
}

NS.Constants = Constants

-- ============================================================================
-- PLAYSTYLE SPELL VALIDATION
-- ============================================================================
local last_validated_playstyle = nil

local function validate_playstyle_spells(playstyle)
    if playstyle == last_validated_playstyle then return end
    last_validated_playstyle = playstyle

    for k in pairs(unavailable_spells) do
        unavailable_spells[k] = nil
    end

    local missing_spells = {}
    local optional_missing = {}

    if playstyle == "combat" then
        local core = {
            { spell = A.SinisterStrike, name = "Sinister Strike", required = true },
            { spell = A.SliceAndDice, name = "Slice and Dice", required = true },
            { spell = A.Eviscerate, name = "Eviscerate", required = true },
            { spell = A.Rupture, name = "Rupture", required = false },
            { spell = A.BladeFlurry, name = "Blade Flurry", required = false, note = "Combat talent" },
            { spell = A.AdrenalineRush, name = "Adrenaline Rush", required = false, note = "Combat talent" },
            { spell = A.ExposeArmor, name = "Expose Armor", required = false },
            { spell = A.Shiv, name = "Shiv", required = false, note = "TBC ability" },
            { spell = A.Kick, name = "Kick", required = false },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    elseif playstyle == "assassination" then
        local core = {
            { spell = A.Mutilate, name = "Mutilate", required = true, note = "41pt Assassination talent" },
            { spell = A.SliceAndDice, name = "Slice and Dice", required = true },
            { spell = A.Eviscerate, name = "Eviscerate", required = true },
            { spell = A.Rupture, name = "Rupture", required = false },
            { spell = A.Envenom, name = "Envenom", required = false, note = "TBC ability" },
            { spell = A.ColdBlood, name = "Cold Blood", required = false, note = "Assassination talent" },
            { spell = A.Shiv, name = "Shiv", required = false, note = "TBC ability" },
            { spell = A.Kick, name = "Kick", required = false },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    elseif playstyle == "subtlety" then
        local core = {
            { spell = A.Hemorrhage, name = "Hemorrhage", required = true, note = "Subtlety talent" },
            { spell = A.SliceAndDice, name = "Slice and Dice", required = true },
            { spell = A.Eviscerate, name = "Eviscerate", required = true },
            { spell = A.Rupture, name = "Rupture", required = false },
            { spell = A.Shadowstep, name = "Shadowstep", required = false, note = "41pt Subtlety talent" },
            { spell = A.GhostlyStrike, name = "Ghostly Strike", required = false, note = "Subtlety talent" },
            { spell = A.Preparation, name = "Preparation", required = false, note = "Subtlety talent" },
            { spell = A.Premeditation, name = "Premeditation", required = false, note = "Subtlety talent" },
            { spell = A.Kick, name = "Kick", required = false },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    end

    print("|cFF00FF00[Flux AIO]|r Switched to Rogue " .. playstyle .. " playstyle")

    if #missing_spells > 0 then
        print("|cFFFF0000[Flux AIO]|r MISSING REQUIRED SPELLS:")
        for _, spell_name in ipairs(missing_spells) do
            print("|cFFFF0000[Flux AIO]|r   - " .. spell_name)
        end
    end

    if #optional_missing > 0 then
        print("|cFFFF8800[Flux AIO]|r Optional spells not available (will be skipped):")
        for _, spell_name in ipairs(optional_missing) do
            print("|cFFFF8800[Flux AIO]|r   - " .. spell_name)
        end
    end

    if #missing_spells == 0 and #optional_missing == 0 then
        print("|cFF00FF00[Flux AIO]|r All spells available!")
    end
end

NS.validate_playstyle_spells = validate_playstyle_spells

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Rogue",
    version = "v1.6.0",
    playstyles = { "combat", "assassination", "subtlety" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "combat"
    end,

    get_idle_playstyle = nil,

    extend_context = function(ctx)
        ctx.energy = Player:Energy()
        ctx.cp = Player:ComboPoints()
        local stealthed = Player:IsStealthed()
        ctx.is_stealthed = stealthed ~= nil and stealthed ~= false
        local behind = Player:IsBehind(0.3)
        ctx.is_behind = behind ~= nil and behind ~= false
        ctx.combat_time = Unit("player"):CombatTime() or 0
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.enemy_count = MultiUnits:GetByRangeInCombat(10) or 0
        -- Cache invalidation flags for per-playstyle context_builders
        ctx._combat_valid = false
        ctx._assassination_valid = false
        ctx._subtlety_valid = false
    end,

    gap_handler = function(icon, context)
        if A.Shadowstep:IsReady(TARGET_UNIT) then
            return A.Shadowstep:Show(icon), "[GAP] Shadowstep"
        end
        if A.Sprint:IsReady(PLAYER_UNIT) then
            return A.Sprint:Show(icon), "[GAP] Sprint"
        end
        return nil
    end,

    dashboard = {
        resource = { type = "energy", label = "Energy", color = {1.00, 0.96, 0.41} },
        cooldowns = {
            combat = { A.BladeFlurry, A.AdrenalineRush, A.Sprint, A.Trinket1, A.Trinket2 },
            assassination = { A.ColdBlood, A.Sprint, A.Trinket1, A.Trinket2 },
            subtlety = { A.Preparation, A.Shadowstep, A.Sprint, A.Trinket1, A.Trinket2 },
        },
        buffs = {
            combat = {
                { id = Constants.BUFF_ID.BLADE_FLURRY, label = "BF" },
                { id = Constants.BUFF_ID.ADRENALINE_RUSH, label = "AR" },
                { id = Constants.BUFF_ID.SLICE_AND_DICE, label = "SnD" },
            },
            assassination = {
                { id = Constants.BUFF_ID.SLICE_AND_DICE, label = "SnD" },
                { id = Constants.BUFF_ID.COLD_BLOOD, label = "CB" },
            },
            subtlety = {
                { id = Constants.BUFF_ID.SLICE_AND_DICE, label = "SnD" },
                { id = Constants.BUFF_ID.MASTER_OF_SUBTLETY, label = "MoS" },
            },
        },
        debuffs = {
            combat = {
                { id = Constants.DEBUFF_ID.RUPTURE, label = "Rupt", target = true },
            },
            assassination = {
                { id = Constants.DEBUFF_ID.RUPTURE, label = "Rupt", target = true },
                { id = Constants.DEBUFF_ID.DEADLY_POISON, label = "DP", target = true, show_stacks = true },
                { id = Constants.DEBUFF_ID.EXPOSE_ARMOR, label = "EA", target = true },
            },
            subtlety = {
                { id = Constants.DEBUFF_ID.RUPTURE, label = "Rupt", target = true },
                { id = Constants.DEBUFF_ID.HEMORRHAGE, label = "Hemo", target = true },
            },
        },
        timers = {
            {
                label = function() return (Player:GetSwingShoot() or 0) > 0 and "Shoot" or "Swing" end,
                color = {1.00, 0.96, 0.41},
                remaining = function()
                    local shoot = Player:GetSwingShoot() or 0
                    if shoot > 0 then return shoot end
                    local s = Player:GetSwingStart(1) or 0; local d = Player:GetSwing(1) or 0
                    if s > 0 and d > 0 then local r = (s + d) - _G.GetTime(); return r > 0 and r or 0 end
                    return 0
                end,
                duration = function()
                    if (Player:GetSwingShoot() or 0) > 0 then return _G.UnitRangedDamage("player") or 1.5 end
                    return Player:GetSwing(1) or 2.0
                end,
            },
        },
        custom_lines = {
            function(context) return "CP", tostring(context.cp or 0) end,
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Rogue]|r Class module loaded")
