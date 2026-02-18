---@meta
--- GGL Action Framework - Unit System Stubs
--- Auto-generated with type information

---@class Unit
local Unit = {}

---@param spell? any
---@param filter? any
---@param caster? any
---@param byID? any
---@param kindKey? any
---@param requestedIndex? any
---@return any
function Unit:AuraTooltipNumberByIndex(spell, filter, caster, byID, kindKey, requestedIndex) end

--- First non-zero aura value
---@param spell? any
---@param filter? any
---@param caster? any
---@param byID? any
---@return number
function Unit:AuraVariableNumber(spell, filter, caster, byID) end

---@param range? any
---@return any
function Unit:AverageTTD(range) end

---@param otherunit? any
---@return any
function Unit:CanCooperate(otherunit) end

--- Within range
---@param range? any
---@param orBooleanInRange? any
---@return boolean
function Unit:CanInterract(range, orBooleanInRange) end

--- Can be interrupted
---@param kickAble? any
---@param auras? any
---@param minX? any
---@param maxX? any
---@return boolean
function Unit:CanInterrupt(kickAble, auras, minX, maxX) end

--- total, remaining, percent, spellID, name, notKickable, isChannel
---@param argSpellID? any
---@return number, number, number, number, string, boolean, boolean
function Unit:CastTime(argSpellID) end

--- Class uppercase (WARRIOR)
---@return string
function Unit:Class() end

--- elite, worldboss, rare, or empty
---@return string
function Unit:Classification() end

--- Time in combat, GUID
---@return number, string
function Unit:CombatTime() end

--- Wolf, Cat, Imp, etc.
---@return string
function Unit:CreatureFamily() end

--- Beast, Demon, Humanoid, etc.
---@return string
function Unit:CreatureType() end

---@return any
function Unit:DeBuffCyclone() end

---@param unitID? any
---@param stop? any
---@param range? any
---@return any
function Unit:FocusingUnitIDByClasses(unitID, stop, range) end

--- Total absorb taken
---@param spell? any
---@return number
function Unit:GetAbsorb(spell) end

---@return any
function Unit:GetBlinkOrShrimmer() end

--- rank, remain, duration, stacks
---@param auraTable? any
---@param caster? any
---@return number, number, number, number
function Unit:GetBuffInfo(auraTable, caster) end

---@param auraName? any
---@param caster? any
---@return any
function Unit:GetBuffInfoByName(auraName, caster) end

---@param spells? any
---@param range? any
---@param source? any
---@return any
function Unit:GetBuffs(spells, range, source) end

---@param spells? any
---@return any
function Unit:GetCC(spells) end

---@param spellName? any
---@return any
function Unit:GetCooldown(spellName) end

--- Current speed %, max speed %
---@return number, number
function Unit:GetCurrentSpeed() end

--- Damage taken (smoothed)
---@param index? any
---@return number
function Unit:GetDMG(index) end

--- Damage done (smoothed)
---@param index? any
---@return number
function Unit:GetDPS(index) end

--- DR_Tick, DR_Remain, DR_App, DR_Max
---@param drCat? any
---@return number, number, number, number
function Unit:GetDR(drCat) end

--- rank, remain, duration, stacks
---@param auraTable? any
---@param caster? any
---@return number, number, number, number
function Unit:GetDeBuffInfo(auraTable, caster) end

---@param auraName? any
---@param caster? any
---@return any
function Unit:GetDeBuffInfoByName(auraName, caster) end

---@param spells? any
---@param range? any
---@return any
function Unit:GetDeBuffs(spells, range) end

--- Healing taken
---@param index? any
---@return number
function Unit:GetHEAL(index) end

--- Healing done
---@param index? any
---@return number
function Unit:GetHPS(index) end

--- Predicted healing
---@param castTime? any
---@param unitGUID? any
---@return number
function Unit:GetIncomingHeals(castTime, unitGUID) end

--- Including self-heals
---@param castTime? any
---@param unitGUID? any
---@return number
function Unit:GetIncomingHealsIncSelf(castTime, unitGUID) end

--- Has incoming res
---@return boolean
function Unit:GetIncomingResurrection() end

--- Damage in last X seconds
---@param x? any
---@return number
function Unit:GetLastTimeDMGX(x) end

--- Unit level or 0
---@return number
function Unit:GetLevel() end

---@param spellName? any
---@return any
function Unit:GetMaxDuration(spellName) end

--- Max movement speed %
---@return number
function Unit:GetMaxSpeed() end

--- Max range, min range
---@return number, number
function Unit:GetRange() end

--- Damage taken
---@param index? any
---@return number
function Unit:GetRealTimeDMG(index) end

--- Damage done
---@param index? any
---@return number
function Unit:GetRealTimeDPS(index) end

---@param index? any
---@return any
function Unit:GetSchoolDMG(index) end

--- Spell damage/healing
---@param spell? any
---@return number
function Unit:GetSpellAmount(spell) end

