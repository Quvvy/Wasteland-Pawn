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

### Session display/stash is not permanent

Status: Intentional
Area: Display / Stash / Persistence
Risk: Players may expect display or stash items to survive rejoin/server reset later.
Notes:
- Display and stash items now persist across shifts within the same server session.
- Rejoin and server reset still clear display/stash. Do not add DataStores yet.
Possible Fix:
- Add real persistence only after stash/display/collection design is clearer.

---

## Design Risks

Systems that may become confusing, too complex, or conflict with the core design.

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

## Recently Resolved

Move fixed issues here instead of deleting them immediately.

### Legacy shift buttons skipped Demand Preview

Status: Fixed
Area: ShiftBoard / UI
Notes:
- Removed the hidden deal-panel quick-start buttons and old `onStartShift` callback.
- Client shift start now flows through the ShiftBoard selector path.

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

Do not:

- turn this into a huge issue tracker system
- add generated timestamps on every entry
- invent fake bugs
- duplicate roadmap tasks from `ROADMAP.md`
- write long essays
