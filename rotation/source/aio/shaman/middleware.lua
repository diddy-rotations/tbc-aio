-- Shaman Middleware Module
-- Cross-playstyle concerns: interrupt, emergency, recovery, shields, dispels, weapon imbues

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "SHAMAN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Shaman Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- EARTH SHOCK INTERRUPT (highest priority — TBC's ONLY shaman interrupt!)
-- Delegates to shared interrupt awareness system for priority scanning + tab-targeting
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Interrupt",
    priority = Priority.MIDDLEWARE.FORM_RESHIFT,  -- 500

    matches = function(context)
        if not context.settings.use_interrupt then return false end

        -- Check tab-target priority interrupt first (replaces old state machine)
        local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
        if NS.interrupt_tab_matches("Shaman", context, spell, 20) then
            return true
        end

        -- Fallback: current-target interrupt
        if not context.has_valid_enemy_target then return false end
        local decision = NS.should_interrupt(context)
        if not decision then return false end
        if decision == "normal" and context.settings.interrupt_priority_only then return false end
        return true
    end,

    execute = function(icon, context)
        local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock

        -- Tab-target flow (seeking/returning phases)
        local tab_result, tab_log = NS.interrupt_tab_execute("Shaman", icon, context, spell)
        if tab_result then return tab_result, tab_log end

        -- Standard current-target interrupt
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if spell:IsReady(TARGET_UNIT) then
                return spell:Show(icon), format("[MW] Earth Shock Interrupt - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

NS.register_interrupt_capability("Shaman", {
    supports_tab_target = true,
    resolve_spell = function(context)
        return context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
    end,
})

-- ============================================================================
-- SHARED RECOVERY ITEMS (Healthstone, Healing Potion, Mana Potion, Dark Rune)
-- ============================================================================
NS.register_recovery_middleware("Shaman", {
    healthstone = true,
    healing_potion = true,
    mana_potion = { tiers = { A.SuperManaPotion, A.MajorManaPotion } },
    dark_rune = true,
})

-- Shared threat middleware (no dump spell)
NS.register_threat_middleware("Shaman", {})

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
    priority = 350,

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
    priority = 340,

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
    priority = 200,

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
        if playstyle ~= "enhancement" and playstyle ~= "elemental" then return false end
        local hasMH, _, _, _, hasOH = _G.GetWeaponEnchantInfo()
        if playstyle == "enhancement" then
            if not hasMH or not hasOH then return true end
        else
            -- Ele: MH only
            if not hasMH then return true end
        end
        return false
    end,

    execute = function(icon, context)
        local playstyle = context.settings.playstyle or "elemental"
        local hasMH, _, _, _, hasOH = _G.GetWeaponEnchantInfo()
        if playstyle == "enhancement" then
            local mh_imbue = context.settings.enh_mh_imbue or "windfury"
            local oh_imbue = context.settings.enh_oh_imbue or "flametongue"
            -- MH imbue
            if not hasMH then
                local mh_spell = (mh_imbue == "windfury") and A.WindfuryWeapon or A.FlametongueWeapon
                if mh_spell:IsReady(PLAYER_UNIT) then
                    return mh_spell:Show(icon), format("[MW] %s (MH)", mh_imbue == "windfury" and "Windfury" or "Flametongue")
                end
            end
            -- OH imbue
            if not hasOH then
                local oh_spell = (oh_imbue == "windfury") and A.WindfuryWeapon or A.FlametongueWeapon
                if oh_spell:IsReady(PLAYER_UNIT) then
                    return oh_spell:Show(icon), format("[MW] %s (OH)", oh_imbue == "windfury" and "Windfury" or "Flametongue")
                end
            end
        else
            -- Ele: MH Flametongue only (caster weapon)
            if not hasMH and A.FlametongueWeapon:IsReady(PLAYER_UNIT) then
                return A.FlametongueWeapon:Show(icon), "[MW] Flametongue Weapon (MH)"
            end
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO TREMOR TOTEM (Fear/Charm/Sleep protection)
-- ============================================================================
-- TBC NPC IDs that cast Fear, Charm, or Sleep effects
local FEAR_CASTER_IDS = {
    -- Raids
    [17225] = true,  -- Nightbane (Karazhan) — Bellowing Roar
    [17968] = true,  -- Archimonde (Hyjal) — Fear
    [17808] = true,  -- Anetheron (Hyjal) — Carrion Swarm (sleep)
    [22855] = true,  -- Illidari Nightlord (BT) — Fear (AoE)
    [23420] = true,  -- Essence of Anger (BT RoS) — Seethe
    -- Dungeon bosses
    [18731] = true,  -- Ambassador Hellmaw (Shadow Lab) — Fear (45yd AoE)
    [18667] = true,  -- Blackheart the Inciter (Shadow Lab) — Incite Chaos (charm)
    [17308] = true,  -- Omor the Unscarred (Ramparts) — Fear
    [17536] = true,  -- Nazan (Ramparts) — Bellowing Roar
    [16807] = true,  -- Grand Warlock Nethekurse (Shattered Halls) — Death Coil
    -- Trash
    [20883] = true,  -- Coilfang Fathom-Witch (SSC) — Domination (charm)
    [21956] = true,  -- Bonechewer Taskmaster (BT) — Fear
    [22960] = true,  -- Ashtongue Primalist (BT) — Wyvern Sting (sleep)
}

local GetTotemInfo = _G.GetTotemInfo

rotation_registry:register_middleware({
    name = "Shaman_AutoTremor",
    priority = 260,  -- above shield maintain (250), below recovery (300)
    setting_key = "use_auto_tremor",

    matches = function(context)
        if not context.settings.use_auto_tremor then return false end
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        -- Check target NPC ID against fear caster list
        local npc_id = select(6, Unit(TARGET_UNIT):InfoGUID())
        if not npc_id or not FEAR_CASTER_IDS[tonumber(npc_id)] then return false end
        -- Fear caster targeted — check if Tremor is already active in earth slot
        local have, name = GetTotemInfo(2)
        if have and name and name:find("Tremor") and context.totem_earth_remaining > 5 then
            return false  -- tremor already active with good duration
        end
        return true
    end,

    execute = function(icon, context)
        if A.TremorTotem:IsReady(PLAYER_UNIT) then
            return A.TremorTotem:Show(icon), "[MW] Tremor Totem (fear boss)"
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Shaman]|r Middleware module loaded")
