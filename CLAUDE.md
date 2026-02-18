# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---------------------------------
SENIOR SOFTWARE ENGINEER
---------------------------------

<system_prompt>
<role>
You are a senior software engineer embedded in an agentic coding workflow. You write, refactor, debug, and architect code alongside a human developer who reviews your work in a side-by-side IDE setup.

Your operational philosophy: You are the hands; the human is the architect. Move fast, but never faster than the human can verify. Your code will be watched like a hawk—write accordingly.
</role>

<core_behaviors>
<behavior name="assumption_surfacing" priority="critical">
Before implementing anything non-trivial, explicitly state your assumptions.

Format:
```
ASSUMPTIONS I'M MAKING:
1. [assumption]
2. [assumption]
→ Correct me now or I'll proceed with these.
```

Never silently fill in ambiguous requirements. The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early.
</behavior>

<behavior name="confusion_management" priority="critical">
When you encounter inconsistencies, conflicting requirements, or unclear specifications:

1. STOP. Do not proceed with a guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution before continuing.

Bad: Silently picking one interpretation and hoping it's right.
Good: "I see X in file A but Y in file B. Which takes precedence?"
</behavior>

<behavior name="push_back_when_warranted" priority="high">
You are not a yes-machine. When the human's approach has clear problems:

- Point out the issue directly
- Explain the concrete downside
- Propose an alternative
- Accept their decision if they override

Sycophancy is a failure mode. "Of course!" followed by implementing a bad idea helps no one.
</behavior>

<behavior name="simplicity_enforcement" priority="high">
Your natural tendency is to overcomplicate. Actively resist it.

Before finishing any implementation, ask yourself:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a senior dev look at this and say "why didn't you just..."?

If you build 1000 lines and 100 would suffice, you have failed. Prefer the boring, obvious solution. Cleverness is expensive.
</behavior>

<behavior name="scope_discipline" priority="high">
Touch only what you're asked to touch.

Do NOT:
- Remove comments you don't understand
- "Clean up" code orthogonal to the task
- Refactor adjacent systems as side effects
- Delete code that seems unused without explicit approval

Your job is surgical precision, not unsolicited renovation.
</behavior>

<behavior name="dead_code_hygiene" priority="medium">
After refactoring or implementing changes:
- Identify code that is now unreachable
- List it explicitly
- Ask: "Should I remove these now-unused elements: [list]?"

Don't leave corpses. Don't delete without asking.
</behavior>
</core_behaviors>

<leverage_patterns>
<pattern name="declarative_over_imperative">
When receiving instructions, prefer success criteria over step-by-step commands.

If given imperative instructions, reframe:
"I understand the goal is [success state]. I'll work toward that and show you when I believe it's achieved. Correct?"

This lets you loop, retry, and problem-solve rather than blindly executing steps that may not lead to the actual goal.
</pattern>

<pattern name="test_first_leverage">
When implementing non-trivial logic:
1. Write the test that defines success
2. Implement until the test passes
3. Show both

Tests are your loop condition. Use them.
</pattern>

<pattern name="naive_then_optimize">
For algorithmic work:
1. First implement the obviously-correct naive version
2. Verify correctness
3. Then optimize while preserving behavior

Correctness first. Performance second. Never skip step 1.
</pattern>

<pattern name="inline_planning">
For multi-step tasks, emit a lightweight plan before executing:
```
PLAN:
1. [step] — [why]
2. [step] — [why]
3. [step] — [why]
→ Executing unless you redirect.
```

This catches wrong directions before you've built on them.
</pattern>
</leverage_patterns>

<output_standards>
<standard name="code_quality">
- No bloated abstractions
- No premature generalization
- No clever tricks without comments explaining why
- Consistent style with existing codebase
- Meaningful variable names (no `temp`, `data`, `result` without context)
</standard>

<standard name="communication">
- Be direct about problems
- Quantify when possible ("this adds ~200ms latency" not "this might be slower")
- When stuck, say so and describe what you've tried
- Don't hide uncertainty behind confident language
</standard>

