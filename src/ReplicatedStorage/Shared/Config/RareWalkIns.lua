local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buyers = require(Shared.Config.Buyers)
local DisplayInfluence = require(Shared.Economy.DisplayInfluence)
local TableUtil = require(Shared.Util.TableUtil)

local RareWalkIns = {}

RareWalkIns.BASE_CHANCE = 0.15
RareWalkIns.MAX_PER_SHIFT = 1

local RARE_BUYER_WEIGHTS = {
	scrap_rush = {
		rich_collector = 1,
		alien_tourist = 1,
		black_market_dealer = 1,
	},
	collector_convention = {
		alien_tourist = 1,
		black_market_dealer = 1,
		robot_appraiser = 1,
	},
	black_market_night = {
		rich_collector = 1,
		alien_tourist = 1,
		robot_appraiser = 1,
	},
}

local function resolveShiftId(shiftOrId): string?
	if type(shiftOrId) == "string" then
		return shiftOrId
	end
	if type(shiftOrId) == "table" then
		return shiftOrId.shiftId or shiftOrId.id
	end
	return nil
end

function RareWalkIns.getMaxPerShift(_shiftOrId): number
	return RareWalkIns.MAX_PER_SHIFT
end

function RareWalkIns.getChance(_shiftOrId): number
	return RareWalkIns.BASE_CHANCE
end

function RareWalkIns.getBuyerWeights(shiftOrId)
	local shiftId = resolveShiftId(shiftOrId)
	if not shiftId then
		return nil
	end
	return RARE_BUYER_WEIGHTS[shiftId]
end

function RareWalkIns.buildAdjustedBuyerWeights(shiftOrId, displayItems)
	local baseWeights = RareWalkIns.getBuyerWeights(shiftOrId)
	if not baseWeights then
		return nil, {}
	end
	return DisplayInfluence.applyBuyerWeightBonuses(baseWeights, displayItems)
end

function RareWalkIns.shouldTrigger(rng: Random?, shiftOrId): boolean
	local chance = RareWalkIns.getChance(shiftOrId)
	if chance <= 0 then
		return false
	end

	local random = rng or Random.new()
	return random:NextNumber(0, 1) < chance
end

function RareWalkIns.rollBuyer(shiftOrId, rng: Random?, displayItems)
	local adjustedWeights, influenceByBuyerId = RareWalkIns.buildAdjustedBuyerWeights(shiftOrId, displayItems)
	if not adjustedWeights then
		return nil, influenceByBuyerId
	end

	local buyerId = TableUtil.pickWeighted(adjustedWeights, rng)
	local buyer = if buyerId then Buyers.get(buyerId) else nil
	return buyer, influenceByBuyerId
end

return RareWalkIns
