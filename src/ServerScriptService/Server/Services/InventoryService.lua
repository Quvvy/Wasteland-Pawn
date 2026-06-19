local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local DisplayInfluence = require(Shared.Economy.DisplayInfluence)
local ObjectModel = require(Shared.Util.ObjectModel)

local InventoryService = {}

local DEFAULT_MAX_SLOTS = 3
local DEFAULT_DISPLAY_SLOTS = 3
local DEFAULT_STASH_SLOTS = 6

local LOCATION_INVENTORY = ObjectModel.Locations.Inventory
local LOCATION_DISPLAY = ObjectModel.Locations.Display
local LOCATION_STASH = ObjectModel.Locations.Stash

local inventories: { [Player]: { items: { any }, maxSlots: number, displayMaxSlots: number, stashMaxSlots: number } } = {}
local nextInstanceId = 0

function InventoryService:Init()
	Remotes.setup()

	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

function InventoryService:Start() end

function InventoryService:_nextInstanceId(): string
	nextInstanceId += 1
	return `item_{nextInstanceId}`
end

function InventoryService:_ensureInventory(player: Player)
	local inventory = inventories[player]
	if not inventory then
		inventory = {
			items = {},
			maxSlots = DEFAULT_MAX_SLOTS,
			displayMaxSlots = DEFAULT_DISPLAY_SLOTS,
			stashMaxSlots = DEFAULT_STASH_SLOTS,
		}
		inventories[player] = inventory
	end
	if inventory.displayMaxSlots == nil then
		inventory.displayMaxSlots = DEFAULT_DISPLAY_SLOTS
	end
	if inventory.stashMaxSlots == nil then
		inventory.stashMaxSlots = DEFAULT_STASH_SLOTS
	end
	return inventory
end

function InventoryService:_itemLocation(entry): string
	return ObjectModel.normalizeLocation(entry.location)
end

function InventoryService:_serializeItem(entry)
	return ObjectModel.serializeForInventorySnapshot(entry)
end

function InventoryService:_pushState(player: Player)
	(Remotes.get("InventoryStateUpdate") :: RemoteEvent):FireClient(player, self:getSnapshot(player))
end

function InventoryService:pushSnapshot(player: Player)
	self:_pushState(player)
end

function InventoryService:startShiftInventory(player: Player, maxSlots: number?)
	local existing = inventories[player]
	local preservedItems = {}
	local displayMaxSlots = DEFAULT_DISPLAY_SLOTS
	local stashMaxSlots = DEFAULT_STASH_SLOTS

	if existing then
		displayMaxSlots = existing.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
		stashMaxSlots = existing.stashMaxSlots or DEFAULT_STASH_SLOTS
		for _, entry in existing.items do
			local location = self:_itemLocation(entry)
			if not entry.disposed and (location == LOCATION_DISPLAY or location == LOCATION_STASH) then
				table.insert(preservedItems, entry)
			end
		end
	end

	inventories[player] = {
		items = preservedItems,
		maxSlots = maxSlots or DEFAULT_MAX_SLOTS,
		displayMaxSlots = displayMaxSlots,
		stashMaxSlots = stashMaxSlots,
	}
	self:_pushState(player)
end

function InventoryService:addPurchasedItem(player: Player, entry)
	if not self:canAdd(player) then
		return nil
	end

	local inventory = self:_ensureInventory(player)
	local list = inventory.items
	entry.instanceId = entry.instanceId or self:_nextInstanceId()
	ObjectModel.normalizeOwnedObject(entry)
	entry.location = LOCATION_INVENTORY
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = nil
	table.insert(list, entry)
	self:_pushState(player)
	return entry.instanceId
end

function InventoryService:getOwnedItem(player: Player, instanceId: string)
	local inventory = inventories[player]
	if not inventory then
		return nil
	end

	for _, entry in inventory.items do
		if entry.instanceId == instanceId and not entry.disposed then
			return entry
		end
	end

	return nil
end

function InventoryService:setItemHeldBack(player: Player, instanceId: string, heldBack: boolean): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	entry.heldBack = heldBack == true
	self:_pushState(player)
	return true
end

