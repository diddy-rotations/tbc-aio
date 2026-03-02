-- Flux AIO - Shared Interrupt Awareness
-- Provides priority cast database, smart interrupt decisions, and tab-target state machine
-- Classes keep their own kick implementation but use shared decision/targeting logic

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Interrupt]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local UnitClassification = _G.UnitClassification
local UnitGUID = _G.UnitGUID
local GetTime = _G.GetTime
local CONST = A.Const

local TARGET_UNIT = "target"
local PLAYER_UNIT = "player"
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo

-- ============================================================================
-- COMBAT LOG: DUPLICATE INTERRUPT PREVENTION
-- Tracks SPELL_INTERRUPT events to avoid double-kicking targets
-- Covers both self and teammate interrupts
-- ============================================================================

local recent_interrupts = {}  -- [destGUID] = timestamp
local INTERRUPT_DEDUP_WINDOW = 0.5  -- seconds to suppress kicks after an interrupt

local interrupt_frame = _G.CreateFrame("Frame")
interrupt_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
interrupt_frame:SetScript("OnEvent", function()
    local _, event, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if event == "SPELL_INTERRUPT" then
        recent_interrupts[destGUID] = GetTime()
    end
end)

local function was_recently_interrupted(guid)
    if not guid then return false end
    local last_kick = recent_interrupts[guid]
    if not last_kick then return false end
    if (GetTime() - last_kick) < INTERRUPT_DEDUP_WINDOW then
        return true
    end
    recent_interrupts[guid] = nil
    return false
end

-- ============================================================================
-- UNIT CLASSIFICATION HELPERS
-- ============================================================================

local CLASSIFICATION_RANK = {
    worldboss = 3,
    elite     = 2,
    rareelite = 2,
    rare      = 1,
    normal    = 1,
    trivial   = 0,
    minus     = 0,
}

local SCOPE_THRESHOLD = {
    boss  = 3,
    elite = 2,
    all   = 0,
}

-- ============================================================================
-- PRIORITY INTERRUPT SPELL DATABASE
-- Migrated from Shaman middleware + expanded for all TBC dungeon/raid content
-- Categories: "heal", "cc", "damage"
-- Spells NOT in this table are treated as "normal" (low priority)
-- ============================================================================

NS.INTERRUPT_PRIORITY = {
    -- ============================
    -- HEALING (always interrupt)
    -- ============================
    [41455] = "heal",   -- Circle of Healing
    [30528] = "heal",   -- Dark Mending
    [30878] = "heal",   -- Eternal Affection
    [17843] = "heal",   -- Flash Heal
    [35096] = "heal",   -- Greater Heal
    [33144] = "heal",   -- Heal
    [38330] = "heal",   -- Healing Wave
    [43451] = "heal",   -- Holy Light
    [46181] = "heal",   -- Lesser Healing Wave
    [33152] = "heal",   -- Prayer of Healing
    [8362]  = "heal",   -- Renew

    -- ============================
    -- CROWD CONTROL (always interrupt)
    -- ============================
    [41410] = "cc",     -- Deaden
    [37135] = "cc",     -- Domination
    [40184] = "cc",     -- Paralyzing Screech
    [39096] = "cc",     -- Polarity Shift
    [13323] = "cc",     -- Polymorph
    [38815] = "cc",     -- Sightless Touch

    -- ============================
    -- DANGEROUS DAMAGE (interrupt if possible)
    -- ============================
    [31472] = "damage", -- Arcane Discharge
    [29973] = "damage", -- Arcane Explosion
    [44644] = "damage", -- Arcane Nova
    [30616] = "damage", -- Blast Nova
    [15305] = "damage", -- Chain Lightning
    [45342] = "damage", -- Conflagration
    [46605] = "damage", -- Darkness of a Thousand Souls
    [31258] = "damage", -- Death & Decay
    [45737] = "damage", -- Flame Dart
    [30004] = "damage", -- Flame Wreath
    [44224] = "damage", -- Gravity Lapse
    [15785] = "damage", -- Mana Burn
    [38253] = "damage", -- Poison Bolt
    [36819] = "damage", -- Pyroblast
    [45248] = "damage", -- Shadow Blades
    [39005] = "damage", -- Shadow Nova
    [39193] = "damage", -- Shadow Power
    [46680] = "damage", -- Shadow Spike
    [38796] = "damage", -- Sonic Boom
    [41426] = "damage", -- Spirit Shock
    [29969] = "damage", -- Summon Blizzard
    [32424] = "damage", -- Summon Avatar
}

