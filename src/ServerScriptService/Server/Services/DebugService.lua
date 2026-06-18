local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Net.Remotes)

local DealService = require(script.Parent.DealService)
local InventoryService = require(script.Parent.InventoryService)
local ShiftService = require(script.Parent.ShiftService)

local DebugService = {}

local debugRng = Random.new()

local TECH_CATEGORIES = { "Old World Tech", "Alien Tech" }
local COLLECTIBLE_CATEGORY = { "Collectibles" }

local function requireActiveShift(player: Player): (any?, { ok: boolean, error: string }?)
	local shift = ShiftService:getShift(player)
	if not shift or not shift.active or shift.ended then
		return nil, { ok = false, error = "No active shift" }
	end
	return shift, nil
end

local function rejectUnsafeDeal(player: Player, sellingMessage: string?): { ok: boolean, error: string }?
	local phase = DealService:debugGetActiveDealPhase(player)
	if phase == "Selling" then
		return { ok = false, error = sellingMessage or "Finish or skip the active sale first" }
	end
	if phase == "Haggling" then
		return { ok = false, error = "Finish current deal first" }
	end
	return nil
end

function DebugService:runAction(player: Player, actionId: any, _payload: any)
	if not RunService:IsStudio() then
		return { ok = false, error = "Debug actions disabled" }
	end
	if type(actionId) ~= "string" or actionId == "" then
		return { ok = false, error = "Invalid action" }
	end

	if actionId == "GiveRandomItem" then
		return self:_giveRandomItem(player, Items.getRandom(debugRng))
	elseif actionId == "GiveRandomTech" then
		return self:_giveRandomItem(player, Items.pickRandomInCategories(TECH_CATEGORIES, debugRng))
	elseif actionId == "GiveRandomCollectible" then
		return self:_giveRandomItem(player, Items.pickRandomInCategories(COLLECTIBLE_CATEGORY, debugRng))
	elseif actionId == "FillInventory" then
		return self:_fillInventory(player)
	elseif actionId == "ClearInventory" then
		return self:_clearInventory(player)
	elseif actionId == "GiveRandomDisplayItem" then
		return self:_giveRandomDisplayItem(player, Items.getRandom(debugRng))
	elseif actionId == "ForceBuyerVisit" then
		return DealService:debugForceBuyerVisit(player)
	elseif actionId == "SkipToClosingRush" then
		return self:_skipToClosingRush(player)
	elseif actionId == "EndShift" then
		return DealService:debugEndShift(player)
	end

	return { ok = false, error = `Unknown action: {actionId}` }
end

function DebugService:_giveRandomItem(player: Player, itemDef: any)
	local _, shiftError = requireActiveShift(player)
	if shiftError then
		return shiftError
	end
	if not itemDef then
		return { ok = false, error = "No items configured" }
	end

	local instanceId, err = InventoryService:debugAddInventoryItem(player, itemDef)
	if not instanceId then
		return { ok = false, error = err or "Could not add item" }
	end

	return { ok = true, message = `Added {itemDef.displayName}` }
end

function DebugService:_fillInventory(player: Player)
	local _, shiftError = requireActiveShift(player)
	if shiftError then
		return shiftError
	end

	local added = 0
	while InventoryService:canAdd(player) do
		local itemDef = Items.getRandom(debugRng)
		if not itemDef then
			break
		end
		local instanceId, err = InventoryService:debugAddInventoryItem(player, itemDef)
		if not instanceId then
			if added == 0 then
				return { ok = false, error = err or "Inventory full" }
			end
			break
		end
		added += 1
	end

	if added == 0 then
		return { ok = false, error = "Inventory full" }
	end

	return { ok = true, message = `Filled inventory ({added} item(s) added)` }
end

function DebugService:_clearInventory(player: Player)
	local unsafe = rejectUnsafeDeal(player, "Finish or skip the active sale first")
	if unsafe then
		return unsafe
	end

	local cleared, clearError = InventoryService:debugClearWorkingInventory(player)
	if clearError then
		return { ok = false, error = clearError }
	end

	DealService:debugRefreshBuyerVisitMatches(player)

	if cleared == 0 then
		return { ok = true, message = "Working inventory already empty" }
	end

	return { ok = true, message = `Cleared {cleared} working inventory item(s)` }
end

function DebugService:_giveRandomDisplayItem(player: Player, itemDef: any)
	local _, shiftError = requireActiveShift(player)
	if shiftError then
		return shiftError
	end
	if not itemDef then
		return { ok = false, error = "No items configured" }
	end

	local instanceId, err = InventoryService:debugAddDisplayItem(player, itemDef)
	if not instanceId then
		return { ok = false, error = err or "Could not add display item" }
	end

	DealService:debugRefreshBuyerVisitMatches(player)
	return { ok = true, message = `Added {itemDef.displayName} to display` }
end

function DebugService:_skipToClosingRush(player: Player)
	local unsafe = rejectUnsafeDeal(player)
	if unsafe then
		return unsafe
	end

	local shift, shiftError = requireActiveShift(player)
	if shiftError then
		return shiftError
	end

	if shift.phase == "ClosingRush" then
		return { ok = true, message = "Already in Closing Rush" }
	end

	local snapshot = ShiftService:enterClosingRush(player)
	shift = ShiftService:getShift(player)
	if not snapshot or (shift and shift.ended) then
		return { ok = true, message = "Shift ended (no working inventory for Closing Rush)" }
	end

	return { ok = true, message = "Skipped to Closing Rush" }
end

function DebugService:Init()
	Remotes.setup()

	local remote = Remotes.get("DebugRunAction") :: RemoteFunction
	remote.OnServerInvoke = function(player, actionId, payload)
		return self:runAction(player, actionId, payload)
	end
end

function DebugService:Start() end

return DebugService
