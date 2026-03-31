# Shadow Priest Rotation Improvements Design

**Date**: 2026-03-31
**Scope**: `rotation/source/aio/priest/shadow.lua`, `rotation/source/aio/priest/schema.lua`

## Changes

### 1. TTD Checks for DoTs (2-tick minimum)

SWP and VT both tick every 3s. A DoT that doesn't get 2 ticks wastes the GCD.

| Spell | Current TTD Gate | New TTD Gate | Rationale |
|-------|-----------------|--------------|-----------|
| SWP | `< 6` | `< 6` (no change) | 2 ticks × 3s = 6s |
| VT | `< 5` | `< 6` | Was 5s, should be 6s for 2 full ticks |
| VE | `< 6` | No change | Already correct |
| DP | `< 8` | No change | 3min CD deserves extra cushion |
| AoE SWP spread | None | `< 6` | Skip dying units |
| AoE VT spread | None | `< 6` | Skip dying units |

### 2. AoE Priority Reorder

When `enemy_count >= shadow_aoe_count`, rotation reshuffles to blanket-first.

**Current order** (AoE at positions 11-12, after all single-target):
```
Shadowform → Pull → VE → VT → SWP → Starshards → DP → IF → MB → SWD → Racial → AoE SWP → AoE VT → MF → LowManaPWS
```

**New order** when above AoE threshold:
```
Shadowform → Pull → SWP spread ALL → VT main → VT spread others → VE main → MB → SWD → MF
```

Key changes:
- SWP spread moves up, fires before single-target VT
- VT on main target fires next (existing single-target strategy)
- VT spread to other targets fires after main target VT
- VE moves AFTER all dots are blanketed (don't waste GCD on VE when dots need spreading)
- Starshards, DP, IF, Racial still fire in their normal positions outside AoE mode
- Single-target SWP strategy skips when in AoE mode (AoE spread covers main target)

Implementation: Add `in_aoe` flag to shadow_state. AoE strategies move to positions 3-5 (between VE and single-target VT). Existing strategies gate on `not state.in_aoe` where appropriate.

### 3. Execute Phase (Low-TTD Target)

New schema setting: `shadow_execute_ttd` (slider, default: 10, range: 5-15, step: 1, unit: "s").

When `ttd > 0 AND ttd <= shadow_execute_ttd`:
- Skip all DoT application (VT, SWP, VE, Starshards, DP)
- Priority: Inner Focus → MB → SWD → MF

Implementation: Add `execute_phase` boolean to shadow_state. Each DoT strategy returns false when `state.execute_phase` is true.

## Files Modified

- `rotation/source/aio/priest/shadow.lua` — All rotation changes
- `rotation/source/aio/priest/schema.lua` — New `shadow_execute_ttd` setting
