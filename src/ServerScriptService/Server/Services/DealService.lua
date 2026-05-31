local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)
local HaggleTactics = require(Shared.Economy.HaggleTactics)
local Rarities = require(Shared.Config.Rarities)
local TacticHaggleMath = require(Shared.Economy.TacticHaggleMath)
local NpcTells = require(Shared.Economy.NpcTells)
local ItemValuation = require(Shared.Economy.ItemValuation)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local CustomerService = require(script.Parent.CustomerService)
local BuyerService = require(script.Parent.BuyerService)

local DealService = {}

local ACTION_COOLDOWN_SECONDS = 0.15
local VALID_BUY_TACTICS = {
	[HaggleTactics.Buy.Lowball] = true,
	[HaggleTactics.Buy.SplitDifference] = true,
	[HaggleTactics.Buy.PointOutFlaw] = true,
	[HaggleTactics.Buy.Pressure] = true,
	[HaggleTactics.Buy.AcceptPrice] = true,
	[HaggleTactics.Buy.Pass] = true,
}
local VALID_SELL_TACTICS = {
	[HaggleTactics.Sell.SmallBump] = true,
	[HaggleTactics.Sell.PitchValue] = true,
	[HaggleTactics.Sell.HoldFirm] = true,
	[HaggleTactics.Sell.Bluff] = true,
	[HaggleTactics.Sell.AcceptOffer] = true,
	[HaggleTactics.Sell.FindAnotherBuyer] = true,
}

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

	bind("UseBuyTactic", function(player, tacticId)
		return self:useBuyTactic(player, tacticId)
	end)
	bind("UseSellTactic", function(player, tacticId)
		return self:useSellTactic(player, tacticId)
	end)
	bind("InspectItem", function(player)
		return self:inspectItem(player)
	end)
	bind("PassDeal", function(player)
		return self:passDeal(player)
	end)
	bind("StartDeal", function(player, customerId, itemId)
		return self:startDeal(player, customerId, itemId)
	end)
	bind("StartSelling", function(player, instanceId)
		return self:startSelling(player, instanceId)
	end)
	bind("KeepItem", function(player, instanceId)
		return self:keepItem(player, instanceId)
	end)

	-- Legacy remotes route to tactics (debug / old client)
	bind("MakeOffer", function(player, _, kind)
		if kind == "lowball" then
			return self:useBuyTactic(player, HaggleTactics.Buy.Lowball)
		end
		return self:useBuyTactic(player, HaggleTactics.Buy.SplitDifference)
	end)
	bind("AcceptCounter", function(player)
		return self:useBuyTactic(player, HaggleTactics.Buy.AcceptPrice)
	end)
	bind("MakeSellAsk", function(player)
		return self:useSellTactic(player, HaggleTactics.Sell.PitchValue)
	end)
	bind("AcceptBuyerOffer", function(player)
		return self:useSellTactic(player, HaggleTactics.Sell.AcceptOffer)
	end)
	bind("SellItem", function(player, instanceId)
		return self:startSelling(player, instanceId)
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
	local last = playerLastActionAt[player]
	if last and now - last < ACTION_COOLDOWN_SECONDS then
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

function DealService:_getRng(player: Player): Random
	if not playerRng[player] then
		playerRng[player] = Random.new()
	end
	return playerRng[player]
end

function DealService:_canStartDeal(player: Player): (boolean, string?)
	local untilAt = playerNextDealAt[player]
	if untilAt and os.clock() < untilAt then
		return false, "Wait for next customer"
	end
	return true, nil
end

function DealService:_setDealCooldown(player: Player)
	playerNextDealAt[player] = os.clock() + (HaggleTuning.dealCooldownSeconds or 0)
end

function DealService:_pushState(player: Player)
	local deal = activeDeals[player]
	if not deal then
		return
	end
	(Remotes.get("DealStateUpdate") :: RemoteEvent):FireClient(player, self:_buildSnapshot(player, deal))
end

function DealService:_recordTactic(deal, tacticId: string, result: any)
	deal.lastTactic = tacticId
	deal.lastTacticResult = result.outcome
	if not deal.tacticsUsed then
		deal.tacticsUsed = {}
	end
	table.insert(deal.tacticsUsed, tacticId)
end

function DealService:_initDealState(customer, item, hiddenOutcome, askingPrice, minimumAccept, estimatedLow, estimatedHigh, rng)
	local cur = currencyWord()
	local inflated = ItemValuation.isEstimateInflated(estimatedLow, estimatedHigh, hiddenOutcome.trueValue)

	return {
		customer = customer,
		item = item,
		hiddenOutcome = hiddenOutcome,
		phase = "Haggling",
		originalAskingPrice = askingPrice,
		askingPrice = askingPrice,
		currentSellerPrice = askingPrice,
		minimumAccept = minimumAccept,
		estimatedLow = estimatedLow,
		estimatedHigh = estimatedHigh,
		estimateInflated = inflated,
		inspected = false,
		inspectHint = nil,
		sellerHeat = 0,
		sellerHeatMax = HaggleTuning.heatMax,
		sellerTell = NpcTells.forCustomer(customer, rng),
		buyerTell = nil,
		heatWarning = nil,
		buyRoundCount = 0,
		sellRoundCount = 0,
		tacticsUsed = {},
		lastTactic = nil,
		lastTacticResult = nil,
		pendingInstanceId = nil,
		purchasePrice = nil,
		salePrice = nil,
		buyer = nil,
		currentBuyerOffer = nil,
		buyerOffer = nil,
		buyerOpeningOffer = nil,
		buyerMaximum = nil,
		buyerHeat = 0,
		buyerHeatMax = HaggleTuning.heatMax,
		dealSummary = nil,
		dialogue = `{customer.openingLine} Asking {askingPrice} {cur}.`,
	}
end

function DealService:_buildSnapshot(player: Player, deal)
	local rarity = Rarities[deal.hiddenOutcome.rarityId]
	local cur = currencyWord()
	local phase = deal.phase

	local snapshot = {
		phase = phase,
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
		askingPrice = deal.currentSellerPrice,
		currentSellerPrice = deal.currentSellerPrice,
		originalAskingPrice = deal.originalAskingPrice,
		minimumAccept = deal.minimumAccept,
		buyerOffer = deal.currentBuyerOffer,
		currentBuyerOffer = deal.currentBuyerOffer,
		buyerMaximum = deal.buyerMaximum,
		estimatedLow = deal.estimatedLow,
		estimatedHigh = deal.estimatedHigh,
		playerCash = DataService:getCash(player),
		sellerHeat = deal.sellerHeat,
		sellerHeatMax = deal.sellerHeatMax,
		buyerHeat = deal.buyerHeat,
		buyerHeatMax = deal.buyerHeatMax,
		sellerTell = deal.sellerTell,
		buyerTell = deal.buyerTell,
		heatWarning = deal.heatWarning,
		inspected = deal.inspected,
		inspectHint = deal.inspectHint,
		buyRoundCount = deal.buyRoundCount,
		sellRoundCount = deal.sellRoundCount,
		lastTactic = deal.lastTactic,
		lastTacticResult = deal.lastTacticResult,
		tacticsUsed = deal.tacticsUsed,
		instanceId = deal.pendingInstanceId,
		purchasePrice = deal.purchasePrice,
		salePrice = deal.salePrice,
		dealSummary = deal.dealSummary,
	}

	if deal.hiddenOutcome then
		if phase == "Purchased" or phase == "Selling" or phase == "Result" then
			snapshot.trueValue = deal.hiddenOutcome.trueValue
			snapshot.rarityName = rarity and rarity.displayName or deal.hiddenOutcome.rarityId
		end
	end

	return snapshot
end

function DealService:startDeal(player: Player, customerId: string?, itemId: string?)
	if not player.Parent then
		return { ok = false, error = "Player left" }
	end
	local canStart, err = self:_canStartDeal(player)
	if not canStart then
		return { ok = false, error = err }
	end

	local rng = self:_getRng(player)
	local customer = if customerId then CustomerService:getCustomer(customerId) else CustomerService:rollCustomer(rng)
	local item = if itemId then CustomerService:getItem(itemId) else CustomerService:rollItem(rng)
	if not customer or not item then
		return { ok = false, error = "Invalid customer or item id" }
	end

	local hidden = ItemValuation.createHiddenOutcome(item, customer, rng)
	local estLow, estHigh = ItemValuation.generateEstimatedRange(item, customer, hidden.trueValue, rng)
	local ask = TacticHaggleMath.calculateAskingPrice(customer, hidden.trueValue, rng)
	local minAccept = TacticHaggleMath.calculateMinimumAccept(customer, item, hidden.trueValue, ask)

	local deal = self:_initDealState(customer, item, hidden, ask, minAccept, estLow, estHigh, rng)
	activeDeals[player] = deal
	self:_logDealStart(player, deal)
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:useBuyTactic(player: Player, tacticId: any)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Haggling" then
		return { ok = false, error = "No buy haggle" }
	end

	tacticId = if type(tacticId) == "string" then tacticId else ""
	if tacticId == HaggleTactics.Buy.Pass then
		return self:passDeal(player)
	end
	if tacticId == HaggleTactics.Buy.AcceptPrice then
		return self:_acceptSellerPrice(player, deal)
	end
	if not VALID_BUY_TACTICS[tacticId] then
		return { ok = false, error = "Unknown tactic" }
	end

	deal.buyRoundCount += 1
	local ctx = {
		customer = deal.customer,
		item = deal.item,
		currentSellerPrice = deal.currentSellerPrice,
		minimumAccept = deal.minimumAccept,
		trueValue = deal.hiddenOutcome.trueValue,
		sellerHeat = deal.sellerHeat,
		sellerHeatMax = deal.sellerHeatMax,
		inspected = deal.inspected,
		estimateInflated = deal.estimateInflated,
		rarityId = deal.hiddenOutcome.rarityId,
		lastTactic = deal.lastTactic,
		rng = self:_getRng(player),
	}

	local result = TacticHaggleMath.evaluateBuyTactic(tacticId, ctx)
	if not result.ok then
		return result
	end

	self:_recordTactic(deal, tacticId, result)

	if result.walkedAway then
		return self:_handleBuyWalkaway(player, deal, result)
	end

	if result.crack then
		deal.estimatedLow, deal.estimatedHigh = ItemValuation.narrowEstimateAfterInspect(
			deal.estimatedLow,
			deal.estimatedHigh,
			deal.hiddenOutcome.trueValue
		)
		deal.inspectHint = "They slipped — estimate tightened."
	end

	deal.currentSellerPrice = result.newPrice
	deal.askingPrice = result.newPrice
	deal.sellerHeat = result.newHeat
	deal.heatWarning = result.warning
	deal.dialogue = result.dialogue
	if result.warning then
		deal.dialogue ..= ` {result.warning}`
	end
	if result.bigWin then
		deal.dialogue ..= " Big opportunity!"
	end

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal), tacticResult = result }
end

