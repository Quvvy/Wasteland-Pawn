local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)
local WorldMarkers = require(Shared.Util.WorldMarkers)

local CameraController = require(script.Parent.CameraController)
local CounterPresentationController = require(script.Parent.CounterPresentationController)
local DebugOverlayController = require(script.Parent.DebugOverlayController)
local DisplayShelfPresentationController = require(script.Parent.DisplayShelfPresentationController)
local UIController = require(script.Parent.UIController)

local ShelfFocusController = {}

local DEBUG_SHELF_FOCUS = false
local HIGHLIGHT_NAME = "ShelfFocusSelectedHighlight"
local SCREEN_GUI_NAME = "ShelfFocusUI"
local STATION_PROMPT_NAME = "ShelfStationPrompt"
local SLOT_BUTTON_LAYER_NAME = "ShelfSlotButtonLayer"
local EMPTY_CLICK_BUTTON_NAME = "ShelfFocusEmptyClick"

local BUTTON_PADDING_X = 40
local BUTTON_PADDING_TOP = 96
local BUTTON_PADDING_BOTTOM = 14
local BUTTON_MIN_WIDTH = 120
local BUTTON_MIN_HEIGHT = 88
local BUTTON_FALLBACK_WIDTH = 210
local BUTTON_FALLBACK_HEIGHT = 130
local BUTTON_MAX_HEIGHT = 240
local DEFAULT_DISPLAY_SLOTS = 3

local BUTTON_IDLE_TRANSPARENCY = 0.92
local BUTTON_HOVER_TRANSPARENCY = 0.84
local BUTTON_SELECTED_TRANSPARENCY = 0.78

type SlotPickResult = {
	slotIndex: number,
	model: Model?,
	distancePx: number,
	pickSource: string?,
}

type ProjectedRect = {
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	centerY: number,
}

