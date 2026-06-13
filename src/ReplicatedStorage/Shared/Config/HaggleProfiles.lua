local HaggleTactics = require(script.Parent.Parent.Economy.HaggleTactics)

local Buy = HaggleTactics.Buy
local Sell = HaggleTactics.Sell

local HaggleProfiles = {}

HaggleProfiles.Sellers = {
	desperate_survivor = {
		weakTo = { Buy.Pressure, Buy.Lowball },
		resists = {},
		hates = {},
		badState = "Worried",
	},
	shady_scammer = {
		weakTo = { Buy.PointOutFlaw },
		resists = { Buy.SplitDifference },
		hates = { Buy.Lowball },
		badState = "Suspicious",
	},
	rich_collector = {
		weakTo = { Buy.SplitDifference, Buy.PointOutFlaw },
		resists = { Buy.Pressure },
		hates = { Buy.Lowball },
		badState = "Offended",
	},
	robot_trader = {
		weakTo = { Buy.PointOutFlaw, Buy.SplitDifference },
		resists = { Buy.Lowball },
		hates = { Buy.Pressure },
		badState = "Guarded",
	},
	mutant_drifter = {
		weakTo = { Buy.Pressure, Buy.Lowball },
		resists = { Buy.SplitDifference },
		hates = {},
		badState = "Impatient",
	},
	nervous_rookie = {
		weakTo = { Buy.Pressure, Buy.Lowball },
		resists = {},
		hates = { Buy.PointOutFlaw },
		badState = "Panicked",
	},
	soldier = {
		weakTo = { Buy.SplitDifference },
		resists = { Buy.PointOutFlaw },
		hates = { Buy.Pressure, Buy.Lowball },
		badState = "Guarded",
	},
	junk_dealer = {
		weakTo = { Buy.PointOutFlaw, Buy.SplitDifference },
		resists = { Buy.Pressure },
		hates = { Buy.Lowball },
		badState = "Suspicious",
	},
	alien_tourist = {
		weakTo = { Buy.Lowball, Buy.PointOutFlaw },
		resists = {},
		hates = {},
		badState = "Confused",
	},
	silent_stranger = {
		weakTo = { Buy.SplitDifference },
		resists = { Buy.Lowball, Buy.Pressure },
		hates = {},
		badState = "Guarded",
	},
}

HaggleProfiles.Buyers = {
	cheap_scavenger = {
		weakTo = { Sell.SmallBump },
		resists = { Sell.PitchValue, Sell.HoldFirm },
		hates = { Sell.Bluff },
		badState = "Guarded",
	},
	rich_collector = {
		weakTo = { Sell.PitchValue, Sell.HoldFirm },
		resists = { Sell.SmallBump },
		hates = { Sell.Bluff },
		badState = "Offended",
	},
	desperate_mechanic = {
		weakTo = { Sell.PitchValue, Sell.HoldFirm },
		resists = {},
		hates = {},
		badState = "Impatient",
	},
	alien_tourist = {
		weakTo = { Sell.Bluff, Sell.PitchValue },
		resists = {},
		hates = {},
		badState = "Confused",
	},
	robot_appraiser = {
		weakTo = { Sell.SmallBump, Sell.PitchValue },
		resists = { Sell.HoldFirm },
		hates = { Sell.Bluff },
		badState = "Guarded",
	},
	black_market_dealer = {
		weakTo = { Sell.HoldFirm, Sell.SmallBump },
		resists = { Sell.PitchValue },
		hates = { Sell.Bluff },
		badState = "Suspicious",
	},
}

local function listToSet(list: { string }?): { [string]: boolean }
	local set = {}
	for _, value in list or {} do
		set[value] = true
	end
	return set
end

for _, profile in HaggleProfiles.Sellers do
	profile.weakTo = listToSet(profile.weakTo)
	profile.resists = listToSet(profile.resists)
	profile.hates = listToSet(profile.hates)
end

for _, profile in HaggleProfiles.Buyers do
	profile.weakTo = listToSet(profile.weakTo)
	profile.resists = listToSet(profile.resists)
	profile.hates = listToSet(profile.hates)
end

return HaggleProfiles
