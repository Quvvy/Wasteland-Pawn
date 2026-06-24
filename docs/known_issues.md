# Known Issues

Living notes for bugs, technical debt, possible exploits, risky systems, and cleanup tasks.
Keep entries short. Add enough context that future us knows what happened.

---

## Critical

Issues that can corrupt state, break core gameplay, duplicate items/money, or allow exploits.

No current critical issues tracked.

---

## Design risks (world / building / scavenging)

Strategic watch items — not bugs. Full direction: [WORLD_DIRECTION.md](WORLD_DIRECTION.md).

### World scope creep / huge empty map boredom

Status: Watch
Area: World / Product direction
Why it matters:
- The game should feel large because POIs and shops are interesting, not because players walk minutes across empty desert.
- "Full map expansion" is the wrong goal; prefer dense connected POI zones and social town density.
Recommended next action:
- Any world work should pass the feature filter: does it improve weird item discovery, stock decisions, or shop stories?

### Player scattering if main shops relocate freely

Status: Watch
Area: Multiplayer / Shop plots
Why it matters:
- If every player can move their main shop anywhere, the hub dies and new players see emptiness.
- Main identity stays the **town pawn shop**; far-future outposts supplement, not replace.
Recommended next action:
- Keep outposts and remote stalls as supplements in design docs until explicitly scoped.

### Early player trading economy

Status: Watch
Area: Social / Economy
Why it matters:
- Player-to-player trading creates exploit surfaces and balancing problems before the core shop loop is proven.
- Socialization should come from visible shops, shared POIs, events, and convoys — not trading.
Recommended next action:
- Do not add player trading unless explicitly requested after economy is stable.

### Freeform building scope risk

Status: Watch
Area: Building / Shop customization
Why it matters:
- Bloxburg-style freeform building is out of scope; anchor/slot Build Mode keeps shops readable and hard to exploit.
Recommended next action:
- New buildables use valid placement zones and server-authoritative slot IDs.

### Vehicles as empty travel padding

Status: Watch
Area: Vehicles / World
Why it matters:
- Vehicles should be haulers, status, and short travel — not mandatory long commutes or the main progression system.
Recommended next action:
- Tie vehicle tiers to bag capacity and POI friction, not map size.

### ScavengeNodes name confusion vs real POIs

Status: Watch
Area: Hub / Outside / Scavenging
Why it matters:
- `World.Outside.ScavengeNodes` now hosts **Scavenge Node V0** nodes — server-authoritative finds, not POI runs. Future connected POIs are a separate system (see WORLD_DIRECTION.md).
Recommended next action:
- Do not expand to multi-node / POI scavenging without a deliberate design pass.

### Scavenge use limit is session-only (V0 prototype)

Status: Known limitation
Area: Scavenge / Shift
Why it matters:
- Scavenge Node V0 allows successful searches per node per scavenge window. The window token and node use counts are in-memory only (bumps on shift start/end). **Rejoining may reset the limit.** This is intentional prototype debt, not final per-shop-day design.
Recommended next action:
- Ship a persisted per-day counter only after V0 proves the loop is fun.

### BasicJunk only; Scavenge Nodes are not POIs

Status: Known limitation
Area: Scavenge
Why it matters:
- V0 supports duplicated junk-pile nodes, but they still use the same `BasicJunk` table. This is not a POI system, vehicles, bags, tools, or minigames.
Recommended next action:
- Expand only after smoke-test acceptance criteria pass in Studio.

### HubPickup decorative economy disabled

Status: Intentional V0
Area: Hub pickups
Why it matters:
- `HubPickups.Enabled = false` — no spawn loop, no fake "Dropped in Storage" or holding UI while scavenging is live.
Recommended next action:
- Re-enable only with a deliberate inventory/display relationship.

### Teleport / menu fragmentation vs connected town

Status: Watch
Area: World / POIs
Why it matters:
- Normal scavenging should stay in the connected server world; separate Roblox places are for rare instanced expeditions only.
- Menu-teleport to "dungeon #4" kills social density and shop visibility.
Recommended next action:
- Default POI access via roads/gates from the shared town.

---

## Medium

Issues that hurt testing, confuse players, or create inconsistent behavior.

