# Wasteland Pawn — Roadmap

Living roadmap derived from [GDD.md](GDD.md) v0.2. Update this when milestones ship or priorities change.

## North star

Create stories like:

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for a ridiculous profit."*

Haggling resolves deals. **Item routing** (buy → hold → match → cash out) is the game.

---

## Done / mostly working

| Area | Status |
|------|--------|
| Seller haggling (tactics, heat, tells, inspect) | Prototype |
| Buyer haggling (tactics, heat, tells) | Prototype |
| Item traits & categories | In configs |
| Buyer matching (score, labels, bonuses) | v1 |
| Shift inventory (limited slots, shift-scoped) | v1 |
| Buyer visits (pick item from inventory) | v1 |
| Payout summaries (profit + bonus breakdown direction) | v1 |
| Closing Rush structure | v1 |
| Shift targets (Scrap Rush, Collector Convention, Black Market Night) | Config hooks |
| Deal archetypes | Early hooks only |

---

## Now — playtest & polish (no new systems)

**Goal:** Prove holding + matching is fun before adding more content systems.

- [ ] Playtest Closing Rush pacing end-to-end
- [ ] Rename / clarify "Close Shift" vs liquidation
- [ ] Surface liquidation rate clearly (e.g. ~35% of true value)
- [ ] Verify players feel safe holding good items for the right buyer
- [ ] Verify "buyers left" in Closing Rush creates tension, not frustration
- [ ] Confirm quota check happens *after* Closing Rush, not before

**Avoid:** More haggling math tuning unless a specific playtest proves breakage.

**Success quotes to listen for:**

- "I should save this for a collector."
- "This buyer is perfect for my item."
- "I need to make room."
- "I got greedy and had to liquidate."

**Failure quotes:**

- "I just sell everything immediately."
- "The buyer doesn't matter."
- "I failed because the game didn't let me sell."

---

## Next — Deal Archetypes v1

**Goal:** Seller deals feel authored, not random soup.

| Archetype | Player lesson |
|-----------|----------------|
| Safe Flip | Confidence, basic loop |
| Scam Trap | Pass / inspect / Point Out Flaw |
| Desperate Seller | Pressure, buy low |
| Bad Deal | Passing is correct |
| Jackpot Junk | Hidden upside |
| Perfect Buyer Setup | Hold for the right buyer |

Deliverables:

- Weight archetypes per shift type
- Hook generation so shifts have rhythm (safe flip + scam + hold opportunity + match moment)
- Stop relying on pure random seller/item rolls

**MVP only:** weighted seller / item / value setup at generation time. No cutscenes, no quest chains, no big director system yet. Archetypes affect *what spawns*, not a cinematic layer.

---

## Then — Shift Identity v1

Make each shift *feel* different beyond profit target number:

| Shift | Intended feel |
|-------|----------------|
| Scrap Rush | Beginner, safe flips, desperate sellers, low pressure |
| Collector Convention | Collectible/cursed routing, perfect-match moments |
| Black Market Night | Scam traps, jackpot junk, higher risk/reward |

Deliverables:

- Shift-weighted item categories, sellers, buyers, archetypes
- Modifier text that matches actual hooks (not placeholder only)

---

## Later (explicitly not now)

| Milestone | Notes |
|-----------|--------|
| Relics v1 | Run modifiers that change *decisions*, not flat +10% |
| Item content pass | More named weird items with traits |
| Collection log | Discovery / completionist |
| Shop display | Trophy case for rare flips |
| Shop customization | Fixed slots, themes — not freeform building |
| DataStore / progression | After core loop is fun |
| Social / visits | After shop identity exists |

---

## Will not build (for now)

- Realistic pawn sim / full tycoon
- Employees, scheduling, idle passive income
- Player-to-player trading economy
- Auctions, rebirth, quests as core loop
- NPC pathfinding / map building systems
- Fallout-clone tone (use *Neon Cursed Flea Market* direction)
- Endless haggling number tuning as substitute for design

---

## Feature filter (quick check)

Before adding a feature, ask if it improves **at least one** of:

1. Weird item discovery  
2. Buy / pass decisions  
3. Inventory pressure  
4. Buyer matching  
5. Big payout moments  
6. Memorable shift stories  
7. Long-term collection (later)  
8. Shop identity / social flex (later)  

If not → wait.
