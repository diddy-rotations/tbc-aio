-- Warrior Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Warrior class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARRIOR" then return end
local S = _G.FluxAIO_SECTIONS

-- Enable this profile
A.Data.ProfileEnabled[A.CurrentProfile] = true

-- ============================================================================
-- SETTINGS SCHEMA (Single Source of Truth)
-- ============================================================================
-- All setting metadata lives here. Used by:
--   1. aio/ui.lua: generates A.Data.ProfileUI[2] (framework backing store)
--   2. aio/settings.lua: renders the custom tabbed Settings UI
--   3. aio/core.lua: refresh_settings() iterates to build cached_settings
--
-- Keys are snake_case -- the same string used everywhere:
--   GetToggle(2, key), SetToggle({2, key, ...}), cached_settings[key], context.settings[key]

_G.FluxAIO_SETTINGS_SCHEMA = {
    -- Tab 1: General
    [1] = { name = "General", sections = {
        { header = "Spec Selection", settings = {
            { type = "dropdown", key = "playstyle", default = "fury", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "arms", text = "Arms" },
                  { value = "fury", text = "Fury" },
                  { value = "protection", text = "Protection" },
              }},
        }},
        { header = "Shouts", settings = {
            { type = "dropdown", key = "shout_type", default = "battle", label = "Shout Type",
              tooltip = "Which shout to maintain.",
              options = {
                  { value = "battle", text = "Battle Shout" },
                  { value = "commanding", text = "Commanding Shout" },
                  { value = "none", text = "None" },
              }},
            { type = "checkbox", key = "auto_shout", default = true, label = "Auto Shout",
              tooltip = "Automatically maintain selected shout buff." },
        }},
        { header = "Debuff Maintenance", settings = {
            { type = "dropdown", key = "sunder_armor_mode", default = "none", label = "Sunder Armor",
              tooltip = "Sunder Armor maintenance mode.",
              options = {
                  { value = "none", text = "None" },
                  { value = "help_stack", text = "Help Stack (to 5)" },
                  { value = "maintain", text = "Maintain (stack + refresh)" },
              }},
            { type = "checkbox", key = "maintain_thunder_clap", default = false, label = "Maintain Thunder Clap",
              tooltip = "Keep Thunder Clap debuff on target (requires Battle Stance)." },
            { type = "checkbox", key = "maintain_demo_shout", default = false, label = "Maintain Demo Shout",
              tooltip = "Keep Demoralizing Shout debuff on target." },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_interrupt", default = true, label = "Auto Interrupt",
              tooltip = "Interrupt enemy casts (Pummel in Berserker, Shield Bash in Defensive)." },
            { type = "checkbox", key = "use_bloodrage", default = true, label = "Auto Bloodrage",
              tooltip = "Use Bloodrage on cooldown for rage generation." },
            { type = "slider", key = "bloodrage_min_hp", default = 50, min = 20, max = 80, label = "Bloodrage Min HP (%)",
              tooltip = "Don't use Bloodrage when HP is below this (it costs HP).", format = "%d%%" },
            { type = "checkbox", key = "use_berserker_rage", default = true, label = "Auto Berserker Rage",
              tooltip = "Use Berserker Rage on cooldown when in Berserker Stance (rage gen + fear immunity)." },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "aoe_threshold", default = 0, min = 0, max = 8, label = "AoE Threshold",
              tooltip = "Minimum enemies to use Cleave instead of Heroic Strike. 0 = disable.", format = "%d" },
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Recovery Items", settings = {
            { type = "slider", key = "healthstone_hp", default = 35, min = 0, max = 100, label = "Healthstone HP (%)",
              tooltip = "Use Healthstone when HP drops below this. 0 = disable.", format = "%d%%" },
            { type = "checkbox", key = "use_healing_potion", default = true, label = "Use Healing Potion",
              tooltip = "Use Healing Potion when HP drops low in combat." },
            { type = "slider", key = "healing_potion_hp", default = 25, min = 10, max = 50, label = "Healing Potion HP (%)",
              tooltip = "Use Healing Potion when HP drops below this.", format = "%d%%" },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Arms
    [2] = { name = "Arms", sections = {
        { header = "Core Abilities", settings = {
            { type = "checkbox", key = "arms_maintain_rend", default = true, label = "Maintain Rend",
              tooltip = "Keep Rend DoT on target (for Blood Frenzy talent)." },
            { type = "slider", key = "arms_rend_refresh", default = 4, min = 2, max = 8, label = "Rend Refresh (sec)",
              tooltip = "Refresh Rend when remaining duration is below this.", format = "%d sec" },
            { type = "checkbox", key = "arms_use_overpower", default = true, label = "Use Overpower",
              tooltip = "Use Overpower on dodge procs (Battle Stance only)." },
            { type = "slider", key = "arms_overpower_rage", default = 25, min = 10, max = 50, label = "Overpower Min Rage",
              tooltip = "Minimum rage to use Overpower.", format = "%d" },
        }},
        { header = "Rotation", settings = {
            { type = "checkbox", key = "arms_use_whirlwind", default = true, label = "Use Whirlwind",
              tooltip = "Use Whirlwind on cooldown (Berserker Stance only)." },
            { type = "checkbox", key = "arms_use_slam", default = true, label = "Use Slam",
              tooltip = "Use Slam as filler (requires Improved Slam 2/2 for 0.5s cast)." },
            { type = "checkbox", key = "arms_use_sweeping_strikes", default = true, label = "Use Sweeping Strikes",
              tooltip = "Use Sweeping Strikes on cooldown (Battle Stance)." },
        }},
        { header = "Execute Phase", settings = {
            { type = "checkbox", key = "arms_execute_phase", default = true, label = "Execute Phase",
              tooltip = "Switch to Execute priority at <20% target HP." },
            { type = "checkbox", key = "arms_use_ms_execute", default = true, label = "MS During Execute",
              tooltip = "Use Mortal Strike during execute phase." },
            { type = "checkbox", key = "arms_use_ww_execute", default = true, label = "WW During Execute",
              tooltip = "Use Whirlwind during execute phase." },
        }},
        { header = "Rage Dump", settings = {
            { type = "slider", key = "arms_hs_rage_threshold", default = 55, min = 30, max = 80, label = "HS Rage Threshold",
              tooltip = "Queue Heroic Strike above this rage.", format = "%d" },
            { type = "checkbox", key = "arms_hs_during_execute", default = false, label = "HS During Execute",
              tooltip = "Allow Heroic Strike during execute phase." },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "arms_use_death_wish", default = true, label = "Use Death Wish",
              tooltip = "Use Death Wish cooldown (+20% damage)." },
        }},
    }},

    -- Tab 3: Fury
    [3] = { name = "Fury", sections = {
        { header = "Core Abilities", settings = {
            { type = "checkbox", key = "fury_use_whirlwind", default = true, label = "Use Whirlwind",
              tooltip = "Use Whirlwind on cooldown." },
            { type = "checkbox", key = "fury_prioritize_ww", default = false, label = "Prioritize WW over BT",
              tooltip = "Use Whirlwind before Bloodthirst in priority." },
            { type = "checkbox", key = "fury_use_slam", default = false, label = "Use Slam",
              tooltip = "Use Slam weaving (requires Improved Slam 2/2)." },
            { type = "checkbox", key = "fury_use_overpower", default = false, label = "Use Overpower",
              tooltip = "Use Overpower on dodge procs (Battle Stance only)." },
            { type = "slider", key = "fury_overpower_rage", default = 25, min = 10, max = 50, label = "Overpower Min Rage",
              tooltip = "Minimum rage to use Overpower.", format = "%d" },
        }},
        { header = "Rage Dump & Utility", settings = {
            { type = "checkbox", key = "fury_use_heroic_strike", default = true, label = "Heroic Strike Dump",
              tooltip = "Auto-queue Heroic Strike as rage dump." },
            { type = "slider", key = "fury_hs_rage_threshold", default = 50, min = 30, max = 80, label = "HS Rage Threshold",
              tooltip = "Queue Heroic Strike above this rage.", format = "%d" },
            { type = "checkbox", key = "fury_use_hamstring", default = false, label = "Hamstring Weave",
              tooltip = "Weave Hamstring for Sword Spec procs." },
            { type = "slider", key = "fury_hamstring_rage", default = 50, min = 20, max = 80, label = "Hamstring Min Rage",
              tooltip = "Minimum rage to use Hamstring.", format = "%d" },
        }},
        { header = "Rampage", settings = {
            { type = "slider", key = "fury_rampage_threshold", default = 5, min = 2, max = 10, label = "Rampage Refresh (sec)",
              tooltip = "Refresh Rampage when duration below this.", format = "%d sec" },
        }},
        { header = "Execute Phase", settings = {
            { type = "checkbox", key = "fury_execute_phase", default = true, label = "Execute Phase",
              tooltip = "Switch to Execute priority at <20% target HP." },
            { type = "checkbox", key = "fury_bt_during_execute", default = true, label = "BT During Execute",
              tooltip = "Use Bloodthirst during execute phase." },
            { type = "checkbox", key = "fury_ww_during_execute", default = true, label = "WW During Execute",
              tooltip = "Use Whirlwind during execute phase." },
            { type = "checkbox", key = "fury_hs_during_execute", default = false, label = "HS During Execute",
              tooltip = "Allow Heroic Strike during execute phase." },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "fury_use_death_wish", default = true, label = "Use Death Wish",
              tooltip = "Use Death Wish cooldown (+20% damage)." },
            { type = "checkbox", key = "fury_use_recklessness", default = true, label = "Use Recklessness",
              tooltip = "Use Recklessness during burn windows (+100% crit)." },
        }},
    }},

    -- Tab 4: Protection
    [4] = { name = "Protection", sections = {
        { header = "Core Abilities", settings = {
            { type = "checkbox", key = "prot_use_shield_block", default = true, label = "Auto Shield Block",
              tooltip = "Maintain Shield Block on cooldown (crush prevention)." },
            { type = "checkbox", key = "prot_use_revenge", default = true, label = "Use Revenge",
              tooltip = "Use Revenge when available (highest threat/rage)." },
            { type = "checkbox", key = "prot_use_devastate", default = true, label = "Use Devastate",
              tooltip = "Use Devastate (requires Prot 41-point talent)." },
        }},
        { header = "Debuffs", settings = {
            { type = "checkbox", key = "prot_use_thunder_clap", default = true, label = "Use Thunder Clap",
              tooltip = "Maintain Thunder Clap debuff (requires Battle Stance swap)." },
            { type = "checkbox", key = "prot_use_demo_shout", default = true, label = "Use Demo Shout",
              tooltip = "Maintain Demoralizing Shout debuff." },
        }},
        { header = "Rage Dump", settings = {
            { type = "slider", key = "prot_hs_rage_threshold", default = 60, min = 40, max = 90, label = "HS Rage Threshold",
              tooltip = "Queue Heroic Strike above this rage.", format = "%d" },
        }},
        { header = "Taunts", settings = {
            { type = "checkbox", key = "prot_no_taunt", default = false, label = "Disable Taunts (Off-Tank)",
              tooltip = "Disables Taunt and Challenging Shout. Use when off-tanking." },
            { type = "checkbox", key = "prot_use_taunt", default = true, label = "Auto Taunt",
              tooltip = "Taunt when you lose aggro on an elite or boss." },
            { type = "checkbox", key = "prot_use_challenging_shout", default = true, label = "Use Challenging Shout",
              tooltip = "AoE taunt for emergency multi-target aggro loss. 10min CD." },
            { type = "slider", key = "prot_cshout_min_bosses", default = 1, min = 1, max = 3,
              label = "C.Shout Min Bosses", tooltip = "Min loose bosses in range to use Challenging Shout.", format = "%d" },
            { type = "slider", key = "prot_cshout_min_elites", default = 3, min = 1, max = 6,
              label = "C.Shout Min Elites", tooltip = "Min loose elites in range to use Challenging Shout.", format = "%d" },
            { type = "slider", key = "prot_cshout_min_trash", default = 5, min = 2, max = 10,
              label = "C.Shout Min Trash", tooltip = "Min loose trash mobs in range to use Challenging Shout.", format = "%d" },
        }},
    }},

    -- Tab 5: CDs & Survival
    [5] = { name = "CDs & Survival", sections = {
        S.trinkets("Use racial ability (Blood Fury, Berserking, etc.)."),
        { header = "Emergency Survival", settings = {
            { type = "slider", key = "last_stand_hp", default = 20, min = 0, max = 50, label = "Last Stand HP (%)",
              tooltip = "Use Last Stand below this HP. 0 = disable.", format = "%d%%" },
            { type = "slider", key = "shield_wall_hp", default = 15, min = 0, max = 50, label = "Shield Wall HP (%)",
              tooltip = "Use Shield Wall below this HP. 0 = disable.", format = "%d%%" },
            { type = "checkbox", key = "use_spell_reflection", default = true, label = "Auto Spell Reflect",
              tooltip = "Use Spell Reflection on incoming spells." },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Warrior schema loaded")