function DealService:_acceptSellerPrice(player: Player, deal)
	local price = deal.currentSellerPrice
	if not DataService:canAfford(player, price) then
		deal.dialogue = `You don't have enough {currencyWord()} for {price}.`
		self:_pushState(player)
		return { ok = false, error = "Not enough cash" }
	end
	return self:_completePurchase(player, price, deal)
end

function DealService:inspectItem(player: Player)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Haggling" then
		return { ok = false, error = "Cannot inspect now" }
	end
	if deal.inspected then
		return { ok = false, error = "Already inspected" }
	end
	if not DataService:canAfford(player, HaggleTuning.inspectCost) then
		deal.dialogue = `You can't afford an inspection.`
		self:_pushState(player)
		return { ok = false, error = "Not enough cash" }
	end

	DataService:spend(player, HaggleTuning.inspectCost)
	deal.inspected = true
	deal.estimatedLow, deal.estimatedHigh = ItemValuation.narrowEstimateAfterInspect(
		deal.estimatedLow,
		deal.estimatedHigh,
		deal.hiddenOutcome.trueValue
	)
	deal.estimateInflated = ItemValuation.isEstimateInflated(
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
	local bonusTell = NpcTells.inspectBonusTell(deal.customer, deal.hiddenOutcome.rarityId, deal.estimateInflated)
	if bonusTell then
		deal.sellerTell = bonusTell
	end
	deal.dialogue = deal.inspectHint
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_completePurchase(player: Player, price: number, deal)
	if not DataService:canAfford(player, price) then
		deal.dialogue = `You don't have enough {currencyWord()}.`
		self:_pushState(player)
		return { ok = false, error = "Not enough cash" }
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
	deal.dialogue = `Bought for {price} {currencyWord()}. True value: {deal.hiddenOutcome.trueValue} {currencyWord()}. Find a buyer!`
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:startSelling(player: Player, instanceId: any?)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Purchased" then
		if deal and deal.phase == "Selling" then
			return self:_rerollBuyer(player, deal)
		end
		return { ok = false, error = "Buy the item first" }
	end
	if instanceId and (type(instanceId) ~= "string" or instanceId ~= deal.pendingInstanceId) then
		return { ok = false, error = "Invalid item" }
	end
	self:_beginBuyerNegotiation(deal, BuyerService:rollBuyer(self:_getRng(player)), self:_getRng(player))
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_rerollBuyer(player: Player, deal)
	self:_beginBuyerNegotiation(deal, BuyerService:rollBuyer(self:_getRng(player)), self:_getRng(player))
	deal.dialogue = `New buyer: {deal.buyer.displayName}. Offer: {deal.currentBuyerOffer} {currencyWord()}.`
	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_beginBuyerNegotiation(deal, buyer, rng: Random)
	local trueValue = deal.hiddenOutcome.trueValue
	local category = deal.item.category
	local offer = TacticHaggleMath.calculateBuyerOpeningOffer(buyer, trueValue, category, rng)
	local maximum = TacticHaggleMath.calculateBuyerMaximum(buyer, trueValue, category)
	local cur = currencyWord()

	deal.buyer = buyer
	deal.currentBuyerOffer = offer
	deal.buyerOffer = offer
	deal.buyerOpeningOffer = offer
	deal.buyerMaximum = maximum
	deal.buyerHeat = 0
	deal.buyerHeatMax = HaggleTuning.heatMax
	deal.buyerTell = NpcTells.forBuyer(buyer, category, rng)
	deal.phase = "Selling"
	deal.heatWarning = nil
	deal.dialogue = `{buyer.openingLine} Offer: {offer} {cur}.`
end

function DealService:useSellTactic(player: Player, tacticId: any)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Selling" then
		return { ok = false, error = "No sell haggle" }
	end

	tacticId = if type(tacticId) == "string" then tacticId else ""
	if tacticId == HaggleTactics.Sell.FindAnotherBuyer then
		return self:_rerollBuyer(player, deal)
	end
	if tacticId == HaggleTactics.Sell.AcceptOffer then
		return self:_completeSale(player, deal, deal.currentBuyerOffer)
	end
	if not VALID_SELL_TACTICS[tacticId] then
		return { ok = false, error = "Unknown tactic" }
	end

	deal.sellRoundCount += 1
	local ctx = {
		buyer = deal.buyer,
		itemCategory = deal.item.category,
		currentBuyerOffer = deal.currentBuyerOffer,
		buyerMaximum = deal.buyerMaximum,
		trueValue = deal.hiddenOutcome.trueValue,
		purchasePrice = deal.purchasePrice,
		buyerHeat = deal.buyerHeat,
		buyerHeatMax = deal.buyerHeatMax,
		inspected = deal.inspected,
		lastTactic = deal.lastTactic,
		rng = self:_getRng(player),
	}

	local result = TacticHaggleMath.evaluateSellTactic(tacticId, ctx)
	if not result.ok then
		return result
	end

	self:_recordTactic(deal, tacticId, result)

	if result.walkedAway then
		deal.phase = "Purchased"
		deal.buyer = nil
		deal.currentBuyerOffer = nil
		deal.buyerOffer = nil
		deal.buyerHeat = 0
		deal.dialogue = `{result.dialogue} Find another buyer?`
		deal.heatWarning = nil
		self:_pushState(player)
		return { ok = true, snapshot = self:_buildSnapshot(player, deal), tacticResult = result }
	end

	deal.currentBuyerOffer = result.newPrice
	deal.buyerOffer = result.newPrice
	deal.buyerHeat = result.newHeat
	deal.heatWarning = result.warning
	deal.dialogue = result.dialogue
	if result.warning then
		deal.dialogue ..= ` {result.warning}`
	end
	if result.bigWin then
		deal.dialogue ..= " Huge offer jump!"
	end

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal), tacticResult = result }
end

