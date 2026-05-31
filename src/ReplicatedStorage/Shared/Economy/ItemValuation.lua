local Rarities = require(script.Parent.Parent.Config.Rarities)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local ItemValuation = {}

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

function ItemValuation.rollRarity(item, rng: Random?): string
	local weights = Rarities.getRollWeights(item.category)
	local rarityId = TableUtil.pickWeighted(weights, rng)
	return rarityId or "Common"
end

function ItemValuation.calculateTrueValue(item, rarityId: string, rng: Random?): number
	local rarity = Rarities[rarityId] or Rarities.Common
	local random = rng or Random.new()
	local jitter = random:NextNumber(0.92, 1.12)
	return clamp(item.baseValue * rarity.valueMultiplier * jitter, 1, 999999)
end

function ItemValuation.createHiddenOutcome(item, customer, rng: Random?)
	local random = rng or Random.new()
	local rarityId = ItemValuation.rollRarity(item, random)
	local trueValue = ItemValuation.calculateTrueValue(item, rarityId, random)

	return {
		rarityId = rarityId,
		trueValue = trueValue,
	}
end

function ItemValuation.generateEstimatedRange(item, customer, trueValue: number, rng: Random?)
	local random = rng or Random.new()
	local knowledge = customer.knowledge or 0
	local scamBias = customer.scamBias or 0

	local spread = 0.35 - knowledge * 0.15 + scamBias * 0.25
	spread = math.clamp(spread, 0.12, 0.55)

	local center = trueValue * (1 + scamBias * random:NextNumber(0.15, 0.45))
	local low = clamp(center * (1 - spread), 1, 999999)
	local high = clamp(center * (1 + spread), low, 999999)

	return low, high
end

function ItemValuation.narrowEstimateAfterInspect(estimatedLow: number, estimatedHigh: number, trueValue: number): (number, number)
	local mid = (estimatedLow + estimatedHigh) / 2
	local newLow = clamp(math.min(estimatedLow, trueValue * 0.85), 1, 999999)
	local newHigh = clamp(math.max(estimatedHigh, trueValue * 1.15), newLow, 999999)

	if math.abs(mid - trueValue) > trueValue * 0.5 then
		newLow = clamp(trueValue * 0.7, 1, 999999)
		newHigh = clamp(trueValue * 1.3, newLow, 999999)
	end

	return newLow, newHigh
end

function ItemValuation.getInspectHint(rarityId: string, trueValue: number): string
	local rarity = Rarities[rarityId]
	if not rarity then
		return "Your gut says the value is unclear."
	end

	if rarityId == "Legendary" or rarityId == "Epic" then
		return "Inspection: this might be seriously valuable."
	elseif rarityId == "Rare" or rarityId == "Uncommon" then
		return "Inspection: decent find, not trash."
	elseif trueValue < 30 then
		return "Inspection: probably low-tier junk."
	else
		return "Inspection: common salvage at best."
	end
end

return ItemValuation