-- ============================================================================
-- INTERRUPT DECISION FUNCTION (current target)
-- ============================================================================

--- Determine whether the current target's cast should be interrupted.
--- @param context table  The rotation context object
--- @return string|false  "priority" for important casts, "normal" for filler, false for don't kick
function NS.should_interrupt(context)
    -- Basic cast detection (real-time, not cached on context)
    local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
    if not castLeft or castLeft <= 0 or notKickAble then return false end

    -- Dedup: don't kick a target that was just interrupted (by anyone)
    local target_guid = UnitGUID(TARGET_UNIT)
    if was_recently_interrupted(target_guid) then return false end

    -- TTD check — don't waste kick on dying target
    if context.ttd and context.ttd > 0 and context.ttd < 2 then return false end

    -- Unit classification scope
    local scope = context.settings.interrupt_scope or "all"
    local classification = UnitClassification(TARGET_UNIT) or "normal"
    local rank = CLASSIFICATION_RANK[classification] or 1
    local threshold = SCOPE_THRESHOLD[scope] or 0
    if rank < threshold then return false end

    -- Optional delay — don't kick too early
    local delay = context.settings.interrupt_delay or 0
    if delay > 0 then
        local _, castDuration = Unit(TARGET_UNIT):IsCastingRemains()
        local elapsed = (castDuration or 0) - (castLeft or 0)
        if elapsed < delay then return false end
    end

    -- Check priority database
    local _, _, castSpellID = Unit(TARGET_UNIT):IsCastingRemains()
    local category = NS.INTERRUPT_PRIORITY[castSpellID]
    if category then
        return "priority"
    end

    return "normal"
end

-- ============================================================================
-- PRIORITY CASTER NAMEPLATE SCANNER
-- Scans visible nameplates for enemies casting priority spells
-- Extracted from Shaman middleware — now available to all classes
-- ============================================================================