function DealService:_completeSale(player: Player, deal, salePrice: number)
	DataService:addCash(player, salePrice)
	if deal.pendingInstanceId then
		InventoryService:markDisposed(player, deal.pendingInstanceId)
	end

	deal.salePrice = salePrice
	local profit = salePrice - (deal.purchasePrice or 0)
	local rarity = Rarities[deal.hiddenOutcome.rarityId]

	deal.dealSummary = {
		sellerName = deal.customer.displayName,
		sellerId = deal.customer.id,
		sellerTell = deal.sellerTell,
		buyerName = deal.buyer and deal.buyer.displayName,
		buyerId = deal.buyer and deal.buyer.id,
		buyerTell = deal.buyerTell,
		itemName = deal.item.displayName,
		rarityId = deal.hiddenOutcome.rarityId,
		rarityName = rarity and rarity.displayName,
		trueValue = deal.hiddenOutcome.trueValue,
		sellerAsk = deal.originalAskingPrice,
		sellerMinimum = deal.minimumAccept,
		purchasePrice = deal.purchasePrice,
		buyerOpeningOffer = deal.buyerOpeningOffer,
		buyerMaximum = deal.buyerMaximum,
		salePrice = salePrice,
		profit = profit,
		buyRounds = deal.buyRoundCount,
		sellRounds = deal.sellRoundCount,
		inspected = deal.inspected,
		tacticsUsed = table.concat(deal.tacticsUsed or {}, ", "),
		finalSellerHeat = deal.sellerHeat,
		finalBuyerHeat = deal.buyerHeat,
	}
	deal.dealSummary.resultText = self:_formatDealSummaryText(deal.dealSummary)
	self:_logDealSummary(player, deal)

	deal.phase = "Result"
	deal.dialogue = deal.dealSummary.resultText
	deal.pendingInstanceId = nil
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayResult, deal)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:passDeal(player: Player)
	local deal = activeDeals[player]
	if not deal then
		return { ok = false, error = "No deal" }
	end
	if deal.phase == "Purchased" or deal.phase == "Selling" then
		return self:keepItem(player, deal.pendingInstanceId)
	end
	if deal.phase == "Result" or deal.phase == "WalkedAway" then
		playerNextDealAt[player] = nil
		return self:startDeal(player)
	end
	deal.phase = "WalkedAway"
	deal.dialogue = "You let them walk."
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayPass, deal)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:_handleBuyWalkaway(player: Player, deal, result)
	deal.phase = "WalkedAway"
	deal.dialogue = result.dialogue
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayWalkedAway, deal)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:keepItem(player: Player, instanceId: any)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Purchased" and deal.phase ~= "Selling") then
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
	local rarity = Rarities[deal.hiddenOutcome.rarityId]
	deal.dealSummary = {
		sellerName = deal.customer.displayName,
		sellerId = deal.customer.id,
		sellerTell = deal.sellerTell,
		buyerName = deal.buyer and deal.buyer.displayName or "none",
		buyerId = deal.buyer and deal.buyer.id,
		itemName = deal.item.displayName,
		rarityName = rarity and rarity.displayName,
		trueValue = deal.hiddenOutcome.trueValue,
		purchasePrice = deal.purchasePrice,
		salePrice = nil,
		profit = paperProfit,
		buyRounds = deal.buyRoundCount,
		sellRounds = deal.sellRoundCount,
		inspected = deal.inspected,
		tacticsUsed = table.concat(deal.tacticsUsed or {}, ", "),
	}
	deal.dealSummary.resultText = self:_formatDealSummaryText(deal.dealSummary)
	self:_logDealSummary(player, deal)
	deal.phase = "Result"
	deal.dialogue = deal.dealSummary.resultText
	deal.pendingInstanceId = nil
	self:_pushState(player)
	self:_scheduleNextDeal(player, HaggleTuning.autoNextDelayResult, deal)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
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

