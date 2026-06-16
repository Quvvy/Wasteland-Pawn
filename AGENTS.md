# Agent Brief

You are working on **Wasteland Pawn**, a Roblox game built with Luau and Rojo.

Wasteland Pawn is a **shift-based weird-item flipping game**.

The player buys strange junk, spots hidden value, holds items in limited shift inventory, matches those items to the right buyers, and cashes out for absurd profit.

Haggling is the resolution layer.

**Item routing is the game.**

---

# Read First

Before making changes, read these files:

1. `AGENTS.md` (this file — quick rules and boundaries)
2. `README.md`
3. `docs/GDD.md` (source of truth)
4. `docs/ROADMAP.md`

Use those documents as the project source of truth.

If a requested change conflicts with the GDD or Roadmap, call that out before implementing.

---

# Current Priority

The current focus is:

**Playtest and polish Closing Rush.**

Do not add major new systems unless explicitly asked.

Current priorities:

* make Closing Rush clear
* make liquidation clear
* make item holding feel viable
* make buyer matching matter
* make shift results understandable
* keep the loop small and testable

---

# Core Game Rule

The game is not about realistic pawn shop management.

The game is about this loop:

```text
Buy weird item
Hold it
Match it to the right buyer
Haggle the sale
Cash out
Tell a funny story afterward
```

A good feature should support at least one of these:

* weird item discovery
* buy/pass decisions
* inventory pressure
* buyer matching
* big payout moments
* memorable shift stories
* long-term collection
* shop identity or social flex

If a feature does not support one of those, it probably should wait.

---

# Design Pillars

## Weird Items Are The Star

Players should remember items by name.

Good:

```text
Possessed Traffic Cone
Cursed Lunchbox
Alien Soda Tab
Crying Toaster
```

Bad:

```text
Item #37 with +12% value
```

## Smart Decisions Over Realism

The game should reward judgment.

Important questions:

* Should I buy this?
* Should I pass?
* Should I inspect?
* Is this seller lying?
* Is this item worth a slot?
* Should I sell now?
* Should I wait for a better buyer?
* Should I risk one more buyer?
* Should I liquidate and close?

## Haggling Is A Resolution Layer

Do not treat haggling as the entire game.

The main game is item routing.

Haggling decides how well a buy or sell resolves.

## Buyer Matching Creates Aha Moments

The player should feel smart when they match the right item to the right buyer.

Example:

```text
Rich Collector visits.
Player has Cursed Lunchbox, Broken Toaster, and Alien Soda Tab.
Player should immediately think: "Cursed Lunchbox is the play."
```

## Every Shift Should Tell A Story

A good shift should create moments like:

```text
I bought a cursed item, held it through two bad buyers, then barely hit quota during Closing Rush.
```

---

# What Not To Build Unless Explicitly Asked

Do not add these systems unless the user specifically requests them:

* full tycoon systems
* employees
* idle passive income
* rebirth
* player-to-player trading
* auctions
* quests as the core loop
* full building system
* NPC pathfinding
* large map systems
* pet systems
* monetization
* DataStore progression
* collection log
* shop customization
* relics
* big UI rewrite
* massive haggling rewrite

Some of these may happen later.

They are not the current focus.

---

# Implementation Rules

When asked to implement something:

1. Inspect the existing code first.
2. Identify the smallest safe change.
3. Make a short plan before coding if the task is larger than a tiny fix.
4. Keep the diff focused.
5. Do not rewrite working systems without a clear reason.
6. Do not change haggling math unless the task specifically asks for it.
7. Do not add new framework dependencies.
8. Keep server logic authoritative.
9. Never trust client-provided money, prices, item values, inventory state, or deal results.
10. Update docs if the design direction changes.

---

# Code Style Direction

Keep code simple.

Prefer:

* plain Luau modules
* clear service boundaries
* small config tables
* server-authoritative state
* readable names
* simple UI hooks

Avoid:

* overengineering
* large abstractions too early
* framework rewrites
* hidden magic
* giant all-in-one systems
* speculative future-proofing

