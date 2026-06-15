-- Early targets are tuned around modest first-prototype profits, not perfect play.
-- Scrap Rush should be beatable with several small wins so the first run feels welcoming.
local shiftList = {
	{
		id = "scrap_rush",
		displayName = "Scrap Rush",
		dealCount = 6,
		targetProfit = 180,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 4,
		dealArchetypeWeights = {
			safe_flip = 4,
			desperate_seller = 3,
			bad_deal = 1,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {},
		description = "A short beginner shift. Flip whatever walks in.",
		modifierText = "Basic items. Easy target.",
	},
	{
		id = "collector_convention",
		displayName = "Collector Convention",
		dealCount = 7,
		targetProfit = 320,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 4,
		dealArchetypeWeights = {
			safe_flip = 2,
			perfect_buyer_setup = 3,
			jackpot_junk = 2,
			scam_trap = 1,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {},
		description = "Collectors are around. Collectibles should matter more later.",
		modifierText = "Collector-heavy shift. Modifier hooks only for now.",
	},
	{
		id = "black_market_night",
		displayName = "Black Market Night",
		dealCount = 8,
		targetProfit = 520,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 4,
		dealArchetypeWeights = {
			scam_trap = 3,
			jackpot_junk = 3,
			bad_deal = 2,
			perfect_buyer_setup = 1,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {},
		description = "Riskier shift with bigger target.",
		modifierText = "Cursed and alien hooks later. For now, just harder target.",
	},
}

local byId = {}
for _, shift in shiftList do
	byId[shift.id] = shift
end

local Shifts = {
	List = shiftList,
	ById = byId,
}

function Shifts.get(shiftId: string)
	return Shifts.ById[shiftId]
end

function Shifts.getAll()
	return Shifts.List
end

return Shifts