function DealService:_formatDealSummaryText(summary)
	local cur = currencyWord()
	local lines = {}
	if summary.salePrice then
		table.insert(lines, `Sold for {summary.salePrice} {cur}. Profit: {summary.profit} {cur}`)
	else
		table.insert(lines, `Kept item. Paper profit: {summary.profit} {cur}`)
	end
	table.insert(lines, `{summary.itemName} ({summary.rarityName}) | True: {summary.trueValue}`)
	table.insert(lines, `Seller: {summary.sellerName} | Buyer: {summary.buyerName or "none"}`)
	table.insert(lines, `Paid: {summary.purchasePrice} | Ask was: {summary.sellerAsk} (min {summary.sellerMinimum})`)
	if summary.buyerOpeningOffer then
		table.insert(lines, `Buyer opened {summary.buyerOpeningOffer} (max {summary.buyerMaximum})`)
	end
	table.insert(lines, `Tactics: {summary.tacticsUsed or "none"} | Inspected: {summary.inspected}`)
	return table.concat(lines, "\n")
end

function DealService:_logDealStart(player: Player, deal)
	if not RunService:IsStudio() then
		return
	end
	print(
		`[WastelandPawn] DEAL START | {deal.customer.displayName} | {deal.item.displayName} | ask={deal.currentSellerPrice} min={deal.minimumAccept} true={deal.hiddenOutcome.trueValue} tell="{deal.sellerTell}"`
	)
