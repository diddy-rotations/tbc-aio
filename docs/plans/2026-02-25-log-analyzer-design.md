# WCL Log Analyzer Design

**Date:** 2026-02-25
**Status:** Approved
**Scope:** CLI tool to pull top parser combat logs from Warcraft Logs and produce structured JSON for rotation analysis and comparison

## Overview

A Node.js CLI tool in a new `log-analyzer/` workspace that queries the Warcraft Logs v2 GraphQL API to fetch combat event data from top-ranked players. Produces enriched JSON files containing cast sequences, resource snapshots, buff/debuff states, transition matrices, and uptime analysis. Supports comparison between a user's parse and a top parser to identify concrete rotation improvements.

**Primary consumer:** Claude Code — the structured output is designed to inform rotation code changes (priority ordering, refresh thresholds, pooling logic, burst alignment).

## Package Structure

```
log-analyzer/
├── src/
│   ├── cli.js              # CLI entry point (arg parsing, command dispatch)
│   ├── auth.js             # OAuth client credentials flow, token caching
│   ├── api.js              # GraphQL query builder + paginated fetcher
│   ├── queries.js          # All GraphQL query strings
│   ├── fetch-rankings.js   # Fetch top N parses for an encounter
│   ├── fetch-events.js     # Fetch cast/buff/debuff events for a fight
│   ├── process-fight.js    # Transform raw events → enriched fight JSON
│   ├── compare.js          # Diff two fight JSONs → comparison report
│   └── discover.js         # List zones/encounters for a game version
├── data/                   # Output directory (gitignored)
│   ├── raw/                # Raw API responses
│   ├── fights/             # Processed per-fight JSONs
│   └── comparisons/        # Compare output
├── package.json
└── README.md
```

**Dependencies:** `dotenv` only. Uses native `fetch` (Node 18+). No GraphQL client library — raw POST with query strings.

**Credentials:** Reads `WCL_CLIENT_ID` and `WCL_CLIENT_SECRET` from root `.env` file.

## CLI Interface

```bash
# Discover available zones/encounters
node src/cli.js discover --expansion tbc

# Fetch top N parses for a boss fight
node src/cli.js fetch --boss "Gruul" --class Druid --spec Feral --count 10

# Fetch a specific fight from a report (your own parse)
node src/cli.js fetch --report <code> --fight <fightID> --class Druid --spec Feral

# Fetch trash fights from a report
node src/cli.js fetch --report <code> --trash --class Druid --spec Feral

# Compare two fight JSONs
node src/cli.js compare --baseline data/fights/gruul-top1.json --yours data/fights/gruul-mine.json
```

## Data Pipeline

### Phase 1: Authentication

```
POST https://www.warcraftlogs.com/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=WCL_CLIENT_ID
&client_secret=WCL_CLIENT_SECRET

→ { access_token, token_type, expires_in }
```

Token cached in memory for session. Re-fetched on expiry.

### Phase 2: Fetch Rankings

```graphql
query {
  worldData {
    encounter(id: $encounterID) {
      name
      characterRankings(
        className: "Druid"
        specName: "Feral"
        metric: dps
        page: 1
      )
    }
  }
}
```

Returns array of top performers with: `reportCode`, `fightID`, `characterName`, `server`, `dps`, `duration`, `ilvl`.

For **trash fights**: fetch report by code, filter fights where `encounterID == 0`.

### Phase 3: Fetch Events

Three parallel queries per fight:

```graphql
# Casts
reportData { report(code: $code) {
  events(fightIDs: [$fightID], dataType: Casts, startTime: $start, endTime: $end, limit: 10000) {
    data, nextPageTimestamp
  }
}}

# Buffs
reportData { report(code: $code) {
  events(fightIDs: [$fightID], dataType: Buffs, startTime: $start, endTime: $end, limit: 10000) {
    data, nextPageTimestamp
  }
}}

# Debuffs (on target)
reportData { report(code: $code) {
  events(fightIDs: [$fightID], dataType: Debuffs, startTime: $start, endTime: $end, limit: 10000) {
    data, nextPageTimestamp
  }
}}
```

Paginate via `nextPageTimestamp` until null.

### Rate Limiting

Simple delay between requests (500ms). Free tier should handle 10-25 parses comfortably. If we hit limits, increase delay or batch requests.

## Output Format

### Per-Fight JSON (`data/fights/<boss>-<player>-<spec>.json`)

