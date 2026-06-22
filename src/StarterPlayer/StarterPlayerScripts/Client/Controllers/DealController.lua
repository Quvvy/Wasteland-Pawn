local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTactics = require(Shared.Economy.HaggleTactics)
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)

local DealController = {}

local TACTIC_COOLDOWN = 0.35
local shiftStartPending = false

local BUY_TACTIC_KEYS = {
	lowball = HaggleTactics.Buy.Lowball,
	split = HaggleTactics.Buy.SplitDifference,
	flaw = HaggleTactics.Buy.PointOutFlaw,
	pressure = HaggleTactics.Buy.Pressure,
	acceptBuy = HaggleTactics.Buy.AcceptPrice,
	pass = HaggleTactics.Buy.Pass,
}

local SELL_TACTIC_KEYS = {
	smallBump = HaggleTactics.Sell.SmallBump,
	pitch = HaggleTactics.Sell.PitchValue,
	holdFirm = HaggleTactics.Sell.HoldFirm,
	bluff = HaggleTactics.Sell.Bluff,
	acceptSell = HaggleTactics.Sell.AcceptOffer,
	findAnother = HaggleTactics.Sell.FindAnotherBuyer,
}

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

local function formatError(prefix: string, result): string
	local message = if type(result) == "table" then result.error else nil
	if type(message) == "string" and message ~= "" then
		if message == "Shift already active" then
			message = "Shop is already open"
		end
		return `{prefix}: {message}`
	end
	return prefix
end

function DealController:briefCooldown()
	UIController:setTacticButtonsEnabled(false)
	task.delay(TACTIC_COOLDOWN, function()
		UIController:setTacticButtonsEnabled(true)
	end)
end

function DealController:performBuyTactic(key: string)
	local tacticId = BUY_TACTIC_KEYS[key]
	if not tacticId then
		return
	end
	self:briefCooldown()
	if tacticId == HaggleTactics.Buy.Pass then
		invokeRemote("PassDeal")
	else
		invokeRemote("UseBuyTactic", tacticId)
	end
end

function DealController:performSellTactic(key: string)
	local tacticId = SELL_TACTIC_KEYS[key]
	if not tacticId then
		return
	end
	self:briefCooldown()
	invokeRemote("UseSellTactic", tacticId)
end

function DealController:performInspect()
	invokeRemote("InspectItem")
end

function DealController:performPass()
	invokeRemote("PassDeal")
end

function DealController:performOfferInventoryItem(instanceId: string)
	invokeRemote("SelectInventoryItemForBuyer", instanceId)
end

function DealController:performKeep()
	local snapshot = UIController:getSnapshot()
	if snapshot and snapshot.phase == "BuyerVisit" then
		invokeRemote("KeepItem")
	elseif snapshot and snapshot.instanceId then
		invokeRemote("KeepItem", snapshot.instanceId)
	end
end

function DealController:performNextCustomer()
	invokeRemote("StartDeal")
end

function DealController:performCloseShop()
	local ok, result = invokeRemote("CloseShift")
	if ok and result and result.ok and result.shiftSnapshot then
		UIController:updateShiftSnapshot(result.shiftSnapshot)
	end
end

function DealController:Init()
	self:_bindUi()
end

function DealController:_bindUi()
	UIController:onBuyTactic(function(key: string)
		self:performBuyTactic(key)
	end)

	UIController:onSellTactic(function(key: string)
		self:performSellTactic(key)
	end)

	UIController:onInspect(function()
		self:performInspect()
	end)

	UIController:onFindBuyer(function()
		local snapshot = UIController:getSnapshot()
		if snapshot and snapshot.instanceId then
			invokeRemote("StartSelling", snapshot.instanceId)
		else
			invokeRemote("StartSelling")
		end
	end)

	UIController:onOfferInventoryItem(function(instanceId: string)
		self:performOfferInventoryItem(instanceId)
	end)

	UIController:onKeep(function()
		self:performKeep()
	end)

	UIController:onCloseShift(function()
		self:performCloseShop()
	end)

	UIController:onNext(function()
		self:performNextCustomer()
	end)

	UIController:onShiftSelectStart(function(shiftId: string)
		self:startShiftFlow(shiftId)
	end)
end

function DealController:startShiftFlow(shiftId: string): boolean
	if shiftStartPending then
		UIController:showHubMessage("Open Shop is already in progress.")
		return false
	end

	if UIController:isShiftActive() then
		UIController:showHubMessage("Shop is already open.")
		return false
	end

	shiftStartPending = true
	local ok, result = invokeRemote("StartShift", shiftId)
	if ok and type(result) == "table" and result.ok then
		UIController:updateShiftSnapshot(result.snapshot)
		UIController:closeShiftSelect()
		local dealOk, dealResult = invokeRemote("StartDeal")
		if not dealOk then
			UIController:showHubMessage("Shop opened, but the first seller could not load.")
		elseif type(dealResult) ~= "table" or not dealResult.ok then
			UIController:showHubMessage(formatError("Shop opened, but the first seller could not load", dealResult))
		end
		shiftStartPending = false
		return true
	end

	if type(result) == "table" and result.snapshot then
		UIController:updateShiftSnapshot(result.snapshot)
	end
	UIController:showHubMessage(formatError("Could not open shop", result))
	shiftStartPending = false
	return false
end

function DealController:Start()
	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(function(snapshot)
		UIController:updateSnapshot(snapshot)
	end)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(function(snapshot)
		UIController:updateShiftSnapshot(snapshot)
	end)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(function(snapshot)
		UIController:updateInventorySnapshot(snapshot)
	end)
end

return DealController
