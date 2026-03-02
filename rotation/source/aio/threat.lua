-- Flux AIO - Shared Threat Awareness Middleware
-- Monitors threat levels and takes configurable action (dump, stop DPS, or ignore)
-- Classes call NS.register_threat_middleware() from their middleware.lua

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Threat]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local format = string.format
local GetTime = _G.GetTime
local UnitClassification = _G.UnitClassification
local UnitGUID = _G.UnitGUID

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

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
    boss  = 3,    -- worldboss only
    elite = 2,    -- elite + worldboss
    all   = 0,    -- everything
}

local function target_meets_scope(scope)
    local classification = UnitClassification(TARGET_UNIT) or "normal"
    local rank = CLASSIFICATION_RANK[classification] or 1
    local threshold = SCOPE_THRESHOLD[scope] or 0
    return rank >= threshold
end

-- ============================================================================
-- NAMEPLATE ENEMY COUNTING
-- ============================================================================

-- Pre-allocated state to avoid combat table creation
local enemy_counts = { bosses = 0, elites = 0, trash = 0, total = 0 }

local function count_enemies_targeting_player()
    enemy_counts.bosses = 0
    enemy_counts.elites = 0
    enemy_counts.trash = 0
    enemy_counts.total = 0

    local player_guid = UnitGUID(PLAYER_UNIT)
    if not player_guid then return enemy_counts end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if _G.UnitExists(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
            local target_of = unit .. "target"
            if _G.UnitExists(target_of) and UnitGUID(target_of) == player_guid then
                local class = UnitClassification(unit) or "normal"
                if class == "worldboss" then
                    enemy_counts.bosses = enemy_counts.bosses + 1
                elseif class == "elite" or class == "rareelite" then
                    enemy_counts.elites = enemy_counts.elites + 1
                else
                    enemy_counts.trash = enemy_counts.trash + 1
                end
                enemy_counts.total = enemy_counts.total + 1
            end
        end
    end
    return enemy_counts
end

-- Export for use by other modules
NS.count_enemies_targeting_player = count_enemies_targeting_player

-- ============================================================================
-- THREAT MIDDLEWARE FACTORY
-- ============================================================================

--- Register threat awareness middleware for a DPS class.
--- @param class_name string  Class display name (e.g. "Rogue")
--- @param config table       Configuration:
---   dump_spell:       Action spell for threat dump (nil if class has no dump)
---   dump_ready_check: function(context) → bool, extra conditions (e.g. energy >= 20)
function NS.register_threat_middleware(class_name, config)
    if not config then return end

    local dump_spell = config.dump_spell
    local dump_ready_check = config.dump_ready_check

    rotation_registry:register_middleware({
        name = class_name .. "_ThreatAwareness",
        priority = Priority.MIDDLEWARE.DISPEL_CURSE,  -- 350
        is_defensive = true,

        matches = function(context)
            if not context.in_combat then return false end

            -- Check threat_mode setting
            local mode = context.settings.threat_mode or "dump"
            if mode == "off" then return false end

            -- Check TTD — don't waste dump on dying target
            if context.ttd and context.ttd > 0 and context.ttd < 3 then return false end

            -- Check unit classification scope
            local scope = context.settings.threat_scope or "elite"
            if not target_meets_scope(scope) then return false end

            -- Count enemies and populate context for downstream use
            local counts = count_enemies_targeting_player()
            context.threat_bosses = counts.bosses
            context.threat_elites = counts.elites
            context.threat_trash = counts.trash
            context.threat_total = counts.total

            -- Check if we actually have threat
            -- Use IsTanking as primary check (matches existing class behavior)
            local is_tanking = Unit(PLAYER_UNIT):IsTanking(TARGET_UNIT)
            if not is_tanking then return false end

            return true
        end,

        execute = function(icon, context)
            local mode = context.settings.threat_mode or "dump"

            -- Try threat dump first (if mode is "dump" and class has a dump spell)
            if mode == "dump" and dump_spell then
                local can_dump = true
                if dump_ready_check and not dump_ready_check(context) then
                    can_dump = false
                end
                if can_dump and dump_spell:IsReady(PLAYER_UNIT) then
                    return dump_spell:Show(icon), format("[MW] %s - Threat dump (targeting %d enemies)", class_name, context.threat_total or 0)
                end
            end

            -- Fallback: return nil to let rotation continue (dump on CD, can't stop)
            return nil
        end,
    })
end
