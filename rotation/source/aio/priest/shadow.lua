-- Priest Shadow DPS Module
-- DoT management, Shadow Weaving, Mind Flay filler

local _G = _G
local format = string.format
local A = _G.Action

if not A then
   return
end
if A.PlayerClass ~= "PRIEST" then
   return
end

local NS = _G.DiddyAIO
if not NS then
   print("|cFFFF0000[Diddy AIO Priest Shadow]|r Core module not loaded!")
   return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local CONST = A.Const

-- ============================================================================
-- SHADOW STATE (per-frame cache)
-- ============================================================================
local shadow_state = {
   vt_remaining = 0,
   swp_active = false,
   swp_remaining = 0,
   ve_remaining = 0,
   shadow_weaving_stacks = 0,
   mb_ready = false,
   swd_ready = false,
   swd_safe = false,
   inner_focus_ready = false,
}

local function get_shadow_state(context)
   if context._shadow_valid then
      return shadow_state
   end
   context._shadow_valid = true

   -- VT: use spell ID to detect correct rank (useMaxRank = true means ID changes per rank)
   shadow_state.vt_remaining = Unit(TARGET_UNIT):HasDeBuffs(A.VampiricTouch.ID, "player", true) or 0
   local swp_dur = Unit(TARGET_UNIT):HasDeBuffs(A.ShadowWordPain.ID, "player", true) or 0
   shadow_state.swp_active = swp_dur > 0
   shadow_state.swp_remaining = swp_dur
   -- VE: use spell ID (15286) not party buff ID (15290) for target debuff check
   shadow_state.ve_remaining = Unit(TARGET_UNIT):HasDeBuffs(A.VampiricEmbrace.ID, "player", true) or 0
   shadow_state.shadow_weaving_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SHADOW_WEAVING) or 0
   shadow_state.mb_ready = is_spell_available(A.MindBlast) and A.MindBlast:IsReady(TARGET_UNIT)
   shadow_state.swd_ready = is_spell_available(A.ShadowWordDeath) and A.ShadowWordDeath:IsReady(TARGET_UNIT)
   shadow_state.swd_safe = context.hp > (context.settings.shadow_swd_hp or 40)
   shadow_state.inner_focus_ready = is_spell_available(A.InnerFocus) and A.InnerFocus:IsReady(PLAYER_UNIT)

   return shadow_state
end

