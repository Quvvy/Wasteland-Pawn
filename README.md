# Wasteland Pawn

**A shift-based weird-item flipping game for Roblox.**

Buy strange junk, spot hidden value, hold items in limited shift inventory, match them to the right buyers, and cash out for absurd profit. Haggling is the *resolution layer* — the real game is routing weird items to the buyers who want them.

> *"I bought a cursed traffic cone for 40 scraps and sold it to an alien tourist for 8,000 because it was a perfect match."*

## Design docs

| Document | Description |
|----------|-------------|
| [docs/GDD.md](docs/GDD.md) | Living game design document (markdown) |
| [docs/Wasteland Pawn GDD.docx](docs/Wasteland%20Pawn%20GDD.docx) | Original GDD source (Word) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones, current focus, and what not to build yet |

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
src/StarterPlayer/.../Client/   Client controllers and placeholder UI
docs/                           GDD, roadmap, design reference
```

## Current prototype (high level)

- Tactic-based seller/buyer haggling (heat, tells, profiles)
- Shift runs with profit targets
- Limited shift inventory (hold items between seller/buyer visits)
- Buyer visits — choose which held item to offer
- Buyer matching (category/traits → match labels and bonuses)
- Closing Rush — final cashout when sellers run out
- Placeholder UI (functional, not polished)

**Not in scope yet:** DataStore saving, shop decoration, employees, auctions, rebirth, player trading.

## Contributing / AI agents

Read [docs/GDD.md](docs/GDD.md) and [docs/ROADMAP.md](docs/ROADMAP.md) before adding features. Use the [feature filter](docs/GDD.md#26-feature-filter): if it does not improve weird items, buy/pass decisions, inventory pressure, buyer matching, big payouts, or shift stories — it probably waits.
