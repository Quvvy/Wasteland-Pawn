local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)
local HubWorld = require(script.Parent.HubWorld)

local DebugOverlayController = {}

local DEBUG_ENABLED = RunService:IsStudio()

local LOG_MAX_LINES = 20
local SCAN_INTERVAL = 1
local PROMPT_KEYWORDS = { "prompt", "shelf", "offer", "hold", "display", "return", "inventory" }
local LEGACY_PROMPT_NAMES = {
	ShelfOfferPrompt = true,
	ShelfHoldPrompt = true,
	ShelfDisplayPrompt = true,
}
local LOCAL_FOLDERS = {
	"HubInventoryLocal",
	"HubDisplayLocal",
	"HubItemLocal",
	"HubVisitorLocal",
	"HubPickupsLocal",
}
local OPEN_CLOSED_SIGN_NAMES = { "OpenClosedSign", "Open_Sign", "OpenClosed", "Sign" }

local ACTION_BUTTONS = {
	{ id = "GiveRandomItem", label = "Give Random Item" },
	{ id = "GiveRandomTech", label = "Give Random Tech" },
	{ id = "GiveRandomCollectible", label = "Give Random Collectible" },
	{ id = "FillInventory", label = "Fill Inventory" },
	{ id = "ClearInventory", label = "Clear Inventory" },
	{ id = "GiveRandomDisplayItem", label = "Give Random Display Item" },
	{ id = "ForceBuyerVisit", label = "Force Buyer Visit" },
	{ id = "SkipToClosingRush", label = "Skip To Closing Rush" },
	{ id = "EndShift", label = "End Shift" },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local rootFrame: Frame? = nil
local contentLabel: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil
local actionButtons: { TextButton } = {}

local overlayVisible = false
local actionPending = false
local scanTaskToken = 0
local isDragging = false
local dragStartMouse: Vector2? = nil
local dragStartPos: UDim2? = nil

local lastShiftSnapshot: any? = nil
local lastDealSnapshot: any? = nil
local lastInventorySnapshot: any? = nil
local lastShiftUpdateAt: number? = nil
local lastDealUpdateAt: number? = nil
local lastInventoryUpdateAt: number? = nil
local remoteLog: { string } = {}
local worldScanCache: any? = nil
local promptScanCache: any? = nil

local function showHubMessage(message: string)
	local uiOk, UIController = pcall(require, script.Parent.UIController)
	if uiOk then
		UIController:showHubMessage(message)
	else
		warn(message)
	end
end

local function formatTime(clockTime: number?): string
	if not clockTime then
		return "-"
	end
	return os.date("%H:%M:%S", clockTime)
end

local function formatTraits(traits): string
	if traits and #traits > 0 then
		return table.concat(traits, ", ")
	end
	return "-"
end

local function appendLog(line: string)
	table.insert(remoteLog, line)
	while #remoteLog > LOG_MAX_LINES do
		table.remove(remoteLog, 1)
	end
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function appendActionLog(actionId: string, result: any)
	if type(result) == "table" and result.ok == true then
		local message = if type(result.message) == "string" then result.message else "OK"
		appendLog(`[ACTION] {actionId}: {message}`)
		showHubMessage(message)
	elseif type(result) == "table" then
		local errorText = if type(result.error) == "string" then result.error else "Failed"
		appendLog(`[ACTION FAILED] {actionId}: {errorText}`)
		showHubMessage(`{actionId}: {errorText}`)
	else
		appendLog(`[ACTION FAILED] {actionId}: Remote error`)
		showHubMessage(`{actionId}: Remote error`)
	end
end

local function field(value: any): string
	if value == nil then
		return "-"
	end
	if type(value) == "boolean" then
		return if value then "true" else "false"
	end
	return tostring(value)
end

local function formatExpectedInteraction(phase: string?): string
	if phase == "BuyerVisit" then
		return "BuyerVisit: InventoryShelf prompts should say Offer <Item>. DisplayShelf: Return to Shelf."
	elseif phase == "Selling" then
		return "Selling: selected item hidden from InventoryShelf and visible on counter."
	elseif phase == "Haggling" then
		return "Haggling: buy from seller at counter. No shelf offer/hold prompts for negotiation item."
	elseif phase == "WalkedAway" or phase == "Result" or phase == "Stored" or phase == "BuyerSkipped" then
		return "Terminal: click Next Customer to continue (no auto-advance)."
	elseif phase == nil or phase == "" then
		return "No deal: InventoryShelf prompts should say Hold Back when shift is active."
	end
	return `Phase {phase}: use normal gameplay controls.`
end

local function formatShiftSection(): string
	local snapshot = lastShiftSnapshot
	local deal = lastDealSnapshot
	local lines = {
		"=== SHIFT ===",
		`active: {field(snapshot and snapshot.active)}`,
		`ended: {field(snapshot and snapshot.ended)}`,
		`phase: {field(snapshot and snapshot.phase)}`,
		`shiftId: {field(snapshot and snapshot.shiftId)}`,
		`displayName: {field(snapshot and snapshot.displayName)}`,
		`playerCash: {field(deal and deal.playerCash)}`,
		`dealsCompleted: {field(snapshot and (snapshot.dealsCompleted or snapshot.sellerVisitsResolved))}`,
		`dealsRemaining: {field(snapshot and snapshot.dealsRemaining)}`,
		`pendingBuyerVisit: {field(snapshot and snapshot.pendingBuyerVisit)}`,
		`closingRushBuyersRemaining: {field(snapshot and snapshot.closingRushBuyersRemaining)}`,
		`closingRushBuyersSeen: {field(snapshot and snapshot.closingRushBuyersSeen)}`,
		`last ShiftStateUpdate: {formatTime(lastShiftUpdateAt)}`,
	}
	return table.concat(lines, "\n")
end

local function formatDealSection(): string
	local snapshot = lastDealSnapshot
	local lines = {
		"=== DEAL ===",
		`phase: {field(snapshot and snapshot.phase)}`,
		`customer: {field(snapshot and (snapshot.customerName or snapshot.customerId))}`,
		`buyer: {field(snapshot and (snapshot.buyerName or snapshot.buyerId))}`,
		`item: {field(snapshot and (snapshot.itemName or snapshot.itemId))}`,
		`instanceId: {field(snapshot and snapshot.instanceId)}`,
		`category: {field(snapshot and snapshot.category)}`,
		`traits: {formatTraits(snapshot and snapshot.traits)}`,
		`buyerInterest: {field(snapshot and snapshot.buyerInterest)}`,
		`buyerMatchLabel: {field(snapshot and snapshot.buyerMatchLabel)}`,
		`displayInfluenceLabel: {field(snapshot and snapshot.displayInfluenceLabel)}`,
		`displayInfluenceBuyerId: {field(snapshot and snapshot.displayInfluenceBuyerId)}`,
		`last DealStateUpdate: {formatTime(lastDealUpdateAt)}`,
	}
	return table.concat(lines, "\n")
end

local function formatInventorySection(): string
	local snapshot = lastInventorySnapshot
	local lines = {
		"=== INVENTORY (working stock) ===",
		`usedSlots / maxSlots: {field(snapshot and snapshot.usedSlots)} / {field(snapshot and snapshot.maxSlots)}`,
	}

	local items = snapshot and snapshot.items or {}
	if #items == 0 then
		table.insert(lines, "(empty)")
	else
		for index, entry in ipairs(items) do
			table.insert(lines, `# {index} | {entry.instanceId} | {entry.itemId} | {entry.displayName}`)
			table.insert(lines, `  category={entry.category} location={entry.location} heldBack={field(entry.heldBack)}`)
			table.insert(lines, `  traits={formatTraits(entry.traits)} purchasePrice={field(entry.purchasePrice)}`)
		end
	end

	return table.concat(lines, "\n")
end

local function formatDisplaySection(): string
	local snapshot = lastInventorySnapshot
	local lines = {
		"=== DISPLAY ===",
		`displayUsedSlots / displayMaxSlots: {field(snapshot and snapshot.displayUsedSlots)} / {field(snapshot and snapshot.displayMaxSlots)}`,
		`displayAppealSummary: {field(snapshot and snapshot.displayAppealSummary)}`,
		"Note: display items do NOT count toward inventory usedSlots.",
	}

	local displayMax = snapshot and snapshot.displayMaxSlots or 3
	local displayItems = InventorySnapshot.indexDisplayItemsBySlot(snapshot and snapshot.displayItems)
	for slotIndex = 1, displayMax do
		local entry = displayItems[slotIndex]
		if entry then
			table.insert(lines, `D{slotIndex} | {entry.instanceId} | {entry.itemId} | {entry.displayName}`)
			table.insert(lines, `  category={entry.category} location={entry.location} heldBack={field(entry.heldBack)}`)
			table.insert(lines, `  traits={formatTraits(entry.traits)}`)
		else
			table.insert(lines, `D{slotIndex}: Empty`)
		end
	end

	return table.concat(lines, "\n")
end

local function findOpenClosedSign(shop: Instance?): Instance?
	if not shop then
		return nil
	end
	return HubWorld.findChildByNames(shop, OPEN_CLOSED_SIGN_NAMES)
		or HubWorld.findShopPart(shop, OPEN_CLOSED_SIGN_NAMES, "openclosedsign")
end

function DebugOverlayController:scanWorld()
	local world = Workspace:FindFirstChild("World")
	local shop = world and world:FindFirstChild("Shop")
	local inventoryShelf = HubWorld.findInventoryShelf(shop)
	local displayShelf = HubWorld.findDisplayShelf(shop)

	local scan = {
		world = world ~= nil,
		shop = shop ~= nil,
		inventoryShelf = inventoryShelf ~= nil,
		inventorySlots = {},
		displayShelf = displayShelf ~= nil,
		displaySlots = {},
		counterItemSpot = HubWorld.findCounterItemSpot(shop) ~= nil,
		customerSpot = HubWorld.findCustomerSpot(shop) ~= nil,
		openClosedSign = findOpenClosedSign(shop) ~= nil,
		localFolders = {},
	}

	for slotIndex = 1, 3 do
		scan.inventorySlots[slotIndex] = HubWorld.findInventorySlot(inventoryShelf, slotIndex) ~= nil
		scan.displaySlots[slotIndex] = HubWorld.findDisplayShelfSlot(displayShelf, slotIndex) ~= nil
	end

	if world then
		for _, folderName in LOCAL_FOLDERS do
			local folder = world:FindFirstChild(folderName)
			scan.localFolders[folderName] = {
				found = folder ~= nil,
				childCount = if folder then #folder:GetChildren() else 0,
			}
		end
	end

	worldScanCache = scan
	return scan
end

local function promptNameMatches(name: string): boolean
	local lower = string.lower(name)
	for _, keyword in PROMPT_KEYWORDS do
		if string.find(lower, keyword, 1, true) then
			return true
		end
	end
	return false
end

function DebugOverlayController:scanPrompts()
	local world = Workspace:FindFirstChild("World")
	local prompts = {}
	local legacyCounts = {
		ShelfOfferPrompt = 0,
		ShelfHoldPrompt = 0,
		ShelfDisplayPrompt = 0,
	}

	if world then
		for _, descendant in world:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				if LEGACY_PROMPT_NAMES[descendant.Name] then
					legacyCounts[descendant.Name] += 1
				end
				if promptNameMatches(descendant.Name) or LEGACY_PROMPT_NAMES[descendant.Name] then
					table.insert(prompts, {
						name = descendant.Name,
						actionText = descendant.ActionText,
						objectText = descendant.ObjectText,
						enabled = descendant.Enabled,
						parentPath = descendant.Parent and descendant.Parent:GetFullName() or "?",
						maxDistance = descendant.MaxActivationDistance,
						promptMode = descendant:GetAttribute("PromptMode"),
						instanceId = descendant:GetAttribute("InstanceId"),
					})
				end
			end
		end
	end

	table.sort(prompts, function(a, b)
		return a.parentPath < b.parentPath
	end)

	promptScanCache = {
		prompts = prompts,
		legacyCounts = legacyCounts,
	}
	return promptScanCache
end

local function formatWorldSection(scan: any): string
	if not scan then
		return "=== WORLD ===\n(not scanned)"
	end

	local function status(found: boolean): string
		return if found then "OK" else "MISSING"
	end

	local lines = {
		"=== WORLD ===",
		`Workspace.World: {status(scan.world)}`,
		`Workspace.World.Shop: {status(scan.shop)}`,
		`InventoryShelf: {status(scan.inventoryShelf)}`,
		`InventorySlot1: {status(scan.inventorySlots[1])}`,
		`InventorySlot2: {status(scan.inventorySlots[2])}`,
		`InventorySlot3: {status(scan.inventorySlots[3])}`,
		`DisplayShelf: {status(scan.displayShelf)}`,
		`DisplaySlot1: {status(scan.displaySlots[1])}`,
		`DisplaySlot2: {status(scan.displaySlots[2])}`,
		`DisplaySlot3: {status(scan.displaySlots[3])}`,
		`CounterItemSpot: {status(scan.counterItemSpot)}`,
		`CustomerSpot: {status(scan.customerSpot)}`,
		`OpenClosedSign: {status(scan.openClosedSign)}`,
	}

	for _, folderName in LOCAL_FOLDERS do
		local folderInfo = scan.localFolders[folderName]
		if folderInfo and folderInfo.found then
			table.insert(lines, `{folderName}: OK ({folderInfo.childCount} children)`)
		else
			table.insert(lines, `{folderName}: MISSING`)
		end
	end

	return table.concat(lines, "\n")
end

local function formatPromptSection(scan: any): string
	if not scan then
		return "=== PROMPTS ===\n(not scanned)"
	end

	local legacy = scan.legacyCounts
	local lines = {
		"=== PROMPTS ===",
		`count={#scan.prompts} | legacy: ShelfOfferPrompt={legacy.ShelfOfferPrompt} ShelfHoldPrompt={legacy.ShelfHoldPrompt} ShelfDisplayPrompt={legacy.ShelfDisplayPrompt}`,
	}

	for _, prompt in scan.prompts do
		local modeText = if prompt.promptMode then ` PromptMode={prompt.promptMode}` else ""
		local instanceText = if prompt.instanceId then ` InstanceId={prompt.instanceId}` else ""
		table.insert(lines, `- {prompt.name} | {prompt.actionText} | enabled={field(prompt.enabled)}`)
		table.insert(lines, `  object={prompt.objectText} dist={prompt.maxDistance}{modeText}{instanceText}`)
		table.insert(lines, `  parent={prompt.parentPath}`)
	end

	if #scan.prompts == 0 then
		table.insert(lines, "(no matching prompts)")
	end

	return table.concat(lines, "\n")
end

local function formatRemoteLogSection(): string
	local lines = { "=== REMOTE LOG ===" }
	if #remoteLog == 0 then
		table.insert(lines, "(empty)")
	else
		for _, line in remoteLog do
			table.insert(lines, line)
		end
	end
	return table.concat(lines, "\n")
end

function DebugOverlayController:rebuildText()
	if not contentLabel then
		return
	end

	local phase = lastDealSnapshot and lastDealSnapshot.phase
	local sections = {
		"=== EXPECTED INTERACTION ===",
		formatExpectedInteraction(phase),
		"",
		formatShiftSection(),
		"",
		formatDealSection(),
		"",
		formatInventorySection(),
		"",
		formatDisplaySection(),
		"",
		formatWorldSection(worldScanCache),
		"",
		formatPromptSection(promptScanCache),
		"",
		formatRemoteLogSection(),
	}

	contentLabel.Text = table.concat(sections, "\n")
	if scrollFrame and contentLabel then
		scrollFrame.CanvasSize = UDim2.fromOffset(0, contentLabel.TextBounds.Y + 16)
	end
end

local function setActionButtonsEnabled(enabled: boolean)
	for _, button in actionButtons do
		button.Active = enabled
		button.AutoButtonColor = enabled
	end
end

function DebugOverlayController:runDebugAction(actionId: string)
	if actionPending or not DEBUG_ENABLED then
		return
	end

	actionPending = true
	setActionButtonsEnabled(false)

	local remote = Remotes.get("DebugRunAction") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(actionId)
	end)

	actionPending = false
	setActionButtonsEnabled(true)

	if not ok then
		appendActionLog(actionId, { ok = false, error = tostring(result) })
		return
	end

	appendActionLog(actionId, result)
	self:rebuildText()
