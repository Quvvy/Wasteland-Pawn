local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)
local Shifts = require(Shared.Config.Shifts)
local DemandPreview = require(Shared.Economy.DemandPreview)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local dealRoot: Frame
local labels: { [string]: TextLabel } = {}
local buttons: { [string]: TextButton } = {}
local heatBarBg: Frame
local heatBarFill: Frame
local shiftSelectOverlay: Frame
local shiftSelectPanel: Frame?
local shiftSelectList: ScrollingFrame
local shiftSelectPreviewPane: Frame?
local shiftSelectPreviewLabel: TextLabel?
local stashOverlay: Frame
local stashList: ScrollingFrame?
local hubToast: TextLabel
local hubHoldingBanner: TextLabel
local shiftSelectStartCallback: ((string) -> ())?
local stashActionCallback: ((string, string) -> ())?

local currentSnapshot: any = nil
local currentShiftSnapshot: any = nil
local currentInventorySnapshot: any = nil
local tacticButtonsEnabled = true
local stashActionsEnabled = true

local TACTIC_RESULT_DISPLAY = {
	price_drop = "Price dropped",
	price_raise = "Offer raised",
	warning = "Warning",
	walkaway = "Walked away",
	crack = "Intel gained",
	big_win = "Big win!",
	accept = "Accepted",
	no_movement = "No movement",
}

local function currencyLabel(snapshot: any?): string
	return (snapshot and snapshot.currencyName) or HaggleTuning.currencyName or "scraps"
end

local function formatSignedAmount(amount: number?): string
	local value = amount or 0
	if value > 0 then
		return `+{value}`
	end
	return tostring(value)
end

local function statBand(value: number?): string
	local amount = value or 0
	if amount >= 67 then
		return "High"
	elseif amount >= 34 then
		return "Med"
	end
	return "Low"
end

local function formatTraits(traits): string
	return if traits and #traits > 0 then table.concat(traits, ", ") else "None"
end

local function formatInventorySummary(inventory): string
	if not inventory then
		return "Inventory: 0/3"
	end

	local usedSlots = inventory.usedSlots or 0
	local maxSlots = inventory.maxSlots or 3
	local lines = {
		`Inventory: {usedSlots}/{maxSlots}`,
	}
	for slotIndex = 1, maxSlots do
		local item = inventory.items and inventory.items[slotIndex]
		if item then
			local heldTag = if item.heldBack then " [Held Back]" else ""
			table.insert(lines, `{slotIndex}. {item.displayName} ({item.category}) - paid {item.purchasePrice}{heldTag}`)
		end
	end
	if usedSlots <= 0 then
		table.insert(lines, "Shelf: empty")
	elseif usedSlots < maxSlots then
		table.insert(lines, `Open slots: {maxSlots - usedSlots}`)
	end

	local displayMax = inventory.displayMaxSlots or 3
	local displayUsed = inventory.displayUsedSlots or 0
	local displayBySlot = InventorySnapshot.indexDisplayItemsBySlot(inventory.displayItems)
	table.insert(lines, `Display: {displayUsed}/{displayMax}`)
	for slotIndex = 1, displayMax do
		local item = displayBySlot[slotIndex]
		if item then
			table.insert(lines, `D{slotIndex}. {item.displayName} ({item.category})`)
		end
	end

	local appeal = inventory.displayAppealSummary
	if appeal and appeal ~= "" then
		table.insert(lines, `Display Appeal: {appeal}`)
	end

	local stashUsed = inventory.stashUsedSlots or 0
	local stashMax = inventory.stashMaxSlots or 6
	table.insert(lines, `Stash: {stashUsed}/{stashMax}`)

	return table.concat(lines, "\n")
end

local function liquidationRatePercent(rate: number?): number
	return math.floor(((rate or Shifts.LiquidationRate) * 100) + 0.5)
end

local function formatClosingRushShiftText(snapshot, cur: string, inventoryCount: number, inventoryMax: number): string
	return table.concat({
		`Shift: {snapshot.displayName or "?"} | Closing Rush | Buyers left: {snapshot.closingRushBuyersRemaining or 0}`,
		`Profit: {formatSignedAmount(snapshot.shiftProfit)} / {snapshot.targetProfit or 0} {cur} | Inventory: {inventoryCount}/{inventoryMax}`,
		`Unsold items liquidate at {liquidationRatePercent()}% value.`,
	}, "\n")
end

local function refreshInventoryLabel()
	labels.inventory.Text = formatInventorySummary(currentInventorySnapshot)
end

local function compactTerminalDialogue(phase: string, snapshot): string
	if not snapshot.dealSummary then
		return snapshot.dialogue or "..."
	end

	if phase == "Stored" then
		return "Stored."
	elseif phase == "WalkedAway" then
		return "They left."
	elseif phase == "Result" then
		return "Resolved."
	end

	return snapshot.dialogue or "..."
end

local function formatLiquidationSummary(summary, cur: string): string
	if not summary or (summary.itemCount or 0) <= 0 then
		return ""
	end

	local rate = liquidationRatePercent(summary.rate)
	return `\nLiquidated {summary.itemCount} item(s) at {rate}% value.\nLiquidation cash: {summary.totalCash or 0} {cur} | Profit: {formatSignedAmount(summary.totalProfit)} {cur}`
end

local function formatNextTrafficSummary(traffic): string
	if type(traffic) ~= "table" or type(traffic.boardName) ~= "string" or traffic.boardName == "" then
		return ""
	end

	local subtitle = if type(traffic.boardSubtitle) == "string" and traffic.boardSubtitle ~= "" then ` - {traffic.boardSubtitle}` else ""
	return `\nNext traffic: {traffic.boardName}{subtitle}`
end

