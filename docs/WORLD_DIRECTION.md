# Wasteland Pawn — World, Building, and Scavenging Direction

**Status:** Strategic direction — not an implementation plan.

This doc keeps future prompts aligned with the real game: a **weird shopkeeping / negotiation game with Roblox retention discipline**. The shop is the heart. The world exists to feed the shop.

Full design source of truth for the current prototype: [GDD.md](GDD.md). Milestones: [ROADMAP.md](ROADMAP.md).

---

## What this game is not

Do not drift into:

- giant survival game
- tycoon conveyor game
- idle / rebirth simulator
- generic open-world collectathon
- Bloxburg-style freeform building game

---

## Core player fantasy

```text
I run a weird pawn shop in a wasteland town.
I go out into strange places, find weird junk, bring it home, arrange it, and sell it to freaks.
```

- **The shop is the heart of the game.**
- **The world exists to feed the shop.**
- **Scavenging exists to create interesting stock decisions.**
- **Building exists to make the shop personal and strategically useful.**

Do not let the game become "walk forever in a huge empty desert."

Do not let the game become "teleport to private dungeon #4 from a menu."

Do not let the game become "buy machines, wait for money, rebirth."

---

## North star scene (far future)

```text
You spawn in a dusty pawn town.
Other players' weird shops line the road.
A board says: "Alien Caravan in 12 minutes. Wants Tech and Relics."
You hop in your busted junk scooter.
Two other players are driving toward the Crash Site too.
You search wreckage and find a humming alien battery.
Your bag is almost full, so you leave a broken toaster behind.
You return to your shop.
You put the alien battery in your display case.
A strange customer arrives because they saw it.
You haggle.
Other players walk by and see your shop getting weirder.
```

This is the target fantasy. Every world system should support moments like this.

---

## 1. World structure

### Recommended far-future model

```text
Shared wasteland pawn town
+ player shop plots around the town
+ compact POIs connected by roads/outskirts
+ optional vehicles for hauling/style
+ later rare instanced expeditions for special content
```

The world should feel **connected and social**, but still **dense and readable**.

### Town layout (target)

```text
Wasteland Pawn Town
├─ Player shop plots
├─ Shared town services
│  ├─ Traffic Board
│  ├─ Black Market notice board
│  ├─ NPC trader
│  ├─ upgrade vendor
│  └─ event announcer
├─ Roads / gates to compact POIs
│  ├─ Junkyard
│  ├─ Dead Mall
│  ├─ Crash Site
│  ├─ Military Dump
│  ├─ Haunted Ruins
│  └─ Black Market Alley
└─ Social / visual weirdness
```

### Player shop plots

Players are assigned plots around the central town/hub. When a player joins:

```text
find empty shop plot
→ spawn/load their shop shell there
→ load Shelf / Storage / Counter / decoration state
→ start player at their shop
```

Player shops should be visible enough to create **social proof and curiosity**.

### Early multiplayer direction

```text
public/shared outside world
player-owned shop plots
server-authoritative inventory
no player trading economy yet
```

### Prototype today

The current repo uses a **single embedded shop** in Studio (`Workspace.World.Shop`). That is a stepping stone, not the final world model.

---

## 2. POI / scavenging world model

### Same server, connected world

Normal POIs should live in the **same connected server world** when possible — not separate Roblox places.

Reason:

- keeps the world feeling physical
- keeps player shops socially visible
- reduces teleport/menu feeling
- lets players cross paths naturally
- makes driving/travel meaningful without fragmenting the server

### Reserve instanced places for special content

Separate Roblox places / instanced areas are for **later special content** only:

- rare crashed alien ship
- haunted bunker expedition
- black market convoy
- military vault
- timed storm salvage event

**Normal scavenging should not require teleporting away from the social hub.**

### POI design rules

```text
small
dense
readable
high-intent
2 to 5 minute runs
clear item themes
clear reason to visit
```

### Example POIs and themes

| POI | Typical finds |
|-----|----------------|
| Junkyard | tools, scrap, broken machines |
| Dead Mall | toys, electronics, cursed retail junk |
| Crash Site | alien tech, black boxes, strange metal |
| Military Dump | radios, armor, military junk |
| Haunted Ruins | relics, cursed items, skulls |
| Black Market Alley | risky deals, fake items, rare sellers |
| Meteor Field | glowing rocks, alien junk |

### Example POI run (Dead Mall)

```text
Dead Mall
├─ toy store rubble
├─ electronics kiosk
├─ cursed fountain
├─ locked back room
└─ weird vending machine
```

Players make small decisions: search deeper, take cursed object, leave fake-looking item, use bag space on bulky item, pay NPC for a tip, risk damaged item for higher value.

### Prototype today

`World.Outside.ScavengeNodes` currently hosts **Scavenge Node V0**: small server-authoritative junk searches that feed Shelf/Storage. It is not the future POI scavenging system. See [known_issues.md](known_issues.md).

---

## 3. Vehicles

Vehicles are a good **far-future** idea. They should support the shop loop.

### Vehicles should be

- short-distance travel tools
- haulers for bigger/more items
- social/status objects
- optional convenience/progression

### Vehicles should not become

- mandatory long commute machines
- physics headache centerpieces
- the main progression system
- empty map padding

