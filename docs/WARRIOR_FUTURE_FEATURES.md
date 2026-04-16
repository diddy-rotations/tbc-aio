# Warrior Future Features

Ideas from reference profile analysis. Sorted roughly by impact.

## PvE Features

### Sunder Armor Priority/Filler Split
Split Sunder into two modes: "priority" (first 5 stacks as fast as possible, skip fillers) and "filler" (use Sunder as rage dump between Shield Slam/Revenge CDs). Current implementation has help-stack and maintain modes but doesn't prioritize initial 5-stack rush.

### Automated Burst Sequencer
Chain Death Wish → Recklessness → trinkets in a timed sequence with GCD awareness. Current implementation fires them independently via burst context. A sequencer would coordinate them for maximum overlap window.

### Pandemonius Safety (Shadow Damage Boss)
Auto Shield Block before engaging Pandemonius-style bosses that reflect physical attacks. Detects via boss unit ID or aura. Very niche but prevents deaths on specific TBC encounters.

## PvP Features

### Spell Reflect Timing
Smart Spell Reflect that watches enemy cast bars and queues reflect just before cast completes. Would need cast tracking and stance dance to Defensive for the reflect window.

### Anti-Fakecast Interrupt Logic
Track enemy interrupt patterns — if target frequently fakecasts, hold Pummel longer or wait for a confirmed cast before committing. Would need a per-target cast history tracker.

### Disarm on Offensive Buffs
Auto-Disarm targets when they pop offensive cooldowns (Adrenaline Rush, Bestial Wrath, Recklessness, etc.). Uses buff detection to time the disarm for maximum value.

### Anti-Vanish Detection
Detect rogue Vanish with Thunder Clap or Demo Shout to break stealth. Fire a PBAoE immediately when rogue vanishes (combat drop detection + immediate AoE).

### Slow Hierarchy
Intelligent slow management: Hamstring → Piercing Howl based on situation. Use Piercing Howl for multi-target kiting, Hamstring for single-target sticking. Would need a slow-tracking system.

### Charge/Intercept Stance Dance
Smart gap closer that picks Charge (Battle Stance) vs Intercept (Berserker Stance) based on current stance, rage, and distance. Auto stance-dance to the cheapest option.
