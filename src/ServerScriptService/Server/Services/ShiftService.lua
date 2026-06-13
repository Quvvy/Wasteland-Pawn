local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shifts = require(Shared.Config.Shifts)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)

local ShiftService = {}

local playerShifts: { [Player]: any } = {}

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
		targetProfit = shift.targetProfit,
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
	local shift = Shifts.get(shiftId or "scrap_rush")
	if not shift then
		return { ok = false, error = "Unknown shift" }
	end

	playerShifts[player] = {
		active = true,
		shiftId = shift.id,
		displayName = shift.displayName,
		dealCount = shift.dealCount,
		dealsCompleted = 0,
		targetProfit = shift.targetProfit,
		shiftProfit = 0,
		startingCash = DataService:getCash(player),
		ended = false,
		success = false,
		grade = "Bust",
		resultTitle = nil,
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

function ShiftService:recordDealResult(player: Player, dealSummary)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended then
		return nil
	end

	local profit = 0
	if dealSummary then
		profit = dealSummary.totalProfit or dealSummary.profit or 0
	end

	shift.dealsCompleted = math.min(shift.dealsCompleted + 1, shift.dealCount)
	shift.shiftProfit += profit
	shift.lastDealProfit = profit

	if shift.dealsCompleted >= shift.dealCount then
		return self:endShift(player)
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:shouldContinueShift(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil and shift.active and not shift.ended and shift.dealsCompleted < shift.dealCount
end

function ShiftService:endShift(player: Player)
	local shift = playerShifts[player]
	if not shift then
		return nil
	end

	shift.active = false
	shift.ended = true
	shift.success = shift.shiftProfit >= shift.targetProfit
	shift.grade = getGrade(shift)
	shift.resultTitle = getResultTitle(shift)

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
		shiftId = shift.shiftId,
		displayName = shift.displayName,
		dealCount = shift.dealCount,
		dealsCompleted = shift.dealsCompleted,
		dealsRemaining = math.max(shift.dealCount - shift.dealsCompleted, 0),
		targetProfit = shift.targetProfit,
		shiftProfit = shift.shiftProfit,
		startingCash = shift.startingCash,
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

return ShiftService