### Progression sketch

```text
starter: walk / carry by hand
early: cart or hand truck
mid: junk scooter / wagon
later: scavenging van / buggy
endgame: weird convoy vehicle
```

### Gameplay meaning (example)

```text
small bag = 3 items
cart = 5 items
van = 8 items or one huge item
```

Keep travel **fast**. Avoid boring downtime.

---

## 4. Outposts / remote shops

Do **not** make "set up your whole shop anywhere" the main early model.

The **main shop stays in town.**

Far-future outposts near POIs **supplement** the main shop instead of replacing it:

- Junkyard stall
- Dead Mall kiosk
- Black Market table
- Crash Site salvage tent

Outposts might allow:

- small local storage
- special local buyers
- temporary event selling
- reduced travel friction

The player's main identity remains their **town pawn shop**.

**Why:** If everyone can move their main shop anywhere, players scatter, the hub dies, new players see emptiness, and social density drops.

---

## 5. Socialization direction

Players should make friends through **repeated low-pressure contact**, not forced trading.

### Good social features later

- seeing other players' shops
- visiting shops
- liking/rating shops
- guest book
- public rare item displays
- convoy scavenging events
- "help carry huge junk" moments
- public POI events
- event timers pulling players to the same location

### Avoid early player trading

Player trading creates exploit and economy-balancing problems. Socialization should come from:

```text
shops near each other
visible rare finds
shared POIs
shared events
vehicles/convoys
shop flexing
```

---

## 6. Building system direction

Do **not** build a full freeform building system first.

Use an **anchor/slot-based shop customization** system.

### Build Mode flow

```text
Build Mode
→ choose object
→ valid spots glow
→ click spot
→ object appears
```

### Valid placement zones

- Shelf slots
- Storage spots
- Wall decoration spots
- Counter spots
- Relic pedestal spots
- Sign spots
- Floor decoration spots
- Lighting spots

### Buildable roles

| Role | Purpose |
|------|---------|
| Shelves | more public stock |
| Storage | more hidden saved stock |
| Display cases | protect/boost rare items |
| Relics | attract specific buyer types or change shop weirdness |
| Signs | influence traffic/events slightly |
| Counter upgrades | improve selling flow |
| Decorations | reputation / vibe / collection flex |
| Lighting | readability / cosmetic |

### Good direction

```text
Add cursed display case
→ cursed buyers show up more often
→ normal buyers may react differently
```

### Bad direction

```text
Buy money printer
→ upgrade money printer
→ rebirth
→ repeat
```

### Shop expansion should be physical

```text
Starter Shop
→ bigger shelf wall
→ back storage room
→ side display room
→ rare item case
→ relic corner
→ outdoor bargain bin
```

Player-facing terms: **Shelf**, **Storage**, **Counter**. Internal save keys (`display`, `stash`, etc.) stay unchanged unless explicitly planned later. See [OBJECT_MODEL_UNIFICATION_PLAN.md](OBJECT_MODEL_UNIFICATION_PLAN.md).

---

## 7. Open-world scavenging direction

Scavenging should be **short, readable, risky, and tied to upcoming demand**.

### Core loop

```text
check upcoming shop demand
→ choose where to scavenge
→ do a short POI run
→ find 1 to 5 items
→ bring them home
→ decide Shelf / Storage / discard / hold for event
→ open shop
```

Scavenging should **not** be infinite clicking.

Better model:

```text
You have limited search chances or bag space.
Each POI has a handful of meaningful nodes.
Pick what looks promising.
Some are safe.
Some are risky.
Some are weird.
```

Scavenged objects must feed the **same object economy** as haggled items — not a separate money loop. See [GDD.md](GDD.md#two-economy-problem).

---

## 8. Demand connection

Scavenging should connect directly to the **Traffic Board** and upcoming events.

### Examples

**Tomorrow: Collector Convention**

```text
Buyers want: relics, antiques, cursed objects
Player goes to: Haunted Ruins
```

**Tomorrow: Repair Fair**

```text
Buyers want: tools, broken machines, machine parts
Player goes to: Junkyard
```

**Alien Caravan soon**

```text
Buyers want: alien tech, glowing junk
Player goes to: Crash Site
```

This gives players future intent:

```text
I know what buyers are coming.
I know what I should look for.
I have a reason to play one more loop.
```

---

## 9. Retention / boredom / confusion guardrails

### Prioritize

- clear goals
- short loops
- visible progress
- social density
- physical shop personalization
- upcoming events
- weird item surprises
- fast return to selling

### Avoid

- huge empty maps
- unclear travel
- long walking
- private teleport spam
- bloated survival systems
- generic resource farming
- player trading economy too early
- realistic simulation over fun

The world should feel large because it is **interesting**, not because the player spends minutes crossing empty space.

---

## Related docs

| Doc | Role |
|-----|------|
| [GDD.md](GDD.md) | Current prototype design source of truth |
| [ROADMAP.md](ROADMAP.md) | Milestone buckets including far-future world work |
| [OBJECT_MODEL_UNIFICATION_PLAN.md](OBJECT_MODEL_UNIFICATION_PLAN.md) | One object economy; future placed buildables |
| [known_issues.md](known_issues.md) | Design risks for world scope creep |