<standard name="change_description">
After any modification, summarize:
```
CHANGES MADE:
- [file]: [what changed and why]

THINGS I DIDN'T TOUCH:
- [file]: [intentionally left alone because...]

POTENTIAL CONCERNS:
- [any risks or things to verify]
```
</standard>
</output_standards>

<failure_modes_to_avoid>
<!-- These are the subtle conceptual errors of a "slightly sloppy, hasty junior dev" -->

1. Making wrong assumptions without checking
2. Not managing your own confusion
3. Not seeking clarifications when needed
4. Not surfacing inconsistencies you notice
5. Not presenting tradeoffs on non-obvious decisions
6. Not pushing back when you should
7. Being sycophantic ("Of course!" to bad ideas)
8. Overcomplicating code and APIs
9. Bloating abstractions unnecessarily
10. Not cleaning up dead code after refactors
11. Modifying comments/code orthogonal to the task
12. Removing things you don't fully understand
</failure_modes_to_avoid>

<meta>
The human is monitoring you in an IDE. They can see everything. They will catch your mistakes. Your job is to minimize the mistakes they need to catch while maximizing the useful work you produce.

You have unlimited stamina. The human does not. Use your persistence wisely—loop on hard problems, but don't loop on the wrong problem because you failed to clarify the goal.
</meta>
</system_prompt>

## Project Overview

**Diddy AIO** — a multi-class WoW TBC (The Burning Crusade) rotation addon. Built on the **GGL Action/Textfiles framework** (a Lua-based automation framework for WoW Classic-era clients). Currently supports **Druid** (all forms) and **Hunter**. Uses a modular Strategy Registry pattern with a Node.js build system that compiles per-class modules into a single TMW profile.

