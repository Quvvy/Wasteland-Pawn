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
	reject = {
		"That's insulting.",
		"You're wasting my time.",
		"No. Absolutely not.",
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
	local random = rng or Random.new()
	return pool[random:NextInteger(1, #pool)]
end

function HaggleMath.calculateAskingPrice(customer, trueValue: number, rng: Random?): number
	local random = rng or Random.new()
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0
	local scamBias = customer.scamBias or 0

	local markup = 1.08 + greed * 0.35 + scamBias * 0.25 - desperation * 0.22
	markup += random:NextNumber(-0.04, 0.06)

	return clamp(trueValue * markup, 1, 999999)
end

function HaggleMath.calculateMinimumAcceptPrice(customer, item, trueValue: number, askingPrice: number): number
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0

	local floorFromValue = trueValue * (0.72 + greed * 0.18 - desperation * 0.22 + knowledge * 0.08)
	local floorFromAsk = askingPrice * (0.55 - desperation * 0.12 + greed * 0.08)

	return clamp(math.max(floorFromValue, floorFromAsk * 0.5), 1, askingPrice)
end

function HaggleMath.calculateCounterOffer(customer, item, offerAmount: number, askingPrice: number, minimumAccept: number, rng: Random?): number
	local random = rng or Random.new()
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0

	local midpoint = (offerAmount + askingPrice) / 2
	local counter = midpoint + (askingPrice - offerAmount) * (0.25 + greed * 0.25)
	counter -= desperation * (askingPrice - offerAmount) * 0.15
	counter += random:NextNumber(-3, 6)

	return clamp(counter, minimumAccept, askingPrice)
end

function HaggleMath.evaluateOffer(
	customer,
	item,
	offerAmount: number,
	dealState,
	rng: Random?
)
	local random = rng or Random.new()
	local askingPrice = dealState.askingPrice
	local minimumAccept = dealState.minimumAccept
	local patience = dealState.patience or 100

	local ratio = offerAmount / math.max(askingPrice, 1)
	local temper = customer.temper or 0.5
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0

	local patienceDelta = 0
	local outcome = "reject"
	local counterOffer: number? = nil

	if offerAmount >= minimumAccept then
		local acceptChance = 0.55 + desperation * 0.35 - knowledge * 0.1
		if offerAmount >= askingPrice * 0.98 then
			acceptChance = 0.95
		end

		if random:NextNumber() <= acceptChance or offerAmount >= askingPrice then
			outcome = "accept"
			patienceDelta = 0
		else
			outcome = "counter"
			counterOffer = HaggleMath.calculateCounterOffer(customer, item, offerAmount, askingPrice, minimumAccept, random)
			patienceDelta = -math.floor(4 + temper * 4)
		end
	elseif ratio >= 0.78 then
		outcome = "counter"
		counterOffer = HaggleMath.calculateCounterOffer(customer, item, offerAmount, askingPrice, minimumAccept, random)
		patienceDelta = -math.floor(6 + temper * 6)
	elseif ratio >= 0.55 then
		outcome = "reject"
		patienceDelta = -math.floor(10 + temper * 12)
	else
		outcome = "reject"
		patienceDelta = -math.floor(16 + temper * 18)
	end

	local newPatience = patience + patienceDelta
	if newPatience <= 0 and outcome ~= "accept" then
		outcome = "walkaway"
		counterOffer = nil
	end

	return {
		outcome = outcome,
		patienceDelta = patienceDelta,
		reactionText = HaggleMath.getReactionText(customer, outcome, dealState, random),
		counterOffer = counterOffer,
	}
end

function HaggleMath.getReactionText(customer, outcome: string, dealState, rng: Random?): string
	if outcome == "accept" then
		return pickReaction(REACTIONS.accept, rng)
	elseif outcome == "counter" then
		return pickReaction(REACTIONS.counter, rng)
	elseif outcome == "walkaway" then
		return pickReaction(REACTIONS.walkaway, rng)
	end

	return pickReaction(REACTIONS.reject, rng)
end

return HaggleMath