--- Scan nameplates for priority casters within range.
--- @param max_range number  Maximum range to consider (e.g. 20 for Earth Shock, 30 for Counterspell)
--- @return string|nil guid, number|nil castLeft, string|nil spellName  Best priority caster found
function NS.find_priority_caster(max_range)
    local best_guid = nil
    local best_cast_left = 0
    local best_spell_name = nil

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if _G.UnitExists(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
            local unit_guid = UnitGUID(unit)
            -- Skip recently interrupted targets (teammate or self already got it)
            if not was_recently_interrupted(unit_guid) then
                if Unit(unit):GetRange() <= max_range then
                    local castLeft, _, spellID, spellName, notKickAble = Unit(unit):IsCastingRemains()
                    if castLeft and castLeft > 0 and not notKickAble and spellID then
                        if NS.INTERRUPT_PRIORITY[spellID] then
                            -- Pick the caster with the most remaining cast time (easier to reach)
                            if castLeft > best_cast_left then
                                best_guid = unit_guid
                                best_cast_left = castLeft
                                best_spell_name = spellName
                            end
                        end
                    end
                end
            end
        end
    end

    return best_guid, best_cast_left, best_spell_name
end

-- ============================================================================
-- TAB-TARGET INTERRUPT STATE MACHINE
-- Extracted from Shaman — provides seek→interrupt→return flow for any class
-- Classes opt in via supports_tab_target = true in capability registration
-- ============================================================================

local SEEK_TIMEOUT = 1.0   -- seconds to tab toward priority caster
local RETURN_TIMEOUT = 1.0 -- seconds to tab back to original target

-- Per-class interrupt state tables (pre-allocated to avoid combat allocation)
local class_interrupt_states = {}

local function get_interrupt_state(class_name)
    if not class_interrupt_states[class_name] then
        class_interrupt_states[class_name] = {
            phase = "idle",           -- "idle" | "seeking" | "returning"
            original_guid = nil,      -- GUID of original target before tab
            target_guid = nil,        -- GUID of priority caster we're seeking
            spell_name = nil,         -- Name of spell being cast
            timeout = 0,             -- GetTime deadline for current phase
        }
    end
    return class_interrupt_states[class_name]
end

--- Check if tab-target interrupt should activate (called from matches).
--- Returns true if the class should enter the interrupt flow, false otherwise.
--- @param class_name string  The class using this
--- @param context table      Rotation context
--- @param interrupt_spell Action  The kick spell (for CD check)
--- @param max_range number   Max interrupt range
--- @return boolean
function NS.interrupt_tab_matches(class_name, context, interrupt_spell, max_range)
    if not context.in_combat then
        local state = get_interrupt_state(class_name)
        state.phase = "idle"
        return false
    end

    local state = get_interrupt_state(class_name)
    local now = GetTime()

    -- RETURNING phase: tabbing back to original target
    if state.phase == "returning" then
        if now > state.timeout then
            state.phase = "idle"
            return false
        end
        if not state.original_guid then
            state.phase = "idle"
            return false
        end
        -- Already back on original target
        if UnitGUID(TARGET_UNIT) == state.original_guid then
            state.phase = "idle"
            return false
        end
        -- Validate original target is still alive and attackable
        local original_valid = false
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if _G.UnitExists(unit) and UnitGUID(unit) == state.original_guid then
                if not _G.UnitIsDead(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
                    original_valid = true
                end
                break
            end
        end
        if not original_valid then
            state.phase = "idle"
            return false
        end
        return true
    end

    -- SEEKING phase: tabbing toward priority caster
    if state.phase == "seeking" then
        if now > state.timeout then
            state.phase = "returning"
            state.timeout = now + RETURN_TIMEOUT
            return true
        end
        return true
    end

    -- IDLE phase: scan for priority casters
    if not context.settings.use_priority_interrupt then return false end

    -- Check if our kick is off cooldown before scanning
    if interrupt_spell and interrupt_spell:GetCooldown() > 0 then return false end

    local caster_guid, _, spell_name = NS.find_priority_caster(max_range or 30)
    if caster_guid then
        local current_guid = UnitGUID(TARGET_UNIT)
        if caster_guid == current_guid then
            -- Priority caster IS current target — let normal interrupt handle it
            return false
        end
        -- Different unit → start seeking
        state.phase = "seeking"
        state.original_guid = current_guid
        state.target_guid = caster_guid
        state.spell_name = spell_name
        state.timeout = now + SEEK_TIMEOUT
        return true
    end

    return false
end

--- Execute tab-target interrupt flow (called from execute).
--- @param class_name string
--- @param icon any           TMW icon
--- @param context table
--- @param interrupt_spell Action  The kick spell to use
--- @return any result, string log
function NS.interrupt_tab_execute(class_name, icon, context, interrupt_spell)
    local state = get_interrupt_state(class_name)

    -- SEEKING: tab toward caster, or interrupt if we've arrived
    if state.phase == "seeking" then
        if UnitGUID(TARGET_UNIT) == state.target_guid then
            -- Landed on the caster — try to interrupt
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                if interrupt_spell:IsReady(TARGET_UNIT) then
                    state.phase = "returning"
                    state.timeout = GetTime() + RETURN_TIMEOUT
                    return interrupt_spell:Show(icon), ("[MW] PRIORITY Interrupt (" .. (state.spell_name or "?") .. ")")
                end
            end
            -- Can't interrupt → return to original
            state.phase = "returning"
            state.timeout = GetTime() + RETURN_TIMEOUT
        end
        -- Not on caster yet → tab
        return A:Show(icon, CONST.AUTOTARGET), ("[MW] Seeking " .. (state.spell_name or "?") .. " caster")
    end

    -- RETURNING: tab back toward original target
    if state.phase == "returning" then
        return A:Show(icon, CONST.AUTOTARGET), "[MW] Returning to original target"
    end

    return nil
end

-- ============================================================================
-- CAPABILITY REGISTRATION
-- ============================================================================

NS.interrupt_capabilities = {}

--- Register a class's interrupt capability.
--- @param class_name string
--- @param config table  { supports_tab_target, resolve_spell }
function NS.register_interrupt_capability(class_name, config)
    NS.interrupt_capabilities[class_name] = config
end