local function createLabel(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

local function formatShiftOptionStats(option, cur: string): string
	local sellerCount = option.sellerVisitCount or option.dealCount or 0
	local buyerEvery = option.buyerVisitEvery or 2
	return `Target: {option.targetProfit or 0} {cur} | Sellers: {sellerCount} | Slots: {option.inventorySlots or 3} | Buyer every {buyerEvery}`
end

local function formatShiftCardModifier(option): string
	local modifier = option.modifierText or ""
	if type(option.trafficLabel) == "string" and option.trafficLabel ~= "" then
		return if modifier ~= "" then `{option.trafficLabel}: {modifier}` else option.trafficLabel
	end
	return modifier
end

local function formatTrafficBoardTitle(traffic): string
	if type(traffic) == "table" and type(traffic.boardName) == "string" and traffic.boardName ~= "" then
		return `Traffic Board: {traffic.boardName}`
	end
	return "Traffic Board"
end

local function collectTrafficWindowNames(rows): ({ string }, boolean)
	local names = {}
	local hasScrapRush = false
	for _, row in rows or {} do
		local name = row.displayName or row.trafficLabel or row.shiftId or row.id
		if type(name) == "string" and name ~= "" then
			table.insert(names, name)
		end
		local shiftId = row.shiftId or row.id
		if shiftId == "scrap_rush" then
			hasScrapRush = true
		end
	end
	return names, hasScrapRush
end

local function formatTrafficBoardText(traffic, options): string
	if type(traffic) ~= "table" then
		return "Session traffic windows. Tap ? for demand preview."
	end

	local boardSubtitle = traffic.boardSubtitle
	local lines = {}
	if type(boardSubtitle) == "string" and boardSubtitle ~= "" then
		table.insert(lines, boardSubtitle)
	end

	local availableNames, hasScrapRush = collectTrafficWindowNames(traffic.availableWindows)
	if #availableNames == 0 then
		availableNames, hasScrapRush = collectTrafficWindowNames(options)
	end
	if #availableNames > 0 then
		table.insert(lines, `Available: {table.concat(availableNames, ", ")}`)
	end
	if hasScrapRush then
		table.insert(lines, "Scrap Rush is reliable normal-day traffic.")
	end

	local upcomingNames = {}
	for _, board in traffic.upcomingBoards or {} do
		if type(board.boardName) == "string" and board.boardName ~= "" then
			table.insert(upcomingNames, board.boardName)
		end
	end

	if #upcomingNames > 0 then
		table.insert(lines, `Up next: {upcomingNames[1]}`)
	end
	return table.concat(lines, "\n")
end

local SHIFT_PREVIEW_HINT = "Tap ? on a shift to see likely demand."
local SHIFT_PREVIEW_MIN_HEIGHT = 28
local SHIFT_PREVIEW_MAX_HEIGHT = 150
local SHIFT_PREVIEW_LIST_MIN_HEIGHT = 140
local SHIFT_PREVIEW_PANEL_MIN_HEIGHT = 520
local SHIFT_PREVIEW_TEXT_WIDTH = 380
local SHIFT_PREVIEW_TEXT_SIZE = 11
local SHIFT_PREVIEW_FONT = Enum.Font.Gotham
local SHIFT_CARD_ACTION_RIGHT = 10
local SHIFT_CARD_START_HEIGHT = 26
local SHIFT_CARD_PREVIEW_HEIGHT = 22
local SHIFT_CARD_ACTION_GAP = 4
local SHIFT_SELECT_LIST_TOP = 104
local shiftPreviewExpanded = false
local selectedShiftPreviewId: string? = nil
local shiftPreviewButtons: { [string]: TextButton } = {}
local shiftPreviewCardStrokes: { [string]: UIStroke } = {}

local SHIFT_CARD_STROKE_COLOR = Color3.fromRGB(80, 75, 95)
local SHIFT_CARD_SELECTED_STROKE_COLOR = Color3.fromRGB(255, 220, 140)
local SHIFT_PREVIEW_BUTTON_COLOR = Color3.fromRGB(55, 70, 95)
local SHIFT_PREVIEW_BUTTON_SELECTED_COLOR = Color3.fromRGB(100, 120, 70)

local function joinNames(rows: { any }?, fieldName: string): string
	local names = {}
	for _, row in rows or {} do
		local name = row[fieldName]
		if type(name) == "string" and name ~= "" then
			table.insert(names, name)
		end
	end
	return if #names > 0 then table.concat(names, ", ") else "None"
end

local function formatDemandPreviewText(preview: any?): string
	if not preview then
		return SHIFT_PREVIEW_HINT
	end

	local lines = { preview.displayName or "Shift" }

	if preview.likelyBuyers and #preview.likelyBuyers > 0 then
		table.insert(lines, `Likely buyers: {joinNames(preview.likelyBuyers, "displayName")}`)
	end

	if preview.hasMixedDemand then
		table.insert(lines, "Good stock: mixed demand")
	else
		if preview.goodCategories and #preview.goodCategories > 0 then
			table.insert(lines, `Good categories: {table.concat(preview.goodCategories, ", ")}`)
		end
		if preview.goodTraits and #preview.goodTraits > 0 then
			table.insert(lines, `Good traits: {table.concat(preview.goodTraits, ", ")}`)
		end
	end

	if preview.hasDisplayItems and preview.displayAppealSummary and preview.displayAppealSummary ~= "" then
		table.insert(lines, `Your display: {preview.displayAppealSummary}`)
	else
		table.insert(lines, "Your display: empty")
	end

	if not preview.hasDisplayItems then
		table.insert(lines, "Display effect: none yet")
	elseif preview.displayEffects and #preview.displayEffects > 0 then
		table.insert(lines, `Display effect: {joinNames(preview.displayEffects, "displayName")} may be more likely`)
	else
		table.insert(lines, "Display effect: no strong match here")
	end

	return table.concat(lines, "\n")
end

local function appendStrings(target: { string }, values: any)
	if type(values) ~= "table" then
		return
	end

	for _, value in values do
		if type(value) == "string" and value ~= "" then
			table.insert(target, value)
		end
	end
end

local function formatDisplayInfluenceHelp(snapshot): string?
	if not snapshot or (snapshot.displayInfluenceBonus or 0) <= 0 then
		return nil
	end
	if snapshot.rareWalkInBuyer then
		return "Attracted by your display."
	end

	local matched = {}
	appendStrings(matched, snapshot.displayInfluenceMatchedCategories)
	appendStrings(matched, snapshot.displayInfluenceMatchedTraits)

	if #matched > 0 then
		return `Display helped: {table.concat(matched, " / ")}`
	end

	return snapshot.displayInfluenceLabel or "Display helped attract this buyer."
end

local function measurePreviewTextHeight(text: string): number
	local bounds = TextService:GetTextSize(
		text,
		SHIFT_PREVIEW_TEXT_SIZE,
		SHIFT_PREVIEW_FONT,
		Vector2.new(SHIFT_PREVIEW_TEXT_WIDTH, 10000)
	)
	return bounds.Y
end

local function refreshShiftSelectLayout()
	if not shiftSelectPanel or not shiftSelectPreviewPane or not shiftSelectList or not shiftSelectPreviewLabel then
		return
	end

	local text = shiftSelectPreviewLabel.Text
	local textHeight = measurePreviewTextHeight(text)
	local desiredPreviewHeight = if shiftPreviewExpanded then textHeight + 14 else SHIFT_PREVIEW_MIN_HEIGHT
	local previewHeight = math.max(
		SHIFT_PREVIEW_MIN_HEIGHT,
		math.min(desiredPreviewHeight, SHIFT_PREVIEW_MAX_HEIGHT)
	)
	local previewBottomMargin = 8
	local listTop = SHIFT_SELECT_LIST_TOP
	local listGap = 8

	shiftSelectPreviewLabel.Size = UDim2.new(1, -16, 0, textHeight + 4)

	shiftSelectPreviewPane.Size = UDim2.fromOffset(396, previewHeight)
	shiftSelectPreviewPane.Position = UDim2.new(0, 12, 1, -(previewHeight + previewBottomMargin))

	local panelHeight = math.max(
		SHIFT_PREVIEW_PANEL_MIN_HEIGHT,
		listTop + SHIFT_PREVIEW_LIST_MIN_HEIGHT + listGap + previewHeight + previewBottomMargin
	)
	shiftSelectPanel.Size = UDim2.fromOffset(420, panelHeight)
	shiftSelectPanel.Position = UDim2.new(0.5, -210, 0.5, -math.floor(panelHeight / 2))

	local listHeight = panelHeight - listTop - previewHeight - previewBottomMargin - listGap
	shiftSelectList.Size = UDim2.fromOffset(396, math.max(SHIFT_PREVIEW_LIST_MIN_HEIGHT, listHeight))
end

local function refreshShiftPreviewSelection()
	for shiftId, button in shiftPreviewButtons do
		local selected = shiftId == selectedShiftPreviewId
		button.BackgroundColor3 = if selected then SHIFT_PREVIEW_BUTTON_SELECTED_COLOR else SHIFT_PREVIEW_BUTTON_COLOR
	end

	for shiftId, stroke in shiftPreviewCardStrokes do
		local selected = shiftId == selectedShiftPreviewId
		stroke.Color = if selected then SHIFT_CARD_SELECTED_STROKE_COLOR else SHIFT_CARD_STROKE_COLOR
		stroke.Thickness = if selected then 2 else 1
	end
end

local function setShiftDemandPreview(shiftId: string?)
	if not shiftSelectPreviewLabel then
		return
	end

	if not shiftId then
		shiftPreviewExpanded = false
		selectedShiftPreviewId = nil
		shiftSelectPreviewLabel.Text = SHIFT_PREVIEW_HINT
	else
		shiftPreviewExpanded = true
		selectedShiftPreviewId = shiftId
		local preview = DemandPreview.buildFromSnapshot(shiftId, currentInventorySnapshot)
		shiftSelectPreviewLabel.Text = formatDemandPreviewText(preview)
	end

	refreshShiftPreviewSelection()
	task.defer(refreshShiftSelectLayout)
end

local function clearShiftSelectList()
	selectedShiftPreviewId = nil
	shiftPreviewButtons = {}
	shiftPreviewCardStrokes = {}

	for _, child in shiftSelectList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function refreshDealRootVisibility()
	if not dealRoot then
		return
	end
	local snap = currentShiftSnapshot
	dealRoot.Visible = snap ~= nil and snap.active == true
end

local function createButton(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.Text = text
	button.Position = position
	button.Size = size
	button.Parent = parent
	return button
end

local function clearStashList()
	if not stashList then
		return
	end

	for _, child in stashList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function isStashRouteLocked(): boolean
	local phase = currentSnapshot and currentSnapshot.phase
	return phase == "BuyerVisit" or phase == "Selling"
end

local function setRouteButtonState(button: TextButton, enabled: boolean, label: string, disabledLabel: string?)
	button.Text = if enabled then label else (disabledLabel or label)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.45
	button.BackgroundColor3 = if enabled then Color3.fromRGB(70, 100, 76) else Color3.fromRGB(55, 55, 55)
end

local function invokeStashAction(remoteName: string, instanceId: string)
	if not stashActionsEnabled or not stashActionCallback then
		return
	end
	stashActionCallback(remoteName, instanceId)
end

local function itemSubtitle(entry: any): string
	local parts = {}
	if entry.category and entry.category ~= "" then
		table.insert(parts, entry.category)
	end
	if entry.purchasePrice then
		table.insert(parts, `paid {entry.purchasePrice}`)
	end
	return if #parts > 0 then table.concat(parts, " - ") else ""
end

local function addStashSectionHeader(text: string, order: number)
	if not stashList then
		return order
	end

	local header = createLabel(stashList, `Header_{order}`, text, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 24))
	header.LayoutOrder = order
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextColor3 = Color3.fromRGB(255, 220, 140)
	return order + 1
end

local function addStashEmptyRow(text: string, order: number)
	if not stashList then
		return order
	end

	local row = createLabel(stashList, `Empty_{order}`, text, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 30))
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	row.BackgroundTransparency = 0.15
	row.TextSize = 12
	row.TextColor3 = Color3.fromRGB(175, 175, 185)
	return order + 1
