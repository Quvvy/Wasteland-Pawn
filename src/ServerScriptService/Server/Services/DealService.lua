local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)
local Rarities = require(Shared.Config.Rarities)
local HaggleMath = require(Shared.Economy.HaggleMath)
local ItemValuation = require(Shared.Economy.ItemValuation)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local CustomerService = require(script.Parent.CustomerService)
local BuyerService = require(script.Parent.BuyerService)

local DealService = {}

local ACTION_COOLDOWN_SECONDS = 0.15

local activeDeals: { [Player]: any } = {}
local playerRng: { [Player]: Random } = {}
local playerNextDealAt: { [Player]: number } = {}
local playerActionBusy: { [Player]: boolean } = {}
local playerLastActionAt: { [Player]: number } = {}

local function currencyWord(): string
	return HaggleTuning.currencyName or "scraps"
end

function DealService:Init()
	Remotes.setup()
end

function DealService:Start()
	local function bind(remoteName: string, handler)
		local remote = Remotes.get(remoteName) :: RemoteFunction
		remote.OnServerInvoke = function(player, ...)
			local invokeArgs = { ... }
			return self:_runPlayerAction(player, function()
				return handler(player, table.unpack(invokeArgs))
			end)
		end
	end

	bind("MakeOffer", function(player, amount, offerKind)
		return self:makeOffer(player, amount, offerKind)
	end)
	bind("InspectItem", function(player)
		return self:inspectItem(player)
	end)
	bind("AcceptCounter", function(player)
		return self:acceptCounter(player)
	end)
	bind("PassDeal", function(player)
		return self:passDeal(player)
	end)
	bind("SellItem", function(player, instanceId)
		return self:startSelling(player, instanceId)
	end)
	bind("KeepItem", function(player, instanceId)
		return self:keepItem(player, instanceId)
	end)
	bind("StartDeal", function(player)
		return self:startDeal(player)
	end)
	bind("StartSelling", function(player, instanceId)
		return self:startSelling(player, instanceId)
	end)
	bind("MakeSellAsk", function(player, amount)
		return self:makeSellAsk(player, amount)
	end)
	bind("AcceptBuyerOffer", function(player)
		return self:acceptBuyerOffer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activeDeals[player] = nil
		playerRng[player] = nil
		playerNextDealAt[player] = nil
		playerActionBusy[player] = nil
		playerLastActionAt[player] = nil
	end)

	if RunService:IsStudio() then
		self:_setupStudioDebug()
	end
end

function DealService:_runPlayerAction(player: Player, callback)
	if playerActionBusy[player] then
		return { ok = false, error = "Action in progress" }
	end

	local now = os.clock()
	local lastActionAt = playerLastActionAt[player]
	if lastActionAt and now - lastActionAt < ACTION_COOLDOWN_SECONDS then
		return { ok = false, error = "Slow down" }
	end

	playerActionBusy[player] = true
	playerLastActionAt[player] = now

	local ok, result = pcall(callback)
	playerActionBusy[player] = nil

	if not ok then
		warn(`[WastelandPawn] Deal action failed for {player.Name}: {result}`)
		return { ok = false, error = "Server error" }
	end

	return result
end

function DealService:_setupStudioDebug()
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			self:_handleDebugChat(player, message)
		end)
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

function DealService:_handleDebugChat(player: Player, message: string)
	if not RunService:IsStudio() or message:sub(1, 1) ~= "/" then
		return
	end

	local parts = string.split(message:sub(2), " ")
	local command = string.lower(parts[1] or "")

	if command == "cash" then
		local amount = tonumber(parts[2]) or 1000
		DataService:setCash(player, amount)
		print(`[WastelandPawn] Set {player.Name} {currencyWord()} to {amount}`)
		self:_pushState(player)
	elseif command == "deal" then
		local customerId = parts[2]
		local itemId = parts[3]
		if not customerId or not itemId then
			print("[WastelandPawn] Usage: /deal <customerId> <itemId>")
			return
		end
		playerNextDealAt[player] = nil
		self:startDeal(player, customerId, itemId)
	end
