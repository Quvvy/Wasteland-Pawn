local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Net.Remotes)

local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
local DataService = require(script.Parent.DataService)
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

function DebugService:getDebugRole(player: Player): string?
	return DebugAccess.getRole(player)
end

function DebugService:canViewDebug(player: Player): boolean
	return DebugAccess.canViewDebug(player)
end

function DebugService:canViewHiddenEconomy(player: Player): boolean
	return DebugAccess.canViewHiddenEconomy(player)
end

function DebugService:canRunDebugAction(player: Player, actionName: string): boolean
	return DebugAccess.canRunDebugAction(player, actionName)
end

function DebugService:validateDebugActionArgs(player: Player, actionName: string, payload: any): (boolean, string?)
	return DebugAccess.validateDebugActionArgs(player, actionName, payload)
end

function DebugService:logDebugAction(player: Player, role: string?, actionName: string, payload: any, result: any)
	local argsSummary = DebugAccess.sanitizeArgsForLog(actionName, payload)
	local ok = type(result) == "table" and result.ok == true
	local detail = if ok
		then (if type(result.message) == "string" then result.message else "ok")
		else (if type(result) == "table" and type(result.error) == "string" then result.error else "failed")
	warn(
		`[WastelandPawn][DevTools] {player.Name} ({player.UserId}) role={role or "none"} action={actionName} args={argsSummary} -> {detail}`
	)
end

function DebugService:getAccess(player: Player)
	return DebugAccess.buildAccessSnapshot(player)
end

function DebugService:runAction(player: Player, actionId: any, payload: any)
	if not DebugAccess.canViewDebug(player) then
		return { ok = false, error = "Forbidden" }
	end
	if type(actionId) ~= "string" or actionId == "" then
		return { ok = false, error = "Invalid action" }
	end
	if not DebugAccess.canRunDebugAction(player, actionId) then
		self:logDebugAction(player, DebugAccess.getRole(player), actionId, payload, { ok = false, error = "Forbidden" })
		return { ok = false, error = "Forbidden" }
	end

	local argsOk, argsError = DebugAccess.validateDebugActionArgs(player, actionId, payload)
	if not argsOk then
		return { ok = false, error = argsError or "Invalid payload" }
	end

	local role = DebugAccess.getRole(player)
	local result

	if actionId == "GiveRandomItem" then
		result = self:_giveRandomItem(player, Items.getRandom(debugRng))
	elseif actionId == "GiveRandomTech" then
		result = self:_giveRandomItem(player, Items.pickRandomInCategories(TECH_CATEGORIES, debugRng))
	elseif actionId == "GiveRandomCollectible" then
		result = self:_giveRandomItem(player, Items.pickRandomInCategories(COLLECTIBLE_CATEGORY, debugRng))
	elseif actionId == "FillInventory" then
		result = self:_fillInventory(player)
	elseif actionId == "ClearInventory" then
		result = self:_clearInventory(player)
	elseif actionId == "ClearDisplay" then
		result = self:_clearDisplay(player)
	elseif actionId == "GiveRandomDisplayItem" then
		result = self:_giveRandomDisplayItem(player, Items.getRandom(debugRng))
	elseif actionId == "ForceBuyerVisit" then
		result = DealService:debugForceBuyerVisit(player)
	elseif actionId == "ForceRareBuyerVisit" then
		result = DealService:debugForceRareBuyerVisit(player)
	elseif actionId == "SkipToClosingRush" then
		result = self:_skipToClosingRush(player)
	elseif actionId == "EndShift" then
		result = DealService:debugEndShift(player)
	elseif actionId == "ResetSaveData" then
		result = self:_resetSaveData(player)
	elseif actionId == "SetScraps" then
		result = self:_setScraps(player, payload)
	else
		return { ok = false, error = `Unknown action: {actionId}` }
	end

	self:logDebugAction(player, role, actionId, payload, result)
	return result
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
	while InventoryService:canAddToDisplay(player) do
		local itemDef = Items.getRandom(debugRng)
		if not itemDef then
			break
		end
		local instanceId, err = InventoryService:debugAddInventoryItem(player, itemDef)
		if not instanceId then
			if added == 0 then
				return { ok = false, error = err or "Shelf full" }
			end
			break
		end
		added += 1
	end

	if added == 0 then
		return { ok = false, error = "Shelf full" }
	end

	return { ok = true, message = `Filled shelf ({added} item(s) added)` }
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

function DebugService:_clearDisplay(player: Player)
	local cleared, clearError = InventoryService:debugClearDisplay(player)
	if clearError then
		return { ok = false, error = clearError }
	end

	DealService:debugRefreshBuyerVisitMatches(player)

	if cleared == 0 then
		return { ok = true, message = "Shelf already empty" }
	end

	return { ok = true, message = `Cleared {cleared} shelf item(s)` }
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
	return { ok = true, message = `Added {itemDef.displayName} to shelf` }
end

function DebugService:_resetSaveData(player: Player)
	local unsafe = rejectUnsafeDeal(player, "Finish or skip the active sale first")
	if unsafe then
		return unsafe
	end

	local cleared, clearError = InventoryService:debugClearPersistentShopState(player)
	if clearError then
		return { ok = false, error = clearError }
	end

	local ok, resetError = DataService:debugResetPlayerData(player)
	if not ok then
		return { ok = false, error = resetError or "Could not reset save data" }
	end

	DealService:debugRefreshBuyerVisitMatches(player)
	return { ok = true, message = `Reset save data. Cleared {cleared} permanent item(s).` }
end

function DebugService:_setScraps(player: Player, payload: any)
	local _, amount, err = DebugAccess.validateSetScrapsArgs(player, payload)
	if not amount then
		return { ok = false, error = err or "Invalid amount" }
	end

	local ok, setError = DataService:debugSetScraps(player, amount)
	if not ok then
		return { ok = false, error = setError or "Could not set scraps" }
	end

	return { ok = true, message = `Set scraps to {amount}` }
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
		return { ok = true, message = "Shift ended (no shelf stock for Closing Rush)" }
	end

	return { ok = true, message = "Skipped to Closing Rush" }
end

function DebugService:Init()
	Remotes.setup()

	local runActionRemote = Remotes.get("DebugRunAction") :: RemoteFunction
	runActionRemote.OnServerInvoke = function(player, actionId, payload)
		return self:runAction(player, actionId, payload)
	end

	local getAccessRemote = Remotes.get("DebugGetAccess") :: RemoteFunction
	getAccessRemote.OnServerInvoke = function(player)
		return self:getAccess(player)
	end
end

function DebugService:Start() end

return DebugService
