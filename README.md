# Wasteland Pawn

**A weird wasteland shopkeeping game for Roblox.**

Run a sketchy pawn shop in a neon cursed flea market: find strange objects, figure out what they might be worth, and sell to the buyers who actually want them. The long-term game is **when** you open, **what** you keep, and **who** you sell to.

The **current prototype** is a physical-shop shift loop — start at the Traffic Board, haggle with sellers, hold items in limited working inventory, route haggled items to the display shelf, match buyers, and survive Closing Rush. That is playable today; real-time calendar events, permanent stash, and relics are future direction.

> *"I bought a cursed traffic cone for 40 scraps and sold it to an alien tourist for ridiculous profit because it was a perfect match."*

**Design voice:** Physical world. Fast decisions. The shop is real. The UI is a tool. Never let immersion create friction.

## Product thesis

Wasteland Pawn should stay a weird shopkeeping / negotiation game with Roblox retention discipline. The goal is to make the fantasy easier to understand, easier to return to, and easier to scale -- not to become a generic simulator, idle tycoon, employee manager, or rebirth treadmill.

Strategic risks are tracked in [docs/GDD.md](docs/GDD.md), [docs/ROADMAP.md](docs/ROADMAP.md), and [docs/known_issues.md](docs/known_issues.md): first-shift clarity, weak return loop, mobile/onboarding, session-only stash/display limits, and `DealService` growth.

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
- **Traffic Board V1** — session-only rotating traffic windows; Scrap Rush stays available as the normal-day fallback
- **Shift loop** — profit targets, seller visits, buyer visits, Closing Rush, liquidation
- **Seller haggling** — tactic-based negotiation (heat, tells, inspect)
- **Buyer visits and matching** — category/traits → match labels and payout bonuses
- **Rare Buyer Walk-In V1** — session-only, server-authoritative extra buyer chance during Buying; capped at one per shift
- **Working inventory** — limited InventoryShelf slots per shift (server-authoritative; resets each shift)
- **DisplayShelf haggled item display** — Hold Back routes bought items to display slots
- **Stash V1** — server-authoritative, session-only haggled item storage via StashBin
- **Session display/stash persistence** — DisplayShelf and stash items persist across shifts during the same server session (not permanent saves)
- **Display influence** — displayed categories/traits bias buyer traffic roll weights
- **Demand Preview V1** — Traffic Board `?` preview shows likely buyers, good categories/traits, and display effects per shift (**Prototype**)
- **Physical presentation** — customer rigs at `CustomerSpot`, item props at `CounterItemSpot`, shelf props
- **Deal archetypes** — weighted deal shapes (scam traps, jackpots, buyer setups, etc.)
- **Ctrl+U Studio debug overlay** — shift/deal/inventory diagnostics and Studio debug actions
- **Hub pickup props** — client-only decorative pick up / place / stash (session-only; **not** economy or saves)

**Not built yet:** DataStore saves, permanent stash saves, collection log, relics, real-time calendar/events (dates, timers), unified scavenging + haggled item economy, shop upgrades.

**Design warning:** scavenging and haggling must eventually feed **one** object economy — not two competing money loops. See [GDD](docs/GDD.md#two-economy-problem).

Haggling is the **resolution layer**. **Object routing** (what to keep, who to sell to, when to open) is the bigger game.

## Contributing / AI agents

Start with **[AGENTS.md](AGENTS.md)** — rules, status labels, and what not to build.

Then read [docs/GDD.md](docs/GDD.md) and [docs/ROADMAP.md](docs/ROADMAP.md).
