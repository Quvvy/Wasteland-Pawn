local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shifts = require(Shared.Config.Shifts)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local ShiftService = {}

local playerShifts: { [Player]: any } = {}
local PHASE_BUYING = "Buying"
local PHASE_CLOSING_RUSH = "ClosingRush"
local PHASE_ENDED = "Ended"

local function getGrade(shift): string
	local target = math.max(shift.targetProfit or 0, 1)
	local ratio = (shift.shiftProfit or 0) / target
	if ratio >= 1.5 then
		return "Big Win"
	elseif ratio >= 1 then
		return "Success"
	elseif ratio >= 0.7 then
		return "Close"
	end
	return "Bust"
end

local function getResultTitle(shift): string
	local grade = getGrade(shift)
	if grade == "Big Win" then
		return "Shift Crushed"
	elseif grade == "Success" then
		return "Shift Complete"
	elseif grade == "Close" then
		return "Close Run"
	end
	return "Shift Failed"
end

local function copyShiftOption(shift)
	return {
		id = shift.id,
		displayName = shift.displayName,
		dealCount = shift.dealCount,
		sellerVisitCount = shift.sellerVisitCount or shift.dealCount,
		targetProfit = shift.targetProfit,
		inventorySlots = shift.inventorySlots,
		buyerVisitEvery = shift.buyerVisitEvery,
		closingRushBuyerLimit = shift.closingRushBuyerLimit,
		description = shift.description,
		modifierText = shift.modifierText,
	}
end

function ShiftService:Init()
	Remotes.setup()

	Players.PlayerRemoving:Connect(function(player)
		playerShifts[player] = nil
	end)
end

function ShiftService:Start()
	local startShift = Remotes.get("StartShift") :: RemoteFunction
	startShift.OnServerInvoke = function(player, shiftId)
		return self:startShift(player, shiftId)
	end

	local getShiftOptions = Remotes.get("GetShiftOptions") :: RemoteFunction
	getShiftOptions.OnServerInvoke = function()
		return {
			ok = true,
			options = self:getShiftOptions(),
		}
	end
end

function ShiftService:getShiftOptions()
	local options = {}
	for _, shift in Shifts.getAll() do
		table.insert(options, copyShiftOption(shift))
	end
	return options
end

function ShiftService:startShift(player: Player, shiftId: string?)
	local activeShift = playerShifts[player]
	if activeShift and activeShift.active and not activeShift.ended then
		return {
			ok = false,
			error = "Shift already active",
			snapshot = self:buildSnapshot(player),
		}
	end

	local shift = Shifts.get(shiftId or "scrap_rush")
	if not shift then
		return { ok = false, error = "Unknown shift" }
	end

	local inventorySlots = shift.inventorySlots or 3
	local buyerVisitEvery = shift.buyerVisitEvery or 2
	local sellerVisitCount = shift.sellerVisitCount or shift.dealCount
	local closingRushBuyerLimit = shift.closingRushBuyerLimit or (inventorySlots + 1)
	InventoryService:startShiftInventory(player, inventorySlots)

	playerShifts[player] = {
		active = true,
		phase = PHASE_BUYING,
		shiftId = shift.id,
		displayName = shift.displayName,
		dealCount = sellerVisitCount,
		sellerVisitCount = sellerVisitCount,
		dealsCompleted = 0,
		sellerVisitsResolved = 0,
		targetProfit = shift.targetProfit,
		shiftProfit = 0,
		startingCash = DataService:getCash(player),
		ended = false,
		success = false,
		grade = "Bust",
		resultTitle = nil,
		inventoryMaxSlots = inventorySlots,
		buyerVisitEvery = buyerVisitEvery,
		pendingBuyerVisit = false,
		dealArchetypeWeights = shift.dealArchetypeWeights,
		buyerWeights = shift.buyerWeights,
		closingRushBuyerLimit = closingRushBuyerLimit,
		closingRushBuyersRemaining = closingRushBuyerLimit,
		closingRushBuyersSeen = 0,
		liquidationSummary = nil,
		description = shift.description,
		modifierText = shift.modifierText,
		lastDealProfit = nil,
	}

	local snapshot = self:buildSnapshot(player)
	self:_pushState(player)
	return { ok = true, snapshot = snapshot }
end

function ShiftService:getShift(player: Player)
	return playerShifts[player]
end

