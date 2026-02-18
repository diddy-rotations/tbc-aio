---@meta
--- GGL Action Framework - Player System Stubs
--- Auto-generated with type information

---@class Player
local Player = {}

--- Register bag tracking
---@param name? any
---@param data? any
---@return nil
function Player:AddBag(name, data) end

--- Register inv slot
---@param name? any
---@param slot? any
---@param data? any
---@return nil
function Player:AddInv(name, slot, data) end

--- Register tier set
---@param tier? any
---@param items? any
---@return nil
function Player:AddTier(tier, items) end

--- Current charges
---@return number
function Player:ArcaneCharges() end

---@return any
function Player:ArcaneChargesDeficit() end

---@return any
function Player:ArcaneChargesDeficitPercentage() end

--- Max charges
---@return number
function Player:ArcaneChargesMax() end

---@return any
function Player:ArcaneChargesPercentage() end

--- Current AP
---@param OverrideFutureAstralPower? any
---@return number
function Player:AstralPower(OverrideFutureAstralPower) end

--- Missing AP
---@param OverrideFutureAstralPower? any
---@return number
function Player:AstralPowerDeficit(OverrideFutureAstralPower) end

---@param OverrideFutureAstralPower? any
---@return any
function Player:AstralPowerDeficitPercentage(OverrideFutureAstralPower) end

--- Max AP
---@return number
function Player:AstralPowerMax() end

--- AP %
---@param OverrideFutureAstralPower? any
---@return number
function Player:AstralPowerPercentage(OverrideFutureAstralPower) end

--- AP damage mod
---@param offHand? any
---@return number
function Player:AttackPowerDamageMod(offHand) end

--- Cancel buff
---@param buffName? any
---@return nil
function Player:CancelBuff(buffName) end

--- Real-time cast cost
---@return number
function Player:CastCost() end

--- Cached cast cost
---@return number
function Player:CastCostCache() end

--- Remaining cast time
---@param spellID? any
---@return number
function Player:CastRemains(spellID) end

--- Seconds since cast
---@return number
function Player:CastTimeSinceStart() end

--- Current chi
---@return number
function Player:Chi() end

---@return any
function Player:ChiDeficit() end

---@return any
function Player:ChiDeficitPercentage() end

--- Max chi
---@return number
function Player:ChiMax() end

---@return any
function Player:ChiPercentage() end

--- Current CP
---@param unitID? any
---@return number
function Player:ComboPoints(unitID) end

--- Missing CP
---@param unitID? any
---@return number
function Player:ComboPointsDeficit(unitID) end

--- Max CP
---@return number
function Player:ComboPointsMax() end

--- Crit %
---@return number
function Player:CritChancePct() end

--- Current energy
---@return number
function Player:Energy() end

--- Missing energy
---@return number
function Player:EnergyDeficit() end

--- Missing energy %
---@return number
function Player:EnergyDeficitPercentage() end

--- Predicted deficit
---@param Offset? any
---@return number
function Player:EnergyDeficitPredicted(Offset) end

--- Max energy
---@return number
function Player:EnergyMax() end

--- Energy %
---@return number
function Player:EnergyPercentage() end

--- Predicted energy
---@param Offset? any
---@return number
function Player:EnergyPredicted(Offset) end

--- Energy/second
---@return number
function Player:EnergyRegen() end

--- Regen as % of max
---@return number
function Player:EnergyRegenPercentage() end

--- Energy during cast
---@param Offset? any
---@return number
function Player:EnergyRemainingCastRegen(Offset) end

--- Seconds to full
---@return number
function Player:EnergyTimeToMax() end

--- Predicted time to max
---@return number
function Player:EnergyTimeToMaxPredicted() end

--- Seconds to X
---@param Amount? any
---@param Offset? any
---@return number
function Player:EnergyTimeToX(Amount, Offset) end

--- Seconds to X%
---@param Amount? any
---@return number
function Player:EnergyTimeToXPercentage(Amount) end

--- Current essence
---@return number
function Player:Essence() end

---@return any
function Player:EssenceDeficit() end

---@return any
function Player:EssenceDeficitPercentage() end

--- Max essence
---@return number
function Player:EssenceMax() end

--- GCD or cast time
---@param spellID? any
---@return number
function Player:Execute_Time(spellID) end

--- Current focus
---@return number
function Player:Focus() end

--- Focus during cast
---@param CastTime? any
---@return number
function Player:FocusCastRegen(CastTime) end

--- Missing focus
---@return number
function Player:FocusDeficit() end

--- Missing focus %
---@return number
function Player:FocusDeficitPercentage() end

--- Predicted deficit
---@param Offset? any
---@return number
function Player:FocusDeficitPredicted(Offset) end

--- Focus cost of cast
---@return number
function Player:FocusLossOnCastEnd() end

--- Max focus
---@return number
function Player:FocusMax() end

--- Focus %
---@return number
function Player:FocusPercentage() end

