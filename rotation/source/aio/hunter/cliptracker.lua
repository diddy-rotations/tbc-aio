-- Hunter Auto Shot Clip Tracker (AIO)
-- Adapted from standalone Hunter_ClipTracker.lua
--
-- Tracks auto shot clipping: what caused each clip, how long it was,
-- and whether it was worth it. Integrates with the Action framework.

local _G, pairs, ipairs, string, tostring, format, table, math, wipe, select =
      _G, pairs, ipairs, string, tostring, string.format, table, math, _G.wipe, select

local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.DiddyAIO
if not NS then
    print("|cFFFF0000[Diddy AIO Hunter ClipTracker]|r Core module not loaded!")
    return
end

local Listener              = A.Listener
local GetTime               = _G.GetTime
local GetLatency            = A.GetLatency
local CreateFrame           = _G.CreateFrame
local UIParent              = _G.UIParent
local UnitRangedDamage      = _G.UnitRangedDamage
local UnitGUID              = _G.UnitGUID
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local date                  = _G.date
local print                 = _G.print
local GetSpellInfo          = _G.GetSpellInfo

-- Melee-only spells that prove the player was in melee range
local MeleeSpellNames = {
    ["Raptor Strike"] = true,
    ["Mongoose Bite"] = true,
    ["Wing Clip"] = true,
    ["Counterattack"] = true,
}

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local ClipTracker = {
    -- Timing state
    LastAutoShotTime = nil,
    LastExpectedSpeed = nil,
    IsFirstShot = true,

    -- Cast tracking
    CurrentCastSpell = nil,
    CurrentCastStartTime = nil,

    -- Rotation suggestion tracking
    LastSuggestion = nil,
    LastSuggestionTime = nil,
    LastSuggestionSwing = nil,

    -- Melee/movement interval tracking (between auto shots)
    WasInMeleeInterval = false,
    WasMovingInInterval = false,
    MeleeSpellsDuringInterval = {},
    MoveStartTime = nil,
    IsCurrentlyMoving = false,

    -- Log buffer
    ClipLog = {},
    ClipLogMax = 5000,

    -- Combat session stats
    CombatStats = {
        totalClips = 0,
        totalClipTime = 0,
        worstClip = 0,
        worstClipCause = "",
        clipsBySpell = {},
        clipsBySeverity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        autoShotCount = 0,
        combatStartTime = 0,
    },

    -- UI state
    IsVisible = false,
    IsPaused = false,
    Frame = nil,
    ScrollFrame = nil,
    LogText = nil,

    -- Severity filter state
    SeverityEnabled = {
        GREEN = true,
        YELLOW = true,
        ORANGE = true,
        RED = true,
    },

    -- Severity colors
    SeverityColors = {
        GREEN  = { 0, 1, 0 },
        YELLOW = { 1, 1, 0 },
        ORANGE = { 1, 0.54, 0 },
        RED    = { 1, 0, 0 },
    },

    -- Spells that are always worth clipping for (by spellID)
    AlwaysWorthSpells = {
        [34026] = true,  -- Kill Command
        [19574] = true,  -- Bestial Wrath
        [3045]  = true,  -- Rapid Fire
        [19577] = true,  -- Intimidation
        [136]   = true,  -- Mend Pet (base ID)
    },
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function GetTimestamp()
    local gameTime = GetTime()
    local ms = format("%.2f", gameTime % 1)
    return format("%s.%s", date("%H:%M:%S"), ms:sub(3))
end

local function GetSeverity(delay)
    local s = NS.cached_settings
    local t1 = (s.clip_threshold_1 or 125) / 1000
    local t2 = (s.clip_threshold_2 or 250) / 1000
    local t3 = (s.clip_threshold_3 or 500) / 1000
    if delay <= t1 then return "GREEN"
    elseif delay <= t2 then return "YELLOW"
    elseif delay <= t3 then return "ORANGE"
    else return "RED"
    end
end

local function GetSpellCastTime(spellName)
    if not spellName then return 0 end
    local name, _, _, castTime = GetSpellInfo(spellName)
    if castTime and castTime > 0 then return castTime / 1000 end
    return 0
end

local function EvaluateWorth(clipDuration, causeSpell, wasMoving)
    if wasMoving and (not causeSpell or causeSpell == "Movement") then
        return "NECESSARY"
    end

    -- Melee interlude: can't auto shot while in melee range
    if causeSpell and causeSpell:find("^Melee") then
        return "NECESSARY"
    end

    local latency = GetLatency() or 0.05
    if clipDuration <= latency then
        return "TRIVIAL"
    end

    if causeSpell and causeSpell ~= "Unknown" and causeSpell ~= "Movement" then
        -- Check always-worth spells by name lookup
        local alwaysWorth = {
            ["Kill Command"] = true,
            ["Bestial Wrath"] = true,
            ["Rapid Fire"] = true,
            ["Intimidation"] = true,
            ["Mend Pet"] = true,
        }
        if alwaysWorth[causeSpell] then
            return "WORTH_IT"
        end

        local castTime = GetSpellCastTime(causeSpell)
        if castTime <= 0 then
            -- Instant cast spell with significant clip
            if clipDuration > 0.2 then
                return "NOT_WORTH"
            else
                return "TRIVIAL"
            end
        end

        -- Overhead ratio: clip time as fraction of cast time
        local ratio = clipDuration / castTime
        if ratio < 0.15 then
            return "WORTH_IT"
        elseif ratio < 0.30 then
            return "MARGINAL"
        else
            return "NOT_WORTH"
        end
    end

    return "UNKNOWN"
end

-- ============================================================================
-- CORE CLIP DETECTION
-- ============================================================================

function ClipTracker:IsEnabled()
    return NS.cached_settings.clip_tracker_enabled or false
end

function ClipTracker:ResetCombatStats()
    self.CombatStats = {
        totalClips = 0,
        totalClipTime = 0,
        worstClip = 0,
        worstClipCause = "",
        clipsBySpell = {},
        clipsBySeverity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        autoShotCount = 0,
        combatStartTime = GetTime(),
    }
    self.IsFirstShot = true
    self.LastAutoShotTime = nil
    self.LastExpectedSpeed = nil
    self.CurrentCastSpell = nil
    self.CurrentCastStartTime = nil
    self.LastSuggestion = nil
    self.LastSuggestionTime = nil
    self.LastSuggestionSwing = nil
    self:ResetIntervalState()
end

function ClipTracker:ResetIntervalState()
    self.WasInMeleeInterval = false
    self.WasMovingInInterval = false
    wipe(self.MeleeSpellsDuringInterval)
    -- Don't reset MoveStartTime/IsCurrentlyMoving here — those track live state across intervals
end

function ClipTracker:OnAutoShotFired()
    if not self:IsEnabled() then return end

    local now = GetTime()
    self.CombatStats.autoShotCount = self.CombatStats.autoShotCount + 1

    if self.IsFirstShot or not self.LastAutoShotTime or not self.LastExpectedSpeed then
        self.LastAutoShotTime = now
        self.LastExpectedSpeed = UnitRangedDamage("player") or 3.0
        self.IsFirstShot = false
        self:ResetIntervalState()
        return
    end

    local elapsed = now - self.LastAutoShotTime
    local delay = elapsed - self.LastExpectedSpeed

    -- Discard unreasonable values (target swap, death, etc.)
    if delay > 10 or delay < -1 then
        self.LastAutoShotTime = now
        self.LastExpectedSpeed = UnitRangedDamage("player") or 3.0
        self:ResetIntervalState()
        return
    end

    -- Record speed at this shot for next comparison
    local prevSpeed = self.LastExpectedSpeed
    self.LastAutoShotTime = now
    self.LastExpectedSpeed = UnitRangedDamage("player") or 3.0

    -- Only record clips above threshold
    if delay <= 0.01 then
        self:ResetIntervalState()
        return
    end

    -- Determine cause (priority: melee > cast-bar spell > movement > instant cast > unknown)
    local causeSpell = nil
    local causeCastTime = 0
    local hadMelee = #self.MeleeSpellsDuringInterval > 0

    -- Priority 1: Melee spells were cast during interval → player was in melee, auto shot blocked
    if hadMelee or self.WasInMeleeInterval then
        if hadMelee then
            causeSpell = "Melee (" .. self.MeleeSpellsDuringInterval[1].name .. ")"
        else
            causeSpell = "Melee"
        end
        causeCastTime = 0
    end

    -- Priority 2: Cast-bar spell (Steady Shot, etc.)
    if not causeSpell and self.CurrentCastSpell and self.CurrentCastStartTime then
        local castAge = now - self.CurrentCastStartTime
        if castAge < 5 then
            causeSpell = self.CurrentCastSpell
            causeCastTime = GetSpellCastTime(self.CurrentCastSpell)
        end
    end

    -- Priority 3: Movement during interval (auto shot can't fire while moving)
    -- Only counts if sustained movement (>= 0.25s) overlapped the expected fire time
    local wasMoving = false
    if self.WasMovingInInterval then
        wasMoving = true
    elseif self.IsCurrentlyMoving and self.MoveStartTime and (now - self.MoveStartTime) >= 0.25 then
        wasMoving = true
    end

    if not causeSpell and wasMoving then
        causeSpell = "Movement"
        causeCastTime = 0
    end

    -- Priority 4: Framework's last cast (instant spells like Arcane Shot)
    if not causeSpell and A.LastPlayerCastName then
        causeSpell = A.LastPlayerCastName
        causeCastTime = GetSpellCastTime(causeSpell)
    end

    if wasMoving and not causeSpell then
        causeSpell = "Movement"
        causeCastTime = 0
    end

    if not causeSpell then
        causeSpell = "Unknown"
    end

    local severity = GetSeverity(delay)
    local verdict = EvaluateWorth(delay, causeSpell, wasMoving)

    -- Record clip event
    local entry = {
        timestamp = GetTimestamp(),
        rawTime = now,
        clipDuration = delay,
        expectedSpeed = prevSpeed,
        actualInterval = elapsed,
        causeSpell = causeSpell,
        causeCastTime = causeCastTime,
        severity = severity,
        wasMoving = wasMoving,
        verdict = verdict,
    }

    table.insert(self.ClipLog, entry)
    while #self.ClipLog > self.ClipLogMax do
        table.remove(self.ClipLog, 1)
    end

    -- Update stats
    local stats = self.CombatStats
    stats.totalClips = stats.totalClips + 1
    stats.totalClipTime = stats.totalClipTime + delay
    stats.clipsBySeverity[severity] = (stats.clipsBySeverity[severity] or 0) + 1

    if delay > stats.worstClip then
        stats.worstClip = delay
        stats.worstClipCause = causeSpell
    end

    if not stats.clipsBySpell[causeSpell] then
        stats.clipsBySpell[causeSpell] = { count = 0, totalTime = 0 }
    end
    stats.clipsBySpell[causeSpell].count = stats.clipsBySpell[causeSpell].count + 1
    stats.clipsBySpell[causeSpell].totalTime = stats.clipsBySpell[causeSpell].totalTime + delay

    -- Update display
    if self.IsVisible and self.Frame and self.Frame:IsShown() then
        self:RefreshLogDisplay()
        self:UpdateStatsStrip()
    end

    -- Reset interval tracking for next auto shot
    self:ResetIntervalState()
end

function ClipTracker:RecordSuggestion(spellName, swingTimer)
    if not self:IsEnabled() then return end
    self.LastSuggestion = spellName
    self.LastSuggestionTime = GetTime()
    self.LastSuggestionSwing = swingTimer
end

-- ============================================================================
-- COMBAT SUMMARY
-- ============================================================================

function ClipTracker:PrintCombatSummary()
    if not self:IsEnabled() then return end
    if not NS.cached_settings.clip_print_summary then return end

    local stats = self.CombatStats
    if stats.autoShotCount == 0 then return end

    local combatDuration = GetTime() - stats.combatStartTime
    if combatDuration < 3 then return end

    local clipRate = stats.totalClips > 0 and (stats.totalClips / stats.autoShotCount * 100) or 0
    local avgPerShot = stats.totalClipTime / stats.autoShotCount
    local avgPerClip = stats.totalClips > 0 and (stats.totalClipTime / stats.totalClips) or 0

    print(format("|cffFF8000[ClipTracker]|r Combat Summary (%.1fs)", combatDuration))
    print(format("  Auto Shots: %d | Clips: %d (%.1f%%) | Total Clip Time: %.2fs",
        stats.autoShotCount, stats.totalClips, clipRate, stats.totalClipTime))
    print(format("  Avg Clip/Shot: %.3fs | Avg Clip (clipped only): %.3fs | Worst: %.3fs (%s)",
        avgPerShot, avgPerClip, stats.worstClip, stats.worstClipCause ~= "" and stats.worstClipCause or "N/A"))
    print(format("  Green: %d | Yellow: %d | Orange: %d | Red: %d",
        stats.clipsBySeverity.GREEN or 0, stats.clipsBySeverity.YELLOW or 0,
        stats.clipsBySeverity.ORANGE or 0, stats.clipsBySeverity.RED or 0))

    -- Clips by cause
    local causes = {}
    for spell, data in pairs(stats.clipsBySpell) do
        table.insert(causes, { spell = spell, count = data.count, totalTime = data.totalTime })
    end
    if #causes > 0 then
        table.sort(causes, function(a, b) return a.totalTime > b.totalTime end)
        print("  Clips by cause:")
        for _, c in ipairs(causes) do
            local avg = c.count > 0 and (c.totalTime / c.count) or 0
            print(format("    %s: %dx (%.2fs total, %.3fs avg)", c.spell, c.count, c.totalTime, avg))
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local pGUID = nil

local function OnCLEU()
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if not pGUID then pGUID = UnitGUID("player") end
    if sourceGUID ~= pGUID then return end

    if subevent == "SPELL_CAST_SUCCESS" then
        if spellID == 75 then
            -- Auto Shot fired
            ClipTracker:OnAutoShotFired()
        elseif spellName and MeleeSpellNames[spellName] then
            -- Melee spell cast → proves we were in melee range
            table.insert(ClipTracker.MeleeSpellsDuringInterval, {
                name = spellName,
                time = GetTime(),
            })
            ClipTracker.WasInMeleeInterval = true
        end
    elseif subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
        -- Melee auto-attack → proves we were in melee range
        ClipTracker.WasInMeleeInterval = true
    end
end

local function OnSpellcastStart(_, unit, _, spellID)
    if unit ~= "player" then return end
    if not ClipTracker:IsEnabled() then return end
    local spellName = GetSpellInfo(spellID)
    if spellName then
        ClipTracker.CurrentCastSpell = spellName
        ClipTracker.CurrentCastStartTime = GetTime()
    end
end

local function OnCombatStart()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker:ResetCombatStats()
end

local function OnCombatEnd()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker:PrintCombatSummary()
end

-- Movement tracking via start/stop events with duration filter
local function OnStartMoving()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker.MoveStartTime = GetTime()
    ClipTracker.IsCurrentlyMoving = true
end

local function OnStopMoving()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker.IsCurrentlyMoving = false
    -- Only flag as real movement if we moved for >= 0.25s (filters turning, micro-adjustments)
    if ClipTracker.MoveStartTime and (GetTime() - ClipTracker.MoveStartTime) >= 0.25 then
        ClipTracker.WasMovingInInterval = true
    end
    ClipTracker.MoveStartTime = nil
end

-- Register events via Action Listener
Listener:Add("CLIPTRACKER_CLEU", "COMBAT_LOG_EVENT_UNFILTERED", OnCLEU)
Listener:Add("CLIPTRACKER_CAST", "UNIT_SPELLCAST_START", OnSpellcastStart)
Listener:Add("CLIPTRACKER_COMBAT_START", "PLAYER_REGEN_DISABLED", OnCombatStart)
Listener:Add("CLIPTRACKER_COMBAT_END", "PLAYER_REGEN_ENABLED", OnCombatEnd)
Listener:Add("CLIPTRACKER_MOVE_START", "PLAYER_STARTED_MOVING", OnStartMoving)
Listener:Add("CLIPTRACKER_MOVE_STOP", "PLAYER_STOPPED_MOVING", OnStopMoving)

-- ============================================================================
-- UI CREATION
-- ============================================================================

function ClipTracker:CreateFrame()
    if self.Frame then return self.Frame end

    local f = CreateFrame("Frame", "HunterClipTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(550, 450)
    f:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:Hide()

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -5)
    f.title:SetText("Auto Shot Clip Tracker")

    -- Severity filter buttons
    local severities = { "GREEN", "YELLOW", "ORANGE", "RED" }
    local sevNames = { GREEN = "Green", YELLOW = "Yellow", ORANGE = "Orange", RED = "Red" }
    f.filterButtons = {}
    local btnWidth = 60

    for i, sev in ipairs(severities) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, 20)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * (btnWidth + 5), -25)
        btn:SetText(sevNames[sev])

        local color = self.SeverityColors[sev]
        btn:GetFontString():SetTextColor(color[1], color[2], color[3])

        btn.severity = sev
        btn.enabled = true

        btn:SetScript("OnClick", function(self)
            self.enabled = not self.enabled
            ClipTracker.SeverityEnabled[self.severity] = self.enabled
            if self.enabled then
                self:SetAlpha(1.0)
            else
                self:SetAlpha(0.4)
            end
            ClipTracker:RefreshLogDisplay()
        end)

        f.filterButtons[sev] = btn
    end

    -- Live stats strip
    f.statsStrip = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.statsStrip:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -48)
    f.statsStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -48)
    f.statsStrip:SetJustifyH("LEFT")
    f.statsStrip:SetText("Clips: 0 | Avg/Shot: 0.000s | Total: 0.00s | Rate: 0.0% | Worst: 0.000s")

    -- Scroll frame for logs
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -65)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 45)

    -- Log text
    local logText = CreateFrame("EditBox", nil, sf)
    logText:SetMultiLine(true)
    logText:SetFontObject("GameFontHighlightSmall")
    logText:SetWidth(sf:GetWidth() - 20)
    logText:SetAutoFocus(false)
    logText:EnableMouse(true)
    logText:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(logText)

    self.ScrollFrame = sf
    self.LogText = logText

    -- Bottom buttons: Pause
    local pauseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pauseBtn:SetSize(60, 22)
    pauseBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    pauseBtn:SetText("Pause")
    pauseBtn:SetScript("OnClick", function(self)
        ClipTracker.IsPaused = not ClipTracker.IsPaused
        if ClipTracker.IsPaused then
            self:SetText("Resume")
        else
            self:SetText("Pause")
        end
    end)
    f.pauseBtn = pauseBtn

    -- Clear
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(55, 22)
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 5, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        wipe(ClipTracker.ClipLog)
        ClipTracker:ResetCombatStats()
        ClipTracker:RefreshLogDisplay()
        ClipTracker:UpdateStatsStrip()
    end)

    -- Export
    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(60, 22)
    exportBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        ClipTracker:ShowExportWindow()
    end)

    -- Log count
    f.logCount = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.logCount:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 15)
    f.logCount:SetText("0 clips")

    self.Frame = f
    return f
