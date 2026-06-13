local HaggleTuning = require(script.Parent.Parent.Config.HaggleTuning)
local HaggleProfiles = require(script.Parent.Parent.Config.HaggleProfiles)
local HaggleTactics = require(script.Parent.HaggleTactics)

local TacticHaggleMath = {}

local Buy = HaggleTactics.Buy
local Sell = HaggleTactics.Sell

local STATE = {
	Open = "Open",
	Guarded = "Guarded",
	Suspicious = "Suspicious",
	Offended = "Offended",
	Worried = "Worried",
	Impatient = "Impatient",
	Confused = "Confused",
	Panicked = "Panicked",
	FinalOffer = "FinalOffer",
}

local BUY_DIALOGUE = {
	split_good = { "Fair split. That's as close as I get.", "Alright. I can move a little.", "Fine. Meet me there." },
	split_low = { "We already split it.", "Not much room left.", "That's barely moving me." },
	flaw_good = { "You caught the flaw. Price drops.", "Fine, it has problems.", "Alright, that point lands." },
	flaw_bad = { "You're reaching.", "Nothing wrong with it.", "Don't invent flaws." },
	pressure_good = { "Fine. I need this done.", "Alright, stop pushing.", "You win this round." },
	pressure_bad = { "Don't pressure me.", "Back off.", "Bad move." },
	lowball_good = { "That hurts. Fine.", "Take it before I regret this.", "You found my weak spot." },
	lowball_bad = { "Insulting.", "Try that again and I'm gone.", "Absolutely not." },
	final = { "Final offer. Take it or leave it.", "That's my final price.", "No more movement." },
	warn = { "Careful. I'm almost done here.", "You're pushing it.", "Last chance." },
}

local SELL_DIALOGUE = {
	small_good = { "Small bump. Fine.", "I can add a little.", "A little more, sure." },
	small_low = { "I already bumped it.", "Tiny movement, that's it.", "Don't milk it." },
	pitch_good = { "Good pitch. I'll stretch.", "That does make it more tempting.", "You make a case." },
	pitch_bad = { "Doesn't matter to me.", "Wrong pitch.", "Not convinced." },
	hold_good = { "Fine. Strong offer.", "You held firm. I'll meet it.", "That's near my final." },
	hold_bad = { "Firm on what?", "No leverage there.", "You're overplaying it." },
	bluff_good = { "Wait. Fine, big number.", "Alright, don't shop it around.", "You got me." },
	bluff_bad = { "Obvious bluff.", "No. I'm out if you keep that up.", "Dream on." },
	final = { "That's my final offer.", "Final. Take it or find someone else.", "No more scraps from me." },
	warn = { "Careful. I'm nearly done.", "You're pushing it.", "Last chance." },
}

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

local function clamp01(value: number): number
	return math.clamp(value, -1, 1)
end