function ShiftService:isBuying(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil and shift.active and not shift.ended and shift.phase == PHASE_BUYING
end

function ShiftService:isClosingRush(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil and shift.active and not shift.ended and shift.phase == PHASE_CLOSING_RUSH
end

function ShiftService:canRollClosingRushBuyer(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil
		and shift.active
		and not shift.ended
		and shift.phase == PHASE_CLOSING_RUSH
		and (shift.closingRushBuyersRemaining or 0) > 0
end

function ShiftService:queueClosingRushBuyer(player: Player): boolean
	local shift = playerShifts[player]
	if not shift or shift.ended or shift.phase ~= PHASE_CLOSING_RUSH then
		return false
	end
	if InventoryService:getCount(player) <= 0 then
		return false
	end
	if not self:canRollClosingRushBuyer(player) then
		return false
	end
	shift.pendingBuyerVisit = true
	return true
end

function ShiftService:enterClosingRush(player: Player)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended then
		return nil
	end

	if InventoryService:getCount(player) <= 0 then
		return self:endShift(player)
	end

	shift.phase = PHASE_CLOSING_RUSH
	shift.pendingBuyerVisit = true
	if (shift.closingRushBuyersRemaining or 0) <= 0 then
		self:liquidateRemainingInventory(player, "No Closing Rush buyers left")
		return self:endShift(player)
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:recordSellerVisitResolved(player: Player, forceBuyerVisit: boolean?)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended or shift.phase ~= PHASE_BUYING then
		return nil
	end

	shift.sellerVisitsResolved = math.min((shift.sellerVisitsResolved or shift.dealsCompleted or 0) + 1, shift.sellerVisitCount)
	shift.dealsCompleted = shift.sellerVisitsResolved

	if forceBuyerVisit or (shift.buyerVisitEvery > 0 and shift.sellerVisitsResolved % shift.buyerVisitEvery == 0) then
		shift.pendingBuyerVisit = true
	end

	if shift.sellerVisitsResolved >= shift.sellerVisitCount then
		if InventoryService:getCount(player) > 0 then
			return self:enterClosingRush(player)
		end
		return self:endShift(player)
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:recordDealResult(player: Player, dealSummary)
	local shift = playerShifts[player]
	if not shift or shift.ended then
		return nil
	end

	local profit = 0
	if dealSummary then
		profit = dealSummary.totalProfit or dealSummary.profit or 0
	end

	shift.shiftProfit += profit
	shift.lastDealProfit = profit

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:shouldTriggerBuyerVisit(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil and shift.active and not shift.ended and shift.pendingBuyerVisit == true
end

function ShiftService:beginBuyerVisit(player: Player)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended or not shift.pendingBuyerVisit then
		return nil
	end

	if shift.phase == PHASE_CLOSING_RUSH then
		if InventoryService:getCount(player) <= 0 then
			return self:endShift(player)
		end
		if not self:canRollClosingRushBuyer(player) then
			self:liquidateRemainingInventory(player, "Closing Rush buyers ran out")
			return self:endShift(player)
		end
		shift.closingRushBuyersRemaining -= 1
		shift.closingRushBuyersSeen = (shift.closingRushBuyersSeen or 0) + 1
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:completeBuyerVisit(player: Player)
	local shift = playerShifts[player]
	if not shift or shift.ended then
		return nil
	end

	shift.pendingBuyerVisit = false
	if shift.phase == PHASE_BUYING then
		if shift.sellerVisitsResolved >= shift.sellerVisitCount then
			if InventoryService:getCount(player) > 0 then
				return self:enterClosingRush(player)
			end
			return self:endShift(player)
		end
	elseif shift.phase == PHASE_CLOSING_RUSH then
		if InventoryService:getCount(player) <= 0 then
			return self:endShift(player)
		end
		if self:canRollClosingRushBuyer(player) then
			shift.pendingBuyerVisit = true
		else
			self:liquidateRemainingInventory(player, "Closing Rush buyers ran out")
			return self:endShift(player)
		end
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:shouldContinueShift(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil
		and shift.active
		and not shift.ended
		and shift.phase == PHASE_BUYING
		and not shift.pendingBuyerVisit
		and (shift.sellerVisitsResolved or shift.dealsCompleted or 0) < shift.sellerVisitCount
end

function ShiftService:liquidateRemainingInventory(player: Player, reason: string?)
	local shift = playerShifts[player]
	if not shift or shift.ended then
		return nil
	end

	local items = {}
	local totalCash = 0
	local totalProfit = 0

	for _, entry in InventoryService:getInventoryItems(player) do
		local trueValue = entry.trueValue or 0
		local liquidationValue = math.max(0, math.floor(trueValue * Shifts.LiquidationRate + 0.5))
		local profit = liquidationValue - (entry.purchasePrice or 0)
		totalCash += liquidationValue
		totalProfit += profit
		table.insert(items, {
			instanceId = entry.instanceId,
			itemName = entry.displayName,
			trueValue = trueValue,
			purchasePrice = entry.purchasePrice or 0,
			liquidationValue = liquidationValue,
			profit = profit,
		})
	end

	if totalCash > 0 then
		DataService:addCash(player, totalCash)
	end
	for _, item in items do
		InventoryService:markDisposed(player, item.instanceId)
	end

	shift.shiftProfit += totalProfit
	shift.lastDealProfit = totalProfit
	shift.liquidationSummary = {
		reason = reason or "Liquidated after close",
		rate = Shifts.LiquidationRate,
		itemCount = #items,
		items = items,
		totalCash = totalCash,
		totalProfit = totalProfit,
	}

	self:_pushState(player)
	return shift.liquidationSummary
end

function ShiftService:closeShift(player: Player, reason: string?)
	local shift = playerShifts[player]
	if not shift or shift.ended then
		return { ok = false, error = "No active shift" }
	end
	if shift.phase ~= PHASE_CLOSING_RUSH then
		return { ok = false, error = "Can only close during Closing Rush" }
	end

	if InventoryService:getCount(player) > 0 then
		self:liquidateRemainingInventory(player, reason or "Liquidated after close")
	end

	local snapshot = self:endShift(player)
	return {
		ok = true,
		snapshot = snapshot,
		liquidationSummary = shift.liquidationSummary,
	}
end

function ShiftService:endShift(player: Player)
	local shift = playerShifts[player]
	if not shift then
		return nil
	end

	shift.active = false
	shift.ended = true
	shift.phase = PHASE_ENDED
	shift.pendingBuyerVisit = false
	shift.success = shift.shiftProfit >= shift.targetProfit
	shift.grade = getGrade(shift)
	shift.resultTitle = getResultTitle(shift)

	InventoryService:pushSnapshot(player)
	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:buildSnapshot(player: Player)
	local shift = playerShifts[player]
	if not shift then
		return {
			active = false,
			ended = false,
		}
	end

	return {
		active = shift.active,
		phase = shift.phase,
		shiftId = shift.shiftId,
		displayName = shift.displayName,
		dealCount = shift.sellerVisitCount or shift.dealCount,
		sellerVisitCount = shift.sellerVisitCount or shift.dealCount,
		dealsCompleted = shift.sellerVisitsResolved or shift.dealsCompleted,
		sellerVisitsResolved = shift.sellerVisitsResolved or shift.dealsCompleted,
		dealsRemaining = math.max((shift.sellerVisitCount or shift.dealCount) - (shift.sellerVisitsResolved or shift.dealsCompleted), 0),
		targetProfit = shift.targetProfit,
		shiftProfit = shift.shiftProfit,
		startingCash = shift.startingCash,
		inventoryMaxSlots = shift.inventoryMaxSlots,
		buyerVisitEvery = shift.buyerVisitEvery,
		pendingBuyerVisit = shift.pendingBuyerVisit,
		closingRushBuyerLimit = shift.closingRushBuyerLimit,
		closingRushBuyersRemaining = shift.closingRushBuyersRemaining,
		closingRushBuyersSeen = shift.closingRushBuyersSeen,
		liquidationSummary = shift.liquidationSummary,
		ended = shift.ended,
		success = shift.success,
		grade = shift.grade or getGrade(shift),
		resultTitle = shift.resultTitle or getResultTitle(shift),
		description = shift.description,
		modifierText = shift.modifierText,
		lastDealProfit = shift.lastDealProfit,
	}
end

function ShiftService:_pushState(player: Player)
	local shiftStateUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftStateUpdate:FireClient(player, self:buildSnapshot(player))
end

function ShiftService:debugSetPendingBuyerVisit(player: Player): boolean
	if not game:GetService("RunService"):IsStudio() then
		return false
	end

	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended then
		return false
	end

	shift.pendingBuyerVisit = true
	self:_pushState(player)
	return true
end

return ShiftService