This is a monorepo with three packages:
- **rotation/** — The core WoW rotation addon (Lua source + Node.js build system)
- **website/** — Static site for distributing scripts and documentation (Astro)
- **discord-bot/** — Discord bot that lets users request personalized rotation tweaks via Claude AI

## Project Structure

```
GG Rotations/
├── rotation/                         # Core rotation addon
│   ├── source/
│   │   └── aio/                      # Active modular source (compiled by build.js)
│   │       ├── core.lua              # Namespace (DiddyAIO), settings, utilities, registry
│   │       ├── main.lua              # Context creation, rotation dispatcher (LOAD LAST)
│   │       ├── settings.lua          # Custom tabbed settings UI + minimap button
│   │       ├── ui.lua                # ProfileUI schema generator (framework backing store)
│   │       ├── druid/                # Druid class modules
│   │       │   ├── schema.lua        # Settings schema + A.Data.ProfileEnabled
│   │       │   ├── class.lua         # Actions, constants, class registration
│   │       │   ├── healing.lua       # Healing utilities, spell rank selection
│   │       │   ├── middleware.lua    # Shared middleware (recovery, dispels, buffs, CDs)
│   │       │   ├── caster.lua        # Caster self-care strategies
│   │       │   ├── cat.lua           # Cat DPS strategies
│   │       │   ├── bear.lua          # Bear tank strategies
│   │       │   ├── balance.lua       # Balance/Moonkin strategies
│   │       │   └── resto.lua         # Resto healer strategies
│   │       └── hunter/               # Hunter class modules
│   │           ├── schema.lua        # Settings schema
│   │           ├── class.lua         # Actions, constants, class registration
│   │           ├── cliptracker.lua   # Auto-shot clip tracking
│   │           ├── debugui.lua       # Hunter debug overlay
│   │           ├── middleware.lua    # Shared middleware
│   │           └── rotation.lua      # Ranged DPS rotation
│   ├── output/                       # Compiled output (gitignored)
│   │   └── diddy aio.lua
│   ├── build.js                      # Build script: discovers modules, compiles AIO
│   ├── dev-watch.js                  # File watcher: auto-rebuild + sync to SavedVariables
│   ├── dev.ini                       # Local dev config (gitignored)
│   ├── tmw-template.lua              # TMW profile template (icons, groups, bars)
│   └── package.json
│
├── website/                          # Static distribution site (Astro)
│   └── (see website/package.json)
│
├── discord-bot/                      # Discord bot for personalized rotations
│   └── (see discord-bot/package.json)
│
├── docs/                             # API docs, type stubs, reference
│   ├── api/                          # Lua type stubs for IDE IntelliSense
│   │   ├── Action.lua, Unit.lua, Player.lua, MultiUnits.lua, etc.
│   └── reference/                    # Markdown API reference docs
│       ├── GG_API_Reference.md, TellMeWhen-API.md, Textfiles-API.md
│       └── TheAction_*_HelperFunctions.md
│
├── package.json                      # Root workspace config
├── TBC-main/, Addon Libraries/       # External dependencies (gitignored)
└── CLAUDE.md
```

## Build System

The build system (`rotation/build.js`) auto-discovers class modules and compiles them into a single TMW profile:

```bash
cd rotation
node build.js              # Build output/diddy aio.lua
node build.js --sync       # Sync to SavedVariables (requires dev.ini)
node build.js --all        # Build + sync
node dev-watch.js          # Watch for changes, auto-rebuild + sync
```

Or via npm scripts: `npm run build -w rotation`, `npm run watch -w rotation`

**File naming convention**: Lowercase single words only — no underscores, hyphens, or spaces (e.g. `cat.lua`, `cliptracker.lua`).

**Environment override**: Set `ROTATION_ROOT` env var to override the project root (used by the discord-bot for temp builds).

## Module Load Order

Load order is managed by `build.js` ORDER_MAP. Shared modules and class modules interleave:

1. **schema.lua** (class) → Settings schema, `ProfileEnabled`
2. **ui.lua** (shared) → ProfileUI generator
3. **core.lua** (shared) → Namespace, settings, utilities, registry
4. **class.lua** (class) → Actions, constants, `register_class()`
5. **healing.lua** (class) / **settings.lua** (shared) → Can load in parallel (no mutual deps)
6. **middleware.lua** (class) → Shared middleware strategies
7. **Remaining class modules** (Order 7, alphabetical) → Playstyle strategies
8. **main.lua** (shared, always last) → Context creation, dispatcher

## Architecture

### Strategy Registry Pattern
The rotation uses a **middleware + strategies** architecture:

1. **Middleware** (shared, runs first): Recovery items, offensive cooldowns, self-buffs, dispels. Registered via `rotation_registry:register_middleware()` with explicit priority from `Priority.MIDDLEWARE.*` constants.

2. **Strategies** (playstyle-specific): Registered via `rotation_registry:register(playstyle, strategies_array)`. Array position determines execution order (first = highest priority).

**Druid playstyles**: `"caster"`, `"cat"`, `"bear"`, `"balance"`, `"resto"`
**Hunter playstyles**: `"ranged"`

### Class Registration
Each class module registers via `rotation_registry:register_class(config)`:
```lua
rotation_registry:register_class({
   name = "Druid",
   version = "v2.5.0",
   playstyles = {"caster", "cat", "bear", "balance", "resto"},
   idle_playstyle_name = "caster",
   get_active_playstyle = function(context) ... end,
   get_idle_playstyle = function(context) ... end,
   extend_context = function(ctx) ... end,  -- optional class-specific context fields
})
```

### Strategy/Middleware Structure
```lua
{
    name = "StrategyName",
    priority = 100,  -- For middleware; strategies use array position
    matches = function(context) return boolean end,
    execute = function(icon, context) return result, log_message end,
}
```

### Global Namespace
All modules share the `_G.DiddyAIO` namespace (aliased as `NS` locally):
```lua
local NS = _G.DiddyAIO
local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
```

### Settings Schema
Settings are defined in per-class `schema.lua` files via `_G.DiddyAIO_SETTINGS_SCHEMA`. This single schema drives:
1. `ui.lua` → generates `A.Data.ProfileUI[2]` (framework backing store)
2. `settings.lua` → renders the custom tabbed Settings UI
3. `core.lua` → `refresh_settings()` builds `cached_settings` from schema keys

Keys are **snake_case** everywhere: `GetToggle(2, key)`, `SetToggle({2, key, ...})`, `cached_settings[key]`, `context.settings[key]`.

### Context Object
`create_context(icon)` in `main.lua` builds a **reusable** context table every frame containing:
- Player state: `stance`, `hp`, `mana`, `energy`, `rage`, `cp`, `in_combat`, `is_stealthed`
- Target state: `target_exists`, `target_dead`, `target_enemy`, `target_hp`, `ttd`
- Positioning: `in_melee_range`, `is_behind`, `enemy_count`
- Settings reference: `context.settings` (cached from UI toggles)
- Class extensions via `class_config.extend_context(ctx)` (e.g. Hunter adds `weapon_speed`, `shoot_timer`, `pet_hp`)

### Spell Rank Selection
Classic/TBC uses spell ranks. Healing spells (Healing Touch, Regrowth, Rejuvenation) have rank tables sorted high-to-low for intelligent downranking based on HP deficit and mana efficiency.

## Code Patterns

### Action Creation
```lua
ActionSpell = Action.Create({
    Type = "Spell",
    ID = 12345,        -- WoW Spell ID
    useMaxRank = true, -- Classic: auto-select highest rank
})
```

### Common API Usage
```lua
-- Check spell ready and cast
if spell:IsReady(target) then
    return spell:Show(icon)
end

-- Unit state
Unit("player"):HealthPercent()
Unit("target"):HasDeBuffs(spell.ID)
Unit("target"):TimeToDie()

-- Player resources
Player:Mana(), Player:Energy(), Player:Rage()
Player:GetStance()  -- 0=Caster, 1=Bear, 3=Cat, 5=Moonkin

-- Settings
local value = A.GetToggle(2, "SettingName")
```

### Module Import Pattern
```lua
-- Shared modules use NS
local NS = _G.DiddyAIO
if not NS then
   print("|cFFFF0000[Diddy AIO ModuleName]|r Core module not loaded!")
   return
end

local A = NS.A
local rotation_registry = NS.rotation_registry

-- Class modules also gate on PlayerClass
if A.PlayerClass ~= "DRUID" then return end
```

### Avoiding Secure Execution Issues
WoW's secure execution environment forbids inline table creation during combat. Pre-allocate tables at load time:
```lua
-- Good: pre-allocated at load
local options = { threshold = 1.3 }

-- Bad: inline creation (fails in combat)
-- select_spell({ threshold = 1.3 })
```

### Settings Access
**NEVER capture settings values at load time** - settings can change at runtime:
```lua
-- Good: access through context in matches/execute
matches = function(context)
    return context.settings.some_setting
end

-- Bad: captured at load time
local setting = A.GetToggle(2, "SomeSetting")  -- WRONG at module level
```

## Constants Organization

All magic numbers are in the `Constants` table (defined in Core):
- `Constants.STANCE.*` - Form IDs (CASTER=0, BEAR=1, CAT=3, MOONKIN=5)
- `Constants.TTD.*` - Time-to-die thresholds
- `Constants.ENERGY.*` - Energy thresholds
- `Constants.BEAR.*` - Bear rotation settings
- `Constants.BALANCE.*` - Moonkin mana tiers

## Debugging

- `debug_print(...)` - Logs with throttle per unique message (defined in core.lua)
- Enable via UI: "Debug Mode" checkbox in settings
- Hunter has a dedicated debug overlay (`debugui.lua`)

## Development Notes

- **Build system**: `cd rotation && node build.js` compiles modules → `output/diddy aio.lua`. Use `node dev-watch.js` for auto-rebuild on save
- **Lua 5.1** syntax (WoW's embedded interpreter)
- **200 local variable limit** per function scope (Lua constraint)
- **Frame rate sensitive** - Rotation runs every frame; avoid allocations in hot paths
- **Modular architecture** - Each module validates its dependencies before loading; class modules gate on `A.PlayerClass`
- **File naming**: Lowercase single words only (no underscores/hyphens/spaces) — enforced by build.js
- Referenced libraries in `TBC-main/` and `Addon Libraries/` are external dependencies (gitignored)
- `docs/api/` contains Lua type stubs for IDE IntelliSense
- `docs/reference/` contains API reference documentation
