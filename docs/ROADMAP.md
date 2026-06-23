# Wasteland Pawn — Roadmap

Living roadmap derived from [GDD.md](GDD.md) v0.3. Update this when milestones ship or priorities change.

## North star

Create stories like:

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for a ridiculous profit."*

**Target retention hook (future direction, not implemented):**

> *"I found an Alien Battery. Normal buyers offer scraps. Alien Caravan starts soon. I stash it, prep the shop, open when the right traffic arrives, and sell for a ridiculous markup."*

Haggling resolves deals. The bigger game is **running the shop** — object routing (when to sell, who to sell to, what to keep, how to prepare display/stash) — not re-selecting the same static shift forever.

**Target product:** open and close the shop for variable shop days. Traffic Board is a prototype stepping stone toward forecast/prep, not the final fantasy.

---

## Current Scope Snapshot

The current game is a physical-shop **shop-day prototype** (internal: shift). Target direction is **open/close shop days** with variable traffic — not a permanent mission-select menu.

**Built enough to test:**

- buying from sellers
- buyer visits
- matching items to buyers
- holding items on the public Shelf
- moving items to Storage
- Persistent Shop State V1 (scraps, 2 Storage slots, Shelf items/positions)
- Shelf ↔ Storage routing
- shelf appeal on buyer traffic
- session-only Traffic Board V1 (forecast/prep prototype)
- Rare Buyer Walk-In V1
- Closing Rush and liquidation

**Next design target (in order):**

1. First Shift Onboarding V1 readability (session guidance)
2. Open/close shop **framing** in player-facing UX when implemented — docs/UI direction only; sim not built
3. Traffic Board as **forecast/prep** tool, not mission select
4. Shop-day variable readability (rare walk-ins, traffic conditions)
5. Playtest Persistent Shop State V1 for return motivation and trust

**Still intentionally out of current phase scope:**

- full open/close shop simulation
- broader permanent progression saves
- full decoration editor / shop upgrades
- relics
- collection log
- real-time calendar
- unified object economy

Planning note: the unification path is drafted in [OBJECT_MODEL_UNIFICATION_PLAN.md](OBJECT_MODEL_UNIFICATION_PLAN.md). Implementation remains out of scope until the shop-day loop and demand timing feel solid.

---

## Done / mostly working (current repo)

| Area | Status |
|------|--------|
| Seller haggling (tactics, heat, tells, inspect) | **Prototype** |
| Buyer haggling (tactics, heat, tells) | **Prototype** |
| Item traits & categories | **Implemented** (configs) |
| Buyer matching (score, labels, bonuses) | **Prototype** |
| Shift inventory — public Shelf (internal `display`) | **Prototype** |
| Buyer visits (pick item from Shelf) | **Prototype** |
| Payout summaries | **Prototype** |
| Closing Rush + liquidation | **Prototype** |
| Closing Rush / liquidation UI clarity | **Prototype** |
| Deal archetypes (weighted generation) | **Prototype** |
| Archetype legibility (evidence-style clues) | **Prototype** |
| Shift balance pass (`buyerWeights`, tuned shifts) | **Prototype** |
| Physical shop hub — Traffic Board opens prototype shop day (internal: shift) | **Prototype** |
| Traffic-window overlay (from board prompt) | **Prototype** |
| OpenClosedSign (client visual) | **Prototype** |
| Hub pickup props (pick up / place / stash) | **Prototype** — decorative only; see GDD |
| Customer counter presentation (`CustomerPresentationController`, cloned visitor rigs) | **Prototype** |
| Item counter props at `CounterItemSpot` | **Prototype** |
| Hybrid Counter Presentation V1 (shopkeeper camera, counter dialogue overlay, legacy UI fallback) | **Prototype** |
| Public Shelf presentation (`Shop.Shelves.BasicShelf`) | **Prototype** |
| Shelf Focus V0 (Inspect Shelf station + click/tap management; always-on prompt when shelf exists) | **Prototype** |
| WorldMarkers helper (tags + hierarchy + legacy fallback) | **Prototype** |
| Shelf ↔ Storage routing (Move to Storage / Return to Shelf) | **Prototype** |
| Storage for haggled items (2 saved slots; internal `stash`) | **Prototype** |
| Persistent Shop State V1 (scraps, 2 Storage slots, Shelf positions) | **Prototype** |
| Shelf appeal on buyer traffic | **Prototype** |
| Demand Preview V1 (Traffic Board `?` panel) | **Prototype** |
| First Shift Onboarding V1 | **Prototype** |
| Traffic Board V1 (session-only traffic windows) | **Prototype** |
| Rare Buyer Walk-In V1 | **Prototype** |
| Ctrl+U DevTools overlay (allowlist + role gates) | **Prototype** |

---

## Now

**Current phase:** Phase 1 - Readability and first-session clarity.

- [x] Add Open Shop / Shop Day Variables V1 as a compact forecast/prep slice
- [ ] Finish Traffic Board readability and hardening (forecast/prep, not mission select)
- [x] Add First Shift Onboarding V1 as a session-only guided first lesson
- [ ] Make Rare Walk-Ins understandable as extra buyer opportunities
- [ ] Reduce first-shop-day confusion before adding more feature layers
- [ ] Make mobile input and UI viable enough for the first shop day