end

local function stopScanLoop()
	scanTaskToken += 1
end

local function startScanLoop()
	stopScanLoop()
	local token = scanTaskToken
	task.spawn(function()
		while overlayVisible and token == scanTaskToken do
			task.wait(SCAN_INTERVAL)
			if overlayVisible and token == scanTaskToken then
				DebugOverlayController:scanWorld()
				DebugOverlayController:scanPrompts()
				DebugOverlayController:rebuildText()
			end
		end
	end)
end

function DebugOverlayController:setVisible(visible: boolean)
	if not screenGui then
		return
	end

	overlayVisible = visible
	screenGui.Enabled = visible

	if visible then
		self:scanWorld()
		self:scanPrompts()
		self:rebuildText()
		startScanLoop()
	else
		stopScanLoop()
	end
end

function DebugOverlayController:toggleVisible()
	self:setVisible(not overlayVisible)
end

local function bindDragHandle(root: Frame, dragHandle: GuiObject)
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		isDragging = true
		dragStartMouse = input.Position
		dragStartPos = root.Position
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not isDragging or not dragStartMouse or not dragStartPos or not rootFrame then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStartMouse
		rootFrame.Position = UDim2.new(
			dragStartPos.X.Scale,
			dragStartPos.X.Offset + delta.X,
			dragStartPos.Y.Scale,
			dragStartPos.Y.Offset + delta.Y
		)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		isDragging = false
		dragStartMouse = nil
		dragStartPos = nil
	end)