### Hybrid Counter Presentation — missing Studio anchors

Status: Watch
Area: Counter presentation / Camera
Risk: Without `DealCameraSpot` and `CounterLookAt` under `Workspace.World.Shop`, client falls back to legacy deal UI and normal camera.
Notes:
- Optional look targets (`SellShelfLookAt`, `DisplayShelfLookAt`, `StorageLookAt`) are silent fallbacks.
- For buyer-visit shelf framing, place `SellShelfLookAt` near `Workspace.World.Shop.Shelf` (canonical public shelf). Client falls back to `Shelf` / `ShelfSlot1` geometry when look targets are missing.
- For storage camera assist, place `StorageLookAt` (or legacy `StashBinLookAt`) near the Storage bin. Client falls back to `StorageBin` / `StashBin` geometry when the anchor is missing.
- Optional `PlayerCounterSpot` improves explore-mode shopkeeper camera framing (player centered at counter); falls back to live character position when missing.
- Ctrl+U debug overlay can toggle **Legacy Deal UI** for A/B testing in Studio.
Possible Fix:
- Place required presentation anchors in Studio; use debug world scan to verify.

### Shopkeeper camera + player movement

Status: Watch
Area: Camera / Controls
Risk: Scriptable shopkeeper camera with movement enabled may feel disorienting for some players.
Notes:
- Mouse pan is intentionally conservative (small yaw/pitch clamps).
- Buyer visit uses dedicated `BuyerVisit` camera mode (wider pan, shelf bias) so public shelf items stay in frame.
- Camera restores `Custom` on shop close, fallback, error, and respawn.
Possible Fix:
- Tune `ClientPresentation` pan values after PC playtest.

---

## Low

Cosmetic bugs, minor UX issues, cleanup tasks.

### Hub decorative pickups — ScavengeNodes vs JunkLot

Status: Watch
Area: Hub pickups / Outside
Notes:
- `HubPickupController` prefers `World.Outside.ScavengeNodes` for spawn parent lookup, then falls back to legacy `Outside.JunkLot`.
- Decorative hub pickups stay disabled; Scavenge Node V0 uses `ScavengeNodes` for server-known junk piles, not client-only pickup spawn rewards.
- Scavenge Node V0 uses direct `ScavengeNodes` children with `ScavengePromptPart`; decorative HubPickup spawns remain disabled and separate.

---

## Security / Exploit Risks

Things where a client might be able to call a remote incorrectly, duplicate state, bypass server checks, or create invalid item routing.

### Client-called debug actions

Status: Watch
Area: Debug tools / Remotes
Risk: Debug actions could become dangerous if allowlist or server gates regress.
Notes:
- `DebugAccess.lua` is server-only (`Server/Config/DebugAccess.lua`). Never replicate `Users` to clients.
- `DebugGetAccess` returns derived permissions for the caller only; `DebugRunAction` checks `DebugAccess.canRunDebugAction` on every action.
- `EnabledInLive` never grants public access — live DevTools require `Users[player.UserId]`.
- `StudioBypass` applies only when `RunService:IsStudio()`.
- Owner role sees hidden economy fields; tester role does not (`canViewHiddenEconomy`).
- `SetScraps` is owner-only, self-only, number-only, clamped `0..999_999`.
Possible Fix:
- Keep server write gates on every debug path (DebugService + InventoryService + DataService + DealService + ShiftService).
- Never trust client-side DevTools UI gating alone.

### Live DevTools overlay V1

Status: Fixed
Area: Debug UI
Notes:
- Ctrl+U opens a tabbed DevTools panel for allowlisted users (`DebugGetAccess` bootstrap).
- Non-allowlisted players get no overlay and no Ctrl+U handler.
- Panel supports drag (viewport clamp), resize, collapse, and tabs: Overview, Shop Day, Shelf, Deal, Persistence, Camera, Actions, Log.
- Dangerous actions are role-gated; testers get operational read-only state without hidden economy math.

### Shelf / Storage item sale protection

Status: Fixed (Public Shelves V1)
Area: BuyerVisit / Shelf
Risk: Storage items should never be offerable; only public Shelf items should be sellable.
Notes:
- Server accepts `SelectInventoryItemForBuyer` only when `location == "display"` (player-facing: Shelf).
- Storage (`stash`) is rejected.

