local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buyers = require(Shared.Config.Buyers)

local BuyerService = {}

function BuyerService:Init() end

function BuyerService:Start() end

function BuyerService:rollBuyer(rng: Random?)
	return Buyers.getRandom(rng)
end

function BuyerService:getBuyer(buyerId: string)
	return Buyers.get(buyerId)
end

return BuyerService
