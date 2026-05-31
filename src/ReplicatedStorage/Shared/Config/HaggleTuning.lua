-- Central balance knobs for the haggling prototype. Tune here first.
local HaggleTuning = {
	currencyName = "scraps",
	startingCash = 500,
	inspectCost = 25,
	startingPatience = 100,

	autoNextDelayWalkedAway = 2.5,
	autoNextDelayResult = 2.5,
	autoNextDelayPass = 1.5,

	-- Offer amount / asking price
	offerRatioCounter = 0.78,
	offerRatioReject = 0.55,
	offerRatioInsult = 0.45,
	nearAskAcceptRatio = 0.98,

	-- Must offer at least this fraction of stated ask before accept RNG (unless lowball steal)
	minOfferRatioOfAsk = 0.85,
	minRaiseStepCaps = 5,
	minRaiseStepAskPercent = 0.03,

	-- Accept roll when offer >= effectiveMinimum
	acceptChanceBase = 0.38,
	acceptChanceDesperationScale = 0.32,
	acceptChanceKnowledgePenalty = 0.14,
	acceptChanceNearAsk = 0.88,

	-- Asking price markup over true value
	askingMarkupBase = 1.08,
	askingMarkupGreed = 0.38,
	askingMarkupScam = 0.28,
	askingMarkupDesperation = 0.24,
	askingMarkupJitter = 0.06,

	-- Minimum acceptable buy price (hidden true-value floor)
	minAcceptValueBase = 0.7,
	minAcceptGreed = 0.2,
	minAcceptDesperation = 0.26,
	minAcceptKnowledge = 0.1,
	minAcceptAskFactor = 0.52,

	-- Counter offer bias
	counterMidBias = 0.25,
	counterGreedBias = 0.28,
	counterDesperationBias = 0.16,
	counterJitter = 6,
	counterDesperationSlip = 8,

	-- Repeat offer anti-spam
	repeatPatiencePenalty = 12,
	repeatOfferWalkawayAt = 3,
	repeatBlockAcceptAt = 2,

	-- Patience loss (base + temper * scale)
	patienceLossCounterNearAccept = { base = 5, temperScale = 5 },
	patienceLossCounter = { base = 8, temperScale = 8 },
	patienceLossReject = { base = 12, temperScale = 14 },
	patienceLossInsult = { base = 20, temperScale = 22 },
	patienceLossBelowCounter = { base = 22, temperScale = 24 },
	patienceLossRepeat = { base = 14, temperScale = 10 },

	-- customer.patience stat (0-1) scales starting deal patience
	customerPatienceMin = 0.42,
	customerPatienceMax = 1.0,

	-- Lowball
	lowballMaxRatio = 0.5,
	lowballMinUsefulRatio = 0.32,
	lowballStealBase = 0.06,
	lowballStealDesperationScale = 0.22,
	lowballCrackBase = 0.12,
	lowballCrackDesperationScale = 0.18,
	lowballCrackKnowledgeScale = 0.16,
	lowballCrackMin = 0.03,
	lowballCrackMax = 0.5,
	lowballOffendedTemperScale = 0.35,
	lowballScamCalloutChance = 0.35,
	lowballScamAskReduction = 0.12,
	lowballInstantWalkawayTemper = 0.75,

	-- Pass / walkaway costs (0 while playtesting)
	passPenaltyCaps = 0,
	walkawayPenaltyCaps = 0,
	dealCooldownSeconds = 0,

	-- Sell-side haggle
	buyerOfferBaseRatio = 0.62,
	buyerOfferGreedPenalty = 0.14,
	buyerOfferUrgencyBonus = 0.12,
	buyerMaximumBaseRatio = 0.92,
	buyerMaximumUrgencyBonus = 0.28,
	buyerMaximumKnowledgePenalty = 0.08,
	sellAcceptChanceBase = 0.4,
	sellAcceptUrgencyScale = 0.35,
	sellAcceptKnowledgePenalty = 0.15,
	sellCounterStepRatio = 0.35,
	sellRepeatWalkawayAt = 3,
	sellRepeatBlockAt = 2,

	-- Item estimate spread
	estimateSpreadBase = 0.36,
	estimateSpreadKnowledge = 0.16,
	estimateSpreadScam = 0.3,
	estimateSpreadMin = 0.12,
	estimateSpreadMax = 0.58,
	scamInflateMin = 0.18,
	scamInflateMax = 0.5,
	inspectInflatedThreshold = 0.32,
}

return HaggleTuning
