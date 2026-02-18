# TellMeWhen API Reference

## Overview

**Version:** 12.0.3
**Purpose:** WoW Combat Notification Addon
**Global Namespace:** `TMW`
**Architecture:** Object-Oriented using LibOO-1.0
**Framework:** Ace3-based

### Dependencies

TellMeWhen is built on the Ace3 framework and requires several embedded libraries:

- **AceAddon-3.0** - Core addon framework
- **AceEvent-3.0** - Event handling
- **AceTimer-3.0** - Timer management
- **AceConsole-3.0** - Console commands
- **AceComm-3.0** - Inter-addon communication
- **AceSerializer-3.0** - Data serialization
- **AceDB-3.0** - Database management
- **LibOO-1.0** - Object-oriented programming framework
- **LibSharedMedia-3.0** - Shared media management
- **LibDogTag-3.0** - Text formatting
- **LibDogTag-Unit-3.0** - Unit text formatting
- **LibDogTag-Stats-3.0** - Stats text formatting
- **LibRangeCheck-3.0** - Range checking
- **LibSpellRange-1.0** - Spell range checking
- **LibCustomGlow-1.0** - Custom glow effects
- **LibBabble-Race-3.0** - Race localization
- **LibBabble-CreatureType-3.0** - Creature type localization
- **DRList-1.0** - Diminishing returns tracking

---

## Core Concepts

### LibOO Class System

TellMeWhen uses LibOO-1.0 for object-oriented programming:

```lua
-- Creating a new class
local MyClass = TMW:NewClass("MyClass")

-- Accessing classes
local Icon = TMW.Classes.Icon  -- Full path
local Icon = TMW.C.Icon        -- Shortcut
```

### Icon/Group Architecture

- **Groups** contain multiple **Icons**
- Icons have **Types** (buff, cooldown, etc.)
- Icons have **Views** (icon, bar, text)
- Groups belong to **Domains** (global/profile)

### Event-Driven Updates

TMW uses callbacks for updates:

```lua
TMW:RegisterCallback("TMW_GLOBAL_UPDATE", function()
    -- React to global updates
end)
```

---

## Global API

### TMW Namespace

#### Core Initialization

##### `TMW:NewClass(className)`
Creates a new LibOO class.

- **Parameters:**
  - `className` (string) - Name of the class
- **Returns:** Class object
- **Example:**
```lua
local MyClass = TMW:NewClass("MyClass")
```

##### `TMW:CInit(self, className)`
Initializes an existing frame as a TMW class instance.

- **Parameters:**
  - `self` (frame) - Frame to initialize
  - `className` (string|nil) - Class name (uses self.tmwClass if nil)
- **Example:**
```lua
TMW:CInit(myFrame, "Icon")
```

##### `TMW:RegisterDatabaseDefaults(defaults)`
Registers default values for the database.

- **Parameters:**
  - `defaults` (table) - Table of default values

##### `TMW:MergeDefaultsTables(src, dest)`
Merges default tables together.

- **Parameters:**
  - `src` (table) - Source defaults
  - `dest` (table) - Destination defaults

---

### Spell & Texture API

#### `TMW.GetSpellTexture(spell)`
Gets the texture for a spell.

- **Parameters:**
  - `spell` (number|string) - Spell ID or name
- **Returns:** (string) Texture path
- **Example:**
```lua
local texture = TMW.GetSpellTexture(12345)
```

#### `TMW:GetSpells(spellString, allowRenaming)`
Parses a semicolon-delimited spell string into a SpellSet.

- **Parameters:**
  - `spellString` (string|number) - Semicolon-delimited spell names/IDs
  - `allowRenaming` (boolean) - Allow spell name renaming
- **Returns:** (TMW.C.SpellSet) SpellSet instance
- **Example:**
```lua
local spells = TMW:GetSpells("Fireball; Frostbolt; 133")
local firstSpell = spells.First
local allSpells = spells.Array
local spellHash = spells.Hash
```

