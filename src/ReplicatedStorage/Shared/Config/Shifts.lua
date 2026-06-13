-- Early targets are tuned around modest first-prototype profits, not perfect play.
-- Scrap Rush should be beatable with several small wins so the first run feels welcoming.
local shiftList = {
	{
		id = "scrap_rush",
		displayName = "Scrap Rush",
		dealCount = 6,
		targetProfit = 180,
		description = "A short beginner shift. Flip whatever walks in.",
		modifierText = "Basic items. Easy target.",
	},
	{
		id = "collector_convention",
		displayName = "Collector Convention",
		dealCount = 7,
		targetProfit = 320,
		description = "Collectors are around. Collectibles should matter more later.",
		modifierText = "Collector-heavy shift. Modifier hooks only for now.",
	},
	{
		id = "black_market_night",
		displayName = "Black Market Night",
		dealCount = 8,
		targetProfit = 520,
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
