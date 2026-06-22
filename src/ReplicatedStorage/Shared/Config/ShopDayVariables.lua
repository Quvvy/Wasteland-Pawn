local ShopDayVariables = {}

local BUYER_DEMAND_PROFILES = {
	practical = {
		label = "Practical demand",
		shortLabel = "Practical",
		line = "Practical buyers are a little more likely.",
		buyerMultipliers = {
			desperate_mechanic = 1.08,
			cheap_scavenger = 1.08,
			robot_appraiser = 1.04,
		},
	},
	collector = {
		label = "Collector interest",
		shortLabel = "Collectors",
		line = "Collector-flavored buyers are a little more likely.",
		buyerMultipliers = {
			rich_collector = 1.08,
			alien_tourist = 1.06,
			robot_appraiser = 1.04,
		},
	},
	black_market = {
		label = "Back-room demand",
		shortLabel = "Back-room",
		line = "Stranger buyers are a little more likely.",
		buyerMultipliers = {
			black_market_dealer = 1.08,
			alien_tourist = 1.06,
			cheap_scavenger = 1.03,
		},
	},
	mixed = {
		label = "Mixed demand",
		shortLabel = "Mixed",
		line = "Traffic is broad with no single strong pull.",
		buyerMultipliers = {
			desperate_mechanic = 1.03,
			rich_collector = 1.03,
			alien_tourist = 1.03,
			black_market_dealer = 1.03,
			robot_appraiser = 1.03,
		},
	},
}

local SELLER_FLOW_PROFILES = {
	steady = {
		label = "Steady sellers",
		shortLabel = "Steady",
		line = "Seller stock leans slightly safer.",
		archetypeMultipliers = {
			safe_flip = 1.08,
			desperate_seller = 1.04,
		},
	},
	odd_lots = {
		label = "Odd lots",
		shortLabel = "Odd lots",
		line = "Seller stock leans slightly weirder.",
		archetypeMultipliers = {
			jackpot_junk = 1.06,
			perfect_buyer_setup = 1.04,
			scam_trap = 1.03,
		},
	},
	rough = {
		label = "Rough sellers",
		shortLabel = "Rough",
		line = "Seller stock leans slightly riskier.",
		archetypeMultipliers = {
			scam_trap = 1.06,
			bad_deal = 1.06,
			jackpot_junk = 1.03,
		},
	},
}

local SHIFT_PROFILES = {
	scrap_rush = {
		buyerDemand = {
			{ id = "practical", weight = 4 },
			{ id = "mixed", weight = 1 },
		},
		sellerFlow = {
			{ id = "steady", weight = 4 },
			{ id = "odd_lots", weight = 1 },
		},
		riskLabel = "Low risk",
		riskLine = "Reliable normal-day traffic.",
	},
	collector_convention = {
		buyerDemand = {
			{ id = "collector", weight = 4 },
			{ id = "mixed", weight = 1 },
		},
		sellerFlow = {
			{ id = "odd_lots", weight = 3 },
			{ id = "rough", weight = 2 },
		},
		riskLabel = "Medium risk",
		riskLine = "Better specialty traffic, uneven stock.",
	},
	black_market_night = {
		buyerDemand = {
			{ id = "black_market", weight = 4 },
			{ id = "mixed", weight = 1 },
		},
		sellerFlow = {
			{ id = "rough", weight = 4 },
			{ id = "odd_lots", weight = 1 },
		},
		riskLabel = "High risk",
		riskLine = "Volatile traffic and rougher stock.",
	},
}

