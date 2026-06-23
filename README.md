# Wasteland Pawn

**A weird wasteland shopkeeping game for Roblox.**

Run a sketchy pawn shop in a neon cursed flea market: find strange objects, figure out what they might be worth, and sell to the buyers who actually want them. The long-term game is **when** you open, **what** you keep, and **who** you sell to.

The **current prototype** uses a shift/traffic-board stepping stone — start at the Traffic Board, run a shop day (sellers, buyers, Closing Rush), and review results. The **target direction** is open/close shop days with variable traffic, not picking the same mission from a menu over and over.

> *"I bought a cursed traffic cone for 40 scraps and sold it to an alien tourist for ridiculous profit because it was a perfect match."*

**Design voice:** Physical world. Fast decisions. The shop is real. The UI is a tool. Never let immersion create friction.

## Product thesis

Wasteland Pawn is a weird shopkeeping and negotiation game with Roblox retention discipline. The shop is real. The player opens and closes it. Each day should have variables, surprises, and demand conditions. Negotiation resolves deals, but the larger game is deciding what to buy, stash, display, sell, and save for better traffic.

We are **not** trying to build a static shift picker. We are trying to build a weird pawn shop where opening the shop creates a variable day.

More detail: [docs/GDD.md](docs/GDD.md), [docs/ROADMAP.md](docs/ROADMAP.md), [docs/known_issues.md](docs/known_issues.md).

## Product direction (planned — not fully built)

- Prepare the shop (inventory, display, stash) → **open shop** → variable day (traffic, sellers, buyers, rare walk-ins, closing pressure) → **close shop** → receipt and results
- Traffic Board should evolve into a **forecast/prep tool**, not a permanent mission-select menu
- Real-time calendar, full open/close simulation, and broader progression saves are **not built yet**

## Design docs

| Document | Description |
|----------|-------------|
| [docs/GDD.md](docs/GDD.md) | Design source of truth (v0.3) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones, current scope, and priorities |
| [docs/known_issues.md](docs/known_issues.md) | Living bugs, risks, and technical debt |

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
docs/                           GDD, roadmap, known issues
AGENTS.md                       Agent brief for Cursor / Codex
```

## Current prototype features

- **Physical shop hub** — Traffic Board prompt, traffic-window overlay, open/closed sign
- **Traffic Board V1** — session-only forecast/prep prototype; rotating traffic conditions (not a real-time calendar)
- **First Shift Onboarding V1** — session-only guided first buy/sell lesson
- **Shop day loop (internal: shift)** — profit targets, seller visits, buyer visits, Closing Rush, liquidation
- **Seller haggling** — tactic-based negotiation (heat, tells, inspect)
- **Buyer visits and matching** — category/traits → match labels and payout bonuses
- **Rare Buyer Walk-In V1** — session-only extra buyer chance during Buying; capped at one per shop day
- **Public Shelf** — buys land on the Shelf; buyers offer on Shelf items when the shop is open
- **Storage** — server-authoritative hidden stock via StorageBin; V1 saves 2 slots permanently
- **Persistent Shop State V1** — persistent scraps, 2 **Storage** slots, and saved **Shelf** items/positions
- **Legacy working stock** — internal `inventory` location only; compat-only; liquidated at shop close
- **Shelf appeal** — Shelf categories/traits bias buyer traffic roll weights
- **Demand Preview V1** — Traffic Board `?` preview for likely buyers, categories/traits, and shelf match hints (**Prototype**)
- **Physical presentation** — customer rigs at `CustomerSpot`, item props at `CounterItemSpot`, shelf props
- **Deal archetypes** — weighted deal shapes (scam traps, jackpots, buyer setups, etc.)
- **Ctrl+U DevTools** — allowlist-gated live diagnostics; owners get dangerous write actions when enabled in live
- **Hub pickup props** — client-only decorative pick up / place / Storage (session-only; **not** economy or saves)

**Not built yet:** full open/close shop simulation, real-time calendar or daily reset, collection log, relics, shop upgrades, permanent hub pickups, full decoration editor, unified scavenging + haggled item economy.

**Design warning:** scavenging and haggling must eventually feed **one** object economy — not two competing money loops. See [GDD](docs/GDD.md#two-economy-problem).

Haggling is the **resolution layer**. **Object routing** (what to keep, who to sell to, when to open) is the bigger game.

## Contributing / AI agents

Start with **[AGENTS.md](AGENTS.md)** — rules, status labels, and what not to build.

Then read [docs/GDD.md](docs/GDD.md) and [docs/ROADMAP.md](docs/ROADMAP.md).
