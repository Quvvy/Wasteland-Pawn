# Wasteland Pawn — Roadmap

Living roadmap derived from [GDD.md](GDD.md) v0.3. Update this when milestones ship or priorities change.

## North star

Create stories like:

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for a ridiculous profit."*

**Target retention hook (future direction, not implemented):**

> *"I found an Alien Battery. Normal buyers offer scraps. Alien Caravan starts soon. I stash it, prep the shop, open when the right traffic arrives, and sell for a ridiculous markup."*

Haggling resolves deals. The bigger game is **object routing**: when to sell, who to sell to, what to keep, and how the shop is prepared.

---

## Done / mostly working (current repo)

| Area | Status |
|------|--------|
| Seller haggling (tactics, heat, tells, inspect) | **Prototype** |
| Buyer haggling (tactics, heat, tells) | **Prototype** |
| Item traits & categories | **Implemented** (configs) |
| Buyer matching (score, labels, bonuses) | **Prototype** |
| Shift inventory (limited slots, shift-scoped) | **Prototype** |
| Buyer visits (pick item from inventory) | **Prototype** |
| Payout summaries | **Prototype** |
| Closing Rush + liquidation | **Prototype** |
| Closing Rush / liquidation UI clarity | **Prototype** |
| Deal archetypes (weighted generation) | **Prototype** |
| Archetype legibility (evidence-style clues) | **Prototype** |
| Shift balance pass (`buyerWeights`, tuned shifts) | **Prototype** |
| Physical shop hub — ShiftBoard shift start | **Prototype** |
| Shift select overlay (from ShiftBoard) | **Prototype** |
| OpenClosedSign (client visual) | **Prototype** |
| Hub pickup props (pick up / place / stash) | **Prototype** — decorative only; see GDD |
| Customer counter presentation (`CustomerPresentationController`, cloned visitor rigs) | **Prototype** |

---

## Now

**Goal:** Stabilize the physical shop + shift prototype and make normal customer traffic feel good before building calendar or persistence systems.

- [ ] Playtest shift start from ShiftBoard end-to-end
- [ ] Playtest Closing Rush pacing and liquidation clarity
- [ ] Verify buyer matching still matters across shift types
- [ ] Playtest customer counter presentation at `CustomerSpot` (visitor rigs + labels)
- [ ] Shop open / close flow polish (beyond client sign text)
- [ ] Make Scrap Rush feel like a reliable “normal day” traffic baseline
- [ ] Keep hub pickup props clearly separate from shift economy in playtests

**Inventory shelf prompt mode (BuyerVisit vs Hold Back):**

- [ ] BuyerVisit starts
- [ ] InventoryShelf item shows exactly one prompt: `Offer <Item Name>`
- [ ] Pressing prompt starts Selling and moves item to CounterItemSpot
- [ ] No Hold Back / Display action fires during BuyerVisit
- [ ] Outside BuyerVisit, same item shows exactly one prompt: `Hold Back`
- [ ] Pressing Hold Back moves item to DisplayShelf
- [ ] No SelectInventoryItemForBuyer call fires when pressing Hold Back
- [ ] Rapid phase changes do not leave stale prompts or stale callbacks
- [ ] Server rejects DisplayInventoryItem during BuyerVisit with clear error
- [ ] Displayed items still cannot be offered to buyers

**Avoid:** Calendar systems, DataStores, relics, unified object inventory, or scavenging economy until hub + shift prototype feels solid.

---

## Next

| Milestone | Status | Notes |
|-----------|--------|-------|
| Item counter props at `CounterItemSpot` | **Planned** | Clone from `ReplicatedStorage.Assets.Items`; client-only presentation |
| Object model unification **plan** | **Planned** | One object ecosystem; hub pickups + haggled items converge later |
| Haggled item → stash/display decision prototype | **Planned** | Server-authoritative; not hub-prop decorative layer |
| Customer-demand-focused shift/calendar prototype | **Planned** | Shifts as prototype of event/traffic windows |
| Rare walk-in buyer/seller prototype | **Planned** | Sellers stay special; buyers remain main money engine |

---

## Later

| Milestone | Status |
|-----------|--------|
| Local calendar events | **Future direction** |
| Global synchronized events (rare) | **Future direction** |
| Relic / display modifiers | **Future direction** |
| Storage and display slot upgrades | **Future direction** |
| Collection log | **Future direction** |
| Reputation / faction demand | **Future direction** |
| DataStore / persistence | **Future direction** |
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