end

function DealService:_logDealStart(player: Player, deal)
	if not RunService:IsStudio() then
		return
	end

	print(
		`[WastelandPawn] DEAL START | {deal.customer.displayName} selling {deal.item.displayName} | ask={deal.askingPrice} effective={deal.effectiveMinimum} true={deal.hiddenOutcome.trueValue} ({deal.hiddenOutcome.rarityId})`
	)
end

function DealService:_logDealSummary(player: Player, deal)
	local summary = deal.dealSummary
	if not summary then
		return
	end

	local line = `[WastelandPawn] DEAL DONE | seller={summary.sellerName} buyer={summary.buyerName or "none"}`
		.. ` item={summary.itemName} rarity={summary.rarityId} true={summary.trueValue}`
		.. ` bought={summary.purchasePrice} sold={summary.salePrice or "kept"}`
		.. ` profit={summary.profit} buyRounds={summary.buyRounds} sellRounds={summary.sellRounds}`
		.. ` inspected={summary.inspected} lowball={summary.lowballResult or "none"}`

	if RunService:IsStudio() then
		print(line)
	end

	deal.resultMessage = summary.resultText
end

function DealService:_getRng(player: Player): Random
	if not playerRng[player] then
		playerRng[player] = Random.new()
	end
	return playerRng[player]
end

function DealService:_sanitizeAmount(amount: any): number?
	if type(amount) ~= "number" then
		return nil
	end

	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end

	return math.clamp(math.floor(amount + 0.5), 1, 999999)
end

function DealService:_sanitizeOfferKind(offerKind: any): string
	if offerKind == "lowball" then
		return "lowball"
	end
	return "normal"
end

function DealService:_canStartDeal(player: Player): (boolean, string?)
	local waitUntil = playerNextDealAt[player]
	if waitUntil and os.clock() < waitUntil then
		local remaining = math.ceil(waitUntil - os.clock())
		return false, `Wait {remaining}s for the next customer.`
	end
	return true, nil
end

function DealService:_setDealCooldown(player: Player)
	if HaggleTuning.dealCooldownSeconds > 0 then
		playerNextDealAt[player] = os.clock() + HaggleTuning.dealCooldownSeconds
	end
end

function DealService:_scheduleNextDeal(player: Player, delay: number, deal)
	self:_setDealCooldown(player)
	task.delay(delay, function()
		if player.Parent and activeDeals[player] == deal then
			playerNextDealAt[player] = nil
			self:startDeal(player)
		end
	end)
end

function DealService:_rejectUnaffordable(player: Player, deal, amount: number)
	deal.dialogue = `You don't have enough {currencyWord()} to make that offer.`
	self:_pushState(player)
	return { ok = false, error = "Not enough cash" }
end

function DealService:_applyLowballCrack(deal)
	local trueValue = deal.hiddenOutcome.trueValue
	deal.estimatedLow, deal.estimatedHigh = ItemValuation.narrowEstimateAfterInspect(
		deal.estimatedLow,
		deal.estimatedHigh,
		trueValue
	)
	deal.inspectHint = "Lowball tipped them off. Estimate tightened sharply."
end

function DealService:_applyScamCallout(deal)
	if deal.scamCalloutUsed then
		return
	end
	deal.scamCalloutUsed = true
	local reduction = math.floor(deal.askingPrice * HaggleTuning.lowballScamAskReduction)
	deal.askingPrice = math.max(deal.effectiveMinimum, deal.askingPrice - reduction)
	deal.effectiveMinimum = HaggleMath.calculateEffectiveMinimum(deal.customer, deal.minimumAccept, deal.askingPrice)
	deal.dialogue = `They blinked. Asking lowered to {deal.askingPrice} {currencyWord()}.`
end