type SlotButtonState = {
	button: TextButton,
	stroke: UIStroke,
	slotIndex: number,
	instanceId: string?,
	hovered: boolean,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local focusActive = false
local selectedInstanceId: string? = nil
local selectedHighlight: Highlight? = nil
local stationPrompt: ProximityPrompt? = nil
local stationPromptBound = false
local slotButtonUpdateConnection: RBXScriptConnection? = nil

local currentDealSnapshot: any? = nil
local actionPending = false

local screenGui: ScreenGui? = nil
local slotButtonLayer: Frame? = nil
local panelFrame: Frame? = nil
local itemNameLabel: TextLabel? = nil
local itemInfoLabel: TextLabel? = nil
local inspectButton: TextButton? = nil
local storageButton: TextButton? = nil
local closeButton: TextButton? = nil

local slotButtons: { [number]: SlotButtonState } = {}
local lastPickContext: SlotPickResult? = nil
local lastLoggedSelectionKey: string? = nil

local function shortenInstanceId(instanceId: string): string
	if #instanceId <= 8 then
		return instanceId
	end
	return string.sub(instanceId, 1, 8) .. "..."
end

local function debugLog(line: string)
	DebugOverlayController:appendClientLog(line)
	if DEBUG_SHELF_FOCUS then
		warn(line)
	end
end

local function getMaxSlotCount(): number
	local snapshot = DisplayShelfPresentationController:getLastInventorySnapshot()
	if snapshot then
		return snapshot.shelfMaxSlots or snapshot.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
	end
	return DEFAULT_DISPLAY_SLOTS
end

local function getShelfItemsBySlot(): { [number]: any }
	local snapshot = DisplayShelfPresentationController:getLastInventorySnapshot()
	if not snapshot then
		return {}
	end
	return InventorySnapshot.indexShelfItemsBySlot(snapshot.shelfItems or snapshot.displayItems)
end

local function getShelfEntry(instanceId: string): any?
	local snapshot = DisplayShelfPresentationController:getLastInventorySnapshot()
	if not snapshot then
		return nil
	end
	local items = snapshot.shelfItems or snapshot.displayItems or {}
	for _, entry in items do
		if type(entry) == "table" and entry.instanceId == instanceId then
			return entry
		end
	end
	return nil
end

local function getShelfEntryForSlot(slotIndex: number): any?
	return getShelfItemsBySlot()[slotIndex]
end

local function isShelfFocusBlockedPhase(): boolean
	local phase = currentDealSnapshot and currentDealSnapshot.phase
	return phase == "Haggling" or phase == "Selling"
end

local function isBuyerVisitPhase(): boolean
	return currentDealSnapshot ~= nil and currentDealSnapshot.phase == "BuyerVisit"
end

local function isMoveToStorageBlocked(): boolean
	return isBuyerVisitPhase() or isShelfFocusBlockedPhase()
end

local function canEnterShelfFocus(): (boolean, string?)
	if isShelfFocusBlockedPhase() then
		return false, "Finish the current deal first."
	end
	return true, nil
end

local function showMessage(message: string)
	UIController:showHubMessage(message)
end

local function setActionButtonsEnabled(enabled: boolean)
	if inspectButton then
		inspectButton.Active = enabled
		inspectButton.AutoButtonColor = enabled
		inspectButton.BackgroundTransparency = if enabled then 0 else 0.45
	end
	if storageButton and enabled then
		storageButton.Active = not actionPending
		storageButton.AutoButtonColor = not actionPending
		storageButton.BackgroundTransparency = 0
	elseif storageButton then
		storageButton.Active = false
		storageButton.AutoButtonColor = false
		storageButton.BackgroundTransparency = 0.45
	end
end

local function notifySelectionDebug(logEvent: boolean)
	local entry = if selectedInstanceId then getShelfEntry(selectedInstanceId) else nil
	DebugOverlayController:updateShelfFocusDebugState({
		active = focusActive,
		selectedName = entry and entry.displayName or nil,
		instanceId = selectedInstanceId,
	})

	if not logEvent then
		return
	end

	local logKey = `{focusActive}:{selectedInstanceId or ""}`
	if logKey == lastLoggedSelectionKey then
		return
	end
	lastLoggedSelectionKey = logKey

	if selectedInstanceId and entry then
		local name = entry.displayName or "Item"
		local source = lastPickContext and lastPickContext.pickSource or "slot-button"
		local slotText = if lastPickContext then `slot {lastPickContext.slotIndex}` else "shelf"
		debugLog(`[ShelfFocus] Picked {slotText} {source} -> {name}`)
	else
		debugLog("[ShelfFocus] Cleared selection")
	end
end

local function formatInspectText(entry: any): string
	local lines = { entry.displayName or "Item" }
	if entry.category and entry.category ~= "" then
		table.insert(lines, `Category: {entry.category}`)
	end
	if entry.traits and #entry.traits > 0 then
		table.insert(lines, `Traits: {table.concat(entry.traits, ", ")}`)
	end
	if entry.purchasePrice then
		table.insert(lines, `Paid: {entry.purchasePrice} scraps`)
	end
	if entry.estimatedLow and entry.estimatedHigh then
		table.insert(lines, `Est: {entry.estimatedLow}-{entry.estimatedHigh}`)
	end
	return table.concat(lines, "\n")
end

local function formatPanelDetailText(entry: any): string
	local lines = {}
	if entry.category and entry.category ~= "" then
		table.insert(lines, `Category: {entry.category}`)
	end
	if entry.traits and #entry.traits > 0 then
		table.insert(lines, `Traits: {table.concat(entry.traits, ", ")}`)
	end
	if entry.purchasePrice then
		table.insert(lines, `Paid: {entry.purchasePrice} scraps`)
	end
	return table.concat(lines, "\n")
end

local function clearSelectionHighlight()
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
	selectedInstanceId = nil
end

local function showIdlePanel()
	if not panelFrame then
		return
	end
	panelFrame.Visible = true
	if itemNameLabel then
		itemNameLabel.Text = "No item selected"
	end
	if itemInfoLabel then
		itemInfoLabel.Text = "Click a shelf item to select it."
	end
	setActionButtonsEnabled(false)
end

local function clearSelection(skipSelectionLog: boolean?)
	local hadSelection = selectedInstanceId ~= nil
	clearSelectionHighlight()
	lastPickContext = nil
	if focusActive then
		showIdlePanel()
	end
	if hadSelection and not skipSelectionLog then
		notifySelectionDebug(true)
	else
		notifySelectionDebug(false)
	end
end

local function applySelectionHighlight(model: Model)
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) or model
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.Adornee = adornee
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.75
	highlight.OutlineTransparency = 0
	highlight.Parent = model
	selectedHighlight = highlight