### Storage routing during buyer phases

Status: Watch
Area: Storage / Remotes
Risk: Moving items while a buyer offer list is active could stale the UI or offer a moved item.
Notes:
- Stash V1 blocks stash/display routing during `BuyerVisit` and `Selling`.
Possible Fix:
- Keep route remotes server-authoritative and refresh buyer matches after future routing expansions.

---

## Technical Debt

Code that works now but may become painful later.

### Debug overlay can grow too large

Status: Fixed (Live DevTools V1)
Area: Debug UI
Notes:
- DevTools panel uses tabs (Overview, Shop Day, Shelf, Deal, Persistence, Camera, Actions, Log) instead of one scrolling dump.

### DealService responsibility growth

Status: Watch
Area: DealService / Architecture
Why it matters:
- `DealService` sits on buyer visits, seller flow, haggling, payouts, rare walk-ins, debug-facing state adaptation, and onboarding event hooks that fire from deal flow.
- `ShiftService` owns onboarding hint routing; both services still absorb cross-cutting prototype features.
- If unrelated features keep landing there, it becomes hard to change safely.
Current impact:
- Work is still possible, but each new feature risks increasing the blast radius of deal-flow edits.
Recommended next action:
- Do not rewrite it immediately. When a boundary stabilizes, extract one slice at a time, such as buyer visit scheduling, buyer matching, haggle resolution, payout building, or debug adaptation.
Fixed when:
- New feature work can avoid unrelated `DealService` edits, and at least one stable responsibility has moved behind a small helper or service without changing player behavior.

### Persistent shop state is narrow

Status: Improved / Watch
Area: Shelf / Storage / Persistence
Why it matters:
- The long-term fantasy depends on saving something for the perfect future buyer.
- Persistent Shop State V1 now supports trust, but it is still not a full progression system.
Current impact:
- Scraps, 2 **Storage** slots (internal `stash`), and **Shelf** items/positions (internal `display`) persist.
- Legacy `inventory` working stock, hub pickups, collection goals, relics, upgrades, and broader decoration state do not persist.
Recommended next action:
- Playtest whether players understand **Storage** / **Shelf** permanence and that unsold legacy stock is temporary.
Fixed when:
- Returning players can explain what is saved, what is temporary, and why they care about at least one saved item or scraps goal.

### Persistence save-frequency pressure

Status: Watch
Area: InventoryService / DataService / Persistence
Why it matters:
- `InventoryService:_markPersistentDirty` spawns an immediate `DataService:savePlayer` on every Shelf/Storage route change.
- Frequent shelf moves during playtests could hit DataStore write limits or add server load.
Current impact:
- Intentional for trust (route changes should not be lost on crash), but not batched or debounced.
Recommended next action:
- Audit save call volume before larger live playtests; consider debounced saves only after measuring real traffic.
Fixed when:
- Save frequency is measured in playtests and either accepted with documented limits or batched without losing route-change durability.

### Shelf focus camera edge cases

Status: Watch
Area: Shelf Focus V0 / Camera / WorldMarkers
Why it matters:
- Shelf focus uses `BasicShelf.Markers.ShelfCameraSpot` / `ShelfLookAt` when present; legacy or derived poses may feel wrong in some Studio layouts.
- Shelf focus and Hybrid Counter Presentation shopkeeper camera are mutually exclusive but both touch `CameraController`.
Current impact:
- Missing markers fall back to legacy names or a derived bounding-box pose (warn-once in Output).
- Entering shelf focus during an open shop day suspends shopkeeper camera and hides the counter overlay; exiting must restore both from the live deal snapshot (BuyerVisit Offer buttons usable immediately).
- Entering seller **Haggling** or **Selling** force-exits shelf focus.
- Closing the shop while in shelf focus force-exits focus and restores the player camera (shift-end lifecycle).
- Exiting shelf focus then closing the shop restores third-person camera instead of replaying a stale Scriptable shelf snapshot.
Recommended next action:
- Place `BasicShelf.Markers` + `ShelfPromptAnchor` in Studio; playtest focus enter/exit during BuyerVisit, exit-then-close-shop, shop close during focus, and around counter deals.
Fixed when:
- Focus camera is stable with hierarchy markers in the target place and restores cleanly on exit, exit-then-shift-end, buyer visit, shop close, and respawn.