function DealService:_pushState(player: Player)
	local deal = activeDeals[player]
	if not deal then
		return
	end

	local event = Remotes.get("DealStateUpdate") :: RemoteEvent
	event:FireClient(player, self:_buildSnapshot(player, deal))
end

function DealService:_buildSnapshot(player: Player, deal)
	local rarity = Rarities[deal.hiddenOutcome.rarityId]
	local cur = currencyWord()
	local waitUntil = playerNextDealAt[player]

	local snapshot = {
		phase = deal.phase,
		currencyName = cur,
		customerId = deal.customer.id,
		customerName = deal.customer.displayName,
		buyerId = deal.buyer and deal.buyer.id or nil,
		buyerName = deal.buyer and deal.buyer.displayName or nil,
		dialogue = deal.dialogue,
		itemId = deal.item.id,
		itemName = deal.item.displayName,
		category = deal.item.category,
		flavorText = deal.item.flavorText,
		askingPrice = deal.askingPrice,
		counterOffer = deal.counterOffer,
		buyerOffer = deal.buyerOffer,
		buyerCounterOffer = deal.buyerCounterOffer,
		estimatedLow = deal.estimatedLow,
		estimatedHigh = deal.estimatedHigh,
		playerCash = DataService:getCash(player),
		patience = deal.patience,
		maxPatience = deal.maxPatience,
		buyerPatience = deal.buyerPatience,
		buyerMaxPatience = deal.buyerMaxPatience,
		inspected = deal.inspected,
		inspectHint = deal.inspectHint,
		buyRoundCount = deal.buyRoundCount,
		sellRoundCount = deal.sellRoundCount,
		instanceId = deal.pendingInstanceId,
		purchasePrice = deal.purchasePrice,
		salePrice = deal.salePrice,
		resultMessage = deal.resultMessage,
		lastOutcome = deal.lastOutcome,
		patienceDelta = deal.lastPatienceDelta,
		requiredNextOffer = self:_getRequiredNextOffer(deal),
		repeatBlocked = deal.repeatBlocked,
		lowballResult = deal.lowballResult,
		penaltyMessage = deal.penaltyMessage,
		dealSummary = deal.dealSummary,
	}

	if waitUntil and os.clock() < waitUntil then
		snapshot.nextDealAvailableAt = waitUntil
	end

	if deal.hiddenOutcome then
		if deal.phase == "Purchased" or deal.phase == "Selling" or deal.phase == "BuyerCounter" or deal.phase == "Result" then
			snapshot.trueValue = deal.hiddenOutcome.trueValue
			snapshot.rarityName = rarity and rarity.displayName or deal.hiddenOutcome.rarityId
		end
		if deal.purchasePrice and deal.hiddenOutcome.trueValue then
			snapshot.profitPreview = deal.hiddenOutcome.trueValue - deal.purchasePrice
		end
	end

	return snapshot
end

function DealService:_getRequiredNextOffer(deal)
	if deal.phase == "Counter" and deal.counterOffer then
		return deal.counterOffer
	end
	if deal.phase == "BuyerCounter" and deal.buyerCounterOffer then
		return deal.buyerCounterOffer
	end
	if deal.phase == "Selling" and deal.buyerOffer then
		return deal.buyerOffer
	end
	if deal.effectiveMinimum then
		return deal.effectiveMinimum
	end
	return nil
end

