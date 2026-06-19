# Known Issues

Living notes for bugs, technical debt, possible exploits, risky systems, and cleanup tasks.
Keep entries short. Add enough context that future us knows what happened.

---

## Critical

Issues that can corrupt state, break core gameplay, duplicate items/money, or allow exploits.

### Display items wiped during shift end

Status: Watch
Area: Inventory / Display / Shift
Risk: DisplayShelf items may be cleared or liquidated when ending a shift.
Notes:
- `liquidateRemainingInventory` uses `getActiveItems`, which includes all non-disposed items regardless of location.
- Session Display Persistence V1 is planned to make display items survive between shifts.
Possible Fix:
- Ensure liquidation only applies to `location == "inventory"`.

### Prompt mode conflict during BuyerVisit

Status: Watch
Area: InventoryShelf prompts
Risk: A shelf prompt could trigger both Offer and Hold Back behavior if stale callbacks survive phase changes.
Notes:
- BuyerVisit should only show Offer prompts.
- Outside BuyerVisit should only show Hold Back prompts.
Possible Fix:
- Rebuild prompts on phase changes and keep server validation strict.

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

### Display item sale protection

Status: Watch
Area: BuyerVisit / Inventory
Risk: DisplayShelf items should never be offerable or sellable unless returned to InventoryShelf first.
Possible Fix:
- Server should reject `SelectInventoryItemForBuyer` for `location == "display"`.

---

## Technical Debt

Code that works now but may become painful later.

### Debug overlay can grow too large

Status: Open
Area: Debug UI
Risk: One huge scrolling debug panel may get hard to read as systems grow.
Possible Fix:
- Split into tabs later: Shift, Deal, Inventory, World, Prompts, Actions.

### Session display is not permanent

Status: Intentional
Area: Display / Persistence
Risk: Players may expect display items to survive rejoin/server reset later.
Notes:
- For now this is session-only. Do not add DataStores yet.
Possible Fix:
- Add real persistence only after stash/display/collection design is clearer.

---

## Design Risks

Systems that may become confusing, too complex, or conflict with the core design.

---

## Recently Resolved

Move fixed issues here instead of deleting them immediately.

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