**SpellSet Members:**
- `First` - First spell in the string
- `FirstString` - First spell as name
- `FirstId` - First spell as ID
- `Array` - Array of all spells
- `StringArray` - Array with IDs converted to names
- `Hash` - Dictionary with spell indices
- `StringHash` - Hash with IDs as names
- `Durations` - Array of durations (using "Spell: Duration" syntax)

All members also available with `NoLower` suffix (e.g., `FirstNoLower`, `ArrayNoLower`).

#### `TMW:LowerNames(str)`
Converts strings/table values to lowercase, preserving capitalization cache.

- **Parameters:**
  - `str` (string|table) - String or table to lowercase
- **Returns:** Lowercased version
- **Example:**
```lua
local lower = TMW:LowerNames("Fireball")  -- "fireball"
```

#### `TMW:RestoreCase(str)`
Restores capitalization of a lowercased spell name.

- **Parameters:**
  - `str` (string) - Lowercased string
- **Returns:** (string, string) Original case, lowered case
- **Example:**
```lua
local proper, lower = TMW:RestoreCase("fireball")  -- "Fireball", "fireball"
```

#### `TMW:EquivToTable(name)`
Generates table of spells from a spell equivalency.

- **Parameters:**
  - `name` (string) - Equivalency name
- **Returns:** (table|nil) Table of spells, or nil if invalid
- **Example:**
```lua
local spells = TMW:EquivToTable("buffs/arcane")
```

---

### Unit API

#### `TMW:GetUnits(icon, setting, Conditions)`
Parses unit strings and returns a unit set with conditions.

- **Parameters:**
  - `icon` (Icon|nil) - Icon requesting units
  - `setting` (string) - Semicolon-delimited unit string
  - `Conditions` (table|nil) - Condition table
- **Returns:** (table, UnitSet) Exposed units table, UnitSet object
- **Example:**
```lua
local units, unitSet = TMW:GetUnits(icon, "target; focus; party1-4", conditions)
for _, unit in ipairs(units) do
    -- Process unit
end
```

**Unit String Syntax:**
- `target` - Single unit
- `party1-4` - Range of units
- `raid` - Expands to raid1-40
- `group` - Auto-selects party/raid
- `maintank1-3` - Main tanks
- `mainassist1-3` - Main assists
- `nameplate1-40` - Nameplates

---

### Item API

#### `TMW:GetItems(setting)`
Parses item string into item set.

- **Parameters:**
  - `setting` (string) - Semicolon-delimited item names/IDs
- **Returns:** (table) Item data structure

#### `TMW:GetNullRefItem()`
Returns a null reference item (for error handling).

- **Returns:** (table) Null item object

---

### Cooldown API

#### `TMW.COMMON.Cooldowns.GetSpellCooldown(spell)`
Gets cooldown information for a spell (cached per frame).

- **Parameters:**
  - `spell` (number|string) - Spell ID or name
- **Returns:** (table|nil) Cooldown info: `{startTime, duration, isEnabled, modRate}`
- **Example:**
```lua
local cd = TMW.COMMON.Cooldowns.GetSpellCooldown(12345)
if cd then
    local remaining = cd.duration - (TMW.time - cd.startTime)
end
```

#### `TMW.COMMON.Cooldowns.GetSpellCharges(spell)`
Gets charge information for a spell (cached per frame).

- **Parameters:**
  - `spell` (number|string) - Spell ID or name
- **Returns:** (table|nil) Charge info: `{currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate}`

#### `TMW.COMMON.Cooldowns.GetSpellCastCount(spell)`
Gets spell cast count (for multi-cast spells).

- **Parameters:**
  - `spell` (number|string) - Spell ID or name
- **Returns:** (number|nil) Cast count

#### `TMW.GetGCD()`
Gets the current GCD duration.

- **Returns:** (number) GCD duration in seconds
- **Example:**
```lua
local gcd = TMW.GetGCD()
```

#### `TMW.OnGCD(duration)`
Checks if a duration represents a GCD.

- **Parameters:**
  - `duration` (number) - Duration to check
