local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local InventoryService = {}

local DEFAULT_MAX_SLOTS = 3

local inventories: { [Player]: { items: { any }, maxSlots: number } } = {}
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
		}
		inventories[player] = inventory
	end
	return inventory
end

function InventoryService:_pushState(player: Player)
	(Remotes.get("InventoryStateUpdate") :: RemoteEvent):FireClient(player, self:getSnapshot(player))
end

function InventoryService:startShiftInventory(player: Player, maxSlots: number?)
	inventories[player] = {
		items = {},
		maxSlots = maxSlots or DEFAULT_MAX_SLOTS,
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

function InventoryService:getCount(player: Player): number
	return #self:getActiveItems(player)
end

function InventoryService:getMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.maxSlots
end

function InventoryService:canAdd(player: Player): boolean
	return self:getCount(player) < self:getMaxSlots(player)
end

function InventoryService:getSnapshot(player: Player)
	local inventory = self:_ensureInventory(player)
	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed then
			table.insert(items, {
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
			})
		end
	end

	return {
		maxSlots = inventory.maxSlots,
		usedSlots = #items,
		items = items,
	}
end

return InventoryService
