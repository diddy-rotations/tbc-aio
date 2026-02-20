-- Flux AIO - Main Module
-- Generic context creation and main rotation dispatcher
-- MUST LOAD LAST - after all strategies are registered

-- ============================================================
-- This is the entry point. It creates the context and dispatches
-- to the appropriate strategies based on active playstyle.
-- All class-specific logic lives in class_config callbacks.
-- ============================================================

local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Main]|r Core module not loaded!")
   return
end

if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Main]|r Registry not found!")
   return
end

-- Import commonly used references
local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local cached_settings = NS.cached_settings
local refresh_settings = NS.refresh_settings
local get_time_to_die = NS.get_time_to_die
local has_phys_immunity = NS.has_phys_immunity
local debug_print = NS.debug_print
local validate_playstyle_spells = NS.validate_playstyle_spells
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Lua optimizations
local format = string.format
local ipairs = ipairs

-- Suggestion system for A[1] icon
local suggestion = { spell = nil }

-- ============================================================================
-- ROTATION REGISTRY EXECUTION METHODS
-- ============================================================================

--- Executes middleware. Returns: result, log_message (optional)
function rotation_registry:execute_middleware(icon, context)
   local debug_mode = context.settings and context.settings.debug_mode
   local debug_system = context.settings and context.settings.debug_system

   for _, mw in ipairs(self.middleware) do
      if (not context.on_gcd and mw.is_gcd_gated ~= false)
         or (mw.is_gcd_gated == false) then
      local matches = mw.matches(context)

      if matches then
         local result, log_msg = mw.execute(icon, context)
         if result then
            if debug_mode and log_msg and debug_print then
                debug_print(format("[MW] %s", log_msg))
            elseif debug_system and debug_print then
               debug_print(format("[MW] EXECUTED %s (P%d)", mw.name, mw.priority))
            end
            return result
         end
      end
      end
   end

   return nil
end

--- Executes strategies for playstyle. Returns: result, log_message (optional)
function rotation_registry:execute_strategies(playstyle, icon, context)
   local debug_mode = context.settings and context.settings.debug_mode
   local debug_system = context.settings and context.settings.debug_system
   local strategies = self.strategy_maps[playstyle]

   if not strategies then
      return nil
   end

   local config = self.playstyle_config[playstyle]
   local config_prereqs = config and config.check_prerequisites
   local state = self:get_playstyle_state(playstyle, context)

   for _, strategy in ipairs(strategies) do
      if not context.on_gcd or strategy.is_gcd_gated == false then
         if self:check_prerequisites(strategy, context)
            and (not config_prereqs or config_prereqs(strategy, context))
            and (not strategy.matches or strategy.matches(context, state)) then
            local result, log_msg = strategy.execute(icon, context, state)

            if debug_mode and log_msg and debug_print then
               debug_print(format("[%s] %s", playstyle:upper(), log_msg))
            elseif debug_system and debug_print then
               debug_print(format("[%s] EXECUTED %s (P%d)", playstyle:upper(), strategy.name, strategy.priority))
            end

            if result then
               return result
            end
         end
      end
   end
   return nil
end

-- ============================================================================
-- CONTEXT CREATION
-- ============================================================================

--- Reusable context table (avoid allocation every frame)
local reusable_context = {}

