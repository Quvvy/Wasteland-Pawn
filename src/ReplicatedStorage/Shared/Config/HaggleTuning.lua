-- Tactic + heat haggling prototype tuning.
local HaggleTuning = {
	currencyName = "scraps",
	startingCash = 500,
	inspectCost = 20,

	autoNextDelayWalkedAway = 2.5,
	autoNextDelayResult = 2.5,
	autoNextDelayPass = 1.5,

	passPenaltyCaps = 0,
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
	buyerMaximumBaseRatio = 1.08,
	buyerMaximumUrgencyBonus = 0.4,
	buyerMaximumKnowledgePenalty = 0.05,
	buyerMaximumGreedPenalty = 0.06,

	-- Buy tactic heat
	heatBuySplit = 10,
	heatBuyFlaw = 18,
	heatBuyPressure = 22,
	heatBuyLowball = 38,
	heatMismatchBonus = 12,
	heatGoodMatchReduction = 6,
	heatRepeatTactic = 14,

	-- Sell tactic heat
	heatSellSmallBump = 9,
	heatSellPitch = 18,
	heatSellHoldFirm = 24,
	heatSellBluff = 40,

	-- Price movement ratios (fraction of gap or current price)
	buySplitDropRatio = 0.42,
	buyFlawDropRatio = 0.28,
	buyPressureDropRatio = 0.35,
	buyLowballDropRatio = 0.55,
	buyLowballBigWinRatio = 0.72,
	buyInspectFlawBonus = 0.12,
	buyScamFlawBonus = 0.18,

	sellSmallBumpRatio = 0.1,
	sellPitchRatio = 0.28,
	sellHoldRatio = 0.22,
	sellBluffRatio = 0.45,
	sellBluffBigWinRatio = 0.65,
	sellCategoryPitchBonus = 0.14,

	-- Walk / success chances
	buyLowballWalkChanceBad = 0.35,
	buyLowballWalkChanceGood = 0.08,
	sellBluffWalkChanceBad = 0.4,
	sellBluffWalkChanceGood = 0.1,
	tacticWalkChanceAtHighHeat = 0.55,

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
