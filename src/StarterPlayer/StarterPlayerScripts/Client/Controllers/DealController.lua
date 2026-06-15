local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTactics = require(Shared.Economy.HaggleTactics)
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)

local DealController = {}

local TACTIC_COOLDOWN = 0.35

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

local function briefCooldown()
	UIController:setTacticButtonsEnabled(false)
	task.delay(TACTIC_COOLDOWN, function()
		UIController:setTacticButtonsEnabled(true)
	end)
end

function DealController:Init()
	self:_bindUi()
end

function DealController:_bindUi()
	local buyTactics = {
		lowball = HaggleTactics.Buy.Lowball,
		split = HaggleTactics.Buy.SplitDifference,
		flaw = HaggleTactics.Buy.PointOutFlaw,
		pressure = HaggleTactics.Buy.Pressure,
		acceptBuy = HaggleTactics.Buy.AcceptPrice,
		pass = HaggleTactics.Buy.Pass,
	}

	UIController:onBuyTactic(function(key: string)
		local tacticId = buyTactics[key]
		if not tacticId then
			return
		end
		briefCooldown()
		if tacticId == HaggleTactics.Buy.Pass then
			invokeRemote("PassDeal")
		else
			invokeRemote("UseBuyTactic", tacticId)
		end
	end)

	local sellTactics = {
		smallBump = HaggleTactics.Sell.SmallBump,
		pitch = HaggleTactics.Sell.PitchValue,
		holdFirm = HaggleTactics.Sell.HoldFirm,
		bluff = HaggleTactics.Sell.Bluff,
		acceptSell = HaggleTactics.Sell.AcceptOffer,
		findBuyer = HaggleTactics.Sell.FindAnotherBuyer,
	}

	UIController:onSellTactic(function(key: string)
		local tacticId = sellTactics[key]
		if not tacticId then
			return
		end
		briefCooldown()
		invokeRemote("UseSellTactic", tacticId)
	end)

	UIController:onInspect(function()
		invokeRemote("InspectItem")
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
		invokeRemote("SelectInventoryItemForBuyer", instanceId)
	end)

	UIController:onKeep(function()
		local snapshot = UIController:getSnapshot()
		if snapshot and snapshot.phase == "BuyerVisit" then
			invokeRemote("KeepItem")
		elseif snapshot and snapshot.instanceId then
			invokeRemote("KeepItem", snapshot.instanceId)
		end
	end)

	UIController:onCloseShift(function()
		local ok, result = invokeRemote("CloseShift")
		if ok and result and result.ok and result.shiftSnapshot then
			UIController:updateShiftSnapshot(result.shiftSnapshot)
		end
	end)

	UIController:onNext(function()
		invokeRemote("StartDeal")
	end)

	UIController:onStartShift(function(shiftId: string)
		local ok, result = invokeRemote("StartShift", shiftId)
		if ok and result and result.ok then
			UIController:updateShiftSnapshot(result.snapshot)
			invokeRemote("StartDeal")
		end
	end)
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

	task.defer(function()
		local ok, result = invokeRemote("GetShiftOptions")
		if ok and result and result.ok then
			UIController:updateShiftSnapshot({ active = false, ended = false })
		end
	end)
end

return DealController