end

local function updatePanelForSelection(instanceId: string)
	local entry = getShelfEntry(instanceId)
	if not entry or not panelFrame then
		showIdlePanel()
		return
	end

	selectedInstanceId = instanceId
	panelFrame.Visible = true
	if itemNameLabel then
		itemNameLabel.Text = `Selected: {entry.displayName or "Item"}`
	end
	if itemInfoLabel then
		itemInfoLabel.Text = formatPanelDetailText(entry)
	end

	if inspectButton then
		inspectButton.Active = true
		inspectButton.AutoButtonColor = true
		inspectButton.BackgroundTransparency = 0
	end

	local snapshot = DisplayShelfPresentationController:getLastInventorySnapshot()
	local storageFull = snapshot and (snapshot.stashUsedSlots or 0) >= (snapshot.stashMaxSlots or 2)
	local moveBlocked = isMoveToStorageBlocked()
	if storageButton then
		if moveBlocked then
			storageButton.Text = "Finish buyer first"
			storageButton.Active = false
			storageButton.AutoButtonColor = false
			storageButton.BackgroundTransparency = 0.45
		elseif storageFull then
			storageButton.Text = "Storage full"
			storageButton.Active = false
			storageButton.AutoButtonColor = false
			storageButton.BackgroundTransparency = 0.45
		else
			storageButton.Text = "Move to Storage"
			storageButton.Active = not actionPending
			storageButton.AutoButtonColor = not actionPending
			storageButton.BackgroundTransparency = if actionPending then 0.45 else 0
		end
	end
end

local function selectModel(model: Model, pickContext: SlotPickResult?)
	local instanceId = model:GetAttribute("InstanceId")
	if type(instanceId) ~= "string" then
		clearSelection()
		return
	end

	if selectedInstanceId == instanceId and selectedHighlight and selectedHighlight.Parent then
		return
	end

	clearSelectionHighlight()
	lastPickContext = pickContext
	applySelectionHighlight(model)
	updatePanelForSelection(instanceId)
	notifySelectionDebug(true)
end

local function selectSlot(slotIndex: number)
	local entry = getShelfEntryForSlot(slotIndex)
	if not entry or type(entry.instanceId) ~= "string" then
		clearSelection()
		return
	end

	local model = DisplayShelfPresentationController:findModelBySlotIndex(slotIndex)
	if not model or not model.Parent then
		clearSelection()
		return
	end

	if model:GetAttribute("InstanceId") ~= entry.instanceId then
		clearSelection()
		return
	end

	selectModel(model, {
		slotIndex = slotIndex,
		model = model,
		distancePx = 0,
		pickSource = "slot-button",
	})
end

local function isSelectablePart(part: BasePart): boolean
	if part.Transparency >= 0.95 then
		return false
	end
	if part.Name == "SelectionHitbox" then
		return false
	end
	if part:GetAttribute("SelectionHitbox") == true then
		return false
	end
	return true
end

local function includeProjectedPoint(camera: Camera, worldPos: Vector3, rect: ProjectedRect?): ProjectedRect?
	local point = camera:WorldToViewportPoint(worldPos)
	if point.Z <= 0 then
		return rect
	end

	if rect then
		rect.minX = math.min(rect.minX, point.X)
		rect.maxX = math.max(rect.maxX, point.X)
		rect.minY = math.min(rect.minY, point.Y)
		rect.maxY = math.max(rect.maxY, point.Y)
		rect.centerY = (rect.minY + rect.maxY) * 0.5
		return rect
	end

	return {
		minX = point.X,
		maxX = point.X,
		minY = point.Y,
		maxY = point.Y,
		centerY = point.Y,
	}
end