- **Returns:** (boolean) True if duration is a GCD
- **Example:**
```lua
if TMW.OnGCD(1.5) then
    -- This is a GCD
end
```

#### `TMW.GetRuneCooldownDuration()`
Gets the rune cooldown duration (Death Knights).

- **Returns:** (number) Rune cooldown duration

#### `TMW.GetSpellCost(spell)`
Gets the power cost of a spell.

- **Parameters:**
  - `spell` (number|string) - Spell ID or name
- **Returns:** (number|nil, table|nil) Cost amount, cost data
- **Example:**
```lua
local cost, costData = TMW.GetSpellCost(12345)
if cost then
    print("Costs", cost, Enum.PowerType[costData.type])
end
```

---

### String Utilities

#### `TMW.toSeconds(str)`
Converts time string to seconds.

- **Parameters:**
  - `str` (string) - Time string (e.g., "1:45:30")
- **Returns:** (number) Total seconds
- **Example:**
```lua
local secs = TMW.toSeconds("1:30")  -- 90
```

#### `TMW:CleanString(text)`
Cleans up spell/unit strings (removes extra spaces, semicolons).

- **Parameters:**
  - `text` (string|frame) - Text or frame with GetText()
- **Returns:** (string) Cleaned string
- **Example:**
```lua
local clean = TMW:CleanString("Fireball  ;  Frostbolt")
-- Returns: "Fireball; Frostbolt"
```

#### `TMW:CleanPath(path)`
Normalizes file paths.

- **Parameters:**
  - `path` (string) - File path
- **Returns:** (string) Normalized path
- **Example:**
```lua
local path = TMW:CleanPath("Interface\\Icons\\Spell.tga")
-- Returns: "Interface/Icons/Spell.tga"
```

#### `TMW:SplitNames(input, stringsOnly)`
Splits semicolon-delimited string into table.

- **Parameters:**
  - `input` (string) - String to split
  - `stringsOnly` (boolean) - Don't convert numbers
- **Returns:** (table) Array of names
- **Example:**
```lua
local names = TMW:SplitNames("Fireball; 133; Frostbolt")
-- Returns: {"Fireball", 133, "Frostbolt"}
```

#### `TMW:FormatSeconds(seconds, skipSmall, keepTrailing)`
Formats seconds as human-readable time string.

- **Parameters:**
  - `seconds` (number) - Seconds to format
  - `skipSmall` (boolean) - Skip decimal places
  - `keepTrailing` (boolean) - Keep trailing zeros
- **Returns:** (string) Formatted time (e.g., "1:45:30")
- **Example:**
```lua
local time = TMW:FormatSeconds(3661)  -- "1:01:01"
```

---

### Color Utilities

#### `TMW:RGBAToString(r, g, b, a, flags)`
Converts RGBA values to hex color string.

- **Parameters:**
  - `r` (number) - Red (0-1)
  - `g` (number) - Green (0-1)
  - `b` (number) - Blue (0-1)
  - `a` (number) - Alpha (0-1)
  - `flags` (table|nil) - Color flags
- **Returns:** (string) Hex color string
- **Example:**
```lua
local color = TMW:RGBAToString(1, 0, 0, 1)  -- "ffff0000"
```

#### `TMW:StringToRGBA(str)`
Converts hex color string to RGBA values.

- **Parameters:**
  - `str` (string|table) - Hex color string or table
- **Returns:** (number, number, number, number, table) r, g, b, a, flags
- **Example:**
```lua
local r, g, b, a = TMW:StringToRGBA("ffff0000")
```

#### `TMW:StringToCachedRGBATable(str)`
Converts color string to cached RGBA table.

- **Parameters:**
  - `str` (string) - Color string
- **Returns:** (table) `{r, g, b, a, flags}`

#### `TMW:StringToCachedColorMixin(str)`
Converts color string to ColorMixin object.

- **Parameters:**
  - `str` (string) - Color string
- **Returns:** (ColorMixin) Color object