function InventoryService:findFirstEmptyDisplaySlot(player: Player): number?
	local inventory = self:_ensureInventory(player)
	local taken = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_DISPLAY and entry.displaySlotIndex then
			taken[entry.displaySlotIndex] = true
		end
	end

	for slotIndex = 1, inventory.displayMaxSlots do
		if not taken[slotIndex] then
			return slotIndex
		end
	end

	return nil
end

function InventoryService:findFirstEmptyStashSlot(player: Player): number?
	local inventory = self:_ensureInventory(player)
	local taken = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_STASH and entry.stashSlotIndex then
			taken[entry.stashSlotIndex] = true
		end
	end

	for slotIndex = 1, inventory.stashMaxSlots do
		if not taken[slotIndex] then
			return slotIndex
		end
	end

	return nil
end

function InventoryService:moveItemToDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return false
	end

	entry.location = LOCATION_DISPLAY
	entry.heldBack = true
	entry.displaySlotIndex = displaySlotIndex
	entry.stashSlotIndex = nil
	self:_pushState(player)
	return true
end

function InventoryService:returnItemFromDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_DISPLAY then
		return false
	end
	if not self:canAdd(player) then
		return false
	end

	entry.location = LOCATION_INVENTORY
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = nil
	self:_pushState(player)
	return true
end