--- Spell damage in X seconds
---@param spell? any
---@param x? any
---@return number
function Unit:GetSpellAmountX(spell, x) end

--- Total casts
---@param spell? any
---@return number
function Unit:GetSpellCounter(spell) end

--- Seconds since, timestamp
---@param spell? any
---@return number, number
function Unit:GetSpellLastCast(spell) end

---@param count? any
---@param seconds? any
---@param range? any
---@return any
function Unit:GetTTD(count, seconds, range) end

--- Healing absorb amount
---@return number
function Unit:GetTotalHealAbsorbs() end

--- Absorb as % of HP
---@return number
function Unit:GetTotalHealAbsorbsPercent() end

---@param range? any
---@return any
function Unit:GetUnitID(range) end

--- Remaining time, total duration
---@param spell? any
---@param caster? any
---@param byID? any
---@return number, number
function Unit:HasBuffs(spell, caster, byID) end

--- Stack count
---@param spell? any
---@param caster? any
---@param byID? any
---@return number
function Unit:HasBuffsStacks(spell, caster, byID) end

--- Stack count
---@param spell? any
---@param caster? any
---@param byID? any
---@return number
function Unit:HasDeBuffsStacks(spell, caster, byID) end

--- Carrying BG flag
---@return boolean
function Unit:HasFlags() end

---@param checkVisible? any
---@return any
function Unit:HasInvisibleUnits(checkVisible) end

--- Has spec ID
---@param specID? any
---@return boolean
function Unit:HasSpec(specID) end

---@param burst? any
---@param deffensive? any
---@param range? any
---@param isMelee? any
---@return any
function Unit:HealerIsFocused(burst, deffensive, range, isMelee) end

--- Current health
---@return number
function Unit:Health() end

--- Missing health
---@return number
function Unit:HealthDeficit() end

--- Missing health %
---@return number
function Unit:HealthDeficitPercent() end

--- Maximum health
---@return number
function Unit:HealthMax() end

--- Current health %
---@return number
function Unit:HealthPercent() end

--- HP% gained per second
---@return number
function Unit:HealthPercentGainPerSecond() end

--- HP% lost per second
---@return number
function Unit:HealthPercentLosePerSecond() end

--- Remaining CC time
---@param index? any
---@return number
function Unit:InCC(index) end

--- In player's group
---@param includeAnyGroups? any
---@param unitGUID? any
---@return boolean
function Unit:InGroup(includeAnyGroups, unitGUID) end

--- In line of sight
---@param unitGUID? any
---@return boolean
function Unit:InLOS(unitGUID) end

--- In player's party
---@return boolean
function Unit:InParty() end

--- In player's raid
---@return boolean
function Unit:InRaid() end

--- In interact range
---@return boolean
function Unit:InRange() end

--- In vehicle
---@return boolean
function Unit:InVehicle() end

--- GUID parsed info
---@param unitGUID? any
---@return string, number, number, number, number, number, number
function Unit:InfoGUID(unitGUID) end

--- Unit is boss
---@return boolean
function Unit:IsBoss() end

---@param range? any
---@return any
function Unit:IsBreakAble(range) end

--- name, start, end, notKickable, spellID, isChannel
---@return string, number, number, boolean, number, boolean
function Unit:IsCasting() end

---@param offset? any
---@return any
function Unit:IsCastingBreakAble(offset) end

--- remaining, percent, spellID, name, notKickable, isChannel
---@param argSpellID? any
---@return number, number, number, string, boolean, boolean
function Unit:IsCastingRemains(argSpellID) end

--- Unit is mind-controlled
---@return boolean
function Unit:IsCharmed() end

--- Unit is online
---@return boolean
function Unit:IsConnected() end

--- Can be CC'd
---@param drCat? any
---@param DR_Tick? any
---@return boolean
function Unit:IsControlAble(drCat, DR_Tick) end

--- Unit is DPS
---@param class? any
---@return boolean
function Unit:IsDamager(class) end

---@return any
function Unit:IsDeBuffsLimited() end

--- Unit is dead
---@return boolean
function Unit:IsDead() end

--- CreatureType is Demon
---@return boolean
function Unit:IsDemon() end

--- Unit is target dummy
---@return boolean
function Unit:IsDummy() end

--- CreatureType is Elemental
---@return boolean
function Unit:IsElemental() end

--- Unit is hostile
---@param isPlayer? any
---@return boolean
function Unit:IsEnemy(isPlayer) end

--- In execute range
---@return boolean
function Unit:IsExecuted() end

--- Unit exists
---@return boolean
function Unit:IsExists() end

--- Being focused
---@param burst? any
---@param deffensive? any
---@param range? any
---@param isMelee? any
---@return boolean
function Unit:IsFocused(burst, deffensive, range, isMelee) end

--- Unit is ghost
---@return boolean
function Unit:IsGhost() end