### Mobile/touch shelf item selection

Status: Watch
Area: Shelf Focus V0 / Input
Why it matters:
- V0 uses screen-space slot buttons over shelf items; small props, labels, or crowded camera angles may still need touch playtesting.
Current impact:
- Touch and mouse share the same slot-button path; no drag-to-select or Storage focus mode.
Recommended next action:
- Playtest tap accuracy and destination-slot buttons on phone/tablet before assuming mobile-ready shelf management.
Fixed when:
- Players can reliably select shelf items on touch devices or a follow-up adds clearer tap targets.

### Legacy loose marker fallback debt

Status: Open
Area: WorldMarkers / Studio hierarchy
Why it matters:
- Counter, customer, storage, and shelf lookups still fall back to loose `Shop.*` part names when `Counter.Markers` / `CustomerPath` / `Shelves.BasicShelf.Markers` are missing.
Current impact:
- Older places keep working; new places should use the cleaned hierarchy to avoid ambiguous descendant scans.
Recommended next action:
- Migrate Studio to `Shelves.BasicShelf`, `Counter.Markers`, `CustomerPath`, and `Storage.StorageBin` when editing the map.
Fixed when:
- Target place uses hierarchy markers and DevTools camera scan shows `source: hierarchy` or `tag` for shelf focus.

### Shelf reordering V0 limits

Status: Watch
Area: Shelf Focus / Product scope
Why it matters:
- Shelf order matters now because Shelf positions persist and contribute to shop identity.
Current impact:
- Shelf Focus supports empty-slot moves and Shelf-item swaps while the shop is closed.
- V0 does not support drag-and-drop, Storage focus, or reordering during an open shop day.
Recommended next action:
- Playtest whether click-to-move/click-to-swap is enough before adding drag behavior or a broader Shelf/Storage management mode.
Fixed when:
- Players can arrange saved Shelf items without item loss, accidental adjacent-slot selection, or needing a hidden workaround.

### Storage focus mode not implemented

Status: Intentional (V0)
Area: Storage / Product scope
Notes:
- Storage still uses the existing bin prompt and overlay UI. No storage focus camera in this slice.

---

## Design Risks

Systems that may become confusing, too complex, or conflict with the core design.

### Weak return loop

Status: Open
Area: Retention / Progression
Why it matters:
- Roblox players need a reason to come back that is clearer than "play the same shift again."
- The strongest fantasy is saving prep for a better shop day — **Storage**, **Shelf**, and traffic timing — not re-selecting the same traffic window.
Current impact:
- Traffic Board, **Shelf**, and 2-slot permanent **Storage** now create a small durable return reason.
- The game still lacks collection, reputation, upgrades, or other longer-term goals.
Recommended next action:
- Playtest Persistent Shop State V1, then decide whether the next return hook should be collection log, permanent goals, or shop identity.
Fixed when:
- Returning players have a saved goal that makes them want to open another shop day, such as a kept item, currency target, or small collection objective.

### Shift/traffic selection feels like repeated mission select

Status: Open
Area: Traffic Board / Product direction
Why it matters:
- Current Traffic Board is a prototype picker; product direction is open/close shop days with variable traffic.
Current impact:
- Open Shop / Shop Day Variables V1 improves player-facing copy and adds compact server-owned forecasts, but the board can still feel menu-like until playtests prove players read it as preparation.
Recommended next action:
- Playtest whether Open Shop, Shop Closed, and compact forecast/result copy make the board feel like preparation instead of mission select.
Fixed when:
- Player-facing flow reads as preparing and opening the shop, not picking a mission from a menu.

### Shop-day variance may read as randomness without agency

Status: Watch
Area: Shop-day variables / Prep
Why it matters:
- Variables must tie to readable prep (**Shelf** / **Storage** / legacy inventory) and forecast hints, not pure RNG punishment.
Current impact:
- Shop Day Variables V1 lightly changes buyer demand and seller flow using visible forecasts, while risk remains informational. The system still needs playtesting to prove it feels fair instead of random.
Recommended next action:
- Watch whether players can connect forecast lines, **Shelf** choices, buyer visits, and the Shop Closed summary without seeing hidden weight math.
Fixed when:
- Players can explain why today felt different and what they could have done differently.