end

local function buildOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WastelandPawnDebug"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.fromOffset(12, 12)
	root.Size = UDim2.new(0.55, 0, 0.78, 0)
	root.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Parent = gui

	local dragHandle = Instance.new("TextButton")
	dragHandle.Name = "DragHandle"
	dragHandle.AutoButtonColor = false
	dragHandle.Text = ""
	dragHandle.Position = UDim2.fromOffset(0, 0)
	dragHandle.Size = UDim2.new(1, -84, 0, 32)
	dragHandle.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	dragHandle.BackgroundTransparency = 0.35
	dragHandle.BorderSizePixel = 0
	dragHandle.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -96, 0, 24)
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(230, 230, 230)
	title.Text = "Wasteland Pawn Debug"
	title.Parent = root

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Position = UDim2.new(1, -84, 0, 6)
	closeButton.Size = UDim2.fromOffset(72, 28)
	closeButton.Font = Enum.Font.Code
	closeButton.TextSize = 14
	closeButton.Text = "Close"
	closeButton.Parent = root

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "ButtonRow"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Position = UDim2.fromOffset(8, 36)
	buttonRow.Size = UDim2.new(1, -16, 0, 30)
	buttonRow.Parent = root

	local function makeTopButton(name: string, text: string, x: number)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 0)
		button.Size = UDim2.fromOffset(120, 28)
		button.Font = Enum.Font.Code
		button.TextSize = 12
		button.Text = text
		button.Parent = buttonRow
		return button
	end

	local refreshButton = makeTopButton("Refresh", "Refresh", 0)
	local clearLogButton = makeTopButton("ClearLog", "Clear Log", 126)
	local printButton = makeTopButton("PrintDebug", "Print Debug Text", 252)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ContentScroll"
	scroll.Position = UDim2.fromOffset(8, 72)
	scroll.Size = UDim2.new(1, -16, 1, -170)
	scroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	scroll.BackgroundTransparency = 0.2
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "Content"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(8, 8)
	label.Size = UDim2.new(1, -16, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextWrapped = true
	label.Text = ""
	label.Parent = scroll

	local actionsLabel = Instance.new("TextLabel")
	actionsLabel.Name = "ActionsTitle"
	actionsLabel.BackgroundTransparency = 1
	actionsLabel.AnchorPoint = Vector2.new(0, 1)
	actionsLabel.Position = UDim2.new(0, 8, 1, -92)
	actionsLabel.Size = UDim2.new(1, -16, 0, 18)
	actionsLabel.Font = Enum.Font.Code
	actionsLabel.TextSize = 13
	actionsLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	actionsLabel.Text = "=== DEV ACTIONS ==="
	actionsLabel.Parent = root

	local actionsFrame = Instance.new("Frame")
	actionsFrame.Name = "Actions"
	actionsFrame.BackgroundTransparency = 1
	actionsFrame.AnchorPoint = Vector2.new(0, 1)
	actionsFrame.Position = UDim2.new(0, 8, 1, -8)
	actionsFrame.Size = UDim2.new(1, -16, 0, 80)
	actionsFrame.Parent = root

	local x = 0
	local y = 0
	for index, action in ACTION_BUTTONS do
		local button = Instance.new("TextButton")
		button.Name = action.id
		button.Position = UDim2.fromOffset(x, y)
		button.Size = UDim2.fromOffset(168, 24)
		button.Font = Enum.Font.Code
		button.TextSize = 11
		button.Text = action.label
		button.Parent = actionsFrame
		table.insert(actionButtons, button)

		local actionId = action.id
		button.MouseButton1Click:Connect(function()
			DebugOverlayController:runDebugAction(actionId)
		end)

		x += 174
		if index % 3 == 0 then
			x = 0
			y += 28
		end
	end

	closeButton.MouseButton1Click:Connect(function()
		DebugOverlayController:setVisible(false)
	end)

	refreshButton.MouseButton1Click:Connect(function()
		DebugOverlayController:scanWorld()
		DebugOverlayController:scanPrompts()
		DebugOverlayController:rebuildText()
	end)

	clearLogButton.MouseButton1Click:Connect(function()
		table.clear(remoteLog)
		DebugOverlayController:rebuildText()
	end)

	printButton.MouseButton1Click:Connect(function()
		if contentLabel then
			print(contentLabel.Text)
		end
	end)

	screenGui = gui
	rootFrame = root
	scrollFrame = scroll
	contentLabel = label
	bindDragHandle(root, dragHandle)
end

local function onShiftSnapshot(snapshot: any?)
	lastShiftSnapshot = snapshot
	lastShiftUpdateAt = os.time()
	appendLog(`[{formatTime(lastShiftUpdateAt)}] ShiftStateUpdate: active={field(snapshot and snapshot.active)} phase={field(snapshot and snapshot.phase)}`)
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function onDealSnapshot(snapshot: any?)
	lastDealSnapshot = snapshot
	lastDealUpdateAt = os.time()
	if snapshot and snapshot.inventory then
		lastInventorySnapshot = snapshot.inventory
		lastInventoryUpdateAt = lastDealUpdateAt
	end
	if snapshot and snapshot.shift then
		lastShiftSnapshot = snapshot.shift
		lastShiftUpdateAt = lastDealUpdateAt
	end
	appendLog(`[{formatTime(lastDealUpdateAt)}] DealStateUpdate: {field(snapshot and snapshot.phase)}`)
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function onInventorySnapshot(snapshot: any?)
	lastInventorySnapshot = snapshot
	lastInventoryUpdateAt = os.time()
	local used = snapshot and snapshot.usedSlots or 0
	local displayUsed = snapshot and snapshot.displayUsedSlots or 0
	appendLog(`[{formatTime(lastInventoryUpdateAt)}] InventoryStateUpdate: items={used} display={displayUsed}`)
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function isCtrlDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

function DebugOverlayController:Init()
	if not DEBUG_ENABLED then
		return
	end
	buildOverlay()
end

function DebugOverlayController:Start()
	if not DEBUG_ENABLED then
		return
	end

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(onInventorySnapshot)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape and overlayVisible then
			self:setVisible(false)
			return
		end

		if input.KeyCode == Enum.KeyCode.U and isCtrlDown() then
			self:toggleVisible()
		end
	end)
end

return DebugOverlayController