end

local function addStashItemRow(entry: any, actions: { any }, order: number)
	if not stashList then
		return order
	end

	local row = Instance.new("Frame")
	row.Name = `Item_{entry.instanceId or order}`
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	row.BackgroundTransparency = 0.08
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, 54)
	row.LayoutOrder = order
	row.Parent = stashList

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local nameLabel = createLabel(
		row,
		"Name",
		entry.displayName or "Item",
		UDim2.fromOffset(8, 5),
		UDim2.new(1, -190, 0, 22)
	)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)

	local detailLabel = createLabel(
		row,
		"Details",
		itemSubtitle(entry),
		UDim2.fromOffset(8, 28),
		UDim2.new(1, -190, 0, 18)
	)
	detailLabel.BackgroundTransparency = 1
	detailLabel.TextSize = 11
	detailLabel.TextColor3 = Color3.fromRGB(175, 205, 180)

	local buttonWidth = 82
	local buttonGap = 6
	local startX = 468 - (#actions * buttonWidth) - ((#actions - 1) * buttonGap) - 12
	for index, action in actions do
		local button = createButton(
			row,
			action.name,
			action.label,
			UDim2.fromOffset(startX + (index - 1) * (buttonWidth + buttonGap), 14),
			UDim2.fromOffset(buttonWidth, 26)
		)
		button.TextSize = 11
		setRouteButtonState(button, action.enabled, action.label, action.disabledLabel)
		button.MouseButton1Click:Connect(function()
			if action.enabled and entry.instanceId then
				invokeStashAction(action.remoteName, entry.instanceId)
			end
		end)
	end

	return order + 1
end

local function refreshStashOverlay()
	if not stashOverlay or not stashOverlay.Visible or not stashList then
		return
	end

	clearStashList()

	local inventory = currentInventorySnapshot or {}
	local activeShift = currentShiftSnapshot ~= nil and currentShiftSnapshot.active == true and currentShiftSnapshot.ended ~= true
	local locked = isStashRouteLocked()
	local stashFull = (inventory.stashUsedSlots or 0) >= (inventory.stashMaxSlots or 6)
	local displayFull = (inventory.displayUsedSlots or 0) >= (inventory.displayMaxSlots or 3)
	local shelfFull = (inventory.usedSlots or 0) >= (inventory.maxSlots or 3)
	local lockedLabel = if locked then "Finish buyer first" else nil
	local order = 1

	order = addStashSectionHeader(`Working Stock ({inventory.usedSlots or 0}/{inventory.maxSlots or 3})`, order)
	local stockItems = inventory.items or {}
	if #stockItems == 0 then
		order = addStashEmptyRow("No working stock on the shelf.", order)
	else
		for _, entry in stockItems do
			local enabled = activeShift and not locked and not stashFull and stashActionsEnabled
			local disabledLabel = lockedLabel or (if not activeShift then "Open shift" elseif stashFull then "Stash full" else "Stash")
			order = addStashItemRow(entry, {
				{
					name = "Stash",
					label = "Stash",
					disabledLabel = disabledLabel,
					enabled = enabled,
					remoteName = "StashInventoryItem",
				},
			}, order)
		end
	end

	order = addStashSectionHeader(`Stash ({inventory.stashUsedSlots or 0}/{inventory.stashMaxSlots or 6})`, order)
	local stashItems = inventory.stashItems or {}
	if #stashItems == 0 then
		order = addStashEmptyRow("Nothing stashed.", order)
	else
		for _, entry in stashItems do
			local displayEnabled = not locked and not displayFull and stashActionsEnabled
			local shelfEnabled = activeShift and not locked and not shelfFull and stashActionsEnabled
			local displayDisabled = lockedLabel or (if displayFull then "Display full" else "Display")
			local shelfDisabled = lockedLabel or (if not activeShift then "Open shift" elseif shelfFull then "Shelf full" else "To Shelf")
			order = addStashItemRow(entry, {
				{
					name = "Display",
					label = "Display",
					disabledLabel = displayDisabled,
					enabled = displayEnabled,
					remoteName = "MoveStashedItemToDisplay",
				},
				{
					name = "ToShelf",
					label = "To Shelf",
					disabledLabel = shelfDisabled,
					enabled = shelfEnabled,
					remoteName = "ReturnStashedItemToInventory",
				},
			}, order)
		end
	end

	order = addStashSectionHeader(`Display ({inventory.displayUsedSlots or 0}/{inventory.displayMaxSlots or 3})`, order)
	local displayItems = inventory.displayItems or {}
	if #displayItems == 0 then
		order = addStashEmptyRow("DisplayShelf is empty.", order)
	else
		for _, entry in displayItems do
			local enabled = not locked and not stashFull and stashActionsEnabled
			local disabledLabel = lockedLabel or (if stashFull then "Stash full" else "Stash")
			order = addStashItemRow(entry, {
				{
					name = "Stash",
					label = "Stash",
					disabledLabel = disabledLabel,
					enabled = enabled,
					remoteName = "MoveDisplayItemToStash",
				},
			}, order)
		end
	end
end

function UIController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WastelandPawnDealUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	hubToast = createLabel(screenGui, "HubToast", "", UDim2.new(0.5, -220, 0, 12), UDim2.fromOffset(440, 36))
	hubToast.Visible = false
	hubToast.ZIndex = 20
	hubToast.TextXAlignment = Enum.TextXAlignment.Center
	hubToast.Font = Enum.Font.GothamBold
	hubToast.TextSize = 14
	hubToast.TextColor3 = Color3.fromRGB(255, 235, 175)
	hubToast.BackgroundColor3 = Color3.fromRGB(30, 28, 38)
	hubToast.BackgroundTransparency = 0.1

	hubHoldingBanner = createLabel(screenGui, "HubHoldingBanner", "", UDim2.new(0.5, -220, 0, 52), UDim2.fromOffset(440, 28))
	hubHoldingBanner.Visible = false
	hubHoldingBanner.ZIndex = 20
	hubHoldingBanner.TextXAlignment = Enum.TextXAlignment.Center
	hubHoldingBanner.Font = Enum.Font.Gotham
	hubHoldingBanner.TextSize = 13
	hubHoldingBanner.TextColor3 = Color3.fromRGB(200, 230, 200)
	hubHoldingBanner.BackgroundColor3 = Color3.fromRGB(28, 38, 32)
	hubHoldingBanner.BackgroundTransparency = 0.15

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	root.BorderSizePixel = 0
	root.Position = UDim2.fromOffset(20, 20)
	root.Size = UDim2.fromOffset(440, 700)
	root.Visible = false
	root.Parent = screenGui
	dealRoot = root

	labels.title = createLabel(root, "Title", "Wasteland Pawn - Tactics", UDim2.fromOffset(12, 8), UDim2.fromOffset(416, 26))
	labels.title.TextSize = 17
	labels.title.Font = Enum.Font.GothamBold

	labels.shift = createLabel(root, "Shift", "Choose a shift to begin.", UDim2.fromOffset(12, 38), UDim2.fromOffset(416, 48))
	labels.shift.Font = Enum.Font.GothamBold
	labels.shift.TextColor3 = Color3.fromRGB(255, 235, 175)

	labels.customer = createLabel(root, "Customer", "Trader: -", UDim2.fromOffset(12, 92), UDim2.fromOffset(416, 22))
	labels.tell = createLabel(root, "Tell", "Tell: -", UDim2.fromOffset(12, 116), UDim2.fromOffset(416, 46))
	labels.tell.TextColor3 = Color3.fromRGB(180, 220, 255)

	labels.dialogue = createLabel(root, "Dialogue", "...", UDim2.fromOffset(12, 166), UDim2.fromOffset(416, 44))
	labels.item = createLabel(root, "Item", "Item: -", UDim2.fromOffset(12, 212), UDim2.fromOffset(416, 58))
	labels.prices = createLabel(root, "Prices", "", UDim2.fromOffset(12, 272), UDim2.fromOffset(416, 64))
	labels.cash = createLabel(root, "Cash", "Your scraps: -", UDim2.fromOffset(12, 338), UDim2.fromOffset(416, 22))

	labels.outcome = createLabel(root, "Outcome", "", UDim2.fromOffset(12, 362), UDim2.fromOffset(416, 20))
	labels.outcome.Font = Enum.Font.GothamBold

	heatBarBg = Instance.new("Frame")
	heatBarBg.Name = "HeatBarBg"
	heatBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	heatBarBg.BorderSizePixel = 0
	heatBarBg.Position = UDim2.fromOffset(12, 386)
	heatBarBg.Size = UDim2.fromOffset(416, 16)
	heatBarBg.Parent = root

	heatBarFill = Instance.new("Frame")
	heatBarFill.Name = "HeatBarFill"
	heatBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	heatBarFill.BorderSizePixel = 0
	heatBarFill.Size = UDim2.new(0, 0, 1, 0)
	heatBarFill.Parent = heatBarBg

	labels.heat = createLabel(root, "Heat", "Heat: 0", UDim2.fromOffset(12, 406), UDim2.fromOffset(416, 34))
	labels.heat.BackgroundTransparency = 1

	labels.inspect = createLabel(root, "Inspect", "", UDim2.fromOffset(12, 442), UDim2.fromOffset(416, 42))
	labels.result = createLabel(root, "Result", "", UDim2.fromOffset(12, 474), UDim2.fromOffset(416, 86))
	labels.result.Visible = false

	labels.inventory = createLabel(root, "Inventory", "Inventory: 0/3", UDim2.fromOffset(12, 562), UDim2.fromOffset(416, 68))
	labels.inventory.TextColor3 = Color3.fromRGB(210, 240, 210)
	labels.inventory.Visible = false

	labels.shiftResult = createLabel(root, "ShiftResult", "", UDim2.fromOffset(12, 562), UDim2.fromOffset(416, 68))
	labels.shiftResult.Font = Enum.Font.GothamBold
	labels.shiftResult.Visible = false

	-- Buy tactics
	buttons.lowball = createButton(root, "Lowball", "Lowball", UDim2.fromOffset(12, 634), UDim2.fromOffset(98, 30))
	buttons.split = createButton(root, "Split", "Split Diff", UDim2.fromOffset(116, 634), UDim2.fromOffset(98, 30))
	buttons.flaw = createButton(root, "Flaw", "Point Flaw", UDim2.fromOffset(220, 634), UDim2.fromOffset(98, 30))
	buttons.pressure = createButton(root, "Pressure", "Pressure", UDim2.fromOffset(324, 634), UDim2.fromOffset(104, 30))
	buttons.acceptBuy = createButton(root, "AcceptBuy", "Accept Price", UDim2.fromOffset(12, 668), UDim2.fromOffset(130, 26))
	buttons.pass = createButton(root, "Pass", "Pass", UDim2.fromOffset(148, 668), UDim2.fromOffset(80, 26))
	buttons.inspectBtn = createButton(
		root,
		"InspectBtn",
		`Inspect ({HaggleTuning.inspectCost})`,
		UDim2.fromOffset(234, 668),
		UDim2.fromOffset(100, 26)
	)

	-- Sell tactics
	buttons.smallBump = createButton(root, "SmallBump", "Small Bump", UDim2.fromOffset(12, 634), UDim2.fromOffset(98, 30))
	buttons.pitch = createButton(root, "Pitch", "Pitch Value", UDim2.fromOffset(116, 634), UDim2.fromOffset(98, 30))
	buttons.holdFirm = createButton(root, "HoldFirm", "Hold Firm", UDim2.fromOffset(220, 634), UDim2.fromOffset(98, 30))
	buttons.bluff = createButton(root, "Bluff", "Bluff", UDim2.fromOffset(324, 634), UDim2.fromOffset(104, 30))
	buttons.acceptSell = createButton(root, "AcceptSell", "Accept Offer", UDim2.fromOffset(12, 668), UDim2.fromOffset(130, 26))
	buttons.findBuyer = createButton(root, "FindBuyer", "Find Buyer", UDim2.fromOffset(12, 668), UDim2.fromOffset(120, 26))
	buttons.findAnother = createButton(root, "FindAnother", "Skip Buyer", UDim2.fromOffset(148, 668), UDim2.fromOffset(120, 26))
	buttons.keep = createButton(root, "Keep", "Keep Item", UDim2.fromOffset(276, 668), UDim2.fromOffset(100, 26))
	buttons.next = createButton(root, "Next", "Next Customer", UDim2.fromOffset(276, 668), UDim2.fromOffset(152, 26))
	buttons.closeShift = createButton(root, "CloseShift", "Liquidate & Close", UDim2.fromOffset(12, 668), UDim2.fromOffset(120, 26))
	buttons.closeShift.TextSize = 12

	buttons.offerSlot1 = createButton(root, "OfferSlot1", "Offer 1", UDim2.fromOffset(12, 634), UDim2.fromOffset(132, 30))
	buttons.offerSlot2 = createButton(root, "OfferSlot2", "Offer 2", UDim2.fromOffset(150, 634), UDim2.fromOffset(132, 30))
	buttons.offerSlot3 = createButton(root, "OfferSlot3", "Offer 3", UDim2.fromOffset(288, 634), UDim2.fromOffset(140, 30))
	buttons.offerSlot1.TextSize = 12
	buttons.offerSlot2.TextSize = 12
	buttons.offerSlot3.TextSize = 12
	buttons.offerSlot1.TextWrapped = true
	buttons.offerSlot2.TextWrapped = true
	buttons.offerSlot3.TextWrapped = true

	local sellOnly = {
		"smallBump",
		"pitch",
		"holdFirm",
		"bluff",
		"acceptSell",
		"findAnother",
		"closeShift",
		"offerSlot1",
		"offerSlot2",
		"offerSlot3",
	}
	for _, name in sellOnly do
		buttons[name].Visible = false
	end
	buttons.next.Visible = false

	shiftSelectOverlay = Instance.new("Frame")
	shiftSelectOverlay.Name = "ShiftSelectOverlay"
	shiftSelectOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shiftSelectOverlay.BackgroundTransparency = 0.45
	shiftSelectOverlay.BorderSizePixel = 0
	shiftSelectOverlay.Size = UDim2.fromScale(1, 1)
	shiftSelectOverlay.Visible = false
	shiftSelectOverlay.ZIndex = 10
	shiftSelectOverlay.Parent = screenGui

	shiftSelectPanel = Instance.new("Frame")
	shiftSelectPanel.Name = "Panel"
	shiftSelectPanel.BackgroundColor3 = Color3.fromRGB(22, 20, 28)
	shiftSelectPanel.BorderSizePixel = 0
	shiftSelectPanel.Position = UDim2.new(0.5, -210, 0.5, -260)
	shiftSelectPanel.Size = UDim2.fromOffset(420, 520)
	shiftSelectPanel.Parent = shiftSelectOverlay

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(255, 120, 180)
	panelStroke.Thickness = 2
	panelStroke.Parent = shiftSelectPanel

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = shiftSelectPanel

	labels.shiftSelectTitle = createLabel(
		shiftSelectPanel,
		"Title",
		"Traffic Board",
		UDim2.fromOffset(12, 10),
		UDim2.fromOffset(396, 28)
	)
	labels.shiftSelectTitle.BackgroundTransparency = 1
	labels.shiftSelectTitle.Font = Enum.Font.GothamBold
	labels.shiftSelectTitle.TextSize = 20
	labels.shiftSelectTitle.TextColor3 = Color3.fromRGB(255, 220, 140)

	labels.shiftSelectSubtitle = createLabel(
		shiftSelectPanel,
		"Subtitle",
		"Session traffic windows. Tap ? for demand preview.",
		UDim2.fromOffset(12, 38),
		UDim2.fromOffset(396, 58)
	)
	labels.shiftSelectSubtitle.BackgroundTransparency = 1
	labels.shiftSelectSubtitle.TextSize = 12
	labels.shiftSelectSubtitle.TextColor3 = Color3.fromRGB(190, 190, 200)

	buttons.shiftSelectClose = createButton(shiftSelectPanel, "Close", "Close", UDim2.fromOffset(340, 8), UDim2.fromOffset(68, 24))
	buttons.shiftSelectClose.TextSize = 12
	buttons.shiftSelectClose.MouseButton1Click:Connect(function()
		self:closeShiftSelect()
	end)

	shiftSelectList = Instance.new("ScrollingFrame")
	shiftSelectList.Name = "OptionList"
	shiftSelectList.BackgroundTransparency = 1
	shiftSelectList.BorderSizePixel = 0
	shiftSelectList.Position = UDim2.fromOffset(12, SHIFT_SELECT_LIST_TOP)
	shiftSelectList.Size = UDim2.fromOffset(396, 264)
	shiftSelectList.CanvasSize = UDim2.fromOffset(0, 0)
	shiftSelectList.ScrollBarThickness = 6
	shiftSelectList.Parent = shiftSelectPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = shiftSelectList

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		shiftSelectList.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
	end)

	local previewPane = Instance.new("Frame")
	previewPane.Name = "DemandPreview"
	previewPane.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
	previewPane.BorderSizePixel = 0
	previewPane.Position = UDim2.fromOffset(12, 364)
	previewPane.Size = UDim2.fromOffset(396, SHIFT_PREVIEW_MIN_HEIGHT)
	previewPane.Parent = shiftSelectPanel
	shiftSelectPreviewPane = previewPane

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 8)
	previewCorner.Parent = previewPane

	local previewStroke = Instance.new("UIStroke")
	previewStroke.Color = Color3.fromRGB(90, 85, 110)
	previewStroke.Thickness = 1
	previewStroke.Parent = previewPane

	shiftSelectPreviewLabel = createLabel(
		previewPane,
		"PreviewText",
		SHIFT_PREVIEW_HINT,
		UDim2.fromOffset(8, 6),
		UDim2.new(1, -16, 0, 20)
	)
	shiftSelectPreviewLabel.BackgroundTransparency = 1
	shiftSelectPreviewLabel.TextXAlignment = Enum.TextXAlignment.Left
	shiftSelectPreviewLabel.TextYAlignment = Enum.TextYAlignment.Top
	shiftSelectPreviewLabel.TextWrapped = true
	shiftSelectPreviewLabel.TextSize = SHIFT_PREVIEW_TEXT_SIZE
	shiftSelectPreviewLabel.TextColor3 = Color3.fromRGB(205, 205, 215)
	shiftSelectPreviewLabel.Font = SHIFT_PREVIEW_FONT
	shiftSelectPreviewLabel.ClipsDescendants = false

	refreshShiftSelectLayout()

	stashOverlay = Instance.new("Frame")
	stashOverlay.Name = "StashOverlay"
	stashOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stashOverlay.BackgroundTransparency = 0.45
	stashOverlay.BorderSizePixel = 0
	stashOverlay.Size = UDim2.fromScale(1, 1)
	stashOverlay.Visible = false
	stashOverlay.ZIndex = 12
	stashOverlay.Parent = screenGui

	local stashPanel = Instance.new("Frame")
	stashPanel.Name = "Panel"
	stashPanel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
	stashPanel.BorderSizePixel = 0
	stashPanel.Position = UDim2.new(0.5, -250, 0.5, -260)
	stashPanel.Size = UDim2.fromOffset(500, 520)
	stashPanel.Parent = stashOverlay

	local stashPanelStroke = Instance.new("UIStroke")
	stashPanelStroke.Color = Color3.fromRGB(120, 185, 145)
	stashPanelStroke.Thickness = 2
	stashPanelStroke.Parent = stashPanel

	local stashPanelCorner = Instance.new("UICorner")
	stashPanelCorner.CornerRadius = UDim.new(0, 10)
	stashPanelCorner.Parent = stashPanel

	local stashTitle = createLabel(
		stashPanel,
		"Title",
		"Stash",
		UDim2.fromOffset(12, 10),
		UDim2.fromOffset(360, 28)
	)
	stashTitle.BackgroundTransparency = 1
	stashTitle.Font = Enum.Font.GothamBold
	stashTitle.TextSize = 20
	stashTitle.TextColor3 = Color3.fromRGB(210, 245, 210)

	local stashSubtitle = createLabel(
		stashPanel,
		"Subtitle",
		"Session-only storage. Display affects demand; stash does not.",
		UDim2.fromOffset(12, 38),
		UDim2.fromOffset(396, 22)
	)
	stashSubtitle.BackgroundTransparency = 1
	stashSubtitle.TextSize = 12
	stashSubtitle.TextColor3 = Color3.fromRGB(190, 200, 190)

	local stashClose = createButton(stashPanel, "Close", "Close", UDim2.fromOffset(420, 8), UDim2.fromOffset(68, 24))
	stashClose.TextSize = 12
	stashClose.MouseButton1Click:Connect(function()
		self:closeStash()
	end)

	stashList = Instance.new("ScrollingFrame")
	stashList.Name = "StashList"
	stashList.BackgroundTransparency = 1
	stashList.BorderSizePixel = 0
	stashList.Position = UDim2.fromOffset(12, 68)
	stashList.Size = UDim2.fromOffset(476, 438)
	stashList.CanvasSize = UDim2.fromOffset(0, 0)
	stashList.ScrollBarThickness = 6
	stashList.Parent = stashPanel

	local stashListLayout = Instance.new("UIListLayout")
	stashListLayout.Padding = UDim.new(0, 6)
	stashListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stashListLayout.Parent = stashList

	stashListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if stashList then
			stashList.CanvasSize = UDim2.fromOffset(0, stashListLayout.AbsoluteContentSize.Y + 8)
		end
	end)

	self:updateShiftSnapshot({ active = false, ended = false })
