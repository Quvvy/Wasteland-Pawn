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
- Rare Buyer Walk-In V1
- Closing Rush and liquidation

**Next design target:**

- finish Traffic Board + Rare Walk-In readability/hardening
- improve first-session onboarding and mobile clarity
- add a real return reason only after the player understands the loop

**Still intentionally out of current phase scope:**

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
| Rare Buyer Walk-In V1 | **Prototype** |
| Ctrl+U debug overlay + Studio debug actions | **Prototype** |

---

## Now

**Current phase:** Phase 1 - Readability and first-session clarity.

- [ ] Finish Traffic Board readability and hardening
- [ ] Make Rare Walk-Ins understandable as extra buyer opportunities
- [ ] Reduce first-shift confusion before adding more feature layers
- [ ] Make mobile input and UI viable enough for the first shift

**Stabilize:**

- [x] InventoryShelf prompt mode: Offer only during BuyerVisit; Hold Back only outside BuyerVisit
- [x] Server rejects display items for buyer offers
- [x] Rapid phase changes do not leave stale shelf prompts

**Phase 1 exit criteria:**

- Traffic Board readability is done when a player understands why timing affects buyer quality without reading a long explanation.
- Rare Walk-In readability is done when a player understands that the extra buyer is an opportunity, not a broken cadence.
- First-shift clarity is done when a new player can start, buy or pass, and sell one item without external explanation.
- Mobile viability is done when a mobile player can complete the first shift without fighting the UI.

**Avoid:** real-time calendar systems, DataStores, relics, unified object inventory, or scavenging economy until readability and first-session clarity are proven.

---

## Roadmap phases

A phase is not done because the feature exists. It is done when it reduces player confusion, improves return motivation, or lowers technical risk.

### Phase 1: Readability and first-session clarity

Goals:

- Finish Traffic Board readability.
- Make Rare Walk-Ins understandable.
- Reduce first-session confusion.
- Make Scrap Rush feel like the reliable normal-day baseline.
- Make mobile input and UI viable.

Exit criteria:

- A new player understands where to go first.
- A new player understands what a good deal looks like.
- A new player understands why traffic windows and rare buyers matter.
- A mobile player can complete the first shift without fighting the UI.

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

- Add permanent scraps.
- Add a tiny permanent stash.
- Save only what supports the core fantasy first.
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
| Permanent scraps + tiny permanent stash | **Planned** |
| Broader DataStore persistence | **Future direction** |
| Collection log | **Planned** |
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