#### `TMW:RGBToHSV(r, g, b)`
Converts RGB to HSV color space.

- **Parameters:**
  - `r` (number) - Red (0-1)
  - `g` (number) - Green (0-1)
  - `b` (number) - Blue (0-1)
- **Returns:** (number, number, number) h, s, v

#### `TMW:HSVToRGB(h, s, v, a)`
Converts HSV to RGB color space.

- **Parameters:**
  - `h` (number) - Hue (0-1)
  - `s` (number) - Saturation (0-1)
  - `v` (number) - Value (0-1)
  - `a` (number|nil) - Alpha (0-1)
- **Returns:** (number, number, number, number) r, g, b, a

---

### Table Utilities

#### `TMW.map(t, func)`
Maps a function over a table.

- **Parameters:**
  - `t` (table) - Table to map
  - `func` (function) - Function(value, key, table) -> newValue, newKey
- **Returns:** (table) New mapped table
- **Example:**
```lua
local doubled = TMW.map({1, 2, 3}, function(v) return v * 2 end)
-- Returns: {2, 4, 6}
```

#### `TMW.approachTable(t, ...)`
Traverses nested table using keys/functions.

- **Parameters:**
  - `t` (table) - Table to traverse
  - `...` - Keys or functions to traverse
- **Returns:** Final value or nil
- **Example:**
```lua
local val = TMW.approachTable(db, "profile", "Groups", 1)
```

#### `TMW.shallowCopy(t)`
Creates shallow copy of table.

- **Parameters:**
  - `t` (table) - Table to copy
- **Returns:** (table) Copied table

#### `TMW.tContains(table, item, returnNum)`
Checks if table contains an item.

- **Parameters:**
  - `table` (table) - Table to search
  - `item` (*) - Item to find
  - `returnNum` (boolean) - Return count instead of key
- **Returns:** (key|nil, number|nil) First key, total count
- **Example:**
```lua
local key = TMW.tContains({"a", "b", "c"}, "b")  -- 2
```

#### `TMW.tDeleteItem(table, item, onlyOne)`
Removes item(s) from table.

- **Parameters:**
  - `table` (table) - Table to modify
  - `item` (*) - Item to remove
  - `onlyOne` (boolean) - Only remove first match
- **Returns:** (boolean) True if removed

#### `TMW.tRemoveDuplicates(table)`
Removes duplicate values from table.

- **Parameters:**
  - `table` (table) - Table to deduplicate
- **Returns:** (table) Same table, modified

#### `TMW.binaryInsert(table, value, comp)`
Inserts value into sorted table using binary search.

- **Parameters:**
  - `table` (table) - Sorted table
  - `value` (*) - Value to insert
  - `comp` (function|nil) - Comparison function
- **Returns:** (number) Insertion index

#### `TMW:SortOrderedTables(parentTable)`
Sorts tables with `Order` or `order` keys.

- **Parameters:**
  - `parentTable` (table) - Table to sort
- **Returns:** (table) Sorted table

#### `TMW:CopyWithMetatable(source, blocker)`
Deep copies table with metatables.

- **Parameters:**
  - `source` (table) - Source table
  - `blocker` (table|nil) - Keys to block from copying
- **Returns:** (table) Copied table

#### `TMW:CopyInPlaceWithMetatable(source, dest, blocker)`
Copies table into existing destination with metatables.

- **Parameters:**
  - `source` (table) - Source table
  - `dest` (table) - Destination table
  - `blocker` (table|nil) - Keys to block

#### `TMW:DeepCompare(t1, t2)`
Deep comparison of two tables.

- **Parameters:**
  - `t1` (table) - First table
  - `t2` (table) - Second table
- **Returns:** (boolean) True if equal

---

### Iterator Functions

#### `TMW:InNLengthTable(arg)`
Iterates over table with `n` length property.

- **Parameters:**
  - `arg` (table) - Table with `.n` property
- **Returns:** Iterator function
- **Example:**
```lua
for k, v in TMW:InNLengthTable(conditions) do
    -- Process condition
end
```

