-- Flux AIO - Combat Dashboard
-- Shared, data-driven dashboard — classes register configs, this module renders.
-- Toggle via "Show Dashboard" setting or /flux status

local _G = _G
local format = string.format
local floor = math.floor
local tostring = tostring
local select = select
local math_min = math.min
local math_max = math.max
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local GameTooltip_Hide = _G.GameTooltip_Hide
local GetSpellTexture = _G.GetSpellTexture
local GetSpellInfo = _G.GetSpellInfo
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local UnitName = _G.UnitName
local UnitDetailedThreatSituation = _G.UnitDetailedThreatSituation

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Dashboard]|r Core module not loaded!")
    return
end

local Unit = NS.Unit
local Player = NS.Player
local rotation_registry = NS.rotation_registry

-- Last action state (updated by main.lua via set_last_action)
local last_action = { name = nil, source = nil }

function NS.set_last_action(name, source)
    last_action.name = name
    last_action.source = source
end

-- ============================================================================
-- THEME
-- ============================================================================
local THEME = {
    bg          = { 0.031, 0.031, 0.039, 0.92 },
    bg_light    = { 0.047, 0.047, 0.059, 0.7 },
    border      = { 0.118, 0.118, 0.149, 1 },
    accent      = { 0.424, 0.388, 1.0, 1 },
    text        = { 0.863, 0.863, 0.894, 1 },
    text_dim    = { 0.580, 0.580, 0.659, 1 },
}

local BACKDROP_THIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================
local MAX_COOLDOWNS = 8
local MAX_BUFFS = 6
local MAX_DEBUFFS = 6
local MAX_CUSTOM_LINES = 6
local UPDATE_INTERVAL = 0.1
local TOGGLE_CHECK_INTERVAL = 0.5

local FRAME_WIDTH = 210
local ICON_SIZE = 28
local ICON_GAP = 3
local ICON_STEP = ICON_SIZE + ICON_GAP   -- 31px per icon cell
local ICONS_PER_ROW = 6
local ICON_X = 12             -- left padding for icon grid
local MAX_TIMER_BARS = 3
local TIMER_BAR_HEIGHT = 10

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local RESOURCE_COLORS = {
    rage   = { 0.78, 0.25, 0.25 },
    energy = { 1.0, 1.0, 0.0 },
    mana   = { 0.24, 0.51, 0.90 },
}

local CLASS_HEX = {
    Druid = "ff7d0a", Hunter = "abd473", Mage = "69ccf0", Paladin = "f58cba",
    Priest = "ffffff", Rogue = "fff569", Shaman = "0070dd", Warlock = "9482c9",
    Warrior = "c79c6e",
}

-- ============================================================================
-- ICON HELPERS
-- ============================================================================

local function get_action_icon(spell)
    -- Framework trinkets (TrinketBySlot) store inventory slot in SlotID
    if spell.SlotID then
        local inv = GetInventoryItemTexture("player", spell.SlotID)
        if inv then return inv end
    end
    -- Direct slot IDs (13/14) or item IDs
    local inv = GetInventoryItemTexture("player", spell.ID)
    if inv then return inv end
    return GetSpellTexture(spell.ID) or ICON_FALLBACK
end

local function get_buff_icon(id)
    local spell_id = type(id) == "table" and id[1] or id
    if not spell_id then return ICON_FALLBACK end
    return select(3, GetSpellInfo(spell_id)) or ICON_FALLBACK
end

local function format_timer(seconds)
    if seconds > 60 then
        return format("%dm", floor(seconds / 60))
    end
    return format("%d", floor(seconds))
end

--- Resolve a config that may be flat (array/table) or per-playstyle keyed
local function resolve_list(cfg, playstyle)
    if not cfg then return nil end
    if #cfg > 0 then return cfg end                    -- flat array
    if playstyle and cfg[playstyle] then return cfg[playstyle] end
    return nil
end

--- Resolve a single config object (has .type key) or per-playstyle lookup
local function resolve_config(cfg, playstyle)
    if not cfg then return nil end
    if cfg.type then return cfg end                    -- direct config
    if playstyle and cfg[playstyle] then return cfg[playstyle] end
    return nil