-- ============================================================================
-- SHADOW STRATEGIES
-- ============================================================================
rotation_registry:register("shadow", {

   -- [1] Ensure Shadowform (OOC or if dropped)
   named("EnsureShadowform", {
      matches = function(context, state)
         if context.in_shadowform then
            return false
         end
         if context.is_mounted then
            return false
         end
         return is_spell_available(A.Shadowform)
      end,
      execute = function(icon, context, state)
         return try_cast(A.Shadowform, icon, PLAYER_UNIT, "[SHADOW] Shadowform")
      end,
   }),

   -- [1.5] Pre-Combat Pull (start combat with VT or MB)
   named("PreCombatPull", {
      matches = function(context, state)
         if context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         if not context.in_shadowform then
            return false
         end
         -- Only pull if we have a valid enemy and are in range
         if not A.VampiricTouch:IsInRange(TARGET_UNIT) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         -- Prefer VT for pull (applies DoT immediately), fallback to MB
         if is_spell_available(A.VampiricTouch) and A.VampiricTouch:IsReady(TARGET_UNIT) then
            return try_cast(A.VampiricTouch, icon, TARGET_UNIT, "[SHADOW] Pull: Vampiric Touch")
         end
         if state.mb_ready then
            return try_cast(A.MindBlast, icon, TARGET_UNIT, "[SHADOW] Pull: Mind Blast")
         end
         return nil
      end,
   }),

   -- [2] Vampiric Embrace (maintain debuff on target)
   named("VampiricEmbrace", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_ve_maintain then
            return false
         end
         if state.ve_remaining >= 3 then
            return false
         end
         -- Range check: VE is 30yd range, same as VT
         if not A.VampiricEmbrace:IsInRange(TARGET_UNIT) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.VampiricEmbrace, icon, TARGET_UNIT, "[SHADOW] Vampiric Embrace")
      end,
   }),

   -- [3] Vampiric Touch (refresh when remaining <= ~1.5s cast time)
   named("VampiricTouch", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         -- Refresh when remaining <= 1.5s (cast time)
         return state.vt_remaining < 1.8
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.VampiricTouch, icon, TARGET_UNIT, "[SHADOW]", "VT", "rem: %.1fs", state.vt_remaining)
      end,
   }),

   -- [4] Shadow Word: Pain (reapply only when it falls off)
   named("ShadowWordPain", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if state.swp_active then
            return false
         end
         -- Don't apply if target will die soon
         if context.ttd < 6 then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.ShadowWordPain, icon, TARGET_UNIT, "[SHADOW] SW:P")
      end,
   }),

   -- [5] Starshards (Night Elf racial, before MB/SWD)
   named("Starshards", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_use_starshards then
            return false
         end
         return is_spell_available(A.Starshards) and A.Starshards:IsReady(TARGET_UNIT)
      end,
      execute = function(icon, context, state)
         return try_cast(A.Starshards, icon, TARGET_UNIT, "[SHADOW] Starshards")
      end,
   }),

   -- [6] Devouring Plague (Undead racial, before MB/SWD)
   named("DevouringPlague", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_use_devouring_plague then
            return false
         end
         -- Don't reapply if already active
         local dp_remaining = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEVOURING_PLAGUE, "player", true) or 0
         if dp_remaining > 3 then
            return false
         end
         return is_spell_available(A.DevouringPlague) and A.DevouringPlague:IsReady(TARGET_UNIT)
      end,
      execute = function(icon, context, state)
         return try_cast(A.DevouringPlague, icon, TARGET_UNIT, "[SHADOW] Devouring Plague")
      end,
   }),

   -- [7] Inner Focus (off-GCD, fire before Mind Blast)
   named("InnerFocus", {
      is_gcd_gated = false,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.shadow_use_inner_focus then
            return false
         end
         if not state.inner_focus_ready then
            return false
         end
         if context.has_inner_focus then
            return false
         end
         -- Only use if MB is also ready (pair them)
         return state.mb_ready
      end,
      execute = function(icon, context, state)
         return try_cast(A.InnerFocus, icon, PLAYER_UNIT, "[SHADOW] Inner Focus")
      end,
   }),

   -- [8] Mind Blast (on cooldown)
   named("MindBlast", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         return state.mb_ready
      end,
      execute = function(icon, context, state)
         return try_cast(A.MindBlast, icon, TARGET_UNIT, "[SHADOW] Mind Blast")
      end,
   }),

   -- [9] Shadow Word: Death (on CD, HP gated)
   named("ShadowWordDeath", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_use_swd then
            return false
         end
         if not state.swd_safe then
            return false
         end
         return state.swd_ready
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.ShadowWordDeath, icon, TARGET_UNIT, "[SHADOW]", "SW:D", "HP: %.0f%%", context.hp)
      end,
   }),

   -- [10] Trinkets (off-GCD)
   named("Trinkets", {
      is_gcd_gated = false,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         if context.settings.use_trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then
            return A.Trinket1:Show(icon), "[SHADOW] Trinket 1"
         end
         if context.settings.use_trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then
            return A.Trinket2:Show(icon), "[SHADOW] Trinket 2"
         end
         return nil
      end,
   }),

   -- [11] Racial (off-GCD)
   named("Racial", {
      is_gcd_gated = false,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.use_racial then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[SHADOW] Berserking"
         end
         if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[SHADOW] Arcane Torrent"
         end
         return nil
      end,
   }),

   -- [12] Mind Flay (filler)
   named("MindFlay", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.MindFlay, icon, TARGET_UNIT, "[SHADOW] Mind Flay")
      end,
   }),

   -- [13] Wand / Auto Attack (movement filler, last resort)
   named("WandAutoAttack", {
      is_gcd_gated = false,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         -- Use wand when moving or when we can't cast anything else
         if not context.is_moving and not context.on_gcd then
            return false
         end
         if not Player:IsAttacking() then
            return true
         end
         return false
      end,
      execute = function(icon, context, state)
         return A:Show(icon, CONST.AUTOATTACK), "[SHADOW] Auto Attack / Wand"
      end,
   }),
}, {
   context_builder = get_shadow_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Diddy AIO Priest]|r Shadow rotation loaded")