#### `TMW:OrderedPairs(t, compare, byValues, rev)`
Iterates over table in sorted order.

- **Parameters:**
  - `t` (table) - Table to iterate
  - `compare` (function|nil) - Comparison function
  - `byValues` (boolean|nil) - Sort by values instead of keys
  - `rev` (boolean|nil) - Reverse order
- **Returns:** Iterator function
- **Example:**
```lua
for k, v in TMW:OrderedPairs(spells) do
    print(k, v)
end
```

---

### Output & Error Handling

#### `TMW.print(...)`
Prints to chat with TMW prefix.

- **Parameters:**
  - `...` - Values to print

#### `TMW:Warn(text)`
Displays warning once.

- **Parameters:**
  - `text` (string) - Warning text

#### `TMW:Debug(...)`
Prints debug message (only if `TMW.debug` is true).

- **Parameters:**
  - `...` - Format string and args

#### `TMW:Error(text, ...)`
Triggers error handler.

- **Parameters:**
  - `text` (string) - Error format string
  - `...` - Format args

#### `TMW:Assert(statement, text, ...)`
Asserts condition or triggers error.

- **Parameters:**
  - `statement` (*) - Value to test
  - `text` (string) - Error message
  - `...` - Format args

---

### Function Caching

#### `TMW:MakeFunctionCached(obj, method)`
Creates cached version of function (any number of args).

- **Parameters:**
  - `obj` (table|function) - Object or function
  - `method` (string|nil) - Method name if obj is table
- **Returns:** (function, table) Wrapper function, cache table

#### `TMW:MakeNArgFunctionCached(argCount, obj, method)`
Creates cached version with fixed arg count (faster than MakeFunctionCached).

- **Parameters:**
  - `argCount` (number) - Number of arguments
  - `obj` (table|function) - Object or function
  - `method` (string|nil) - Method name
- **Returns:** (function, table) Wrapper function, cache

#### `TMW:MakeSingleArgFunctionCached(obj, method)`
Creates cached version for single-arg functions (fastest).

- **Parameters:**
  - `obj` (table|function) - Object or function
  - `method` (string|nil) - Method name
- **Returns:** (function) Wrapper function

---

### Tooltip Utilities

#### `TMW:TT(f, title, text, actualtitle, actualtext, showchecker)`
Adds tooltip to frame.

- **Parameters:**
  - `f` (frame) - Frame to add tooltip to
  - `title` (string) - Tooltip title
  - `text` (string) - Tooltip text
  - `actualtitle` (boolean) - Use title literally
  - `actualtext` (boolean) - Use text literally
  - `showchecker` (string|nil) - Property to check before showing

#### `TMW:TT_Update(f)`
Updates tooltip if frame is hovered.

- **Parameters:**
  - `f` (frame) - Frame with tooltip

---

### Counter API

#### `TMW:ChangeCounter(name, operation, value)`
Changes a TMW counter value.

- **Parameters:**
  - `name` (string) - Counter name
  - `operation` (string) - "set", "add", "subtract"
  - `value` (number) - Value
- **Example:**
```lua
TMW:ChangeCounter("MyCounter", "add", 5)
local count = TMW.COUNTERS.MyCounter
```

---

### Miscellaneous Utilities

#### `TMW.get(value, ...)`
Calls value as function or indexes as table/returns as-is.

- **Parameters:**
  - `value` (function|table|*) - Value to get
  - `...` - Args for function or key for table
- **Returns:** Result

#### `TMW.NULLFUNC()`
Empty function (does nothing).

#### `TMW.oneUpString(string)`
Increments number in string or appends " 2".

- **Parameters:**
  - `string` (string) - String to increment
- **Returns:** (string) Incremented string
- **Example:**
```lua
local s = TMW.oneUpString("Group 1")  -- "Group 2"
```

#### `TMW:AnimateHeightChange(f, endHeight, duration)`
Animates frame height change.

- **Parameters:**
  - `f` (frame) - Frame to animate
  - `endHeight` (number) - Target height
  - `duration` (number) - Animation duration

