# Bear Rotation Optimization Design

**Date:** 2026-04-06
**Status:** Approved
**Reference:** wowsims/tbc sim (`sim/druid/tank/rotation.go`, `maul.go`, `lacerate.go`, `swipe.go`)

## Problem

Bear rotation has three issues visible in combat logs and WCL data:

1. **Swipe fires on single target** — wastes rage on low-value filler, starving Maul
2. **Maul barely queues** — starvation logic doesn't properly protect Mangle's rage when Maul is pending
3. **Lacerate constants are broken** — `LACERATE_SWIPE_THRESHOLD = 3` equals `LACERATE_URGENT_REFRESH = 3`, making the normal-priority refresh path dead code

Top WCL bears show Maul at 47-61% of damage. Current implementation is well below that.

## Changes

### 1. Swipe ST Filler Toggle (default OFF)

Add boolean setting `swipe_st_filler` (default `false`) to bear schema. When off, `Bear_Swipe` does not fire on single target — the bear auto-attacks + Mauls between Mangles.

When Lacerate is available (level 66+), Swipe ST also requires 5 Lacerate stacks with >3s remaining.

**Schema:** New checkbox in Bear > Rage Management section.

### 2. Maul Starvation Fix

Keep schema default threshold at 15. Fix `Bear_Maul.matches()` to account for Maul's delayed rage consumption:

Maul is queued now but consumed on the next melee swing (up to 2.5s later). Current `would_starve_mangle` uses a 0.5s window that's too narrow for this.

**New check in Maul matches:** If `rage < RAGE_COST_MAUL + RAGE_COST_MANGLE` and Mangle CD < swing time remaining, don't queue. This prevents the scenario where Maul eats the swing's rage right as Mangle comes off CD.

Existing `would_starve_mangle()` stays unchanged for GCD abilities (instant consumption).

### 3. GCD Priority Reorder

**Current:**
```
LacerateUrgent > FF > SwipeAoE > Mangle > DemoRoar > LacerateBuild > Swipe(ST)
```

**New:**
```
LacerateUrgent > FF > SwipeAoE > Mangle > LacerateBuild > Swipe(ST conditional) > DemoRoar
```

- LacerateBuild moves above Swipe — Lacerate is the primary filler
- DemoRoar drops to lowest GCD priority — defensive luxury
- Swipe ST becomes conditional on toggle + Lacerate state

### 4. Lacerate Constants Fix

| Constant | Old | New | Reason |
|---|---|---|---|
| `LACERATE_SWIPE_THRESHOLD` | 3 | 8 | Creates actual refresh window between urgent (3s) and normal priority |
| `LACERATE_URGENT_REFRESH` | 3 | 3 | Stays — emergency safety net |
| `LACERATE_BUILD_REFRESH` | 6 | 6 | Stays — controls stack-building reapplication cadence |

### 5. Swipe ST Lacerate Gate (future-proof for level 66+)

When Lacerate is available, `Bear_Swipe` adds condition:
- Lacerate stacks == 5 AND Lacerate duration > 3s

This matches the sim's conditional Swipe logic. Combined with the toggle, Swipe ST only fires when both the user enables it AND Lacerate is fully stacked.

## Files Modified

| File | Changes |
|---|---|
| `druid/bear.lua` | Maul starvation fix, Swipe ST conditional logic, strategy reorder, Lacerate gate |
| `druid/schema.lua` | Add `swipe_st_filler` checkbox |
| `druid/class.lua` | Fix `LACERATE_SWIPE_THRESHOLD` constant |

## Not Changed

- Maul position in strategy array (already correct)
- SwipeAoE logic (working correctly for multi-target)
- Enrage / Frenzied Regen logic (working correctly)
- Tab targeting (working correctly)
- Mangle hold window 0.5s (appropriate for GCD hold)