end

--- Create a reusable icon slot (pre-allocated at load time)
local function create_icon_slot(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:EnableMouse(true)

    -- Border (subtle dark, 1px)
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Spell icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Dark tint overlay
    local tint = f:CreateTexture(nil, "OVERLAY", nil, 1)
    tint:SetAllPoints()
    tint:SetColorTexture(0, 0, 0, 0.6)
    tint:Hide()

    -- Timer/status text (centered, large outline font)
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:Hide()

    -- Tooltip on hover
    f:SetScript("OnEnter", function(self)
        if self.slot_id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", self.slot_id)
            GameTooltip:Show()
        elseif self.spell_id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spell_id)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    f:Hide()

    return { frame = f, icon = icon, border = border, tint = tint, text = text }
end

-- ============================================================================
-- STATE
-- ============================================================================
local dashboard_frame = nil
local cd_slots = {}
local buff_slots = {}
local debuff_slots = {}
local custom_lines = {}
local priority_text = nil
local resource_bar = nil
local resource_text = nil
local resource_bg2 = nil
local resource_bar2 = nil
local resource_text2 = nil
local header_text = nil
local sep2_tex = nil
local playstyle_line_fs = nil
local playstyle_sep = nil
local cd_label_fs = nil
local buff_label_fs = nil
local debuff_label_fs = nil
local target_info_fs = nil
local timer_bars = {}
local last_class_name = nil

local dash_context = { settings = nil }

-- ============================================================================
-- FRAME CREATION
-- ============================================================================
local function create_dashboard()
    if dashboard_frame then return dashboard_frame end

    -- Aggressively clean up stale frame from previous /reload
    local stale = _G["FluxAIODashboard"]
    if stale then
        stale:Hide()
        stale:SetAlpha(0)
        -- Hide all child regions (fontstrings, textures) that may ghost-render
        local regions = { stale:GetRegions() }
        for _, r in pairs(regions) do r:Hide() end
        local children = { stale:GetChildren() }
        for _, c in pairs(children) do
            c:Hide()
            c:SetAlpha(0)
            -- Hide grandchildren (fontstrings parented to sub-frames like bar_bg)
            local sub = { c:GetRegions() }
            for _, s in pairs(sub) do s:Hide() end
        end
        stale:ClearAllPoints()
        stale:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
    end

    local f = CreateFrame("Frame", "FluxAIODashboard", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, 300)
    f:SetBackdrop(BACKDROP_THIN)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
    f:SetBackdropBorderColor(0, 0, 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
    end)
    f:SetFrameStrata("HIGH")
    f:Hide()

    if not f:IsUserPlaced() then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    end

    local y = -6

    -- Header (class name only, playstyle shown at bottom)
    header_text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header_text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    header_text:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -4)
    local close_txt = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    close_txt:SetPoint("CENTER")
    close_txt:SetText("x")
    close_txt:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() close_txt:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() close_txt:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]) end)

    y = y - 18

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, y)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, y)
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    y = y - 4

    -- Resource bar (wider for new frame width)
    local bar_bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bar_bg:SetSize(FRAME_WIDTH - 20, 16)
    bar_bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    bar_bg:SetBackdrop(BACKDROP_THIN)
    bar_bg:SetBackdropColor(0, 0, 0, 0.6)
    bar_bg:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)

    resource_bar = bar_bg:CreateTexture(nil, "ARTWORK")
    resource_bar:SetPoint("TOPLEFT", 1, -1)
    resource_bar:SetHeight(14)
    resource_bar:SetTexture("Interface\\Buttons\\WHITE8X8")

    resource_text = bar_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resource_text:SetPoint("CENTER", bar_bg)
    resource_text:SetTextColor(1, 1, 1)
    y = y - 22

    -- Secondary resource bar (positioned dynamically in update)
    resource_bg2 = CreateFrame("Frame", nil, f, "BackdropTemplate")
    resource_bg2:SetSize(FRAME_WIDTH - 20, 16)
    resource_bg2:SetBackdrop(BACKDROP_THIN)
    resource_bg2:SetBackdropColor(0, 0, 0, 0.6)
    resource_bg2:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)
    resource_bg2:Hide()

    resource_bar2 = resource_bg2:CreateTexture(nil, "ARTWORK")
    resource_bar2:SetPoint("TOPLEFT", 1, -1)
    resource_bar2:SetHeight(14)
    resource_bar2:SetTexture("Interface\\Buttons\\WHITE8X8")

    resource_text2 = resource_bg2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resource_text2:SetPoint("CENTER", resource_bg2)
    resource_text2:SetTextColor(1, 1, 1)
    -- Don't advance y — positioned dynamically in update

    -- Timer bars (GCD + class timers, thin progress bars)
    for i = 1, MAX_TIMER_BARS do
        local tbg = CreateFrame("Frame", nil, f, "BackdropTemplate")
        tbg:SetSize(FRAME_WIDTH - 20, TIMER_BAR_HEIGHT)
        tbg:SetBackdrop(BACKDROP_THIN)
        tbg:SetBackdropColor(0, 0, 0, 0.4)
        tbg:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.3)
        tbg:Hide()

        local tbar = tbg:CreateTexture(nil, "ARTWORK")
        tbar:SetPoint("TOPLEFT", 1, -1)
        tbar:SetHeight(TIMER_BAR_HEIGHT - 2)
        tbar:SetTexture("Interface\\Buttons\\WHITE8X8")

        local tlabel = tbg:CreateFontString(nil, "OVERLAY")
        tlabel:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        tlabel:SetPoint("LEFT", tbg, "LEFT", 3, 0)
        tlabel:SetTextColor(1, 1, 1, 0.9)

        local tvalue = tbg:CreateFontString(nil, "OVERLAY")
        tvalue:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        tvalue:SetPoint("RIGHT", tbg, "RIGHT", -3, 0)
        tvalue:SetTextColor(1, 1, 1, 0.9)

        timer_bars[i] = { bg = tbg, bar = tbar, label = tlabel, value = tvalue }
    end

    -- Current Priority (inline label + value, positioned dynamically)
    priority_text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    priority_text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    priority_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y)
    priority_text:SetJustifyH("LEFT")
    priority_text:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    y = y - 16

    -- Target info (label + name + stats on separate lines, positioned dynamically)
    target_info_fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    target_info_fs:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    target_info_fs:SetJustifyH("LEFT")
    target_info_fs:SetSpacing(4)

    -- Separator (positioned dynamically in update)
    sep2_tex = f:CreateTexture(nil, "ARTWORK")
    sep2_tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, y)
    sep2_tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, y)
    sep2_tex:SetHeight(1)
    sep2_tex:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)
    y = y - 4

    -- Section labels (accent-colored, no background panels)
    cd_label_fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cd_label_fs:SetText("Cooldowns")
    cd_label_fs:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)

    buff_label_fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buff_label_fs:SetText("Buffs")
    buff_label_fs:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)

    debuff_label_fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debuff_label_fs:SetText("Debuffs")
    debuff_label_fs:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)

    -- Playstyle/Form line (shown at bottom with separator)
    playstyle_sep = f:CreateTexture(nil, "ARTWORK")
    playstyle_sep:SetHeight(1)
    playstyle_sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)

    playstyle_line_fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    playstyle_line_fs:SetJustifyH("LEFT")
    playstyle_line_fs:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])

    -- Pre-allocate all icon slots
    for i = 1, MAX_COOLDOWNS do
        cd_slots[i] = create_icon_slot(f)
    end
    for i = 1, MAX_BUFFS do
        buff_slots[i] = create_icon_slot(f)
    end
    for i = 1, MAX_DEBUFFS do
        debuff_slots[i] = create_icon_slot(f)
    end

    -- Custom lines (text-based)
    for i = 1, MAX_CUSTOM_LINES do
        local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 14, 0)
        line:SetWidth(FRAME_WIDTH - 28)
        line:SetJustifyH("LEFT")
        line:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
        line:Hide()
        custom_lines[i] = line
    end

    dashboard_frame = f
    return f