end

-- ============================================================================
-- DISPLAY REFRESH
-- ============================================================================

function ClipTracker:UpdateStatsStrip()
    if not self.Frame or not self.Frame.statsStrip then return end

    local stats = self.CombatStats
    local clipRate = stats.autoShotCount > 0 and (stats.totalClips / stats.autoShotCount * 100) or 0
    local avgPerShot = stats.autoShotCount > 0 and (stats.totalClipTime / stats.autoShotCount) or 0
    local worstCause = stats.worstClipCause ~= "" and stats.worstClipCause or "N/A"

    self.Frame.statsStrip:SetText(format(
        "Clips: %d | Avg/Shot: %.3fs | Total: %.2fs | Rate: %.1f%% | Worst: %.3fs (%s)",
        stats.totalClips, avgPerShot, stats.totalClipTime, clipRate, stats.worstClip, worstCause))
end

function ClipTracker:RefreshLogDisplay()
    if not self.LogText then return end

    local lines = {}
    for _, entry in ipairs(self.ClipLog) do
        if self.SeverityEnabled[entry.severity] then
            local color = self.SeverityColors[entry.severity]
            local colorHex = format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)

            local causeDetail = entry.causeSpell
            if entry.causeCastTime and entry.causeCastTime > 0 then
                causeDetail = format("%s (%.2fs cast)", entry.causeSpell, entry.causeCastTime)
            end

            local line = format("%s[%s] [%s] +%.3fs clip | %s | %s|r",
                colorHex, entry.timestamp, entry.severity, entry.clipDuration,
                causeDetail, entry.verdict)
            table.insert(lines, line)
        end
    end

    self.LogText:SetText(table.concat(lines, "\n"))

    -- Update count
    if self.Frame and self.Frame.logCount then
        self.Frame.logCount:SetText(#self.ClipLog .. " clips")
    end

    -- Auto-scroll to bottom
    if self.ScrollFrame then
        C_Timer.After(0.01, function()
            if self.ScrollFrame then
                self.ScrollFrame:SetVerticalScroll(self.ScrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

-- ============================================================================
-- EXPORT WINDOW
-- ============================================================================

function ClipTracker:GetCSVExport()
    local lines = {}
    -- CSV header
    table.insert(lines, "timestamp,clip_duration,expected_speed,actual_interval,cause_spell,cause_cast_time,severity,was_moving,verdict")

    for _, entry in ipairs(self.ClipLog) do
        table.insert(lines, format("%s,%.4f,%.4f,%.4f,%s,%.4f,%s,%s,%s",
            entry.timestamp, entry.clipDuration, entry.expectedSpeed, entry.actualInterval,
            entry.causeSpell, entry.causeCastTime or 0, entry.severity,
            tostring(entry.wasMoving), entry.verdict))
    end

    -- Append summary block
    local stats = self.CombatStats
    if stats.autoShotCount > 0 then
        local combatDuration = GetTime() - stats.combatStartTime
        local clipRate = stats.totalClips / stats.autoShotCount * 100
        local avgPerShot = stats.totalClipTime / stats.autoShotCount
        local avgPerClip = stats.totalClips > 0 and (stats.totalClipTime / stats.totalClips) or 0

        table.insert(lines, "")
        table.insert(lines, "--- COMBAT SUMMARY ---")
        table.insert(lines, format("Combat Duration: %.1fs", combatDuration))
        table.insert(lines, format("Auto Shots: %d", stats.autoShotCount))
        table.insert(lines, format("Clips: %d (%.1f%%)", stats.totalClips, clipRate))
        table.insert(lines, format("Total Clip Time: %.3fs", stats.totalClipTime))
        table.insert(lines, format("Avg Clip/Shot: %.4fs", avgPerShot))
        table.insert(lines, format("Avg Clip (clipped only): %.4fs", avgPerClip))
        table.insert(lines, format("Worst Clip: %.4fs (%s)", stats.worstClip, stats.worstClipCause))
        table.insert(lines, format("Green: %d | Yellow: %d | Orange: %d | Red: %d",
            stats.clipsBySeverity.GREEN or 0, stats.clipsBySeverity.YELLOW or 0,
            stats.clipsBySeverity.ORANGE or 0, stats.clipsBySeverity.RED or 0))

        for spell, data in pairs(stats.clipsBySpell) do
            local avg = data.count > 0 and (data.totalTime / data.count) or 0
            table.insert(lines, format("  %s: %dx (%.3fs total, %.4fs avg)", spell, data.count, data.totalTime, avg))
        end
    end

    return table.concat(lines, "\n")
end

function ClipTracker:ShowExportWindow()
    local text = self:GetCSVExport()
    if text == "" then
        text = "-- No clip data to export --"
    end

    local f = _G["HunterClipTrackerExportFrame"]
    if not f then
        f = CreateFrame("Frame", "HunterClipTrackerExportFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", f, "TOP", 0, -5)
        f.title:SetText("Export Clip Data - Select All (Ctrl+A) & Copy (Ctrl+C)")

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -30)
        sf:SetPoint("BOTTOMRIGHT", -30, 40)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(540)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.editBox = eb

        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(100, 25)
        btn:SetPoint("BOTTOM", 0, 10)
        btn:SetText("Close")
        btn:SetScript("OnClick", function() f:Hide() end)
    end

    f.editBox:SetText(text)
    f.editBox:HighlightText()
    f.editBox:SetFocus()
    f:Show()
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function ClipTracker:Show()
    if not self.Frame then
        self:CreateFrame()
    end
    self.Frame:Show()
    self.IsVisible = true
    self:RefreshLogDisplay()
    self:UpdateStatsStrip()
end

function ClipTracker:Hide()
    if self.Frame then
        self.Frame:Hide()
    end
    self.IsVisible = false
end

function ClipTracker:Toggle()
    if not self.Frame then
        self:CreateFrame()
    end
    if self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- AUTO SHOW/HIDE FROM TOGGLE
-- ============================================================================

local lastToggleState = nil
local function CheckToggleState()
    local showTracker = NS.cached_settings.show_clip_tracker or false
    if showTracker ~= lastToggleState then
        lastToggleState = showTracker
        if showTracker then
            ClipTracker:Show()
        else
            ClipTracker:Hide()
        end
    end
end

local watchFrame = CreateFrame("Frame")
watchFrame.elapsed = 0
watchFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        CheckToggleState()
    end
end)

-- ============================================================================
-- NAMESPACE REGISTRATION
-- ============================================================================

NS.HunterClipTracker = ClipTracker

print("|cFF00FF00[Diddy AIO Hunter]|r Clip Tracker loaded")