### Open/close shop framing must not overclaim

Status: Intentional
Area: Docs / UI / Product honesty
Why it matters:
- Docs and UI must not imply real-time calendar, full open/close simulation, collection, upgrades, or a full decoration editor are built.
Current impact:
- Prototype still uses internal "shift" code; Traffic Board V1 is session-only. Persistent Shop State V1 is real but narrow.
Recommended next action:
- Use open/close language for direction; label prototype reality honestly.
Fixed when:
- No player-facing surface claims daily reset, calendar, collection, relics, shop upgrades, or full decoration persistence without a shipped milestone.

### Traffic Board could become skip/wait exploit surface

Status: Watch
Area: Traffic Board / Forecast
Why it matters:
- Forecast/prep must not reward waiting out "bad" boards without playing the shop.
Current impact:
- Board advances after meaningful progress, but re-roll temptation may grow as options multiply.
Recommended next action:
- Tie board advance to shop-day outcomes; avoid free re-rolls without cost.
Fixed when:
- Players cannot farm better traffic by stalling without engaging the shop loop.

### First shop-day clarity is not proven

Status: Watch
Area: Onboarding / First session
Why it matters:
- If a new player does not understand where to go, what to buy, or why buyers matter, later retention systems only save confusion.
Current impact:
- First Shift Onboarding V1 now gives a session-only normal-day traffic lesson, but it still needs fresh-player playtesting.
Recommended next action:
- Playtest with a fresh player on desktop and mobile-sized screens; tighten only confusing steps.
Fixed when:
- A new player can start, buy or pass, sell one item, and understand the result without external explanation.

### Session-only onboarding repeats

Status: Intentional
Area: Onboarding / Persistence
Why it matters:
- First Shift Onboarding V1 does not use DataStores, so a returning player may see the first-lesson guidance again after rejoin or server reset.
Current impact:
- This is acceptable for V1 because saving onboarding completion is still out of scope, but it could feel repetitive later.
Recommended next action:
- Keep the guidance short and non-blocking until permanent player data exists.
Fixed when:
- A future persistence milestone can remember onboarding completion without adding DataStores prematurely.

### Mobile and onboarding viability

Status: Watch
Area: UI / Input / First session
Why it matters:
- Roblox retention depends heavily on mobile readability and fast comprehension.
Current impact:
- The current UI works for desktop testing, but mobile comfort and first-shift input flow are not proven.
Recommended next action:
- Test the first shop day on mobile-sized screens and simplify the highest-friction controls before adding more feature layers.
Fixed when:
- A mobile player can complete the first shop day without fighting small buttons, overlapping text, or unclear prompts.

### Shelf / Storage between-shift routing

Status: Intentional (Public Shelves V1)
Area: Shelf / Storage / UX
Risk: Players may expect full after-hours management before the shop is open.
Notes:
- Public Shelf props remain visible after shift end; world prompts disable until the next shift starts.
- A client bug previously cleared shelf props on close; fixed in DisplayShelfPresentationController (props persist, prompts only).
- Storage overlay allows Shelf ↔ Storage between shifts.
- Buys land directly on the Shelf; there is no separate working-stock shelf in V1.
Possible Fix:
- Add fuller after-hours routing only when that design is ready.

### Persistence depends on DataStore availability

Status: Watch
Area: Persistence / Studio testing
Why it matters:
- Persistent Shop State V1 is the first trust-building save layer; silent save loss would be worse than no persistence.
Current impact:
- Load/save calls are guarded with `pcall`.
- Stash/display route changes now request an immediate save, and player leave cleanup defers inventory clearing until after save attempts.
- If load fails or a future save version is detected, saving is disabled for that session to avoid overwriting unknown data with fallback defaults.
- Studio tests require API Services enabled to verify real saves.
Recommended next action:
- Test fresh load, rejoin, failed API, and Reset Save Data paths before playtests.
Fixed when:
- Ctrl+U clearly reports load/save status during Studio and live read-only testing, and failure modes do not overwrite existing saves or crash the session.

