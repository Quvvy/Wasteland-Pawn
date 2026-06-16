# Wasteland Pawn — Game Design Document

| | |
|---|---|
| **Version** | 0.2 |
| **Status** | Living design document |
| **Purpose** | Define vision, core loop, current systems, future direction, and feature boundaries |

See also: [ROADMAP.md](ROADMAP.md) for milestone tracking.

---

## Table of contents

- [One sentence vision](#one-sentence-vision)
- [High concept](#high-concept)
- [Core player fantasy](#core-player-fantasy)
- [Target platform and audience](#target-platform-and-audience)
- [Genre](#genre)
- [Design pillars](#design-pillars)
- [What the game is not](#what-the-game-is-not)
- [Core gameplay loop](#core-gameplay-loop)
- [Current implemented systems](#current-implemented-systems)
- [Shift structure](#shift-structure)
- [Deal archetypes](#deal-archetypes)
- [Items](#items)
- [Buyers](#buyers)
- [Sellers](#sellers)
- [Haggling philosophy](#haggling-philosophy)
- [Payout screen](#payout-screen)
- [Holy crap moments](#holy-crap-moments)
- [Art direction](#art-direction)
- [UI direction](#ui-direction)
- [Long-term progression](#long-term-progression)
- [Relics / counter items](#relics--counter-items)
- [Future shop system](#future-shop-system)
- [Feature filter](#feature-filter)
- [Current development stage](#current-development-stage)
- [Immediate to-do](#immediate-to-do)
- [Success criteria](#success-criteria)
- [Development principles](#development-principles-codex--cursor)
- [Glossary](#glossary)
- [North star](#north-star)

---

## One sentence vision

**Wasteland Pawn** is a shift-based weird-item flipping game where players buy strange junk, identify hidden value, match items to the right buyers, and cash out for absurd profit.

The game is **not** about realistic pawn shop management.

It is about finding value in garbage, making smart flips, and creating stories like:

> *"I bought a cursed traffic cone for 40 scraps and sold it to an alien tourist for 8,000 because it perfectly matched my buyer and bonuses."*

---

## High concept

The player runs a sketchy pawn shop in a wasteland.

- Sellers bring strange items — some scams, some trash, some secretly worth a fortune.
- The player decides what to buy, pass, inspect, hold, and which buyer deserves which item.
- Each **shift** is a short run: profit target, limited seller visits, limited inventory, buyer visits, and a **Closing Rush** cashout phase.
- Long-term fantasy: become the most notorious junk dealer in the wasteland.

---

## Core player fantasy

The player is not just a negotiator. They are:

- a junk dealer
- a scam spotter
- a treasure hunter
- a buyer matcher
- a risk taker
- a collector of weird garbage
- someone who sees value where others see trash

Core fantasy line:

> *"I know this weird thing is worth something. I just need the right buyer."*

---

## Target platform and audience

**Platform:** Roblox

**Audience:**

- Players who like collecting, trading, upgrading, and number-go-up loops
- Short repeatable sessions
- Weird items and funny outcomes
- Decisions without high mechanical skill
- Showing off progress, rare finds, and customized spaces

**Readability:** A spectator should understand within ~10 seconds:

- buying weird junk
- selling for more
- some items are secretly valuable
- matching the right buyer matters

---

## Genre

| Primary | Secondary influences |
|---------|------------------------|
| Shift-based item flipping | Roguelite run structure |
| | Light negotiation game |
| | Collection game |
| | Shop fantasy |
| | Strategy-lite economy |

**Avoid becoming:** pure tycoon, idle simulator, or realistic store-management game.

---

## Design pillars

### Pillar 1: Weird items are the star

Players should remember **names and stories**, not `Item #37 (+12% value)`.

Every item needs strong name, traits, category, flavor, and visible value clues.

**Example items:** Possessed Traffic Cone, Cursed Lunchbox, Alien Soda Tab, Crying Toaster, Mayor's Left Shoe, Rusted Robot Heart, Jar of Living Dust, Suspicious Taxidermy Ferret.

### Pillar 2: Smart decisions over realism

Reward judgment. Key questions:

- Should I buy / pass / inspect?
- Is this seller lying?
- Is this worth an inventory slot?
- Sell now or wait for a better buyer?
- Dump to a bad buyer or hold?
- Risk one more buyer reroll?
- Liquidate and close now?

### Pillar 3: Haggling is a resolution layer

Haggling answers: *"How well did this deal resolve?"*

The main game is **item routing:** buy weird item → hold → match buyer → cash out.

### Pillar 4: Buyer matching creates aha moments

Example: Rich Collector visits while you hold Cursed Lunchbox, Broken Toaster, Alien Soda Tab → player should immediately think *"Cursed Lunchbox is the play."*

### Pillar 5: Big payouts feel explosive

Result screen must explain **why** a sale was good: base profit, buyer match bonus, trait bonus, total cash, match label, rarity, true value.

### Pillar 6: Every shift tells a story

Good shifts have highs, lows, risks, and payoff — not six disconnected transactions.

---

## What the game is not

| Not this | Why |
|----------|-----|
| Realistic pawn sim | Fun > realism; values can exaggerate |
| Traditional tycoon | Core is active flipping, not passive income |
| Store management sim | No scheduling/logistics focus |
| Pure haggling game | Negotiation must not carry the whole experience |
| Player trading economy | Not core now; maybe much later |
| Fallout clone | Tone is weird, funny, dusty, cursed, **neon** — not generic brown apocalypse |

---

## Core gameplay loop

1. Start a shift.
2. Seller arrives with a weird item.
3. Player reads item info, traits, estimate, seller tell.
4. Player haggles, inspects, buys, or passes.
5. Bought item enters **limited shift inventory**.
6. **Buyer visits** occur during the shift.
7. Player **chooses which inventory item** to offer.
8. Buyer interest depends on category and traits.
9. Player haggles sale.
10. Sale pays cash and **match bonuses**.
11. Seller visits eventually run out.
12. If inventory remains → **Closing Rush**.
13. Cash out remaining inventory or liquidate.
14. Shift result vs profit quota.

### Loop diagram

```
Start Shift
    ↓
Buying Phase
    ↓
Seller Visit → Evaluate → Buy / Pass / Inspect / Haggle → Store in Inventory
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

## Current implemented systems

*As of latest prototype direction.*

### Seller haggling

Resolution mechanic for buying. Includes tactics, heat, leverage, confidence, final-offer states, profile weaknesses/resistances, inspect, seller tells.

**Buy tactics:** Lowball, Split Difference, Point Out Flaw, Pressure, Accept Price, Pass.

*Keep stable — good enough unless playtest proves breakage.*

### Buyer haggling

Resolution mechanic for selling after choosing an inventory item. Includes offer, maximum, heat, leverage, confidence, buyer profiles, match influence.

**Sell tactics:** Small Bump, Pitch Value, Hold Firm, Bluff, Accept Offer, Find Another Buyer / Keep Item.

*Keep stable — good enough unless playtest proves breakage.*

### Shift inventory

- **3 active slots** per shift (direction)
- Bought items enter inventory; resets each shift
- No DataStore yet
- Creates slot pressure — *does this item deserve a slot?*

### Buyer visits

Player **chooses** which held item to offer. Visit should show:

- buyer name, tell, wants/preferences
- inventory items with **match labels** per item

Matching should matter more than tiny haggle deltas.

### Buyer matching

**Inputs:** item category, item traits, buyer category/trait preferences.

**Outputs:** match score, match label, offer multiplier, matched categories/traits, bonus lines.

**Labels:** Bad Match → Low Interest → Curious → Interested → Perfect Match

### Payout bonuses

Bonuses are **real cash**, not fake score. If the UI shows a bonus, wallet must reflect it.

### Closing Rush

When seller visits end but inventory remains:

- No more sellers
- Limited final buyers
- Sell, hold, or skip
- Unsold items **liquidate** at bad rate (~35% intended)
- Quota checked **after** Closing Rush ends

**Fixes old problem:** game encouraged holding items then ended shift before selling.

**New tension:** *"I can hold this, but I might have to dump it."*

---

## Shift structure

| Phase | What happens |
|-------|----------------|
| **Buying** | Limited seller visits; periodic buyer visits; inventory pressure; profit target visible |
| **Closing Rush** | No sellers; final buyers; limited count; liquidation fallback; quota after phase ends |
| **Ended** | Result: total profit, target, success/fail, grade, liquidation summary |

### Shift examples (config direction)

| Shift | Purpose | Player feel |
|-------|---------|-------------|
| **Scrap Rush** | Beginner | Short, easy target, safe flips, low pressure |
| **Collector Convention** | Matching | Collectibles/cursed routing, higher target |
| **Black Market Night** | Risk | Scam traps, jackpot junk, big upside/downside |

### What makes a good shift

Include across the run:

- at least one safe flip
- one clear pass
- one scam/suspicious seller
- one item worth holding
- one buyer-match opportunity
- one high-upside moment
- one tense cashout decision

---

## Deal archetypes

*Planned / early hooks — makes deals feel authored.*

**MVP scope:** weighted seller/item/value at generation time only. No cutscenes, quest chains, or director system.

| Archetype | Purpose |
|-----------|---------|
| **Safe Flip** | Confidence, teaches loop, low risk |
| **Scam Trap** | Pass/inspect/flaw matter; punishes blind buy |
| **Desperate Seller** | Pressure tactics, buy-low satisfaction |
| **Bad Deal** | Correct play is pass |
| **Jackpot Junk** | Looks bad, secretly valuable |
| **Perfect Buyer Setup** | Mediocre alone, great with right buyer |

---

## Items

Most important content. Each item should have:

name · category · traits · rarity · true value · estimate range · flavor · buyer appeal · visual identity

### Categories (examples)

Scrap · Cursed Junk · Alien Tech · Old World Tech · Collectibles · Military · Dangerous · Sentimental · Weird Artifacts · Rare Parts

### Traits (examples)

Cursed · Alien · Collectible · Useful · Damaged · Shiny · Fake · Military · Weird · Dangerous · Sentimental · Ancient · Broken · Rare Part · Contraband

### Item name examples

Possessed Traffic Cone · Crying Toaster · Moon Casino Token · Suspicious Taxidermy Ferret · Mini Gravity Reactor · The Mayor's Left Shoe · Jar of Living Dust · Singing Teeth · Alien Soda Tab · Cursed Lunchbox · Rusted Robot Heart · …

---

## Buyers

Readable archetypes — player infers wants from name/look/description.

| Buyer | Role | Likes (examples) |
|-------|------|------------------|
| **Cheap Scavenger** | Dump bad items; low offers | cheap junk, scrap |
| **Rich Collector** | Big payouts for matches | Collectible, Cursed, Weird, Sentimental |
| **Desperate Mechanic** | Practical parts | Useful, Damaged, Old World Tech, Rare Part |
| **Alien Tourist** | Volatile jackpots | Alien, Weird, Cursed, Shiny |
| **Robot Appraiser** | Fair, hard to trick | accurate value, practical |
| **Black Market Dealer** | Risky high reward | Military, Dangerous, Contraband, Cursed |

---

## Sellers

Affect asking price, minimum, tells, tactic weaknesses, scam chance, desperation, confidence.

Examples: Desperate Survivor · Shady Scammer · Rich Collector · Robot Trader · Alien Tourist Seller · …

---

## Haggling philosophy

**Should be:** readable, tense, short, tactic-based, profile-driven, heat/confidence, supportive of item game.

**Should not be:** perfect sim, long dialogue trees, endless tiny tuning, the only source of decisions.

- Good: *"I can push one more time, but they might walk."*
- Bad: *"I'm clicking numbers until the price changes."*

---

## Payout screen

Messy pawn receipt — the dopamine moment.

Show:

- Bought For / Sold For
- Cash Bonuses (Buyer Match, Trait Match)
- Total Cash Received / Base Profit / Total Profit
- Match Label · True Value · Rarity · Shift Progress

**Example:**

```
Bought for:     80 scraps
Sold for:       260 scraps
Cash Bonuses:   +195 scraps
  Buyer Match:  +120 scraps
  Trait Match:  +75 scraps
Cash Received:  455 scraps
Total Profit:   +375 scraps
Stamp:          PERFECT MATCH
```

---

## Holy crap moments

- Jackpot junk discovered after buy
- Perfect buyer for held item
- Huge flip (many × purchase price)
- Scam caught / avoided
- Closing Rush quota save
- Relic combo (future)
- Rare discovery (new item)

Must be **visible, readable, shareable**.

---

## Art direction

**Style name:** *Neon Cursed Flea Market*

| Outside world | Shop interior |
|---------------|---------------|
| dusty, rusty, roadside, worn | warm, dense, cluttered, glowing, weird |

Avoid muddy brown apocalypse realism. Target: stylized roadside pawn shop — neon signs, cursed junk, alien trash, scammy sellers, buyers who look like walking red flags.

**Item visuals:** readable silhouette, one funny detail, one value clue, one rarity effect.

---

## UI direction

Pawn receipt / price tag / scrap-paper ledger.

Motifs: receipt paper, stamped labels, price tags, sticky notes, red circles, scrap frames, handwritten warnings.

Key labels: Seller Ask · Inventory · Buyer Match · Closing Rush · Buyers Left · Total Flip · Perfect Match · Scam Caught · Liquidated

**Clarity over decoration.**

---

## Long-term progression

*Not implemented.*

| System | Purpose |
|--------|---------|
| Collection log | Discovery, rare chase, social flex |
| Shop display | Trophy case for best flips |
| Shop customization | Fixed slots/themes — not freeform building |
| Shift / buyer / relic unlocks | Run variety and buildcraft |

---

## Relics / counter items

*Future.* Must change **decisions**, not flat +10%.

Good examples:

- First Cursed item sold each shift also counts as Collectible
- Pass two sellers → next seller higher jackpot chance
- Alien buyers pay double for Weird; others pay less
- +1 inventory slot but higher shift quota

---

## Future shop system

Shop customization + display, **not** freeform building.

Player should say: *"Come look at my cursed item room."*

Supports visual progress and social showing — must not distract from flipping loop.

---

## Feature filter

Before adding a feature, does it improve at least one of:

1. Weird item discovery  
2. Buy/pass decisions  
3. Inventory pressure  
4. Buyer matching  
5. Big payout moments  
6. Memorable shift stories  
7. Long-term collection (later)  
8. Shop identity / social flex (later)  

**Examples:**

| Feature | Verdict |
|---------|---------|
| Collection log | Yes |
| Full employee scheduling | No — management sim |
| Pets | Only if they support discovery/identity |
| Full building system | Not now |
| Relics | Yes, after core loop stable |
| More haggling math | Only if playtest proves need |

---

## Current development stage

### Completed / mostly working

Seller & buyer haggling · traits · buyer matching · shift inventory · buyer visits · payout summaries · Closing Rush structure

### Current focus

Playtest: Closing Rush pacing, buyer limits, inventory pressure, quota fairness, liquidation clarity, whether holding feels good.

### Next major milestone

**Deal Archetypes v1** — authored deals, shift rhythm, less random soup.

### Following

**Shift Identity v1** — Scrap Rush / Collector Convention / Black Market Night feel distinct.

### Later

Relics · more items · collection log · shop display/customization · saving/progression.

---

## Immediate to-do

**Do now:**

- Playtest Closing Rush
- Clarify Close Shift / liquidation UI
- Show ~35% liquidation rate
- Validate holding good items feels safe
- Validate buyers-left tension

**Do next:** Deal Archetypes v1, shift weights, stronger shift identity.

**Do later:** Relics, content, collection, shop, saving.

---

## Success criteria

**Moving right if players say:**

- "Save this for a collector."
- "This buyer is perfect."
- "I need to make room."
- "I got greedy and liquidated."
- "Barely hit quota in Closing Rush."
- "One more shift."
- "Look at this weird item."

**Failing if:**

- "I sell everything immediately."
- "Buyer doesn't matter."
- "Traits don't matter."
- "Every deal feels the same."
- "Game didn't let me sell."
- "Just tuning haggling forever."
- "Weird items are only names."

---

## Development principles (Codex & Cursor)

1. Protect the core loop — don't fight holding + matching.
2. Small, testable milestones.
3. Don't rewrite haggling without playtest proof.
4. Future systems stay hooks until loop works.
5. Decisions visible in UI.
6. Payout causes clear.
7. Avoid overengineering and unrelated Roblox trends.
8. **Designer first, coder second.**

---

## Glossary

| Term | Definition |
|------|------------|
| **Seller visit** | Buying opportunity — seller brings an item |
| **Buyer visit** | Selling opportunity — player picks inventory item to offer |
| **Shift** | Short run with sellers, buyers, inventory cap, quota, result |
| **Buying phase** | Main shift phase while sellers still arrive |
| **Closing Rush** | Final cashout after sellers exhausted |
| **Liquidation** | Bad fallback cashout for unsold items (~35% intended) |
| **Buyer match** | How well item fits buyer preferences |
| **Perfect match** | High-value fit; should feel exciting |
| **Deal archetype** | Authored deal shape (Safe Flip, Scam Trap, …) |
| **Relic** | Future run modifier for buildcraft |
| **Shift identity** | What makes each shift type feel different |

---

## North star

> *"I bought a haunted traffic cone for 40 scraps, held it through two bad buyers, almost ran out of time, then sold it during Closing Rush to an alien tourist for a ridiculous profit."*

If a feature helps create stories like that, it probably belongs. If not, it can wait.

---

*This file (`docs/GDD.md`) is the source of truth for design (v0.2). `docs/Wasteland Pawn GDD.docx` is an optional human export — edit the markdown, not the Word file.*
