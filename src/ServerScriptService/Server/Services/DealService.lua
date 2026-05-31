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

local DealService = {}

local activeDeals: { [Player]: any } = {}
local playerRng: { [Player]: Random } = {}

function DealService:Init()
	Remotes.setup()
end

function DealService:Start()
	local makeOffer = Remotes.get("MakeOffer") :: RemoteFunction
	local inspectItem = Remotes.get("InspectItem") :: RemoteFunction
	local acceptCounter = Remotes.get("AcceptCounter") :: RemoteFunction
	local passDeal = Remotes.get("PassDeal") :: RemoteFunction
	local sellItem = Remotes.get("SellItem") :: RemoteFunction
	local keepItem = Remotes.get("KeepItem") :: RemoteFunction
	local startDeal = Remotes.get("StartDeal") :: RemoteFunction

	makeOffer.OnServerInvoke = function(player, amount)
		return self:makeOffer(player, amount)
	end

	inspectItem.OnServerInvoke = function(player)
		return self:inspectItem(player)
	end

	acceptCounter.OnServerInvoke = function(player)
		return self:acceptCounter(player)
	end

	passDeal.OnServerInvoke = function(player)
		return self:passDeal(player)
	end

	sellItem.OnServerInvoke = function(player, instanceId)
		return self:sellItem(player, instanceId)
	end

	keepItem.OnServerInvoke = function(player, instanceId)
		return self:keepItem(player, instanceId)
	end

	startDeal.OnServerInvoke = function(player)
		return self:startDeal(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		activeDeals[player] = nil
		playerRng[player] = nil
	end)

	if RunService:IsStudio() then
		self:_setupStudioDebug()
	end
end

function DealService:_setupStudioDebug()
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			self:_handleDebugChat(player, message)
		end)
	end)

	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(message)
			self:_handleDebugChat(player, message)
		end)
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
		print(`[WastelandPawn] Set {player.Name} cash to {amount}`)
		self:_pushState(player)
	elseif command == "deal" then
		local customerId = parts[2]
		local itemId = parts[3]
		if not customerId or not itemId then
			print("[WastelandPawn] Usage: /deal <customerId> <itemId>")
			return
		end
		self:startDeal(player, customerId, itemId)
	else
		return
	end
end

function DealService:_logDealDebug(player: Player, deal)
	if not RunService:IsStudio() then
		return
	end

	print(
		`[WastelandPawn] {player.Name} | {deal.customer.displayName} + {deal.item.displayName} | ask={deal.askingPrice} min={deal.minimumAccept} true={deal.hiddenOutcome.trueValue} ({deal.hiddenOutcome.rarityId})`
	)
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
	local snapshot = {
		phase = deal.phase,
		customerId = deal.customer.id,
		customerName = deal.customer.displayName,
		dialogue = deal.dialogue,
		itemId = deal.item.id,
		itemName = deal.item.displayName,
		category = deal.item.category,
		flavorText = deal.item.flavorText,
		askingPrice = deal.askingPrice,
		counterOffer = deal.counterOffer,
		estimatedLow = deal.estimatedLow,
		estimatedHigh = deal.estimatedHigh,
		playerCash = DataService:getCash(player),
		patience = deal.patience,
		maxPatience = deal.maxPatience,
		inspected = deal.inspected,
		inspectHint = deal.inspectHint,
		roundCount = deal.roundCount,
		instanceId = deal.pendingInstanceId,
		purchasePrice = deal.purchasePrice,
		resultMessage = deal.resultMessage,
		lastOutcome = deal.lastOutcome,
		patienceDelta = deal.lastPatienceDelta,
	}

	if deal.phase == "Purchased" or deal.phase == "Result" then
		snapshot.trueValue = deal.hiddenOutcome.trueValue
		snapshot.rarityName = rarity and rarity.displayName or deal.hiddenOutcome.rarityId
		snapshot.profitPreview = deal.hiddenOutcome.trueValue - (deal.purchasePrice or 0)
	end

	return snapshot
end