end

function UIController:getSnapshot()
	return currentSnapshot
end

function UIController:getShiftSnapshot()
	return currentShiftSnapshot
end

function UIController:getInventorySnapshot()
	return currentInventorySnapshot
end

function UIController:isShiftActive(): boolean
	return currentShiftSnapshot ~= nil and currentShiftSnapshot.active == true
end

function UIController:showHubMessage(text: string)
	labels.shift.Text = text
	if hubToast then
		hubToast.Text = text
		hubToast.Visible = text ~= ""
		if text ~= "" then
			task.delay(4, function()
				if hubToast and hubToast.Text == text then
					hubToast.Visible = false
				end
			end)
		end
	end
end

function UIController:setHubHolding(displayName: string?)
	if not hubHoldingBanner then
		return
	end
	if displayName and displayName ~= "" then
		hubHoldingBanner.Text = `Holding: {displayName}`
		hubHoldingBanner.Visible = true
	else
		hubHoldingBanner.Text = ""
		hubHoldingBanner.Visible = false
	end
end

function UIController:closeShiftSelect()
	if shiftSelectOverlay then
		shiftSelectOverlay.Visible = false
	end
	setShiftDemandPreview(nil)
end

function UIController:openStash()
	if not stashOverlay then
		return false
	end

	if not stashActionCallback then
		self:showHubMessage("Stash is not ready yet.")
		return false
	end

	stashOverlay.Visible = true
	refreshStashOverlay()
	return true
