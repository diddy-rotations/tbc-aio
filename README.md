# Flux AIO

A multi-class WoW TBC rotation addon built on the GGL Action/Textfiles framework. Currently supports **Druid** (all forms) and **Hunter**.

**Website & Docs** — [flux-aio.github.io/tbc-aio](https://flux-aio.github.io/tbc-aio)

## Project Structure

This is a monorepo with three packages:

| Package | Description |
|---------|-------------|
| `rotation/` | Core WoW rotation addon (Lua source + Node.js build system) |
| `website/` | Static site for script distribution and documentation (Astro) |
| `discord-bot/` | Discord bot for personalized rotation tweaks via Claude AI |

## Getting Started

```bash
npm install
```

### Building the Rotation

```bash
npm run build -w rotation          # Compile to rotation/output/TellMeWhen.lua
npm run build:sync -w rotation     # Build + sync to SavedVariables (requires dev.ini)
npm run build:all -w rotation      # Build + sync
npm run watch -w rotation          # Watch mode: auto-rebuild + sync on save
```

### Running the Website

```bash
npm run dev -w website
npm run build -w website
```

### Running the Discord Bot

```bash
npm run register -w discord-bot    # Register slash commands
npm run start -w discord-bot       # Start the bot
```

## Architecture

The rotation uses a **Strategy Registry** pattern:

1. **Middleware** — shared logic (recovery, cooldowns, buffs, dispels) that runs first, priority-ordered
2. **Strategies** — playstyle-specific rotations registered per form/spec

Each class registers itself via `rotation_registry:register_class()` and gates its modules on `A.PlayerClass`. The build system (`rotation/build.js`) auto-discovers class modules and compiles them into a single TMW profile.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Supported Classes

- **Druid** — Caster, Cat, Bear, Balance (Moonkin), Resto (Tree of Life)
- **Hunter** — Ranged DPS with auto-shot clip tracking
