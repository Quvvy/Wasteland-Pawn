local HaggleTuning = require(script.Parent.Parent.Config.HaggleTuning)
local HaggleTactics = require(script.Parent.HaggleTactics)
local ItemValuation = require(script.Parent.ItemValuation)

local TacticHaggleMath = {}

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

local function pick(pool: { string }, rng: Random?): string
	if not pool or #pool == 0 then
		return "..."
	end
	local random = rng or Random.new()
	return pool[random:NextInteger(1, #pool)]
end

-- Archetype tactic fit: -1 bad .. +1 great
local SELLER_MATCH = {
	[HaggleTactics.Buy.Lowball] = {
		desperate_survivor = 0.95,
		nervous_rookie = 0.75,
		mutant_drifter = 0.5,
		alien_tourist = 0.35,
		shady_scammer = -0.5,
		rich_collector = -0.85,
		soldier = -0.7,
		junk_dealer = -0.55,
		robot_trader = -0.4,
		silent_stranger = -0.2,
	},
	[HaggleTactics.Buy.SplitDifference] = {
		desperate_survivor = 0.6,
		soldier = 0.7,
		robot_trader = 0.75,
		junk_dealer = 0.5,
		rich_collector = 0.35,
		shady_scammer = 0.2,
		mutant_drifter = 0.4,
		nervous_rookie = 0.55,
		alien_tourist = 0.45,
		silent_stranger = 0.3,
	},
	[HaggleTactics.Buy.PointOutFlaw] = {
		shady_scammer = 0.95,
		junk_dealer = 0.55,
		robot_trader = 0.7,
		rich_collector = 0.25,
		desperate_survivor = 0.35,
		soldier = 0.4,
		nervous_rookie = 0.45,
		mutant_drifter = 0.3,
		alien_tourist = 0.5,
		silent_stranger = 0.15,
	},
	[HaggleTactics.Buy.Pressure] = {
		desperate_survivor = 0.9,
		nervous_rookie = 0.65,
		mutant_drifter = 0.7,
		shady_scammer = 0.15,
		rich_collector = -0.8,
		soldier = -0.65,
		junk_dealer = -0.35,
		robot_trader = -0.5,
		alien_tourist = 0.25,
		silent_stranger = -0.15,
	},
}

local BUYER_MATCH = {
	[HaggleTactics.Sell.SmallBump] = {
		cheap_scavenger = 0.55,
		robot_appraiser = 0.6,
		black_market_dealer = 0.45,
		rich_collector = 0.5,
		desperate_mechanic = 0.55,
		alien_tourist = 0.5,
	},
	[HaggleTactics.Sell.PitchValue] = {
		rich_collector = 0.85,
		desperate_mechanic = 0.8,
		alien_tourist = 0.7,
		robot_appraiser = 0.35,
		cheap_scavenger = -0.35,
		black_market_dealer = 0.4,
	},
	[HaggleTactics.Sell.HoldFirm] = {
		black_market_dealer = 0.55,
		soldier = 0.5,
		rich_collector = 0.35,
		robot_appraiser = 0.25,
		cheap_scavenger = -0.55,
		desperate_mechanic = 0.45,
		alien_tourist = 0.3,
	},
	[HaggleTactics.Sell.Bluff] = {
		alien_tourist = 0.75,
		desperate_mechanic = 0.55,
		black_market_dealer = 0.35,
		rich_collector = -0.45,
		cheap_scavenger = -0.7,
		robot_appraiser = -0.65,
	},
}

local BUY_DIALOGUE = {
	split_good = { "Fine. I'll meet you halfway.", "Alright. A fair split.", "I can move on that." },
	split_neutral = { "Hmm. Maybe a little.", "I'll budge some.", "Not thrilled, but okay." },
	lowball_good = { "Okay... take it before I change my mind.", "You're killing me. Deal.", "Fine! Just go." },
	lowball_bad = { "That's insulting.", "You trying to rob me?", "Absolutely not." },
	flaw_good = { "You caught me. Price drops.", "Okay, it's not perfect.", "Fair point on the flaws." },
	pressure_good = { "Stop. You're right, I need this gone.", "Alright, you win.", "Fine. Pressure worked." },
	pressure_bad = { "Don't push me.", "Back off.", "I don't respond to threats." },
	sell_small = { "A little more? Fine.", "Small bump. Deal.", "Okay, slightly higher." },
	sell_pitch = { "You make a good case.", "I'll stretch for that.", "Convincing pitch." },
	sell_hold = { "You're tough. Fine.", "Respect. Higher offer.", "Alright, you held firm." },
	sell_bluff_win = { "Wow. Okay. Big number.", "You're crazy. I pay it.", "Fine! Take your scraps!" },
	sell_bluff_fail = { "You're dreaming.", "No. Absurd.", "Walk away from that number." },
	warn = {
		"Careful. I'm almost done here.",
		"You're pushing it.",
		"One more stunt and I walk.",
		"Last chance.",
	},
}

function TacticHaggleMath.getHeatWarning(heat: number): string?
	if heat >= HaggleTuning.heatWalkThreshold then
		return "They're done. Deal or walk."
	elseif heat >= HaggleTuning.heatWarningThreshold then
		return pick(BUY_DIALOGUE.warn)
	end
	return nil
end

function TacticHaggleMath.getSellerMatch(customer, tacticId: string): number
	local tableForTactic = SELLER_MATCH[tacticId]
	if tableForTactic and tableForTactic[customer.id] then
		return tableForTactic[customer.id]
	end

	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0
	local temper = customer.temper or 0
	local scam = customer.scamBias or 0

	if tacticId == HaggleTactics.Buy.Lowball then
		return desperation * 0.9 - knowledge * 0.5 - temper * 0.3
	elseif tacticId == HaggleTactics.Buy.SplitDifference then
		return 0.45 - temper * 0.15
	elseif tacticId == HaggleTactics.Buy.PointOutFlaw then
		return scam * 0.8 + knowledge * 0.1 - temper * 0.2
	elseif tacticId == HaggleTactics.Buy.Pressure then
		return desperation * 0.85 - knowledge * 0.4 - temper * 0.45
	end
	return 0
end

function TacticHaggleMath.getBuyerMatch(buyer, tacticId: string, categoryMatch: number): number
	local tableForTactic = BUYER_MATCH[tacticId]
	local base = 0
	if tableForTactic and tableForTactic[buyer.id] then
		base = tableForTactic[buyer.id]
	end

	if tacticId == HaggleTactics.Sell.PitchValue then
		return base + categoryMatch * 0.5
	elseif tacticId == HaggleTactics.Sell.Bluff then
		return base + categoryMatch * 0.25
	end
	return base + categoryMatch * 0.2
end

function TacticHaggleMath.getBuyerCategoryMatch(buyer, category: string): number
	local prefs = buyer.categoryPreferences
	if not prefs then
		return 0
	end
	local entry = prefs[category] or prefs.default
	if not entry then
		return 0
	end
	local open = entry.open or 1
	local max = entry.max or 1
	return math.clamp((open + max) / 2 - 1, -0.2, 0.45)
end

function TacticHaggleMath.calculateAskingPrice(customer, trueValue: number, rng: Random?): number
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

function TacticHaggleMath.calculateMinimumAccept(customer, item, trueValue: number, askingPrice: number): number
	local greed = customer.greed or 0
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0
	local valueRatio = HaggleTuning.minAcceptValueBase
		+ greed * HaggleTuning.minAcceptGreed
		- desperation * HaggleTuning.minAcceptDesperation
		+ knowledge * HaggleTuning.minAcceptKnowledge
	valueRatio = math.clamp(valueRatio, HaggleTuning.minAcceptFloorOfTrue, HaggleTuning.minAcceptCeilingOfTrue)
	local floorFromValue = trueValue * valueRatio
	local floorFromAsk = askingPrice * (HaggleTuning.minAcceptAskFactor - desperation * 0.2 + greed * 0.06)
	return clamp(math.max(floorFromValue, floorFromAsk), math.floor(trueValue * HaggleTuning.minAcceptFloorOfTrue), askingPrice)
end

function TacticHaggleMath.getBuyerCategoryMultipliers(buyer, category: string): (number, number)
	local prefs = buyer.categoryPreferences
	if not prefs then
		return 1, 1
	end
	local entry = prefs[category] or prefs.default
	if not entry then
		return 1, 1
	end
	return entry.open or 1, entry.max or 1
end

function TacticHaggleMath.calculateBuyerOpeningOffer(buyer, trueValue: number, category: string, rng: Random?): number
	local random = rng or Random.new()
	local openMult, _ = TacticHaggleMath.getBuyerCategoryMultipliers(buyer, category)
	local ratio = (
		HaggleTuning.buyerOfferBaseRatio
		- (buyer.greed or 0) * HaggleTuning.buyerOfferGreedPenalty
		+ (buyer.urgency or 0) * HaggleTuning.buyerOfferUrgencyBonus
	) * openMult
	ratio += random:NextNumber(-HaggleTuning.buyerOfferJitter, HaggleTuning.buyerOfferJitter)
	if buyer.id == "alien_tourist" then
		ratio += random:NextNumber(-0.1, 0.15)
	end
	return clamp(trueValue * ratio, 1, 999999)
end

function TacticHaggleMath.calculateBuyerMaximum(buyer, trueValue: number, category: string): number
	local _, maxMult = TacticHaggleMath.getBuyerCategoryMultipliers(buyer, category)
	local ratio = (
		HaggleTuning.buyerMaximumBaseRatio
		+ (buyer.urgency or 0) * HaggleTuning.buyerMaximumUrgencyBonus
		- (buyer.greed or 0) * HaggleTuning.buyerMaximumGreedPenalty
		- (buyer.knowledge or 0) * HaggleTuning.buyerMaximumKnowledgePenalty
	) * maxMult
	return clamp(trueValue * ratio, 1, 999999)
end

function TacticHaggleMath.evaluateBuyTactic(tacticId: string, ctx): any
	local customer = ctx.customer
	local rng = ctx.rng or Random.new()
	local price = ctx.currentSellerPrice
	local floor = ctx.minimumAccept
	local trueValue = ctx.trueValue
	local heat = ctx.sellerHeat or 0
	local heatMax = ctx.sellerHeatMax or HaggleTuning.heatMax
	local match = TacticHaggleMath.getSellerMatch(customer, tacticId)

	local baseHeat = 0
	local dropRatio = 0
	local dialoguePool = BUY_DIALOGUE.split_neutral
	local outcome = "price_drop"
	local walkedAway = false
	local bigWin = false
	local crack = false

	if ctx.lastTactic == tacticId then
		heat += HaggleTuning.heatRepeatTactic
	end

	if tacticId == HaggleTactics.Buy.SplitDifference then
		baseHeat = HaggleTuning.heatBuySplit
		dropRatio = HaggleTuning.buySplitDropRatio
		dialoguePool = if match >= 0.4 then BUY_DIALOGUE.split_good else BUY_DIALOGUE.split_neutral
	elseif tacticId == HaggleTactics.Buy.PointOutFlaw then
		baseHeat = HaggleTuning.heatBuyFlaw
		dropRatio = HaggleTuning.buyFlawDropRatio
		if ctx.inspected then
			dropRatio += HaggleTuning.buyInspectFlawBonus
		end
		if ctx.estimateInflated or (customer.scamBias or 0) > 0.35 then
			dropRatio += HaggleTuning.buyScamFlawBonus
			match += 0.35
		end
		if ctx.rarityId == "Common" or (trueValue and trueValue < 40) then
			dropRatio += 0.08
		end
		dialoguePool = BUY_DIALOGUE.flaw_good
	elseif tacticId == HaggleTactics.Buy.Pressure then
		baseHeat = HaggleTuning.heatBuyPressure
		dropRatio = HaggleTuning.buyPressureDropRatio
		dialoguePool = if match >= 0.35 then BUY_DIALOGUE.pressure_good else BUY_DIALOGUE.pressure_bad
	elseif tacticId == HaggleTactics.Buy.Lowball then
		baseHeat = HaggleTuning.heatBuyLowball
		dropRatio = if match >= 0.5 then HaggleTuning.buyLowballBigWinRatio else HaggleTuning.buyLowballDropRatio
		dialoguePool = if match >= 0.35 then BUY_DIALOGUE.lowball_good else BUY_DIALOGUE.lowball_bad
	else
		return { ok = false, error = "Unknown buy tactic" }
	end

	if match < 0 then
		baseHeat += HaggleTuning.heatMismatchBonus
	elseif match >= 0.5 then
		baseHeat = math.max(0, baseHeat - HaggleTuning.heatGoodMatchReduction)
		dropRatio += 0.08
	end

	local gap = price - floor
	local drop = math.max(math.floor(gap * dropRatio), math.floor(price * 0.08))
	if match >= 0.7 and tacticId == HaggleTactics.Buy.Lowball then
		drop = math.max(drop, math.floor(gap * 0.65))
		bigWin = true
	end

	local newPrice = clamp(price - drop, floor, price)
	local heatDelta = baseHeat
	local newHeat = math.min(heat + heatDelta, heatMax + 20)

	local walkRoll = if match < 0
		then HaggleTuning.buyLowballWalkChanceBad
		else HaggleTuning.buyLowballWalkChanceGood
	if tacticId == HaggleTactics.Buy.Lowball and rng:NextNumber() < walkRoll and match < 0.2 then
		walkedAway = true
		outcome = "walkaway"
	elseif newHeat >= HaggleTuning.heatWalkThreshold then
		if rng:NextNumber() < HaggleTuning.tacticWalkChanceAtHighHeat then
			walkedAway = true
			outcome = "walkaway"
		else
			outcome = "warning"
		end
	elseif newHeat >= HaggleTuning.heatWarningThreshold then
		outcome = "warning"
	end

	if tacticId == HaggleTactics.Buy.Lowball and match >= 0.45 and rng:NextNumber() < 0.22 then
		crack = true
		outcome = "crack"
	end

	if newPrice <= trueValue * 0.55 and trueValue > 50 then
		bigWin = true
		outcome = if outcome == "warning" then "big_win" else outcome
	end

	local warning = TacticHaggleMath.getHeatWarning(newHeat)

	return {
		ok = true,
		outcome = outcome,
		priceDelta = newPrice - price,
		newPrice = newPrice,
		heatDelta = heatDelta,
		newHeat = newHeat,
		dialogue = pick(dialoguePool, rng),
		warning = warning,
		walkedAway = walkedAway,
		bigWin = bigWin,
		crack = crack,
		readText = `match={string.format("%.2f", match)} drop={drop}`,
	}
end

function TacticHaggleMath.evaluateSellTactic(tacticId: string, ctx): any
	local buyer = ctx.buyer
	local rng = ctx.rng or Random.new()
	local offer = ctx.currentBuyerOffer
	local maxOffer = ctx.buyerMaximum
	local trueValue = ctx.trueValue
	local heat = ctx.buyerHeat or 0
	local heatMax = ctx.buyerHeatMax or HaggleTuning.heatMax
	local categoryMatch = TacticHaggleMath.getBuyerCategoryMatch(buyer, ctx.itemCategory or "")
	local match = TacticHaggleMath.getBuyerMatch(buyer, tacticId, categoryMatch)

	local baseHeat = 0
	local raiseRatio = 0
	local dialoguePool = BUY_DIALOGUE.sell_small
	local outcome = "price_raise"
	local walkedAway = false
	local bigWin = false

	if ctx.lastTactic == tacticId then
		heat += HaggleTuning.heatRepeatTactic
	end

	if tacticId == HaggleTactics.Sell.SmallBump then
		baseHeat = HaggleTuning.heatSellSmallBump
		raiseRatio = HaggleTuning.sellSmallBumpRatio
		dialoguePool = BUY_DIALOGUE.sell_small
	elseif tacticId == HaggleTactics.Sell.PitchValue then
		baseHeat = HaggleTuning.heatSellPitch
		raiseRatio = HaggleTuning.sellPitchRatio + categoryMatch * HaggleTuning.sellCategoryPitchBonus
		dialoguePool = BUY_DIALOGUE.sell_pitch
	elseif tacticId == HaggleTactics.Sell.HoldFirm then
		baseHeat = HaggleTuning.heatSellHoldFirm
		raiseRatio = HaggleTuning.sellHoldRatio
		dialoguePool = BUY_DIALOGUE.sell_hold
	elseif tacticId == HaggleTactics.Sell.Bluff then
		baseHeat = HaggleTuning.heatSellBluff
		raiseRatio = if match >= 0.4 then HaggleTuning.sellBluffBigWinRatio else HaggleTuning.sellBluffRatio
		dialoguePool = if match >= 0.35 then BUY_DIALOGUE.sell_bluff_win else BUY_DIALOGUE.sell_bluff_fail
	else
		return { ok = false, error = "Unknown sell tactic" }
	end

	if match < 0 then
		baseHeat += HaggleTuning.heatMismatchBonus
	elseif match >= 0.45 then
		baseHeat = math.max(0, baseHeat - HaggleTuning.heatGoodMatchReduction)
		raiseRatio += 0.1
	end

	if ctx.inspected and tacticId == HaggleTactics.Sell.PitchValue then
		raiseRatio += 0.06
	end

	local gap = maxOffer - offer
	local raise = math.max(math.floor(gap * raiseRatio), math.floor(offer * 0.08))
	if match >= 0.65 and tacticId == HaggleTactics.Sell.Bluff then
		raise = math.max(raise, math.floor(gap * 0.7))
		bigWin = true
	end

	local newOffer = clamp(offer + raise, offer + 1, maxOffer)
	if categoryMatch >= 0.25 and tacticId == HaggleTactics.Sell.PitchValue then
		newOffer = clamp(offer + math.floor(gap * (raiseRatio + 0.12)), offer + 1, maxOffer)
	end

	local heatDelta = baseHeat
	local newHeat = math.min(heat + heatDelta, heatMax + 20)

	local walkRoll = if match < 0 then HaggleTuning.sellBluffWalkChanceBad else HaggleTuning.sellBluffWalkChanceGood
	if tacticId == HaggleTactics.Sell.Bluff and match < 0.15 and rng:NextNumber() < walkRoll then
		walkedAway = true
		outcome = "walkaway"
	elseif newHeat >= HaggleTuning.heatWalkThreshold then
		if rng:NextNumber() < HaggleTuning.tacticWalkChanceAtHighHeat then
			walkedAway = true
			outcome = "walkaway"
		else
			outcome = "warning"
		end
	elseif newHeat >= HaggleTuning.heatWarningThreshold then
		outcome = "warning"
	end

	if newOffer >= trueValue * 1.15 and (ctx.purchasePrice or 0) > 0 then
		local profit = newOffer - ctx.purchasePrice
		if profit >= trueValue * 0.25 then
			bigWin = true
		end
	end

	local warning = TacticHaggleMath.getHeatWarning(newHeat)

	return {
		ok = true,
		outcome = outcome,
		priceDelta = newOffer - offer,
		newPrice = newOffer,
		heatDelta = heatDelta,
		newHeat = newHeat,
		dialogue = pick(dialoguePool, rng),
		warning = warning,
		walkedAway = walkedAway,
		bigWin = bigWin,
		readText = `match={string.format("%.2f", match)} raise={raise}`,
	}
end

return TacticHaggleMath
