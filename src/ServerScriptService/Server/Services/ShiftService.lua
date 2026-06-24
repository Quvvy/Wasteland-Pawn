local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RareWalkIns = require(Shared.Config.RareWalkIns)
local ShopDayVariables = require(Shared.Config.ShopDayVariables)
local Shifts = require(Shared.Config.Shifts)
local TrafficCalendar = require(Shared.Config.TrafficCalendar)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local ShiftService = {}

local playerShifts: { [Player]: any } = {}
local playerScavengeWindow: { [Player]: number } = {}
local playerTraffic: { [Player]: { boardIndex: number, completedWindows: number } } = {}
local playerOnboarding: { [Player]: any } = {}
local playerShopDayForecasts: { [Player]: any } = {}
local PHASE_BUYING = "Buying"
local PHASE_CLOSING_RUSH = "ClosingRush"
local PHASE_ENDED = "Ended"

local ONBOARDING_RECOMMENDED_SHIFT_ID = "scrap_rush"
local ONBOARDING_HINTS = {
	open_board = "Welcome to the shop. Buy junk from sellers, put it on your Shelf, then open the shop for buyers.",
	start_scrap_rush = "Recommended shop day: Scrap Rush. Normal buyers, normal junk, fewer surprises.",
	first_seller = "Inspect before you buy. Clues tell you if the junk is worth the risk.",
	after_buy = "It goes on your Shelf. Buyers offer on Shelf items when the shop is open.",
	buyer_visit = "Good match. This buyer wants this kind of junk.",
	offer_item = "The right buyer pays more. Match labels show interest.",
	first_sale = "Nice sale. Some items are worth keeping in Storage for better traffic.",
	forward = "Shelf items attract buyers. Storage saves up to 2 items for later.",
}

local function bumpScavengeWindow(player: Player)
	playerScavengeWindow[player] = (playerScavengeWindow[player] or 0) + 1
end

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
		return "Shop Day Crushed"
	elseif grade == "Success" then
		return "Shop Day Complete"
	elseif grade == "Close" then
		return "Close Shop Run"
	end
	return "Shop Day Failed"
end

local function copyShiftOption(shift, trafficEntry)
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
		trafficLabel = trafficEntry and trafficEntry.label or nil,
		trafficDescription = trafficEntry and trafficEntry.description or nil,
		windowIndex = trafficEntry and trafficEntry.windowIndex or nil,
	}
end

local function newOnboardingState()
	return {
		active = true,
		stepId = "open_board",
		hint = ONBOARDING_HINTS.open_board,
		recommendedShiftId = ONBOARDING_RECOMMENDED_SHIFT_ID,
		firstShiftCompleted = false,
		boardOpened = false,
		recommendedShiftStarted = false,
		firstSellerShown = false,
		itemInspected = false,
		firstItemBought = false,
		buyerVisitStarted = false,
		itemOffered = false,
		firstSaleCompleted = false,
		buyerSkipped = false,
		pendingBuyerId = nil,
		buyerQueued = false,
	}
end

local function hasMeaningfulProgress(shift): boolean
	if not shift then
		return false
	end
	if (shift.sellerVisitsResolved or shift.dealsCompleted or 0) > 0 then
		return true
	end
	if (shift.closingRushBuyersSeen or 0) > 0 then
		return true
	end
	if (shift.shiftProfit or 0) ~= 0 then
		return true
	end
	if (shift.lastLiquidationItemCount or 0) > 0 then
		return true
	end

	local summary = shift.liquidationSummary
	return summary ~= nil and (summary.itemCount or 0) > 0
end