---

# Current Architecture

Expected project structure:

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

Server services should own gameplay truth.

Client controllers should request actions and display state.

---

# Current Important Systems

The project currently has or is moving toward:

* seller haggling
* buyer haggling
* item traits
* item categories
* limited shift inventory
* buyer visits
* buyer matching
* payout bonuses
* shift targets
* Closing Rush
* shift result summaries

Do not casually replace these systems.

Improve them only when the requested task requires it.

---

# Closing Rush Rules

Closing Rush is a final cashout phase.

It exists because holding items should feel viable.

When seller visits run out:

* if inventory is empty, end the shift
* if inventory has items, enter Closing Rush
* no more sellers appear
* final buyers appear
* buyers are limited
* unsold items liquidate at a bad rate
* quota is checked after Closing Rush ends

The intended tension is:

```text
Do I take this okay buyer now, or risk one more buyer before liquidation?
```

Not:

```text
The shift ended before I had a fair chance to sell.
```

---

# Deal Archetype Direction

Deal Archetypes are the next major gameplay milestone after Closing Rush playtesting.

Keep the first version small.

Do not build a huge director system yet.

MVP goal:

```text
Make seller deals feel authored instead of random soup.
```

Initial archetypes:

* Safe Flip
* Scam Trap
* Desperate Seller
* Bad Deal
* Jackpot Junk
* Perfect Buyer Setup

Deal Archetypes should influence seller/item/value setup and shift rhythm.

They should not become cutscenes, quests, or a giant narrative system.

---

# Art Direction

Style name:

```text
Neon Cursed Flea Market
```

The outside world should feel:

* dusty
* rusty
* roadside
* wasteland
* worn down

The pawn shop interior should feel:

* warm
* dense
* cluttered
* glowing
* weird
* half scam, half museum

Avoid muddy realism.

Avoid Fallout clone visuals.

The goal is:

```text
A stylized roadside pawn shop full of neon signs, cursed junk, alien trash, scammy sellers, and buyers who look like walking red flags.
```

---

# UI Direction

The UI should prioritize clarity.

Useful motifs:

* receipt paper
* price tags
* stamped labels
* sticky notes
* red marker circles
* scrap metal frames

Important information must be obvious:

* current phase
* current seller or buyer
* item traits
* estimated value
* current offer
* heat
* inventory slots
* buyer match
* buyers left in Closing Rush
* liquidation penalty
* profit result

Do not do a large UI polish pass unless explicitly requested.

---

# Roadmap Order

Current order:

1. Playtest and polish Closing Rush
2. Deal Archetypes v1
3. Shift Identity v1
4. Relics v1
5. More weird item content
6. Collection log
7. Shop display
8. Shop customization
9. DataStore progression
10. Social visits

Do not skip ahead unless explicitly asked.

---

# Success Criteria

The game is moving in the right direction if players say:

```text
I should save this for a collector.
This buyer is perfect for my item.
I need to make room.
I should pass this seller.
I got greedy and had to liquidate.
I barely hit quota in Closing Rush.
I want one more shift.
Look at this weird item I found.
```

The game is failing if players say:

```text
I just sell everything immediately.
The buyer does not matter.
The item traits do not matter.
Every deal feels the same.
I failed because the game did not let me sell.
I am just tuning haggling numbers forever.
The weird items are just names, not gameplay.
```

---

# Agent Behavior

When responding to a task:

1. State what files you inspected.
2. Explain the intended change briefly.
3. Mention any design risk.
4. Implement the smallest clean version.
5. Summarize changed files.
6. Provide a Studio test checklist.

If the task is unclear, make a reasonable assumption and state it.

Do not invent large systems that were not requested.

Do not chase Roblox trends unless they support the GDD.

Think like a game designer first and a coder second.

---

# North Star

The game should create stories like:

```text
I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for ridiculous profit.
```

If a feature helps create stories like that, it probably belongs.

If it does not, it can wait.