function DealService:_initDealState(customer, item, hiddenOutcome, askingPrice, minimumAccept, estimatedLow, estimatedHigh)
	local effectiveMinimum = HaggleMath.calculateEffectiveMinimum(customer, minimumAccept, askingPrice)
	local maxPatience = HaggleMath.getStartingPatience(customer)
	local cur = currencyWord()

	return {
		customer = customer,
		item = item,
		hiddenOutcome = hiddenOutcome,
		askingPrice = askingPrice,
		minimumAccept = minimumAccept,
		effectiveMinimum = effectiveMinimum,
		counterOffer = nil,
		patience = maxPatience,
		maxPatience = maxPatience,
		phase = "Haggling",
		inspected = false,
		estimatedLow = estimatedLow,
		estimatedHigh = estimatedHigh,
		inspectHint = nil,
		buyRoundCount = 0,
		sellRoundCount = 0,
		pendingInstanceId = nil,
		purchasePrice = nil,
		salePrice = nil,
		resultMessage = nil,
		lastOutcome = nil,
		lastPatienceDelta = nil,
		lastOfferAmount = nil,
		bestOfferAmount = nil,
		repeatOfferStreak = 0,
		repeatBlocked = false,
		lowballResult = nil,
		penaltyMessage = nil,
		scamCalloutUsed = false,
		buyer = nil,
		buyerOffer = nil,
		buyerCounterOffer = nil,
		buyerMaximum = nil,
		buyerPatience = nil,
		buyerMaxPatience = nil,
		lastSellAsk = nil,
		sellRepeatStreak = 0,
		dealSummary = nil,
		dialogue = customer.openingLine .. ` Asking {askingPrice} {cur}.`,
	}
end