function InventoryService:moveInventoryItemToStash(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	local stashSlotIndex = self:findFirstEmptyStashSlot(player)
	if not stashSlotIndex then
		return false
	end

	entry.location = LOCATION_STASH
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = stashSlotIndex
	self:_pushState(player)
	return true
end

function InventoryService:returnItemFromStash(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_STASH then
		return false
	end
	if not self:canAdd(player) then
		return false
	end

	entry.location = LOCATION_INVENTORY
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = nil
	self:_pushState(player)
	return true
end

function InventoryService:moveDisplayItemToStash(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_DISPLAY then
		return false
	end

	local stashSlotIndex = self:findFirstEmptyStashSlot(player)
	if not stashSlotIndex then
		return false
	end

	entry.location = LOCATION_STASH
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = stashSlotIndex
	self:_pushState(player)
	return true
end

function InventoryService:moveStashItemToDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_STASH then
		return false
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return false
	end

	entry.location = LOCATION_DISPLAY
	entry.heldBack = true
	entry.displaySlotIndex = displaySlotIndex
	entry.stashSlotIndex = nil
	self:_pushState(player)
	return true
end

function InventoryService:markDisposed(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry then
		return false
	end

	entry.disposed = true
	self:_pushState(player)
	return true
end

function InventoryService:getActiveItems(player: Player): { any }
	-- All non-disposed items (inventory + display). Do not use for liquidation.
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local active = {}
	for _, entry in inventory.items do
		if not entry.disposed then
			table.insert(active, entry)
		end
	end
	return active
end

function InventoryService:getInventoryItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_INVENTORY then
			table.insert(items, entry)
		end
	end
	return items
end

function InventoryService:getDisplayItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_DISPLAY then
			table.insert(items, entry)
		end
	end

	table.sort(items, function(a, b)
		return (a.displaySlotIndex or 0) < (b.displaySlotIndex or 0)
	end)

	return items
end

function InventoryService:getStashItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_STASH then
			table.insert(items, entry)
		end
	end

	table.sort(items, function(a, b)
		return (a.stashSlotIndex or 0) < (b.stashSlotIndex or 0)
	end)

	return items
end

function InventoryService:getCount(player: Player): number
	return #self:getInventoryItems(player)
end

function InventoryService:getDisplayCount(player: Player): number
	return #self:getDisplayItems(player)
end

function InventoryService:getStashCount(player: Player): number
	return #self:getStashItems(player)
end

function InventoryService:getMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.maxSlots
end

function InventoryService:getDisplayMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.displayMaxSlots
end

function InventoryService:getStashMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.stashMaxSlots
end

function InventoryService:canAdd(player: Player): boolean
	return self:getCount(player) < self:getMaxSlots(player)
end

function InventoryService:canAddToDisplay(player: Player): boolean
	return self:getDisplayCount(player) < self:getDisplayMaxSlots(player)
end

function InventoryService:canAddToStash(player: Player): boolean
	return self:getStashCount(player) < self:getStashMaxSlots(player)
end

local function assertStudioDebug(): boolean
	return game:GetService("RunService"):IsStudio()
end

function InventoryService:debugAddInventoryItem(player: Player, itemDef: any): (string?, string?)
	if not assertStudioDebug() then
		return nil, "Debug actions disabled"
	end
	if not itemDef then
		return nil, "No item configured"
	end
	if not self:canAdd(player) then
		return nil, "Inventory full"
	end

	local baseValue = itemDef.baseValue or 10
	local instanceId = self:addPurchasedItem(player, ObjectModel.fromDefinition(itemDef, {
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
	}))
	if not instanceId then
		return nil, "Inventory full"
	end

	return instanceId, itemDef.displayName
end

function InventoryService:debugAddDisplayItem(player: Player, itemDef: any): (string?, string?)
	if not assertStudioDebug() then
		return nil, "Debug actions disabled"
	end
	if not itemDef then
		return nil, "No item configured"
	end
	if not self:canAddToDisplay(player) then
		return nil, "Display shelf full"
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return nil, "Display shelf full"
	end

	local inventory = self:_ensureInventory(player)
	local baseValue = itemDef.baseValue or 10
	local entry = ObjectModel.fromDefinition(itemDef, {
		instanceId = self:_nextInstanceId(),
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
		location = LOCATION_DISPLAY,
		heldBack = true,
		displaySlotIndex = displaySlotIndex,
		stashSlotIndex = nil,
	})
	table.insert(inventory.items, entry)
	self:_pushState(player)
	return entry.instanceId, itemDef.displayName
end

function InventoryService:debugClearWorkingInventory(player: Player): (number, string?)
	if not assertStudioDebug() then
		return 0, "Debug actions disabled"
	end

	local cleared = 0
	for _, entry in self:getInventoryItems(player) do
		if self:markDisposed(player, entry.instanceId) then
			cleared += 1
		end
	end

	return cleared, nil
end

function InventoryService:debugClearDisplay(player: Player): (number, string?)
	if not assertStudioDebug() then
		return 0, "Debug actions disabled"
	end

	local cleared = 0
	for _, entry in self:getDisplayItems(player) do
		if self:markDisposed(player, entry.instanceId) then
			cleared += 1
		end
	end

	return cleared, nil
end

function InventoryService:getSnapshot(player: Player)
	local inventory = self:_ensureInventory(player)
	local items = {}
	local displayBySlot: { [number]: any } = {}
	local stashBySlot: { [number]: any } = {}

	for _, entry in inventory.items do
		if entry.disposed then
			continue
		end

		local location = self:_itemLocation(entry)
		if location == LOCATION_INVENTORY then
			table.insert(items, self:_serializeItem(entry))
		elseif location == LOCATION_DISPLAY and entry.displaySlotIndex then
			displayBySlot[entry.displaySlotIndex] = entry
		elseif location == LOCATION_STASH and entry.stashSlotIndex then
			stashBySlot[entry.stashSlotIndex] = entry
		end
	end

	local displayItems = {}
	local displayUsedSlots = 0
	for slotIndex = 1, inventory.displayMaxSlots do
		local entry = displayBySlot[slotIndex]
		if entry then
			table.insert(displayItems, self:_serializeItem(entry))
			displayUsedSlots += 1
		end
	end

	local stashItems = {}
	local stashUsedSlots = 0
	for slotIndex = 1, inventory.stashMaxSlots do
		local entry = stashBySlot[slotIndex]
		if entry then
			table.insert(stashItems, self:_serializeItem(entry))
			stashUsedSlots += 1
		end
	end

	return {
		maxSlots = inventory.maxSlots,
		usedSlots = #items,
		items = items,
		displayMaxSlots = inventory.displayMaxSlots,
		displayUsedSlots = displayUsedSlots,
		displayItems = displayItems,
		stashMaxSlots = inventory.stashMaxSlots,
		stashUsedSlots = stashUsedSlots,
		stashItems = stashItems,
		displayAppealSummary = DisplayInfluence.summarizeDisplayAppeal(self:getDisplayItems(player)),
	}
end

return InventoryService
