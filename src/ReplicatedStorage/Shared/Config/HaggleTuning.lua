-- Tactic + heat haggling prototype tuning.
local HaggleTuning = {
	currencyName = "scraps",
	startingCash = 500,
	inspectCost = 20,

	autoNextDelayWalkedAway = 2.5,
	autoNextDelayResult = 2.5,
	autoNextDelayPass = 1.5,

	passPenaltyCaps = 5,
	buyerRerollCost = 10,
	walkawayPenaltyCaps = 0,
	dealCooldownSeconds = 0,

	-- Heat (0-100 typical; walk at heatMax)
	heatMax = 100,
	heatWarningThreshold = 60,
	heatWalkThreshold = 100,

	-- Seller init
	askingMarkupBase = 1.14,
	askingMarkupGreed = 0.4,
	askingMarkupScam = 0.32,
	askingMarkupDesperation = 0.26,
	askingMarkupJitter = 0.08,
	minAcceptValueBase = 0.5,
	minAcceptGreed = 0.14,
	minAcceptDesperation = 0.4,
	minAcceptKnowledge = 0.12,
	minAcceptAskFactor = 0.34,
	minAcceptFloorOfTrue = 0.32,
	minAcceptCeilingOfTrue = 1.02,

	-- Buyer init (opening / max of true value)
	buyerOfferBaseRatio = 0.8,
	buyerOfferGreedPenalty = 0.08,
	buyerOfferUrgencyBonus = 0.12,
	buyerOfferJitter = 0.05,
	buyerMaximumBaseRatio = 1.0,
	buyerMaximumUrgencyBonus = 0.32,
	buyerMaximumKnowledgePenalty = 0.07,
	buyerMaximumGreedPenalty = 0.08,

	-- Buy tactic heat
	heatBuySplit = 10,
	heatBuyFlaw = 18,
	heatBuyPressure = 22,
	heatBuyLowball = 38,
	heatMismatchBonus = 18,
	heatGoodMatchReduction = 4,
	heatRepeatTactic = 20,

	-- Sell tactic heat
	heatSellSmallBump = 9,
	heatSellPitch = 18,
	heatSellHoldFirm = 24,
	heatSellBluff = 40,

	-- Price movement ratios (fraction of gap or current price)
	buySplitDropRatio = 0.34,
	buyFlawDropRatio = 0.23,
	buyPressureDropRatio = 0.28,
	buyLowballDropRatio = 0.44,
	buyLowballBigWinRatio = 0.62,
	buyInspectFlawBonus = 0.1,
	buyScamFlawBonus = 0.14,

	sellSmallBumpRatio = 0.08,
	sellPitchRatio = 0.22,
	sellHoldRatio = 0.18,
	sellBluffRatio = 0.34,
	sellBluffBigWinRatio = 0.54,
	sellCategoryPitchBonus = 0.11,

	-- Walk / success chances
	buyLowballWalkChanceBad = 0.5,
	buyLowballWalkChanceGood = 0.1,
	sellBluffWalkChanceBad = 0.55,
	sellBluffWalkChanceGood = 0.12,
	tacticWalkChanceAtHighHeat = 0.68,

	-- Inspection
	inspectInflatedThreshold = 0.28,
	inspectNarrowLowRatio = 0.75,
	inspectNarrowHighRatio = 1.25,
	estimateSpreadBase = 0.34,
	estimateSpreadKnowledge = 0.14,
	estimateSpreadScam = 0.28,
	estimateSpreadMin = 0.1,
	estimateSpreadMax = 0.55,
	scamInflateMin = 0.2,
	scamInflateMax = 0.48,
}

return HaggleTuning