```json
{
  "meta": {
    "player": "Topcat",
    "server": "Whitemane",
    "class": "Druid",
    "spec": "Feral",
    "boss": "Gruul the Dragonkiller",
    "encounter_id": 649,
    "duration_sec": 142.3,
    "dps": 1847,
    "ilvl": 141,
    "report_code": "abc123",
    "fight_id": 12,
    "fetched_at": "2026-02-25T12:00:00Z"
  },

  "cast_summary": {
    "Mangle (Cat)": { "count": 34, "cpm": 14.3 },
    "Shred": { "count": 42, "cpm": 17.7 },
    "Rip": { "count": 8, "cpm": 3.4 },
    "Ferocious Bite": { "count": 3, "cpm": 1.3 },
    "Tiger's Fury": { "count": 5, "cpm": 2.1 }
  },

  "uptimes": {
    "Rip": 94.2,
    "Mangle (Cat)": 98.1,
    "Tiger's Fury": 22.5,
    "Savage Roar": null
  },

  "cast_sequence": [
    {
      "time": 0.0,
      "spell": "Mangle (Cat)",
      "spell_id": 33876,
      "energy": 100,
      "combo_points": 0,
      "buffs_active": ["Mark of the Wild", "Blessing of Kings"],
      "target_debuffs": [],
      "target_hp_pct": 100
    },
    {
      "time": 1.2,
      "spell": "Shred",
      "spell_id": 27002,
      "energy": 58,
      "combo_points": 1,
      "buffs_active": ["Mark of the Wild", "Blessing of Kings"],
      "target_debuffs": ["Mangle (Cat)"],
      "target_hp_pct": 97
    }
  ],

  "transitions": {
    "Mangle (Cat) -> Shred": 28,
    "Mangle (Cat) -> Rip": 4,
    "Shred -> Shred": 18,
    "Shred -> Rip": 6,
    "Shred -> Ferocious Bite": 2,
    "Rip -> Mangle (Cat)": 7,
    "Tiger's Fury -> Shred": 4
  },

  "refresh_patterns": {
    "Rip": {
      "avg_remaining_on_refresh": 1.2,
      "min_remaining": 0.1,
      "max_remaining": 3.4,
      "clips": 0,
      "drops": 1,
      "drop_durations": [2.3]
    },
    "Mangle (Cat)": {
      "avg_remaining_on_refresh": 0.8,
      "min_remaining": 0.0,
      "max_remaining": 2.1,
      "clips": 2,
      "drops": 0,
      "drop_durations": []
    }
  },

  "idle_analysis": {
    "total_idle_sec": 4.2,
    "idle_pct": 2.9,
    "avg_energy_during_idle": 34,
    "idle_windows": [
      { "start": 22.1, "duration": 1.8, "energy_start": 28, "energy_end": 55 },
      { "start": 88.4, "duration": 2.4, "energy_start": 31, "energy_end": 62 }
    ]
  },

  "cooldown_alignment": {
    "Tiger's Fury": {
      "timestamps": [0.8, 31.2, 61.5, 92.0, 122.3],
      "during_bloodlust": 2,
      "during_execute_phase": 1,
      "on_pull": true,
      "avg_energy_on_use": 28
    }
  },

  "resource_stats": {
    "avg_energy_at_rip": 52,
    "avg_energy_at_ferocious_bite": 71,
    "avg_cp_at_rip": 5.0,
    "avg_cp_at_ferocious_bite": 5.0,
    "avg_energy_at_shred": 48,
    "energy_waste_estimate": 12
  }
}
```

### Comparison JSON (`data/comparisons/<boss>-comparison.json`)

