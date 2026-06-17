# Wasteland Pawn

**A weird wasteland shopkeeping game for Roblox.**

Run a sketchy pawn shop in a neon cursed flea market: find strange objects, figure out what they might be worth, and sell to the buyers who actually want them. The long-term game is **when** you open, **what** you keep, and **who** you sell to.

The **current prototype** is a shift loop — start at the ShiftBoard, haggle with sellers, hold items in limited inventory, match buyers, and survive Closing Rush. That is playable today; calendar events, persistent stash, and relics are future direction.

> *"I bought a cursed traffic cone for 40 scraps and sold it to an alien tourist for ridiculous profit because it was a perfect match."*

## Design docs

| Document | Description |
|----------|-------------|
| [docs/GDD.md](docs/GDD.md) | Design source of truth (v0.3) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones and priorities |

Edit **GDD.md** in the repo — not the Word export. `docs/Wasteland Pawn GDD.docx` is an optional human export only.

## Tech stack

- **Roblox** + **Luau**
- **Rojo** for syncing code from this repo into Studio
- Server-authoritative economy (money, items, deals, inventory, shift state)

## Setup

1. Install [Rojo](https://rojo.space/docs/installation/) (or use Aftman: `aftman install` from this folder).
2. Open the Wasteland Pawn place in Roblox Studio.
3. From this folder:

   ```sh
   rojo serve
   ```

4. Connect the Rojo plugin in Studio.
5. Press **Play** to test.

## Workflow

- **Studio** — maps, props, models, lighting, visual layout.
- **This repo** — Luau gameplay code via Rojo.
- **Server owns truth** — clients request actions; never trust client prices or inventory.

## Project layout

```
src/ReplicatedStorage/Shared/   Shared configs, economy math, remotes
src/ServerScriptService/Server/ Server services (Deal, Shift, Inventory, …)
src/StarterPlayer/.../Client/   Client controllers and UI
docs/                           GDD, roadmap
AGENTS.md                       Agent brief for Cursor / Codex
```

## Current prototype features

- **Shift loop** — profit targets, seller visits, buyer visits, Closing Rush, liquidation
- **Haggling** — tactic-based seller/buyer negotiation (heat, tells, inspect)
- **Shift inventory** — limited slots; hold items between visits (server-authoritative, per shift)
- **Buyer matching** — category/traits → match labels and payout bonuses
- **Deal archetypes** — weighted deal shapes (scam traps, jackpots, buyer setups, etc.)
- **Physical shop hub** — ShiftBoard prompt, shift select overlay, open/closed sign
- **Hub pickup props** — client-only decorative pick up / place / stash (session-only; **not** economy or saves)

**Not built yet:** calendar events, persistent stash/display for haggled items, relics, DataStore saves, unified scavenging economy, shop upgrades.

**Design warning:** scavenging and haggling must eventually feed **one** object economy — not two competing money loops. See [GDD](docs/GDD.md#two-economy-problem).

## Contributing / AI agents

Start with **[AGENTS.md](AGENTS.md)** — rules, status labels, and what not to build.

Then read [docs/GDD.md](docs/GDD.md) and [docs/ROADMAP.md](docs/ROADMAP.md).
