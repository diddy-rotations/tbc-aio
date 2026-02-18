-- Method type definitions for stub generation
-- Format: methodName = { returns = "type", params = { {name="x", type="type"}, ... }, desc = "description" }

local MethodTypes = {}

-- ActionObject methods
MethodTypes.ActionObject = {
    -- Ready checks
    IsReady = { returns = "boolean", desc = "Full ready check with all conditions" },
    IsReadyP = { returns = "boolean", desc = "Passive ready check (skips block/queue)" },
    IsReadyM = { returns = "boolean", desc = "MSG system check (bypasses GCD)" },
    IsReadyByPassCastGCD = { returns = "boolean", desc = "Bypasses cast/GCD blocking" },
    IsReadyByPassCastGCDP = { returns = "boolean", desc = "Bypasses cast/GCD for passive slots" },
    IsReadyToUse = { returns = "boolean", desc = "Simplified ready check without range" },
    IsCastable = { returns = "boolean", desc = "Core castability check" },
    IsUsable = { returns = "boolean", desc = "Resource + cooldown check" },
    IsExists = { returns = "boolean", desc = "Spell known/item available" },

    -- Spell info
    GetSpellInfo = { returns = "string, string, number, number, number, number, number, number", desc = "name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon" },
    GetSpellBaseCooldown = { returns = "number", desc = "Unmodified spell cooldown in seconds" },
    GetSpellCastTime = { returns = "number", desc = "Cast time in seconds" },
    GetSpellCastTimeCache = { returns = "number", desc = "Cached cast time" },
    GetSpellCharges = { returns = "number", desc = "Current charges" },
    GetSpellChargesMax = { returns = "number", desc = "Maximum charges" },
    GetSpellChargesFrac = { returns = "number", desc = "Fractional charges" },
    GetSpellChargesFullRechargeTime = { returns = "number", desc = "Time to full recharge" },
    GetSpellTimeSinceLastCast = { returns = "number", desc = "Seconds since last cast" },
    GetSpellCounter = { returns = "number", desc = "Total casts this fight" },
    GetSpellAmount = { returns = "number", desc = "Damage/healing amount" },
    GetSpellAbsorb = { returns = "number", desc = "Current absorb amount" },
    GetSpellBaseDuration = { returns = "number", desc = "Base duration from enum" },
    GetSpellMaxDuration = { returns = "number", desc = "Maximum duration" },
    GetSpellPandemicThreshold = { returns = "number", desc = "Pandemic threshold (30%)" },
    GetSpellTravelTime = { returns = "number", desc = "Projectile travel time" },
    GetSpellLink = { returns = "string", desc = "Spell link for chat" },
    GetSpellIcon = { returns = "number", desc = "Icon texture ID" },
    GetSpellTexture = { returns = "string, number", desc = "TMW texture type and ID" },
    GetSpellPowerCostCache = { returns = "number, number", desc = "Cached cost and power type" },
    GetSpellRank = { returns = "number", desc = "Current spell rank" },
    GetSpellMaxRank = { returns = "number", desc = "Maximum available rank" },
    GetSpellAutocast = { returns = "boolean, boolean", desc = "autocastable, autostate" },

    -- Spell state
    IsSpellLastGCD = { returns = "boolean", desc = "Was last GCD action" },
    IsSpellLastCastOrGCD = { returns = "boolean", desc = "Was last GCD or is casting" },
    IsSpellInFlight = { returns = "boolean", desc = "Projectile in flight" },
    IsSpellInRange = { returns = "boolean", desc = "In range of target" },
    IsSpellInCasting = { returns = "boolean", desc = "Currently casting this spell" },
    IsSpellCurrent = { returns = "boolean", desc = "Spell is active/channeling" },

    -- Cooldown & count
    GetCooldown = { returns = "number", desc = "Remaining cooldown" },
    GetCount = { returns = "number", desc = "Charges or stack count" },
    GetItemCooldown = { returns = "number", desc = "Item cooldown remaining" },

    -- Range & immunity
    IsInRange = { returns = "boolean", desc = "Action is in range" },
    HasRange = { returns = "boolean", desc = "Action has range requirement" },
    AbsentImun = { returns = "boolean", desc = "Target not immune" },

    -- Item methods
    GetItemInfo = { returns = "string, string, number, number, string, string, string, number, string, number, number", desc = "Item info" },
    GetItemLink = { returns = "string", desc = "Item link" },
    GetItemIcon = { returns = "number", desc = "Item icon texture" },
    GetItemSpell = { returns = "string, number", desc = "spellName, spellID or nil" },
    GetItemCategory = { returns = "string", desc = "CC, MISC, BOTH, DPS, or DEFF" },
    IsItemTank = { returns = "boolean", desc = "Suitable for tanks" },
    IsItemDamager = { returns = "boolean", desc = "Suitable for DPS" },
    IsItemCurrent = { returns = "boolean", desc = "Item being used" },

    -- Talent
    GetTalentRank = { returns = "number", desc = "Talent rank (0-5)" },
    IsTalentLearned = { returns = "boolean", desc = "Talent has points" },

    -- Utility
    IsHarmful = { returns = "boolean", desc = "Action is offensive" },
    IsHelpful = { returns = "boolean", desc = "Action is friendly" },
    IsCurrent = { returns = "boolean", desc = "Spell/item active" },
    IsBlockedByAny = { returns = "boolean", desc = "Blocked by any condition" },
    IsBlockedBySpellBook = { returns = "boolean", desc = "Not in spellbook" },
    IsSuspended = { returns = "boolean", desc = "Rate-limited" },
    GetKeyName = { returns = "string", desc = "Key name in action table" },
    CanSafetyCastHeal = { returns = "boolean", desc = "Heal can complete before death" },
    IsRequiredGCD = { returns = "boolean, number", desc = "Requires GCD and amount" },
    ShouldStopByGCD = { returns = "boolean", desc = "Should stop due to GCD" },

    -- Racial
    IsRacialReady = { returns = "boolean", desc = "Racial ready check" },
    IsRacialReadyP = { returns = "boolean", desc = "Racial ready (passive)" },
    AutoRacial = { returns = "boolean", desc = "Auto-use racial" },

    -- Display
    Show = { returns = "boolean", desc = "Display on icon" },
    GetColorTexture = { returns = "string, table", desc = "Color state data" },
    GetColoredSpellTexture = { returns = "string, table, number", desc = "Colored texture data" },
    GetColoredItemTexture = { returns = "string, table, number", desc = "Colored item texture" },
    GetColoredSwapTexture = { returns = "string, table, number", desc = "Colored swap texture" },
}

