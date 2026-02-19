-- Warrior Class Module
-- Defines all Warrior spells, constants, helper functions, and registers Warrior as a class

local _G, setmetatable, pairs, ipairs, tostring, select, type = _G, setmetatable, pairs, ipairs, tostring, select, type
local tinsert = table.insert
local format = string.format
local GetTime = _G.GetTime
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARRIOR" then return end

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Warrior]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    BloodFury          = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    Berserking         = Create({ Type = "Spell", ID = 26296, Click = { unit = "player", type = "spell", spell = 26296 } }),
    WarStomp           = Create({ Type = "Spell", ID = 20549, Click = { unit = "player", type = "spell", spell = 20549 } }),
    WilloftheForsaken  = Create({ Type = "Spell", ID = 7744, Click = { unit = "player", type = "spell", spell = 7744 } }),
    EscapeArtist       = Create({ Type = "Spell", ID = 20589, Click = { unit = "player", type = "spell", spell = 20589 } }),
    Stoneform          = Create({ Type = "Spell", ID = 20594, Click = { unit = "player", type = "spell", spell = 20594 } }),
    GiftOfTheNaaru     = Create({ Type = "Spell", ID = 28880, Click = { unit = "player", type = "spell", spell = 28880 } }),

    -- Core Damage (useMaxRank with base IDs)
    HeroicStrike       = Create({ Type = "Spell", ID = 78, useMaxRank = true }),
    Cleave             = Create({ Type = "Spell", ID = 845, useMaxRank = true }),
    MortalStrike       = Create({ Type = "Spell", ID = 12294, useMaxRank = true }),
    Bloodthirst        = Create({ Type = "Spell", ID = 23881, useMaxRank = true }),
    Execute            = Create({ Type = "Spell", ID = 5308, useMaxRank = true }),
    Overpower          = Create({ Type = "Spell", ID = 7384, useMaxRank = true }),
    Slam               = Create({ Type = "Spell", ID = 1464, useMaxRank = true }),
    Revenge            = Create({ Type = "Spell", ID = 6572, useMaxRank = true }),
    ShieldSlam         = Create({ Type = "Spell", ID = 23922, useMaxRank = true }),
    Devastate          = Create({ Type = "Spell", ID = 20243, useMaxRank = true }),
    Rend               = Create({ Type = "Spell", ID = 772, useMaxRank = true }),
    Hamstring          = Create({ Type = "Spell", ID = 1715, useMaxRank = true }),
    SunderArmor        = Create({ Type = "Spell", ID = 7386, useMaxRank = true }),
    ThunderClap        = Create({ Type = "Spell", ID = 6343, useMaxRank = true }),

    -- Single-rank spells
    Whirlwind          = Create({ Type = "Spell", ID = 1680 }),
    VictoryRush        = Create({ Type = "Spell", ID = 34428 }),
    Taunt              = Create({ Type = "Spell", ID = 355 }),

    -- Shouts
    BattleShout        = Create({ Type = "Spell", ID = 6673, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    CommandingShout    = Create({ Type = "Spell", ID = 469, Click = { unit = "player", type = "spell", spell = 469 } }),
    DemoralizingShout  = Create({ Type = "Spell", ID = 1160, useMaxRank = true }),

    -- Cooldowns (self-cast)
    DeathWish          = Create({ Type = "Spell", ID = 12292, Click = { unit = "player", type = "spell", spell = 12292 } }),
    Recklessness       = Create({ Type = "Spell", ID = 1719, Click = { unit = "player", type = "spell", spell = 1719 } }),
    SweepingStrikes    = Create({ Type = "Spell", ID = 12328, Click = { unit = "player", type = "spell", spell = 12328 } }),
    Bloodrage          = Create({ Type = "Spell", ID = 2687, Click = { unit = "player", type = "spell", spell = 2687 } }),
    BerserkerRage      = Create({ Type = "Spell", ID = 18499, Click = { unit = "player", type = "spell", spell = 18499 } }),
    Rampage            = Create({ Type = "Spell", ID = 29801, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Defensive (self-cast)
    ShieldBlock        = Create({ Type = "Spell", ID = 2565, Click = { unit = "player", type = "spell", spell = 2565 } }),
    ShieldWall         = Create({ Type = "Spell", ID = 871, Click = { unit = "player", type = "spell", spell = 871 } }),
    LastStand          = Create({ Type = "Spell", ID = 12975, Click = { unit = "player", type = "spell", spell = 12975 } }),
    SpellReflection    = Create({ Type = "Spell", ID = 23920, Click = { unit = "player", type = "spell", spell = 23920 } }),

    -- Interrupts
    Pummel             = Create({ Type = "Spell", ID = 6552 }),
    ShieldBash         = Create({ Type = "Spell", ID = 72, useMaxRank = true }),

    -- Stances (for suggesting stance swaps)
    BattleStance       = Create({ Type = "Spell", ID = 2457, Click = { unit = "player", type = "spell", spell = 2457 } }),
    DefensiveStance    = Create({ Type = "Spell", ID = 71, Click = { unit = "player", type = "spell", spell = 71 } }),
    BerserkerStance    = Create({ Type = "Spell", ID = 2458, Click = { unit = "player", type = "spell", spell = 2458 } }),

    -- Items
    SuperHealingPotion = Create({ Type = "Item", ID = 22829, Click = { unit = "player", type = "item", item = 22829 } }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446, Click = { unit = "player", type = "item", item = 13446 } }),
    HastePotion        = Create({ Type = "Item", ID = 22838, Click = { unit = "player", type = "item", item = 22838 } }),
    IronshieldPotion   = Create({ Type = "Item", ID = 22849, Click = { unit = "player", type = "item", item = 22849 } }),

    -- Healthstones
    HealthstoneMaster  = Create({ Type = "Item", ID = 22105, Click = { unit = "player", type = "item", item = 22105 } }),
    HealthstoneMajor   = Create({ Type = "Item", ID = 22104, Click = { unit = "player", type = "item", item = 22104 } }),

    -- Trinkets
    Trinket1           = Create({ Type = "Trinket", ID = 13 }),
    Trinket2           = Create({ Type = "Trinket", ID = 14 }),
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
    STANCE = {
        BATTLE    = 1,
        DEFENSIVE = 2,
        BERSERKER = 3,
    },

    BUFF_ID = {
        BATTLE_SHOUT      = 2048,
        COMMANDING_SHOUT  = 469,
        DEATH_WISH        = 12292,
        RECKLESSNESS      = 1719,
        SWEEPING_STRIKES  = 12328,
        BERSERKER_RAGE    = 18499,
        ENRAGE            = 14202,
        FLURRY            = 12974,
        RAMPAGE           = 30033,
        SHIELD_BLOCK      = 2565,
        LAST_STAND        = 12975,
        SPELL_REFLECTION  = 23920,
        BLOODRAGE         = 29131,
    },

    DEBUFF_ID = {
        REND              = 25208,
        SUNDER_ARMOR      = 25225,
        THUNDER_CLAP      = 25264,
        DEMO_SHOUT        = 25203,
        HAMSTRING         = 25212,
        MORTAL_STRIKE     = 12294,
        DEEP_WOUNDS       = 12867,
    },

    SUNDER_MAX_STACKS        = 5,
    SUNDER_REFRESH_WINDOW    = 3,
    TC_REFRESH_WINDOW        = 2,
    RAMPAGE_MAX_STACKS       = 5,

    -- All shout buff IDs for checking if any shout is active
    SHOUT_BUFF_IDS = { 2048, 469 },
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

    if playstyle == "arms" then
        local core = {
            { spell = A.MortalStrike, name = "Mortal Strike", required = true, note = "Arms talent" },
            { spell = A.Overpower, name = "Overpower", required = false },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Slam, name = "Slam", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.Rend, name = "Rend", required = false },
            { spell = A.SweepingStrikes, name = "Sweeping Strikes", required = false, note = "Arms talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    elseif playstyle == "fury" then
        local core = {
            { spell = A.Bloodthirst, name = "Bloodthirst", required = true, note = "Fury talent" },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.Slam, name = "Slam", required = false },
            { spell = A.Rampage, name = "Rampage", required = false, note = "41pt Fury talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
            { spell = A.Recklessness, name = "Recklessness", required = false },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    elseif playstyle == "protection" then
        local core = {
            { spell = A.ShieldSlam, name = "Shield Slam", required = false, note = "Prot talent" },
            { spell = A.Revenge, name = "Revenge", required = true },
            { spell = A.Devastate, name = "Devastate", required = false, note = "41pt Prot talent" },
            { spell = A.SunderArmor, name = "Sunder Armor", required = false },
            { spell = A.ShieldBlock, name = "Shield Block", required = false },
            { spell = A.ThunderClap, name = "Thunder Clap", required = false },
            { spell = A.LastStand, name = "Last Stand", required = false, note = "Prot talent" },
        }
        check_spell_availability(core, missing_spells, optional_missing)
    end

    print("|cFF00FF00[Diddy AIO]|r Switched to " .. playstyle .. " playstyle")

    if #missing_spells > 0 then
        print("|cFFFF0000[Diddy AIO]|r MISSING REQUIRED SPELLS:")
        for _, spell_name in ipairs(missing_spells) do
            print("|cFFFF0000[Diddy AIO]|r   - " .. spell_name)
        end
    end

    if #optional_missing > 0 then
        print("|cFFFF8800[Diddy AIO]|r Optional spells not available (will be skipped):")
        for _, spell_name in ipairs(optional_missing) do
            print("|cFFFF8800[Diddy AIO]|r   - " .. spell_name)
        end
    end

    if #missing_spells == 0 and #optional_missing == 0 then
        print("|cFF00FF00[Diddy AIO]|r All spells available!")
    end
end

NS.validate_playstyle_spells = validate_playstyle_spells

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Warrior",
    version = "v1.2.2",
    playstyles = { "arms", "fury", "protection" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "fury"
    end,

    get_idle_playstyle = nil,

    extend_context = function(ctx)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit("player"):CombatTime() or 0
        ctx.stance = Player:GetStance()
        ctx.rage = Player:Rage()
        ctx.enemy_count = MultiUnits:GetByRangeInCombat(8) or 0

        -- Buff tracking
        ctx.has_battle_shout = (Unit("player"):HasBuffs(Constants.BUFF_ID.BATTLE_SHOUT) or 0) > 0
        ctx.has_commanding_shout = (Unit("player"):HasBuffs(Constants.BUFF_ID.COMMANDING_SHOUT) or 0) > 0
        ctx.death_wish_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.DEATH_WISH) or 0) > 0
        ctx.recklessness_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.RECKLESSNESS) or 0) > 0
        ctx.sweeping_strikes_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SWEEPING_STRIKES) or 0) > 0
        ctx.berserker_rage_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.BERSERKER_RAGE) or 0) > 0
        ctx.rampage_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.RAMPAGE) or 0) > 0
        ctx.rampage_stacks = Unit("player"):HasBuffsStacks(Constants.BUFF_ID.RAMPAGE) or 0
        ctx.rampage_duration = Unit("player"):HasBuffs(Constants.BUFF_ID.RAMPAGE) or 0
        ctx.shield_block_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SHIELD_BLOCK) or 0) > 0

        -- Cache invalidation flags for per-playstyle context_builders
        ctx._arms_valid = false
        ctx._fury_valid = false
        ctx._prot_valid = false
    end,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Warrior]|r Class module loaded")