--- Predicted focus
---@param Offset? any
---@return number
function Player:FocusPredicted(Offset) end

--- Focus/second
---@return number
function Player:FocusRegen() end

--- Regen as % of max
---@return number
function Player:FocusRegenPercentage() end

--- Focus during remaining
---@param Offset? any
---@return number
function Player:FocusRemainingCastRegen(Offset) end

--- Seconds to full
---@return number
function Player:FocusTimeToMax() end

--- Predicted time to max
---@return number
function Player:FocusTimeToMaxPredicted() end

--- Seconds to X
---@param Amount? any
---@return number
function Player:FocusTimeToX(Amount) end

--- Seconds to X%
---@param Amount? any
---@return number
function Player:FocusTimeToXPercentage(Amount) end

--- Current fury
---@return number
function Player:Fury() end

---@return any
function Player:FuryDeficit() end

---@return any
function Player:FuryDeficitPercentage() end

--- Max fury
---@return number
function Player:FuryMax() end

---@return any
function Player:FuryPercentage() end

--- Remaining GCD
---@return number
function Player:GCDRemains() end

--- Ammo count
---@return number
function Player:GetAmmo() end

--- Arrow count
---@return number
function Player:GetArrow() end

--- Bag item info
---@param name? any
---@return table
function Player:GetBag(name) end

--- Units, buffs
---@return number, number
function Player:GetBuffsUnitCount() end

--- Bullet count
---@return number
function Player:GetBullet() end

--- Units, debuffs
---@return number, number
function Player:GetDeBuffsUnitCount() end

--- Falling duration
---@return number
function Player:GetFalling() end

--- Inv item info
---@param name? any
---@return table
function Player:GetInv(name) end

--- Current stance
---@return number
function Player:GetStance() end

--- Swing timer
---@param inv? any
---@return number
function Player:GetSwing(inv) end

--- Max swing duration
---@param inv? any
---@return number
function Player:GetSwingMax(inv) end

--- Next auto-shot
---@return number
function Player:GetSwingShoot() end

--- Swing start time
---@param inv? any
---@return number
function Player:GetSwingStart(inv) end

--- Thrown count
---@return number
function Player:GetThrown() end

--- Tier pieces
---@param tier? any
---@return number
function Player:GetTier(tier) end

--- have, name, start, dur, icon
---@param i? any
---@return boolean, string, number, number, string
function Player:GetTotemInfo(i) end

--- Totem remaining
---@param i? any
---@return number
function Player:GetTotemTimeLeft(i) end

--- Damage, DPS
---@param inv? any
---@param mod? any
---@return number, number
function Player:GetWeaponMeleeDamage(inv, mod) end

--- Glyph active
---@param spell? any
---@return boolean
function Player:HasGlyph(spell) end

--- Shield itemID or nil
---@param isEquiped? any
---@return number
function Player:HasShield(isEquiped) end

--- Has X pieces
---@param tier? any
---@param count? any
---@return boolean
function Player:HasTier(tier, count) end

--- Dagger itemID
---@param isEquiped? any
---@return number
function Player:HasWeaponMainOneHandDagger(isEquiped) end

--- Sword itemID
---@param isEquiped? any
---@return number
function Player:HasWeaponMainOneHandSword(isEquiped) end

--- Off-hand itemID
---@param isEquiped? any
---@return number
function Player:HasWeaponOffHand(isEquiped) end

--- Off sword itemID
---@param isEquiped? any
---@return number
function Player:HasWeaponOffOneHandSword(isEquiped) end

--- Two-hand itemID
---@param isEquiped? any
---@return number
function Player:HasWeaponTwoHand(isEquiped) end

--- Haste %
---@return number
function Player:HastePct() end

--- Current HP
---@return number
function Player:HolyPower() end

---@return any
function Player:HolyPowerDeficit() end

---@return any
function Player:HolyPowerDeficitPercentage() end

--- Max HP
---@return number
function Player:HolyPowerMax() end

---@return any
function Player:HolyPowerPercentage() end

--- Current insanity
---@return number
function Player:Insanity() end

---@return any
function Player:InsanityDeficit() end

---@return any
function Player:InsanityDeficitPercentage() end

--- Max insanity
---@return number
function Player:InsanityMax() end

---@return any
function Player:InsanityPercentage() end

---@return any
function Player:Insanityrain() end

--- Melee auto-attack
---@return boolean
function Player:IsAttacking() end

--- Behind target
---@param x? any
---@return boolean
function Player:IsBehind(x) end

--- Seconds since not behind
---@return number
function Player:IsBehindTime() end

--- Spell name or nil
---@return string
function Player:IsCasting() end

--- Spell name or nil
---@return string
function Player:IsChanneling() end

--- Is falling, duration
---@return boolean, number
function Player:IsFalling() end

--- Player mounted
---@return boolean
function Player:IsMounted() end

--- Player moving
---@return boolean
function Player:IsMoving() end