**Stabilize:**

- [x] Public Shelves V1 — unified public Shelf (`Shop.Shelf` / `ShelfSlot1-3`), buys land on Shelf, buyers offer from Shelf, Storage for hidden stock
- [x] InventoryShelf prompt mode: Offer only during BuyerVisit; Hold Back only outside BuyerVisit (superseded by Shelf Offer / Move to Storage on public Shelf)
- [x] Server rejects storage items for buyer offers; accepts shelf (`display`) items
- [x] Rapid phase changes do not leave stale shelf prompts

**Phase 1 exit criteria:**

- Traffic Board readability is done when a player understands why timing and prep affect buyer quality without reading a long explanation — and the board reads as forecast/prep, not "pick the same mission again."
- Rare Walk-In readability is done when a player understands that the extra buyer is an opportunity, not a broken cadence.
- First-shop-day clarity is done when a new player can start, buy or pass, and sell one item without external explanation.
- Mobile viability is done when a mobile player can complete the first shop day without fighting the UI.

**Avoid:** real-time calendar systems, broader DataStore progression, relics, unified object inventory, or scavenging economy until readability and first-session clarity are proven.

---

## Roadmap phases

A phase is not done because the feature exists. It is done when it reduces player confusion, improves return motivation, or lowers technical risk.

### Phase 1: Readability and first-session clarity

Goals:

- Finish Traffic Board readability as **forecast/prep**, not mission select.
- Use open/close shop language in player-facing surfaces when UX is updated (not claiming full sim is built).
- Keep Shop Day Variables V1 readable: compact forecasts before opening, compact results after closing, light server-owned roll-weight effects only.
- Make Rare Walk-Ins understandable.
- Reduce first-session confusion.
- Make normal-day traffic feel like the reliable baseline.
- **Shop-day variables readability** — players understand why today feels different without calling it random.
- Make mobile input and UI viable.

Exit criteria:

- A new player understands where to go first.
- A new player understands what a good deal looks like.
- A new player understands why traffic conditions, prep (display/stash), and rare buyers matter.
- A mobile player can complete the first shop day without fighting the UI.

### Phase 2: Onboarding

Goals:

- Teach buying, price judgment, haggling, and selling through guided action.
- Keep onboarding short and avoid walls of text.
- Show why a good item may be worth keeping.

Exit criteria:

- A new player completes one buy/sell loop without external explanation.
- The player sees at least one clear "I could have made more money if I understood this better" moment.
- The player understands the fantasy before being asked to optimize it.

### Phase 3: Minimal persistence

Goals:

- Save permanent scraps.
- Save 2 Stash slots.
- Save DisplayShelf items and slot positions.
- Save only what supports the core shop fantasy first.
- Avoid a giant persistence system before the loop is proven.

Exit criteria:

- The player can leave, return, and still care about at least one saved item or currency goal.
- The "save this item for the perfect buyer" fantasy starts to work across sessions.
- Persistence improves return motivation without forcing a full economy rewrite.

### Phase 4: Collection log

Goals:

- Add a small collection log for discovered items, rare buyers, or notable sales.
- Use it as a lightweight long-term goal.
- Keep it tied to weird item stories, not bloated completionism.

Exit criteria:

- The player has a simple reason to care about unusual items.
- The game gains a light long-term progression layer.
- The collection log reinforces shopkeeping instead of becoming a checklist chore.

### Phase 5: DealService refactor

Goals:

- Stop adding unrelated systems into `DealService`.
- Refactor in slices, not one giant rewrite.
- Separate responsibilities only after boundaries are stable.

Possible end-state modules:

- `BuyerVisitScheduler`
- `BuyerMatcher`
- `ArchetypeGenerator`
- `ItemValuationService`
- `HaggleResolver`
- `TacticResolver`
- `PayoutCalculator`
- `DealSummaryBuilder`
- `RareBuyerService`
- `DealDebugAdapter`

Exit criteria:

- New feature work no longer requires unrelated edits inside one giant service.
- At least one stable responsibility has moved behind a small helper or service without changing player behavior.
- Debugging buyer visits, haggling, and payouts is easier than before.

---

## Later

| Milestone | Status |
|-----------|--------|
| Persistent Shop State V1 | **Prototype** |
| Broader DataStore persistence | **Future direction** |
| Collection log | **Planned** |
| Local calendar events | **Future direction** — real-time calendar not built |
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
- Static shift picker / mission-select loop as the long-term product
- Idle passive income generators
- Player-to-player trading economy
- Auctions, rebirth, quests as core loop
- NPC pathfinding as a core system
- Fallout-clone tone (use *Neon Cursed Flea Market*)
- Endless haggling math tuning as substitute for design
- More feature layers before onboarding and return loop are solved
- Major rewrites before the player loop is validated
- Decorative object expansion before object unification
- Monetization that bypasses negotiation, buyer timing, or item judgment
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