### Rare buyer pacing may feel noisy

Status: Watch
Area: Rare Buyer Walk-In / Shift pacing
Risk: Extra buyers could make shifts feel too generous or interrupt seller rhythm if the chance is too high.
Notes:
- V1 is capped at one rare buyer per shift and only checks during Buying when **Shelf** stock exists.
- Rare buyers are session-only prototype behavior, not calendar events or persistence.
Possible Fix:
- Tune chance, pools, or per-shift caps after playtesting.

## Recently Resolved

Move fixed issues here instead of deleting them immediately.

### Stash/display could save empty on leave

Status: Fixed
Area: Persistence / InventoryService / DataService
Notes:
- Inventory cleanup could race the final save provider and make the save path see an empty shop.
- InventoryService now saves before cleanup, defers clearing the player inventory, and stash/display route changes request immediate saves.

### Onboarding documented but not active in runtime

Status: Fixed
Area: Onboarding / ShiftService / DealService / UI
Notes:
- The current checkout had First Shift Onboarding V1 described in docs, but no runtime onboarding hooks.
- Session-only onboarding state now recommends Scrap Rush, uses the existing Nervous Rookie / Copper Wire Bundle / Safe Flip lesson, and queues a normal scheduled buyer after the first purchase.

### Live Ctrl+U debug overlay was unavailable

Status: Superseded (Live DevTools V1)
Area: Debug UI
Notes:
- Ctrl+U now opens allowlist-gated DevTools via `DebugGetAccess` (owners `86845593`, `87696934` in V1 config).
- See **Live DevTools overlay V1** under Security / Exploit Risks.

### No-progress shift end advanced Traffic Board

Status: Fixed
Area: Traffic Board / ShiftService
Notes:
- Traffic Board advancement now requires meaningful shift progress.
- Meaningful progress uses existing shift state: seller progress, Closing Rush buyer progress, profit, or liquidation from working inventory.
- No-progress shift endings leave the current traffic board in place and expose the skipped advancement only in snapshots/debug.

### Legacy shift buttons skipped Demand Preview

Status: Fixed
Area: Traffic Board / UI
Notes:
- Removed the hidden deal-panel quick-start buttons and old `onStartShift` callback.
- Client shift start now flows through the Traffic Board selector path.

### Traffic window bypass via stale start paths

Status: Fixed
Area: Traffic Board / ShiftService
Notes:
- No old quick-start buttons or `onStartShift` handler remain in the client.
- `StartShift` now rejects known shifts that are not available on the current traffic board.

### Display items wiped during shift end

Status: Fixed (Session Display Persistence V1)
Area: Inventory / Display / Shift
Notes:
- `startShiftInventory` now preserves `location == "display"` entries.
- `liquidateRemainingInventory` uses `getInventoryItems` only.
- Display shelf props follow `displayItems`, not `shift.active`.

### Deal diagnostics moved to Ctrl+U overlay

Status: Fixed
Area: Debug UI / DealService
Notes:
- `[WastelandPawn]` DEAL START/DONE/TACTIC Output prints removed.
- Archetype, pricing, tactic debug, and buyer influence bonus now show in the debug overlay.

### Prompt mode conflict during BuyerVisit

Status: Fixed
Area: InventoryShelf prompts
Notes:
- InventoryShelf prompts now carry a prompt generation and slot index.
- Stale prompt triggers are ignored when BuyerVisit / normal shelf mode changes.
- Server validation still rejects non-inventory buyer offers.

---

## How to update this file

At the end of major feature work, review whether to add or update entries.

Update this file when you find:

- confirmed bugs
- likely bugs
- remote validation risks
- item duplication risks
- money duplication risks
- stale prompt or UI state risks
- confusing design behavior
- code that should be refactored later

Keep entries short. Use **Watch** or **Risk** unless confirmed. Move fixed issues to **Recently Resolved** instead of deleting them.

For strategic risks, include:

- why it matters
- current impact
- recommended next action
- what would prove it is fixed

Do not:

- turn this into a huge issue tracker system
- add generated timestamps on every entry
- invent fake bugs
- duplicate roadmap tasks from `ROADMAP.md`
- write long essays