#### `TMW:ValidateType(argN, methodName, var, reqType)`
Validates argument type.

- **Parameters:**
  - `argN` (string) - Argument description
  - `methodName` (string) - Method name
  - `var` (*) - Variable to check
  - `reqType` (string) - Required type(s) separated by semicolon

#### `TMW:GetRaceIconInfo(race)`
Gets atlas string for race icon.

- **Parameters:**
  - `race` (string) - Race name
- **Returns:** (string) Atlas string

#### `TMW:TryGetNPCName(id)`
Attempts to get NPC name from ID.

- **Parameters:**
  - `id` (number) - NPC ID
- **Returns:** (string|nil) NPC name

#### `TMW:FormatAtlasString(atlasName, trimPercent)`
Formats atlas as texture string.

- **Parameters:**
  - `atlasName` (string) - Atlas name
  - `trimPercent` (number|nil) - Trim percentage
- **Returns:** (string) Texture string

#### `TMW:CreateDogTagEventString(...)`
Creates event string for DogTag updates.

- **Parameters:**
  - `...` - Event names
- **Returns:** (string) Event string

---

### WoW API Helpers

#### `TMW.GetSpellBookItemInfo(index, book)`
Gets spellbook item info (compatibility wrapper).

- **Parameters:**
  - `index` (number) - Spellbook index
  - `book` (string) - "player" or "pet"
- **Returns:** (table) `{itemType, typeName, actionID, name}`

#### `TMW.GetSpecializationInfo(index)`
Gets specialization info for current class.

- **Parameters:**
  - `index` (number) - Spec index
- **Returns:** (number, string, string, number, string) id, name, description, icon, role

#### `TMW.GetSpecializationInfoByID(specID)`
Gets specialization info by ID.

- **Parameters:**
  - `specID` (number) - Spec ID
- **Returns:** (number, string, string, number, string) id, name, description, icon, role

#### `TMW.GetSpecializationInfoForClassID(classID, index)`
Gets spec info for a class.

- **Parameters:**
  - `classID` (number) - Class ID
  - `index` (number) - Spec index
- **Returns:** (number, string, string, number, string) id, name, description, icon, role

#### `TMW.GetCurrentSpecialization()`
Gets current active spec index.

- **Returns:** (number) Active spec index

#### `TMW.GetCurrentSpecializationID()`
Gets current spec ID.

- **Returns:** (number) Active spec ID

#### `TMW.GetCurrentSpecializationRole()`
Gets current spec role.

- **Returns:** (string) "TANK", "HEALER", or "DAMAGER"

#### `TMW.GetNumSpecializations()`
Gets number of specializations for player.

- **Returns:** (number) Spec count

#### `TMW.GetNumSpecializationsForClassID(classID)`
Gets number of specs for a class.

- **Parameters:**
  - `classID` (number) - Class ID
- **Returns:** (number) Spec count

#### `TMW.GetClassInfo(classID)`
Gets class information.

- **Parameters:**
  - `classID` (number) - Class ID
- **Returns:** (string, string, number) className, classFile, classID

#### `TMW.GetMaxClassID()`
Gets maximum class ID.

- **Returns:** (number) Max class ID (13)

#### `TMW:GetParser()`
Gets shared tooltip parser frame.

- **Returns:** (GameTooltip, FontString...) Parser and text objects

---

### Data & Settings API

#### `TMW:GenerateGUID(type, length)`
Generates unique identifier.

- **Parameters:**
  - `type` (string) - GUID type
  - `length` (number) - Length
- **Returns:** (string) GUID

#### `TMW:ParseGUID(GUID)`
Parses GUID string.

- **Parameters:**
  - `GUID` (string) - GUID to parse
- **Returns:** (string, number) Type, ID

#### `TMW:DeclareDataOwner(GUID, object)`
Declares object as owner of GUID.

- **Parameters:**
  - `GUID` (string) - GUID
  - `object` (*) - Owner object

