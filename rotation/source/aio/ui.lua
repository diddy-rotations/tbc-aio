-- Diddy AIO - ProfileUI Generator
-- Reads _G.DiddyAIO_SETTINGS_SCHEMA and generates A.Data.ProfileUI[2]
-- Generic: works for any class that provides a schema

local _G = _G
local A = _G.Action
if not A then return end

local schema = _G.DiddyAIO_SETTINGS_SCHEMA
if not schema then return end

-- ============================================================================
-- PROFILE UI GENERATOR
-- ============================================================================
-- Builds A.Data.ProfileUI[2] from the schema so the framework's built-in UI
-- has all settings registered with correct keys, defaults, and types.

local function generate_profile_ui(s)
    local profile_ui = {}
    local empty = {}

    -- Title header
    profile_ui[#profile_ui + 1] = {
        { E = "Header", L = { enUS = "Diddy AIO Rotation Settings" }, S = 16 }
    }

    -- Iterate all tabs in the schema
    for _, tab_def in pairs(s) do
        if tab_def.sections then
            -- Tab header
            profile_ui[#profile_ui + 1] = {
                { E = "Header", L = { enUS = tab_def.name .. " Settings" }, S = 14 }
            }

            for _, section in ipairs(tab_def.sections) do
                -- Section header
                profile_ui[#profile_ui + 1] = {
                    { E = "Header", L = { enUS = section.header }, S = 12 }
                }

                -- Group settings into rows of 2
                local settings = section.settings
                local i = 1
                while i <= #settings do
                    local row = {}
                    local st = settings[i]
                    if st.type == "checkbox" then
                        row[#row + 1] = { E = "Checkbox", DB = st.key, DBV = st.default,
                            L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
                    else
                        row[#row + 1] = { E = "Slider", DB = st.key, DBV = st.default,
                            MIN = st.min, MAX = st.max,
                            L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
                    end

                    -- Add second widget to row if not wide and another setting exists
                    if not st.wide and i + 1 <= #settings then
                        i = i + 1
                        st = settings[i]
                        if st.type == "checkbox" then
                            row[#row + 1] = { E = "Checkbox", DB = st.key, DBV = st.default,
                                L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
                        else
                            row[#row + 1] = { E = "Slider", DB = st.key, DBV = st.default,
                                MIN = st.min, MAX = st.max,
                                L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
                        end
                    end

                    profile_ui[#profile_ui + 1] = row
                    i = i + 1
                end
            end
        end
    end

    return profile_ui
end

-- ============================================================================
-- GENERATE PROFILE UI
-- ============================================================================
A.Data.ProfileUI = {
    DateTime = "v2.5 (17.02.2026)",
    [2] = generate_profile_ui(schema),
}

print("|cFF00FF00[Diddy AIO]|r ProfileUI generated")
