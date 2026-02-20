--- Bear Module
--- Bear (Feral Tank) playstyle strategies
--- Part of the modular rotation system
--- Loads after: core.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime (e.g., playstyle switching).
-- Always access settings through context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Bear]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Bear]|r Registry not found in Core!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast_fmt = NS.try_cast_fmt
local is_spell_available = NS.is_spell_available
local get_debuff_state = NS.get_debuff_state
local get_time_until_swing = NS.get_time_until_swing
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local CONST = A.Const

-- Lua optimizations
local format = string.format

-- Debuff ID tables
local DEMO_ROAR_DEBUFF_IDS = NS.DEMO_ROAR_DEBUFF_IDS

-- Utility imports
local get_spell_rage_cost = NS.get_spell_rage_cost
local AddDebugLogLine = NS.AddDebugLogLine
local GetTime = _G.GetTime

-- Import factory functions from Core
local create_faerie_fire_strategy = NS.create_faerie_fire_strategy
local create_combat_strategy = NS.create_combat_strategy
local named = NS.named

-- ============================================================================
-- BEAR (FERAL TANK) STRATEGIES
-- ============================================================================
do
   -- Bear-local helpers
   local function get_swipe_threshold(ctx)
      return ctx.settings.swipe_min_targets or Constants.BEAR.DEFAULT_SWIPE_TARGETS
   end

   local function get_lacerate_info()
      return get_debuff_state(A.Lacerate, TARGET_UNIT, "player")
   end

   -- Check if Lacerate maintenance is enabled (spell available + settings allow it)
   local function should_maintain_lacerate(ctx)
      if not is_spell_available(A.Lacerate) then return false end
      if ctx.settings.maintain_lacerate == false then return false end
      if ctx.settings.lacerate_boss_only and not Unit(TARGET_UNIT):IsBoss() then return false end
      return true
   end

   -- Hold GCD for Mangle: sim explicitly waits for Mangle rather than
   -- wasting a 1.5s GCD on filler when Mangle is almost ready.
   -- Returns true if filler abilities should yield.
   local MANGLE_HOLD_WINDOW = 1.0  -- seconds; don't waste GCD if Mangle ready within this
   local function should_hold_for_mangle()
      if not is_spell_available(A.MangleBear) then return false end
      local cd = A.MangleBear:GetCooldown()
      return cd > 0 and cd <= MANGLE_HOLD_WINDOW
   end

   local function is_target_cc_locked(threshold)
      local cc_remaining = Unit(TARGET_UNIT):InCC() or 0
      return cc_remaining > threshold
   end

   local function is_targettarget_healer()
      if not _G.UnitExists("targettarget") then return false end
      return Unit("targettarget"):IsHealer() == true
   end

   -- Reliable aggro check: target is targeting us
   local function has_target_aggro()
      return _G.UnitExists("targettarget") and _G.UnitIsUnit("targettarget", PLAYER_UNIT)
   end

   -- AoE floor: when swipe_min=1, AoE optimization still kicks in at this enemy count
   local AOE_MIN_ENEMIES = 3

   -- Effective AoE threshold: respects user setting, but floors at AOE_MIN_ENEMIES for swipe_min=1
   -- When elites/bosses are in melee, raise threshold by 1 (Lacerate on elite is higher value)
   local function get_aoe_threshold(ctx, state)
      local swipe_min = get_swipe_threshold(ctx)
      local base = swipe_min <= 1 and AOE_MIN_ENEMIES or swipe_min
      if state and (state.nearby_bosses > 0 or state.nearby_elites > 0) then
         return base + 1
      end
      return base
   end

   -- CC safety: prevent Swipe from breaking nearby breakable CC
   -- Name-based checks (not "BreakAble" category) so we detect ANY caster's debuffs
   local SWIPE_CC_CHECK_RANGE = 10  -- yards; slightly wider than melee for safety
   local BREAKABLE_CC_NAMES = {
      "Polymorph",            -- Mage
      "Freezing Trap Effect", -- Hunter
      "Repentance",           -- Paladin
      "Blind",                -- Rogue
      "Sap",                  -- Rogue
      "Gouge",                -- Rogue
      "Hibernate",            -- Druid
      "Wyvern Sting",         -- Hunter
      "Scatter Shot",         -- Hunter
      "Shackle Undead",       -- Priest
      "Seduction"            -- Warlock (Succubus)
   }
   local NUM_BREAKABLE_CC = #BREAKABLE_CC_NAMES

   local function has_breakable_cc_nearby()
      local plates = A.MultiUnits:GetActiveUnitPlates()
      for unitID in pairs(plates) do
         if Unit(unitID):GetRange() <= SWIPE_CC_CHECK_RANGE then
            for i = 1, NUM_BREAKABLE_CC do
               if (Unit(unitID):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
                  return true
               end
            end
         end
      end
      return false
   end

   -- =========================================================================
   -- TAB TARGETING (multi-mob threat management)
   -- =========================================================================
   -- Determines when to switch targets to spread threat across multiple mobs.
   -- Priority:
   --   1. Switch OFF CC'd targets to valid ones
   --   2. Pick up loose mobs (not targeting us) when we're not managing too many
   --   3. Spread Lacerate stacks for DPS when below Swipe threshold
   local function is_target_breakable_cc()
      for i = 1, NUM_BREAKABLE_CC do
         if (Unit(TARGET_UNIT):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
            return true
         end
      end
      return false
   end

   local function should_tab_target(ctx, state)
      if not ctx.settings.enable_tab_targeting then return false end
      if ctx.enemy_count < 2 then return false end
      if _G.UnitIsPlayer(TARGET_UNIT) then return false end
      if Unit(TARGET_UNIT):CombatTime() == 0 then return false end

      -- Switch away from CC'd target to find a valid one
      if is_target_breakable_cc() then return true end

      -- Only switch if current target is valid and in melee range
      if _G.UnitExists(TARGET_UNIT) and not _G.UnitIsDead(TARGET_UNIT) and _G.UnitIsVisible(TARGET_UNIT) and ctx.in_melee_range then
         -- Only switch if we have solid aggro (threat >= 2) on current target
         local threat = Unit(TARGET_UNIT):ThreatSituation() or 0
         local hasAggro = threat >= 2 or (_G.UnitExists("targettarget") and _G.UnitIsUnit("targettarget", PLAYER_UNIT))

         if not hasAggro then
            -- Don't have aggro yet, stay on this target
            return false
         end

         -- Count mobs by aggro status, and find if there's a healthy target to switch to
         local mobsWithAggro = 0
         local mobsWithoutAggro = 0
         local maxMobsToManage = 4
         local mobsWithLowLacerate = 0

         local plates = A.MultiUnits:GetActiveUnitPlates()
         for unitID in pairs(plates) do
            if unitID
               and _G.UnitExists(unitID)
               and not _G.UnitIsDead(unitID)
               and not _G.UnitIsPlayer(unitID)
               and not _G.UnitIsUnit(unitID, TARGET_UNIT) -- Don't count current target
               and Unit(unitID):CombatTime() > 0
               and A.MangleBear:IsInRange(unitID) == true -- Only consider targets in melee range
               and (Unit(unitID):InCC() or 0) == 0 -- Don't count CC'd targets
            then
               local unitTTD = Unit(unitID):TimeToDie()
               local unitIsDying = unitTTD > 0 and unitTTD < 5

               -- Don't count dying mobs as needing pickup
               if not unitIsDying then
                  local unitThreat = _G.UnitThreatSituation(PLAYER_UNIT, unitID) or 0
                  local unitTargetingPlayer = _G.UnitExists(unitID .. "target") and _G.UnitIsUnit(unitID .. "target", PLAYER_UNIT)
                  local unitHasAggro = unitThreat >= 2 or unitTargetingPlayer

                  if unitHasAggro then
                     mobsWithAggro = mobsWithAggro + 1
                  else
                     mobsWithoutAggro = mobsWithoutAggro + 1
                  end

                  -- Count mobs with low lacerate stacks for DPS optimization
                  if is_spell_available(A.Lacerate) then
                     local unitLacerateStacks = Unit(unitID):HasDeBuffsStacks(A.Lacerate.ID, true)
                     if unitLacerateStacks < 3 then
                        mobsWithLowLacerate = mobsWithLowLacerate + 1
                     end
                  end
               end
            end
         end

         -- Switch if there are uncontrolled mobs and we're not already managing too many
         if mobsWithoutAggro > 0 and mobsWithAggro < maxMobsToManage then
            return true
         end

         -- DPS optimization: Spread lacerate on multi-target (but below swipe threshold)
         -- Only do this on non-boss fights to maximize DPS
         if not ctx.is_boss_fight and ctx.enemy_count >= 2 and ctx.enemy_count < 3 then
            local currentLacerateStacks = state.lacerate_stacks
            -- If current target has 3+ stacks and there are mobs with < 3 stacks, switch
            if currentLacerateStacks >= 3 and mobsWithLowLacerate > 0 then
               return true
            end
         end

         -- Stay on current target if we have aggro and it's in range
         return false
      end

      -- Target is invalid (doesn't exist, is dead, or out of range)
      -- Switch to find a valid in-range target
      if not _G.UnitExists(TARGET_UNIT) or _G.UnitIsDead(TARGET_UNIT) or not ctx.in_melee_range then
         return true
      end

      -- Should not reach here, but default to not switching
      return false
   end

   -- =========================================================================
   -- SHARED BEAR STATE (computed once per frame, cached)
   -- =========================================================================
   local bear_state = {
      maul_queued = false,     -- true while we're trying to queue Maul (spamming TMW:Fire)
      maul_confirmed = false,  -- true once IsSpellCurrent() confirms game accepted the queue
      maul_dequeue_logged = false, -- throttle: only log dequeue once per cycle
      lacerate_stacks = 0,
      lacerate_duration = 0,
      nearby_elites = 0,
      nearby_bosses = 0,
      nearby_trash = 0,
   }

   -- Rage costs (cached at load time, must be before CLEU handler)
   local RAGE_COST_MAUL = get_spell_rage_cost(A.Maul) or 15
   local RAGE_COST_MANGLE = get_spell_rage_cost(A.MangleBear) or 20
   local RAGE_COST_SWIPE = get_spell_rage_cost(A.Swipe) or 15
   local RAGE_COST_LACERATE = get_spell_rage_cost(A.Lacerate) or 10
   local RAGE_COST_DEMO_ROAR = get_spell_rage_cost(A.DemoralizingRoar) or 10

   -- =========================================================================
   -- BEAR CLEU TRACKER (swing-event Maul suppression)
   -- =========================================================================
   local player_guid = _G.UnitGUID(PLAYER_UNIT)
   local MAUL_SPELL_NAME = select(1, _G.GetSpellInfo(A.Maul.ID)) or "Maul"
   local cleu_frame = _G.CreateFrame("Frame")
   cleu_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   cleu_frame:SetScript("OnEvent", function()
      local _, event, _, srcGUID, _, _, _, _, destName, _, _, p12, p13, p14, p15, _, _, _, _, p20 = _G.CombatLogGetCurrentEventInfo()
      if srcGUID ~= player_guid then return end
      if event == "SWING_DAMAGE" or event == "SWING_MISSED" then
         if bear_state.maul_queued then
            bear_state.maul_queued = false
            bear_state.maul_confirmed = false
            bear_state.maul_dequeue_logged = false
         end
      elseif p13 == MAUL_SPELL_NAME then
         bear_state.maul_queued = false
         bear_state.maul_confirmed = false
         bear_state.maul_dequeue_logged = false
      end
   end)

   -- =========================================================================
   -- NAMEPLATE SCANNER (enemy classification by range)
   -- =========================================================================
   -- @param max_range: yard radius to check
   -- @param loose_only: if true, only count mobs NOT targeting us
   -- @return elites, bosses, trash
   local function count_nearby_enemies(max_range, loose_only)
      local plates = A.MultiUnits:GetActiveUnitPlates()
      local elites, bosses, trash = 0, 0, 0
      for unitID in pairs(plates) do
         if loose_only then
            local tt = unitID .. "target"
            if not _G.UnitExists(tt) or _G.UnitIsUnit(tt, PLAYER_UNIT) then
               -- Skip: either no target (idle) or already targeting us
               unitID = nil
            end
         end
         if unitID then
            local range = Unit(unitID):GetRange()
            if range <= max_range then
               local class = _G.UnitClassification(unitID)
               if class == "worldboss" then
                  bosses = bosses + 1
               elseif class == "elite" or class == "rareelite" then
                  elites = elites + 1
               else
                  trash = trash + 1
               end
            end
         end
      end
      return elites, bosses, trash
   end

   local function get_bear_state(context)
      if context._bear_valid then return bear_state end
      context._bear_valid = true

      if bear_state.maul_queued then
         local isc = A.Maul:IsSpellCurrent()
         if not bear_state.maul_confirmed and isc then
            bear_state.maul_confirmed = true
            AddDebugLogLine(format("[%.3fs] [MAUL] Confirmed by IsSpellCurrent", GetTime()))
         elseif bear_state.maul_confirmed and not isc then
            --bear_state.maul_queued = false
            --bear_state.maul_confirmed = false
            -- Log once, not every frame (CLEU will clear state authoritatively)
            if not bear_state.maul_dequeue_logged then
               bear_state.maul_dequeue_logged = true
               AddDebugLogLine(format("[%.3fs] [MAUL] Dequeued (IsSpellCurrent lost, awaiting CLEU)", GetTime()))
            end
         end
      end

      bear_state.lacerate_stacks, bear_state.lacerate_duration = get_lacerate_info()
      -- Classification breakdown at melee range (5yd) for Swipe/Maul/Lacerate decisions
      bear_state.nearby_elites, bear_state.nearby_bosses, bear_state.nearby_trash = count_nearby_enemies(5, false)
      return bear_state
   end

   -- Maul rage reservation: prevent other abilities from de-queuing Maul
   -- Clearcasting = free ability, can't starve anything
   local function would_starve_maul(ctx, rage_cost)
      if ctx.has_clearcasting then return false end
      return bear_state.maul_confirmed and (ctx.rage - rage_cost) < RAGE_COST_MAUL
   end

   -- Mangle rage reservation: returns true if spending rage_cost would leave us
   -- unable to Mangle when it's ready or coming off CD soon.
   local function would_starve_mangle(ctx, rage_cost)
      if ctx.has_clearcasting then return false end -- free cast, safe to spend
      local cd = A.MangleBear:GetCooldown()
      if cd <= 0 then
         -- Mangle ready NOW: if we can afford it, it fires by priority — safe to spend
         if ctx.rage >= RAGE_COST_MANGLE then return false end
         -- Can't afford Mangle — block if spending would keep us unable
         return (ctx.rage - rage_cost) < RAGE_COST_MANGLE
      end
      if cd >= 0.5 then return false end -- Mangle far off, safe to spend
      if (ctx.rage - rage_cost) >= RAGE_COST_MANGLE then return false end -- enough rage for both, safe to spend
      -- Auto-attack landing before Mangle CD means rage is incoming, safe to spend
      -- Unless Maul is queued — it consumes the swing's rage
      if ctx.in_melee_range and not bear_state.maul_queued then
         local swing_remaining = get_time_until_swing()
         if swing_remaining > 0 and swing_remaining < cd then return false end
      end
      return true -- would starve Mangle, hold rage
   end

   -- [1] Frenzied Regeneration (emergency heal)
   -- Smart: standard emergency trigger + proactive use when grouped with high rage
   -- High rage = more healing output; healers supplement, so using at 50% HP is safe
   local Bear_FrenziedRegen = {
      is_gcd_gated = false,
      is_defensive = true,
      requires_combat = true,
      setting_key = "use_frenzied_regen",
      spell = A.FrenziedRegeneration,
      matches = function(context)
         -- FR drains rage for healing; need rage as fuel (not a cast cost, OoC doesn't help)
         if context.rage < 10 then return false end
         -- Standard trigger: emergency HP threshold (works solo and grouped)
         if context.hp <= context.settings.emergency_heal_hp then
            return true
         end
         -- Proactive use: when grouped and rage-rich, use at higher threshold
         -- High rage means more total healing; healers keep us alive while FR ticks
         return context.hp <= Constants.BEAR.FRENZIED_PROACTIVE_HP
            and context.rage >= Constants.BEAR.FRENZIED_PROACTIVE_RAGE
            and _G.IsInGroup()
      end,
      execute = function(icon, context)
         local proactive = context.hp > context.settings.emergency_heal_hp
         local mode = proactive and "Proactive (grouped)" or "Emergency"
         return try_cast_fmt(A.FrenziedRegeneration, icon, TARGET_UNIT, "[P2]", "Frenzied Regeneration", "%s - HP: %.0f%%, Rage: %d", mode, context.hp, context.rage)
      end,
   }

   -- [3] Enrage (rage generation)
   -- Smart: skips when HP is low (armor reduction ~27% is dangerous during burst)
   -- Exception: allows if Frenzied Regen is active (Enrage feeds it rage for healing)
   local Bear_Enrage = {
      is_gcd_gated = false,
      requires_combat = true,
      setting_key = "use_enrage",
      spell = A.Enrage,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if not (context.rage < (context.settings.enrage_rage_threshold or Constants.BEAR.ENRAGE_RAGE_THRESHOLD)) then return false end
         -- Boss safety: 27% armor reduction is too risky on boss encounters
         -- Exception: allow if Frenzied Regen is active (Enrage feeds rage to FR for healing)
         -- Boss hits generate enough rage naturally; not worth the armor loss
         if Unit(TARGET_UNIT):IsBoss() then
            local fr_active = (Unit(PLAYER_UNIT):HasBuffs(A.FrenziedRegeneration.ID) or 0) > 0
            if not fr_active then return false end
         end
         -- HP safety: armor reduction is dangerous when low HP (any target)
         if context.hp < Constants.BEAR.ENRAGE_HP_SAFETY then
            local fr_active = (Unit(PLAYER_UNIT):HasBuffs(A.FrenziedRegeneration.ID) or 0) > 0
            if not fr_active then return false end
         end
         return true
      end,
      execute = function(icon, context)
         local fr_active = (Unit(PLAYER_UNIT):HasBuffs(A.FrenziedRegeneration.ID) or 0) > 0
         local note = fr_active and " [FR active]" or ""
         return try_cast_fmt(A.Enrage, icon, PLAYER_UNIT, "[P3]", "Enrage", "Rage: %d, HP: %.0f%%%s", context.rage, context.hp, note)
      end,
   }

   -- [7] Lacerate Urgent Refresh (at 5 stacks, low duration) - skip if phys immune
   local Bear_LacerateUrgent = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Lacerate,
      matches = function(context, state)
         if not should_maintain_lacerate(context) then return false end
         return state.lacerate_stacks >= Constants.BEAR.LACERATE_MAX_STACKS and
               state.lacerate_duration > 0 and
               state.lacerate_duration <= Constants.BEAR.LACERATE_URGENT_REFRESH
      end,
      execute = function(icon, context, state)
         local cc_str = context.has_clearcasting and " [CC]" or ""
         return try_cast_fmt(A.Lacerate, icon, TARGET_UNIT, "[P5]", "Lacerate URGENT", "5 stacks, Duration: %.1fs%s", state.lacerate_duration, cc_str)
      end,
   }

   -- [8] Faerie Fire debuff maintenance
   local Bear_FaerieFire = create_faerie_fire_strategy()

   -- [5] Growl (single-target taunt when losing aggro - PvE only)
   -- Smart: skips CC'd mobs, dying mobs (unless healer targeted), double-checks via targettarget
   local Bear_Growl = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      requires_in_range = true,
      setting_key = "use_growl",
      spell = A.Growl,
      matches = function(context)
         if context.settings.bear_no_taunt then return false end
         -- Only taunt NPCs, not players
         if _G.UnitIsPlayer(TARGET_UNIT) then return false end
         -- Skip if target is CC'd (taunting wastes 10s CD, mob can't attack while CC'd)
         if is_target_cc_locked(Constants.BEAR.GROWL_CC_THRESHOLD) then return false end
         -- Skip if target is already attacking us (we have aggro)
         if has_target_aggro() then return false end
         -- Only taunt elites and bosses - don't waste 10s CD on trash
         local classification = _G.UnitClassification(TARGET_UNIT)
         if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
         -- TTD check: skip dying elites to save taunt CD
         -- Exception: ALWAYS taunt if elite is hitting a healer
         local targeting_healer = is_targettarget_healer()
         if not targeting_healer and context.ttd < Constants.BEAR.GROWL_MIN_TTD then return false end
         return true
      end,
      execute = function(icon, context)
         local targeting_healer = is_targettarget_healer()
         local reason = targeting_healer and "HEALER TARGETED" or "taunting"
         return try_cast_fmt(A.Growl, icon, TARGET_UNIT, "[P3]", "Growl", "Lost aggro - %s (TTD: %.0fs)", reason, context.ttd)
      end,
   }

   -- [6] Challenging Roar (AoE taunt when losing aggro to multiple enemies OR boss)
   local Bear_ChallengingRoar = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      setting_key = "use_challenging_roar",
      spell = A.ChallengingRoar,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if context.settings.bear_no_taunt then return false end
         local croar_range = context.settings.croar_range or Constants.BEAR.DEFAULT_CROAR_RANGE
         local elites, bosses = count_nearby_enemies(croar_range, true)
         if elites == 0 and bosses == 0 then return false end
         local min_bosses = context.settings.croar_min_bosses or Constants.BEAR.DEFAULT_CROAR_MIN_BOSSES
         local min_elites = context.settings.croar_min_elites or Constants.BEAR.DEFAULT_CROAR_MIN_ELITES
         return bosses >= min_bosses or elites >= min_elites
      end,
      execute = function(icon, context)
         local croar_range = context.settings.croar_range or Constants.BEAR.DEFAULT_CROAR_RANGE
         local elites, bosses = count_nearby_enemies(croar_range, true)
         local reason = bosses >= 1 and format("EMERGENCY - %d boss(es) loose, %d elite(s)", bosses, elites) or format("EMERGENCY - %d loose elite(s)", elites)
         return try_cast_fmt(A.ChallengingRoar, icon, PLAYER_UNIT, "[P4]", "Challenging Roar", reason)
      end,
   }

   -- [5] Tab Target (multi-mob threat management)
   -- Switches targets to spread threat across multiple mobs
   -- Priority: CC'd targets -> loose mobs -> Lacerate spread
   local Bear_TabTarget = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      setting_key = "enable_tab_targeting",
      matches = function(context, state)
         return should_tab_target(context, state)
      end,
      execute = function(icon, context)
         AddDebugLogLine(format("[%.3fs] [TAB TARGET] Switching to next target for threat management", GetTime()))
         return A:Show(icon, CONST.AUTOTARGET)
      end,
   }

   -- [9] Demoralizing Roar (attack power reduction)
   -- Configurable thresholds: min bosses/elites/trash within 10yd (defaults: 1/1/3)
   -- Smart: skips immune, dying (single target), warrior-shout-covered
   local Bear_DemoRoar = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      setting_key = "maintain_demo_roar",
      spell = A.DemoralizingRoar,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if would_starve_maul(context, RAGE_COST_DEMO_ROAR) then return false end
         if would_starve_mangle(context, RAGE_COST_DEMO_ROAR) then return false end
         -- Only worth using with enough nearby enemies to justify the rage
         local demo_range = context.settings.demo_roar_range or Constants.BEAR.DEFAULT_DEMO_ROAR_RANGE
         local elites, bosses, trash = count_nearby_enemies(demo_range, false)
         local min_bosses = context.settings.demo_roar_min_bosses or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_BOSSES
         local min_elites = context.settings.demo_roar_min_elites or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_ELITES
         local min_trash = context.settings.demo_roar_min_trash or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_TRASH
         if bosses < min_bosses and elites < min_elites and trash < min_trash then return false end
         -- TTD check: skip if single target dying soon (PBAoE still hits other mobs in AoE)
         if context.enemy_count <= 1 and context.ttd < Constants.BEAR.DEMO_ROAR_MIN_TTD then
            return false
         end
         -- Check for existing AP reduction debuff (Demo Roar from any druid)
         local demo_duration = Unit(TARGET_UNIT):HasDeBuffs(DEMO_ROAR_DEBUFF_IDS) or 0
         if demo_duration > Constants.BEAR.DEMO_ROAR_REFRESH then return false end
         -- Warrior's Demoralizing Shout also reduces AP (doesn't stack, stronger one wins)
         local shout_duration = Unit(TARGET_UNIT):HasDeBuffs("Demoralizing Shout") or 0
         if shout_duration > Constants.BEAR.DEMO_ROAR_REFRESH then return false end
         return true
      end,
      execute = function(icon, context)
         local demo_range = context.settings.demo_roar_range or Constants.BEAR.DEFAULT_DEMO_ROAR_RANGE
         local elites, bosses, trash = count_nearby_enemies(demo_range, false)
         local cc_str = context.has_clearcasting and " [CC]" or ""
         local reason = bosses >= 1 and format("%d boss(es) + %d elite(s)", bosses, elites) or format("%d elite(s), %d trash", elites, trash)
         return try_cast_fmt(A.DemoralizingRoar, icon, PLAYER_UNIT, "[P7]", "Demoralizing Roar",
            "%s%s", reason, cc_str)
      end,
   }

   -- [8] Swipe AoE (priority above Mangle when multiple targets)
   -- Sim: SwipeSpam mode replaces Mangle entirely in AoE.
   -- With 3+ targets, total Swipe damage > Mangle single-target damage.
   local Bear_SwipeAoE = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Swipe,
      matches = function(context, state)
         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count < aoe_threshold then return false end
         -- CC safety
         if context.settings.swipe_cc_check ~= false then
            if has_breakable_cc_nearby() then return false end
         end
         if not context.has_clearcasting then
            local swipe_threshold = context.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
            if context.rage < swipe_threshold then return false end
            if would_starve_maul(context, RAGE_COST_SWIPE) then return false end
            -- No starve_mangle check: in AoE, Swipe > Mangle
         end
         return true
      end,
      execute = function(icon, context)
         return try_cast_fmt(A.Swipe, icon, TARGET_UNIT, "[P8]", "Swipe (AoE)", "Rage: %d, Targets: %d%s", context.rage, context.enemy_count, context.has_clearcasting and " [CC]" or "")
      end,
   }

   -- [9] Mangle (main single-target damage ability) - skip if target has physical immunity
   local Bear_Mangle = create_combat_strategy({
      spell = A.MangleBear,
      log_name = "Mangle",
      prefix = "[P9]",
      log_fmt = "Rage: %d%s",
      log_args = function(ctx) return ctx.rage, ctx.has_clearcasting and " [CC]" or "" end,
      extra_match = function(ctx)
         -- Skip if target has physical immunity
         if ctx.target_phys_immune then return false end
         -- Clearcasting: Mangle is free, bypass rage check
         if ctx.has_clearcasting then return true end
         -- Mangle is highest DPET ability — use on CD with minimal rage gating
         local mangle_threshold = ctx.settings.mangle_rage_threshold or RAGE_COST_MANGLE
         if ctx.rage < mangle_threshold then return false end
         return true
      end
   })

   -- [10] Swipe single-target filler (below Mangle — used when Lacerate maintained)
   -- Sim: conditional Swipe fires when 5 Lac stacks, >3s duration, AP threshold met.
   local Bear_Swipe = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Swipe,
      matches = function(context, state)
         -- AoE is handled by SwipeAoE above Mangle; this is single-target filler only
         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count >= aoe_threshold then return false end

         -- Hold for Mangle: don't waste a 1.5s GCD when Mangle is almost ready
         if should_hold_for_mangle() then return false end

         -- CC safety
         if context.settings.swipe_cc_check ~= false then
            if has_breakable_cc_nearby() then return false end
         end

         if not context.has_clearcasting then
            local swipe_threshold = context.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
            if context.rage < swipe_threshold then return false end
            if would_starve_maul(context, RAGE_COST_SWIPE) then return false end
            if would_starve_mangle(context, RAGE_COST_SWIPE) then return false end
         end

         -- Not maintaining Lacerate on this target → Swipe is the filler
         if not should_maintain_lacerate(context) then
            return true
         end

         -- Sim: only Swipe as filler when Lacerate at 5 stacks with >3s remaining
         local stacks, duration = state.lacerate_stacks, state.lacerate_duration
         if stacks >= Constants.BEAR.LACERATE_MAX_STACKS and duration > Constants.BEAR.LACERATE_SWIPE_THRESHOLD then
            return true
         end

         return false
      end,
      execute = function(icon, context)
         return try_cast_fmt(A.Swipe, icon, TARGET_UNIT, "[P10]", "Swipe", "Rage: %d%s", context.rage, context.has_clearcasting and " [CC]" or "")
      end,
   }

   -- [11] Lacerate Build (building/maintaining stacks) - skip if target has physical immunity
   -- Lacerate costs 10 rage. Used as lowest-priority filler (matches sim).
   local Bear_LacerateBuild = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Lacerate,
      matches = function(context, state)
         if not should_maintain_lacerate(context) then return false end
         if not context.has_clearcasting then
            if context.rage < RAGE_COST_LACERATE then return false end
            if would_starve_maul(context, RAGE_COST_LACERATE) then return false end
            if would_starve_mangle(context, RAGE_COST_LACERATE) then return false end
         end

         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count >= aoe_threshold then return false end

         local stacks, duration = state.lacerate_stacks, state.lacerate_duration

         -- Still building stacks → always Lacerate (don't hold for Mangle)
         if stacks < Constants.BEAR.LACERATE_MAX_STACKS then
            return true
         end

         -- At 5 stacks, refreshing as filler — hold for Mangle if it's almost ready
         if should_hold_for_mangle() then return false end

         -- Refresh if above urgent threshold but below swipe threshold
         return duration > Constants.BEAR.LACERATE_URGENT_REFRESH and
            duration <= Constants.BEAR.LACERATE_SWIPE_THRESHOLD
      end,
      execute = function(icon, context, state)
         local cc_str = context.has_clearcasting and " [CC]" or ""
         return try_cast_fmt(A.Lacerate, icon, TARGET_UNIT, "[P11]", "Lacerate", "Stacks: %d/5, Duration: %.1fs%s", state.lacerate_stacks, state.lacerate_duration, cc_str)
      end,
   }

   -- [4] Maul (off-GCD, queues on next melee swing)
   -- Only queue above rage threshold - preserve rage when low (losing aggro = less rage income)
   -- Smart: trash-only packs → raise threshold to save rage for Swipe spam
   local Bear_Maul = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      requires_in_range = true,
      spell = A.Maul,
      matches = function(context, state)
         -- Confirmed queued by game → wait for CLEU to consume it
         if bear_state.maul_confirmed then return false end
         -- Still queuing (not yet confirmed) → allow re-entry to keep firing TMW:Fire
         if bear_state.maul_queued then return true end
         -- Idle: normal rage checks
         local maul_threshold = context.settings.maul_rage_threshold or Constants.BEAR.DEFAULT_MAUL_RAGE
         return context.rage >= maul_threshold
      end,
      execute = function(icon, context, state)
         bear_state.maul_queued = true
         bear_state.maul_dequeue_logged = false
         return try_cast_fmt(A.Maul, icon, TARGET_UNIT, "[P12]", "Maul", "Rage: %d, Melee: %dB/%dE/%dT", context.rage, state.nearby_bosses, state.nearby_elites, state.nearby_trash)
      end,
   }

   -- Register all Bear strategies (array order = execution priority)
   -- Off-GCD emergencies/taunts first, then GCD rotation, then Maul last.
   -- Maul is off-GCD (swing queue) — placed last so GCD abilities fire first.
   -- During GCD frames, only off-GCD strategies evaluate, so Maul fires then.
   --
   -- KEY: SwipeAoE sits ABOVE Mangle (sim SwipeSpam mode).
   -- In AoE, total Swipe damage > Mangle single-target damage.
   -- Single-target Swipe filler sits below Mangle (conditional on Lacerate maintained).
   rotation_registry:register("bear", {
      named("FrenziedRegen",    Bear_FrenziedRegen),     -- [1]  off-GCD emergency heal
      named("Enrage",           Bear_Enrage),            -- [2]  off-GCD rage gen
      named("Growl",            Bear_Growl),             -- [3]  off-GCD taunt
      named("ChallengingRoar",  Bear_ChallengingRoar),   -- [4]  off-GCD AoE taunt
      named("LacerateUrgent",   Bear_LacerateUrgent),    -- [5]  GCD — urgent refresh
      named("TabTarget",        Bear_TabTarget),         -- [6]  off-GCD tab targeting
      named("FaerieFire",       Bear_FaerieFire),        -- [7]  GCD — debuff maintenance
      named("DemoRoar",         Bear_DemoRoar),          -- [8]  GCD — AP reduction
      named("SwipeAoE",         Bear_SwipeAoE),          -- [9]  GCD — AoE priority (above Mangle)
      named("Mangle",           Bear_Mangle),            -- [10] GCD — main ST damage/threat
      named("Swipe",            Bear_Swipe),             -- [11] GCD — ST filler (Lac maintained)
      named("LacerateBuild",    Bear_LacerateBuild),     -- [12] GCD — stack builder
      named("Maul",             Bear_Maul),              -- [13] off-GCD swing queue (fires during GCD)
   }, {
      context_builder = get_bear_state,
   })

end  -- End Bear strategies do...end block

print("|cFF00FF00[Flux AIO Bear]|r 13 Bear strategies registered.")
