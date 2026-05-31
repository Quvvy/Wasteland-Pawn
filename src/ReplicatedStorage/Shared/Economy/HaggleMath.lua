local HaggleTuning = require(script.Parent.Parent.Config.HaggleTuning)

local HaggleMath = {}

local REACTIONS = {
	accept = {
		"Deal. Hand over the caps.",
		"Fine. You drive a hard bargain.",
		"Accepted. Don't make me regret it.",
	},
	counter = {
		"Not enough. Meet me higher.",
		"I can do better than that. Try again.",
		"You're close. Bump your offer.",
	},
	reject_insult = {
		"That's insulting.",
		"You're wasting my time.",
		"No. Absolutely not.",
	},
	reject_low = {
		"Still too low.",
		"Come on, be serious.",
		"You'll need to do better.",
	},
	walkaway = {
		"Forget it. I'm out.",
		"Done talking. Goodbye.",
		"Keep your lowball. I'm leaving.",
	},
}

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), 1, maxValue)
end

local function pickReaction(pool: { string }, rng: Random?): string
	if not pool or #pool == 0 then
		return "..."
	end
	local random = rng or Random.new()
	return pool[random:NextInteger(1, #pool)]
end

local function patienceLoss(config: { base: number, temperScale: number }, temper: number): number
	return -math.floor(config.base + temper * config.temperScale)
end

function HaggleMath.getStartingPatience(customer): number
	local stat = customer.patience or 0.5
	local mult = HaggleTuning.customerPatienceMin
		+ (HaggleTuning.customerPatienceMax - HaggleTuning.customerPatienceMin) * stat
	return math.clamp(math.floor(HaggleTuning.startingPatience * mult + 0.5), 25, HaggleTuning.startingPatience)
end

function HaggleMath.getOfferRatioBand(offerRatio: number): string
	if offerRatio < HaggleTuning.offerRatioInsult then
		return "insult"
	elseif offerRatio < HaggleTuning.offerRatioReject then
		return "low"
	elseif offerRatio < HaggleTuning.offerRatioCounter then
		return "close"
	elseif offerRatio < HaggleTuning.nearAskAcceptRatio then
		return "fair"
	end
	return "high"
end

function HaggleMath.calculateAskingPrice(customer, trueValue: number, rng: Random?): number
	local random = rng or Random.new()
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0
	local scamBias = customer.scamBias or 0

	local markup = HaggleTuning.askingMarkupBase
		+ greed * HaggleTuning.askingMarkupGreed
		+ scamBias * HaggleTuning.askingMarkupScam
		- desperation * HaggleTuning.askingMarkupDesperation
	markup += random:NextNumber(-HaggleTuning.askingMarkupJitter, HaggleTuning.askingMarkupJitter)

	return clamp(trueValue * markup, 1, 999999)
end

function HaggleMath.calculateMinimumAcceptPrice(customer, item, trueValue: number, askingPrice: number): number
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0

	local floorFromValue = trueValue
		* (
			HaggleTuning.minAcceptValueBase
			+ greed * HaggleTuning.minAcceptGreed
			- desperation * HaggleTuning.minAcceptDesperation
			+ knowledge * HaggleTuning.minAcceptKnowledge
		)
	local floorFromAsk = askingPrice
		* (HaggleTuning.minAcceptAskFactor - desperation * 0.14 + greed * 0.1)

	return clamp(math.max(floorFromValue, floorFromAsk * 0.48), 1, askingPrice)
end

function HaggleMath.calculateCounterOffer(
	customer,
	item,
	offerAmount: number,
	askingPrice: number,
	minimumAccept: number,
	rng: Random?
): number
	local random = rng or Random.new()
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0

	local gap = askingPrice - offerAmount
	local midpoint = (offerAmount + askingPrice) / 2
	local counter = midpoint + gap * (HaggleTuning.counterMidBias + greed * HaggleTuning.counterGreedBias)
	counter -= desperation * gap * HaggleTuning.counterDesperationBias
	counter += random:NextNumber(-3, HaggleTuning.counterJitter)

	return clamp(counter, minimumAccept, askingPrice)
end

function HaggleMath.evaluateOffer(customer, item, offerAmount: number, dealState, rng: Random?)
	local random = rng or Random.new()
	local askingPrice = dealState.askingPrice
	local minimumAccept = dealState.minimumAccept
	local maxPatience = dealState.maxPatience or HaggleTuning.startingPatience
	local patience = dealState.patience or maxPatience

	local ratio = offerAmount / math.max(askingPrice, 1)
	local temper = customer.temper or 0.5
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0

	local patienceDelta = 0
	local outcome = "reject"
	local counterOffer: number? = nil

	if offerAmount >= minimumAccept then
		local acceptChance = HaggleTuning.acceptChanceBase
			+ desperation * HaggleTuning.acceptChanceDesperationScale
			- knowledge * HaggleTuning.acceptChanceKnowledgePenalty
		if offerAmount >= askingPrice * HaggleTuning.nearAskAcceptRatio then
			acceptChance = HaggleTuning.acceptChanceNearAsk
		end

		if random:NextNumber() <= acceptChance or offerAmount >= askingPrice then
			outcome = "accept"
			patienceDelta = 0
		else
			outcome = "counter"
			counterOffer = HaggleMath.calculateCounterOffer(customer, item, offerAmount, askingPrice, minimumAccept, random)
			patienceDelta = patienceLoss(HaggleTuning.patienceLossCounterNearAccept, temper)
		end
	elseif ratio >= HaggleTuning.offerRatioCounter then
		outcome = "counter"
		counterOffer = HaggleMath.calculateCounterOffer(customer, item, offerAmount, askingPrice, minimumAccept, random)
		patienceDelta = patienceLoss(HaggleTuning.patienceLossCounter, temper)
	elseif ratio >= HaggleTuning.offerRatioReject then
		outcome = "reject"
		patienceDelta = patienceLoss(HaggleTuning.patienceLossReject, temper)
	else
		outcome = "reject"
		patienceDelta = patienceLoss(HaggleTuning.patienceLossInsult, temper)
	end

	local newPatience = patience + patienceDelta
	if newPatience <= 0 and outcome ~= "accept" then
		outcome = "walkaway"
		counterOffer = nil
	end

	return {
		outcome = outcome,
		patienceDelta = patienceDelta,
		offerRatio = ratio,
		reactionText = HaggleMath.getReactionText(customer, outcome, ratio, rng),
		counterOffer = counterOffer,
	}
end

function HaggleMath.getReactionText(customer, outcome: string, offerRatio: number, rng: Random?): string
	local reactions = customer.reactions
	local band = HaggleMath.getOfferRatioBand(offerRatio)

	if reactions then
		if outcome == "accept" and reactions.accept then
			return pickReaction(reactions.accept, rng)
		elseif outcome == "counter" then
			if band == "close" and reactions.counter_close then
				return pickReaction(reactions.counter_close, rng)
			elseif reactions.counter then
				return pickReaction(reactions.counter, rng)
			end
		elseif outcome == "walkaway" and reactions.walkaway then
			return pickReaction(reactions.walkaway, rng)
		elseif outcome == "reject" then
			if band == "insult" and reactions.reject_insult then
				return pickReaction(reactions.reject_insult, rng)
			elseif reactions.reject_low then
				return pickReaction(reactions.reject_low, rng)
			end
		end
	end

	if outcome == "accept" then
		return pickReaction(REACTIONS.accept, rng)
	elseif outcome == "counter" then
		return pickReaction(REACTIONS.counter, rng)
	elseif outcome == "walkaway" then
		return pickReaction(REACTIONS.walkaway, rng)
	elseif band == "insult" then
		return pickReaction(REACTIONS.reject_insult, rng)
	end

	return pickReaction(REACTIONS.reject_low, rng)
end

return HaggleMath