--- Unit is healer
---@param class? any
---@return boolean
function Unit:IsHealer(class) end

--- Class can be healer
---@return boolean
function Unit:IsHealerClass() end

--- CreatureType is Humanoid
---@return boolean
function Unit:IsHumanoid() end

--- Unit is melee
---@param class? any
---@return boolean
function Unit:IsMelee(class) end

--- Class can be melee
---@return boolean
function Unit:IsMeleeClass() end

--- Unit is mounted
---@return boolean
function Unit:IsMounted() end

--- Unit is moving
---@return boolean
function Unit:IsMoving() end

--- Moving toward player
---@param snap_timer? any
---@return boolean
function Unit:IsMovingIn(snap_timer) end

--- Moving away from player
---@param snap_timer? any
---@return boolean
function Unit:IsMovingOut(snap_timer) end

--- Seconds moving
---@return number
function Unit:IsMovingTime() end

--- Unit is NPC
---@return boolean
function Unit:IsNPC() end

--- Has nameplate, unitID
---@return boolean, string
function Unit:IsNameplate() end

--- Any nameplate, unitID
---@return boolean, string
function Unit:IsNameplateAny() end

--- Has level penalty
---@return boolean
function Unit:IsPenalty() end

--- Unit is pet
---@return boolean
function Unit:IsPet() end

--- Unit is player
---@return boolean
function Unit:IsPlayer() end

--- Player or player-controlled
---@return boolean
function Unit:IsPlayerOrPet() end

---@param offset? any
---@return any
function Unit:IsPremonitionAble(offset) end

---@param offset? any
---@return any
function Unit:IsReshiftAble(offset) end

---@param spellName? any
---@return any
function Unit:IsSpellInFly(spellName) end

--- Unit is stationary
---@return boolean
function Unit:IsStaying() end

--- Seconds stationary
---@return number
function Unit:IsStayingTime() end

--- Unit is tank
---@param class? any
---@return boolean
function Unit:IsTank(class) end

--- Class can be tank
---@return boolean
function Unit:IsTankClass() end

--- Tanking target
---@param otherunitID? any
---@param range? any
---@return boolean
function Unit:IsTanking(otherunitID, range) end

--- Tanking any nameplate
---@param range? any
---@return boolean
function Unit:IsTankingAoE(range) end

---@param object? any
---@param range? any
---@return any
function Unit:IsTauntPetAble(object, range) end

--- CreatureType is Totem
---@return boolean
function Unit:IsTotem() end

--- CreatureType is Undead
---@return boolean
function Unit:IsUndead() end

--- Unit is visible
---@return boolean
function Unit:IsVisible() end

---@param spells? any
---@param source? any
---@return any
function Unit:MissedBuffs(spells, source) end

---@param spells? any
---@param range? any
---@return any
function Unit:MultiCast(spells, range) end

--- Unit name or 'none'
---@return string
function Unit:Name() end

--- Pandemic threshold (<=30%)
---@param spell? any
---@param debuff? any
---@param byID? any
---@return boolean
function Unit:PT(spell, debuff, byID) end

---@param range? any
---@param combatTime? any
---@return any
function Unit:PlayersInCombat(range, combatTime) end

---@param stop? any
---@param range? any
---@return any
function Unit:PlayersInRange(stop, range) end

--- Current power
---@return number
function Unit:Power() end

--- Missing power
---@return number
function Unit:PowerDeficit() end

--- Missing power %
---@return number
function Unit:PowerDeficitPercent() end

--- Maximum power
---@return number
function Unit:PowerMax() end

--- Current power %
---@return number
function Unit:PowerPercent() end

--- MANA, ENERGY, RAGE, etc.
---@return string
function Unit:PowerType() end

--- Unit race (English)
---@return string
function Unit:Race() end

--- TANK, HEALER, DAMAGER, NONE
---@param hasRole? any
---@return string
function Unit:Role(hasRole) end

--- Highest remaining, duration
---@param spell? any
---@param caster? any
---@param byID? any
---@return number, number
function Unit:SortBuffs(spell, caster, byID) end

--- Highest remaining, duration
---@param spell? any
---@param caster? any
---@param byID? any
---@return number, number
function Unit:SortDeBuffs(spell, caster, byID) end

--- status, percent, value
---@param otherunitID? any
---@return number, number, number
function Unit:ThreatSituation(otherunitID) end

--- Seconds until 0%
---@return number
function Unit:TimeToDie() end

--- TTD from magic only
---@return number
function Unit:TimeToDieMagic() end

--- TTD magic to X%
---@param x? any
---@return number
function Unit:TimeToDieMagicX(x) end

--- Seconds until X%
---@param x? any
---@return number
function Unit:TimeToDieX(x) end

--- Should use burst
---@param pBurst? any
---@return boolean
function Unit:UseBurst(pBurst) end

--- Should use defensives
---@return boolean
function Unit:UseDeff() end
