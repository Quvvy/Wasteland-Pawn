local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)

local DealController = {}

local OFFER_COOLDOWN = 0.5
local REPEAT_BLOCK_COOLDOWN = 1.2

local function invokeRemote(remoteName: string, ...: any): (boolean, any)
	local remote = Remotes.get(remoteName) :: RemoteFunction
	local ok, result = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)

	if not ok then
		warn(`Remote {remoteName} failed: {result}`)
		return false, nil
	end

	return true, result
end

local function briefOfferCooldown(duration: number?)
	UIController:setHaggleButtonsEnabled(false)
	task.delay(duration or OFFER_COOLDOWN, function()
		UIController:setHaggleButtonsEnabled(true)
	end)
end

local function afterOfferResult(result: any)
	if result and result.snapshot and result.snapshot.repeatBlocked then
		briefOfferCooldown(REPEAT_BLOCK_COOLDOWN)
	end
end

function DealController:Init()
	self:_bindUi()
end

function DealController:_bindUi()
	UIController:onOffer(function()
		local snapshot = UIController:getSnapshot()
		local amount = UIController:getOfferAmount()
		if not amount then
			return
		end
		briefOfferCooldown()

		local phase = snapshot and snapshot.phase
		if phase == "Selling" or phase == "BuyerCounter" then
			local _, result = invokeRemote("MakeSellAsk", amount)
			afterOfferResult(result)
		else
			local _, result = invokeRemote("MakeOffer", amount, "normal")
			afterOfferResult(result)
		end
	end)

	UIController:onQuickOffer(function(kind: string)
		local snapshot = UIController:getSnapshot()
		if not snapshot then
			return
		end

		local phase = snapshot.phase
		if phase == "Selling" or phase == "BuyerCounter" then
			local base = snapshot.buyerCounterOffer or snapshot.buyerOffer or snapshot.trueValue or 0
			local amount = math.floor(base * (if kind == "fair" then 1.12 else 1.25))
			UIController:setOfferAmount(amount)
			briefOfferCooldown()
			local _, result = invokeRemote("MakeSellAsk", amount)
			afterOfferResult(result)
			return
		end

		if not snapshot.askingPrice then
			return
		end

		local asking = snapshot.askingPrice
		local amount = asking
		local offerKind = "normal"
		if kind == "lowball" then
			amount = math.floor(asking * 0.45)
			offerKind = "lowball"
		elseif kind == "fair" then
			amount = math.floor(asking * 0.82)
		end

		UIController:setOfferAmount(amount)
		briefOfferCooldown()
		local _, result = invokeRemote("MakeOffer", amount, offerKind)
		afterOfferResult(result)
	end)

	UIController:onInspect(function()
		invokeRemote("InspectItem")
	end)

	UIController:onAcceptCounter(function()
		briefOfferCooldown()
		invokeRemote("AcceptCounter")
	end)

	UIController:onFindBuyer(function()
		local snapshot = UIController:getSnapshot()
		if snapshot and snapshot.instanceId then
			invokeRemote("StartSelling", snapshot.instanceId)
		else
			invokeRemote("StartSelling")
		end
	end)

	UIController:onAcceptBuyer(function()
		briefOfferCooldown()
		invokeRemote("AcceptBuyerOffer")
	end)

	UIController:onSellBump(function()
		local snapshot = UIController:getSnapshot()
		if not snapshot then
			return
		end
		local base = UIController:getOfferAmount() or snapshot.buyerCounterOffer or snapshot.buyerOffer or 0
		local amount = math.floor(base * 1.1)
		UIController:setOfferAmount(amount)
		briefOfferCooldown()
		local _, result = invokeRemote("MakeSellAsk", amount)
		afterOfferResult(result)
	end)

	UIController:onPass(function()
		invokeRemote("PassDeal")
	end)

	UIController:onKeep(function()
		local snapshot = UIController:getSnapshot()
		if snapshot and snapshot.instanceId then
			invokeRemote("KeepItem", snapshot.instanceId)
		end
	end)

	UIController:onNext(function()
		invokeRemote("StartDeal")
	end)
end

function DealController:Start()
	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(function(snapshot)
		UIController:updateSnapshot(snapshot)
		if snapshot.repeatBlocked then
			briefOfferCooldown(REPEAT_BLOCK_COOLDOWN)
		end
	end)

	task.defer(function()
		invokeRemote("StartDeal")
	end)
end

return DealController