function DealService:startDeal(player: Player, customerId: string?, itemId: string?)
	if not player.Parent then
		return { ok = false, error = "Player left" }
	end

	local canStart, waitError = self:_canStartDeal(player)
	if not canStart then
		return { ok = false, error = waitError }
	end

	local rng = self:_getRng(player)
	local customer = if customerId then CustomerService:getCustomer(customerId) else CustomerService:rollCustomer(rng)
	local item = if itemId then CustomerService:getItem(itemId) else CustomerService:rollItem(rng)

	if not customer or not item then
		return { ok = false, error = "Invalid customer or item id" }
	end

	local hiddenOutcome = ItemValuation.createHiddenOutcome(item, customer, rng)
	local estimatedLow, estimatedHigh = ItemValuation.generateEstimatedRange(item, customer, hiddenOutcome.trueValue, rng)
	local askingPrice = HaggleMath.calculateAskingPrice(customer, hiddenOutcome.trueValue, rng)
	local minimumAccept = HaggleMath.calculateMinimumAcceptPrice(customer, item, hiddenOutcome.trueValue, askingPrice)

	local deal = self:_initDealState(customer, item, hiddenOutcome, askingPrice, minimumAccept, estimatedLow, estimatedHigh)

	activeDeals[player] = deal
	self:_logDealStart(player, deal)
	self:_pushState(player)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:makeOffer(player: Player, amount: any, offerKind: any)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Haggling" and deal.phase ~= "Counter") then
		return { ok = false, error = "No active haggle" }
	end

	local offerAmount = self:_sanitizeAmount(amount)
	if not offerAmount then
		return { ok = false, error = "Invalid offer" }
	end

	local kind = self:_sanitizeOfferKind(offerKind)
	if kind == "lowball" and deal.phase ~= "Haggling" then
		return { ok = false, error = "Lowball only before a counter" }
	end

	if kind ~= "lowball" and not DataService:canAfford(player, offerAmount) then
		return self:_rejectUnaffordable(player, deal, offerAmount)
	end

	deal.buyRoundCount += 1
	deal.lowballResult = nil
	deal.penaltyMessage = nil
	deal.repeatBlocked = false

	local rng = self:_getRng(player)
	local evaluation = if kind == "lowball"
		then HaggleMath.evaluateLowball(deal.customer, deal.item, offerAmount, deal, rng)
		else HaggleMath.evaluateOffer(deal.customer, deal.item, offerAmount, deal, rng)

	deal.repeatOfferStreak = evaluation.repeatStreak or 0
	deal.lastOfferAmount = offerAmount
	if not deal.bestOfferAmount or offerAmount > deal.bestOfferAmount then
		deal.bestOfferAmount = offerAmount
	end

	deal.patience = math.clamp(deal.patience + evaluation.patienceDelta, 0, deal.maxPatience)
	deal.lastOutcome = evaluation.outcome
	deal.lastPatienceDelta = evaluation.patienceDelta
	deal.repeatBlocked = evaluation.repeatBlocked or false
	deal.dialogue = evaluation.dialogueOverride or evaluation.reactionText

	if evaluation.lowballResult then
		deal.lowballResult = evaluation.lowballResult
	end

	if evaluation.outcome == "crack" then
		self:_applyLowballCrack(deal)
		deal.phase = "Haggling"
		deal.lastOutcome = "crack"
		self:_pushState(player)
		return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
	end

	if evaluation.scamCallout then
		self:_applyScamCallout(deal)
		deal.lowballResult = "scam_callout"
		self:_pushState(player)
		return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
	end

	if evaluation.outcome == "accept" then
		return self:_completePurchase(player, offerAmount, deal)
	end

	if evaluation.outcome == "walkaway" then
		return self:_handleBuyWalkaway(player, deal, evaluation)
	end

	if evaluation.outcome == "counter" then
		deal.phase = "Counter"
		deal.counterOffer = evaluation.counterOffer
		deal.lastOutcome = "counter"
		deal.dialogue = `{deal.dialogue} Counter: {deal.counterOffer} {currencyWord()}.`
	else
		deal.phase = if deal.phase == "Counter" then "Counter" else "Haggling"
		if deal.phase ~= "Counter" then
			deal.counterOffer = nil
		end
		deal.lastOutcome = "reject"
	end

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:inspectItem(player: Player)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Haggling" and deal.phase ~= "Counter") then
		return { ok = false, error = "Cannot inspect now" }
	end

	if deal.inspected then
		return { ok = false, error = "Already inspected" }
	end

	if not DataService:spend(player, HaggleTuning.inspectCost) then
		deal.dialogue = `You can't afford an inspection.`
		self:_pushState(player)
		return { ok = false, error = "Not enough cash" }
	end

	deal.inspected = true
	deal.estimatedLow, deal.estimatedHigh = ItemValuation.narrowEstimateAfterInspect(
		deal.estimatedLow,
		deal.estimatedHigh,
		deal.hiddenOutcome.trueValue
	)
	deal.inspectHint = ItemValuation.getInspectHint(
		deal.hiddenOutcome.rarityId,
		deal.hiddenOutcome.trueValue,
		deal.customer,
		deal.estimatedLow,
		deal.estimatedHigh
	)
	deal.dialogue = deal.inspectHint
	deal.lastOutcome = nil
	deal.lastPatienceDelta = nil

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:acceptCounter(player: Player)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Counter" or not deal.counterOffer then
		return { ok = false, error = "No counter to accept" }
	end

	if not DataService:canAfford(player, deal.counterOffer) then
		return self:_rejectUnaffordable(player, deal, deal.counterOffer)
	end

	return self:_completePurchase(player, deal.counterOffer, deal)
end

