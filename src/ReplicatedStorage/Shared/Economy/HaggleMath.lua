local HaggleTuning = require(script.Parent.Parent.Config.HaggleTuning)

local HaggleMath = {}

local REACTIONS = {
	accept = {
		"Deal. Hand over the scraps.",
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
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
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

function HaggleMath.getMinAskRatio(customer): number
	return customer.minAskRatio or HaggleTuning.minOfferRatioOfAsk
end

function HaggleMath.calculateEffectiveMinimum(customer, minimumAccept: number, askingPrice: number): number
	local askFloor = askingPrice * HaggleMath.getMinAskRatio(customer)
	return clamp(math.max(minimumAccept, askFloor), 1, askingPrice)
end

function HaggleMath.getRequiredNextOffer(dealState): number?
	if dealState.phase == "Counter" and dealState.counterOffer then
		return dealState.counterOffer
	end
	if dealState.effectiveMinimum then
		return dealState.effectiveMinimum
	end
	return nil
end

function HaggleMath.getMinRaiseAmount(askingPrice: number): number
	local percentRaise = math.floor(askingPrice * HaggleTuning.minRaiseStepAskPercent)
	return math.max(HaggleTuning.minRaiseStepCaps, percentRaise)
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
	rng: Random?,
	previousCounter: number?
): number
	local random = rng or Random.new()
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0

	local gap = askingPrice - offerAmount
	local midpoint = (offerAmount + askingPrice) / 2
	local counter = midpoint + gap * (HaggleTuning.counterMidBias + greed * HaggleTuning.counterGreedBias)
	counter -= desperation * gap * HaggleTuning.counterDesperationBias
	counter += random:NextNumber(-3, HaggleTuning.counterJitter)
	counter = clamp(counter, minimumAccept, askingPrice)

	if previousCounter then
		local slip = math.floor(HaggleTuning.counterDesperationSlip * desperation)
		counter = math.max(counter, previousCounter - slip)
	end

	return clamp(counter, minimumAccept, askingPrice)
end

local function applyPatienceWalkaway(patience: number, patienceDelta: number, outcome: string, counterOffer: number?)
	local newPatience = patience + patienceDelta
	if newPatience <= 0 and outcome ~= "accept" then
		return "walkaway", nil, newPatience
	end
	return outcome, counterOffer, newPatience
end

function HaggleMath.evaluateOffer(customer, item, offerAmount: number, dealState, rng: Random?)
	local random = rng or Random.new()
	local askingPrice = dealState.askingPrice
	local minimumAccept = dealState.minimumAccept
	local effectiveMinimum = dealState.effectiveMinimum
		or HaggleMath.calculateEffectiveMinimum(customer, minimumAccept, askingPrice)
	local maxPatience = dealState.maxPatience or HaggleTuning.startingPatience
	local patience = dealState.patience or maxPatience

	local ratio = offerAmount / math.max(askingPrice, 1)
	local temper = customer.temper or 0.5
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0

	local patienceDelta = 0
	local outcome = "reject"
	local counterOffer: number? = nil
	local repeatBlocked = false
	local blockAccept = false

	local lastOffer = dealState.lastOfferAmount
	local repeatStreak = 0
	if lastOffer and offerAmount <= lastOffer then
		repeatStreak = (dealState.repeatOfferStreak or 0) + 1
		patienceDelta += patienceLoss(HaggleTuning.patienceLossRepeat, temper)
		if repeatStreak >= HaggleTuning.repeatOfferWalkawayAt then
			outcome = "walkaway"
			blockAccept = true
			repeatBlocked = true
			patienceDelta += patienceLoss(HaggleTuning.patienceLossInsult, temper)
		elseif repeatStreak >= HaggleTuning.repeatBlockAcceptAt then
			blockAccept = true
			repeatBlocked = true
		end
	end

	if not blockAccept and dealState.phase == "Counter" and dealState.counterOffer then
		if offerAmount < dealState.counterOffer then
			blockAccept = true
			patienceDelta += patienceLoss(HaggleTuning.patienceLossBelowCounter, temper)
			outcome = "reject"
			if temper >= HaggleTuning.lowballInstantWalkawayTemper and random:NextNumber() < 0.4 then
				outcome = "walkaway"
			end
		elseif dealState.bestOfferAmount and offerAmount < dealState.bestOfferAmount then
			blockAccept = true
			patienceDelta += patienceLoss(HaggleTuning.patienceLossReject, temper)
			outcome = "reject"
		end
	end

	if
		not blockAccept
		and dealState.phase == "Counter"
		and dealState.counterOffer
		and offerAmount >= dealState.counterOffer
	then
		outcome = "accept"
		patienceDelta = 0
	elseif not blockAccept and not repeatBlocked then
		if offerAmount >= effectiveMinimum then
			local canRollAccept = true
			if dealState.phase == "Counter" and dealState.counterOffer then
				local minRaise = HaggleMath.getMinRaiseAmount(askingPrice)
				local improvedEnough = offerAmount >= dealState.counterOffer
					or (dealState.bestOfferAmount and offerAmount >= dealState.bestOfferAmount + minRaise)
				canRollAccept = improvedEnough
			end

			if canRollAccept then
				local acceptChance = HaggleTuning.acceptChanceBase
					+ desperation * HaggleTuning.acceptChanceDesperationScale
					- knowledge * HaggleTuning.acceptChanceKnowledgePenalty
				if offerAmount >= askingPrice * HaggleTuning.nearAskAcceptRatio then
					acceptChance = HaggleTuning.acceptChanceNearAsk
				end
				if repeatStreak >= 1 then
					acceptChance *= 0.35
				end

				if random:NextNumber() <= acceptChance or offerAmount >= askingPrice then
					outcome = "accept"
					patienceDelta = 0
				else
					outcome = "counter"
					counterOffer = HaggleMath.calculateCounterOffer(
						customer,
						item,
						offerAmount,
						askingPrice,
						effectiveMinimum,
						random,
						dealState.counterOffer
					)
					patienceDelta += patienceLoss(HaggleTuning.patienceLossCounterNearAccept, temper)
				end
			else
				outcome = "counter"
				counterOffer = HaggleMath.calculateCounterOffer(
					customer,
					item,
					offerAmount,
					askingPrice,
					effectiveMinimum,
					random,
					dealState.counterOffer
				)
				patienceDelta += patienceLoss(HaggleTuning.patienceLossCounter, temper)
			end
		elseif ratio >= HaggleTuning.offerRatioCounter then
			outcome = "counter"
			counterOffer = HaggleMath.calculateCounterOffer(
				customer,
				item,
				offerAmount,
				askingPrice,
				effectiveMinimum,
				random,
				dealState.counterOffer
			)
			patienceDelta += patienceLoss(HaggleTuning.patienceLossCounter, temper)
		elseif ratio >= HaggleTuning.offerRatioReject then
			outcome = "reject"
			patienceDelta += patienceLoss(HaggleTuning.patienceLossReject, temper)
		else
			outcome = "reject"
			patienceDelta += patienceLoss(HaggleTuning.patienceLossInsult, temper)
		end
	end

	outcome, counterOffer, patience = applyPatienceWalkaway(patience, patienceDelta, outcome, counterOffer)

	local dialogueOverride = nil
	if not blockAccept and dealState.phase == "Counter" and dealState.counterOffer and offerAmount < dealState.counterOffer then
		dialogueOverride = `I already said {dealState.counterOffer} scraps.`
	end

	local reactionText = dialogueOverride or HaggleMath.getReactionText(customer, outcome, ratio, rng)

	return {
		outcome = outcome,
		patienceDelta = patienceDelta,
		offerRatio = ratio,
		reactionText = reactionText,
		dialogueOverride = dialogueOverride,
		counterOffer = counterOffer,
		repeatStreak = repeatStreak,
		repeatBlocked = repeatBlocked,
		requiredNextOffer = HaggleMath.getRequiredNextOffer({
			phase = if counterOffer then "Counter" else dealState.phase,
			counterOffer = counterOffer,
			effectiveMinimum = effectiveMinimum,
		}),
	}
end

function HaggleMath.evaluateLowball(customer, item, offerAmount: number, dealState, rng: Random?)
	local random = rng or Random.new()
	local askingPrice = dealState.askingPrice
	local trueValue = dealState.hiddenOutcome and dealState.hiddenOutcome.trueValue or askingPrice
	local ratio = offerAmount / math.max(askingPrice, 1)
	local temper = customer.temper or 0.5
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0
	local scamBias = customer.scamBias or 0

	if ratio > HaggleTuning.lowballMaxRatio then
		return {
			outcome = "reject",
			lowballResult = "invalid",
			patienceDelta = 0,
			reactionText = "That's not a lowball.",
			repeatStreak = dealState.repeatOfferStreak or 0,
			repeatBlocked = false,
		}
	end

	local usefulRatio = HaggleTuning.lowballMinUsefulRatio or 0.3
	local lowballQuality = math.clamp(
		(ratio - usefulRatio) / math.max(HaggleTuning.lowballMaxRatio - usefulRatio, 0.01),
		0,
		1
	)
	local stealChance = (HaggleTuning.lowballStealBase + desperation * HaggleTuning.lowballStealDesperationScale)
		* lowballQuality
	local crackChance = (
		HaggleTuning.lowballCrackBase
		+ desperation * HaggleTuning.lowballCrackDesperationScale
		- knowledge * HaggleTuning.lowballCrackKnowledgeScale
	) * lowballQuality
	crackChance = math.clamp(crackChance, HaggleTuning.lowballCrackMin, HaggleTuning.lowballCrackMax)
	local roll = random:NextNumber()

	if roll <= stealChance then
		local reaction = pickReaction(customer.reactions and customer.reactions.lowball_steal or REACTIONS.accept, random)
		return {
			outcome = "accept",
			lowballResult = "steal",
			patienceDelta = 0,
			reactionText = reaction,
			repeatStreak = 0,
			repeatBlocked = false,
		}
	end

	if roll <= stealChance + crackChance then
		local reaction = pickReaction(customer.reactions and customer.reactions.lowball_crack or {
			"You might be onto something...",
			"Fine, think what you want.",
			"Don't push your luck.",
		}, random)
		return {
			outcome = "crack",
			lowballResult = "crack",
			patienceDelta = -math.floor(4 + temper * 3),
			reactionText = reaction,
			repeatStreak = dealState.repeatOfferStreak or 0,
			repeatBlocked = false,
		}
	end

	local patienceDelta = patienceLoss(HaggleTuning.patienceLossInsult, temper)
	patienceDelta -= math.floor(HaggleTuning.lowballOffendedTemperScale * temper * 10)

	local outcome = "reject"
	if temper >= HaggleTuning.lowballInstantWalkawayTemper and random:NextNumber() < 0.35 + temper * 0.25 then
		outcome = "walkaway"
		patienceDelta = -dealState.patience
	end

	local newPatience = (dealState.patience or 100) + patienceDelta
	if newPatience <= 0 and outcome ~= "walkaway" then
		outcome = "walkaway"
	end

	local scamCallout = false
	if
		scamBias > 0.2
		and lowballQuality > 0
		and not dealState.scamCalloutUsed
		and random:NextNumber() < HaggleTuning.lowballScamCalloutChance * lowballQuality
	then
		scamCallout = true
	end

	local reaction = pickReaction(customer.reactions and customer.reactions.lowball_offended or REACTIONS.reject_insult, random)

	return {
		outcome = outcome,
		lowballResult = if scamCallout then "scam_callout" else "offended",
		patienceDelta = patienceDelta,
		reactionText = reaction,
		scamCallout = scamCallout,
		repeatStreak = dealState.repeatOfferStreak or 0,
		repeatBlocked = false,
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

-- Sell-side: player pushes sale price up; buyer opens low and may counter upward.

function HaggleMath.getBuyerStartingPatience(buyer): number
	return HaggleMath.getStartingPatience(buyer)
end

function HaggleMath.calculateBuyerOpeningOffer(buyer, trueValue: number, rng: Random?): number
	local random = rng or Random.new()
	local greed = buyer.greed or 0
	local urgency = buyer.urgency or 0
	local ratio = HaggleTuning.buyerOfferBaseRatio - greed * HaggleTuning.buyerOfferGreedPenalty + urgency * HaggleTuning.buyerOfferUrgencyBonus
	ratio += random:NextNumber(-0.05, 0.05)
	return clamp(trueValue * ratio, 1, 999999)
end

function HaggleMath.calculateBuyerMaximum(buyer, trueValue: number): number
	local greed = buyer.greed or 0
	local urgency = buyer.urgency or 0
	local knowledge = buyer.knowledge or 0
	local ratio = HaggleTuning.buyerMaximumBaseRatio
		+ urgency * HaggleTuning.buyerMaximumUrgencyBonus
		- greed * 0.1
		- knowledge * HaggleTuning.buyerMaximumKnowledgePenalty
	return clamp(trueValue * ratio, 1, 999999)
end

function HaggleMath.calculateBuyerCounterOffer(
	buyer,
	playerAsk: number,
	buyerOffer: number,
	buyerMaximum: number,
	rng: Random?,
	previousCounter: number?
): number
	local random = rng or Random.new()
	local gap = playerAsk - buyerOffer
	local counter = buyerOffer + gap * (HaggleTuning.sellCounterStepRatio + (buyer.urgency or 0) * 0.2)
	counter += random:NextNumber(-4, 8)
	counter = clamp(counter, buyerOffer + 1, buyerMaximum)

	if previousCounter then
		counter = math.max(counter, previousCounter)
	end

	return clamp(counter, buyerOffer + 1, buyerMaximum)
end

function HaggleMath.getBuyerReactionText(buyer, outcome: string, rng: Random?): string
	local reactions = buyer.reactions
	if reactions then
		if outcome == "accept" and reactions.accept then
			return pickReaction(reactions.accept, rng)
		elseif outcome == "counter" and reactions.counter then
			return pickReaction(reactions.counter, rng)
		elseif outcome == "walkaway" and reactions.walkaway then
			return pickReaction(reactions.walkaway, rng)
		elseif reactions.reject then
			return pickReaction(reactions.reject, rng)
		end
	end
	return pickReaction(REACTIONS.reject_low, rng)
end

function HaggleMath.evaluateSellAsk(buyer, trueValue: number, playerAsk: number, dealState, rng: Random?)
	local random = rng or Random.new()
	local buyerOffer = dealState.buyerOffer or 0
	local buyerMaximum = dealState.buyerMaximum or trueValue
	local patience = dealState.buyerPatience or HaggleTuning.startingPatience
	local temper = buyer.temper or 0.5
	local urgency = buyer.urgency or 0
	local knowledge = buyer.knowledge or 0

	local patienceDelta = 0
	local outcome = "reject"
	local counterOffer: number? = nil
	local repeatBlocked = false

	local lastAsk = dealState.lastSellAsk
	local repeatStreak = 0
	if lastAsk and playerAsk <= lastAsk then
		repeatStreak = (dealState.sellRepeatStreak or 0) + 1
		patienceDelta += patienceLoss(HaggleTuning.patienceLossRepeat, temper)
		if repeatStreak >= HaggleTuning.sellRepeatWalkawayAt then
			outcome = "walkaway"
			repeatBlocked = true
			patienceDelta += patienceLoss(HaggleTuning.patienceLossInsult, temper)
		elseif repeatStreak >= HaggleTuning.sellRepeatBlockAt then
			repeatBlocked = true
		end
	end

	if not repeatBlocked and dealState.phase == "BuyerCounter" and dealState.buyerCounterOffer then
		if playerAsk < dealState.buyerCounterOffer then
			repeatBlocked = true
			outcome = "reject"
			patienceDelta += patienceLoss(HaggleTuning.patienceLossBelowCounter, temper)
			if temper >= 0.55 and random:NextNumber() < 0.35 then
				outcome = "walkaway"
			end
		end
	end

	if not repeatBlocked then
		if playerAsk <= buyerOffer then
			outcome = "accept"
			patienceDelta = 0
		elseif playerAsk <= buyerMaximum then
			local acceptChance = HaggleTuning.sellAcceptChanceBase
				+ urgency * HaggleTuning.sellAcceptUrgencyScale
				- knowledge * HaggleTuning.sellAcceptKnowledgePenalty
			if repeatStreak >= 1 then
				acceptChance *= 0.3
			end

			if random:NextNumber() <= acceptChance then
				outcome = "accept"
				patienceDelta = 0
			else
				outcome = "counter"
				counterOffer = HaggleMath.calculateBuyerCounterOffer(
					buyer,
					playerAsk,
					buyerOffer,
					buyerMaximum,
					random,
					dealState.buyerCounterOffer
				)
				patienceDelta += patienceLoss(HaggleTuning.patienceLossCounter, temper)
			end
		else
			outcome = "reject"
			patienceDelta += patienceLoss(HaggleTuning.patienceLossInsult, temper)
			if temper >= 0.6 and random:NextNumber() < 0.35 + temper * 0.2 then
				outcome = "walkaway"
			end
		end
	end

	local newPatience = patience + patienceDelta
	if newPatience <= 0 and outcome ~= "accept" then
		outcome = "walkaway"
		counterOffer = nil
	end

	local dialogueOverride = nil
	if dealState.phase == "BuyerCounter" and dealState.buyerCounterOffer and playerAsk > dealState.buyerCounterOffer then
		dialogueOverride = `I won't go above {dealState.buyerCounterOffer} scraps.`
	end

	local salePrice = nil
	if outcome == "accept" then
		salePrice = if playerAsk <= buyerOffer then buyerOffer else math.min(playerAsk, buyerMaximum)
	end

	return {
		outcome = outcome,
		patienceDelta = patienceDelta,
		reactionText = dialogueOverride or HaggleMath.getBuyerReactionText(buyer, outcome, rng),
		dialogueOverride = dialogueOverride,
		buyerCounterOffer = counterOffer,
		salePrice = salePrice,
		repeatStreak = repeatStreak,
		repeatBlocked = repeatBlocked,
		requiredNextOffer = if counterOffer then counterOffer else buyerOffer,
	}
end

return HaggleMath
