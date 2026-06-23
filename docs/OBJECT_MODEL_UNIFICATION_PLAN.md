# Object Model Unification Plan

Status: **Prototype**

This is a design and technical migration plan, not an implementation milestone.

The goal is to make haggled items, future scavenged objects, display objects, and stash objects converge into one object ecosystem without creating a second economy.

---

## Why this exists

The current prototype has two separate object shapes:

- Haggled items: server-owned economy objects in `InventoryService`.
- Hub pickup props: client-only decorative props in `HubPickupController` / `HubPickups.lua`.

That split is acceptable for the prototype, but it cannot become the final game. If scavenging props become valuable through a separate path, the game risks becoming two economies: scavenging money vs haggling money. The intended game is one shop economy where objects can come from different sources but route through the same sell / stash / display decisions.

**Shop-day preparation:** object routing supports preparing before and during an open shop day:

- `display` — public Shelf (sellable, traffic influence, persistent); player-facing: **Shelf**
- `stash` — hidden Storage (not sellable, persistent); player-facing: **Storage**
- `inventory` — legacy working stock (compat only; migrated to Shelf on shift start; liquidated at close)

Traffic Board / internal shift configs are prototype traffic wrappers, not the final open-shop fantasy.

---

## Current repo reality

### Haggled items

Implemented as server-authoritative entries in `InventoryService`.

Important fields today:

- `instanceId`
- `itemId`
- `displayName`
- `category`
- `traits`
- `flavorText`
- `purchasePrice`
- `estimatedLow`
- `estimatedHigh`
- `sellerName`
- `sellerTell`
- `heldBack`
- `location`
- `displaySlotIndex`
- `stashSlotIndex`

Valid locations today:

- `inventory` - legacy working stock (compat); phased out in Public Shelves V1
- `display` - public Shelf; sellable, affects demand, persists (internal key unchanged)
- `stash` - Storage; 2-slot hidden stock; does not affect demand, not sellable from shelf

### Hub pickup props

Prototype only. Client-owned and decorative.

Current decision: **freeze, do not expand**. Keep hub pickups if they support the physical shop fantasy, but do not add more decorative object behavior until it has a clear relationship to inventory, display, value, or persistence.

Important fields today:

- `propId`
- `assetName`
- `displayName`
- `placeholderSize`
- `placeholderColor`

They do not have:

- server instance ids
- value
- category / traits
- buyer matching
- persistence
- economy authority

---

## Target concepts

### ObjectDefinition

Static config for an object type.

Suggested fields:

```lua
{
	id = "alien_memory_crystal",
	displayName = "Memory Crystal",
	category = "Alien Tech",
	baseValue = 165,
	flavorText = "Shows flickers of someone else's dream.",
	traits = { "Alien", "Collectible", "Weird" },
	visualKey = "alien_memory_crystal",
	sourceTags = { "seller", "future_scavenge" },
}
```

Notes:

- This mostly matches `Items.lua` today.
- Hub prop visuals should eventually point at this same definition shape.
- `sourceTags` are descriptive; they should not create different economies.

### OwnedObject

Server-owned instance of an object in a player's shop state.

Suggested fields:

```lua
{
	instanceId = "item_123",
	objectId = "alien_memory_crystal",
	origin = "seller",
	location = "inventory",
	acquiredAtSessionTick = 42,

	displayName = "Memory Crystal",
	category = "Alien Tech",
	traits = { "Alien", "Collectible", "Weird" },
	flavorText = "Shows flickers of someone else's dream.",

	purchasePrice = 78,
	estimatedLow = 120,
	estimatedHigh = 190,
	trueValue = 165,

	displaySlotIndex = nil,
	stashSlotIndex = nil,
	disposed = false,
}
```

Notes:

- Server owns all economy-relevant fields.
- Client props mirror this data; they do not create it.
- `objectId` should replace or alias today's `itemId` over time.
- `location` remains the main routing state.

---

## Location rules

Keep location semantics simple and authoritative.

| Location | Meaning | Sellable | Affects demand | Liquidated |
|----------|---------|----------|----------------|------------|
| `display` | Public Shelf (`Shop.Shelf`) | Yes | Yes | No |
| `stash` | Storage | No | No | No |
| `inventory` | Legacy working stock (compat) | Yes (migrating) | No | Yes |
| `counter` | Active negotiation item | In active deal only | No | No |
| `discarded` | Removed / sold / liquidated | No | No | No |

Notes:

- `counter` can remain implicit for now through `DealService.pendingInstanceId`.
- `discarded` can remain `disposed = true` for now.
- Do not expose `heldBack` as a player-facing route. It can remain as a compatibility flag until removed safely.

---

## Migration phases

### Phase 0 - Current state

Status: **Prototype**