local function pickWeighted(rows, rng: Random): string
	local total = 0
	for _, row in rows do
		total += math.max(row.weight or 0, 0)
	end
	if total <= 0 then
		return rows[1] and rows[1].id or "mixed"
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, row in rows do
		running += math.max(row.weight or 0, 0)
		if roll <= running then
			return row.id
		end
	end
	return rows[#rows].id
end

local function copyWeightedMap(source, multipliers)
	local result = {}
	for id, weight in source or {} do
		if type(weight) == "number" and weight > 0 then
			local multiplier = if type(multipliers) == "table" and type(multipliers[id]) == "number"
				then multipliers[id]
				else 1
			result[id] = math.max(weight * multiplier, 0.01)
		end
	end
	return result
end

local function collectDisplayParts(displayItems)
	local categories = {}
	local traits = {}
	for _, item in displayItems or {} do
		if type(item.category) == "string" and item.category ~= "" then
			categories[item.category] = true
		end
		for _, trait in item.traits or {} do
			if type(trait) == "string" and trait ~= "" then
				traits[trait] = true
			end
		end
	end

	local parts = {}
	for category in categories do
		table.insert(parts, category)
	end
	for trait in traits do
		table.insert(parts, trait)
	end
	table.sort(parts)
	return parts
end

local function displaySummary(displayItems): string
	local parts = collectDisplayParts(displayItems)
	if #parts == 0 then
		return "Display has no pull yet"
	end
	return `Display shows {table.concat(parts, " / ")}`
end

function ShopDayVariables.displayFingerprint(displayItems): string
	local parts = {}
	for _, item in displayItems or {} do
		local traits = {}
		for _, trait in item.traits or {} do
			table.insert(traits, tostring(trait))
		end
		table.sort(traits)
		table.insert(
			parts,
			table.concat({
				tostring(item.permanentId or item.instanceId or ""),
				tostring(item.displaySlotIndex or ""),
				tostring(item.displayName or ""),
				tostring(item.category or ""),
				table.concat(traits, "+"),
			}, "|")
		)
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function ShopDayVariables.build(shift, trafficEntry, displayItems, rng: Random?)
	local random = rng or Random.new()
	local shiftId = shift and shift.id or "scrap_rush"
	local profile = SHIFT_PROFILES[shiftId] or SHIFT_PROFILES.scrap_rush
	local buyerDemandId = pickWeighted(profile.buyerDemand, random)
	local sellerFlowId = pickWeighted(profile.sellerFlow, random)
	local buyerDemand = BUYER_DEMAND_PROFILES[buyerDemandId] or BUYER_DEMAND_PROFILES.mixed
	local sellerFlow = SELLER_FLOW_PROFILES[sellerFlowId] or SELLER_FLOW_PROFILES.steady
	local trafficLabel = trafficEntry and trafficEntry.label or nil

	return {
		shiftId = shiftId,
		trafficLabel = trafficLabel,
		buyerDemandId = buyerDemandId,
		buyerDemandLabel = buyerDemand.label,
		buyerDemandShortLabel = buyerDemand.shortLabel,
		buyerEffectText = buyerDemand.line,
		sellerFlowId = sellerFlowId,
		sellerFlowLabel = sellerFlow.label,
		sellerFlowShortLabel = sellerFlow.shortLabel,
		sellerEffectText = sellerFlow.line,
		riskLabel = profile.riskLabel,
		riskLine = profile.riskLine,
		displayLine = displaySummary(displayItems),
		forecastLine = `{buyerDemand.shortLabel} demand | {sellerFlow.shortLabel} sellers | {profile.riskLabel}`,
		buyerMultipliers = buyerDemand.buyerMultipliers,
		archetypeMultipliers = sellerFlow.archetypeMultipliers,
		displayHelped = false,
	}
end

function ShopDayVariables.applyBuyerWeights(baseWeights, forecast)
	return copyWeightedMap(baseWeights, forecast and forecast.buyerMultipliers)
end

function ShopDayVariables.applyDealArchetypeWeights(baseWeights, forecast)
	return copyWeightedMap(baseWeights, forecast and forecast.archetypeMultipliers)
end

function ShopDayVariables.toSnapshot(forecast)
	if type(forecast) ~= "table" then
		return nil
	end

	return {
		shiftId = forecast.shiftId,
		trafficLabel = forecast.trafficLabel,
		buyerDemandId = forecast.buyerDemandId,
		buyerDemandLabel = forecast.buyerDemandLabel,
		buyerDemandShortLabel = forecast.buyerDemandShortLabel,
		buyerEffectText = forecast.buyerEffectText,
		sellerFlowId = forecast.sellerFlowId,
		sellerFlowLabel = forecast.sellerFlowLabel,
		sellerFlowShortLabel = forecast.sellerFlowShortLabel,
		sellerEffectText = forecast.sellerEffectText,
		riskLabel = forecast.riskLabel,
		riskLine = forecast.riskLine,
		displayLine = forecast.displayLine,
		forecastLine = forecast.forecastLine,
		displayHelped = forecast.displayHelped == true,
	}
end

return ShopDayVariables