function DealService:startDeal(player: Player, customerId: string?, itemId: string?)
	if not player.Parent then
		return { ok = false, error = "Player left" }
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
	local maxPatience = HaggleMath.getStartingPatience(customer)

	local deal = {
		customer = customer,
		item = item,
		hiddenOutcome = hiddenOutcome,
		askingPrice = askingPrice,
		minimumAccept = minimumAccept,
		counterOffer = nil,
		patience = maxPatience,
		maxPatience = maxPatience,
		phase = "Haggling",
		inspected = false,
		estimatedLow = estimatedLow,
		estimatedHigh = estimatedHigh,
		inspectHint = nil,
		roundCount = 0,
		pendingInstanceId = nil,
		purchasePrice = nil,
		resultMessage = nil,
		lastOutcome = nil,
		lastPatienceDelta = nil,
		dialogue = customer.openingLine .. ` Asking {askingPrice} caps.`,
	}

	activeDeals[player] = deal
	self:_logDealDebug(player, deal)
	self:_pushState(player)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:makeOffer(player: Player, amount: any)
	local deal = activeDeals[player]
	if not deal or (deal.phase ~= "Haggling" and deal.phase ~= "Counter") then
		return { ok = false, error = "No active haggle" }
	end

	local offerAmount = self:_sanitizeAmount(amount)
	if not offerAmount then
		return { ok = false, error = "Invalid offer" }
	end

	deal.roundCount += 1
	local evaluation = HaggleMath.evaluateOffer(deal.customer, deal.item, offerAmount, deal, self:_getRng(player))
	deal.patience = math.clamp(deal.patience + evaluation.patienceDelta, 0, deal.maxPatience)
	deal.lastOutcome = evaluation.outcome
	deal.lastPatienceDelta = evaluation.patienceDelta
	deal.dialogue = evaluation.reactionText

	if evaluation.outcome == "accept" then
		deal.lastOutcome = "accept"
		return self:_completePurchase(player, offerAmount, deal)
	end

	if evaluation.outcome == "walkaway" then
		deal.phase = "WalkedAway"
		deal.counterOffer = nil
		deal.dialogue = evaluation.reactionText
		self:_pushState(player)
		task.delay(HaggleTuning.autoNextDelayWalkedAway, function()
			if activeDeals[player] == deal and deal.phase == "WalkedAway" then
				self:startDeal(player)
			end
		end)
		return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
	end

	if evaluation.outcome == "counter" then
		deal.phase = "Counter"
		deal.counterOffer = evaluation.counterOffer
		deal.lastOutcome = "counter"
		deal.dialogue = `{evaluation.reactionText} Counter: {deal.counterOffer} caps.`
	else
		deal.phase = "Haggling"
		deal.counterOffer = nil
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
		deal.dialogue = "You can't afford an inspection."
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

	deal.lastOutcome = "accept"
	return self:_completePurchase(player, deal.counterOffer, deal)
end

function DealService:_completePurchase(player: Player, price: number, deal)
	if not DataService:canAfford(player, price) then
		deal.dialogue = "You don't have enough caps."
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
	deal.counterOffer = nil
	deal.dialogue = `Bought for {price} caps. True value revealed!`

	self:_pushState(player)
	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:passDeal(player: Player)
	local deal = activeDeals[player]
	if not deal then
		return { ok = false, error = "No deal" }
	end

	if deal.phase == "Purchased" then
		return { ok = false, error = "Finish this purchase first" }
	end

	if deal.phase == "WalkedAway" or deal.phase == "Result" then
		self:startDeal(player)
		return { ok = true }
	end

	deal.phase = "WalkedAway"
	deal.dialogue = "You let them walk. Another customer will show up."
	deal.lastOutcome = "walkaway"
	self:_pushState(player)

	task.delay(HaggleTuning.autoNextDelayPass, function()
		if activeDeals[player] == deal then
			self:startDeal(player)
		end
	end)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:sellItem(player: Player, instanceId: any)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Purchased" then
		return { ok = false, error = "Nothing to sell" }
	end

	if type(instanceId) ~= "string" or instanceId ~= deal.pendingInstanceId then
		return { ok = false, error = "Invalid item" }
	end

	local entry = InventoryService:getOwnedItem(player, instanceId)
	if not entry then
		return { ok = false, error = "Item not found" }
	end

	DataService:addCash(player, entry.trueValue)
	InventoryService:markDisposed(player, instanceId)

	local profit = entry.trueValue - entry.purchasePrice
	deal.phase = "Result"
	deal.resultMessage = if profit >= 0
		then `Sold for {entry.trueValue} caps. Profit: +{profit}.`
		else `Sold for {entry.trueValue} caps. Loss: {profit}.`
	deal.dialogue = deal.resultMessage
	deal.pendingInstanceId = nil
	deal.lastOutcome = nil

	self:_pushState(player)

	task.delay(HaggleTuning.autoNextDelayResult, function()
		if activeDeals[player] == deal and deal.phase == "Result" then
			self:startDeal(player)
		end
	end)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

function DealService:keepItem(player: Player, instanceId: any)
	local deal = activeDeals[player]
	if not deal or deal.phase ~= "Purchased" then
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
	deal.phase = "Result"
	deal.resultMessage = `Kept {entry.displayName}. Paper value: {entry.trueValue} caps (unrealized).`
	deal.dialogue = deal.resultMessage
	deal.pendingInstanceId = nil
	deal.lastOutcome = nil

	self:_pushState(player)

	task.delay(HaggleTuning.autoNextDelayResult, function()
		if activeDeals[player] == deal and deal.phase == "Result" then
			self:startDeal(player)
		end
	end)

	return { ok = true, snapshot = self:_buildSnapshot(player, deal) }
end

return DealService