local function projectPart(camera: Camera, part: BasePart, rect: ProjectedRect?): ProjectedRect?
	local half = part.Size * 0.5
	for _, x in { -half.X, half.X } do
		for _, y in { -half.Y, half.Y } do
			for _, z in { -half.Z, half.Z } do
				rect = includeProjectedPoint(camera, part.CFrame:PointToWorldSpace(Vector3.new(x, y, z)), rect)
			end
		end
	end
	return rect
end

local function getModelScreenRect(model: Model, camera: Camera): ProjectedRect?
	local rect: ProjectedRect? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isSelectablePart(descendant) then
			rect = projectPart(camera, descendant, rect)
		end
	end

	if not rect then
		return nil
	end

	rect.minX -= BUTTON_PADDING_X
	rect.maxX += BUTTON_PADDING_X
	rect.minY -= BUTTON_PADDING_TOP
	rect.maxY += BUTTON_PADDING_BOTTOM

	local width = rect.maxX - rect.minX
	if width < BUTTON_MIN_WIDTH then
		local extra = (BUTTON_MIN_WIDTH - width) * 0.5
		rect.minX -= extra
		rect.maxX += extra
	end

	local height = rect.maxY - rect.minY
	if height < BUTTON_MIN_HEIGHT then
		local extra = (BUTTON_MIN_HEIGHT - height) * 0.5
		rect.minY -= extra
		rect.maxY += extra
	elseif height > BUTTON_MAX_HEIGHT then
		local center = (rect.minY + rect.maxY) * 0.5
		rect.minY = center - BUTTON_MAX_HEIGHT * 0.5
		rect.maxY = center + BUTTON_MAX_HEIGHT * 0.5
	end

	rect.centerY = (rect.minY + rect.maxY) * 0.5
	return rect
end

local function getSlotFallbackRect(slotIndex: number, camera: Camera): ProjectedRect?
	local slotPart = DisplayShelfPresentationController:getSlotParts(getMaxSlotCount())[slotIndex]
	if not slotPart then
		return nil
	end

	local worldPos = slotPart.Position + Vector3.new(0, slotPart.Size.Y * 0.5, 0)
	local point = camera:WorldToViewportPoint(worldPos)
	if point.Z <= 0 then
		return nil
	end

	return {
		minX = point.X - BUTTON_FALLBACK_WIDTH * 0.5,
		maxX = point.X + BUTTON_FALLBACK_WIDTH * 0.5,
		minY = point.Y - BUTTON_FALLBACK_HEIGHT * 0.5,
		maxY = point.Y + BUTTON_FALLBACK_HEIGHT * 0.5,
		centerY = point.Y,
	}
end

local function clampRectToViewport(rect: ProjectedRect, viewportSize: Vector2): ProjectedRect?
	rect.minX = math.clamp(rect.minX, 0, viewportSize.X)
	rect.maxX = math.clamp(rect.maxX, 0, viewportSize.X)
	rect.minY = math.clamp(rect.minY, 0, viewportSize.Y)
	rect.maxY = math.clamp(rect.maxY, 0, viewportSize.Y)

	if rect.maxX - rect.minX < 8 or rect.maxY - rect.minY < 8 then
		return nil
	end
	rect.centerY = (rect.minY + rect.maxY) * 0.5
	return rect
end

local function styleSlotButton(state: SlotButtonState)
	local selected = selectedInstanceId ~= nil and state.instanceId == selectedInstanceId
	state.button.BackgroundTransparency = if selected
		then BUTTON_SELECTED_TRANSPARENCY
		elseif state.hovered then BUTTON_HOVER_TRANSPARENCY
		else BUTTON_IDLE_TRANSPARENCY
	state.stroke.Transparency = if selected or state.hovered then 0.05 else 0.42
	state.stroke.Thickness = if selected then 3 else 2
end

