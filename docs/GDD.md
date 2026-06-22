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
- [Product thesis and retention discipline](#product-thesis-and-retention-discipline)
- [Open Shop / Close Shop direction](#open-shop--close-shop-direction)
- [Desired future loop (planned direction)](#desired-future-loop-planned-direction)
- [Prototype loop](#prototype-loop-implemented)
- [Core player fantasy](#core-player-fantasy)
- [Target platform and audience](#target-platform-and-audience)
- [Genre](#genre)
- [Design pillars](#design-pillars)
- [What the game is not](#what-the-game-is-not)
- [Current prototype systems](#current-prototype-systems)
- [Shop hub](#shop-hub)
- [Shifts (shop day prototype — internal: shift)](#shifts-shop-day-prototype--internal-shift)
- [Deal archetypes](#deal-archetypes)
- [Items](#items)
- [Object ecosystem](#object-ecosystem-planned)
- [Player decisions](#player-decisions-sell--stash--display--activate-planned)
- [Buyers and customer traffic](#buyers-and-customer-traffic)
- [Sellers](#sellers)
- [Calendar and events](#calendar-and-events-planned)
- [Global events](#global-events-future-direction)
- [Long playtime and CCU](#long-playtime-and-ccu-future-direction)
- [Monetization direction](#monetization-direction-future-direction)
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

**Wasteland Pawn** is a weird wasteland **shopkeeping** game where players acquire strange objects, learn what they might be worth, decide whether to sell, stash, display, or hold them, then **open and close their shop** across days with variable traffic and demand.

The prototype still runs on an internal **shift loop** (sellers, working inventory, buyers, Closing Rush). That is current repo DNA and a stepping stone — not the final open/close shop fantasy.

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

## Product thesis and retention discipline

**Design thesis:** Wasteland Pawn is a weird shopkeeping and negotiation game with Roblox retention discipline. The shop is real. The player opens and closes it. Each day should have variables, surprises, and demand conditions. Negotiation resolves deals, but the larger game is deciding what to buy, stash, display, sell, and save for better traffic.

We are **not** trying to build a static shift picker. We are trying to build a weird pawn shop where opening the shop creates a variable day.

The product direction is **weird shopkeeping / negotiation game with Roblox retention discipline** — retention should make the fantasy easier to understand and return to, not turn the game into a generic simulator, idle tycoon, employee manager, passive cash generator, or rebirth-first treadmill.

### Current repo facts

- The playable loop is a shift prototype with sellers, haggling, working inventory, DisplayShelf, StashBin, buyers, Rare Walk-Ins, Traffic Board, Closing Rush, and liquidation.
- Persistent Shop State V1 saves scraps, 2 Stash slots, and DisplayShelf items/positions.
- InventoryShelf working stock remains current-shop-day only. Hub pickups remain decorative and non-persistent.
- There is no collection log, real calendar, relic system, shop upgrade system, full decoration editor, or broader DataStore progression.
- Hub pickup props are decorative, client-only, and separate from the server-owned haggled-item economy.
- `DealService` carries a lot of core loop responsibility and should be watched as features stabilize.

### Strategic assumptions

- The game has its first small return hook: scraps, a tiny permanent stash, and remembered DisplayShelf identity. It still needs stronger long-term goals.
- New players may not understand the first shop day fast enough. Onboarding and first-session clarity are as urgent as persistence.
- Mobile and input readability are retention risks for Roblox.
- Persistence should save a fantasy players already understand. Saving confusion does not fix retention.
- Technical debt matters, but major refactors should happen in slices after the player loop is clearer.

### Future recommendations

- First, make the current Traffic Board, Rare Walk-In, and first shop day readable without long explanations.
- Then add short first-session onboarding that teaches one buy/sell loop through action.
- Then test whether Persistent Shop State V1 actually makes players return with a reason to continue.
- Then add a small collection log that reinforces weird items and memorable sales.
- Refactor `DealService` in slices as responsibilities become stable; do not keep adding unrelated systems into it.

---

## Open Shop / Close Shop direction

**Status:** **Prototype direction slice** — not fully built. The current Traffic Board and internal shift flow are **prototype stepping stones**.

The long-term shop loop should be **Open Shop / Close Shop**, not "select the same shift over and over."

**Player fantasy:**

```text
Prepare the shop → decide to open → see what kind of day happens
→ handle sellers, buyers, rare walk-ins, traffic, surprises, and closing pressure
→ close the shop and review results
```

Opening the shop starts a **shop day**. Open Shop / Shop Day Variables V1 now adds compact server-owned forecasts and light buyer/seller weight nudges to the existing internal shift loop. A shop day can include:

- normal foot traffic
- seller quality variance
- buyer demand variance
- rare walk-ins
- event-flavored traffic
- display-influenced visitors
- stash/display/inventory preparation paying off
- Closing Rush pressure
- liquidation risk
- receipt / result feedback

**Controlled variance:** variables should create readable decisions, not chaos. Player agency comes from prep (what to display, stash, hold, and sell) and forecast hints — not pure RNG punishment.

**Traffic Board evolution:** today it is a session-only traffic-window picker plus compact shop-day forecast (**Prototype**). It should evolve into a stronger **forecast and preparation tool** (what traffic may show up, how display/stash matter, what to expect) — not a permanent static mission-select menu.

**Not built yet:** full open/close shop simulation, real-time calendar, daily reset, collection log, relics, shop upgrades, full decoration editor, global events, broader progression saves.

---

## Desired future loop (planned direction)

```text
Prepare shop
    ↓
Open shop
    ↓
Traffic / event variables roll
    ↓
Sellers and buyers arrive
    ↓
Buy / pass / stash / display / sell
    ↓
Rare walk-ins or event visitors may appear
    ↓
Closing rush / liquidation pressure
    ↓
Close shop
    ↓
Receipt / results / future opportunity preview
```

**Not implemented.** The repo does not yet have full open/close shop verbs, real-time calendar events, unified objects, relics, broader progression saves, or server-authoritative hub scavenging.

The older acquisition-first loop below remains useful context for long-term object routing:

```text
Acquire weird object → understand value → decide sell / stash / display / hold
→ watch demand → prepare shop → open at right time → sell to right buyer
→ earn scraps, reputation, collection progress, or shop identity → repeat
```

---

## Target core loop (future direction — legacy framing)

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

**Not implemented.** See [Desired future loop](#desired-future-loop-planned-direction) for the primary open/close shop framing.

---

## Prototype loop (implemented — stepping stone)

What players can do in the **current repo**. Code still uses the internal term **shift**; player-facing direction is **shop day**.

1. Walk to the **Traffic Board** (physical `ShiftBoard` part) and review session traffic conditions via the forecast/prep overlay.
2. Start a **shop day** (internal: shift) from an available traffic window on the current board.
3. **Seller visits** bring weird items; player haggles, inspects, buys, or passes.
4. Bought items land on the **public Shelf** (3 slots; internal `display`; persists).
5. Player may **Move to Storage** or **Return to Shelf** via Storage overlay / world prompts.
6. **Buyer visits** occur; player chooses a shelf item to offer.
7. **Buyer matching** and **shelf appeal** (display influence) affect interest and traffic.
8. **Rare walk-ins** may add an extra buyer opportunity during Buying (capped per shop day).
9. Sellers run out; remaining legacy inventory (if any) enters **Closing Rush** or the shop day ends.
10. Unsold legacy working-stock items may **liquidate** (~35%). Shelf and Storage items are excluded.
11. Shop-day result vs profit quota; Traffic Board may advance after meaningful progress.

**Persistent Shop State V1:** scraps, 2 Storage slots, and public Shelf items/positions survive rejoin. Legacy working inventory is compat-only.

Separately (decorative only): **hub pickup props** do not affect scraps, working inventory, or saves.

### Prototype loop diagram

```text
Traffic Board (forecast/prep) → Open shop day (internal: shift)
    ↓
Buying Phase: Seller → Haggle/Buy/Pass → InventoryShelf
    ↓
(Optional) Hold Back → DisplayShelf / StashBin
    ↓
Buyer Visit → Choose Item → Sell / Hold / Skip
    ↓
(repeat until sellers exhausted)
    ↓
Closing Rush → Final buyers / Liquidation
    ↓
Close shop day → Result / receipt
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

**Prototype genre today:** physical-shop shop-day prototype (internal: shift) with hub wrapper — not a mission-select menu as the long-term fantasy.

**Avoid becoming:** pure tycoon, idle simulator, realistic store-management sim, static shift picker.

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

Server-authoritative storage for haggled items. Persistent Shop State V1 saves 2 Stash slots permanently. Stashed items do not appear in buyer offers, do not influence demand, and are excluded from liquidation. Stash is managed from StashBin.

### Persistent Shop State V1 — **Prototype**

`location == "display"` and up to 2 `location == "stash"` items persist through DataStore as Persistent Shop State V1. DisplayShelf slot positions are saved. Liquidation only touches temporary working inventory; permanent-origin items return to their saved display/stash home instead of being automatically liquidated.

### Display influence — **Prototype**

Displayed categories and traits apply weight bonuses to buyer visit rolls (`DisplayInfluence.lua`). This biases actual buyer traffic during a shift.

### Demand Preview — **Prototype**

Traffic Board overlay shows a `?` demand preview: likely buyers, good categories/traits, current display appeal, and which buyers the display may attract. Informational only — does not change rolls.

### First Shift Onboarding V1 — **Prototype**

Session-only guidance for a fresh player. Normal-day traffic is recommended, not forced. The first guided lesson uses existing content to show a readable seller item and a clear buyer match, then points toward display/stash as preparation tools. No DataStore onboarding completion exists yet.

### Traffic Board V1 — **Prototype stepping stone**

Session-only rotating traffic conditions wrap internal shift configs. Normal-day traffic is always available as a fallback; collector- and black-market-flavored traffic rotate as event-like opportunities. The board advances after meaningful shop-day progress. This is **not** a real-time calendar, not global, not persistent, and **not** the final open/close shop fantasy — it should evolve into forecast/prep before open shop.

### Counter and shelf presentation — **Prototype**

- **Hybrid Counter Presentation V1** — shopkeeper camera, counter dialogue overlay, simplified actions; legacy deal UI fallback when anchors missing or `ForceLegacyDealUI` (`CounterPresentationController`, `CameraController`).
- **CounterItemSpot** — item prop during seller haggle and buyer sell phases (`ItemPresentationController`).
- **InventoryShelf** / **DisplayShelf** — client props and prompts for working stock and display routing.
- **CustomerSpot** — cloned visitor rigs during visits (`CustomerPresentationController`).

### Debug tools — **Prototype**

Ctrl+U debug overlay (shift, deal, inventory, persistence, world, prompts) is available as a read-only live diagnostic. Debug write actions (`DebugService`) remain Studio-gated and are not player-facing.

### Buyer visits + matching — **Prototype**

Player picks inventory item to offer. Match labels: Bad Match → … → Perfect Match. Bonuses are real cash.

### Rare Buyer Walk-In V1 — **Prototype**

During Buying, a server-authoritative rare buyer check can add one extra buyer visit when the player has working inventory and no scheduled buyer is already waiting. V1 uses existing buyer types, is capped at one rare buyer per shift, and is session-only shift prototype behavior. It is not a real-time calendar event, not global, and not persistent.

### Closing Rush — **Prototype**

No more sellers; limited final buyers; liquidation fallback; quota after phase ends.

### Deal archetypes — **Prototype**

Weighted seller/item/value setup via archetypes (Safe Flip, Scam Trap, Desperate Seller, Bad Deal, Jackpot Junk, Perfect Buyer Setup). Evidence-style clues in UI; archetype names not shown to players.

### Shift balance — **Prototype**

Per-shift `dealArchetypeWeights` and `buyerWeights` in [Shifts.lua](../src/ReplicatedStorage/Shared/Config/Shifts.lua). Internal configs (`scrap_rush`, `collector_convention`, `black_market_night`) tuned as traffic-pattern examples.

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

Current decision: **freeze, do not expand**. Keep hub pickups if they support the physical shop fantasy, but stop expanding them until they have a clear relationship to inventory, display, value, or persistence.

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

Forecast/prep at Traffic Board, then start a shop day (internal: shift). Client sign, decorative hub props, deal UI while open, InventoryShelf/DisplayShelf/Stash routing, persistent scraps/display/stash V1, counter and visitor presentation, read-only live debug overlay with Studio-gated actions.

### Future — **Planned / future direction**

**Open shop / close shop** as core verbs; Traffic Board as forecast/prep (not mission select); stash/display for **all** objects; real-time calendar (**planned**, not built); relic placement; shop upgrades; rare walk-ins.

---

## Shifts (shop day prototype — internal: shift)

**Status:** **Prototype stepping stone** — code and config still use the word *shift*. Player-facing direction is **shop day**. Traffic Board V1 rotates available traffic conditions in the current session. Long-term, a shop day is opened and closed — not a permanent menu of three static modes to pick forever.

| Phase | What happens |
|-------|----------------|
| **Buying** | Seller visits; periodic buyer visits; working inventory; profit target |
| **Closing Rush** | No sellers; final buyers; liquidation; quota after phase |
| **Ended** | Grade, profit vs target, liquidation summary; close shop day |

### Traffic-pattern examples ([Shifts.lua](../src/ReplicatedStorage/Shared/Config/Shifts.lua))

Internal config names — **not** player-facing mission picks. They describe traffic patterns behind the board:

| Config (internal) | Traffic-pattern role |
|-------------------|----------------------|
| **scrap_rush** | Normal-day baseline; steady, practical traffic |
| **collector_convention** | Collector-flavored demand; hold-for-match pressure |
| **black_market_night** | High-volatility, riskier buyers and deals |

### Current traffic-board role — **Prototype**

Normal-day traffic is available every board. Collector- and black-market-flavored windows rotate as event-like opportunities. The board advances after meaningful shop-day progress. A real-time **calendar** (**planned**, not built) can deepen this later — it is not the same as Traffic Board V1 today.

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
| **Sell** | **Prototype** | Immediate scraps via buyer haggle during an open shop day |
| **Display** (haggled items) | **Prototype** | Route to DisplayShelf; session persistence; influences buyer traffic / shop identity |
| **Stash** (haggled items) | **Prototype** | 2 permanent slots; save for a better future shop day; no demand influence |
| **Activate** | **Future direction** | Relic modifiers |

Future design must use **slot limits** on stash and display so players curate, not hoard infinitely.

**Persistent Shop State V1 is implemented.** Broader permanent inventory, collection, relic, upgrade, and decoration saves are not implemented.

---

## Buyers and customer traffic

**Future direction:** buyers are the **main money engine** during open shop hours.

**Prototype today:** buyer visits, rare walk-ins, matching labels/bonuses, **display influence**, **Demand Preview**, and Traffic Board V1 before opening a shop day (internal: shift). Preview is approximate — not a real-time calendar or guarantee.

Buyer types: scavengers, mechanics, collectors, black market dealers, alien tourists, robot appraisers, cultists, military buyers, desperate weirdos.

**Normal days** should feel like reliable baseline traffic: many item types, lower ceiling, good for clearing stock.

**Rare buyers** can appear on normal days — *"I've been holding this cursed doll for days; a collector finally walked in."*

### Sellers

**Still matter.** Do not remove sellers.

Future: sellers are **rarer and more exciting** — nervous traveler with suspicious object, classic pawn fantasy. They feed the **same object economy** as scavenging, not a competing money loop.

---

## Calendar and events (planned)

**Status:** **Planned** — not in repo as real-time dates/timers. Traffic Board V1 is a session-only **prototype stepping stone**, not a real calendar.

The product should not stay "pick three static modes forever." Traffic Board V1 is the first forecast/prep step; later, a **real-time calendar** (**planned**, not built) can drive demand:

Normal Day · collector-flavored traffic · black-market-flavored traffic · Repair Fair · Estate Sale · Alien Caravan · Cult Auction · Vault Opening · …

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
| **Local / shop calendar** (**planned**, not built) | Frequent | Normal Day, collector-flavored traffic, black-market-flavored traffic, Repair Fair |
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

## Monetization direction (future direction)

Monetization should support the shop fantasy instead of replacing the game with a paid shortcut.

Good directions:

- shop expansions
- cosmetic displays
- premium decoration themes
- event tickets
- extra display/stash convenience
- non-pay-to-win boosts that reduce friction but do not replace skill

Avoid:

- arbitrary cash multipliers
- paid rebirth advantages
- paid auto-profit systems
- skipping the negotiation loop entirely
- paid systems that make item judgment irrelevant

If monetization makes the best strategy "pay to ignore buyers, timing, and weird item judgment," it is working against the game.

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

Receipt paper, price tags, stamped labels, clarity over decoration. Shift/deal UI is **prototype**; hidden when idle; hub overlays for traffic forecast/prep and holding props.

---

## Long-term progression (planned)

| System | Status |
|--------|--------|
| Persistent scraps + 2-slot Stash + saved DisplayShelf | **Prototype** |
| Collection log | **Planned** |
| Shop display (haggled items + influence) | **Prototype** |
| Broader permanent inventory / decoration saves | **Future direction** |
| Shop customization (fixed slots) | **Future direction** |
| Broader DataStore / persistence | **Future direction** |
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
8. **Do not imply calendar, relics, collection, broader inventory saves, or shop upgrades are built** until milestones ship.
9. **Do not confuse display influence with Demand Preview** — influence changes rolls during a shift; preview only explains likely demand before opening.
10. **Do not claim all shop objects are permanent** — Persistent Shop State V1 saves scraps, 2 Stash slots, and DisplayShelf items/positions only.
11. **Do not describe the long-term game as a static shift picker** — open/close shop days with variable traffic is the direction.
12. **Do not imply full open/close shop simulation, real-time calendar, or daily reset are built** — Traffic Board V1 is a prototype forecast/prep tool.
13. **Do not solve retention by becoming a tycoon-lite game** — no idle cash, employees, rebirth-first ladders, or paid auto-profit.
14. **Do not expand decorative hub pickups yet** — freeze them until they have a clear relationship to inventory, display, value, or persistence.
15. **Do not let `DealService` absorb every new system** — slice responsibilities out when a feature boundary stabilizes.

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
| Shop day haggle loop (internal: shift) | **Prototype** — playable |
| Open / close shop day framing | **Planned direction** — not fully built |
| Shop hub + Traffic Board forecast/prep | **Prototype stepping stone** |
| InventoryShelf + DisplayShelf + Stash routing | **Prototype** |
| Persistent Shop State V1 | **Prototype** — scraps, 2 Stash slots, DisplayShelf items/positions |
| Display influence on buyer traffic | **Prototype** |
| Demand Preview V1 (Traffic Board) | **Prototype** |
| First Shift Onboarding V1 | **Prototype** — session-only |
| Traffic Board V1 | **Prototype** — session-only rotating traffic conditions |
| Rare Buyer Walk-In V1 | **Prototype** — one extra buyer max per shop day |
| Counter / shelf / customer presentation | **Prototype** |
| Ctrl+U debug overlay + Studio actions | **Prototype** |
| Hub pickup props | **Prototype** — decorative only |
| Permanent scraps + tiny permanent stash + DisplayShelf saves | **Prototype** |
| Real-time calendar / event schedule | **Planned** — not built |
| Broader permanent saves / relics | **Not started** |

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
| **Shop day** | One open-shop session: sellers, buyers, inventory cap, quota (**Planned** player framing; **Prototype** as internal shift) |
| **Open shop** | Future core verb: start the shop day and let traffic/deals run (**Planned**) |
| **Close shop** | Future core verb: end the shop day, review receipt/results (**Planned**) |
| **Shift** | Internal/code term for prototype shop day (**Prototype**) — sellers, buyers, inventory cap, quota |
| **InventoryShelf** | Legacy working stock (compat); Public Shelves V1 uses unified **Shelf** instead (**Prototype**) |
| **Shelf** (internal `display`) | Public sellable stock on `Shop.Shelf`; traffic influence; persists (**Prototype**) |
| **Storage** (internal `stash`) | 2 permanent hidden slots; save for a better future shop day (**Prototype**) |
| **Persistent Shop State** | Scraps, Stash, and DisplayShelf items/positions survive rejoin; InventoryShelf and hub pickups do not (**Prototype**) |
| **Display influence** | Displayed categories/traits bias buyer visit roll weights (**Prototype**) |
| **Demand Preview** | Traffic Board `?` panel: likely buyers, good stock, display match hints (**Prototype**) |
| **Traffic Board** | Prototype forecast/prep overlay; session-only traffic conditions; evolves toward pre-open forecast (**Prototype stepping stone**) |
| **Seller visit** | Buying opportunity during an open shop day |
| **Buyer visit** | Selling opportunity; pick inventory item |
| **Closing Rush** | Final cashout after sellers exhausted |
| **Liquidation** | Bad fallback for unsold working-stock items (~35%) |
| **Buyer match** | Fit between item and buyer preferences |
| **Deal archetype** | Authored deal shape at generation time |
| **Hub prop** | Client-only decorative pickup (**Prototype**) |
| **Real-time calendar** | Scheduled demand with dates/timers (**Planned** — not built) |
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