```json
{
  "meta": {
    "boss": "Gruul the Dragonkiller",
    "baseline": { "player": "Topcat", "dps": 1847, "duration": 142.3 },
    "yours": { "player": "Yourchar", "dps": 1203, "duration": 148.7 }
  },

  "dps_gap": {
    "yours": 1203,
    "top": 1847,
    "delta": -644,
    "pct_of_top": 65.1
  },

  "cast_diffs": {
    "Shred": { "yours_cpm": 11.2, "top_cpm": 17.7, "delta": -6.5 },
    "Rip": { "yours_cpm": 3.0, "top_cpm": 3.4, "delta": -0.4 },
    "Ferocious Bite": { "yours_cpm": 4.1, "top_cpm": 1.3, "delta": 2.8 },
    "Mangle (Cat)": { "yours_cpm": 12.0, "top_cpm": 14.3, "delta": -2.3 }
  },

  "uptime_diffs": {
    "Rip": { "yours": 78.3, "top": 94.2, "delta": -15.9 },
    "Mangle (Cat)": { "yours": 91.0, "top": 98.1, "delta": -7.1 }
  },

  "transition_diffs": {
    "notable": [
      "You: Shred -> Ferocious Bite 8x vs Top: 2x — over-prioritizing Bite",
      "Top: Rip -> Mangle 7x vs You: 2x — top player re-applies Mangle immediately after Rip"
    ]
  },

  "refresh_diffs": {
    "Rip": {
      "yours_avg_remaining": 3.8,
      "top_avg_remaining": 1.2,
      "insight": "Refreshing Rip 2.6s too early — wasting energy on overlapping ticks"
    }
  },

  "resource_diffs": {
    "avg_energy_at_rip": { "yours": 68, "top": 52, "insight": "Over-pooling before Rip — 52 energy is sufficient" },
    "avg_energy_at_bite": { "yours": 45, "top": 71, "insight": "Top parser pools to 71 for bigger Bite — energy dump, not filler" }
  },

  "actionable_insights": [
    "Shred CPM 37% lower — likely too many Ferocious Bites consuming combo points that should go to Rip",
    "Rip uptime 16% lower — refreshing too early (clipping) OR letting it fall off. Data shows early refresh (3.8s remaining vs 1.2s)",
    "Ferocious Bite used 3x more often than top parser — Bite should only fire when Rip has 8+ seconds remaining",
    "Mangle re-application after Rip is a pattern top parser follows consistently — ensure Mangle refresh is high priority after applying Rip"
  ]
}
```

### How This Maps to Rotation Code Changes

| Insight | Code Impact |
|---------|------------|
| Rip refresh threshold too high | Adjust `rip_refresh_threshold` constant in `cat.lua` |
| Bite over-prioritized | Lower Bite strategy priority, add Rip-remaining gate |
| Mangle→Shred transition dominant | Validates current strategy ordering |
| Tiger's Fury used at ~28 energy | Validates/adjusts TF energy threshold in matches() |
| Pooling windows at 28-55 energy | Confirms pooling gate values in cat state |
| Top parser always Mangles after Rip | May need explicit "post-Rip Mangle" priority boost |

## Discovery Command

The `discover` command queries `worldData` to list available zones and encounters, so we don't need to hardcode IDs:

```graphql
query {
  worldData {
    expansion(id: $expansionID) {
      zones {
        id
        name
        encounters {
          id
          name
        }
      }
    }
  }
}
```

Output: printed table of zone/encounter names and IDs. Can also be saved as a lookup JSON for other commands.

### Known TBC Classic Zone IDs (from URL patterns)

| Zone | ID |
|------|----|
| Karazhan | 1007 |
| Gruul / Magtheridon | 1008 |
| SSC / TK | 1010 |
| BT / Hyjal | 1011 |
| Sunwell Plateau | 1013 |

Exact encounter IDs per boss discovered via the API at runtime.

## Scope Boundaries

### In Scope (v1)
- OAuth auth with token caching
- Discover zones/encounters
- Fetch top N parses for a boss+class+spec
- Fetch your own parse from a report code
- Fetch trash fights from a report
- Process raw events into enriched fight JSON
- Compare two fight JSONs with actionable insights
- Cat Druid as first supported spec

### Out of Scope (future)
- AI-powered analysis (Claude layer on top of JSON)
- Automated rotation code modification
- Web UI / dashboard
- Multi-spec aggregation in a single run
- Historical tracking (parse over time)

## Technical Notes

- **Node.js 18+** required (native fetch)
- **ESM modules** (consistent with discord-bot)
- **No GraphQL client library** — raw POST with template strings. The queries are simple enough.
- **Pagination**: `nextPageTimestamp` loop with 10k event limit per page
- **Event enrichment**: Cast events don't include resource state directly. We reconstruct energy/CP from `energize` events and cast costs. Buff/debuff state reconstructed from apply/remove events into a timeline, then sampled at each cast timestamp.
- **Spec generalization**: `process-fight.js` will need spec-specific knowledge (which spells are DoTs, which are CDs, which resources matter). Start with cat druid, add others as config objects later.