end

function UIController:closeStash()
	if stashOverlay then
		stashOverlay.Visible = false
	end
end

function UIController:onStashAction(callback: (string, string) -> ())
	stashActionCallback = callback
end

function UIController:setStashActionsEnabled(enabled: boolean)
	stashActionsEnabled = enabled
	refreshStashOverlay()
end

function UIController:onShiftSelectStart(callback: (string) -> ())
	shiftSelectStartCallback = callback
end

function UIController:openShiftSelect(options, traffic)
	if self:isShiftActive() then
		self:showHubMessage("Shift already in progress. Finish or end it first.")
		return false
	end

	if not options or #options == 0 then
		self:showHubMessage("No shift options available.")
		return false
	end

	if not shiftSelectStartCallback then
		self:showHubMessage("Shift start is not ready yet. Try again.")
		warn("UIController: shiftSelectStartCallback missing")
		return false
	end

	local cur = currencyLabel(currentSnapshot)
	clearShiftSelectList()
	setShiftDemandPreview(nil)
	labels.shiftSelectTitle.Text = formatTrafficBoardTitle(traffic)
	labels.shiftSelectSubtitle.Text = formatTrafficBoardText(traffic, options)

	for index, option in options do
		local shiftId = option.id
		local card = Instance.new("Frame")
		card.Name = `Option_{option.id or index}`
		card.BackgroundColor3 = Color3.fromRGB(34, 32, 42)
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, -4, 0, 118)
		card.LayoutOrder = index
		card.Parent = shiftSelectList

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = SHIFT_CARD_STROKE_COLOR
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		local nameLabel = createLabel(card, "Name", option.displayName or "Shift", UDim2.fromOffset(10, 6), UDim2.new(1, -120, 0, 22))
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextColor3 = Color3.fromRGB(255, 235, 175)

		local modifierLabel = createLabel(
			card,
			"Modifier",
			formatShiftCardModifier(option),
			UDim2.fromOffset(10, 28),
			UDim2.new(1, -20, 0, 18)
		)
		modifierLabel.BackgroundTransparency = 1
		modifierLabel.TextSize = 12
		modifierLabel.TextColor3 = Color3.fromRGB(200, 180, 255)

		local descLabel = createLabel(
			card,
			"Description",
			option.trafficDescription or option.description or "",
			UDim2.fromOffset(10, 46),
			UDim2.new(1, -20, 0, 32)
		)
		descLabel.BackgroundTransparency = 1
		descLabel.TextSize = 12
		descLabel.TextColor3 = Color3.fromRGB(210, 210, 210)

		local statsLabel = createLabel(
			card,
			"Stats",
			formatShiftOptionStats(option, cur),
			UDim2.fromOffset(10, 78),
			UDim2.new(1, -112, 0, 32)
		)
		statsLabel.BackgroundTransparency = 1
		statsLabel.TextSize = 11
		statsLabel.TextColor3 = Color3.fromRGB(160, 200, 160)

		local startBottom = SHIFT_CARD_ACTION_RIGHT
		local startTop = startBottom + SHIFT_CARD_START_HEIGHT
		local previewBottom = startTop + SHIFT_CARD_ACTION_GAP + SHIFT_CARD_PREVIEW_HEIGHT

		local startButton = createButton(
			card,
			"Start",
			"Start",
			UDim2.new(1, -(88 + SHIFT_CARD_ACTION_RIGHT), 1, -startTop),
			UDim2.fromOffset(88, SHIFT_CARD_START_HEIGHT)
		)
		startButton.TextSize = 12
		startButton.BackgroundColor3 = Color3.fromRGB(70, 120, 80)

		local previewButton = createButton(
			card,
			"Preview",
			"?",
			UDim2.new(1, -(26 + SHIFT_CARD_ACTION_RIGHT), 1, -previewBottom),
			UDim2.fromOffset(26, SHIFT_CARD_PREVIEW_HEIGHT)
		)
		previewButton.TextSize = 14
		previewButton.BackgroundColor3 = SHIFT_PREVIEW_BUTTON_COLOR

		if type(shiftId) == "string" then
			shiftPreviewButtons[shiftId] = previewButton
			shiftPreviewCardStrokes[shiftId] = cardStroke
		end

		previewButton.MouseButton1Click:Connect(function()
			if shiftId then
				setShiftDemandPreview(shiftId)
			end
		end)
		startButton.MouseButton1Click:Connect(function()
			if self:isShiftActive() then
				self:showHubMessage("Shift already in progress.")
				return
			end
			if shiftSelectStartCallback and shiftId then
				shiftSelectStartCallback(shiftId)
			end
		end)
	end

	if hubToast then
		hubToast.Visible = false
	end
	shiftSelectOverlay.Visible = true
	task.defer(refreshShiftSelectLayout)
	return true