local function getOrCreateSlotButton(slotIndex: number): SlotButtonState?
	if not slotButtonLayer then
		return nil
	end

	local existing = slotButtons[slotIndex]
	if existing and existing.button.Parent then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Name = `ShelfSlotButton{slotIndex}`
	button.BackgroundColor3 = Color3.fromRGB(235, 220, 180)
	button.BackgroundTransparency = BUTTON_IDLE_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.TextTransparency = 1
	button.ZIndex = 5
	button.Parent = slotButtonLayer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 244, 194)
	stroke.Thickness = 2
	stroke.Transparency = 0.42
	stroke.Parent = button

	local state: SlotButtonState = {
		button = button,
		stroke = stroke,
		slotIndex = slotIndex,
		instanceId = nil,
		hovered = false,
	}
	slotButtons[slotIndex] = state

	button.MouseEnter:Connect(function()
		state.hovered = true
		styleSlotButton(state)
	end)
	button.MouseLeave:Connect(function()
		state.hovered = false
		styleSlotButton(state)
	end)
	button.Activated:Connect(function()
		selectSlot(slotIndex)
	end)

	return state
end

local function updateSlotButtons()
	if not focusActive or not slotButtonLayer then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local itemsBySlot = getShelfItemsBySlot()
	local viewportSize = camera.ViewportSize
	local occupied = {}
	local activeSlots: { [number]: boolean } = {}

	for slotIndex = 1, getMaxSlotCount() do
		local entry = itemsBySlot[slotIndex]
		local model = DisplayShelfPresentationController:findModelBySlotIndex(slotIndex)
		if entry and type(entry.instanceId) == "string" and model and model.Parent then
			local rect = getModelScreenRect(model, camera) or getSlotFallbackRect(slotIndex, camera)
			if rect then
				table.insert(occupied, {
					slotIndex = slotIndex,
					entry = entry,
					model = model,
					rect = rect,
				})
			end
		end
	end

	table.sort(occupied, function(a, b)
		return a.rect.centerY < b.rect.centerY
	end)

	for index, item in occupied do
		local prev = occupied[index - 1]
		local nextItem = occupied[index + 1]
		if prev then
			local topBoundary = (prev.rect.centerY + item.rect.centerY) * 0.5 + 2
			item.rect.minY = math.max(item.rect.minY, topBoundary)
		end
		if nextItem then
			local bottomBoundary = (item.rect.centerY + nextItem.rect.centerY) * 0.5 - 2
			item.rect.maxY = math.min(item.rect.maxY, bottomBoundary)
		end

		local rect = clampRectToViewport(item.rect, viewportSize)
		local state = rect and getOrCreateSlotButton(item.slotIndex)
		if not rect or not state then
			continue
		end

		activeSlots[item.slotIndex] = true
		state.instanceId = item.entry.instanceId
		state.button:SetAttribute("SlotIndex", item.slotIndex)
		state.button:SetAttribute("InstanceId", item.entry.instanceId)
		state.button.Position = UDim2.fromOffset(rect.minX, rect.minY)
		state.button.Size = UDim2.fromOffset(rect.maxX - rect.minX, rect.maxY - rect.minY)
		state.button.Visible = true
		state.button.Active = true
		styleSlotButton(state)
	end

	for slotIndex, state in slotButtons do
		if not activeSlots[slotIndex] then
			state.instanceId = nil
			state.button.Visible = false
			state.button.Active = false
		end
	end

	if selectedInstanceId and not getShelfEntry(selectedInstanceId) then
		clearSelection(true)
	end
end

local function disconnectSlotButtonUpdates()
	if slotButtonUpdateConnection then
		slotButtonUpdateConnection:Disconnect()
		slotButtonUpdateConnection = nil
	end
end

local function connectSlotButtonUpdates()
	disconnectSlotButtonUpdates()
	slotButtonUpdateConnection = RunService.RenderStepped:Connect(updateSlotButtons)
	updateSlotButtons()
end