-- Unit methods
MethodTypes.Unit = {
    -- Basic info
    Name = { returns = "string", desc = "Unit name or 'none'" },
    Race = { returns = "string", desc = "Unit race (English)" },
    Class = { returns = "string", desc = "Class uppercase (WARRIOR)" },
    Role = { returns = "string", desc = "TANK, HEALER, DAMAGER, NONE" },
    Classification = { returns = "string", desc = "elite, worldboss, rare, or empty" },
    CreatureType = { returns = "string", desc = "Beast, Demon, Humanoid, etc." },
    CreatureFamily = { returns = "string", desc = "Wolf, Cat, Imp, etc." },
    GetLevel = { returns = "number", desc = "Unit level or 0" },

    -- Status
    IsExists = { returns = "boolean", desc = "Unit exists" },
    IsDead = { returns = "boolean", desc = "Unit is dead" },
    IsGhost = { returns = "boolean", desc = "Unit is ghost" },
    IsPlayer = { returns = "boolean", desc = "Unit is player" },
    IsPet = { returns = "boolean", desc = "Unit is pet" },
    IsPlayerOrPet = { returns = "boolean", desc = "Player or player-controlled" },
    IsNPC = { returns = "boolean", desc = "Unit is NPC" },
    IsVisible = { returns = "boolean", desc = "Unit is visible" },
    IsConnected = { returns = "boolean", desc = "Unit is online" },
    IsCharmed = { returns = "boolean", desc = "Unit is mind-controlled" },
    IsMounted = { returns = "boolean", desc = "Unit is mounted" },
    IsEnemy = { returns = "boolean", desc = "Unit is hostile" },

    -- Role detection
    IsHealer = { returns = "boolean", desc = "Unit is healer" },
    IsHealerClass = { returns = "boolean", desc = "Class can be healer" },
    IsTank = { returns = "boolean", desc = "Unit is tank" },
    IsTankClass = { returns = "boolean", desc = "Class can be tank" },
    IsDamager = { returns = "boolean", desc = "Unit is DPS" },
    IsMelee = { returns = "boolean", desc = "Unit is melee" },
    IsMeleeClass = { returns = "boolean", desc = "Class can be melee" },

    -- Creature types
    IsUndead = { returns = "boolean", desc = "CreatureType is Undead" },
    IsDemon = { returns = "boolean", desc = "CreatureType is Demon" },
    IsHumanoid = { returns = "boolean", desc = "CreatureType is Humanoid" },
    IsElemental = { returns = "boolean", desc = "CreatureType is Elemental" },
    IsTotem = { returns = "boolean", desc = "CreatureType is Totem" },
    IsDummy = { returns = "boolean", desc = "Unit is target dummy" },
    IsBoss = { returns = "boolean", desc = "Unit is boss" },

    -- Health
    Health = { returns = "number", desc = "Current health" },
    HealthMax = { returns = "number", desc = "Maximum health" },
    HealthDeficit = { returns = "number", desc = "Missing health" },
    HealthDeficitPercent = { returns = "number", desc = "Missing health %" },
    HealthPercent = { returns = "number", desc = "Current health %" },
    HealthPercentLosePerSecond = { returns = "number", desc = "HP% lost per second" },
    HealthPercentGainPerSecond = { returns = "number", desc = "HP% gained per second" },

    -- Power
    Power = { returns = "number", desc = "Current power" },
    PowerType = { returns = "string", desc = "MANA, ENERGY, RAGE, etc." },
    PowerMax = { returns = "number", desc = "Maximum power" },
    PowerDeficit = { returns = "number", desc = "Missing power" },
    PowerDeficitPercent = { returns = "number", desc = "Missing power %" },
    PowerPercent = { returns = "number", desc = "Current power %" },

    -- Movement
    IsMoving = { returns = "boolean", desc = "Unit is moving" },
    IsMovingTime = { returns = "number", desc = "Seconds moving" },
    IsStaying = { returns = "boolean", desc = "Unit is stationary" },
    IsStayingTime = { returns = "number", desc = "Seconds stationary" },
    IsMovingOut = { returns = "boolean", desc = "Moving away from player" },
    IsMovingIn = { returns = "boolean", desc = "Moving toward player" },
    GetCurrentSpeed = { returns = "number, number", desc = "Current speed %, max speed %" },
    GetMaxSpeed = { returns = "number", desc = "Max movement speed %" },

    -- Casting
    IsCasting = { returns = "string, number, number, boolean, number, boolean", desc = "name, start, end, notKickable, spellID, isChannel" },
    IsCastingRemains = { returns = "number, number, number, string, boolean, boolean", desc = "remaining, percent, spellID, name, notKickable, isChannel" },
    CastTime = { returns = "number, number, number, number, string, boolean, boolean", desc = "total, remaining, percent, spellID, name, notKickable, isChannel" },
    CanInterrupt = { returns = "boolean", desc = "Can be interrupted" },

    -- Buffs/Debuffs
    HasBuffs = { returns = "number, number", desc = "Remaining time, total duration" },
    SortBuffs = { returns = "number, number", desc = "Highest remaining, duration" },
    HasBuffsStacks = { returns = "number", desc = "Stack count" },
    HasDeBuffs = { returns = "number, number", desc = "Remaining time, total duration" },
    SortDeBuffs = { returns = "number, number", desc = "Highest remaining, duration" },
    HasDeBuffsStacks = { returns = "number", desc = "Stack count" },
    PT = { returns = "boolean", desc = "Pandemic threshold (<=30%)" },
    GetBuffInfo = { returns = "number, number, number, number", desc = "rank, remain, duration, stacks" },
    GetDeBuffInfo = { returns = "number, number, number, number", desc = "rank, remain, duration, stacks" },
    AuraVariableNumber = { returns = "number", desc = "First non-zero aura value" },

    -- Combat data
    CombatTime = { returns = "number, string", desc = "Time in combat, GUID" },
    GetLastTimeDMGX = { returns = "number", desc = "Damage in last X seconds" },
    GetRealTimeDMG = { returns = "number", desc = "Damage taken" },
    GetRealTimeDPS = { returns = "number", desc = "Damage done" },
    GetDMG = { returns = "number", desc = "Damage taken (smoothed)" },
    GetDPS = { returns = "number", desc = "Damage done (smoothed)" },
    GetHEAL = { returns = "number", desc = "Healing taken" },
    GetHPS = { returns = "number", desc = "Healing done" },
    GetSpellAmount = { returns = "number", desc = "Spell damage/healing" },
    GetSpellAmountX = { returns = "number", desc = "Spell damage in X seconds" },
    GetSpellLastCast = { returns = "number, number", desc = "Seconds since, timestamp" },
    GetSpellCounter = { returns = "number", desc = "Total casts" },
    GetAbsorb = { returns = "number", desc = "Total absorb taken" },

    -- TTD
    TimeToDie = { returns = "number", desc = "Seconds until 0%" },
    TimeToDieX = { returns = "number", desc = "Seconds until X%" },
    TimeToDieMagic = { returns = "number", desc = "TTD from magic only" },
    TimeToDieMagicX = { returns = "number", desc = "TTD magic to X%" },

    -- Range
    GetRange = { returns = "number, number", desc = "Max range, min range" },
    CanInterract = { returns = "boolean", desc = "Within range" },
    InRange = { returns = "boolean", desc = "In interact range" },
    InLOS = { returns = "boolean", desc = "In line of sight" },

    -- Group
    InGroup = { returns = "boolean", desc = "In player's group" },
    InParty = { returns = "boolean", desc = "In player's party" },
    InRaid = { returns = "boolean", desc = "In player's raid" },
    InVehicle = { returns = "boolean", desc = "In vehicle" },

    -- CC
    InCC = { returns = "number", desc = "Remaining CC time" },
    IsControlAble = { returns = "boolean", desc = "Can be CC'd" },
    GetDR = { returns = "number, number, number, number", desc = "DR_Tick, DR_Remain, DR_App, DR_Max" },

    -- Threat
    ThreatSituation = { returns = "number, number, number", desc = "status, percent, value" },
    IsTanking = { returns = "boolean", desc = "Tanking target" },
    IsTankingAoE = { returns = "boolean", desc = "Tanking any nameplate" },

    -- Healing
    GetIncomingResurrection = { returns = "boolean", desc = "Has incoming res" },
    GetIncomingHeals = { returns = "number", desc = "Predicted healing" },
    GetIncomingHealsIncSelf = { returns = "number", desc = "Including self-heals" },
    GetTotalHealAbsorbs = { returns = "number", desc = "Healing absorb amount" },
    GetTotalHealAbsorbsPercent = { returns = "number", desc = "Absorb as % of HP" },

    -- Special
    HasSpec = { returns = "boolean", desc = "Has spec ID" },
    HasFlags = { returns = "boolean", desc = "Carrying BG flag" },
    IsFocused = { returns = "boolean", desc = "Being focused" },
    IsExecuted = { returns = "boolean", desc = "In execute range" },
    UseBurst = { returns = "boolean", desc = "Should use burst" },
    UseDeff = { returns = "boolean", desc = "Should use defensives" },
    IsPenalty = { returns = "boolean", desc = "Has level penalty" },
    InfoGUID = { returns = "string, number, number, number, number, number, number", desc = "GUID parsed info" },
    IsNameplate = { returns = "boolean, string", desc = "Has nameplate, unitID" },
    IsNameplateAny = { returns = "boolean, string", desc = "Any nameplate, unitID" },
}