end

local function refreshAcceptBuyButton()
	local snapshot = currentSnapshot
	local phase = snapshot and snapshot.phase
	local inventory = currentInventorySnapshot or (snapshot and snapshot.inventory)
	local inventoryFull = phase == "Haggling"
		and inventory
		and (inventory.usedSlots or 0) >= (inventory.maxSlots or 3)
	local canAccept = tacticButtonsEnabled and phase == "Haggling" and not inventoryFull

	buttons.acceptBuy.Active = canAccept
	buttons.acceptBuy.AutoButtonColor = canAccept
	buttons.acceptBuy.BackgroundTransparency = if canAccept then 0 else 0.45
	buttons.acceptBuy.Text = if inventoryFull then "Inventory Full" else "Accept Price"
end

function UIController:setTacticButtonsEnabled(enabled: boolean)
	tacticButtonsEnabled = enabled
	local alpha = if enabled then 0 else 0.45
	for name, button in buttons do
		if name ~= "shiftSelectClose" then
			button.Active = enabled
			button.AutoButtonColor = enabled
			button.BackgroundTransparency = alpha
		end
	end
	refreshAcceptBuyButton()
end

local function updateHeatBar(heat: number, maxHeat: number)
	local ratio = math.clamp(heat / math.max(maxHeat, 1), 0, 1)
	heatBarFill.Size = UDim2.new(ratio, 0, 1, 0)
	if heat >= (HaggleTuning.heatWalkThreshold or 100) then
		heatBarFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	elseif heat >= (HaggleTuning.heatWarningThreshold or 60) then
		heatBarFill.BackgroundColor3 = Color3.fromRGB(220, 170, 60)
	else
		heatBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	end
end

