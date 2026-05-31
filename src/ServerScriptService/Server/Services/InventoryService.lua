local Players = game:GetService("Players")

local InventoryService = {}

local inventories: { [Player]: { any } } = {}
local nextInstanceId = 0

function InventoryService:Init()
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

function InventoryService:Start() end

function InventoryService:_nextInstanceId(): string
	nextInstanceId += 1
	return `item_{nextInstanceId}`
end

function InventoryService:addPurchasedItem(player: Player, entry)
	local list = inventories[player]
	if not list then
		list = {}
		inventories[player] = list
	end

	entry.instanceId = entry.instanceId or self:_nextInstanceId()
	table.insert(list, entry)
	return entry.instanceId
end

function InventoryService:getOwnedItem(player: Player, instanceId: string)
	local list = inventories[player]
	if not list then
		return nil
	end

	for _, entry in list do
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
	return true
end

function InventoryService:getCount(player: Player): number
	local list = inventories[player]
	if not list then
		return 0
	end

	local count = 0
	for _, entry in list do
		if not entry.disposed then
			count += 1
		end
	end
	return count
end

return InventoryService
