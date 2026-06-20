# Known Issues

Living notes for bugs, technical debt, possible exploits, risky systems, and cleanup tasks.
Keep entries short. Add enough context that future us knows what happened.

---

## Critical

Issues that can corrupt state, break core gameplay, duplicate items/money, or allow exploits.

No current critical issues tracked.

---

## Medium

Issues that hurt testing, confuse players, or create inconsistent behavior.

---

## Low

Cosmetic bugs, minor UX issues, cleanup tasks.

---

## Security / Exploit Risks

Things where a client might be able to call a remote incorrectly, duplicate state, bypass server checks, or create invalid item routing.

### Client-called debug actions

Status: Watch
Area: Debug tools / Remotes
Risk: Debug actions could become dangerous if accidentally enabled outside Studio.
Notes:
- `DebugRunAction` must remain server-gated with `RunService:IsStudio()`.
Possible Fix:
- Keep client and server gates.
- Never trust client-side debug UI gating alone.

### Display/stash item sale protection

Status: Watch
Area: BuyerVisit / Inventory
Risk: DisplayShelf and stash items should never be offerable or sellable unless returned to InventoryShelf first.
Possible Fix:
- Server should reject `SelectInventoryItemForBuyer` unless `location == "inventory"`.

### Stash routing during buyer phases

Status: Watch
Area: Stash / Remotes
Risk: Moving items while a buyer offer list is active could stale the UI or offer a moved item.
Notes:
- Stash V1 blocks stash/display routing during `BuyerVisit` and `Selling`.
Possible Fix:
- Keep route remotes server-authoritative and refresh buyer matches after future routing expansions.

---

## Technical Debt

Code that works now but may become painful later.

### Debug overlay can grow too large

Status: Open
Area: Debug UI
Risk: One huge scrolling debug panel may get hard to read as systems grow.
Possible Fix:
- Split into tabs later: Shift, Deal, Inventory, World, Prompts, Actions.

### DealService responsibility growth

Status: Watch
Area: DealService / Architecture
Why it matters:
- `DealService` sits on buyer visits, seller flow, haggling, payouts, rare walk-ins, and debug-facing state.
- If unrelated features keep landing there, it becomes hard to change safely.
Current impact:
- Work is still possible, but each new feature risks increasing the blast radius of deal-flow edits.
Recommended next action:
- Do not rewrite it immediately. When a boundary stabilizes, extract one slice at a time, such as buyer visit scheduling, buyer matching, haggle resolution, payout building, or debug adaptation.
Fixed when:
- New feature work can avoid unrelated `DealService` edits, and at least one stable responsibility has moved behind a small helper or service without changing player behavior.

### Persistent shop state is narrow

Status: Improved / Watch
Area: Display / Stash / Persistence
Why it matters:
- The long-term fantasy depends on saving something for the perfect future buyer.
- Persistent Shop State V1 now supports trust, but it is still not a full progression system.
Current impact:
- Scraps, 2 Stash slots, and DisplayShelf items/positions persist.
- InventoryShelf working stock, hub pickups, collection goals, relics, upgrades, and broader decoration state do not persist.
Recommended next action:
- Playtest whether players understand Stash/Display permanence and InventoryShelf temporariness.
Fixed when:
- Returning players can explain what is saved, what is temporary, and why they care about at least one saved item or scraps goal.

---

## Design Risks

Systems that may become confusing, too complex, or conflict with the core design.

### Weak return loop

Status: Open
Area: Retention / Progression
Why it matters:
- Roblox players need a reason to come back that is clearer than "play the same shift again."
- The strongest fantasy is saving prep for a better shop day — stash, display, and traffic timing — not re-selecting the same traffic window.
Current impact:
- Traffic Board, DisplayShelf, and 2-slot permanent Stash now create a small durable return reason.
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
- Players may feel they are choosing the same static mode repeatedly instead of running a shop.
Recommended next action:
- Reframe board as forecast/prep; evolve toward open shop → variable day → close shop.
Fixed when:
- Player-facing flow reads as preparing and opening the shop, not picking a mission from a menu.

### Shop-day variance may read as randomness without agency

Status: Watch
Area: Shop-day variables / Prep
Why it matters:
- Variables must tie to readable prep (display/stash/inventory) and forecast hints, not pure RNG punishment.
Current impact:
- Traffic conditions and rare walk-ins exist but prep-to-outcome links are still thin.
Recommended next action:
- Strengthen Demand Preview and display influence readability before adding more variance layers.
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

### Display/stash between-shift routing is limited

Status: Intentional
Area: Display / Stash / UX
Risk: Players may expect full after-hours inventory management before the shop is open.
Notes:
- V1 shows display props after shift end but disables Return to Shelf prompts until the next shift starts.
- StashBin overlay allows Stash <-> Display between shifts.
- Pulling stashed items to InventoryShelf still requires an active shift.
Possible Fix:
- Add fuller after-hours inventory routing only when that design is ready.

### Persistence depends on DataStore availability

Status: Watch
Area: Persistence / Studio testing
Why it matters:
- Persistent Shop State V1 is the first trust-building save layer; silent save loss would be worse than no persistence.
Current impact:
- Load/save calls are guarded with `pcall`.
- If load fails or a future save version is detected, saving is disabled for that session to avoid overwriting unknown data with fallback defaults.
- Studio tests require API Services enabled to verify real saves.
Recommended next action:
- Test fresh load, rejoin, failed API, and Reset Save Data paths before playtests.
Fixed when:
- Ctrl+U clearly reports load/save status during Studio testing, and failure modes do not overwrite existing saves or crash the session.

### Rare buyer pacing may feel noisy

Status: Watch
Area: Rare Buyer Walk-In / Shift pacing
Risk: Extra buyers could make shifts feel too generous or interrupt seller rhythm if the chance is too high.
Notes:
- V1 is capped at one rare buyer per shift and only checks during Buying when working inventory exists.
- Rare buyers are session-only prototype behavior, not calendar events or persistence.
Possible Fix:
- Tune chance, pools, or per-shift caps after playtesting.

## Recently Resolved

Move fixed issues here instead of deleting them immediately.

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