function DealService:_completePurchase(player: Player, price: number, deal)
	if not DataService:canAfford(player, price) then
		return self:_rejectUnaffordable(player, deal, price)
	end

	DataService:spend(player, price)

	local instanceId = InventoryService:addPurchasedItem(player, {
		itemId = deal.item.id,
		displayName = deal.item.displayName,
		category = deal.item.category,
		rarityId = deal.hiddenOutcome.rarityId,
		trueValue = deal.hiddenOutcome.trueValue,
		purchasePrice = price,
		kept = false,
	})

	deal.pendingInstanceId = instanceId
	deal.purchasePrice = price
	deal.phase = "Purchased"
	deal.counterOffer = nil
	deal.dialogue = `Bought for {price} {currencyWord()}. True value: {deal.hiddenOutcome.trueValue} {currencyWord()}. Find a buyer!`

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:startSelling(player: Player, instanceId: any?)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Purchased" then
		return { ok = false, error = "Buy the item first" }
	end

	if instanceId and (type(instanceId) ~= "string" or instanceId ~= deal.pendingInstanceId) then
		return { ok = false, error = "Invalid item" }
	end

	local rng = self:_getRng(player)
	local buyer = BuyerService:rollBuyer(rng)
	local trueValue = deal.hiddenOutcome.trueValue
	local buyerOffer = HaggleMath.calculateBuyerOpeningOffer(buyer, trueValue, rng)
	local buyerMaximum = HaggleMath.calculateBuyerMaximum(buyer, trueValue)
	local buyerPatience = HaggleMath.getBuyerStartingPatience(buyer)

	deal.buyer = buyer
	deal.buyerOffer = buyerOffer
	deal.buyerCounterOffer = nil
	deal.buyerMaximum = buyerMaximum
	deal.buyerPatience = buyerPatience
	deal.buyerMaxPatience = buyerPatience
	deal.lastSellAsk = nil
	deal.sellRepeatStreak = 0
	deal.phase = "Selling"
	deal.dialogue = `{buyer.openingLine} Offer: {buyerOffer} {currencyWord()}.`

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:makeSellAsk(player: Player, amount: any)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Selling" and deal.phase ~= "BuyerCounter") then
		return { ok = false, error = "No buyer to haggle with" }
	end

	local playerAsk = self:_sanitizeAmount(amount)
	if not playerAsk then
		return { ok = false, error = "Invalid ask" }
	end

	deal.sellRoundCount += 1
	deal.repeatBlocked = false
	deal.lowballResult = nil

	local rng = self:_getRng(player)
	local evaluation = HaggleMath.evaluateSellAsk(deal.buyer, deal.hiddenOutcome.trueValue, playerAsk, deal, rng)

	deal.sellRepeatStreak = evaluation.repeatStreak or 0
	deal.lastSellAsk = playerAsk
	deal.buyerPatience = math.clamp(deal.buyerPatience + evaluation.patienceDelta, 0, deal.buyerMaxPatience)
	deal.lastOutcome = evaluation.outcome
	deal.lastPatienceDelta = evaluation.patienceDelta
	deal.repeatBlocked = evaluation.repeatBlocked or false
	deal.dialogue = evaluation.dialogueOverride or evaluation.reactionText

	if evaluation.outcome == "accept" then
		local salePrice = evaluation.salePrice or math.min(playerAsk, deal.buyerMaximum)
		return self:_completeSale(player, deal, salePrice)
	end

	if evaluation.outcome == "walkaway" then
		return self:_handleSellWalkaway(player, deal, evaluation)
	end

	if evaluation.outcome == "counter" then
		deal.phase = "BuyerCounter"
		deal.buyerCounterOffer = evaluation.buyerCounterOffer
		deal.buyerOffer = evaluation.buyerCounterOffer
		deal.lastOutcome = "counter"
		deal.dialogue = `{deal.dialogue} Buyer counter: {deal.buyerCounterOffer} {currencyWord()}.`
	else
		deal.phase = if deal.phase == "BuyerCounter" then "BuyerCounter" else "Selling"
		deal.lastOutcome = "reject"
	end

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:acceptBuyerOffer(player: Player)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Selling" and deal.phase ~= "BuyerCounter") then
		return { ok = false, error = "No buyer offer" }
	end

	local salePrice = deal.buyerCounterOffer or deal.buyerOffer
	if not salePrice then
		return { ok = false, error = "No buyer offer" }
	end

	return self:_completeSale(player, deal, salePrice)
end