local function ensureUi()
	if screenGui and screenGui.Parent then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = SCREEN_GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = playerGui
	screenGui = gui

	local emptyButton = Instance.new("TextButton")
	emptyButton.Name = EMPTY_CLICK_BUTTON_NAME
	emptyButton.Size = UDim2.fromScale(1, 1)
	emptyButton.BackgroundTransparency = 1
	emptyButton.BorderSizePixel = 0
	emptyButton.AutoButtonColor = false
	emptyButton.Text = ""
	emptyButton.TextTransparency = 1
	emptyButton.ZIndex = 1
	emptyButton.Parent = gui

	emptyButton.Activated:Connect(function()
		if focusActive then
			clearSelection()
		end
	end)

	local buttonLayer = Instance.new("Frame")
	buttonLayer.Name = SLOT_BUTTON_LAYER_NAME
	buttonLayer.Size = UDim2.fromScale(1, 1)
	buttonLayer.BackgroundTransparency = 1
	buttonLayer.BorderSizePixel = 0
	buttonLayer.ZIndex = 4
	buttonLayer.Parent = gui
	slotButtonLayer = buttonLayer

	local panel = Instance.new("Frame")
	panel.Name = "ActionPanel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -16)
	panel.Size = UDim2.fromOffset(260, 200)
	panel.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 20
	panel.Parent = gui
	panelFrame = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "ItemName"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(235, 220, 180)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.ZIndex = 21
	title.Parent = panel
	itemNameLabel = title

	local info = Instance.new("TextLabel")
	info.Name = "ItemInfo"
	info.LayoutOrder = 2
	info.Size = UDim2.new(1, 0, 0, 72)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.Gotham
	info.TextSize = 13
	info.TextColor3 = Color3.fromRGB(200, 195, 175)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.TextWrapped = true
	info.Text = ""
	info.ZIndex = 21
	info.Parent = panel
	itemInfoLabel = info

	local function makeButton(name: string, label: string, order: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 30)
		button.BackgroundColor3 = Color3.fromRGB(70, 100, 76)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.fromRGB(240, 240, 235)
		button.Text = label
		button.ZIndex = 21
		button.Parent = panel
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = button
		return button
	end

	inspectButton = makeButton("Inspect", "Inspect", 3)
	storageButton = makeButton("MoveToStorage", "Move to Storage", 4)
	closeButton = makeButton("Close", "Close", 5)

	inspectButton.MouseButton1Click:Connect(function()
		if not selectedInstanceId then
			return
		end
		local entry = getShelfEntry(selectedInstanceId)
		if entry then
			showMessage(formatInspectText(entry))
		end
	end)

	storageButton.MouseButton1Click:Connect(function()
		if not selectedInstanceId or actionPending or isMoveToStorageBlocked() then
			return
		end
		actionPending = true
		if storageButton then
			storageButton.Active = false
		end

		local remote = Remotes.get("MoveDisplayItemToStash") :: RemoteFunction
		local instanceId = selectedInstanceId
		local ok, result = pcall(function()
			return remote:InvokeServer(instanceId)
		end)

		actionPending = false
		if storageButton then
			storageButton.Active = true
		end

		if not ok or type(result) ~= "table" or result.ok ~= true then
			local err = if ok and type(result) == "table" then result.error else nil
			showMessage(if type(err) == "string" and err ~= "" then err else "Could not move item to Storage")
			updatePanelForSelection(instanceId)
			return
		end

		clearSelection()
	end)

	closeButton.MouseButton1Click:Connect(function()
		clearSelection()
	end)
end

function ShelfFocusController:exitFocus()
	if not focusActive then
		return
	end

	focusActive = false
	disconnectSlotButtonUpdates()
	local hadSelection = selectedInstanceId ~= nil
	clearSelectionHighlight()
	lastLoggedSelectionKey = nil
	if screenGui then
		screenGui.Enabled = false
	end
	if hadSelection then
		notifySelectionDebug(true)
	else
		notifySelectionDebug(false)
	end
	CameraController:exitShelfFocusMode()
	CounterPresentationController:restoreAfterShelfFocus()
end