#### `TMW:GetDataOwner(GUID)`
Gets owner of GUID.

- **Parameters:**
  - `GUID` (string) - GUID
- **Returns:** (*) Owner object

#### `TMW:GetSettingsFromGUID(GUID)`
Gets settings table from GUID.

- **Parameters:**
  - `GUID` (string) - GUID
- **Returns:** (table) Settings table

---

### Import/Export API

#### `TMW:Import(SettingsItem, ...)`
Imports settings data.

- **Parameters:**
  - `SettingsItem` (table) - Settings item
  - `...` - Additional args

#### `TMW:SerializeData(data, type, ...)`
Serializes data for export.

- **Parameters:**
  - `data` (*) - Data to serialize
  - `type` (string) - Data type
  - `...` - Additional args
- **Returns:** (string) Serialized string

#### `TMW:DeserializeData(str, silent)`
Deserializes import string.

- **Parameters:**
  - `str` (string) - Serialized string
  - `silent` (boolean) - Suppress errors
- **Returns:** (*) Deserialized data

---

### Update System

#### `TMW:Update(forceCoroutine)`
Triggers TMW update cycle.

- **Parameters:**
  - `forceCoroutine` (boolean) - Force coroutine update

#### `TMW:ScheduleUpdate(delay)`
Schedules delayed update.

- **Parameters:**
  - `delay` (number) - Delay in seconds

#### `TMW:UpdateGlobals()`
Updates global state.

---

### Callback Events

TMW fires various callback events:

```lua
-- Global updates
TMW:RegisterCallback("TMW_GLOBAL_UPDATE", function() end)

-- Icon updates
TMW:RegisterCallback("TMW_ICON_UPDATED", function(event, icon) end)

-- Spell updates
TMW:RegisterCallback("TMW_SPELL_UPDATE_COOLDOWN", function() end)
TMW:RegisterCallback("TMW_SPELL_UPDATE_CHARGES", function() end)
TMW:RegisterCallback("TMW_SPELL_UPDATE_COUNT", function() end)

-- Unit updates
TMW:RegisterCallback("TMW_UNITSET_UPDATED", function(event, unitSet) end)

-- Condition updates
TMW:RegisterCallback("TMW_CNDT_OBJ_PASSING_CHANGED", function(event, condObj, failed) end)

-- Initialization
TMW:RegisterCallback("TMW_INITIALIZE", function() end)
TMW:RegisterCallback("TMW_OPTIONS_LOADED", function() end)
```

---

## Global Constants

### TMW.COMMON

- `TMW.COMMON.Cooldowns` - Cooldown tracking frame
- `TMW.COMMON.Actions` - Action tracking
- `TMW.COMMON.Textures` - Texture management
- `TMW.COMMON.SpellUsable` - Spell usability tracking
- `TMW.COMMON.SpellRange` - Spell range tracking
- `TMW.COMMON.SwingTimerMonitor` - Swing timer tracking

### TMW Tables

- `TMW.Types` - Icon type registry
- `TMW.OrderedTypes` - Sorted icon types
- `TMW.Views` - Icon view registry
- `TMW.OrderedViews` - Sorted icon views
- `TMW.EventList` - Event registry
- `TMW.DS` - Dispel type textures
- `TMW.COUNTERS` - Counter values (metatable returns 0 for undefined)
- `TMW.TIMERS` - Timer registry
- `TMW.EVENTS` - Event handler registry
- `TMW.UNITS` - Unit management module
- `TMW.CNDT` - Condition system
- `TMW.SNIPPETS` - Code snippets
- `TMW.HELP` - Help system
- `TMW.SUG` - Suggestion system

### Version Info

- `TELLMEWHEN_VERSION` - Version string (e.g., "12.0.3")
- `TELLMEWHEN_VERSION_MINOR` - Minor version
- `TELLMEWHEN_VERSION_FULL` - Full version string
- `TELLMEWHEN_VERSIONNUMBER` - Numeric version (e.g., 12000303)

---

## Formatter Class

The Formatter class provides text formatting utilities:

