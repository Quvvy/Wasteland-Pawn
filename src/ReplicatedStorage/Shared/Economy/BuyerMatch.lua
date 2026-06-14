local BuyerMatch = {}

local LABELS = {
	Bad = "Bad Match",
	Low = "Low Interest",
	Curious = "Curious",
	Interested = "Interested",
	Perfect = "Perfect Match",
}

local OFFER_MULTIPLIERS = {
	[LABELS.Bad] = 0.75,
	[LABELS.Low] = 0.9,
	[LABELS.Curious] = 1,
	[LABELS.Interested] = 1.18,
	[LABELS.Perfect] = 1.4,
}

local function listToSet(list: { string }?): { [string]: boolean }
	local set = {}
	for _, value in list or {} do
		set[value] = true
	end
	return set
end

local function getLabel(score: number): string
	if score >= 4 then
		return LABELS.Perfect
	elseif score >= 3 then
		return LABELS.Interested
	elseif score >= 2 then
		return LABELS.Curious
	elseif score >= 1 then
		return LABELS.Low
	end
	return LABELS.Bad
end

local function getCategoryScore(buyer, category: string?): (number, { string })
	if not buyer or not category then
		return 0, {}
	end

	local prefs = buyer.categoryPreferences or {}
	local explicit = prefs[category]
	local entry = explicit or prefs.default
	if not entry then
		return 0, {}
	end

	local open = entry.open or 1
	local max = entry.max or 1
	local average = (open + max) / 2

	if explicit then
		if average >= 1.15 or max >= 1.25 then
			return 2, { category }
		elseif average >= 0.98 or max >= 1.08 then
			return 1, { category }
		end
		return 0, {}
	end

	if average >= 0.98 then
		return 1, {}
	end
	return 0, {}
end

local function getTraitMatches(buyer, traits): { string }
	local wanted = listToSet(buyer and buyer.traitPreferences)
	local matches = {}
	for _, trait in traits or {} do
		if wanted[trait] then
			table.insert(matches, trait)
		end
	end
	return matches
end

function BuyerMatch.score(item, buyer)
	local trueValue = item and item.trueValue or 0
	local categoryScore, matchedCategories = getCategoryScore(buyer, item and item.category)
	local matchedTraits = getTraitMatches(buyer, item and item.traits)
	local traitScore = #matchedTraits
	if #matchedTraits >= 2 then
		traitScore += 1
	end

	local score = (buyer and buyer.matchBaseline or 0) + categoryScore + traitScore
	local label = getLabel(score)
	local categoryBonus = 0
	local traitBonus = 0

	if categoryScore > 0 then
		categoryBonus = math.floor(trueValue * categoryScore * 0.12 + 0.5)
	end
	if #matchedTraits > 0 then
		local traitMultiplier = #matchedTraits * 0.08
		if #matchedTraits >= 2 then
			traitMultiplier += 0.08
		end
		traitBonus = math.floor(trueValue * traitMultiplier + 0.5)
	end

	local bonusLines = {}
	table.insert(bonusLines, {
		id = "buyer_match",
		label = "Buyer Match",
		amount = categoryBonus,
	})
	table.insert(bonusLines, {
		id = "trait_match",
		label = "Trait Match",
		amount = traitBonus,
	})

	return {
		score = score,
		label = label,
		offerMultiplier = OFFER_MULTIPLIERS[label] or 1,
		categoryBonus = categoryBonus,
		traitBonus = traitBonus,
		matchedCategories = matchedCategories,
		matchedTraits = matchedTraits,
		bonusLines = bonusLines,
	}
end

function BuyerMatch.describeBuyer(buyer): string
	if not buyer then
		return "Wants: unknown"
	end

	local wants = {}
	for category, entry in buyer.categoryPreferences or {} do
		if category ~= "default" and ((entry.open or 1) + (entry.max or 1)) / 2 >= 0.98 then
			table.insert(wants, category)
		end
	end

	local traits = buyer.traitPreferences or {}
	local wantText = if #wants > 0 then table.concat(wants, ", ") else "almost anything"
	local traitText = if #traits > 0 then table.concat(traits, ", ") else "fair value"
	return `Wants: {wantText} | Traits: {traitText}`
end

return BuyerMatch
