# Wasteland Pawn — Roadmap

Living roadmap derived from [GDD.md](GDD.md) v0.3. Update this when milestones ship or priorities change.

## North star

Create stories like:

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for a ridiculous profit."*

**Target retention hook (future direction, not implemented):**

> *"I found an Alien Battery. Normal buyers offer scraps. Alien Caravan starts soon. I stash it, prep the shop, open when the right traffic arrives, and sell for a ridiculous markup."*

Haggling resolves deals. The bigger game is **object routing**: when to sell, who to sell to, what to keep, and how the shop is prepared.

---

## Current Scope Snapshot

The current game is a physical-shop shift prototype.

**Built enough to test:**

- buying from sellers
- buyer visits
- matching items to buyers
- holding working inventory
- displaying haggled items
- session display/stash persistence
- session-only haggled item stash
- display influence on buyer traffic
- session-only Traffic Board V1
- Closing Rush and liquidation

**Next design target:**

- playtest Traffic Board V1 and traffic-window pacing

**Still intentionally out of scope:**

- permanent saves
- permanent stash saves
- relics
- collection log
- real-time calendar
- unified object economy

Planning note: the unification path is drafted in [OBJECT_MODEL_UNIFICATION_PLAN.md](OBJECT_MODEL_UNIFICATION_PLAN.md). Implementation remains out of scope until the shift loop and demand timing feel solid.

---

## Done / mostly working (current repo)

| Area | Status |
|------|--------|
| Seller haggling (tactics, heat, tells, inspect) | **Prototype** |
| Buyer haggling (tactics, heat, tells) | **Prototype** |
| Item traits & categories | **Implemented** (configs) |
| Buyer matching (score, labels, bonuses) | **Prototype** |
| Shift inventory — InventoryShelf working stock | **Prototype** |
| Buyer visits (pick item from inventory) | **Prototype** |
| Payout summaries | **Prototype** |
| Closing Rush + liquidation | **Prototype** |
| Closing Rush / liquidation UI clarity | **Prototype** |
| Deal archetypes (weighted generation) | **Prototype** |
| Archetype legibility (evidence-style clues) | **Prototype** |
| Shift balance pass (`buyerWeights`, tuned shifts) | **Prototype** |
| Physical shop hub — Traffic Board shift start | **Prototype** |
| Traffic-window overlay (from board prompt) | **Prototype** |
| OpenClosedSign (client visual) | **Prototype** |
| Hub pickup props (pick up / place / stash) | **Prototype** — decorative only; see GDD |
| Customer counter presentation (`CustomerPresentationController`, cloned visitor rigs) | **Prototype** |
| Item counter props at `CounterItemSpot` | **Prototype** |
| InventoryShelf presentation | **Prototype** |
| DisplayShelf haggled item routing (Hold Back → display) | **Prototype** |
| Stash V1 for haggled items (session-only) | **Prototype** |
| Session display/stash persistence (same server session) | **Prototype** |
| Display influence on buyer traffic | **Prototype** |
| Demand Preview V1 (Traffic Board `?` panel) | **Prototype** |
| Traffic Board V1 (session-only traffic windows) | **Prototype** |
| Ctrl+U debug overlay + Studio debug actions | **Prototype** |

---

## Now

**Goal:** Playtest the current loop with Traffic Board V1 before building real-time calendar or persistence systems.

- [ ] Playtest shift loop end-to-end through the rotating Traffic Board
- [ ] Confirm Scrap Rush works as the always-available normal-day fallback
- [ ] Check special event rotation pacing after shift end
- [ ] Buyer traffic readability (match labels, influence, pacing)

**Stabilize:**

- [x] InventoryShelf prompt mode: Offer only during BuyerVisit; Hold Back only outside BuyerVisit
- [x] Server rejects display items for buyer offers
- [x] Rapid phase changes do not leave stale shelf prompts

**Avoid:** real-time calendar systems, DataStores, relics, unified object inventory, or scavenging economy until Traffic Board pacing feels solid.

---

## Next

| Milestone | Status | Notes |
|-----------|--------|-------|
| Traffic Board V1 | **Prototype** | Session-only rotating traffic windows; not real-time calendar |
| Normal Day / Scrap Rush polish | **Prototype** | Scrap Rush remains available on every board |
| Stash routing for haggled items | **Prototype** | Server-authoritative, session-only; permanent saves still future |
| Object model unification plan + metadata helpers | **Prototype** | Plan drafted; `ObjectModel` aligns ids; decorative hub props have informational `objectId` mappings |
| Calendar Events V1 | **Planned** | Later real-time/date system after Traffic Board proves useful |
| Rare walk-in buyer/seller prototype | **Planned** | Sellers stay special; buyers remain main money engine |

---

## Later

| Milestone | Status |
|-----------|--------|
| DataStore / persistence | **Future direction** |
| Permanent stash | **Future direction** |
| Collection log | **Future direction** |
| Local calendar events | **Future direction** |
| Global synchronized events (rare) | **Future direction** |
| Relic / display modifiers | **Future direction** |
| Storage and display slot upgrades | **Future direction** |
| Unified object inventory | **Future direction** |
| Reputation / faction demand | **Future direction** |
| Social shop visits | **Future direction** |
| More weird item content | **Future direction** |

---

## Not yet

- Full decoration editor
- Player-to-player trading
- Employees / scheduling
- Rebirth / idle passive income
- Full map expansion
- Final art pass for hub props

---

## Will not build (unless explicitly requested)

- Realistic pawn sim / full tycoon
- Idle passive income generators
- Player-to-player trading economy
- Auctions, rebirth, quests as core loop
- NPC pathfinding as a core system
- Fallout-clone tone (use *Neon Cursed Flea Market*)
- Endless haggling math tuning as substitute for design
- **Two separate economies** (scavenging vs haggling competing for money)

---

## Feature filter (quick check)

Before adding a feature, ask if it improves **at least one** of:

1. Weird item discovery  
2. Acquire / buy / pass decisions  
3. Inventory or storage pressure  
4. Buyer matching or customer demand timing  
5. Big payout moments  
6. Memorable shop stories  
7. Long-term collection (**later**)  
8. Shop identity / social flex (**later**)  

If not → wait.
