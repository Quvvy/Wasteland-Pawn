local Players = game:GetService("Players")

local DataService = {}

DataService.STARTING_CASH = 500

local playerData: { [Player]: { cash: number } } = {}

function DataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_ensurePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerData[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_ensurePlayer(player)
	end
end

function DataService:Start() end

function DataService:_ensurePlayer(player: Player)
	if playerData[player] then
		return
	end

	playerData[player] = {
		cash = DataService.STARTING_CASH,
	}
end

function DataService:getCash(player: Player): number
	self:_ensurePlayer(player)
	return playerData[player].cash
end

function DataService:canAfford(player: Player, amount: number): boolean
	return self:getCash(player) >= amount
end

function DataService:spend(player: Player, amount: number): boolean
	if amount < 0 then
		return false
	end

	self:_ensurePlayer(player)
	local data = playerData[player]

	if data.cash < amount then
		return false
	end

	data.cash -= amount
	return true
end

function DataService:addCash(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	self:_ensurePlayer(player)
	playerData[player].cash += amount
end

return DataService
