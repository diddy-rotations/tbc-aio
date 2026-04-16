# Shadow Priest Rotation Improvements Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve shadow priest rotation with proper TTD gating for dots, AoE blanket-first priority, and execute phase for dying targets.

**Architecture:** Three independent changes to `shadow.lua` and one schema addition. The shadow_state cache gains two new flags (`in_aoe`, `execute_phase`) that gate strategy execution. AoE strategies move higher in priority and single-target strategies defer when in AoE mode.

**Tech Stack:** Lua 5.1 (WoW addon), Node.js build system

---

### Task 1: Add `shadow_execute_ttd` Setting to Schema

**Files:**
- Modify: `rotation/source/aio/priest/schema.lua:104-107` (Shadow Tab 2, AoE section)

**Step 1: Add the execute phase setting**

In `schema.lua`, add a new section after the existing AoE section (line 107). Insert between the AoE `}},` and the Mana Conservation header:

```lua
        { header = "Execute Phase", settings = {
            { type = "slider", key = "shadow_execute_ttd", default = 10, min = 5, max = 15, label = "Execute TTD (sec)",
              tooltip = "Skip DoTs when target dies within this many seconds. Uses MB > SW:D > MF only.", format = "%d sec" },
        }},
```

**Step 2: Build and verify schema loads**

Run: `cd rotation && node build.js`
Expected: Build succeeds with no errors.

**Step 3: Commit**

```bash
git add rotation/source/aio/priest/schema.lua
git commit -m "priest(shadow): add execute phase TTD setting to schema"
```

---

### Task 2: Fix VT TTD Gate and Add Execute Phase + AoE Flags to Shadow State

**Files:**
- Modify: `rotation/source/aio/priest/shadow.lua:40-67` (shadow_state + get_shadow_state)

**Step 1: Add `in_aoe` and `execute_phase` to shadow_state**

Update the `shadow_state` table (line 40) to add two new fields:

```lua
local shadow_state = {
    vt_remaining = 0,
    swp_active = false,
    ve_remaining = 0,
    mb_ready = false,
    swd_ready = false,
    swd_safe = false,
    inner_focus_ready = false,
    in_aoe = false,
    execute_phase = false,
}
```

**Step 2: Compute the new flags in get_shadow_state**

At the end of `get_shadow_state` (before `return shadow_state` on line 66), add:

```lua
    -- AoE mode: enough enemies for blanket DoT spreading
    shadow_state.in_aoe = context.enemy_count >= (context.settings.shadow_aoe_count or 4)

    -- Execute phase: target dying soon, skip DoTs and nuke
    local execute_ttd = context.settings.shadow_execute_ttd or 10
    shadow_state.execute_phase = context.ttd > 0 and context.ttd <= execute_ttd
```

**Step 3: Fix VT TTD gate**

In the VampiricTouch strategy matches function (line 170), change TTD threshold from 5 to 6:

Old (line 170):
```lua
         if context.ttd and context.ttd > 0 and context.ttd < 5 then
```

New:
```lua
         if context.ttd and context.ttd > 0 and context.ttd < 6 then
```

**Step 4: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add rotation/source/aio/priest/shadow.lua
git commit -m "priest(shadow): add execute/aoe state flags, fix VT TTD gate to 6s"
```

---

### Task 3: Gate DoT Strategies on Execute Phase

**Files:**
- Modify: `rotation/source/aio/priest/shadow.lua` (strategies 2-6: VE, VT, SWP, Starshards, DP)

Each DoT strategy's `matches` function needs an early return when `state.execute_phase` is true. Add this check right after the `in_combat` and `has_valid_enemy_target` checks in each strategy.

**Step 1: Add execute_phase gate to VampiricEmbrace (strategy 2)**

After the `has_valid_enemy_target` check (around line 135), add:

```lua
         if state.execute_phase then
            return false
         end
```

**Step 2: Add execute_phase gate to VampiricTouch (strategy 3)**

After the `has_valid_enemy_target` check (around line 165), add the same check.

**Step 3: Add execute_phase gate to ShadowWordPain (strategy 4)**

After the `has_valid_enemy_target` check (around line 189), add the same check.

**Step 4: Add execute_phase gate to Starshards (strategy 5)**

After the `has_valid_enemy_target` check (around line 215), add the same check.

**Step 5: Add execute_phase gate to DevouringPlague (strategy 6)**

After the `has_valid_enemy_target` check (around line 237), add the same check.

**Step 6: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 7: Commit**

```bash
git add rotation/source/aio/priest/shadow.lua
git commit -m "priest(shadow): skip all DoTs during execute phase (TTD-gated)"
```

---

### Task 4: Reorder AoE Strategies and Gate Single-Target on AoE Mode

This is the largest change. The AoE SWP/VT spread strategies move from positions 11-12 to positions 3-4 (between VE and single-target VT). Single-target SWP and VE are gated to skip during AoE mode.

**Files:**
- Modify: `rotation/source/aio/priest/shadow.lua` (reorder strategy array)

**Step 1: Move AoE SWP Spread to position 3 (after VE, before single-target VT)**

Cut the entire `AoESWPSpread` named strategy block (currently at position 11, lines 339-362) and paste it as the 3rd strategy in the array — right after `VampiricEmbrace` and before `VampiricTouch`.

**Step 2: Move AoE VT Spread to position 4 (after AoE SWP, before single-target VT)**

Cut the entire `AoEVTSpread` named strategy block (currently at position 12, lines 364-390) and paste it right after `AoESWPSpread`.

New strategy order after this step:
1. EnsureShadowform
2. PreCombatPull
3. VampiricEmbrace
4. **AoESWPSpread** (moved up)
5. VampiricTouch (single-target)
6. **AoEVTSpread** (moved up)
7. ShadowWordPain (single-target)
8. Starshards
9. DevouringPlague
10. InnerFocus
11. MindBlast
12. ShadowWordDeath
13. Racial
14. MindFlay
15. LowManaPWS

**Step 3: Gate single-target SWP on `not state.in_aoe`**

In the ShadowWordPain strategy `matches` (now at position 7), add after the `execute_phase` check:

```lua
         -- In AoE mode, SWP spread covers all targets including main
         if state.in_aoe then
            return false
         end
