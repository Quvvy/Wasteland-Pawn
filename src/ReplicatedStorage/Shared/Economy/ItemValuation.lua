local Rarities = require(script.Parent.Parent.Config.Rarities)
local HaggleTuning = require(script.Parent.Parent.Config.HaggleTuning)
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

	local spread = HaggleTuning.estimateSpreadBase
		- knowledge * HaggleTuning.estimateSpreadKnowledge
		+ scamBias * HaggleTuning.estimateSpreadScam
	spread = math.clamp(spread, HaggleTuning.estimateSpreadMin, HaggleTuning.estimateSpreadMax)

	local inflate = scamBias * random:NextNumber(HaggleTuning.scamInflateMin, HaggleTuning.scamInflateMax)
	local center = trueValue * (1 + inflate)
	local low = clamp(center * (1 - spread), 1, 999999)
	local high = clamp(center * (1 + spread), low, 999999)

	return low, high
end

function ItemValuation.isEstimateInflated(estimatedLow: number, estimatedHigh: number, trueValue: number): boolean
	local mid = (estimatedLow + estimatedHigh) / 2
	return mid > trueValue * (1 + HaggleTuning.inspectInflatedThreshold)
end

function ItemValuation.narrowEstimateAfterInspect(estimatedLow: number, estimatedHigh: number, trueValue: number): (number, number)
	local targetLow = clamp(trueValue * HaggleTuning.inspectNarrowLowRatio, 1, 999999)
	local targetHigh = clamp(trueValue * HaggleTuning.inspectNarrowHighRatio, targetLow, 999999)
	local newLow = clamp(math.max(estimatedLow, targetLow), 1, 999999)
	local newHigh = clamp(math.min(estimatedHigh, targetHigh), newLow, 999999)

	if newLow >= newHigh then
		return targetLow, targetHigh
	end

	return newLow, newHigh
end

function ItemValuation.getInspectHint(
	rarityId: string,
	trueValue: number,
	customer,
	estimatedLow: number?,
	estimatedHigh: number?
): string
	local rarity = Rarities[rarityId]
	local hint

	if rarityId == "Legendary" or rarityId == "Epic" then
		hint = "Inspection: big opportunity — this could be worth a lot."
	elseif rarityId == "Rare" then
		hint = "Inspection: solid find. Could turn a good profit."
	elseif rarityId == "Uncommon" then
		hint = "Inspection: decent salvage, not trash."
	elseif trueValue < 30 then
		hint = "Inspection: low-tier junk. Don't overpay."
	else
		hint = "Inspection: ordinary stock. Play it safe or skip."
	end

	if
		customer
		and estimatedLow
		and estimatedHigh
		and ItemValuation.isEstimateInflated(estimatedLow, estimatedHigh, trueValue)
	then
		hint ..= " Seller's estimate looks inflated — they may be bluffing."
	end

	return hint
end

return ItemValuation
