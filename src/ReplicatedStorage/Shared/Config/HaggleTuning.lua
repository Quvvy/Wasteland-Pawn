-- Central balance knobs for the haggling prototype. Tune here first.
local HaggleTuning = {
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

	-- Accept roll when offer >= minimumAccept
	acceptChanceBase = 0.52,
	acceptChanceDesperationScale = 0.38,
	acceptChanceKnowledgePenalty = 0.12,
	acceptChanceNearAsk = 0.92,

	-- Asking price markup over true value
	askingMarkupBase = 1.08,
	askingMarkupGreed = 0.38,
	askingMarkupScam = 0.28,
	askingMarkupDesperation = 0.24,
	askingMarkupJitter = 0.06,

	-- Minimum acceptable buy price
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

	-- Patience loss (base + temper * scale)
	patienceLossCounterNearAccept = { base = 3, temperScale = 3 },
	patienceLossCounter = { base = 7, temperScale = 7 },
	patienceLossReject = { base = 11, temperScale = 13 },
	patienceLossInsult = { base = 18, temperScale = 20 },

	-- customer.patience stat (0-1) scales starting deal patience
	customerPatienceMin = 0.42,
	customerPatienceMax = 1.0,

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
