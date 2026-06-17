local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buyers = require(Shared.Config.Buyers)
local TableUtil = require(Shared.Util.TableUtil)

local BuyerService = {}

local function getValidBuyerWeights(source)
	if type(source) ~= "table" then
		return nil
	end

	local weights = {}
	local hasWeight = false
	for buyerId, weight in source do
		if Buyers.get(buyerId) and type(weight) == "number" and weight > 0 then
			weights[buyerId] = weight
			hasWeight = true
		end
	end

	return if hasWeight then weights else nil
end

function BuyerService:Init() end

function BuyerService:Start() end

function BuyerService:rollBuyer(rng: Random?, buyerWeights)
	local validWeights = getValidBuyerWeights(buyerWeights)
	if validWeights then
		local buyerId = TableUtil.pickWeighted(validWeights, rng)
		local buyer = if buyerId then Buyers.get(buyerId) else nil
		if buyer then
			return buyer
		end
	end

	return Buyers.getRandom(rng)
end

function BuyerService:getBuyer(buyerId: string)
	return Buyers.get(buyerId)
end

return BuyerService