local function clampStat(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function pick(pool: { string }, rng: Random?): string
	if not pool or #pool == 0 then
		return "..."
	end
	local random = rng or Random.new()
	return pool[random:NextInteger(1, #pool)]
end

local function getProfile(side: string, npc)
	if side == "buy" then
		return HaggleProfiles.Sellers[npc.id]
	end
	return HaggleProfiles.Buyers[npc.id]
end

local function profileFit(profile, tacticId: string): number
	if not profile then
		return 0
	end
	if profile.hates and profile.hates[tacticId] then
		return -0.75
	elseif profile.resists and profile.resists[tacticId] then
		return -0.35
	elseif profile.weakTo and profile.weakTo[tacticId] then
		return 0.45
	end
	return 0
end

function TacticHaggleMath.getHeatWarning(heat: number): string?
	if heat >= HaggleTuning.heatWalkThreshold then
		return "They're done. Deal or walk."
	elseif heat >= HaggleTuning.heatWarningThreshold then
		return pick(BUY_DIALOGUE.warn)
	end
	return nil
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

function TacticHaggleMath.getBuyerInterestLabel(buyer, category: string): string
	local match = TacticHaggleMath.getBuyerCategoryMatch(buyer, category)
	if match >= 0.25 then
		return "Very interested"
	elseif match >= 0.06 then
		return "Interested"
	elseif match <= -0.08 then
		return "Low interest"
	end
	return "Curious"
end

local function getSellerStatFit(customer, tacticId: string, ctx): number
	local desperation = customer.desperation or 0
	local knowledge = customer.knowledge or 0
	local temper = customer.temper or 0
	local scam = customer.scamBias or 0
	local fit = 0

	if tacticId == Buy.Lowball then
		fit = desperation * 0.75 - knowledge * 0.45 - temper * 0.25
		if (ctx.leverage or 0) >= 45 then
			fit += 0.25
		end
	elseif tacticId == Buy.SplitDifference then
		fit = 0.28 - temper * 0.1
	elseif tacticId == Buy.PointOutFlaw then
		fit = scam * 0.55 + knowledge * 0.08 - temper * 0.18
		if ctx.inspected then
			fit += 0.25
		end
		if ctx.estimateInflated then
			fit += 0.35
		end
		if ctx.rarityId == "Common" or (ctx.trueValue and ctx.trueValue < 40) then
			fit += 0.15
		end
	elseif tacticId == Buy.Pressure then
		fit = desperation * 0.75 - knowledge * 0.4 - temper * 0.35
		if (ctx.confidence or 0) <= 25 then
			fit += 0.12
		end
	end

	return fit
end

local function getBuyerStatFit(buyer, tacticId: string, ctx): number
	local categoryMatch = TacticHaggleMath.getBuyerCategoryMatch(buyer, ctx.itemCategory or "")
	local urgency = buyer.urgency or 0
	local knowledge = buyer.knowledge or 0
	local greed = buyer.greed or 0
	local fit = categoryMatch * 0.5

	if tacticId == Sell.SmallBump then
		fit += 0.2 - greed * 0.1
	elseif tacticId == Sell.PitchValue then
		fit += categoryMatch * 0.5
		if ctx.inspected then
			fit += 0.15
		end
		if ctx.inspected and (ctx.rarityId == "Rare" or ctx.rarityId == "Epic" or ctx.rarityId == "Legendary") then
			fit += 0.12
		end
	elseif tacticId == Sell.HoldFirm then
		fit += (ctx.leverage or 0) / 180 + urgency * 0.2 - greed * 0.15
	elseif tacticId == Sell.Bluff then
		fit += (ctx.leverage or 0) / 160 + urgency * 0.15 - knowledge * 0.45
	end

	return fit
end

function TacticHaggleMath.getTacticFit(side: string, npc, tacticId: string, ctx): number
	local profile = getProfile(side, npc)
	local fit = profileFit(profile, tacticId)

	if side == "buy" then
		fit += getSellerStatFit(npc, tacticId, ctx)
	else
		fit += getBuyerStatFit(npc, tacticId, ctx)
	end

	if (ctx.heat or 0) >= HaggleTuning.heatWarningThreshold then
		fit -= 0.18
	end
	if ctx.finalOffer then
		fit -= 0.35
	end

	return clamp01(fit)
end

function TacticHaggleMath.getRepeatPenalty(repeatCount: number)
	if repeatCount <= 0 then
		return {
			movementMultiplier = 1,
			heatBonus = 0,
			confidenceBonus = 0,
			leverageMultiplier = 1,
		}
	elseif repeatCount == 1 then
		return {
			movementMultiplier = 0.55,
			heatBonus = 10,
			confidenceBonus = 8,
			leverageMultiplier = 0.55,
		}
	end
	return {
		movementMultiplier = 0.18,
		heatBonus = 22,
		confidenceBonus = 18,
		leverageMultiplier = 0.15,
	}
end

local function getStartingConfidence(npc): number
	return clampStat((npc.knowledge or 0.4) * 45 + (npc.temper or 0.4) * 30)
end

function TacticHaggleMath.getStartingSellerConfidence(customer): number
	return getStartingConfidence(customer)
end

function TacticHaggleMath.getStartingBuyerConfidence(buyer): number
	return getStartingConfidence(buyer)
end

local function getStateFromFit(side: string, npc, tacticId: string, fit: number, heat: number): string
	if heat >= HaggleTuning.heatWarningThreshold then
		return STATE.Guarded
	end
	if fit >= 0.45 then
		return side == "buy" and STATE.Worried or STATE.Open
	elseif fit <= -0.45 then
		local profile = getProfile(side, npc)
		return (profile and profile.badState) or STATE.Guarded
	end
	return STATE.Open
end

function TacticHaggleMath.applyLeverageAndConfidence(ctx, result)
	local leverage = ctx.leverage or 0
	local confidence = ctx.confidence or 0
	local fit = result.fit or 0
	local repeatPenalty = result.repeatPenalty

	local leverageDelta = result.leverageDelta or 0
	local confidenceDelta = result.confidenceDelta or 0

	if fit >= 0.45 then
		leverageDelta += 10
	elseif fit <= -0.25 then
		confidenceDelta += 10
	end

	if repeatPenalty then
		leverageDelta *= repeatPenalty.leverageMultiplier
		confidenceDelta += repeatPenalty.confidenceBonus
	end

	if (ctx.heat or 0) >= HaggleTuning.heatWarningThreshold then
		confidenceDelta += 6
	end

	local newLeverage = clampStat(leverage + leverageDelta - (result.leverageSpent or 0))
	local newConfidence = clampStat(confidence + confidenceDelta)

	result.leverageDelta = math.floor(leverageDelta + 0.5)
	result.confidenceDelta = math.floor(confidenceDelta + 0.5)
	result.newLeverage = newLeverage
	result.newConfidence = newConfidence

	return result
end

function TacticHaggleMath.maybeEnterFinalOffer(ctx, result)
	if result.finalOffer then
		return result
	end

	local heat = result.newHeat or ctx.heat or 0
	local confidence = result.newConfidence or ctx.confidence or 0
	local repeatCount = result.repeatCount or 0
	local fit = result.fit or 0

	if ctx.finalOffer then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = "already final"
	elseif heat >= HaggleTuning.heatWalkThreshold then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = "heat maxed"
	elseif heat >= HaggleTuning.finalOfferHeatThreshold and (confidence >= 55 or fit < 0.25) then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = "high heat"
	elseif repeatCount >= 2 then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = "repeated tactic"
	elseif fit <= -0.55 and confidence >= 55 then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = "bad read"
	end

	return result
end

function TacticHaggleMath.calculateAskingPrice(customer, trueValue: number, rng: Random?): number
	local random = rng or Random.new()
	local markup = HaggleTuning.askingMarkupBase
		+ (customer.greed or 0) * HaggleTuning.askingMarkupGreed
		+ (customer.scamBias or 0) * HaggleTuning.askingMarkupScam
		- (customer.desperation or 0) * HaggleTuning.askingMarkupDesperation
	markup += random:NextNumber(-HaggleTuning.askingMarkupJitter, HaggleTuning.askingMarkupJitter)
	return clamp(trueValue * markup, 1, 999999)
end

function TacticHaggleMath.calculateMinimumAccept(customer, item, trueValue: number, askingPrice: number): number
	local valueRatio = HaggleTuning.minAcceptValueBase
		+ (customer.greed or 0) * HaggleTuning.minAcceptGreed
		- (customer.desperation or 0) * HaggleTuning.minAcceptDesperation
		+ (customer.knowledge or 0) * HaggleTuning.minAcceptKnowledge
	valueRatio = math.clamp(valueRatio, HaggleTuning.minAcceptFloorOfTrue, HaggleTuning.minAcceptCeilingOfTrue)
	local floorFromValue = trueValue * valueRatio
	local floorFromAsk = askingPrice
		* (HaggleTuning.minAcceptAskFactor - (customer.desperation or 0) * 0.2 + (customer.greed or 0) * 0.06)
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

local function buyTacticBase(tacticId: string)
	if tacticId == Buy.SplitDifference then
		return {
			heat = HaggleTuning.heatBuySplit,
			ratio = HaggleTuning.buySplitDropRatio,
			role = "safe",
			dialogueGood = BUY_DIALOGUE.split_good,
			dialogueBad = BUY_DIALOGUE.split_low,
		}
	elseif tacticId == Buy.PointOutFlaw then
		return {
			heat = HaggleTuning.heatBuyFlaw,
			ratio = HaggleTuning.buyFlawDropRatio,
			role = "build",
			dialogueGood = BUY_DIALOGUE.flaw_good,
			dialogueBad = BUY_DIALOGUE.flaw_bad,
		}
	elseif tacticId == Buy.Pressure then
		return {
			heat = HaggleTuning.heatBuyPressure,
			ratio = HaggleTuning.buyPressureDropRatio,
			role = "build_risky",
			dialogueGood = BUY_DIALOGUE.pressure_good,
			dialogueBad = BUY_DIALOGUE.pressure_bad,
		}
	elseif tacticId == Buy.Lowball then
		return {
			heat = HaggleTuning.heatBuyLowball,
			ratio = HaggleTuning.buyLowballDropRatio,
			role = "cash_risky",
			dialogueGood = BUY_DIALOGUE.lowball_good,
			dialogueBad = BUY_DIALOGUE.lowball_bad,
		}
	end
	return nil
end

local function sellTacticBase(tacticId: string)
	if tacticId == Sell.SmallBump then
		return {
			heat = HaggleTuning.heatSellSmallBump,
			ratio = HaggleTuning.sellSmallBumpRatio,
			role = "safe",
			dialogueGood = SELL_DIALOGUE.small_good,
			dialogueBad = SELL_DIALOGUE.small_low,
		}
	elseif tacticId == Sell.PitchValue then
		return {
			heat = HaggleTuning.heatSellPitch,
			ratio = HaggleTuning.sellPitchRatio,
			role = "build",
			dialogueGood = SELL_DIALOGUE.pitch_good,
			dialogueBad = SELL_DIALOGUE.pitch_bad,
		}
	elseif tacticId == Sell.HoldFirm then
		return {
			heat = HaggleTuning.heatSellHoldFirm,
			ratio = HaggleTuning.sellHoldRatio,
			role = "cash",
			dialogueGood = SELL_DIALOGUE.hold_good,
			dialogueBad = SELL_DIALOGUE.hold_bad,
		}
	elseif tacticId == Sell.Bluff then
		return {
			heat = HaggleTuning.heatSellBluff,
			ratio = HaggleTuning.sellBluffRatio,
			role = "cash_risky",
			dialogueGood = SELL_DIALOGUE.bluff_good,
			dialogueBad = SELL_DIALOGUE.bluff_bad,
		}
	end
	return nil
end

local function applyMovementModifiers(baseRatio: number, fit: number, leverage: number, confidence: number, repeatPenalty, role: string, finalOffer: boolean): (number, number)
	local ratio = baseRatio
	local leverageSpent = 0

	if role == "build" or role == "build_risky" then
		ratio *= 0.75 + math.max(fit, -0.4) * 0.35
	elseif role == "cash" or role == "cash_risky" then
		local leverageBonus = math.clamp(leverage / 100, 0, 1)
		ratio *= 0.55 + leverageBonus * 0.9 + math.max(fit, -0.5) * 0.25
		leverageSpent = math.floor(18 + leverageBonus * 24)
	else
		ratio *= 0.7 + math.max(fit, -0.4) * 0.25
		if leverage >= 35 then
			ratio += 0.04
			leverageSpent = 8
		end
	end

	ratio *= 1 - math.clamp(confidence / 170, 0, 0.5)
	ratio *= repeatPenalty.movementMultiplier

	if finalOffer then
		ratio *= role == "safe" and 0.05 or 0.18
	end

	return math.max(ratio, 0), leverageSpent
end

function TacticHaggleMath.evaluateBuyTactic(tacticId: string, ctx): any
	local base = buyTacticBase(tacticId)
	if not base then
		return { ok = false, error = "Unknown buy tactic" }
	end

	local rng = ctx.rng or Random.new()
	local price = ctx.currentSellerPrice
	local floor = ctx.minimumAccept
	local heat = ctx.sellerHeat or 0
	local leverage = ctx.leverage or 0
	local confidence = ctx.confidence or 0
	local finalOffer = ctx.finalOffer or false
	local usedTactics = ctx.usedTactics or {}
	local repeatCount = usedTactics[tacticId] or 0
	local repeatPenalty = TacticHaggleMath.getRepeatPenalty(repeatCount)
	local fit = TacticHaggleMath.getTacticFit("buy", ctx.customer, tacticId, {
		heat = heat,
		leverage = leverage,
		confidence = confidence,
		finalOffer = finalOffer,
		inspected = ctx.inspected,
		estimateInflated = ctx.estimateInflated,
		rarityId = ctx.rarityId,
		trueValue = ctx.trueValue,
	})

	local ratio, leverageSpent = applyMovementModifiers(base.ratio, fit, leverage, confidence, repeatPenalty, base.role, finalOffer)
	if tacticId == Buy.PointOutFlaw then
		if ctx.inspected then
			ratio += HaggleTuning.buyInspectFlawBonus
		end
		if ctx.estimateInflated then
			ratio += HaggleTuning.buyScamFlawBonus
		end
	end
	if tacticId == Buy.Lowball and leverage >= 60 and fit >= 0.35 then
		ratio = math.max(ratio, HaggleTuning.buyLowballBigWinRatio)
	end

	local gap = price - floor
	local drop = math.max(math.floor(gap * ratio), if finalOffer then 0 else math.floor(price * 0.02))
	if fit < -0.25 or finalOffer then
		drop = math.floor(drop * 0.35)
	end
	local newPrice = clamp(price - drop, floor, price)

	local heatDelta = base.heat + repeatPenalty.heatBonus
	if fit < -0.25 then
		heatDelta += HaggleTuning.heatMismatchBonus + math.floor(math.abs(fit) * 12)
	elseif fit >= 0.45 then
		heatDelta = math.max(0, heatDelta - HaggleTuning.heatGoodMatchReduction)
	end
	if finalOffer and tacticId ~= Buy.SplitDifference then
		heatDelta += 18
	end

	local newHeat = math.min(heat + heatDelta, (ctx.sellerHeatMax or HaggleTuning.heatMax) + 20)
	local walkedAway = false
	local outcome = if newPrice < price then "price_drop" else "no_movement"
	local risky = base.role == "cash_risky" or base.role == "build_risky"
	local walkChance = 0

	if risky and fit < 0.15 then
		walkChance = 0.22 + math.abs(math.min(fit, 0)) * 0.35 + math.clamp(heat / 140, 0, 0.35)
	end
	if finalOffer and risky then
		walkChance += 0.35
	end
	if newHeat >= HaggleTuning.heatWalkThreshold then
		walkChance += HaggleTuning.tacticWalkChanceAtHighHeat
	end
	if rng:NextNumber() < math.clamp(walkChance, 0, 0.9) then
		walkedAway = true
		outcome = "walkaway"
	end

	local leverageDelta = 0
	local confidenceDelta = 0
	if base.role == "build" or base.role == "build_risky" then
		leverageDelta = if fit >= 0.35 then 20 else 6
	end
	if fit < -0.2 or repeatCount >= 1 then
		confidenceDelta = 10 + repeatCount * 8
	end

	ctx.heat = heat
	local result = TacticHaggleMath.applyLeverageAndConfidence(ctx, {
		ok = true,
		outcome = outcome,
		priceDelta = newPrice - price,
		newPrice = newPrice,
		heatDelta = heatDelta,
		newHeat = newHeat,
		oldHeat = heat,
		dialogue = pick(if fit >= 0.25 then base.dialogueGood else base.dialogueBad, rng),
		warning = TacticHaggleMath.getHeatWarning(newHeat),
		walkedAway = walkedAway,
		bigWin = tacticId == Buy.Lowball and fit >= 0.4 and leverage >= 55 and newPrice <= (ctx.trueValue or price) * 0.65,
		crack = tacticId == Buy.Lowball and fit >= 0.5 and rng:NextNumber() < 0.12,
		fit = fit,
		repeatCount = repeatCount,
		repeatPenalty = repeatPenalty,
		oldLeverage = leverage,
		oldConfidence = confidence,
		oldState = ctx.state or STATE.Open,
		leverageDelta = leverageDelta,
		confidenceDelta = confidenceDelta,
		leverageSpent = leverageSpent,
		newState = getStateFromFit("buy", ctx.customer, tacticId, fit, newHeat),
	})

	TacticHaggleMath.maybeEnterFinalOffer(ctx, result)
	if result.finalOffer and not walkedAway then
		result.dialogue = pick(BUY_DIALOGUE.final, rng)
		result.warning = "Final offer. Accept or pass."
	end
	result.readText = `fit={string.format("%.2f", fit)} repeat={repeatCount} lev={leverage}->{result.newLeverage} conf={confidence}->{result.newConfidence}`
	return result
end

function TacticHaggleMath.evaluateSellTactic(tacticId: string, ctx): any
	local base = sellTacticBase(tacticId)
	if not base then
		return { ok = false, error = "Unknown sell tactic" }
	end

	local rng = ctx.rng or Random.new()
	local offer = ctx.currentBuyerOffer
	local maxOffer = ctx.buyerMaximum
	local heat = ctx.buyerHeat or 0
	local leverage = ctx.leverage or 0
	local confidence = ctx.confidence or 0
	local finalOffer = ctx.finalOffer or false
	local usedTactics = ctx.usedTactics or {}
	local repeatCount = usedTactics[tacticId] or 0
	local repeatPenalty = TacticHaggleMath.getRepeatPenalty(repeatCount)
	local fit = TacticHaggleMath.getTacticFit("sell", ctx.buyer, tacticId, {
		heat = heat,
		leverage = leverage,
		confidence = confidence,
		finalOffer = finalOffer,
		itemCategory = ctx.itemCategory,
		inspected = ctx.inspected,
		rarityId = ctx.rarityId,
	})

	local ratio, leverageSpent = applyMovementModifiers(base.ratio, fit, leverage, confidence, repeatPenalty, base.role, finalOffer)
	if tacticId == Sell.PitchValue then
		local categoryMatch = TacticHaggleMath.getBuyerCategoryMatch(ctx.buyer, ctx.itemCategory or "")
		ratio += math.max(0, categoryMatch) * HaggleTuning.sellCategoryPitchBonus
		if ctx.inspected then
			ratio += 0.03
		end
	end
	if tacticId == Sell.Bluff and leverage >= 65 and fit >= 0.35 then
		ratio = math.max(ratio, HaggleTuning.sellBluffBigWinRatio)
	end

	local gap = maxOffer - offer
	local raise = math.max(math.floor(gap * ratio), if finalOffer then 0 else math.floor(offer * 0.02))
	if fit < -0.25 or finalOffer then
		raise = math.floor(raise * 0.35)
	end
	local newOffer = clamp(offer + raise, offer, maxOffer)

	local heatDelta = base.heat + repeatPenalty.heatBonus
	if fit < -0.25 then
		heatDelta += HaggleTuning.heatMismatchBonus + math.floor(math.abs(fit) * 12)
	elseif fit >= 0.45 then
		heatDelta = math.max(0, heatDelta - HaggleTuning.heatGoodMatchReduction)
	end
	if finalOffer and tacticId ~= Sell.SmallBump then
		heatDelta += 18
	end

	local newHeat = math.min(heat + heatDelta, (ctx.buyerHeatMax or HaggleTuning.heatMax) + 20)
	local walkedAway = false
	local outcome = if newOffer > offer then "price_raise" else "no_movement"
	local risky = base.role == "cash_risky"
	local walkChance = 0

	if risky and fit < 0.15 then
		walkChance = 0.24 + math.abs(math.min(fit, 0)) * 0.4 + math.clamp(heat / 140, 0, 0.35)
	end
	if finalOffer and risky then
		walkChance += 0.35
	end
	if newHeat >= HaggleTuning.heatWalkThreshold then
		walkChance += HaggleTuning.tacticWalkChanceAtHighHeat
	end
	if rng:NextNumber() < math.clamp(walkChance, 0, 0.9) then
		walkedAway = true
		outcome = "walkaway"
	end

	local leverageDelta = 0
	local confidenceDelta = 0
	if base.role == "build" then
		leverageDelta = if fit >= 0.35 then 22 else 7
	end
	if fit < -0.2 or repeatCount >= 1 then
		confidenceDelta = 10 + repeatCount * 8
	end

	ctx.heat = heat
	local result = TacticHaggleMath.applyLeverageAndConfidence(ctx, {
		ok = true,
		outcome = outcome,
		priceDelta = newOffer - offer,
		newPrice = newOffer,
		heatDelta = heatDelta,
		newHeat = newHeat,
		oldHeat = heat,
		dialogue = pick(if fit >= 0.25 then base.dialogueGood else base.dialogueBad, rng),
		warning = TacticHaggleMath.getHeatWarning(newHeat),
		walkedAway = walkedAway,
		bigWin = tacticId == Sell.Bluff and fit >= 0.4 and leverage >= 55 and newOffer >= (ctx.trueValue or offer) * 1.12,
		fit = fit,
		repeatCount = repeatCount,
		repeatPenalty = repeatPenalty,
		oldLeverage = leverage,
		oldConfidence = confidence,
		oldState = ctx.state or STATE.Open,
		leverageDelta = leverageDelta,
		confidenceDelta = confidenceDelta,
		leverageSpent = leverageSpent,
		newState = getStateFromFit("sell", ctx.buyer, tacticId, fit, newHeat),
	})

	TacticHaggleMath.maybeEnterFinalOffer(ctx, result)
	if (tacticId == Sell.HoldFirm or tacticId == Sell.Bluff) and result.newLeverage <= 20 and not walkedAway then
		result.finalOffer = true
		result.newState = STATE.FinalOffer
		result.finalReason = result.finalReason or "cashed leverage"
	end
	if result.finalOffer and not walkedAway then
		result.dialogue = pick(SELL_DIALOGUE.final, rng)
		result.warning = "Final offer. Accept or find another buyer."
	end
	result.readText = `fit={string.format("%.2f", fit)} repeat={repeatCount} lev={leverage}->{result.newLeverage} conf={confidence}->{result.newConfidence}`
	return result
end

return TacticHaggleMath