--- Seconds moving
---@return number
function Player:IsMovingTime() end

--- Pet behind target
---@param x? any
---@return boolean
function Player:IsPetBehind(x) end

--- Pet behind time
---@return number
function Player:IsPetBehindTime() end

--- Auto-shot active
---@return boolean
function Player:IsShooting() end

--- In stance X
---@param x? any
---@return boolean
function Player:IsStance(x) end

--- Player stationary
---@return boolean
function Player:IsStaying() end

--- Seconds stationary
---@return number
function Player:IsStayingTime() end

--- Player stealthed
---@return boolean
function Player:IsStealthed() end

--- Swap locked
---@return boolean
function Player:IsSwapLocked() end

--- Player swimming
---@return boolean
function Player:IsSwimming() end

--- Current maelstrom
---@return number
function Player:Maelstrom() end

---@return any
function Player:MaelstromDeficit() end

---@return any
function Player:MaelstromDeficitPercentage() end

--- Max maelstrom
---@return number
function Player:MaelstromMax() end

---@return any
function Player:MaelstromPercentage() end

--- Current mana
---@return number
function Player:Mana() end

--- Mana during cast
---@param CastTime? any
---@return number
function Player:ManaCastRegen(CastTime) end

--- Missing mana
---@return number
function Player:ManaDeficit() end

--- Predicted deficit
---@return number
function Player:ManaDeficitP() end

--- Missing mana %
---@return number
function Player:ManaDeficitPercentage() end

--- Predicted deficit %
---@return number
function Player:ManaDeficitPercentageP() end

--- Max mana
---@return number
function Player:ManaMax() end

--- Predicted mana
---@return number
function Player:ManaP() end

--- Mana %
---@return number
function Player:ManaPercentage() end

--- Predicted mana %
---@return number
function Player:ManaPercentageP() end

--- Mana/second
---@return number
function Player:ManaRegen() end

--- Mana during remaining cast
---@param Offset? any
---@return number
function Player:ManaRemainingCastRegen(Offset) end

--- Seconds to full
---@return number
function Player:ManaTimeToMax() end

--- Seconds to X
---@param Amount? any
---@return number
function Player:ManaTimeToX(Amount) end

--- Current pain
---@return number
function Player:Pain() end

---@return any
function Player:PainDeficit() end

---@return any
function Player:PainDeficitPercentage() end

--- Max pain
---@return number
function Player:PainMax() end

---@return any
function Player:PainPercentage() end

--- Current rage
---@return number
function Player:Rage() end

--- Missing rage
---@return number
function Player:RageDeficit() end

--- Missing rage %
---@return number
function Player:RageDeficitPercentage() end

--- Max rage
---@return number
function Player:RageMax() end

--- Rage %
---@return number
function Player:RagePercentage() end

---@return any
function Player:RegisterAmmo() end

---@return any
function Player:RegisterShield() end

---@return any
function Player:RegisterThrown() end

---@return any
function Player:RegisterWeaponMainOneHandDagger() end

---@return any
function Player:RegisterWeaponMainOneHandSword() end

---@return any
function Player:RegisterWeaponOffHand() end

---@return any
function Player:RegisterWeaponOffOneHandSword() end

---@return any
function Player:RegisterWeaponTwoHand() end

--- Unregister bag
---@param name? any
---@return nil
function Player:RemoveBag(name) end

--- Unregister inv
---@param name? any
---@return nil
function Player:RemoveInv(name) end

--- Unregister tier
---@param tier? any
---@return nil
function Player:RemoveTier(tier) end

---@param inv? any
---@param dur? any
---@return any
function Player:ReplaceSwingDuration(inv, dur) end

--- Ready runes
---@param presence? any
---@return number
function Player:Rune(presence) end

--- Seconds to X runes
---@param Value? any
---@return number
function Player:RuneTimeToX(Value) end

--- Current RP
---@return number
function Player:RunicPower() end

--- Missing RP
---@return number
function Player:RunicPowerDeficit() end

--- Missing RP %
---@return number
function Player:RunicPowerDeficitPercentage() end

--- Max RP
---@return number
function Player:RunicPowerMax() end

--- RP %
---@return number
function Player:RunicPowerPercentage() end

--- Current shards
---@return number
function Player:SoulShards() end

--- Missing shards
---@return number
function Player:SoulShardsDeficit() end

--- Max shards
---@return number
function Player:SoulShardsMax() end

--- Predicted shards
---@return number
function Player:SoulShardsP() end

--- Spell haste multiplier
---@return number
function Player:SpellHaste() end

--- Current stagger
---@return number
function Player:Stagger() end

--- Max stagger
---@return number
function Player:StaggerMax() end

--- Stagger %
---@return number
function Player:StaggerPercentage() end

--- Target behind player
---@param x? any
---@return boolean
function Player:TargetIsBehind(x) end

--- Target behind time
---@return number
function Player:TargetIsBehindTime() end