--- Creates rotation context (reused table, do not hold references)
local function create_context(icon)
   local ctx = reusable_context
   local gcd_remaining = Player:GCDRemains()
   local on_gcd = gcd_remaining > 0.1

   local combat_status = Unit(PLAYER_UNIT):CombatTime() > 0

   local mana_pct = Player:ManaPercentage()

   local max_range, min_range = Unit(TARGET_UNIT):GetRange()

   -- Generic fields (all classes)
   ctx.on_gcd = on_gcd
   ctx.icon = icon
   ctx.in_combat = (combat_status == 1 or combat_status == true)
   ctx.hp = Unit(PLAYER_UNIT):HealthPercent()
   ctx.mana_pct = mana_pct
   ctx.mana = Player:Mana()
   ctx.target_exists = Unit(TARGET_UNIT):IsExists()
   ctx.target_dead = Unit(TARGET_UNIT):IsDead()
   ctx.target_enemy = Unit(TARGET_UNIT):IsEnemy()
   ctx.has_valid_enemy_target = ctx.target_exists and not ctx.target_dead and ctx.target_enemy
   ctx.target_hp = Unit(TARGET_UNIT):HealthPercent()
   ctx.ttd = get_time_to_die(TARGET_UNIT)
   ctx.target_range = max_range
   ctx.in_melee_range = max_range and max_range <= 5 or false
   ctx.target_phys_immune = has_phys_immunity(TARGET_UNIT)
   ctx.settings = cached_settings
   ctx.gcd_remaining = gcd_remaining

   -- Class-specific context extension (stance, energy, rage, cp, etc.)
   local cc = rotation_registry.class_config
   if cc and cc.extend_context then
      cc.extend_context(ctx)
   end

   return ctx
end

-- ============================================================================
-- MAIN ROTATION DISPATCHER
-- ============================================================================

-- Main rotation entry point (A[3])
A[3] = function(icon)

   refresh_settings()

   local context = create_context(icon)

   -- Reset suggestion each frame
   suggestion.spell = nil

   local cc = rotation_registry.class_config
   if not cc then return end

   -- Run middleware first (shared concerns: recovery items, CDs)
   local mw_result = rotation_registry:execute_middleware(icon, context)
   if mw_result then
      return mw_result
   end

   -- Determine active and idle playstyles via class callbacks
   local active = cc.get_active_playstyle(context)
   local idle = cc.get_idle_playstyle and cc.get_idle_playstyle(context)

   -- Populate suggestions when NOT in idle form
   -- A[1] icon shows the most important idle-form ability the player would want
   if not idle and cc.idle_playstyle_name then
      local idle_strategies = rotation_registry.strategy_maps[cc.idle_playstyle_name]
      if idle_strategies then
         for _, strategy in ipairs(idle_strategies) do
            if strategy.should_suggest and strategy.should_suggest(context) then
               suggestion.spell = strategy.suggestion_spell
               break
            end
         end
      end
   end

   -- Run idle playstyle strategies (e.g., caster self-care when in caster form)
   if idle then
      local result = rotation_registry:execute_strategies(idle, icon, context)
      if result then
         return result
      end
   end

   -- Run active playstyle strategies (cat, bear, balance, resto, etc.)
   if active then
      validate_playstyle_spells(active)
      local result = rotation_registry:execute_strategies(active, icon, context)
      if result then
         return result
      end
   end
end

-- Suggestion icon (A[1]) - shows what spell to cast if player shifts to idle form
A[1] = function(icon)
   if suggestion.spell then
      return suggestion.spell:Show(icon)
   end
end
A[4] = nil
A[5] = nil
A[6] = nil
A[7] = nil
A[8] = nil

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

-- Print load summary (dynamic from class_config)
local cc = rotation_registry.class_config
local class_label = cc and cc.name or "Unknown"
local class_version = cc and cc.version or "?"

-- Count strategies per registered playstyle
local strategy_summary = {}
for ps, strats in pairs(rotation_registry.strategy_maps) do
   strategy_summary[#strategy_summary + 1] = ps .. "=" .. #strats
end
local mw_count = rotation_registry.middleware and #rotation_registry.middleware or 0

print(format("|cFF00FF00[Flux AIO]|r %s %s loaded successfully!", class_label, class_version))
print(format("|cFF00FF00[Flux AIO]|r Strategies: %s", table.concat(strategy_summary, ", ")))
print(format("|cFF00FF00[Flux AIO]|r Middleware: %d handlers registered", mw_count))