```lua
-- Create formatter
local formatter = TMW.C.Formatter:New("%.2f")
local text = formatter:Format(3.14159)  -- "3.14"

-- Built-in formatters
Formatter.NONE           -- No formatting
Formatter.PASS           -- tostring()
Formatter.F_0            -- "%.0f"
Formatter.F_1            -- "%.1f"
Formatter.F_2            -- "%.2f"
Formatter.PERCENT        -- "%s%%"
Formatter.PERCENT100     -- Multiply by 100 and add %
Formatter.PERCENT100_F0  -- Same but no decimals
Formatter.D_SECONDS      -- "X Seconds"
Formatter.TIME_COLONS    -- "1:23:45"
Formatter.TIME_YDHMS     -- "1y 2d 3h 4m 5s"
Formatter.COMMANUMBER    -- "1,234,567"
Formatter.BOOL           -- TRUE/FALSE
```

---

## Comparison Functions

```lua
TMW.CompareFuncs = {
    ["=="] = function(a, b) return a == b end,
    ["~="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"]  = function(a, b) return a < b end,
    [">"]  = function(a, b) return a > b end,
}
```

---

## Cache Tables

```lua
-- String lowercasing cache
TMW.strlowerCache[str]  -- Returns lowercased string

-- Number check cache
TMW.isNumber[val]  -- Returns true if val is number

-- Spell texture cache
TMW.spellTextureCache[spell]  -- Returns texture path
```

---

## Usage Examples

### Tracking Cooldowns

```lua
-- Get spell cooldown
local cd = TMW.COMMON.Cooldowns.GetSpellCooldown("Fireball")
if cd then
    local start, duration = cd.startTime, cd.duration
    local remaining = duration - (TMW.time - start)
    print("Remaining:", remaining)
end

-- Check if on GCD
if not TMW.OnGCD(cd.duration) then
    print("Not a GCD!")
end
```

### Working with Spells

```lua
-- Parse spell string
local spells = TMW:GetSpells("Fireball; Frostbolt; Arcane Blast")

-- Get first spell
local first = spells.FirstString  -- "Fireball"

-- Iterate all spells
for _, spell in ipairs(spells.StringArray) do
    print("Spell:", spell)
end

-- Check if spell is in set
if spells.Hash["Frostbolt"] then
    print("Has Frostbolt!")
end
```

### Unit Tracking

```lua
-- Get units with conditions
local units = TMW:GetUnits(icon, "target; focus; party1-4", {
    {Type = "HEALTH", Level = 50, Operator = "<="}
})

-- Process units
for _, unit in ipairs(units) do
    if UnitHealth(unit) / UnitHealthMax(unit) <= 0.5 then
        print(unit, "is low health!")
    end
end
```

### Using Counters

```lua
-- Set counter
TMW:ChangeCounter("Combo", "set", 0)

-- Increment counter
TMW:ChangeCounter("Combo", "add", 1)

-- Read counter
local comboPoints = TMW.COUNTERS.Combo
```

---

## Appendix

### Version Compatibility

- Built for WoW 12.0.3 (The War Within)
- Compatible with Classic Era, Season of Discovery, Cata Classic, and Retail
- Uses expansion detection for feature availability
- Handles API changes across WoW versions

### Performance Considerations

- Function caching used extensively for performance
- Per-frame caching for cooldown/charge lookups
- Event-driven updates minimize CPU usage
- Coroutine-based updates for large configurations

### Thread Safety

TMW is not thread-safe and must be called from the main thread only. Do not call TMW functions from:
- SecureActionButtonTemplate handlers during combat
- Async callbacks (C_Timer callbacks are safe)
- Coroutines not managed by TMW

---

## Support Resources

- **GitHub:** https://github.com/ascott18/TellMeWhen
- **CurseForge:** https://www.curseforge.com/wow/addons/tellmewhen
- **Discord:** Available through project pages

---

*This documentation covers TellMeWhen 12.0.3. For the most up-to-date information, consult the source code or official documentation.*
