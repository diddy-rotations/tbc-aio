--- Balance Module
--- Balance (Moonkin DPS) playstyle strategies
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
   print("|cFFFF0000[Flux AIO Balance]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Balance]|r Registry not found in Core!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local is_buff_active = NS.is_buff_active
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Import factory functions from Core
local create_faerie_fire_strategy = NS.create_faerie_fire_strategy
local create_combat_strategy = NS.create_combat_strategy
local named = NS.named

-- Immunity check functions
local has_magic_immunity = NS.has_magic_immunity

-- Lua optimizations
local format = string.format

-- ============================================================================
-- BALANCE (MOONKIN) STRATEGIES
-- ============================================================================
do
   -- [1] Faerie Fire debuff maintenance (with refresh window)
   local Balance_FaerieFire = create_faerie_fire_strategy(Constants.BALANCE.FAERIE_FIRE_REFRESH)

   -- [3] Force of Nature (Treants cooldown)
   local Balance_ForceOfNature = create_combat_strategy({
      stance = Constants.STANCE.MOONKIN,
      spell = A.ForceOfNature,
      prefix = "[P2]",
      log_name = "Force of Nature",
      log_fmt = "Treants summoned, TTD: %.1fs",
      log_args = function(ctx) return ctx.ttd end,
      setting_key = "use_force_of_nature",
      extra_match = function(ctx)
         local fon_min_ttd = ctx.settings.force_of_nature_min_ttd or Constants.TTD.FORCE_OF_NATURE_MIN
         return ctx.ttd > fon_min_ttd
      end
   })
   Balance_ForceOfNature.is_burst = true

   -- [4] AoE (Hurricane with Barkskin protection) - skip if target has magic immunity
   local Balance_AoE = {
      matches = function(context)
         if context.stance ~= Constants.STANCE.MOONKIN or not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         -- Skip if target has magic immunity (Divine Shield, Ice Block, Cloak, etc.)
         if has_magic_immunity(TARGET_UNIT) then return false end
         local min_targets = context.settings.hurricane_min_targets or Constants.AOE.HURRICANE_MIN_TARGETS
         return context.enemy_count >= min_targets and A.Hurricane:IsReady(TARGET_UNIT)
      end,
      execute = function(icon, context)
         -- Use Barkskin to protect Hurricane channel
         if A.Barkskin:IsReady(PLAYER_UNIT) and not is_buff_active(A.Barkskin, PLAYER_UNIT) then
            local bark_result = try_cast(A.Barkskin, icon, PLAYER_UNIT, "[P3] Barkskin - Protecting Hurricane channel")
            if bark_result then return bark_result end
         end
         return try_cast_fmt(A.Hurricane, icon, TARGET_UNIT, "[P3]", "Hurricane", "AoE on %d targets", context.enemy_count)
      end,
   }

   -- [5] Pull opener (initiates combat from range when not yet in combat)
   local Balance_Opener = {
      matches = function(context)
         if context.stance ~= Constants.STANCE.MOONKIN then return false end
         if context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if has_magic_immunity(TARGET_UNIT) then return false end
         return true
      end,
      execute = function(icon, context)
         local is_moving = Unit(PLAYER_UNIT):IsMoving()
         if not is_moving then
            -- Starfire: highest damage opener (requires standing still)
            local result, msg = try_cast_fmt(A.Starfire, icon, TARGET_UNIT, "[P0]", "Starfire", "Opening pull")
            if result then return result, msg end
            -- Wrath: shorter cast fallback (requires standing still)
            result, msg = try_cast_fmt(A.Wrath, icon, TARGET_UNIT, "[P0]", "Wrath", "Opening pull")
            if result then return result, msg end
         end
         -- Moonfire: instant cast fallback (works while moving)
         -- Skip if already applied (prevent spam before combat registers)
         local mf_on_target = (Unit(TARGET_UNIT):HasDeBuffs(A.Moonfire.ID) or 0) > 0
         if not mf_on_target then
            return try_cast_fmt(A.Moonfire, icon, TARGET_UNIT, "[P0]", "Moonfire", "Opening pull (moving)")
         end
         return nil
      end,
   }

   -- [6] Main DPS rotation (DoTs + Nukes with mana tiers) - skip damage if target has magic immunity
   local Balance_DPS = {
      matches = function(context)
         return context.stance == Constants.STANCE.MOONKIN and context.in_combat and
                context.has_valid_enemy_target
      end,
      execute = function(icon, context)
         local settings = context.settings
         local mana_pct = context.mana_pct

         -- Check magic immunity (Divine Shield, Ice Block, Cloak, Grounding Totem, etc.)
         -- If immune, skip all magic damage abilities
         local target_magic_immune = has_magic_immunity(TARGET_UNIT)
         if target_magic_immune then return nil end

         -- Mana tier system: Tier 1 (high mana) = full rotation, Tier 2/3 = conserve
         local tier1_mana = settings.balance_tier1_mana or Constants.BALANCE.MANA_TIER1
         local tier2_mana = settings.balance_tier2_mana or Constants.BALANCE.MANA_TIER2
         local mana_tier = (mana_pct < tier2_mana) and 3 or (mana_pct < tier1_mana) and 2 or 1

         -- Track Nature's Grace proc for logging
         local ng_info = ""
         if Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.NATURES_GRACE) > 0 then
            ng_info = " [NG]"
         end

         -- DoT maintenance (priority over nukes)
         -- Insect Swarm: Apply in Tier 1 and 2, or refresh in Tier 3 if about to expire
         local is_duration = Unit(TARGET_UNIT):HasDeBuffs(A.InsectSwarm.ID) or 0
         local is_expiring = is_duration > 0 and is_duration < 3  -- About to expire
         if settings.maintain_insect_swarm ~= false then
            if (mana_tier <= 2 and is_duration == 0) or (mana_tier == 3 and is_expiring) then
               local result, msg = try_cast_fmt(A.InsectSwarm, icon, TARGET_UNIT, "[P4]", "Insect Swarm",
                                                is_expiring and "REFRESH (%.1fs)" or "DoT missing, Mana: %.0f%%",
                                                is_expiring and is_duration or mana_pct)
               if result then return result, msg end
            end
         end

         -- Moonfire: Apply in Tier 1, or refresh in Tier 2/3 if about to expire
         local mf_duration = Unit(TARGET_UNIT):HasDeBuffs(A.Moonfire.ID) or 0
         local mf_expiring = mf_duration > 0 and mf_duration < 3  -- About to expire
         if settings.maintain_moonfire ~= false then
            if (mana_tier == 1 and mf_duration == 0) or (mana_tier >= 2 and mf_expiring) then
               local result, msg = try_cast_fmt(A.Moonfire, icon, TARGET_UNIT, "[P5]", "Moonfire",
                                                mf_expiring and "REFRESH (%.1fs)" or "DoT missing, Mana: %.0f%%",
                                                mf_expiring and mf_duration or mana_pct)
               if result then return result, msg end
            end
         end

         -- Nukes
         local tier_info = mana_tier == 1 and "Tier1" or (mana_tier == 2 and "Tier2" or "Tier3")

         -- Starfire: Primary nuke
         local result, msg = try_cast_fmt(A.Starfire, icon, TARGET_UNIT, "[P6]", "Starfire",
                                          "%s Mana: %.0f%%%s", tier_info, mana_pct, ng_info)
         if result then return result, msg end

         -- Wrath: Fallback (faster cast, lower damage per mana)
         return try_cast_fmt(A.Wrath, icon, TARGET_UNIT, "[P7]", "Wrath",
                             "Fallback cast%s", ng_info)
      end,
   }

   -- Register all Balance strategies (array order = execution priority)
   rotation_registry:register("balance", {
      named("FaerieFire",      Balance_FaerieFire),
      named("ForceOfNature",   Balance_ForceOfNature),
      named("AoE",             Balance_AoE),
      named("Opener",          Balance_Opener),
      named("DPS",             Balance_DPS),
   })

end  -- End Balance strategies do...end block

print("|cFF00FF00[Flux AIO Balance]|r 5 Balance strategies registered.")
