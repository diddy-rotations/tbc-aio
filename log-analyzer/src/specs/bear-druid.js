/**
 * Bear Druid (Feral Tank) spec configuration for fight processing.
 * Defines which spells to track, resource types, debuff durations, cooldowns.
 *
 * Spell IDs sourced from rotation/source/aio/druid/class.lua
 * WCL uses max-rank spell IDs (abilityGameID).
 */
export const bearDruid = {
  name: 'Bear Druid',
  class: 'Druid',
  spec: 'Feral',
  resource: 'rage',

  // Spells to track in cast_summary and cast_sequence
  trackedSpells: {
    // Core bear abilities (max rank IDs from class.lua useMaxRank)
    33878: { name: 'Mangle (Bear)', category: 'ability', cooldown: 6 },
    6807:  { name: 'Maul', category: 'ability' },  // on-next-attack, off-GCD
    779:   { name: 'Swipe', category: 'ability' },
    33745: { name: 'Lacerate', category: 'dot' },
    99:    { name: 'Demoralizing Roar', category: 'debuff', base_duration: 30 },
    6795:  { name: 'Growl', category: 'taunt', cooldown: 10 },
    5209:  { name: 'Challenging Roar', category: 'taunt', cooldown: 600 },
    22842: { name: 'Frenzied Regeneration', category: 'defensive', cooldown: 180 },
    5229:  { name: 'Enrage', category: 'utility', cooldown: 60 },
    22812: { name: 'Barkskin', category: 'defensive', cooldown: 60 },
    16857: { name: 'Faerie Fire (Feral)', category: 'debuff' },
    // Forms (powershifting detection)
    9634:  { name: 'Dire Bear Form', category: 'form' },
    768:   { name: 'Cat Form', category: 'form' },
    // Feral Charge
    16979: { name: 'Feral Charge', category: 'utility', cooldown: 15 },
    // Bash (interrupt)
    8983:  { name: 'Bash', category: 'interrupt', cooldown: 60 },
  },

  // Debuffs to track for uptime analysis (on target)
  // Multi-rank IDs — WCL reports whichever rank was used
  trackedDebuffs: {
    // Lacerate (single ID, stacking)
    33745: { name: 'Lacerate', duration: 15 },
    // Mangle debuff (all ranks: cat + bear variants)
    33878: { name: 'Mangle (Bear)', duration: 12 },
    33986: { name: 'Mangle (Bear) R2', duration: 12 },
    33987: { name: 'Mangle (Bear) R3', duration: 12 },
    33876: { name: 'Mangle (Cat)', duration: 12 },
    33982: { name: 'Mangle (Cat) R2', duration: 12 },
    33983: { name: 'Mangle (Cat) R3', duration: 12 },
    // Demoralizing Roar (all ranks)
    99:    { name: 'Demoralizing Roar', duration: 30 },
    1735:  { name: 'Demoralizing Roar R2', duration: 30 },
    9490:  { name: 'Demoralizing Roar R3', duration: 30 },
    9747:  { name: 'Demoralizing Roar R4', duration: 30 },
    9898:  { name: 'Demoralizing Roar R5', duration: 30 },
    26998: { name: 'Demoralizing Roar R6', duration: 30 },
    // Faerie Fire (feral + caster, all ranks)
    16857: { name: 'Faerie Fire (Feral)', duration: 40 },
    17390: { name: 'Faerie Fire (Feral) R2', duration: 40 },
    17391: { name: 'Faerie Fire (Feral) R3', duration: 40 },
    17392: { name: 'Faerie Fire (Feral) R4', duration: 40 },
    27011: { name: 'Faerie Fire (Feral) R5', duration: 40 },
  },

  // Buffs to track (on player)
  trackedBuffs: {
    16870: { name: 'Clearcasting', duration: 15 },
    22842: { name: 'Frenzied Regeneration', duration: 10 },
    5229:  { name: 'Enrage', duration: 10 },
    22812: { name: 'Barkskin', duration: 12 },
    // External buffs of interest
    2825:  { name: 'Bloodlust', duration: 40 },
    32182: { name: 'Heroism', duration: 40 },
  },

  // Cooldowns to analyze alignment for
  cooldowns: ['Frenzied Regeneration', 'Barkskin', 'Enrage'],

  // Bloodlust buff IDs (for burst/defensive alignment)
  bloodlustBuffs: [2825, 32182],

  // Execute phase threshold (% HP) — less relevant for tank but useful for threat analysis
  executeThreshold: 25,

  // GCD for this spec (seconds) — bear GCD is 1.5s
  gcd: 1.5,
};
