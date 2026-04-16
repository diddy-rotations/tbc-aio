# Cat Rotation Simplification Design

**Date:** 2026-04-12
**Branch:** matt-cat

## Summary

Simplify the cat rotation by removing positional checks (`is_behind`), replacing the mangle builder fallback with a force-mangle option, and removing energy pooling and smart shift delay. Adjust defaults for rake and AoE.

## Changes

### 1. Remove `is_behind` from Druid

- **class.lua**: Remove `ctx.is_behind = Player:IsBehind(0.3)` from `extend_context`
- **cat.lua**: Remove `requires_behind` from `check_prerequisites`, remove `requires_behind` property from all strategies (`Cat_ClearcastingShred`, `Cat_Shred`, `Cat_StealthRavage`, `Cat_StealthShred`, `Cat_WolfsheadShred`)

### 2. Replace Mangle Builder with Force Mangle

- **schema.lua**: Remove `use_mangle_builder` checkbox. Add `force_mangle` checkbox (default off, tooltip: "Always use Mangle instead of Shred. Enable when you cannot reliably get behind the target.")
- **cat.lua**:
  - `Cat_Shred`: Skip if `force_mangle` on or target is targeting player
  - `Cat_ClearcastingShred`: Same — skip if `force_mangle` or target targeting player
  - `Cat_MangleBuilder`: Fire when `force_mangle` on OR target targeting player OR tick optimization. Remove old `is_behind`/`use_mangle_builder` gating
  - Add `target_targeting_us` to `cat_state` (computed once per frame)

### 3. Remove Energy Pooling

- **schema.lua**: Remove `cat_energy_pooling` checkbox
- **cat.lua**: Remove `pooling` field from `cat_state`, remove all `state.pooling` checks from every strategy

### 4. Remove Smart Shift Delay

- **schema.lua**: Remove `cat_smart_shift_delay` checkbox
- **cat.lua**: Remove all `cat_smart_shift_delay` checks from shift strategies, remove `should_delay_shift` from `cat_state`

### 5. Default Changes

- **schema.lua**: `enable_aoe` default `true` -> `false`, `spread_rake` default `true` -> `false`
- `maintain_rake` already defaults to `false` (confirmed)

## Files Touched

- `rotation/source/aio/druid/schema.lua`
- `rotation/source/aio/druid/cat.lua`
- `rotation/source/aio/druid/class.lua`

## Not Touched

- Rogue `is_behind` (stays as-is)
- Bear/Balance/Resto strategies
- `Cat_StealthMangle` (independent stealth opener option)
