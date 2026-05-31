local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)

local DealController = {}

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

function DealController:Init()
	self:_bindUi()
end

function DealController:_bindUi()
	UIController:onOffer(function()
		local amount = UIController:getOfferAmount()
		if not amount then
			return
		end
		invokeRemote("MakeOffer", amount)
	end)

	UIController:onQuickOffer(function(kind: string)
		local snapshot = UIController:getSnapshot()
		if not snapshot or not snapshot.askingPrice then
			return
		end

		local asking = snapshot.askingPrice
		local amount = asking
		if kind == "lowball" then
			amount = math.floor(asking * 0.45)
		elseif kind == "fair" then
			amount = math.floor(asking * 0.82)
		end

		UIController:setOfferAmount(amount)
		invokeRemote("MakeOffer", amount)
	end)

	UIController:onInspect(function()
		invokeRemote("InspectItem")
	end)

	UIController:onAcceptCounter(function()
		invokeRemote("AcceptCounter")
	end)

	UIController:onPass(function()
		invokeRemote("PassDeal")
	end)

	UIController:onSell(function()
		local snapshot = UIController:getSnapshot()
		if snapshot and snapshot.instanceId then
			invokeRemote("SellItem", snapshot.instanceId)
		end
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
	end)

	task.defer(function()
		invokeRemote("StartDeal")
	end)
end

return DealController
