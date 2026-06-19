-- Early targets are tuned around modest first-prototype profits, not perfect play.
-- Scrap Rush should be beatable with several small wins so the first run feels welcoming.
local shiftList = {
	{
		id = "scrap_rush",
		displayName = "Scrap Rush",
		dealCount = 6,
		targetProfit = 165,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 5,
		dealArchetypeWeights = {
			safe_flip = 5,
			desperate_seller = 4,
			bad_deal = 1,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {
			desperate_mechanic = 3,
			cheap_scavenger = 3,
			robot_appraiser = 2,
			rich_collector = 1,
			alien_tourist = 1,
		},
		description = "A short beginner shift. Flip whatever walks in.",
		modifierText = "Steady flips. Low risk, low ceiling.",
	},
	{
		id = "collector_convention",
		displayName = "Collector Convention",
		dealCount = 7,
		targetProfit = 360,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 4,
		dealArchetypeWeights = {
			perfect_buyer_setup = 3,
			safe_flip = 1,
			jackpot_junk = 1,
			scam_trap = 2,
			bad_deal = 2,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {
			rich_collector = 3,
			alien_tourist = 2,
			robot_appraiser = 1,
			cheap_scavenger = 1,
		},
		description = "Collectors are around. Collectibles should matter more later.",
		modifierText = "Hold for the right buyer. Traps and bad stock mixed in.",
	},
	{
		id = "black_market_night",
		displayName = "Black Market Night",
		dealCount = 8,
		targetProfit = 500,
		inventorySlots = 3,
		buyerVisitEvery = 2,
		closingRushBuyerLimit = 4,
		dealArchetypeWeights = {
			scam_trap = 4,
			jackpot_junk = 4,
			bad_deal = 2,
			perfect_buyer_setup = 1,
		},
		itemCategoryWeights = {},
		traitWeights = {},
		buyerWeights = {
			black_market_dealer = 3,
			alien_tourist = 2,
			cheap_scavenger = 1,
		},
		description = "Riskier shift with bigger target.",
		modifierText = "Scams, jackpots, and volatile buyers. Inspect or regret.",
	},
}

local byId = {}
for _, shift in shiftList do
	byId[shift.id] = shift
end

local Shifts = {
	List = shiftList,
	ById = byId,
	LiquidationRate = 0.35,
}

function Shifts.get(shiftId: string)
	return Shifts.ById[shiftId]
end

function Shifts.getAll()
	return Shifts.List
end

return Shifts