function ShiftService:Init()
	Remotes.setup()

	Players.PlayerAdded:Connect(function(player)
		task.delay(1.5, function()
			if player.Parent then
				self:_pushState(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerShifts[player] = nil
		playerScavengeWindow[player] = nil
		playerTraffic[player] = nil
		playerOnboarding[player] = nil
		playerShopDayForecasts[player] = nil
	end)
end

function ShiftService:Start()
	local startShift = Remotes.get("StartShift") :: RemoteFunction
	startShift.OnServerInvoke = function(player, shiftId)
		return self:startShift(player, shiftId)
	end

	local getShiftOptions = Remotes.get("GetShiftOptions") :: RemoteFunction
	getShiftOptions.OnServerInvoke = function(player)
		self:recordOnboardingEvent(player, "board_opened")
		return {
			ok = true,
			options = self:getShiftOptions(player),
			traffic = self:getTrafficSnapshot(player),
			onboarding = self:getOnboardingSnapshot(player),
		}
	end
end

function ShiftService:_getOnboardingState(player: Player)
	local state = playerOnboarding[player]
	if not state then
		state = newOnboardingState()
		playerOnboarding[player] = state
	end
	return state
end

function ShiftService:getOnboardingSnapshot(player: Player)
	local state = self:_getOnboardingState(player)
	return {
		active = state.active == true,
		stepId = state.stepId,
		hint = state.hint,
		recommendedShiftId = state.recommendedShiftId,
		firstShiftCompleted = state.firstShiftCompleted == true,
		boardOpened = state.boardOpened == true,
		recommendedShiftStarted = state.recommendedShiftStarted == true,
		firstSellerShown = state.firstSellerShown == true,
		itemInspected = state.itemInspected == true,
		firstItemBought = state.firstItemBought == true,
		buyerVisitStarted = state.buyerVisitStarted == true,
		itemOffered = state.itemOffered == true,
		firstSaleCompleted = state.firstSaleCompleted == true,
		buyerSkipped = state.buyerSkipped == true,
		pendingBuyerId = state.pendingBuyerId,
	}
end

function ShiftService:_setOnboardingStep(state, stepId: string)
	state.stepId = stepId
	state.hint = ONBOARDING_HINTS[stepId] or state.hint
end

function ShiftService:recordOnboardingEvent(player: Player, eventName: string)
	local state = self:_getOnboardingState(player)
	if state.firstShiftCompleted == true then
		state.active = false
		return self:getOnboardingSnapshot(player)
	end

	if eventName == "board_opened" then
		state.boardOpened = true
		self:_setOnboardingStep(state, "start_scrap_rush")
	elseif eventName == "recommended_shift_started" then
		state.recommendedShiftStarted = true
		self:_setOnboardingStep(state, "first_seller")
	elseif eventName == "first_seller_shown" then
		state.firstSellerShown = true
		self:_setOnboardingStep(state, "first_seller")
	elseif eventName == "item_inspected" then
		state.itemInspected = true
		self:_setOnboardingStep(state, "first_seller")
	elseif eventName == "first_item_bought" then
		state.firstItemBought = true
		self:_setOnboardingStep(state, "after_buy")
	elseif eventName == "buyer_visit_started" then
		state.buyerVisitStarted = true
		self:_setOnboardingStep(state, "buyer_visit")
	elseif eventName == "item_offered" then
		state.itemOffered = true
		self:_setOnboardingStep(state, "offer_item")
	elseif eventName == "first_sale_completed" then
		state.firstSaleCompleted = true
		self:_setOnboardingStep(state, "first_sale")
	elseif eventName == "buyer_skipped" then
		state.buyerSkipped = true
		self:_setOnboardingStep(state, "forward")
	elseif eventName == "first_shift_ended" then
		state.firstShiftCompleted = true
		state.active = false
		state.pendingBuyerId = nil
		self:_setOnboardingStep(state, "forward")
	end

	self:_pushState(player)
	return self:getOnboardingSnapshot(player)
end

function ShiftService:shouldUseFirstOnboardingSeller(player: Player): boolean
	local state = self:_getOnboardingState(player)
	local shift = playerShifts[player]
	return state.active == true
		and state.recommendedShiftStarted == true
		and state.firstSellerShown ~= true
		and shift ~= nil
		and shift.active == true
		and shift.shiftId == ONBOARDING_RECOMMENDED_SHIFT_ID
end

function ShiftService:queueOnboardingBuyer(player: Player, buyerId: string?): boolean
	local state = self:_getOnboardingState(player)
	if state.active ~= true or state.firstItemBought == true or state.buyerQueued == true then
		return false
	end
	if type(buyerId) ~= "string" or buyerId == "" then
		return false
	end

	state.firstItemBought = true
	state.buyerQueued = true
	state.pendingBuyerId = buyerId
	self:_setOnboardingStep(state, "after_buy")
	self:_pushState(player)
	return true
end

function ShiftService:getPendingOnboardingBuyerId(player: Player): string?
	local state = self:_getOnboardingState(player)
	if state.active ~= true or state.buyerQueued ~= true then
		return nil
	end
	return state.pendingBuyerId
end

function ShiftService:clearPendingOnboardingBuyer(player: Player)
	local state = self:_getOnboardingState(player)
	state.pendingBuyerId = nil
	state.buyerQueued = false
end

function ShiftService:_getTrafficState(player: Player)
	local state = playerTraffic[player]
	if not state then
		state = {
			boardIndex = 1,
			completedWindows = 0,
		}
		playerTraffic[player] = state
	end
	return state
end

function ShiftService:getTrafficSnapshot(player: Player)
	local state = self:_getTrafficState(player)
	local snapshot = TrafficCalendar.buildSnapshot(state.boardIndex, state.completedWindows)
	local availableWindows = {}
	for _, trafficEntry in TrafficCalendar.getBoardShiftEntries(state.boardIndex) do
		local shift = Shifts.get(trafficEntry.shiftId)
		table.insert(availableWindows, {
			shiftId = trafficEntry.shiftId,
			displayName = shift and shift.displayName or trafficEntry.shiftId,
			trafficLabel = trafficEntry.label,
			trafficDescription = trafficEntry.description,
			windowIndex = trafficEntry.windowIndex,
		})
	end
	snapshot.availableWindows = availableWindows
	return snapshot
end

function ShiftService:_advanceTrafficBoard(player: Player)
	local state = self:_getTrafficState(player)
	state.boardIndex = TrafficCalendar.nextBoardIndex(state.boardIndex)
	state.completedWindows += 1
	playerShopDayForecasts[player] = nil
end

function ShiftService:_buildShopDayForecastCache(player: Player)
	local trafficState = self:_getTrafficState(player)
	local displayItems = InventoryService:getDisplayItems(player)
	local displayFingerprint = ShopDayVariables.displayFingerprint(displayItems)
	local cache = {
		boardIndex = trafficState.boardIndex,
		displayFingerprint = displayFingerprint,
		forecasts = {},
	}
	local rng = Random.new()

	for _, trafficEntry in TrafficCalendar.getBoardShiftEntries(trafficState.boardIndex) do
		local shift = Shifts.get(trafficEntry.shiftId)
		if shift then
			cache.forecasts[shift.id] = ShopDayVariables.build(shift, trafficEntry, displayItems, rng)
		end
	end

	playerShopDayForecasts[player] = cache
	return cache
end

function ShiftService:_getShopDayForecastCache(player: Player)
	local trafficState = self:_getTrafficState(player)
	local displayFingerprint = ShopDayVariables.displayFingerprint(InventoryService:getDisplayItems(player))
	local cache = playerShopDayForecasts[player]
	if cache and cache.boardIndex == trafficState.boardIndex and cache.displayFingerprint == displayFingerprint then
		return cache
	end
	return self:_buildShopDayForecastCache(player)
end

function ShiftService:_getShopDayForecast(player: Player, shiftId: string)
	local cache = self:_getShopDayForecastCache(player)
	return cache and cache.forecasts and cache.forecasts[shiftId] or nil
end

function ShiftService:getShiftOptions(player: Player)
	local trafficState = self:_getTrafficState(player)
	local forecastCache = self:_getShopDayForecastCache(player)
	local options = {}
	local onboarding = self:_getOnboardingState(player)
	for _, trafficEntry in TrafficCalendar.getBoardShiftEntries(trafficState.boardIndex) do
		local shift = Shifts.get(trafficEntry.shiftId)
		if shift then
			local option = copyShiftOption(shift, trafficEntry)
			option.shopDayForecast = ShopDayVariables.toSnapshot(forecastCache.forecasts[shift.id])
			if onboarding.active == true and option.id == onboarding.recommendedShiftId then
				option.recommended = true
				option.recommendedText = "Recommended shop day"
			end
			table.insert(options, option)
		end
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

	local requestedShiftId = shiftId or TrafficCalendar.DEFAULT_SHIFT_ID
	local shift = Shifts.get(requestedShiftId)
	if not shift then
		return { ok = false, error = "Unknown shift" }
	end
	if not TrafficCalendar.isShiftAvailable(self:_getTrafficState(player).boardIndex, shift.id) then
		return {
			ok = false,
			error = "Traffic window not available",
			traffic = self:getTrafficSnapshot(player),
		}
	end

	local inventorySlots = shift.inventorySlots or 3
	local buyerVisitEvery = shift.buyerVisitEvery or 2
	local sellerVisitCount = shift.sellerVisitCount or shift.dealCount
	local closingRushBuyerLimit = shift.closingRushBuyerLimit or (inventorySlots + 1)
	local shopDayForecast = self:_getShopDayForecast(player, shift.id)
	local adjustedBuyerWeights = ShopDayVariables.applyBuyerWeights(shift.buyerWeights, shopDayForecast)
	local adjustedDealArchetypeWeights = ShopDayVariables.applyDealArchetypeWeights(shift.dealArchetypeWeights, shopDayForecast)
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
		pendingBuyerVisitKind = nil,
		pendingRareBuyerId = nil,
		rareBuyerVisitsSeen = 0,
		rareBuyerMax = RareWalkIns.getMaxPerShift(shift),
		dealArchetypeWeights = adjustedDealArchetypeWeights,
		buyerWeights = adjustedBuyerWeights,
		closingRushBuyerLimit = closingRushBuyerLimit,
		closingRushBuyersRemaining = closingRushBuyerLimit,
		closingRushBuyersSeen = 0,
		liquidationSummary = nil,
		description = shift.description,
		modifierText = shift.modifierText,
		lastDealProfit = nil,
		trafficAdvanced = false,
		trafficAdvanceSkipped = false,
		lastLiquidationItemCount = 0,
		shopDay = ShopDayVariables.toSnapshot(shopDayForecast),
	}

	if shift.id == ONBOARDING_RECOMMENDED_SHIFT_ID then
		self:recordOnboardingEvent(player, "recommended_shift_started")
	end

	bumpScavengeWindow(player)

	local snapshot = self:buildSnapshot(player)
	self:_pushState(player)
	return { ok = true, snapshot = snapshot }
end

function ShiftService:getShift(player: Player)
	return playerShifts[player]
end

function ShiftService:getScavengeWindowToken(player: Player): number
	return playerScavengeWindow[player] or 0
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
	if InventoryService:getDisplayCount(player) <= 0 then
		return false
	end
	if not self:canRollClosingRushBuyer(player) then
		return false
	end
	shift.pendingBuyerVisit = true
	shift.pendingBuyerVisitKind = "scheduled"
	shift.pendingRareBuyerId = nil
	return true
end

function ShiftService:enterClosingRush(player: Player)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended then
		return nil
	end

	if InventoryService:getDisplayCount(player) <= 0 then
		return self:endShift(player)
	end

	shift.phase = PHASE_CLOSING_RUSH
	shift.pendingBuyerVisit = true
	shift.pendingBuyerVisitKind = "scheduled"
	shift.pendingRareBuyerId = nil
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
		shift.pendingBuyerVisitKind = "scheduled"
		shift.pendingRareBuyerId = nil
	end

	if shift.sellerVisitsResolved >= shift.sellerVisitCount then
		if InventoryService:getDisplayCount(player) > 0 then
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

function ShiftService:recordDisplayInfluenceHelped(player: Player)
	local shift = playerShifts[player]
	if not shift or shift.ended or type(shift.shopDay) ~= "table" then
		return nil
	end

	shift.shopDay.displayHelped = true
	return self:buildSnapshot(player)
end

function ShiftService:shouldTriggerBuyerVisit(player: Player): boolean
	local shift = playerShifts[player]
	return shift ~= nil and shift.active and not shift.ended and shift.pendingBuyerVisit == true
end

function ShiftService:canQueueRareBuyerVisit(player: Player): boolean
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended or shift.phase ~= PHASE_BUYING then
		return false
	end
	if shift.pendingBuyerVisit then
		return false
	end
	if InventoryService:getDisplayCount(player) <= 0 then
		return false
	end
	return (shift.rareBuyerVisitsSeen or 0) < (shift.rareBuyerMax or RareWalkIns.MAX_PER_SHIFT)
end

function ShiftService:queueRareBuyerVisit(player: Player, buyerId: string): boolean
	if type(buyerId) ~= "string" or buyerId == "" then
		return false
	end
	if not self:canQueueRareBuyerVisit(player) then
		return false
	end

	local shift = playerShifts[player]
	shift.pendingBuyerVisit = true
	shift.pendingBuyerVisitKind = "rare"
	shift.pendingRareBuyerId = buyerId
	shift.rareBuyerVisitsSeen = (shift.rareBuyerVisitsSeen or 0) + 1
	self:_pushState(player)
	return true
end

function ShiftService:beginBuyerVisit(player: Player)
	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended or not shift.pendingBuyerVisit then
		return nil
	end

	if shift.phase == PHASE_CLOSING_RUSH then
		if InventoryService:getDisplayCount(player) <= 0 then
			return self:endShift(player)
		end
		if not self:canRollClosingRushBuyer(player) then
			self:liquidateRemainingInventory(player, "Closing Rush buyers ran out")
			return self:endShift(player)
		end
		shift.closingRushBuyersRemaining -= 1
		shift.closingRushBuyersSeen = (shift.closingRushBuyersSeen or 0) + 1
	end
	if not shift.pendingBuyerVisitKind then
		shift.pendingBuyerVisitKind = "scheduled"
	end

	self:_pushState(player)
	return self:buildSnapshot(player)
end

function ShiftService:completeBuyerVisit(player: Player)
	local shift = playerShifts[player]
	if not shift or shift.ended then
		return nil
	end

	self:clearPendingOnboardingBuyer(player)
	shift.pendingBuyerVisit = false
	shift.pendingBuyerVisitKind = nil
	shift.pendingRareBuyerId = nil
	if shift.phase == PHASE_BUYING then
		if shift.sellerVisitsResolved >= shift.sellerVisitCount then
			if InventoryService:getDisplayCount(player) > 0 then
				return self:enterClosingRush(player)
			end
			return self:endShift(player)
		end
	elseif shift.phase == PHASE_CLOSING_RUSH then
		if InventoryService:getDisplayCount(player) <= 0 then
			return self:endShift(player)
		end
		if self:canRollClosingRushBuyer(player) then
			shift.pendingBuyerVisit = true
			shift.pendingBuyerVisitKind = "scheduled"
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

	InventoryService:restorePermanentInventoryItems(player)

	local items = {}
	local totalCash = 0
	local totalProfit = 0

	for _, entry in InventoryService:getLiquidatableInventoryItems(player) do
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
	shift.lastLiquidationItemCount = #items
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
		return { ok = false, error = "No open shop day" }
	end
	if shift.phase ~= PHASE_CLOSING_RUSH then
		return { ok = false, error = "Can only close during Closing Rush" }
	end

	InventoryService:restorePermanentInventoryItems(player)

	if #InventoryService:getLiquidatableInventoryItems(player) > 0 then
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
	if shift.ended then
		return self:buildSnapshot(player)
	end

	InventoryService:restorePermanentInventoryItems(player)

	shift.active = false
	shift.ended = true
	shift.phase = PHASE_ENDED
	shift.pendingBuyerVisit = false
	shift.pendingBuyerVisitKind = nil
	shift.pendingRareBuyerId = nil
	shift.success = shift.shiftProfit >= shift.targetProfit
	shift.grade = getGrade(shift)
	shift.resultTitle = getResultTitle(shift)
	if not shift.trafficAdvanced then
		shift.meaningfulProgress = hasMeaningfulProgress(shift)
		if shift.meaningfulProgress then
			shift.trafficAdvanced = true
			shift.trafficAdvanceSkipped = false
			self:_advanceTrafficBoard(player)
		else
			shift.trafficAdvanceSkipped = true
		end
	end

	local onboarding = self:_getOnboardingState(player)
	if onboarding.firstShiftCompleted ~= true then
		onboarding.firstShiftCompleted = true
		onboarding.active = false
		onboarding.pendingBuyerId = nil
		onboarding.buyerQueued = false
		self:_setOnboardingStep(onboarding, "forward")
	end

	InventoryService:pushSnapshot(player)
	self:_pushState(player)
	DataService:savePlayer(player, "shift_end")
	bumpScavengeWindow(player)
	return self:buildSnapshot(player)
end

function ShiftService:buildSnapshot(player: Player)
	local shift = playerShifts[player]
	if not shift then
		return {
			active = false,
			ended = false,
			onboarding = self:getOnboardingSnapshot(player),
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
		pendingBuyerVisitKind = shift.pendingBuyerVisitKind,
		pendingRareBuyerId = shift.pendingRareBuyerId,
		rareBuyerVisitsSeen = shift.rareBuyerVisitsSeen or 0,
		rareBuyerMax = shift.rareBuyerMax or RareWalkIns.MAX_PER_SHIFT,
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
		meaningfulProgress = hasMeaningfulProgress(shift),
		trafficAdvanced = shift.trafficAdvanced == true,
		trafficAdvanceSkipped = shift.trafficAdvanceSkipped == true,
		shopDay = shift.shopDay,
		traffic = self:getTrafficSnapshot(player),
		onboarding = self:getOnboardingSnapshot(player),
	}
end

function ShiftService:_pushState(player: Player)
	local shiftStateUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftStateUpdate:FireClient(player, self:buildSnapshot(player))
end

function ShiftService:debugSetPendingBuyerVisit(player: Player): boolean
	local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
	if not DebugAccess.canRunDebugAction(player, "ForceBuyerVisit") then
		return false
	end

	local shift = playerShifts[player]
	if not shift or not shift.active or shift.ended then
		return false
	end

	shift.pendingBuyerVisit = true
	shift.pendingBuyerVisitKind = "scheduled"
	shift.pendingRareBuyerId = nil
	self:_pushState(player)
	return true
end

return ShiftService