end

function DealService:_logDealSummary(player: Player, deal)
	if not RunService:IsStudio() or not deal.dealSummary then
		return
	end
	local s = deal.dealSummary
	print(
		`[WastelandPawn] DEAL DONE | true={s.trueValue} ask={s.sellerAsk} min={s.sellerMinimum} bought={s.purchasePrice} buyer={s.buyerId} open={s.buyerOpeningOffer} max={s.buyerMaximum} sold={s.salePrice or "kept"} profit={s.profit} inspected={s.inspected} tactics={s.tacticsUsed} sellerTell="{deal.sellerTell}" buyerTell="{deal.buyerTell or ""}" heat={deal.sellerHeat}/{deal.buyerHeat}`
	)
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
		DataService:setCash(player, tonumber(parts[2]) or 1000)
		self:_pushState(player)
	elseif command == "deal" then
		if parts[2] and parts[3] then
			playerNextDealAt[player] = nil
			self:startDeal(player, parts[2], parts[3])
		end
	elseif command == "buyer" and parts[2] then
		local deal = activeDeals[player]
		if deal and (deal.phase == "Purchased" or deal.phase == "Selling") then
			local buyer = BuyerService:getBuyer(parts[2])
			if buyer then
				self:_beginBuyerNegotiation(deal, buyer, self:_getRng(player))
				self:_pushState(player)
			end
		end
	elseif command == "summary" then
		local deal = activeDeals[player]
		if deal then
			print(`[WastelandPawn] phase={deal.phase} heat={deal.sellerHeat}/{deal.buyerHeat} price={deal.currentSellerPrice} offer={deal.currentBuyerOffer}`)
		end
	end
end

return DealService