function ShelfFocusController:enterFocus()
	local allowed, reason = canEnterShelfFocus()
	if not allowed then
		if reason then
			showMessage(reason)
		end
		return
	end

	local shelf = DisplayShelfPresentationController:getPrimaryShelfModel()
	if not shelf then
		showMessage("Shelf not found.")
		return
	end

	local shop = WorldMarkers.getShopRoot()
	local markers = WorldMarkers.findShelfFocusMarkers(shop, shelf)
	local cameraPos = markers.cameraPosition
	local lookAtPos = markers.lookAtPosition
	if not cameraPos or not lookAtPos then
		showMessage("Shelf camera not available.")
		return
	end

	ensureUi()
	CounterPresentationController:prepareForShelfFocus()
	if not CameraController:enterShelfFocusMode(cameraPos, lookAtPos) then
		CounterPresentationController:restoreAfterShelfFocus()
		showMessage("Shelf camera not available.")
		return
	end

	focusActive = true
	if screenGui then
		screenGui.Enabled = true
	end
	showIdlePanel()
	notifySelectionDebug(false)
	connectSlotButtonUpdates()
end

local function refreshStationPrompt()
	if stationPrompt then
		stationPrompt.Enabled = true
	end
end

local function configureStationPrompt(prompt: ProximityPrompt)
	prompt.ActionText = "Inspect Shelf"
	prompt.ObjectText = "Shelf"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
end

local function clearDuplicateStationPrompts(shelf: Instance, keep: ProximityPrompt)
	for _, descendant in shelf:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == STATION_PROMPT_NAME and descendant ~= keep then
			descendant:Destroy()
		end
	end
end

local function findStationPromptOnShelf(shelf: Instance): ProximityPrompt?
	local anchor = WorldMarkers.findShelfPromptAnchor(shelf)
	if anchor then
		local onAnchor = anchor:FindFirstChild(STATION_PROMPT_NAME)
		if onAnchor and onAnchor:IsA("ProximityPrompt") then
			return onAnchor
		end
	end

	for _, descendant in shelf:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == STATION_PROMPT_NAME then
			return descendant
		end
	end

	return nil
end

local function resolveShelfModel(): Instance?
	local shelf = DisplayShelfPresentationController:getPrimaryShelfModel()
	if shelf then
		return shelf
	end

	local shop = WorldMarkers.getShopRoot()
	if not shop then
		return nil
	end
	return WorldMarkers.findPrimaryShelf(shop)
end

local function bindStationPrompt(prompt: ProximityPrompt)
	if stationPromptBound and stationPrompt == prompt then
		return
	end
	stationPromptBound = true

	prompt.Triggered:Connect(function()
		if focusActive then
			ShelfFocusController:exitFocus()
			return
		end
		ShelfFocusController:enterFocus()
	end)
end

local function ensureStationPrompt()
	local shelf = resolveShelfModel()
	if not shelf then
		return
	end

	local attachPart = WorldMarkers.findShelfPromptAnchor(shelf)
	if not attachPart then
		return
	end

	local prompt = findStationPromptOnShelf(shelf)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = STATION_PROMPT_NAME
		prompt.Parent = attachPart
	end

	clearDuplicateStationPrompts(shelf, prompt)
	configureStationPrompt(prompt)
	stationPrompt = prompt
	bindStationPrompt(prompt)
	refreshStationPrompt()
end

local function watchShelfPrompt()
	local world = Workspace:WaitForChild("World", 30)
	if not world then
		return
	end

	ensureStationPrompt()

	local debounceToken = 0
	world.DescendantAdded:Connect(function()
		debounceToken += 1
		local token = debounceToken
		task.delay(0.25, function()
			if token == debounceToken then
				ensureStationPrompt()
			end
		end)
	end)
end

local function onDealSnapshot(snapshot: any?)
	currentDealSnapshot = snapshot
	if focusActive and isShelfFocusBlockedPhase() then
		ShelfFocusController:exitFocus()
	elseif focusActive and selectedInstanceId then
		updatePanelForSelection(selectedInstanceId)
	end
end

local function shouldForceExit(): boolean
	return isShelfFocusBlockedPhase()
end

function ShelfFocusController:Init() end

function ShelfFocusController:Start()
	ensureUi()

	player.CharacterAdded:Connect(function()
		if focusActive then
			ShelfFocusController:exitFocus()
		end
	end)

	task.spawn(watchShelfPrompt)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)

	RunService.Heartbeat:Connect(function()
		if focusActive and shouldForceExit() then
			ShelfFocusController:exitFocus()
		end
	end)
end

return ShelfFocusController
