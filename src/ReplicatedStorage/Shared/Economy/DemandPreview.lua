local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buyers = require(Shared.Config.Buyers)
local Shifts = require(Shared.Config.Shifts)
local BuyerMatch = require(Shared.Economy.BuyerMatch)
local DisplayInfluence = require(Shared.Economy.DisplayInfluence)

local DemandPreview = {}

local MAX_LIKELY_BUYERS = 4
local MAX_GOOD_CATEGORIES = 4
local MAX_GOOD_TRAITS = 5
local MAX_DISPLAY_EFFECTS = 3

local function isPositiveWeight(weight: any): boolean
	return type(weight) == "number" and weight > 0
end

local function collectWeightedBuyers(buyerWeights): { { buyerId: string, displayName: string, weight: number } }
	local rows = {}
	for buyerId, weight in buyerWeights or {} do
		if isPositiveWeight(weight) then
			local buyer = Buyers.get(buyerId)
			table.insert(rows, {
				buyerId = buyerId,
				displayName = if buyer then buyer.displayName else buyerId,
				weight = weight,
			})
		end
	end

	table.sort(rows, function(a, b)
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.displayName < b.displayName
	end)

	local limited = {}
	for index = 1, math.min(#rows, MAX_LIKELY_BUYERS) do
		table.insert(limited, rows[index])
	end
	return limited
end

local function collectGoodCategoriesAndTraits(buyerWeights): ({ string }, { string })
	local categoryScores: { [string]: number } = {}
	local traitScores: { [string]: number } = {}

	for buyerId, weight in buyerWeights or {} do
		if not isPositiveWeight(weight) then
			continue
		end

		local buyer = Buyers.get(buyerId)
		if not buyer then
			continue
		end

		for category, _entry in buyer.categoryPreferences or {} do
			if category ~= "default" then
				local score = BuyerMatch.getCategoryInterest(buyer, category)
				if score > 0 then
					categoryScores[category] = (categoryScores[category] or 0) + weight * score
				end
			end
		end

		for _, trait in buyer.traitPreferences or {} do
			traitScores[trait] = (traitScores[trait] or 0) + weight
		end
	end

	local function topKeys(scores: { [string]: number }, limit: number): { string }
		local rows = {}
		for key, score in scores do
			table.insert(rows, { key = key, score = score })
		end
		table.sort(rows, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.key < b.key
		end)

		local keys = {}
		for index = 1, math.min(#rows, limit) do
			table.insert(keys, rows[index].key)
		end
		return keys
	end

	return topKeys(categoryScores, MAX_GOOD_CATEGORIES), topKeys(traitScores, MAX_GOOD_TRAITS)
end

local function collectDisplayEffects(buyerWeights, displayItems): { any }
	if not displayItems or #displayItems == 0 then
		return {}
	end

	local _adjustedWeights, influenceByBuyerId = DisplayInfluence.applyBuyerWeightBonuses(buyerWeights, displayItems)
	local rows = {}
	for buyerId, entry in influenceByBuyerId do
		local bonus = entry and entry.bonus or 0
		if bonus > 0 then
			local buyer = Buyers.get(buyerId)
			table.insert(rows, {
				buyerId = buyerId,
				displayName = if buyer then buyer.displayName else buyerId,
				bonus = bonus,
				matchedCategories = entry.matchedCategories or {},
				matchedTraits = entry.matchedTraits or {},
			})
		end
	end

	table.sort(rows, function(a, b)
		if a.bonus ~= b.bonus then
			return a.bonus > b.bonus
		end
		return a.displayName < b.displayName
	end)

	local limited = {}
	for index = 1, math.min(#rows, MAX_DISPLAY_EFFECTS) do
		table.insert(limited, rows[index])
	end
	return limited
end

function DemandPreview.build(shiftId: string, displayItems): any?
	local shift = Shifts.get(shiftId)
	if not shift then
		return nil
	end

	local items = displayItems or {}
	local goodCategories, goodTraits = collectGoodCategoriesAndTraits(shift.buyerWeights)

	return {
		shiftId = shift.id,
		displayName = shift.displayName,
		modifierText = shift.modifierText,
		description = shift.description,
		likelyBuyers = collectWeightedBuyers(shift.buyerWeights),
		goodCategories = goodCategories,
		goodTraits = goodTraits,
		hasMixedDemand = #goodCategories == 0 and #goodTraits == 0,
		displayAppealSummary = DisplayInfluence.summarizeDisplayAppeal(items),
		hasDisplayItems = #items > 0,
		displayEffects = collectDisplayEffects(shift.buyerWeights, items),
	}
end

function DemandPreview.buildFromSnapshot(shiftId: string, inventorySnapshot: any?): any?
	local displayItems = if inventorySnapshot then inventorySnapshot.displayItems else nil
	return DemandPreview.build(shiftId, displayItems)
end

return DemandPreview