-- Player methods
MethodTypes.Player = {
    -- Status
    IsStance = { returns = "boolean", desc = "In stance X" },
    GetStance = { returns = "number", desc = "Current stance" },
    IsFalling = { returns = "boolean, number", desc = "Is falling, duration" },
    GetFalling = { returns = "number", desc = "Falling duration" },
    IsMoving = { returns = "boolean", desc = "Player moving" },
    IsMovingTime = { returns = "number", desc = "Seconds moving" },
    IsStaying = { returns = "boolean", desc = "Player stationary" },
    IsStayingTime = { returns = "number", desc = "Seconds stationary" },
    IsShooting = { returns = "boolean", desc = "Auto-shot active" },
    GetSwingShoot = { returns = "number", desc = "Next auto-shot" },
    IsAttacking = { returns = "boolean", desc = "Melee auto-attack" },
    IsBehind = { returns = "boolean", desc = "Behind target" },
    IsBehindTime = { returns = "number", desc = "Seconds since not behind" },
    IsPetBehind = { returns = "boolean", desc = "Pet behind target" },
    IsPetBehindTime = { returns = "number", desc = "Pet behind time" },
    TargetIsBehind = { returns = "boolean", desc = "Target behind player" },
    TargetIsBehindTime = { returns = "number", desc = "Target behind time" },
    IsMounted = { returns = "boolean", desc = "Player mounted" },
    IsSwimming = { returns = "boolean", desc = "Player swimming" },
    IsStealthed = { returns = "boolean", desc = "Player stealthed" },
    IsSwapLocked = { returns = "boolean", desc = "Swap locked" },

    -- Casting
    IsCasting = { returns = "string", desc = "Spell name or nil" },
    IsChanneling = { returns = "string", desc = "Spell name or nil" },
    CastTimeSinceStart = { returns = "number", desc = "Seconds since cast" },
    CastRemains = { returns = "number", desc = "Remaining cast time" },
    CastCost = { returns = "number", desc = "Real-time cast cost" },
    CastCostCache = { returns = "number", desc = "Cached cast cost" },
    CancelBuff = { returns = "nil", desc = "Cancel buff" },

    -- Stats
    CritChancePct = { returns = "number", desc = "Crit %" },
    HastePct = { returns = "number", desc = "Haste %" },
    SpellHaste = { returns = "number", desc = "Spell haste multiplier" },
    Execute_Time = { returns = "number", desc = "GCD or cast time" },
    GCDRemains = { returns = "number", desc = "Remaining GCD" },
    AttackPowerDamageMod = { returns = "number", desc = "AP damage mod" },

    -- Swing
    GetSwing = { returns = "number", desc = "Swing timer" },
    GetSwingMax = { returns = "number", desc = "Max swing duration" },
    GetSwingStart = { returns = "number", desc = "Swing start time" },
    GetWeaponMeleeDamage = { returns = "number, number", desc = "Damage, DPS" },

    -- Mana
    Mana = { returns = "number", desc = "Current mana" },
    ManaMax = { returns = "number", desc = "Max mana" },
    ManaPercentage = { returns = "number", desc = "Mana %" },
    ManaDeficit = { returns = "number", desc = "Missing mana" },
    ManaDeficitPercentage = { returns = "number", desc = "Missing mana %" },
    ManaRegen = { returns = "number", desc = "Mana/second" },
    ManaCastRegen = { returns = "number", desc = "Mana during cast" },
    ManaRemainingCastRegen = { returns = "number", desc = "Mana during remaining cast" },
    ManaTimeToMax = { returns = "number", desc = "Seconds to full" },
    ManaTimeToX = { returns = "number", desc = "Seconds to X" },
    ManaP = { returns = "number", desc = "Predicted mana" },
    ManaPercentageP = { returns = "number", desc = "Predicted mana %" },
    ManaDeficitP = { returns = "number", desc = "Predicted deficit" },
    ManaDeficitPercentageP = { returns = "number", desc = "Predicted deficit %" },

    -- Rage
    Rage = { returns = "number", desc = "Current rage" },
    RageMax = { returns = "number", desc = "Max rage" },
    RagePercentage = { returns = "number", desc = "Rage %" },
    RageDeficit = { returns = "number", desc = "Missing rage" },
    RageDeficitPercentage = { returns = "number", desc = "Missing rage %" },

    -- Energy
    Energy = { returns = "number", desc = "Current energy" },
    EnergyMax = { returns = "number", desc = "Max energy" },
    EnergyRegen = { returns = "number", desc = "Energy/second" },
    EnergyPercentage = { returns = "number", desc = "Energy %" },
    EnergyDeficit = { returns = "number", desc = "Missing energy" },
    EnergyDeficitPercentage = { returns = "number", desc = "Missing energy %" },
    EnergyRegenPercentage = { returns = "number", desc = "Regen as % of max" },
    EnergyTimeToMax = { returns = "number", desc = "Seconds to full" },
    EnergyTimeToX = { returns = "number", desc = "Seconds to X" },
    EnergyTimeToXPercentage = { returns = "number", desc = "Seconds to X%" },
    EnergyRemainingCastRegen = { returns = "number", desc = "Energy during cast" },
    EnergyPredicted = { returns = "number", desc = "Predicted energy" },
    EnergyDeficitPredicted = { returns = "number", desc = "Predicted deficit" },
    EnergyTimeToMaxPredicted = { returns = "number", desc = "Predicted time to max" },

    -- Focus
    Focus = { returns = "number", desc = "Current focus" },
    FocusMax = { returns = "number", desc = "Max focus" },
    FocusRegen = { returns = "number", desc = "Focus/second" },
    FocusPercentage = { returns = "number", desc = "Focus %" },
    FocusDeficit = { returns = "number", desc = "Missing focus" },
    FocusDeficitPercentage = { returns = "number", desc = "Missing focus %" },
    FocusRegenPercentage = { returns = "number", desc = "Regen as % of max" },
    FocusTimeToMax = { returns = "number", desc = "Seconds to full" },
    FocusTimeToX = { returns = "number", desc = "Seconds to X" },
    FocusTimeToXPercentage = { returns = "number", desc = "Seconds to X%" },
    FocusCastRegen = { returns = "number", desc = "Focus during cast" },
    FocusRemainingCastRegen = { returns = "number", desc = "Focus during remaining" },
    FocusLossOnCastEnd = { returns = "number", desc = "Focus cost of cast" },
    FocusPredicted = { returns = "number", desc = "Predicted focus" },
    FocusDeficitPredicted = { returns = "number", desc = "Predicted deficit" },
    FocusTimeToMaxPredicted = { returns = "number", desc = "Predicted time to max" },

    -- Combo Points
    ComboPoints = { returns = "number", desc = "Current CP" },
    ComboPointsMax = { returns = "number", desc = "Max CP" },
    ComboPointsDeficit = { returns = "number", desc = "Missing CP" },

    -- Runic Power
    RunicPower = { returns = "number", desc = "Current RP" },
    RunicPowerMax = { returns = "number", desc = "Max RP" },
    RunicPowerPercentage = { returns = "number", desc = "RP %" },
    RunicPowerDeficit = { returns = "number", desc = "Missing RP" },
    RunicPowerDeficitPercentage = { returns = "number", desc = "Missing RP %" },
    Rune = { returns = "number", desc = "Ready runes" },
    RuneTimeToX = { returns = "number", desc = "Seconds to X runes" },

    -- Soul Shards
    SoulShards = { returns = "number", desc = "Current shards" },
    SoulShardsMax = { returns = "number", desc = "Max shards" },
    SoulShardsP = { returns = "number", desc = "Predicted shards" },
    SoulShardsDeficit = { returns = "number", desc = "Missing shards" },

    -- Other resources
    AstralPower = { returns = "number", desc = "Current AP" },
    AstralPowerMax = { returns = "number", desc = "Max AP" },
    AstralPowerPercentage = { returns = "number", desc = "AP %" },
    AstralPowerDeficit = { returns = "number", desc = "Missing AP" },
    HolyPower = { returns = "number", desc = "Current HP" },
    HolyPowerMax = { returns = "number", desc = "Max HP" },
    Maelstrom = { returns = "number", desc = "Current maelstrom" },
    MaelstromMax = { returns = "number", desc = "Max maelstrom" },
    Chi = { returns = "number", desc = "Current chi" },
    ChiMax = { returns = "number", desc = "Max chi" },
    Insanity = { returns = "number", desc = "Current insanity" },
    InsanityMax = { returns = "number", desc = "Max insanity" },
    ArcaneCharges = { returns = "number", desc = "Current charges" },
    ArcaneChargesMax = { returns = "number", desc = "Max charges" },
    Fury = { returns = "number", desc = "Current fury" },
    FuryMax = { returns = "number", desc = "Max fury" },
    Pain = { returns = "number", desc = "Current pain" },
    PainMax = { returns = "number", desc = "Max pain" },
    Essence = { returns = "number", desc = "Current essence" },
    EssenceMax = { returns = "number", desc = "Max essence" },
    Stagger = { returns = "number", desc = "Current stagger" },
    StaggerMax = { returns = "number", desc = "Max stagger" },
    StaggerPercentage = { returns = "number", desc = "Stagger %" },

    -- Equipment
    GetAmmo = { returns = "number", desc = "Ammo count" },
    GetArrow = { returns = "number", desc = "Arrow count" },
    GetBullet = { returns = "number", desc = "Bullet count" },
    GetThrown = { returns = "number", desc = "Thrown count" },
    HasShield = { returns = "number", desc = "Shield itemID or nil" },
    HasWeaponOffHand = { returns = "number", desc = "Off-hand itemID" },
    HasWeaponTwoHand = { returns = "number", desc = "Two-hand itemID" },
    HasWeaponMainOneHandDagger = { returns = "number", desc = "Dagger itemID" },
    HasWeaponMainOneHandSword = { returns = "number", desc = "Sword itemID" },
    HasWeaponOffOneHandSword = { returns = "number", desc = "Off sword itemID" },

    -- Tier
    AddTier = { returns = "nil", desc = "Register tier set" },
    RemoveTier = { returns = "nil", desc = "Unregister tier" },
    GetTier = { returns = "number", desc = "Tier pieces" },
    HasTier = { returns = "boolean", desc = "Has X pieces" },

    -- Bags
    AddBag = { returns = "nil", desc = "Register bag tracking" },
    RemoveBag = { returns = "nil", desc = "Unregister bag" },
    GetBag = { returns = "table", desc = "Bag item info" },
    AddInv = { returns = "nil", desc = "Register inv slot" },
    RemoveInv = { returns = "nil", desc = "Unregister inv" },
    GetInv = { returns = "table", desc = "Inv item info" },

    -- Aura counting
    GetBuffsUnitCount = { returns = "number, number", desc = "Units, buffs" },
    GetDeBuffsUnitCount = { returns = "number, number", desc = "Units, debuffs" },
    HasGlyph = { returns = "boolean", desc = "Glyph active" },

    -- Totem
    GetTotemInfo = { returns = "boolean, string, number, number, string", desc = "have, name, start, dur, icon" },
    GetTotemTimeLeft = { returns = "number", desc = "Totem remaining" },
}