function UIController:setPhaseControls(phase: string)
	local hasShift = currentShiftSnapshot and currentShiftSnapshot.active
	local showDeal = hasShift or (currentShiftSnapshot and currentShiftSnapshot.ended and currentSnapshot ~= nil)
	local buy = phase == "Haggling"
	local buyerVisit = phase == "BuyerVisit"
	local sell = phase == "Selling"
	local terminal = phase == "WalkedAway" or phase == "Result" or phase == "Stored" or phase == "BuyerSkipped"
	local closingRush = currentShiftSnapshot and currentShiftSnapshot.phase == "ClosingRush"

	for _, name in { "lowball", "split", "flaw", "pressure", "acceptBuy", "pass", "inspectBtn" } do
		buttons[name].Visible = hasShift and buy
	end
	for _, name in { "smallBump", "pitch", "holdFirm", "bluff", "acceptSell" } do
		buttons[name].Visible = hasShift and sell
	end
	buttons.findAnother.Visible = false
	for _, name in { "offerSlot1", "offerSlot2", "offerSlot3" } do
		buttons[name].Visible = hasShift and buyerVisit
	end
	buttons.findBuyer.Visible = false
	buttons.keep.Visible = hasShift and (buyerVisit or sell)
	buttons.keep.Text = if buyerVisit then "Skip Buyer" else "Keep Item"
	buttons.closeShift.Visible = hasShift and closingRush and not sell
	local buyerSkipped = phase == "BuyerSkipped"
	local inventoryCount = currentInventorySnapshot and currentInventorySnapshot.usedSlots or 0
	local sellersRemaining = (currentShiftSnapshot and currentShiftSnapshot.dealsRemaining or 0) > 0
	local closingRushBuyersAvailable = closingRush
		and inventoryCount > 0
		and ((currentShiftSnapshot and currentShiftSnapshot.closingRushBuyersRemaining or 0) > 0
			or currentShiftSnapshot.pendingBuyerVisit == true)
	buttons.next.Visible = hasShift
		and (buyerSkipped or (terminal and (sellersRemaining or closingRushBuyersAvailable)))
	buttons.next.Text = if buyerSkipped then "Continue" else "Next Customer"

	labels.customer.Visible = showDeal
	labels.dialogue.Visible = showDeal
	labels.item.Visible = showDeal and not buyerSkipped
	labels.prices.Visible = showDeal and not buyerSkipped
	labels.cash.Visible = showDeal
	labels.outcome.Visible = showDeal and not buyerSkipped
	heatBarBg.Visible = showDeal and (buy or sell)
	labels.heat.Visible = showDeal and (buy or sell)
	labels.tell.Visible = showDeal and (buy or sell or buyerVisit or phase == "Stored")
	labels.inspect.Visible = showDeal and buy
	labels.result.Visible = showDeal and (sell or (terminal and not buyerSkipped))
	labels.inventory.Visible = hasShift and not (currentShiftSnapshot and currentShiftSnapshot.ended)
end

function UIController:updateSnapshot(snapshot)
	currentSnapshot = snapshot
	if not snapshot then
		return
	end

	local phase = snapshot.phase or "Haggling"
	local cur = currencyLabel(snapshot)
	if snapshot.inventory then
		currentInventorySnapshot = snapshot.inventory
	end
	if snapshot.shift then
		currentShiftSnapshot = snapshot.shift
	end
	if phase == "BuyerSkipped" and currentShiftSnapshot then
		self:updateShiftSnapshot(currentShiftSnapshot)
	else
		self:setPhaseControls(phase)
	end
	refreshStashOverlay()

	if phase == "BuyerSkipped" then
		labels.customer.Text = if snapshot.rareWalkInBuyer then "Rare Walk-In Skipped" else "Buyer Visit Skipped"
		labels.dialogue.Text = snapshot.dialogue or "A buyer came looking, but your shelves are empty."
		labels.item.Text = ""
		labels.prices.Text = ""
		labels.cash.Text = `Your {cur}: {snapshot.playerCash or 0}`
		labels.heat.Text = ""
		labels.tell.Text = ""
		labels.inspect.Text = ""
		labels.result.Text = ""
		labels.outcome.Text = ""
		refreshInventoryLabel()
		refreshAcceptBuyButton()
		return
	end

	local isSell = phase == "Selling"
	local isBuyerVisit = phase == "BuyerVisit"
	local isBuyerFacing = isSell or isBuyerVisit
	labels.customer.Text = if isBuyerFacing
		then `{if snapshot.rareWalkInBuyer then "Rare Walk-In" else "Buyer"}: {snapshot.buyerName or "?"}`
		else `Seller: {snapshot.customerName or "?"}`
	local readHint = if isBuyerFacing then snapshot.buyerReadHint or snapshot.buyerWants else snapshot.sellerReadHint
	labels.tell.Text = `Tell: {if isBuyerFacing then snapshot.buyerTell or "?" else snapshot.sellerTell or "?"}`
	if readHint then
		labels.tell.Text ..= `\n{readHint}`
	end
	local displayInfluenceHelp = if isBuyerVisit then formatDisplayInfluenceHelp(snapshot) else nil
	if displayInfluenceHelp then
		labels.tell.Text ..= `\n{displayInfluenceHelp}`
	end
	labels.dialogue.Text = compactTerminalDialogue(phase, snapshot)
	if isBuyerVisit then
		labels.item.Text = "Choose an item to offer."
	else
		local traits = formatTraits(snapshot.traits)
		labels.item.Text = `{snapshot.itemName or "?"} ({snapshot.category or "?"})\nTraits: {traits}\n{snapshot.flavorText or ""}`
	end

	local lines = {}
	if phase == "Haggling" or phase == "Stored" then
		if snapshot.currentSellerPrice then
			table.insert(lines, `Seller price: {snapshot.currentSellerPrice} {cur}`)
		end
		if snapshot.originalAskingPrice and snapshot.originalAskingPrice ~= snapshot.currentSellerPrice then
			table.insert(lines, `Started at: {snapshot.originalAskingPrice} {cur}`)
		end
	end
	if isSell and snapshot.currentBuyerOffer then
		table.insert(lines, `Buyer offer: {snapshot.currentBuyerOffer} {cur}`)
		if snapshot.buyerInterest then
			table.insert(lines, `Buyer interest: {snapshot.buyerInterest}`)
		end
	end
	if isBuyerVisit then
		local matchCount = snapshot.inventoryMatches and #snapshot.inventoryMatches or 0
		table.insert(lines, `Shelf offers: {matchCount}`)
	end
	if snapshot.estimatedLow and snapshot.estimatedHigh and phase ~= "Result" then
		table.insert(lines, `Estimate: {snapshot.estimatedLow}-{snapshot.estimatedHigh} {cur}`)
	end
	if snapshot.trueValue then
		table.insert(lines, `TRUE VALUE: {snapshot.trueValue} {cur} ({snapshot.rarityName or "?"})`)
	end
	if snapshot.purchasePrice then
		table.insert(lines, `Paid: {snapshot.purchasePrice} {cur}`)
	end
	if snapshot.salePrice then
		table.insert(lines, `Sold: {snapshot.salePrice} {cur}`)
	end
	labels.prices.Text = if #lines > 0 then table.concat(lines, "\n") else "-"

	labels.cash.Text = `Your {cur}: {snapshot.playerCash or 0}`
	refreshInventoryLabel()

	local heat = if isSell then snapshot.buyerHeat or 0 else snapshot.sellerHeat or 0
	local heatMax = if isSell then snapshot.buyerHeatMax or 100 else snapshot.sellerHeatMax or 100
	local leverage = if isSell then snapshot.buyerLeverage else snapshot.sellerLeverage
	local confidence = if isSell then snapshot.buyerConfidence else snapshot.sellerConfidence
	local state = if isSell then snapshot.buyerState or "Open" else snapshot.sellerState or "Open"
	updateHeatBar(heat, heatMax)
	labels.heat.Text =
		`{if isSell then "Buyer" else "Seller"} heat: {heat}/{heatMax} | Lev: {statBand(leverage)} | Conf: {statBand(confidence)} | {state}`
	if snapshot.heatWarning then
		labels.heat.Text ..= ` - {snapshot.heatWarning}`
	end

	if snapshot.lastTacticResult then
		local display = TACTIC_RESULT_DISPLAY[snapshot.lastTacticResult] or snapshot.lastTacticResult
		labels.outcome.Text = `Last: {snapshot.lastTactic or "?"} -> {display}`
	else
		labels.outcome.Text = ""
	end

	if snapshot.dealSummary then
		labels.result.Text = snapshot.dealSummary.resultText or ""
	elseif isBuyerVisit then
		labels.result.Text = ""
	elseif phase == "Stored" then
		labels.result.Text = ""
	else
		labels.result.Text = ""
	end

	for index, name in { "offerSlot1", "offerSlot2", "offerSlot3" } do
		local button = buttons[name]
		local item = snapshot.inventoryMatches and snapshot.inventoryMatches[index]
		if item then
			button.Text = `{index}. {item.displayName}\n{item.matchLabel or "Curious"}`
			button.Active = tacticButtonsEnabled
			button.AutoButtonColor = tacticButtonsEnabled
			button.BackgroundTransparency = if tacticButtonsEnabled then 0 else 0.45
		else
			button.Text = `{index}. Empty`
			button.Active = false
			button.AutoButtonColor = false
			button.BackgroundTransparency = 0.45
		end
	end

	if phase == "Haggling" then
		local inspectCostLine = `Inspect ({HaggleTuning.inspectCost} {cur}) helps Point Out Flaw.`
		if snapshot.inspected then
			if snapshot.inspectClue then
				labels.inspect.Text = `Inspection: {snapshot.inspectClue}`
			elseif snapshot.inspectHint then
				labels.inspect.Text = snapshot.inspectHint
			else
				labels.inspect.Text = inspectCostLine
			end
		elseif snapshot.weakClue then
			labels.inspect.Text = `Clue: {snapshot.weakClue}\n{inspectCostLine}`
		else
			labels.inspect.Text = inspectCostLine
		end
	end

	refreshAcceptBuyButton()