function DealService:_completeSale(player: Player, deal, salePrice: number)
	DataService:addCash(player, salePrice)

	if deal.pendingInstanceId then
		InventoryService:markDisposed(player, deal.pendingInstanceId)
	end

	deal.salePrice = salePrice
	local profit = salePrice - (deal.purchasePrice or 0)
	local cur = currencyWord()

	deal.dealSummary = {
		sellerName = deal.customer.displayName,
		buyerName = deal.buyer and deal.buyer.displayName or nil,
		itemName = deal.item.displayName,
		rarityId = deal.hiddenOutcome.rarityId,
		trueValue = deal.hiddenOutcome.trueValue,
		purchasePrice = deal.purchasePrice,
		salePrice = salePrice,
		profit = profit,
		buyRounds = deal.buyRoundCount,
		sellRounds = deal.sellRoundCount,
		inspected = deal.inspected,
		lowballResult = deal.lowballResult,
		resultText = if profit >= 0
			then `Sold for {salePrice} {cur}. Profit: +{profit} {cur}.`
			else `Sold for {salePrice} {cur}. Loss: {profit} {cur}.`,
	}

	self:_logDealSummary(player, deal)
	deal.phase = "Result"
	deal.dialogue = deal.dealSummary.resultText
	deal.pendingInstanceId = nil
	deal.lastOutcome = nil

	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayResult, deal)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_handleBuyWalkaway(player: Player, deal, evaluation)
	deal.phase = "WalkedAway"
	deal.counterOffer = nil
	deal.dialogue = evaluation.dialogueOverride or evaluation.reactionText
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayWalkedAway, deal)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_handleSellWalkaway(player: Player, deal, evaluation)
	deal.phase = "Purchased"
	deal.buyer = nil
	deal.buyerOffer = nil
	deal.buyerCounterOffer = nil
	deal.buyerPatience = nil
	deal.lastSellAsk = nil
	deal.sellRepeatStreak = 0
	deal.dialogue = (evaluation.dialogueOverride or evaluation.reactionText) .. " Find another buyer?"
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:passDeal(player: Player)
	local deal = activeDeals[player]
	if not deal then
		return { ok = false, error = "No deal" }
	end

	if deal.phase == "Purchased" then
		return self:keepItem(player, deal.pendingInstanceId)
	end

	if deal.phase == "Selling" or deal.phase == "BuyerCounter" then
		return self:keepItem(player, deal.pendingInstanceId)
	end

	if deal.phase == "WalkedAway" or deal.phase == "Result" then
		playerNextDealAt[player] = nil
		return self:startDeal(player)
	end

	deal.phase = "WalkedAway"
	deal.dialogue = "You let them walk."
	deal.lastOutcome = "walkaway"
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayPass, deal)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:keepItem(player: Player, instanceId: any)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Purchased" and deal.phase ~= "Selling" and deal.phase ~= "BuyerCounter") then
		return { ok = false, error = "Nothing to keep" }
	end

	if type(instanceId) ~= "string" or instanceId ~= deal.pendingInstanceId then
		return { ok = false, error = "Invalid item" }
	end

	local entry = InventoryService:getOwnedItem(player, instanceId)
	if not entry then
		return { ok = false, error = "Item not found" }
	end

	entry.kept = true
	local paperProfit = entry.trueValue - entry.purchasePrice
	local cur = currencyWord()

	deal.dealSummary = {
		sellerName = deal.customer.displayName,
		buyerName = deal.buyer and deal.buyer.displayName or "none",
		itemName = deal.item.displayName,
		rarityId = deal.hiddenOutcome.rarityId,
		trueValue = deal.hiddenOutcome.trueValue,
		purchasePrice = deal.purchasePrice,
		salePrice = nil,
		profit = paperProfit,
		buyRounds = deal.buyRoundCount,
		sellRounds = deal.sellRoundCount,
		inspected = deal.inspected,
		lowballResult = deal.lowballResult,
		resultText = `Kept {entry.displayName}. Paper value: {entry.trueValue} {cur} (unrealized).`,
	}

	self:_logDealSummary(player, deal)
	deal.phase = "Result"
	deal.dialogue = deal.dealSummary.resultText
	deal.pendingInstanceId = nil
	deal.lastOutcome = nil

	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayResult, deal)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

return DealService