-- MultiUnits methods
MethodTypes.MultiUnits = {
    GetActiveUnitPlates = { returns = "table", desc = "Enemy nameplates" },
    GetActiveUnitPlatesAny = { returns = "table", desc = "All nameplates" },
    GetActiveUnitPlatesGUID = { returns = "table", desc = "Nameplates by GUID" },
    GetByRange = { returns = "number", desc = "Enemies in range" },
    GetByRangeInCombat = { returns = "number", desc = "Combat enemies in range" },
    GetByRangeCasting = { returns = "number", desc = "Casting enemies" },
    GetByRangeTaunting = { returns = "number", desc = "Enemies needing taunt" },
    GetByRangeMissedDoTs = { returns = "number", desc = "Enemies missing DoTs" },
    GetByRangeAppliedDoTs = { returns = "number", desc = "Enemies with DoTs" },
    GetByRangeIsFocused = { returns = "number, string", desc = "Enemies focusing, unitID" },
    GetByRangeAreaTTD = { returns = "number", desc = "Average TTD" },
    GetBySpell = { returns = "number", desc = "Enemies in spell range" },
    GetBySpellIsFocused = { returns = "number, string", desc = "In range focusing" },
    GetActiveEnemies = { returns = "number", desc = "Active enemies (CLEU)" },
}

return MethodTypes