end

function UIController:updateShiftSnapshot(snapshot)
	currentShiftSnapshot = snapshot or { active = false, ended = false }
	local cur = currencyLabel(currentSnapshot)

	if currentShiftSnapshot.active then
		self:closeShiftSelect()
		local phase = currentShiftSnapshot.phase or "Buying"
		local activeDealPhase = currentSnapshot and currentSnapshot.phase
		local buyerText = ""
		if currentShiftSnapshot.pendingBuyerVisit and activeDealPhase ~= "BuyerSkipped" then
			buyerText = if currentShiftSnapshot.pendingBuyerVisitKind == "rare"
				then " | Rare Walk-In waiting"
				else " | Buyer waiting"
		end
		if phase == "ClosingRush" then
			local inventoryCount = currentInventorySnapshot and currentInventorySnapshot.usedSlots or 0
			local inventoryMax = currentInventorySnapshot and currentInventorySnapshot.maxSlots or currentShiftSnapshot.inventoryMaxSlots or 3
			labels.shift.Size = UDim2.fromOffset(416, 54)
			labels.shift.Text = formatClosingRushShiftText(currentShiftSnapshot, cur, inventoryCount, inventoryMax)
		else
			local activityText = if activeDealPhase == "BuyerSkipped"
				then if currentSnapshot and currentSnapshot.rareWalkInBuyer then "Rare Walk-In Skipped" else "Buyer Visit Skipped"
				elseif activeDealPhase == "BuyerVisit" or activeDealPhase == "Selling"
				then if currentSnapshot and currentSnapshot.rareWalkInBuyer then "Rare Walk-In" else "Buyer Visit"
				else "Buying"
			labels.shift.Size = UDim2.fromOffset(416, 48)
			labels.shift.Text =
				`Shift: {currentShiftSnapshot.displayName or "?"} | Buying | {activityText}\nProfit: {formatSignedAmount(currentShiftSnapshot.shiftProfit)} / {currentShiftSnapshot.targetProfit or 0} {cur} | Sellers: {currentShiftSnapshot.dealsCompleted or 0} / {currentShiftSnapshot.sellerVisitCount or currentShiftSnapshot.dealCount or 0}{buyerText}`
		end
		refreshInventoryLabel()
		labels.shiftResult.Visible = false
	elseif currentShiftSnapshot.ended then
		labels.shift.Size = UDim2.fromOffset(416, 48)
		local grade = currentShiftSnapshot.grade or (if currentShiftSnapshot.success then "Success" else "Bust")
		local resultTitle = currentShiftSnapshot.resultTitle
			or (if currentShiftSnapshot.success then "Shift Complete" else "Shift Failed")
		labels.shift.Text =
			`Shift: {currentShiftSnapshot.displayName or "?"} | Ended\nProfit: {formatSignedAmount(currentShiftSnapshot.shiftProfit)} / {currentShiftSnapshot.targetProfit or 0} {cur} | Sellers: {currentShiftSnapshot.dealsCompleted or 0} / {currentShiftSnapshot.sellerVisitCount or currentShiftSnapshot.dealCount or 0}`
		labels.shiftResult.Text =
			`{resultTitle}\nTarget: {currentShiftSnapshot.targetProfit or 0} {cur} | Profit: {formatSignedAmount(currentShiftSnapshot.shiftProfit)} {cur}\nGrade: {grade}{formatLiquidationSummary(currentShiftSnapshot.liquidationSummary, cur)}{formatNextTrafficSummary(currentShiftSnapshot.traffic)}`
		labels.shiftResult.TextColor3 = if currentShiftSnapshot.success or grade == "Close"
			then Color3.fromRGB(145, 235, 160)
			else Color3.fromRGB(255, 170, 140)
		labels.shiftResult.Visible = true
	else
		labels.shift.Size = UDim2.fromOffset(416, 48)
		labels.shift.Text = "Choose a shift to begin."
		labels.shiftResult.Visible = false
		refreshInventoryLabel()
	end

	self:setPhaseControls(currentSnapshot and currentSnapshot.phase or "")
	refreshStashOverlay()
	refreshDealRootVisibility()
end

function UIController:updateInventorySnapshot(snapshot)
	currentInventorySnapshot = snapshot
	refreshInventoryLabel()
	self:setPhaseControls(currentSnapshot and currentSnapshot.phase or "")
	refreshStashOverlay()
	refreshAcceptBuyButton()
end

local function connectTactic(name: string, callback: () -> ())
	buttons[name].MouseButton1Click:Connect(function()
		if not tacticButtonsEnabled then
			return
		end
		callback()
	end)
end

function UIController:onBuyTactic(callback: (string) -> ())
	connectTactic("lowball", function()
		callback("lowball")
	end)
	connectTactic("split", function()
		callback("split")
	end)
	connectTactic("flaw", function()
		callback("flaw")
	end)
	connectTactic("pressure", function()
		callback("pressure")
	end)
	connectTactic("acceptBuy", function()
		callback("acceptBuy")
	end)
	connectTactic("pass", function()
		callback("pass")
	end)
end

function UIController:onSellTactic(callback: (string) -> ())
	connectTactic("smallBump", function()
		callback("smallBump")
	end)
	connectTactic("pitch", function()
		callback("pitch")
	end)
	connectTactic("holdFirm", function()
		callback("holdFirm")
	end)
	connectTactic("bluff", function()
		callback("bluff")
	end)
	connectTactic("acceptSell", function()
		callback("acceptSell")
	end)
	connectTactic("findAnother", function()
		callback("findAnother")
	end)
end

function UIController:onInspect(callback: () -> ())
	buttons.inspectBtn.MouseButton1Click:Connect(callback)
end

function UIController:onFindBuyer(callback: () -> ())
	buttons.findBuyer.MouseButton1Click:Connect(callback)
end

function UIController:onOfferInventoryItem(callback: (string) -> ())
	for index, name in { "offerSlot1", "offerSlot2", "offerSlot3" } do
		connectTactic(name, function()
			local item = currentSnapshot
				and currentSnapshot.inventoryMatches
				and currentSnapshot.inventoryMatches[index]
			if item and item.instanceId then
				callback(item.instanceId)
			end
		end)
	end
end

function UIController:onKeep(callback: () -> ())
	buttons.keep.MouseButton1Click:Connect(callback)
end

function UIController:onCloseShift(callback: () -> ())
	buttons.closeShift.MouseButton1Click:Connect(callback)
end

function UIController:onNext(callback: () -> ())
	buttons.next.MouseButton1Click:Connect(callback)
end

function UIController:Start() end

return UIController