```

**Step 4: Gate VE on `not state.in_aoe`**

In VampiricEmbrace `matches` (position 3), add after the `execute_phase` check:

```lua
         -- In AoE mode, VE deferred until all DoTs blanketed (AoE strategies run first)
         if state.in_aoe then
            return false
         end
```

Wait — this would skip VE entirely during AoE. We need VE to fire AFTER dots are spread. Let's restructure:

Actually, VE stays at position 3 but gains the `in_aoe` gate. Then we add a NEW VE strategy at a lower position (after AoE VT spread) that only fires in AoE mode. But that duplicates logic.

**Better approach:** Move VE below AoE VT spread. New order:

1. EnsureShadowform
2. PreCombatPull
3. **AoESWPSpread** (moved up)
4. VampiricTouch (single-target — serves as "VT main target" in AoE too)
5. **AoEVTSpread** (moved up)
6. **VampiricEmbrace** (moved down from position 3)
7. ShadowWordPain (single-target, gated `not in_aoe`)
8. Starshards
9. DevouringPlague
10. InnerFocus
11. MindBlast
12. ShadowWordDeath
13. Racial
14. MindFlay
15. LowManaPWS

This way in AoE mode the flow is:
- AoE SWP spread all → VT main target → AoE VT spread others → VE main target → MB → SWD → MF

And in single-target mode:
- VT → VE → SWP → ... (VE now fires after VT instead of before — this is fine since VT is higher priority than VE anyway and the old VE-before-VT was just for convenience, not DPS optimization)

**Step 5: Gate single-target SWP on `not state.in_aoe`**

Add to ShadowWordPain matches:

```lua
         if state.in_aoe then
            return false
         end
```

**Step 6: Add TTD gating to AoE spread strategies**

In `AoESWPSpread` execute, inside the `for unitID` loop, add TTD check before applying:

```lua
               local unit_ttd = Unit(unitID):TimeToDie() or 0
               if unit_ttd > 0 and unit_ttd < 6 then
                  -- Skip: won't survive 2 ticks
               else
```

Wrap the existing SWP check inside that else block. Same pattern for `AoEVTSpread`.

Alternatively, restructure the loop condition more cleanly:

```lua
         for unitID in pairs(plates) do
            if UnitExists(unitID) and not Unit(unitID):IsDead() then
               local unit_ttd = Unit(unitID):TimeToDie() or 0
               local survives = unit_ttd == 0 or unit_ttd >= 6
               if survives then
                  local swp = (Unit(unitID):HasDeBuffs(A.ShadowWordPain.ID, "player", true) or 0)
                  if swp == 0 and A.ShadowWordPain:IsReady(unitID) then
                     return try_cast_fmt(A.ShadowWordPain, icon, unitID, "[SHADOW]", "AoE SW:P", "on %s", unitID)
                  end
               end
            end
         end
```

Same pattern for VT spread (unit_ttd >= 6).

**Step 7: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 8: Commit**

```bash
git add rotation/source/aio/priest/shadow.lua
git commit -m "priest(shadow): reorder AoE blanket-first, gate SWP single-target, add TTD to AoE spread"
```

---

### Task 5: Final Build and Verification

**Step 1: Full build**

Run: `cd rotation && node build.js`
Expected: Build succeeds, `output/TellMeWhen.lua` generated.

**Step 2: Review final strategy order**

Read `shadow.lua` and verify the strategy registration order matches:

1. EnsureShadowform
2. PreCombatPull
3. AoESWPSpread (AoE blanket)
4. VampiricTouch (single-target / main target)
5. AoEVTSpread (AoE blanket)
6. VampiricEmbrace (after dots)
7. ShadowWordPain (gated: not in_aoe, not execute_phase)
8. Starshards (gated: not execute_phase)
9. DevouringPlague (gated: not execute_phase)
10. InnerFocus
11. MindBlast
12. ShadowWordDeath
13. Racial
14. MindFlay
15. LowManaPWS

**Step 3: Verify behavior matrix**

| Scenario | Expected Flow |
|----------|---------------|
| Single target, TTD > 10s | VT → VE → SWP → IF+MB → SWD → MF |
| Single target, TTD ≤ 10s (execute) | IF+MB → SWD → MF (no dots) |
| AoE (≥ threshold), TTD > 10s | SWP all → VT main → VT spread → VE main → MB → SWD → MF |
| AoE, some targets TTD < 6s | SWP/VT spread skips dying units |
| Moving | Instant spells only (SWP, SWD, racials) |
| Low mana | DoTs maintained, shield self, wand filler |

**Step 4: Commit if any cleanup needed**

```bash
git add rotation/source/aio/priest/shadow.lua
git commit -m "priest(shadow): final cleanup and verification"
```
