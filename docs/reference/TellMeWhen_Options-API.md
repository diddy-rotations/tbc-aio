# TellMeWhen_Options API Reference

## Overview

TellMeWhen_Options is a companion addon that provides the configuration interface for TellMeWhen. It loads on-demand to minimize memory usage when not configuring the addon.

### Key Information

- **Purpose:** Configuration UI for TellMeWhen addon
- **Load Type:** LoadOnDemand (loads only when accessing options)
- **Required Dependency:** TellMeWhen (main addon)
- **Author:** Cybeloras of Aerie Peak
- **SavedVariables:** `TMWOptDB`
- **Category:** Combat

### WoW Version Compatibility

Supports the same versions as TellMeWhen:
- **Retail:** 12.0.0, 12.0.1 (Midnight expansion)
- **Classic Cataclysm:** 4.4.2
- **Classic Wrath:** 3.5.0
- **Classic TBC:** 2.5.5
- **Classic Vanilla:** 1.15.7

## Architecture

### File Structure

TellMeWhen_Options does not contain its own Lua files. All configuration files are stored in the main TellMeWhen addon directory but are only loaded when TellMeWhen_Options is enabled.

**Key Directories:**
- `TellMeWhen/Options/` - Main configuration UI files
- `TellMeWhen/Components/IconTypes/*/Config.xml` - Icon type-specific configuration panels
- `TellMeWhen/Components/IconTypes/*/Config.lua` - Icon type configuration logic

### Load-On-Demand Pattern

```lua
-- Options are loaded via the WoW addon system when:
-- 1. User opens TellMeWhen configuration
-- 2. Slash command "/tmw" is used
-- 3. Programmatically via LoadAddOn("TellMeWhen_Options")
```

## Loading the Options UI

### Manual Loading

```lua
-- Check if options are loaded
if not IsAddOnLoaded("TellMeWhen_Options") then
    -- Load the options addon
    LoadAddOn("TellMeWhen_Options")
end

-- Options are now available via TMW global
TMW.Options:Show()  -- Opens the configuration window
```

### Slash Commands

TellMeWhen provides slash commands that automatically load the options UI:

```
/tmw          -- Opens TellMeWhen configuration
/tellmewhen   -- Same as /tmw
```

## SavedVariables

### TMWOptDB

Global saved variable that stores TellMeWhen Options-specific data.

**Structure:**
```lua
TMWOptDB = {
    -- Options UI state and preferences
    -- Window positions and sizes
    -- Recently used settings
    -- Import/export history
}
```

**Note:** The main TellMeWhen settings are stored in `TellMeWhenDB`, not `TMWOptDB`.

## Configuration System

### TMW.Options Table

Once TellMeWhen_Options is loaded, the `TMW.Options` table provides access to the configuration system.

#### TMW.Options:Show()

Opens the TellMeWhen configuration window.

- **Description:** Displays the main configuration interface for managing groups, icons, and settings
- **Parameters:** None
- **Returns:** None
- **Example:**
  ```lua
  TMW.Options:Show()
  ```

#### TMW.Options:Hide()

Closes the TellMeWhen configuration window.

- **Description:** Hides the configuration interface
- **Parameters:** None
- **Returns:** None

## Icon Configuration API

### Icon Type Configuration

Each icon type can provide its own configuration panel that integrates into the main options UI.

#### Configuration Registration

Icon types register their configuration panels via:
```lua
-- In icon type Config.lua files
local TYPE = "icontype_name"
local ConfigFrame = TMW.IE.ConfigFrames[TYPE]

-- ConfigFrame provides the UI for icon-specific settings
```

### Version-Specific Configurations

Some icon types have different configurations for different game versions:

**Retail-only:**
- Runes icon type (Death Knight rune tracking)
- Lose Control icon type (CC tracking)

**Wrath/Cata/Mists:**
- Simplified rune configuration for classic versions

## Embedded Libraries

TellMeWhen_Options embeds the following libraries for enhanced configuration:

### LibBabble-CreatureType-3.0
- **Purpose:** Localized creature type names
- **Usage:** Filtering and displaying creature types in conditions

### LibBabble-Race-3.0
- **Purpose:** Localized race names
- **Usage:** Race-specific condition configuration

## Integration with Main Addon

### Configuration Loading Flow

```
1. User action (slash command, menu click)
   ↓
2. WoW loads TellMeWhen_Options addon
   ↓
3. Options files from TellMeWhen/Options/ are loaded
   ↓
4. TMW.Options table is populated
   ↓
5. Configuration window is shown
   ↓
6. Changes are saved to TellMeWhenDB (main settings)
```

### Performance Considerations

