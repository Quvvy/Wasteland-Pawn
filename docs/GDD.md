# Wasteland Pawn — Game Design Document

| | |
|---|---|
| **Version** | 0.3 |
| **Status** | Living design document |
| **Purpose** | Vision, prototype reality, future direction, and feature boundaries |

See also: [ROADMAP.md](ROADMAP.md) for milestone tracking.

---

## Table of contents

- [Implementation status legend](#implementation-status-legend)
- [One sentence vision](#one-sentence-vision)
- [High concept](#high-concept)
- [Target core loop](#target-core-loop-future-direction)
- [Prototype loop](#prototype-loop-implemented)
- [Core player fantasy](#core-player-fantasy)
- [Target platform and audience](#target-platform-and-audience)
- [Genre](#genre)
- [Design pillars](#design-pillars)
- [What the game is not](#what-the-game-is-not)
- [Current prototype systems](#current-prototype-systems)
- [Shop hub](#shop-hub)
- [Shifts (prototype implementation)](#shifts-prototype-implementation)
- [Deal archetypes](#deal-archetypes)
- [Items](#items)
- [Object ecosystem](#object-ecosystem-planned)
- [Player decisions](#player-decisions-sell--stash--display--activate-planned)
- [Buyers and customer traffic](#buyers-and-customer-traffic)
- [Sellers](#sellers)
- [Calendar and events](#calendar-and-events-planned)
- [Global events](#global-events-future-direction)
- [Long playtime and CCU](#long-playtime-and-ccu-future-direction)
- [Two economy problem](#two-economy-problem)
- [Haggling philosophy](#haggling-philosophy)
- [Payout screen](#payout-screen)
- [Holy crap moments](#holy-crap-moments)
- [Art direction](#art-direction)
- [UI direction](#ui-direction)
- [Long-term progression](#long-term-progression-planned)
- [Relics](#relics-future-direction)
- [Documentation warnings](#documentation-warnings)
- [Feature filter](#feature-filter)
- [Current development stage](#current-development-stage)
- [Success criteria](#success-criteria)
- [Development principles](#development-principles-codex--cursor)
- [Glossary](#glossary)
- [North star](#north-star)

---

## Implementation status legend

Use these labels in design discussion and implementation plans:

| Label | Meaning |
|-------|---------|
| **Implemented** | In repo and doing real gameplay work (server-authoritative where economy matters) |
| **Prototype** | Works in playtests but incomplete, may be UI-only, client-only, or likely to change |
| **Planned** | Next sensible milestone; not built yet |
| **Future direction** | Intentional design target; do not implement without explicit milestone |
| **Out of scope** | Do not build unless explicitly requested |

---

## One sentence vision

**Wasteland Pawn** is a weird wasteland **shopkeeping** game where players acquire strange objects, learn what they might be worth, decide whether to sell, stash, display, or hold them, then open their shop during the right customer traffic or event to make money.

The prototype still runs on a **shift loop** (sellers, shift inventory, buyers, Closing Rush). That is current repo DNA, not the final structure.

---

## High concept

The player runs a sketchy pawn shop in a wasteland flea market.

- **Outside** and **sellers** are sources of weird objects.
- The **shop**, **stash**, and **display** are where objects live.
- **Calendar / traffic / events** are sources of demand.
- **Opening the shop** during the right window is how serious money gets made.
- **Buyers** are the main money engine; **sellers** stay important as special acquisition moments.

Long-term fantasy: become the most notorious junk dealer in the wasteland — known for what you keep, what you sell, and when you open.

---

## Target core loop (future direction)

```text
Acquire weird object
    ↓
Understand its value (inspect, experience, reputation, events)
    ↓
Decide: sell now · stash for later · display in shop · keep as trophy · activate relic later
    ↓
Watch calendar / customer demand / upcoming events
    ↓
Prepare: scavenge, rearrange display, pull from stash, choose modifiers
    ↓
Open shop at the right time
    ↓
Sell to the right buyer
    ↓
Earn scraps, reputation, collection progress, or shop identity
    ↓
Repeat
```

**Not implemented.** The repo does not yet have calendar events, persistent stash, unified objects, relics, or server-authoritative hub scavenging.

---

## Prototype loop (implemented)

What players can do in the **current repo**:

1. Walk to the **Traffic Board** in the physical shop hub and pick an available traffic window.
2. **Seller visits** bring weird items; player haggles, inspects, buys, or passes.
3. Bought items enter **limited working inventory** on the InventoryShelf (3 slots; resets each shift).
4. Player may **Hold Back** an item to the DisplayShelf or move items through a session-only StashBin.
5. **Buyer visits** occur; player chooses which held item to offer.
6. **Buyer matching** affects interest and bonuses. **Display influence** biases which buyers are more likely to visit based on displayed categories/traits.
7. Player haggles the sale.
8. Sellers run out; remaining inventory enters **Closing Rush** or shift ends.
9. Unsold working-stock items may **liquidate** at a bad rate (~35%). DisplayShelf and stash items are excluded from liquidation.
10. Shift result vs profit quota.

**Session display/stash persistence:** DisplayShelf and stash items survive shift end within the same server session. Rejoin and server reset clear them. This is not permanent save data.

Separately (decorative only): **hub pickup props** can be picked up outside, placed on display slots, or dropped in the stash bin — they do not affect scraps, shift inventory, or saves.

### Prototype loop diagram

```text
Traffic Board → Start Traffic Window
    ↓
Buying Phase: Seller → Haggle/Buy/Pass → InventoryShelf
    ↓
(Optional) Hold Back → DisplayShelf
    ↓
Buyer Visit → Choose Item → Sell / Hold / Skip
    ↓
(repeat until sellers exhausted)
    ↓
Closing Rush → Final buyers / Liquidation
    ↓
Shift Result
```

---

## Core player fantasy

The player is:

- a junk dealer and shopkeeper
- a scam spotter and treasure hunter
- a buyer matcher and demand timer
- a collector of weird garbage
- someone who sees value where others see trash

Core fantasy line:

> *"I know this weird thing is worth something. I just need the right buyer — or the right event."*

---

## Target platform and audience

**Platform:** Roblox

**Audience:** players who like collecting, upgrading, weird items, readable decisions, and showing off a shop.

**Readability:** a spectator should understand within ~10 seconds that this is a weird junk shop where matching buyers and timing matter.

---

## Genre

| Primary (target) | Secondary influences |
|------------------|----------------------|
| Weird shopkeeping | Light negotiation |
| Object routing / timing | Collection |
| | Strategy-lite economy |

**Prototype genre today:** shift-based item flipping with physical hub wrapper.

**Avoid becoming:** pure tycoon, idle simulator, realistic store-management sim.

---

## Design pillars

### Pillar 1: Weird items are the star

Players remember **names and stories**, not `Item #37 (+12% value)`.

### Pillar 2: Smart decisions over realism

Key questions today: buy, pass, inspect, hold for buyer, liquidate?

Key questions tomorrow: sell now, stash for event, display for demand, wait for rare buyer?

### Pillar 3: Haggling is one resolution layer

Haggling answers: *"How well did this deal resolve?"*

The bigger game is **object routing**: what to keep, who to sell to, when to open, how the shop is built.

### Pillar 4: Buyer matching creates aha moments

Rich Collector visits while you hold Cursed Lunchbox → *"That's the play."*

### Pillar 5: Big payouts feel explosive

Receipt-style results must explain **why** money moved.

### Pillar 6: Every run tells a story

Good sessions have tension, holds, and payoff — not disconnected transactions.

---

## What the game is not

| Not this | Why |
|----------|-----|
| Realistic pawn sim | Fun > realism |
| Traditional tycoon | No passive generators |
| Idle income game | Player makes active choices |
| Pure haggling game | Negotiation supports routing, not replaces it |
| Player trading economy | Not core now |
| Fallout clone | *Neon Cursed Flea Market* tone |

---

## Current prototype systems

### Seller haggling — **Prototype**

Buy tactics: Lowball, Split Difference, Point Out Flaw, Pressure, Accept Price, Pass. Heat, tells, inspect, profiles.

### Buyer haggling — **Prototype**

Sell tactics: Small Bump, Pitch Value, Hold Firm, Bluff, Accept Offer, Keep / Skip buyer.

### Shift inventory (InventoryShelf) — **Prototype**

3 working-stock slots per shift; server-authoritative; resets each shift; no DataStore.

### DisplayShelf haggled item display — **Prototype**

Server-authoritative routing from InventoryShelf to DisplayShelf via Hold Back. Displayed items are not offerable to buyers until returned to working stock. Client shelf props mirror server `displayItems`.

### Stash V1 for haggled items — **Prototype**

Server-authoritative, session-only storage for haggled items. Stashed items do not appear in buyer offers, do not influence demand, and are excluded from liquidation. Stash is managed from StashBin and is not permanent save data.

### Session display/stash persistence — **Prototype**

`location == "display"` and `location == "stash"` items persist across shifts within the same server session. Liquidation only touches working inventory. Rejoin and server reset clear display/stash. Not DataStore persistence.

### Display influence — **Prototype**

Displayed categories and traits apply weight bonuses to buyer visit rolls (`DisplayInfluence.lua`). This biases actual buyer traffic during a shift.

### Demand Preview — **Prototype**

Traffic Board shift select shows a `?` demand preview per shift: likely buyers, good categories/traits, current display appeal, and which buyers the display may attract. Informational only — does not change rolls.

### Traffic Board V1 — **Prototype**

Session-only rotating traffic windows wrap the existing shift configs. Scrap Rush is available every board as the normal-day fallback; Collector Convention and Black Market Night rotate as event-like opportunities. The board advances after each completed shift. This is not a real-time calendar, not global, and not persistent.

### Counter and shelf presentation — **Prototype**

- **CounterItemSpot** — item prop during seller haggle and buyer sell phases (`ItemPresentationController`).
- **InventoryShelf** / **DisplayShelf** — client props and prompts for working stock and display routing.
- **CustomerSpot** — cloned visitor rigs during visits (`CustomerPresentationController`).

### Studio debug tools — **Prototype**

Ctrl+U debug overlay (shift, deal, inventory, world, prompts) and Studio-gated debug actions (`DebugService`). Not player-facing.

### Buyer visits + matching — **Prototype**

Player picks inventory item to offer. Match labels: Bad Match → … → Perfect Match. Bonuses are real cash.

### Closing Rush — **Prototype**

No more sellers; limited final buyers; liquidation fallback; quota after phase ends.

### Deal archetypes — **Prototype**

Weighted seller/item/value setup via archetypes (Safe Flip, Scam Trap, Desperate Seller, Bad Deal, Jackpot Junk, Perfect Buyer Setup). Evidence-style clues in UI; archetype names not shown to players.

### Shift balance — **Prototype**

Per-shift `dealArchetypeWeights` and `buyerWeights` in [Shifts.lua](../src/ReplicatedStorage/Shared/Config/Shifts.lua). Scrap Rush / Collector Convention / Black Market Night tuned as traffic-pattern examples.

### Shop hub — **Prototype**

- **Traffic Board** uses the existing `ShiftBoard` part / `ProximityPrompt` to open the traffic-window overlay; starts shifts via existing remotes.
- **OpenClosedSign** updates OPEN/CLOSED from shift state (client visual).
- **CustomerSpot** exists as a future presentation marker (no NPC pathfinding).
- Physical hierarchy expected under `Workspace.World` (Outside, Shop, JunkLot, DisplayShelf, StashBin, etc.).

### Hub pickup props — **Prototype** (decorative only)

**Be honest:** this is **not** final gameplay.

| Property | Hub pickups today |
|----------|-------------------|
| Authority | **Client-only** |
| Persistence | **Session-only**; no save data |
| Economy | **No** scraps, shift inventory, progression |
| Purpose | Flavor + foundation for future object/shop loop |

Player can pick up a prop at outdoor spawns, see `Holding: …` UI, place on `DisplaySlot1–3`, or drop in `StashBin`. Haggled shift items are a **separate** system.

Future convergence is planned in [OBJECT_MODEL_UNIFICATION_PLAN.md](OBJECT_MODEL_UNIFICATION_PLAN.md). That plan does not make decorative hub props part of the economy yet.

---

## Shop hub

### Expected Studio hierarchy

```text
Workspace
└── World
    ├── PlayerSpawn
    ├── Outside
    │   └── JunkLot (PickupSpawn1–3, JunkPile, …)
    └── Shop
        ├── ShiftBoard (+ ProximityPrompt)
        ├── OpenClosedSign
        ├── CustomerSpot
        ├── DisplayShelf (DisplaySlot1–3, ShelfBack or Back)
        ├── StashBin
        ├── Counter, CashRegister, Building, …
```

### Current — **Prototype**

Traffic-window start from physical board, client sign, decorative hub props, deal UI during active shift, InventoryShelf/DisplayShelf/Stash routing, session display/stash persistence, counter and visitor presentation, Studio debug overlay.

### Future — **Planned / future direction**

Open/close shop as core verb; stash/display for **all** objects; calendar board; relic placement; shop upgrades; customer presentation at counter; rare walk-ins.

---

## Shifts (prototype implementation)

**Status:** **Prototype** — code and config still use the word *shift*. Traffic Board V1 now rotates the available shift windows in the current session. Long-term, shifts are an analog of **shop-open / event traffic windows**, not a permanent menu of three static modes.

| Phase | What happens |
|-------|----------------|
| **Buying** | Seller visits; periodic buyer visits; shift inventory; profit target |
| **Closing Rush** | No sellers; final buyers; liquidation; quota after phase |
| **Ended** | Grade, profit vs target, liquidation summary |

### Current shift examples ([Shifts.lua](../src/ReplicatedStorage/Shared/Config/Shifts.lua))

| Shift | Prototype role |
|-------|----------------|
| **Scrap Rush** | Steady, low-risk; practical buyers; forgiving Closing Rush |
| **Collector Convention** | Hold for match; more traps/bad stock; collector-biased buyers |
| **Black Market Night** | Scam/jackpot heavy; volatile buyers; highest target |

### Current traffic-board role — **Prototype**

Scrap Rush ≈ normal day traffic and is available every board. Collector Convention ≈ collectible demand event. Black Market Night ≈ high-volatility event. Traffic Board V1 rotates these windows after shift end; a real-time **calendar** can replace this later.

---

## Deal archetypes

**Status:** **Prototype** (implemented in repo)

| Archetype | Purpose |
|-----------|---------|
| Safe Flip | Teach loop; confidence |
| Scam Trap | Inspect / pass / flaw matter |
| Desperate Seller | Buy low under pressure |
| Bad Deal | Correct play is pass |
| Jackpot Junk | Hidden upside |
| Perfect Buyer Setup | Hold for right buyer |

No cutscenes, quest chains, or director system.

---

## Items

Each haggled item has: name, category, traits, rarity, true value, estimate, flavor, buyer appeal.

Categories and traits live in configs. Item **content** can expand over time.

---

## Object ecosystem (planned)

**Status:** **Planned** — not one unified inventory yet. Haggled-item display and session stash routing exist as early **Prototype** slices; relics, persistence, and hub-prop convergence do not.

`Shared.Util.ObjectModel` exists as a Phase 1 shape-alignment helper for haggled item ids/locations. Decorative hub props may carry informational `objectId` mappings, but they still do not create owned objects or money.

Eventually all sources feed one mental model: *"A weird object I found."*

| Type | Role | Examples |
|------|------|----------|
| **Junk** | Usually sold; common | Rusted Pipe, Broken Radio |
| **Collectible** | Sell, stash, or display | Mutant Plushie, Cursed Doll |
| **Relic** | Sell, display, or **activate** as shop modifier | Alien Battery, Cursed Bell |
| **Trophy** | Prestige / shop identity | Golden Traffic Cone |

Sources (future): scavenging, walk-in sellers, event rewards, rare customers, haggling during open hours.

**Hub pickups today are not this system yet** — they preview placement/stash fantasy only.

---

## Player decisions: sell / stash / display / activate

| Decision | Status | Meaning |
|----------|--------|---------|
| **Sell** | **Prototype** | Immediate scraps via buyer haggle |
| **Display** (haggled items) | **Prototype** | Route to DisplayShelf; session persistence; influences buyer traffic |
| **Stash** (haggled items) | **Prototype** | Session-only storage via StashBin; no demand influence and no permanent save |
| **Activate** | **Future direction** | Relic modifiers |

Future design must use **slot limits** on stash and display so players curate, not hoard infinitely.

**Permanent stash and DataStore saves are not implemented.**

---

## Buyers and customer traffic

**Future direction:** buyers are the **main money engine** during open shop hours.

**Prototype today:** buyer visits, matching labels/bonuses, **display influence** on buyer traffic roll weights, **Demand Preview**, and Traffic Board V1 before starting a shift. Preview is approximate — not a calendar or guarantee.

Buyer types: scavengers, mechanics, collectors, black market dealers, alien tourists, robot appraisers, cultists, military buyers, desperate weirdos.

**Normal days** should feel like Scrap Rush: reliable traffic, many item types, lower ceiling, good for clearing stock.

**Rare buyers** can appear on normal days — *"I've been holding this cursed doll for days; a collector finally walked in."*

### Sellers

**Still matter.** Do not remove sellers.

Future: sellers are **rarer and more exciting** — nervous traveler with suspicious object, classic pawn fantasy. They feed the **same object economy** as scavenging, not a competing money loop.

---

## Calendar and events (planned)

**Status:** **Planned** — not in repo as real-time dates/timers. Traffic Board V1 is a session-only prototype wrapper around existing shifts.

Player should not pick three static shifts forever. Traffic Board V1 is the first prototype step; later, a schedule drives demand:

Normal Day · Scrap Rush · Collector Convention · Black Market Night · Repair Fair · Estate Sale · Alien Caravan · Cult Auction · Vault Opening · …

**Good event design = preparation**, not passive waiting:

```text
Collector Convention in 20 minutes.
→ Find collectibles, pull from stash, arrange display, decide what to hold, open when collectors arrive.
```

**Bad:** *"Event starts in 20 minutes. Wait."*

---

## Global events (future direction)

**Status:** **Future direction** — not implemented.

| Type | Frequency | Examples |
|------|-----------|----------|
| **Local / shop calendar** | Frequent | Normal Day, Scrap Rush, Collector Convention, Repair Fair |
| **Global synchronized** | Rare | Alien Caravan, Military Convoy, Vault Opening, Meteor Junkfall |

Global events can boost CCU. **Warning:** the game must not depend on global timers — normal local play must always be worthwhile.

---

## Long playtime and CCU (future direction)

Target retention loop:

```text
Check upcoming events → Prepare inventory → Acquire / identify objects
→ Arrange shop → Open during useful traffic → Sell to matching buyers
→ Earn scraps / reputation → Upgrade capacity / relics → Check next event
```

**Short-term goals:** sell today, clear space, identify suspicious object, catch rare customer.

**Medium-term:** prepare for Collector Convention, save item for right buyer, unlock slots/tools.

**Long-term:** collection log, shop identity, relics, rarer events, faction reputation.

**Strongest hook:** *"I have something valuable, but I'm waiting for the perfect moment to sell it."*

---

## Two economy problem

**Critical design warning — keep prominent.**

If scavenging pays better than haggling → nobody haggles.

If haggling pays better than scavenging → nobody scavenges.

**Solution:** one object economy, multiple acquisition sources, one decision loop:

```text
Acquire → Learn value → Store / display / sell / wait
→ Use demand windows → Convert to money, reputation, or shop power
```

Scavenging must not be a separate money machine. Haggling must not be the only source of valuable objects.

---

## Haggling philosophy

Readable, tense, short, profile-driven. Supports the object game; does not replace it.

---

## Payout screen

Messy pawn receipt showing bought/sold, bonuses, match label, true value, shift progress.

---

## Holy crap moments

Jackpot reveal · perfect buyer match · scam caught · Closing Rush save · rare discovery · (future) event-timed huge sale · relic combo

---

## Art direction

**Neon Cursed Flea Market** — dusty outside, glowing cluttered shop interior. Not muddy brown apocalypse.

---

## UI direction

Receipt paper, price tags, stamped labels, clarity over decoration. Shift/deal UI is **prototype**; hidden when idle; hub overlays for shift select and holding props.

---

## Long-term progression (planned)

| System | Status |
|--------|--------|
| Collection log | **Future direction** |
| Shop display (haggled items + influence) | **Prototype** |
| Permanent stash / display saves | **Future direction** |
| Shop customization (fixed slots) | **Future direction** |
| DataStore / persistence | **Future direction** |
| Reputation / factions | **Future direction** |

---

## Relics (future direction)

Shop modifiers that change **decisions**, not flat +10%.

Examples (not implemented):

- Collector's Lamp → more collector buyers; fewer scavengers
- Cursed Traffic Cone → more weird items and rare buyers; more scams
- Alien Battery → more alien buyers; humans value alien stock less

---

## Documentation warnings

1. **Do not make scavenging a second economy.**
2. **Do not make events passive waiting** — always create prep goals.
3. **Do not overuse global timers** — local play must stay rewarding.
4. **Do not allow unlimited decoration** without stash/display limits.
5. **Do not remove sellers** — make them special, not constant.
6. **Do not turn this into a tycoon** — no idle generators, employees, rebirth ladders.
7. **Do not document hub pickups as real economy** — they are client-only decorative prototype.
8. **Do not imply calendar, relics, permanent stash, or DataStore saves are built** until milestones ship.
9. **Do not confuse display influence with Demand Preview** — influence changes rolls during a shift; preview only explains likely demand before opening.
10. **Do not claim session display/stash persistence is permanent** — rejoin and server reset clear display/stash.

---

## Feature filter

Does the feature improve at least one of:

1. Weird item discovery  
2. Acquire / buy / pass decisions  
3. Inventory or storage pressure  
4. Buyer matching or demand timing  
5. Big payout moments  
6. Memorable shop stories  
7. Long-term collection (**later**)  
8. Shop identity (**later**)  

If not → wait.

---

## Current development stage

| Layer | Status |
|-------|--------|
| Shift haggle loop | **Prototype** — playable |
| Shop hub + Traffic Board | **Prototype** |
| InventoryShelf + DisplayShelf + Stash routing | **Prototype** |
| Session display/stash persistence | **Prototype** — same server session only |
| Display influence on buyer traffic | **Prototype** |
| Demand Preview V1 (Traffic Board) | **Prototype** |
| Traffic Board V1 | **Prototype** — session-only rotating traffic windows |
| Counter / shelf / customer presentation | **Prototype** |
| Ctrl+U debug overlay + Studio actions | **Prototype** |
| Hub pickup props | **Prototype** — decorative only |
| Real-time calendar / event schedule | **Planned** — not built |
| Permanent stash saves / DataStores / relics | **Not started** |

See [ROADMAP.md](ROADMAP.md) for milestone order and [Current Scope Snapshot](ROADMAP.md#current-scope-snapshot).

---

## Success criteria

**Moving right:**

- "Save this for a collector."
- "This buyer is perfect for my item."
- "I should wait for a better event."
- "I need to make room."
- "I got greedy and had to liquidate."
- "Look at this weird item."

**Failing:**

- "I sell everything immediately."
- "The buyer doesn't matter."
- "Scavenging is the only way to win."
- "I failed because the game didn't let me sell."
- "Weird items are only names."

---

## Development principles (Codex & Cursor)

1. Protect holding + matching in the prototype loop.
2. Small, testable milestones.
3. Don't rewrite haggling without playtest proof.
4. Label implemented vs planned in docs and PRs.
5. Decisions visible in UI.
6. Designer first, coder second.

---

## Glossary

| Term | Definition |
|------|------------|
| **Shift** | Prototype run: sellers, buyers, inventory cap, quota (**Prototype**) |
| **InventoryShelf** | Working stock slots; resets each shift (**Prototype**) |
| **DisplayShelf** | Server-routed display slots for haggled items (**Prototype**) |
| **Stash** | Session-only haggled item storage; not demand influence or permanent save (**Prototype**) |
| **Session display/stash persistence** | Display and stash items survive shift end in same server session; not permanent (**Prototype**) |
| **Display influence** | Displayed categories/traits bias buyer visit roll weights (**Prototype**) |
| **Demand Preview** | Traffic Board `?` panel: likely buyers, good stock, display match hints (**Prototype**) |
| **Traffic Board** | Session-only rotating set of available shift windows; not dates/timers (**Prototype**) |
| **Seller visit** | Buying opportunity during a shift |
| **Buyer visit** | Selling opportunity; pick inventory item |
| **Closing Rush** | Final cashout after sellers exhausted |
| **Liquidation** | Bad fallback for unsold working-stock items (~35%) |
| **Buyer match** | Fit between item and buyer preferences |
| **Deal archetype** | Authored deal shape at generation time |
| **Hub prop** | Client-only decorative pickup (**Prototype**) |
| **Shop open** | Future core verb; Traffic Board is prototype entry (**Planned**) |
| **Calendar event** | Scheduled demand window with dates/timers (**Planned**) |
| **Relic** | Displayable/activatable shop modifier (**Future direction**) |

---

## North star

**Prototype story (implemented today):**

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for ridiculous profit."*

**Target story (future direction, not implemented):**

> *"I found an Alien Battery. Normal buyers offered scraps. I stashed it, prepped the shop, opened during Alien Caravan, and sold to the perfect buyer for a ridiculous markup."*

If a feature helps create stories like these, it probably belongs. If not, it can wait.

---

*This file (`docs/GDD.md`) is the source of truth for design (v0.3). `docs/Wasteland Pawn GDD.docx` is an optional human export — edit the markdown, not the Word file.*
