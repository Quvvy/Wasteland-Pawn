# Agent Brief

You are working on **Wasteland Pawn**, a Roblox game built with Luau and Rojo.

**Vision:** a weird wasteland **shopkeeping** game — acquire objects, learn value, decide sell / stash / display / hold, open the shop during the right traffic or event, sell to matching buyers.

**Current repo reality:** a **shop-day prototype** (internal: shift — sellers, working inventory, display routing, buyers, Closing Rush) wrapped in a physical **shop hub**. That loop is playable DNA, not the final open/close shop structure.

Haggling is the **resolution layer**. **Object routing** (what to keep, who to sell to, when to open/close) is the bigger game.

**Product direction (not fully built):** open and close the shop for variable shop days. Traffic Board / shift is a prototype stepping stone, not a static mission-select menu.

**Design voice:** Physical world. Fast decisions. The shop is real. The UI is a tool.

---

# Read First

Before making changes, read:

1. `AGENTS.md` (this file)
2. `README.md`
3. `docs/GDD.md` (design source of truth, v0.3)
4. `docs/ROADMAP.md` (milestones and [current scope snapshot](docs/ROADMAP.md#current-scope-snapshot))
5. `docs/known_issues.md` (bugs and risks — when touching fragile systems)

If a request conflicts with GDD or Roadmap, call that out before implementing.

**Inspect code first.** Docs describe direction; code is ground truth for what actually ships.

---

# Implementation Status Labels

Use these when discussing or documenting systems:

| Label | Meaning |
|-------|---------|
| **Implemented** | In repo; real gameplay (server-authoritative where economy matters) |
| **Prototype** | Works but incomplete; may change |
| **Planned** | Next sensible milestone; not built |
| **Future direction** | Intentional target; do not build without explicit milestone |
| **Out of scope** | Do not build unless user explicitly asks |

---

# Current Priority

**Stabilize the shop hub + shop-day prototype** (internal: shift) before calendar, persistence, relics, or unified object inventory.

Do not add major new systems unless explicitly asked.

Near-term focus:

* Traffic Board → prototype shop day start (internal: shift) → deal flow works end-to-end
* Closing Rush and liquidation are clear
* Buyer matching matters across traffic conditions
* Normal-day traffic feels like reliable baseline demand
* Hub pickup props stay **decorative** — not a second economy
* Shop-day results and holding feel understandable
* Traffic Board reads as **forecast/prep**, not static mission select

See `docs/ROADMAP.md` for milestone order.

---

# Core Game Rule

Not a realistic pawn sim or tycoon.

**Prototype loop today:**

```text
Prepare (display/stash/inventory) → Traffic Board forecast/prep
→ start shop day (internal: shift)
Buy weird items from sellers (haggle)
Hold in limited InventoryShelf working stock
(Optional) Hold Back → DisplayShelf / StashBin
Match items to buyers (haggle); display influences buyer traffic
Closing Rush / liquidation → close shop day (internal: shift end)
Hit quota or fail
```

DisplayShelf and StashBin haggled items persist across shop days **within the same server session**. Not permanent saves.

*Product direction:* open/close shop days with variable traffic — not re-selecting the same static shift forever.

**Target loop (future direction — not fully built):**

```text
Prepare shop → open shop → traffic/event variables roll
→ sellers and buyers arrive
→ buy / pass / stash / display / sell
→ rare walk-ins or event visitors may appear
→ closing rush / liquidation pressure
→ close shop → receipt / results / future opportunity preview
```

A good feature should support at least one of:

* weird item discovery
* buy / pass / acquire decisions
* inventory or storage pressure
* buyer matching or demand timing
* big payout moments
* memorable shop stories
* long-term collection (**later**)
* shop identity (**later**)

If it does not → it probably waits.

---

# Critical Design Warnings

## Two economy problem

**Keep this prominent.** Scavenging and haggling must feed **one object / shop economy**, not compete as separate money loops.

If scavenging pays better → nobody haggles. If haggling pays better → nobody scavenges.

## Hub pickup props — be honest

`HubPickupController` + `HubPickups.lua` are **Prototype**, **client-only**, **session-only**, **decorative**:

* no scraps, money, progression, or save data
* not shift inventory
* not server-authoritative scavenging
* do not document or extend them as real economy without explicit milestone

Haggled shift items are a **separate** server system.

## Do not drift into mission-select design

* Favor **open shop / close shop / shop day** language in player-facing docs and UI.
* Traffic Board = prototype **forecast/prep** tool — not a permanent "pick Scrap Rush again" menu.
* Do not design new features as static mission select.
* No tycoon-lite unless explicitly requested.
* Do not claim persistence, real-time calendar, or full open/close sim are built.

## Do not imply these are built

Unless a milestone has actually merged:

* calendar / scheduled events
* global synchronized events
* unified object inventory (hub props + haggled items)
* relics / shop modifiers
* permanent stash or DataStore display saves
* meaningful shop decoration affecting demand beyond current display influence

## Sellers still matter

Future direction makes **buyers / customer traffic** the main money engine. **Sellers stay important** as rarer, exciting acquisition moments — not removed.

---

# What Not To Build Unless Explicitly Asked

* full tycoon / idle passive income / rebirth
* employees, auctions, quests as core loop
* player-to-player trading
* NPC pathfinding as core system
* large map systems, pet systems, monetization
* DataStore progression, collection log, shop customization
* relics, calendar, global events (future — not current focus)
* big UI rewrite, massive haggling rewrite
* scavenging as a competing money loop

Some may ship later per Roadmap. They are not default scope.

---

# Implementation Rules

1. **Inspect existing code first.**
2. Identify the **smallest safe change**.
3. Short plan before coding if larger than a tiny fix.
4. **Keep diffs focused.**
5. Do not rewrite working systems without clear reason.
6. Do not change haggling math unless task asks.
7. No new framework dependencies (no Knit, Roact, Fusion, etc.).
8. **Server logic authoritative** for money, items, deals, inventory, shift state.
9. **Never trust client** prices, money, item values, inventory, or deal outcomes.
10. Update docs if design direction changes.

---

# Code Style

Prefer plain Luau modules, clear services, small config tables, server-authoritative state, readable names.

Avoid overengineering, large abstractions, speculative future-proofing, giant all-in-one systems.

---

# Architecture

```text
src/ReplicatedStorage/Shared/
src/ReplicatedStorage/Shared/Config/
src/ReplicatedStorage/Shared/Economy/
src/ReplicatedStorage/Shared/Net/

src/ServerScriptService/Server/
src/ServerScriptService/Server/Services/

src/StarterPlayer/StarterPlayerScripts/Client/
src/StarterPlayer/StarterPlayerScripts/Client/Controllers/

docs/
```

Server services own gameplay truth. Client controllers request actions and display state.

---

# Important Systems (current repo)

| System | Status |
|--------|--------|
| Seller / buyer haggling | **Prototype** |
| InventoryShelf working stock (shift-scoped) | **Prototype** |
| DisplayShelf haggled item routing | **Prototype** |
| Stash V1 haggled item routing | **Prototype** — session-only |
| Session display/stash persistence | **Prototype** — same server session only |
| Display influence on buyer traffic | **Prototype** |
| Demand Preview V1 (Traffic Board) | **Prototype** |
| Buyer visits + matching | **Prototype** |
| Closing Rush + liquidation | **Prototype** |
| Deal archetypes + shift `buyerWeights` | **Prototype** |
| Shop hub (Traffic Board, overlay, sign; `ShiftBoard` part name in Studio) | **Prototype** |
| Counter / shelf / customer presentation | **Prototype** |
| Ctrl+U debug overlay + Studio actions | **Prototype** |
| Hub pickup props | **Prototype** — client-only decorative |
| Permanent stash saves, calendar, relics, unified objects | **Not started** |

Do not casually replace working prototype systems. Improve only when the task requires it.

Key configs: `Shifts.lua`, `DealArchetypes.lua`, `HubPickups.lua`. Hub binding: `HubWorld.lua`, `ShopHubController.lua`, `HubPickupController.lua`.

---

# Closing Rush Rules

When seller visits run out:

* empty inventory → end shift
* items remain → Closing Rush
* no more sellers; limited final buyers
* unsold items liquidate (~35%)
* quota checked after Closing Rush

Tension: *"Take this buyer now, or risk one more before liquidation?"*

Not: *"Shift ended before I had a fair chance to sell."*

---

# Deal Archetypes

**Prototype** — implemented in repo. Weighted generation shapes seller/item/value setup.

Archetypes: Safe Flip, Scam Trap, Desperate Seller, Bad Deal, Jackpot Junk, Perfect Buyer Setup.

Not cutscenes, quests, or a director system. Archetype names are not shown to players; evidence-style clues only.

---

# Art & UI Direction

**Neon Cursed Flea Market** — dusty outside, warm cluttered glowing shop. Not muddy Fallout clone.

UI: receipt paper, price tags, clarity over decoration. Deal UI hidden when idle; hub overlays for traffic forecast/prep and holding props.

No large UI polish pass unless explicitly requested.

---

# Roadmap Order

Follow `docs/ROADMAP.md`. Summary:

1. Playtest hub + shop-day prototype; Traffic Board forecast/prep polish (now)
2. Open/close shop framing in player-facing UX when implemented (not claiming sim built)
3. Object model unification **plan**
4. Haggled display/stash routing + Demand Preview (**Prototype**); permanent persistence (**Planned**)
5. Shop-day variable readability; rare walk-in hardening
6. Later: real-time calendar events, relics, collection, DataStores, social visits

Do not skip ahead to full calendar sim unless explicitly asked.

---

# Success Criteria

**Moving right:** save for collector · perfect buyer match · need to make room · greedy liquidation · weird item memorable · (future) wait for better event.

**Failing:** sell everything immediately · buyer does not matter · scavenging-only win · failed because game blocked selling · items are just names.

---

# Agent Behavior

1. State files inspected.
2. Brief intended change + design risks.
3. Smallest clean implementation.
4. Summarize changed files.
5. Studio test checklist when gameplay changes.

If unclear, state your assumption. Do not invent large unrequested systems. Designer first, coder second.

---

# North Star

**Prototype story (today):**

```text
I bought a haunted traffic cone for 40 scraps, held it through two bad buyers,
almost ran out of time, then sold it during Closing Rush to an alien tourist for ridiculous profit.
```

**Target story (future — not implemented):**

```text
I found an Alien Battery, stashed it, prepped the shop, opened during Alien Caravan,
and sold to the perfect buyer for a ridiculous markup.
```

If a feature helps create stories like these, it probably belongs. If not, it can wait.
