local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local DisplayInfluence = require(Shared.Economy.DisplayInfluence)

local InventoryService = {}

local DEFAULT_MAX_SLOTS = 3
local DEFAULT_DISPLAY_SLOTS = 3

local LOCATION_INVENTORY = "inventory"
local LOCATION_DISPLAY = "display"

local inventories: { [Player]: { items: { any }, maxSlots: number, displayMaxSlots: number } } = {}
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
		}
		inventories[player] = inventory
	end
	if inventory.displayMaxSlots == nil then
		inventory.displayMaxSlots = DEFAULT_DISPLAY_SLOTS
	end
	return inventory
end

function InventoryService:_itemLocation(entry): string
	if entry.location == LOCATION_DISPLAY then
		return LOCATION_DISPLAY
	end
	return LOCATION_INVENTORY
end

function InventoryService:_serializeItem(entry)
	return {
		instanceId = entry.instanceId,
		itemId = entry.itemId,
		displayName = entry.displayName,
		dealArchetypeId = entry.dealArchetypeId,
		dealArchetypeName = entry.dealArchetypeName,
		category = entry.category,
		traits = entry.traits or {},
		flavorText = entry.flavorText,
		purchasePrice = entry.purchasePrice,
		estimatedLow = entry.estimatedLow,
		estimatedHigh = entry.estimatedHigh,
		sellerName = entry.sellerName,
		sellerTell = entry.sellerTell,
		heldBack = entry.heldBack == true,
		location = self:_itemLocation(entry),
		displaySlotIndex = entry.displaySlotIndex,
	}
end

function InventoryService:_pushState(player: Player)
	(Remotes.get("InventoryStateUpdate") :: RemoteEvent):FireClient(player, self:getSnapshot(player))
end

function InventoryService:startShiftInventory(player: Player, maxSlots: number?)
	inventories[player] = {
		items = {},
		maxSlots = maxSlots or DEFAULT_MAX_SLOTS,
		displayMaxSlots = DEFAULT_DISPLAY_SLOTS,
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
	entry.heldBack = entry.heldBack == true
	entry.location = LOCATION_INVENTORY
	entry.displaySlotIndex = nil
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

function InventoryService:getCount(player: Player): number
	return #self:getInventoryItems(player)
end

function InventoryService:getDisplayCount(player: Player): number
	return #self:getDisplayItems(player)
end

function InventoryService:getMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.maxSlots
end

function InventoryService:getDisplayMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.displayMaxSlots
end

function InventoryService:canAdd(player: Player): boolean
	return self:getCount(player) < self:getMaxSlots(player)
end

function InventoryService:canAddToDisplay(player: Player): boolean
	return self:getDisplayCount(player) < self:getDisplayMaxSlots(player)
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
	local instanceId = self:addPurchasedItem(player, {
		itemId = itemDef.id,
		displayName = itemDef.displayName,
		category = itemDef.category,
		traits = itemDef.traits or {},
		flavorText = itemDef.flavorText,
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
	})
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
	local entry = {
		instanceId = self:_nextInstanceId(),
		itemId = itemDef.id,
		displayName = itemDef.displayName,
		category = itemDef.category,
		traits = itemDef.traits or {},
		flavorText = itemDef.flavorText,
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
		location = LOCATION_DISPLAY,
		heldBack = true,
		displaySlotIndex = displaySlotIndex,
	}
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

function InventoryService:getSnapshot(player: Player)
	local inventory = self:_ensureInventory(player)
	local items = {}
	local displayBySlot: { [number]: any } = {}

	for _, entry in inventory.items do
		if entry.disposed then
			continue
		end

		if self:_itemLocation(entry) == LOCATION_INVENTORY then
			table.insert(items, self:_serializeItem(entry))
		elseif entry.displaySlotIndex then
			displayBySlot[entry.displaySlotIndex] = entry
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

	return {
		maxSlots = inventory.maxSlots,
		usedSlots = #items,
		items = items,
		displayMaxSlots = inventory.displayMaxSlots,
		displayUsedSlots = displayUsedSlots,
		displayItems = displayItems,
		displayAppealSummary = DisplayInfluence.summarizeDisplayAppeal(self:getDisplayItems(player)),
	}
end

return InventoryService