- Haggled items are server-owned.
- **Shelf** and 2 **Storage** slots (internal `display` / `stash`) persist through Persistent Shop State V1.
- Legacy `inventory` working stock remains temporary (compat only).
- Hub pickups are decorative and client-only.
- Hub pickups are frozen: keep them working, but do not expand them before object unification has a clear gameplay purpose.

No action needed beyond keeping docs honest.

### Phase 1 - Shape alignment

Status: **Planned**

Small code cleanup only:

- Introduce shared naming around `ObjectDefinition` / `OwnedObject`.
- Keep `Items.lua` as the haggled item definition source.
- Add adapter helpers:
  - `ObjectModel.fromDefinition(itemDef, fields)`
  - `ObjectModel.normalizeOwnedObject(entry)`
  - `ObjectModel.serializeForInventorySnapshot(entry)`
- Keep existing remotes and snapshots stable.
- Do not move hub pickups into economy yet.

Current implementation:

- `Shared.Util.ObjectModel` owns location constants and object/id normalization.
- `InventoryService` uses the helper when creating and serializing owned haggled items.
- Snapshots preserve `itemId` and include compatible `objectId` aliases for future naming.

Success:

- New code talks about objects without changing gameplay.
- Haggled item behavior remains identical.

### Phase 2 - Hub prop mapping

Status: **Prototype** (frozen; do not expand)

Map decorative hub pickups to object definitions without making them sellable.

Example:

```lua
{
	propId = "broken_radio",
	objectId = "tech_handheld_radio",
	assetName = "BrokenRadio",
	displayName = "Broken Radio",
}
```

Rules:

- Mapping is informational at first.
- Picking up a hub prop still does not grant money or shift inventory.
- No buyer matching from hub props yet.
- Do not add more decorative prop expansion here. New work should wait until hub props have a defined relationship to inventory, display, value, or persistence.

Current implementation:

- `HubPickups.lua` includes informational `objectId` mappings for the three prototype decorative props.
- `HubPickupController` copies the mapping onto local prop metadata as `HubObjectId`.
- No server-owned object is created from a hub pickup.

Success:

- Visual props can reuse object metadata and visuals.
- Still no second economy.
- The plan stays ready for future unification without turning decorative props into a parallel game.

### Phase 3 - Server-owned acquisition prototype

Status: **Future direction**

Only after the shop loop is stable.

Convert one controlled acquisition source into a real server-owned object.

Good candidate:

- A single debug or test-only "find object" action in Studio.

Bad candidate:

- A full outdoor scavenging loop with value payouts.

Rules:

- New acquisitions create `OwnedObject` entries through the same server path.
- They route through `stash`, `display`, or `inventory`.
- They sell through the same buyer matching and haggling systems.

Success:

- A non-seller object can enter the same object economy.
- There is still one sale path.

### Phase 4 - Persistence and collection

Status: **Future direction**

Only after object routing is fun and stable.

Possible additions:

- saved stash / display
- collection log
- object history
- shop identity

This is intentionally not part of the current prototype.

---

## Server authority rules

When this plan becomes implementation, preserve these rules:

- Server creates economy-relevant object instances.
- Server owns value, purchase price, true value, location, and slot assignment.
- Client may request routing, never decide routing.
- Buyer offers only use `location == "display"` (Shelf).
- Shelf appeal only uses `location == "display"`.
- Liquidation only uses legacy `location == "inventory"`.
- **Storage** (`stash`) never affects buyer rolls.
- Hub props remain decorative and frozen until explicitly converted to server-owned objects through a future unification milestone.

---

## What not to build from this plan yet

Do not build these as part of the planning milestone:

- broader DataStore persistence beyond scraps / 2-slot **Storage** / **Shelf**
- permanent working inventory
- collection log
- full scavenging economy
- player trading
- calendar system
- relics or display modifiers
- shop customization economy
- map expansion

---

## Next safe implementation slice

The safest implementation after this plan is **Phase 1: Shape Alignment**.

Likely files:

- `src/ReplicatedStorage/Shared/Config/Items.lua`
- `src/ServerScriptService/Server/Services/InventoryService.lua`
- `src/ReplicatedStorage/Shared/Util/InventorySnapshot.lua`
- `docs/GDD.md`
- `docs/ROADMAP.md`

Expected outcome:

- No gameplay change.
- No new remotes.
- No object-model migration or hub-pickup persistence.
- Clearer names and helper boundaries for future object routing.

---

## Open questions

- Should `trueValue` be stored on all owned objects or only revealed/debug snapshots?
- Should `counter` become a real `location`, or stay implicit in `DealService`?
- Which existing decorative hub prop mappings should survive when object unification begins?
- Should `heldBack` be removed after all old compatibility paths are gone?
- Persistent Shop State V1 saves haggled **Storage** / **Shelf** items. Future work still needs to decide when hub pickups become server-owned objects.
