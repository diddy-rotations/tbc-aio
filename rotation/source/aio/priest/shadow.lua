-- Priest Shadow DPS Module
-- DoT management, Shadow Weaving, Mind Flay filler

local _G = _G
local A = _G.Action

if not A then
   return
end
if A.PlayerClass ~= "PRIEST" then
   return
end

local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Priest Shadow]|r Core module not loaded!")
   return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named

local has_pws = NS.has_pws
local has_weakened_soul = NS.has_weakened_soul
local MultiUnits = A.MultiUnits
local UnitExists = _G.UnitExists

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- SHADOW STATE (per-frame cache)
-- ============================================================================
local shadow_state = {
   vt_remaining = 0,
   swp_active = false,
   ve_remaining = 0,
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
   shadow_state.swp_active = (Unit(TARGET_UNIT):HasDeBuffs(A.ShadowWordPain.ID, "player", true) or 0) > 0
   -- VE: use spell ID (15286) not party buff ID (15290) for target debuff check
   shadow_state.ve_remaining = Unit(TARGET_UNIT):HasDeBuffs(A.VampiricEmbrace.ID, "player", true) or 0
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
         -- Don't re-pull if VT already on target (cast completed but combat hasn't started)
         if state.vt_remaining > 0 then
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
         -- Don't apply on dying targets (wastes a GCD)
         if context.ttd and context.ttd > 0 and context.ttd < 6 then
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
         -- Don't apply on dying targets (1.5s cast + 15s DoT, poor value if TTD < 5)
         if context.ttd and context.ttd > 0 and context.ttd < 5 then
            return false
         end
         -- Refresh when: VT missing entirely OR (VT expiring AND MB on CD)
         if state.vt_remaining == 0 then return true end
         return state.vt_remaining < 1.8 and not state.mb_ready
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
         -- Only apply when MB on CD (don't waste GCD when MB is ready)
         if state.mb_ready then
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
         -- Don't waste 3min CD on dying targets
         if context.ttd and context.ttd > 0 and context.ttd < 8 then
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
      is_burst = true,
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

   -- [10] Racial (off-GCD, Berserking only — Arcane Torrent is a silence, handled by middleware)
   named("Racial", {
      is_gcd_gated = false,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.use_racial then
            return false
         end
         return is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         return A.Berserking:Show(icon), "[SHADOW] Berserking"
      end,
   }),

   -- [12] Mind Flay (filler — yields to LowManaMode when mana below threshold)
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
         -- Yield to LowManaMode: don't waste mana on MF when conserving
         local threshold = context.settings.shadow_low_mana_pct or 50
         if context.mana_pct <= threshold and state.swp_active and state.vt_remaining >= 1.8 then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.MindFlay, icon, TARGET_UNIT, "[SHADOW] Mind Flay")
      end,
   }),

   -- [11] AoE SW:P Spread (blanket enemies with SW:P)
   named("AoESWPSpread", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if context.enemy_count < (context.settings.shadow_aoe_count or 4) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         local plates = MultiUnits:GetActiveUnitPlates()
         for unitID in pairs(plates) do
            if UnitExists(unitID) and not Unit(unitID):IsDead() then
               local swp = (Unit(unitID):HasDeBuffs(A.ShadowWordPain.ID, "player", true) or 0)
               if swp == 0 and A.ShadowWordPain:IsReady(unitID) then
                  return try_cast_fmt(A.ShadowWordPain, icon, unitID, "[SHADOW]", "AoE SW:P", "on %s", unitID)
               end
            end
         end
         return nil
      end,
   }),

   -- [12] AoE VT Spread (blanket enemies with VT)
   named("AoEVTSpread", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if context.is_moving then
            return false
         end
         if context.enemy_count < (context.settings.shadow_aoe_count or 4) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         local plates = MultiUnits:GetActiveUnitPlates()
         for unitID in pairs(plates) do
            if UnitExists(unitID) and not Unit(unitID):IsDead() then
               local vt = (Unit(unitID):HasDeBuffs(A.VampiricTouch.ID, "player", true) or 0)
               if vt == 0 and A.VampiricTouch:IsReady(unitID) then
                  return try_cast_fmt(A.VampiricTouch, icon, unitID, "[SHADOW]", "AoE VT", "on %s", unitID)
               end
            end
         end
         return nil
      end,
   }),

   -- [14] Low Mana PW:S (shield self when conserving mana, wand handled by framework AutoShoot)
   named("LowManaPWS", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         local threshold = context.settings.shadow_low_mana_pct or 50
         if context.mana_pct > threshold then
            return false
         end
         -- Only activate if DoTs are already up (higher-priority strategies handle reapply)
         if not state.swp_active then
            return false
         end
         if state.vt_remaining < 1.8 then
            return false
         end
         -- Only if we can actually shield
         if has_pws(PLAYER_UNIT) or has_weakened_soul(PLAYER_UNIT) then
            return false
         end
         return A.PowerWordShield:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         return try_cast(A.PowerWordShield, icon, PLAYER_UNIT, "[SHADOW] Low Mana: PW:S")
      end,
   }),

   -- Wand: framework AutoShoot handles wand automatically when no strategy matches
   -- (moving = all cast strategies skip, low mana = MindFlay yields → framework wands)
}, {
   context_builder = get_shadow_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Shadow rotation loaded")