- **Memory Efficiency:** Options UI is ~2-3 MB, only loaded when needed
- **No Runtime Overhead:** Zero performance impact during combat when not configuring
- **Instant Availability:** First-time load takes <100ms on modern systems

## Common Use Cases

### Programmatic Configuration Access

```lua
-- Load options if not already loaded
if not IsAddOnLoaded("TellMeWhen_Options") then
    local loaded, reason = LoadAddOn("TellMeWhen_Options")
    if not loaded then
        print("Failed to load TellMeWhen_Options:", reason)
        return
    end
end

-- Access configuration API
TMW.Options:Show()

-- Navigate to specific group configuration
-- (This would require deeper integration with TMW.IE - Icon Editor)
```

### Checking Options Availability

```lua
-- Check if user can access options
local function CanConfigureTMW()
    -- Check if main addon is loaded
    if not TMW then
        return false, "TellMeWhen not loaded"
    end

    -- Check if options can be loaded
    local enabled = GetAddOnEnableState(nil, "TellMeWhen_Options")
    if enabled == 0 then
        return false, "TellMeWhen_Options is disabled"
    end

    return true
end

local canConfigure, reason = CanConfigureTMW()
if canConfigure then
    LoadAddOn("TellMeWhen_Options")
    TMW.Options:Show()
else
    print("Cannot open configuration:", reason)
end
```

## Configuration Files Reference

While all files are in the main TellMeWhen directory, here are the key configuration files:

### Core Configuration
- `TellMeWhen/Options/TellMeWhen_Options.lua` - Main options initialization
- `TellMeWhen/Options/IconConfig.lua` - Icon configuration panels
- `TellMeWhen/Options/GroupConfig.lua` - Group configuration panels
- `TellMeWhen/Options/ImportExport.lua` - Profile import/export functionality

### Component Configurations
- `TellMeWhen/Components/IconTypes/*/Config.xml` - Icon type UI definitions
- `TellMeWhen/Components/IconTypes/*/Config.lua` - Icon type configuration logic

## Best Practices

### For Addon Developers

1. **Check Before Loading**
   ```lua
   if not IsAddOnLoaded("TellMeWhen_Options") then
       LoadAddOn("TellMeWhen_Options")
   end
   ```

2. **Verify TMW.Options Exists**
   ```lua
   if TMW and TMW.Options then
       TMW.Options:Show()
   end
   ```

3. **Don't Load During Combat**
   ```lua
   if InCombatLockdown() then
       print("Cannot open configuration during combat")
       return
   end
   ```

### For Users

- Options automatically load when using `/tmw` command
- All configuration is saved to character or account (based on TellMeWhen settings)
- Options addon can be disabled to save memory if not actively configuring

## Technical Details

### Addon Metadata

From `TellMeWhen_Options.toc`:
```lua
## Interface: 120000, 120001, 110205, 50500, 40402, 20505, 11507
## Title: TellMeWhen Options
## RequiredDeps: TellMeWhen
## LoadOnDemand: 1
## SavedVariables: TMWOptDB
```

### File Loading Order

1. `TellMeWhen/Options/includes.xml` - Loads all option files
2. Icon type configurations (version-specific)
3. Component configurations

## Troubleshooting

### Options Won't Load

```lua
-- Diagnostic code
local loaded = IsAddOnLoaded("TellMeWhen_Options")
local enabled = GetAddOnEnableState(nil, "TellMeWhen_Options")

print("Options loaded:", loaded)
print("Options enabled:", enabled)

if not loaded and enabled > 0 then
    local success, reason = LoadAddOn("TellMeWhen_Options")
    print("Load attempt:", success, reason)
end
```

### Common Issues

1. **"Interface action failed"** - Usually means trying to open config during combat
2. **Options missing** - TellMeWhen_Options addon is disabled in addon list
3. **Blank configuration** - Corrupted TMWOptDB, delete and reload

## Version History

TellMeWhen_Options follows the same versioning as the main TellMeWhen addon.

**Current Version:** Matches TellMeWhen 12.0.3

## Related Documentation

- See `TellMeWhen-API.md` for the main addon API reference
- See `Textfiles-API.md` for rotation scripting with The Action framework

## Summary

TellMeWhen_Options is a lightweight, on-demand configuration addon that:
- Loads only when needed to save memory
- Provides full UI for configuring TellMeWhen
- Stores preferences in `TMWOptDB`
- Integrates seamlessly with the main TellMeWhen addon
- Supports all WoW versions from Vanilla to Retail

For most users, interaction is simply via `/tmw` slash command. For developers, the LoadAddOn pattern provides programmatic access to the configuration system.