end

-- ============================================================================
-- ICON GRID HELPERS
-- ============================================================================

--- Position an icon in a grid within a column
local function position_icon(slot, parent, col_x, base_y, index)
    local col = (index - 1) % ICONS_PER_ROW
    local row = floor((index - 1) / ICONS_PER_ROW)
    local x = col_x + col * ICON_STEP
    local icon_y = base_y - row * ICON_STEP
    slot.frame:ClearAllPoints()
    slot.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, icon_y)
end

--- Calculate how many rows N icons occupy
local function icon_rows(count)
    if count <= 0 then return 0 end
    return floor((count - 1) / ICONS_PER_ROW) + 1
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function update_dashboard()
    if not dashboard_frame or not dashboard_frame:IsShown() then return end

    local cc = rotation_registry and rotation_registry.class_config
    if not cc then return end

    local dash_config = cc.dashboard
    if not dash_config then return end

    -- Build context for playstyle detection + custom_lines
    dash_context.settings = NS.cached_settings
    if cc.extend_context then
        cc.extend_context(dash_context)
    end

    -- Header: class name in class color, "AIO" in accent purple
    local class_hex = CLASS_HEX[cc.name] or "6c63ff"
    header_text:SetText(format("|cff%s%s|r |cff6c63ffAIO|r", class_hex, cc.name or "Unknown"))
    header_text:SetTextColor(1, 1, 1)
    local active_ps = cc.get_active_playstyle and cc.get_active_playstyle(dash_context) or "?"

    last_class_name = cc.name

    local f = dashboard_frame
    local bar_max = FRAME_WIDTH - 22

    -- Primary resource bar
    local res = resolve_config(dash_config.resource, active_ps)
    if res then
        local value = 0
        local max_value = 100
        local label = res.label or "Resource"

        if res.type == "rage" then
            value = Player:Rage() or 0
        elseif res.type == "energy" then
            value = Player:Energy() or 0
            max_value = Player:EnergyMax() or 100
        elseif res.type == "mana" then
            value = Player:ManaPercentage() or 0
            label = format("%s (%.0f%%)", res.label or "Mana", value)
        end

        local pct = max_value > 0 and (value / max_value) or 0
        local bw = bar_max * pct
        if bw < 1 then bw = 1 end
        resource_bar:SetWidth(bw)

        local color = res.color or RESOURCE_COLORS[res.type] or { 1, 1, 1 }
        resource_bar:SetVertexColor(color[1], color[2], color[3])
        resource_text:SetText(res.type == "mana" and label or format("%s: %d", res.label or res.type, value))
    end

    -- Secondary resource bar (e.g., energy/rage when primary is mana)
    local content_y = -50  -- y after primary resource bar
    local res2 = resolve_config(dash_config.secondary_resource, active_ps)
    if res2 then
        local value = 0
        local max_value = 100

        if res2.type == "rage" then
            value = Player:Rage() or 0
        elseif res2.type == "energy" then
            value = Player:Energy() or 0
            max_value = Player:EnergyMax() or 100
        elseif res2.type == "mana" then
            value = Player:ManaPercentage() or 0
        end

        local pct = max_value > 0 and (value / max_value) or 0
        local bw = bar_max * pct
        if bw < 1 then bw = 1 end

        resource_bg2:ClearAllPoints()
        resource_bg2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, content_y)
        resource_bar2:SetWidth(bw)
        local color = res2.color or RESOURCE_COLORS[res2.type] or { 1, 1, 1 }
        resource_bar2:SetVertexColor(color[1], color[2], color[3])
        resource_text2:SetText(res2.type == "mana"
            and format("%s (%.0f%%)", res2.label or "Mana", value)
            or format("%s: %d", res2.label or res2.type, value))
        resource_bg2:Show()
        content_y = content_y - 22
    else
        resource_bg2:Hide()
    end

    -- Timer bars (GCD built-in + class timers)
    local timer_idx = 1
    local class_A = NS.A

    -- GCD bar (always present when framework available)
    if class_A then
        local tb = timer_bars[1]
        local gcd_total = class_A.GetGCD and class_A.GetGCD() or 1.5
        local gcd_remaining = class_A.GetCurrentGCD and class_A.GetCurrentGCD() or 0

        tb.bg:ClearAllPoints()
        tb.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, content_y)
        tb.label:SetText("GCD")

        local gcd_pct = (gcd_total > 0 and gcd_remaining > 0) and (gcd_remaining / gcd_total) or 0
        if gcd_pct > 0 then
            local gcd_bw = bar_max * gcd_pct
            if gcd_bw < 1 then gcd_bw = 1 end
            tb.bar:SetWidth(gcd_bw)
            tb.bar:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])
            tb.bar:Show()
            tb.value:SetText(format("%.1f", gcd_remaining))
            tb.value:Show()
        else
            tb.bar:Hide()
            tb.value:SetText("")
            tb.value:Hide()
        end
        tb.bg:Show()
        timer_idx = 2
        content_y = content_y - (TIMER_BAR_HEIGHT + 2)
    end

    -- Swing / shoot timer bar (driven by swing_label in class dashboard config)
    local sl = dash_config.swing_label
    local swing_label = type(sl) == "string" and sl or (type(sl) == "table" and sl[active_ps] or nil)
    if swing_label and timer_idx <= MAX_TIMER_BARS then
        local shoot = Player:GetSwingShoot() or 0
        local remaining, duration
        if shoot > 0 then
            remaining = shoot
            duration = _G.UnitRangedDamage("player") or 1.5
        else
            local s = Player:GetSwingStart(1) or 0
            local d = Player:GetSwing(1) or 0
            if s > 0 and d > 0 then
                local r = (s + d) - GetTime()
                remaining = r > 0 and r or 0
            else
                remaining = 0
            end
            duration = d > 0 and d or 2.0
        end

        local lbl = shoot > 0 and swing_label or "Swing"
        local ctb = timer_bars[timer_idx]
        ctb.bg:ClearAllPoints()
        ctb.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, content_y)
        ctb.label:SetText(lbl)

        local tpct = (duration > 0 and remaining > 0) and (remaining / duration) or 0
        if tpct > 0 then
            local tbw = bar_max * tpct
            if tbw < 1 then tbw = 1 end
            ctb.bar:SetWidth(tbw)
            ctb.bar:SetVertexColor(1.00, 0.49, 0.04)
            ctb.bar:Show()
            ctb.value:SetText(format("%.1f", remaining))
            ctb.value:Show()
        else
            ctb.bar:Hide()
            ctb.value:SetText("")
            ctb.value:Hide()
        end
        ctb.bg:Show()
        content_y = content_y - (TIMER_BAR_HEIGHT + 2)
        timer_idx = timer_idx + 1
    end

    -- Hide unused timer bars
    for i = timer_idx, MAX_TIMER_BARS do
        timer_bars[i].bg:Hide()
    end

    content_y = content_y - 8

    -- Current Priority (inline)
    local la = last_action
    local accent_hex = "6c63ff"
    if la and la.name then
        priority_text:SetText(format("|cff%sPriority|r  > %s", accent_hex, la.name))
    else
        priority_text:SetText(format("|cff%sPriority|r  |cff666666Idle|r", accent_hex))
    end
    priority_text:ClearAllPoints()
    priority_text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, content_y)
    priority_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, content_y)
    local info_y = content_y - 16

    -- Target info (name inline with label, stats below — static 2-line height)
    local tname = UnitName("target")
    if tname then
        local stats = ""
        local ttd = Unit("target"):TimeToDie() or 0
        if ttd > 0 then
            stats = format("TTD: %s", format_timer(ttd))
        end
        local dist = Unit("target"):GetRange()
        if dist then
            if stats ~= "" then stats = stats .. "  " end
            stats = stats .. format("%dyd", dist)
        end
        local _, _, threat_pct = UnitDetailedThreatSituation("player", "target")
        if threat_pct and threat_pct > 0 then
            local threat_color = threat_pct >= 100 and "ff3333" or (threat_pct >= 80 and "ffaa33" or "33ff33")
            if stats ~= "" then stats = stats .. "  " end
            stats = stats .. format("|cff%s%d%%|r", threat_color, threat_pct)
        end
        local text = format("|cff%sTarget|r  |cffcccccc%s|r", accent_hex, tname)
        text = text .. "\n|cff9494a8" .. (stats ~= "" and stats or " ") .. "|r"
        target_info_fs:SetText(text)
    else
        target_info_fs:SetText(format("|cff%sTarget|r  |cff666666N/A|r\n ", accent_hex))
    end
    target_info_fs:ClearAllPoints()
    target_info_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 10, info_y)
    target_info_fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, info_y)
    target_info_fs:Show()
    info_y = info_y - 34  -- fixed: 2 lines + SetSpacing(4) padding

    sep2_tex:ClearAllPoints()
    sep2_tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, info_y - 2)
    sep2_tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, info_y - 2)
    local sections_y = info_y - 4
    local cd_list = resolve_list(dash_config.cooldowns, active_ps)
    local buff_list = resolve_list(dash_config.buffs, active_ps)
    local debuff_list = resolve_list(dash_config.debuffs, active_ps)
    local num_cds = cd_list and math_min(#cd_list, MAX_COOLDOWNS) or 0
    local num_buffs = buff_list and math_min(#buff_list, MAX_BUFFS) or 0
    local num_debuffs = debuff_list and math_min(#debuff_list, MAX_DEBUFFS) or 0

    local y = sections_y

    -- ---- COOLDOWNS SECTION ----
    if num_cds > 0 then
        local label_y = y - 2
        local icons_y = y - 16

        cd_label_fs:ClearAllPoints()
        cd_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 10, label_y)
        cd_label_fs:Show()

        for i = 1, MAX_COOLDOWNS do
            local slot = cd_slots[i]
            if i <= num_cds then
                local spell = cd_list[i]
                local equip_slot = spell.SlotID or (GetInventoryItemTexture("player", spell.ID) and spell.ID) or nil
                local cd_remain
                if equip_slot then
                    local start, duration = GetInventoryItemCooldown("player", equip_slot)
                    cd_remain = (start and duration and start > 0) and (start + duration - GetTime()) or 0
                    if cd_remain < 0 then cd_remain = 0 end
                else
                    cd_remain = spell:GetCooldown() or 0
                end
                slot.frame.spell_id = not equip_slot and spell.ID or nil
                slot.frame.slot_id = equip_slot
                slot.icon:SetTexture(get_action_icon(spell))
                position_icon(slot, f, ICON_X, icons_y, i)

                if cd_remain > 600 then
                    slot.tint:SetAlpha(0.7)
                    slot.tint:Show()
                    slot.text:SetText("N/A")
                    slot.text:SetTextColor(0.5, 0.5, 0.5)
                    slot.text:Show()
                elseif cd_remain > 0 then
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:SetText(format_timer(cd_remain))
                    slot.text:SetTextColor(1, 1, 1)
                    slot.text:Show()
                else
                    slot.tint:Hide()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_cds) * ICON_STEP - 6
    else
        cd_label_fs:Hide()
        for i = 1, MAX_COOLDOWNS do cd_slots[i].frame:Hide() end
    end

    -- ---- BUFFS SECTION ----
    if num_buffs > 0 then
        local label_y = y - 2
        local icons_y = y - 16

        buff_label_fs:ClearAllPoints()
        buff_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 10, label_y)
        buff_label_fs:Show()

        for i = 1, MAX_BUFFS do
            local slot = buff_slots[i]
            if i <= num_buffs then
                local b = buff_list[i]
                local dur = Unit("player"):HasBuffs(b.id) or 0

                slot.frame.spell_id = type(b.id) == "table" and b.id[1] or b.id
                slot.icon:SetTexture(get_buff_icon(b.id))
                position_icon(slot, f, ICON_X, icons_y, i)

                if dur > 0 then
                    slot.tint:Hide()
                    slot.text:SetText(format_timer(dur))
                    slot.text:SetTextColor(1, 1, 1)
                    slot.text:Show()
                else
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_buffs) * ICON_STEP - 6
    else
        buff_label_fs:Hide()
        for i = 1, MAX_BUFFS do buff_slots[i].frame:Hide() end
    end

    -- ---- DEBUFFS SECTION ----
    if num_debuffs > 0 then
        local label_y = y - 2
        local icons_y = y - 16

        debuff_label_fs:ClearAllPoints()
        debuff_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 10, label_y)
        debuff_label_fs:Show()

        for i = 1, MAX_DEBUFFS do
            local slot = debuff_slots[i]
            if i <= num_debuffs then
                local d = debuff_list[i]
                local dur
                if d.target then
                    local owned = d.owned ~= false
                    dur = Unit("target"):HasDeBuffs(d.id, nil, owned or nil) or 0
                else
                    dur = Unit("player"):HasDeBuffs(d.id) or 0
                end

                slot.frame.spell_id = type(d.id) == "table" and d.id[1] or d.id
                slot.icon:SetTexture(get_buff_icon(d.id))
                position_icon(slot, f, ICON_X, icons_y, i)

                if dur > 0 then
                    slot.tint:Hide()
                    if d.show_stacks then
                        local stacks
                        if d.target then
                            local owned = d.owned ~= false
                            stacks = Unit("target"):HasDeBuffsStacks(d.id, owned or nil) or 0
                        else
                            stacks = Unit("player"):HasDeBuffsStacks(d.id) or 0
                        end
                        slot.text:SetText(format("%d", stacks))
                    else
                        slot.text:SetText(format_timer(dur))
                    end
                    slot.text:SetTextColor(1, 0.8, 0.3)
                    slot.text:Show()
                else
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_debuffs) * ICON_STEP - 6
    else
        debuff_label_fs:Hide()
        for i = 1, MAX_DEBUFFS do debuff_slots[i].frame:Hide() end
    end

    -- Custom lines (text-based)
    local cl = dash_config.custom_lines
    local num_custom = 0
    for i = 1, MAX_CUSTOM_LINES do
        local line = custom_lines[i]
        if cl and cl[i] then
            local clabel, cvalue = cl[i](dash_context)
            if clabel then
                line:SetText(format("|cff9494a8%s:|r %s", clabel, tostring(cvalue or "")))
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y - num_custom * 14)
                line:Show()
                num_custom = num_custom + 1
            else
                line:Hide()
            end
        else
            line:Hide()
        end
    end
    if num_custom > 0 then
        y = y - num_custom * 14 - 2
    end

    -- Playstyle/Form line (always visible at bottom, with separator)
    playstyle_sep:ClearAllPoints()
    playstyle_sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, y - 2)
    playstyle_sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, y - 2)
    y = y - 8

    local ps_label = cc.name == "Druid" and "Form" or "Playstyle"
    local ps_display = active_ps:sub(1, 1):upper() .. active_ps:sub(2)
    playstyle_line_fs:SetText(format("|cff%s%s:|r  %s", accent_hex, ps_label, ps_display))
    playstyle_line_fs:ClearAllPoints()
    playstyle_line_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    y = y - 16

    -- Auto-resize frame height
    dashboard_frame:SetHeight(math_max(-y + 8, 120))
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
local function toggle_dashboard()
    if not dashboard_frame then
        create_dashboard()
    end
    if dashboard_frame:IsShown() then
        dashboard_frame:Hide()
    else
        dashboard_frame:Show()
    end
end

NS.toggle_dashboard = toggle_dashboard

-- ============================================================================
-- UPDATE TIMER (10 Hz when visible)
-- ============================================================================
local update_frame = CreateFrame("Frame")
update_frame.elapsed = 0
update_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= UPDATE_INTERVAL then
        self.elapsed = 0
        update_dashboard()
    end
end)

-- ============================================================================
-- TOGGLE WATCHER (checks setting every 0.5s)
-- ============================================================================
local watch_frame = CreateFrame("Frame")
watch_frame.elapsed = 0
local last_toggle_state = nil

watch_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= TOGGLE_CHECK_INTERVAL then
        self.elapsed = 0
        local show = NS.cached_settings.show_dashboard or false
        if show ~= last_toggle_state then
            last_toggle_state = show
            if not dashboard_frame then
                create_dashboard()
            end
            if show then
                dashboard_frame:Show()
            else
                dashboard_frame:Hide()
            end
        end
    end
end)

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Dashboard]|r Module loaded")
