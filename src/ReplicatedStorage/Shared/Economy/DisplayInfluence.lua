local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buyers = require(Shared.Config.Buyers)
local BuyerMatch = require(Shared.Economy.BuyerMatch)

local DisplayInfluence = {}

DisplayInfluence.CATEGORY_BONUS = 0.15
DisplayInfluence.TRAIT_BONUS = 0.05
DisplayInfluence.MAX_BONUS = 0.50

function DisplayInfluence.summarizeDisplayAppeal(displayItems): string?
	if not displayItems or #displayItems == 0 then
		return nil
	end

	local seen: { [string]: boolean } = {}
	local categories = {}
	for _, item in displayItems do
		local category = item.category
		if category and category ~= "" and not seen[category] then
			seen[category] = true
			table.insert(categories, category)
		end
	end

	if #categories == 0 then
		return nil
	end

	table.sort(categories)
	return table.concat(categories, ", ")
end

function DisplayInfluence.describeBuyerInfluence(buyer, influenceEntry): string?
	if not buyer or not influenceEntry or (influenceEntry.bonus or 0) <= 0 then
		return nil
	end

	return `{buyer.displayName} noticed your display.`
end

function DisplayInfluence.applyBuyerWeightBonuses(baseWeights, displayItems)
	if type(baseWeights) ~= "table" or not displayItems or #displayItems == 0 then
		return baseWeights, {}
	end

	local adjustedWeights = {}
	local influenceByBuyerId = {}

	for buyerId, baseWeight in baseWeights do
		if type(baseWeight) ~= "number" or baseWeight <= 0 then
			continue
		end

		local buyer = Buyers.get(buyerId)
		if not buyer then
			adjustedWeights[buyerId] = baseWeight
			continue
		end

		local bonus = 0
		local matchedCategorySet: { [string]: boolean } = {}
		local matchedTraitSet: { [string]: boolean } = {}

		for _, item in displayItems do
			local categoryScore, matchedCategories = BuyerMatch.getCategoryInterest(buyer, item.category)
			if categoryScore >= 1 and #matchedCategories > 0 then
				bonus += DisplayInfluence.CATEGORY_BONUS
				for _, category in matchedCategories do
					matchedCategorySet[category] = true
				end
			end

			local matchedTraits = BuyerMatch.getMatchingTraits(buyer, item.traits)
			bonus += #matchedTraits * DisplayInfluence.TRAIT_BONUS
			for _, trait in matchedTraits do
				matchedTraitSet[trait] = true
			end
		end

		bonus = math.min(bonus, DisplayInfluence.MAX_BONUS)
		adjustedWeights[buyerId] = baseWeight * (1 + bonus)

		if bonus > 0 then
			local matchedCategories = {}
			for category in matchedCategorySet do
				table.insert(matchedCategories, category)
			end
			table.sort(matchedCategories)

			local matchedTraits = {}
			for trait in matchedTraitSet do
				table.insert(matchedTraits, trait)
			end
			table.sort(matchedTraits)

			influenceByBuyerId[buyerId] = {
				bonus = bonus,
				matchedCategories = matchedCategories,
				matchedTraits = matchedTraits,
			}
		end
	end

	return adjustedWeights, influenceByBuyerId
end

return DisplayInfluence
