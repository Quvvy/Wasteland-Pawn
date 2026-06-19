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
local PROMPT_KEYWORDS = { "prompt", "shelf", "offer", "hold", "display", "return", "inventory", "stash" }
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
	{ id = "ClearDisplay", label = "Clear Display" },
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
local lastLoggedPhase: string? = nil
local lastLoggedTacticDebug: string? = nil
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

local function formatListField(value: any): string
	if type(value) ~= "table" or #value == 0 then
		return "-"
	end
	return table.concat(value, ", ")
end

local function formatInfluenceBonus(bonus: any): string
	if type(bonus) ~= "number" then
		return "n/a"
	end
	local percent = math.floor(bonus * 100 + 0.5)
	if percent <= 0 then
		return "0% (no display match)"
	end
	return `+{percent}% roll weight`
end

local function isBuyerFacingPhase(phase: string?): boolean
	return phase == "BuyerVisit" or phase == "Selling" or phase == "BuyerSkipped"
end

local TERMINAL_DEAL_PHASES = {
	WalkedAway = true,
	Result = true,
	Stored = true,
	BuyerSkipped = true,
}

local function formatDealStartLog(snapshot: any): string
	if not snapshot then
		return ""
	end
	return `DEAL START | archetype={field(snapshot.dealArchetypeId)} | {field(snapshot.customerName)} | {field(snapshot.itemName)} | ask={field(snapshot.debugOriginalAsk or snapshot.currentSellerPrice)} min={field(snapshot.debugMinimumAccept or snapshot.minimumAccept)} true={field(snapshot.debugTrueValue or snapshot.trueValue)} tell="{field(snapshot.sellerTell)}"`
end

local function formatDealDoneLog(snapshot: any): string
	if not snapshot or not snapshot.dealSummary then
		return ""
	end
	local s = snapshot.dealSummary
	return `DEAL DONE | archetype={field(s.dealArchetypeId or snapshot.dealArchetypeId)} | true={field(s.trueValue)} ask={field(s.sellerAsk)} min={field(s.sellerMinimum)} bought={field(s.purchasePrice)} buyer={field(s.buyerId)} open={field(s.buyerOpeningOffer)} max={field(s.buyerMaximum)} sold={field(s.salePrice or "kept")} profit={field(s.totalProfit or s.profit)} inspected={field(s.inspected)} tactics={field(s.tacticsUsed)} sellerTell="{field(snapshot.sellerTell)}" buyerTell="{field(snapshot.buyerTell)}" heat={field(snapshot.sellerHeat)}/{field(snapshot.buyerHeat)}`
end

local function logDealSnapshotEvents(snapshot: any?)
	if not snapshot then
		lastLoggedPhase = nil
		lastLoggedTacticDebug = nil
		return
	end

	local phase = snapshot.phase
	if phase == "Haggling" and lastLoggedPhase ~= "Haggling" then
		appendLog(formatDealStartLog(snapshot))
	end

	if phase == "BuyerVisit" and lastLoggedPhase ~= "BuyerVisit" then
		appendLog(
			`BUYER VISIT | {field(snapshot.buyerName)} | display influence: {formatInfluenceBonus(snapshot.displayInfluenceBonus)}`
		)
	end

	if TERMINAL_DEAL_PHASES[phase] and lastLoggedPhase ~= phase then
		local doneLine = formatDealDoneLog(snapshot)
		if doneLine ~= "" then
			appendLog(doneLine)
		end
	end

	local tacticLine = snapshot.lastTacticDebug
	if type(tacticLine) == "string" and tacticLine ~= "" and tacticLine ~= lastLoggedTacticDebug then
		appendLog(tacticLine)
		lastLoggedTacticDebug = tacticLine
	end

	lastLoggedPhase = phase
end

local function formatExpectedInteraction(phase: string?): string
	if phase == "BuyerVisit" then
		return "Offer from inventory shelf. Display items cannot be offered."
	elseif phase == "Selling" then
		return "Sell tactics on counter item."
	elseif phase == "Haggling" then
		return "Buy from seller at counter."
	elseif phase == "WalkedAway" or phase == "Result" or phase == "Stored" or phase == "BuyerSkipped" then
		return "Terminal — click Next Customer."
	elseif phase == nil or phase == "" then
		return "No deal — Hold Back on inventory shelf when shift is active."
	end
	return `Phase {phase}.`
end

local function formatShiftSection(): string
	local snapshot = lastShiftSnapshot
	local deal = lastDealSnapshot
	if not snapshot then
		return "=== SHIFT ===\n(no data)"
	end

	local name = snapshot.displayName or snapshot.shiftId or "?"
	local phase = snapshot.phase or "?"
	local profit = `{field(snapshot.shiftProfit)}/{field(snapshot.targetProfit)}`
	local sellers = `{field(snapshot.dealsCompleted or snapshot.sellerVisitsResolved)}/{field(snapshot.sellerVisitCount or snapshot.dealCount)}`
	local buyerFlag = if snapshot.pendingBuyerVisit then " | buyer waiting" else ""

	local lines = {
		"=== SHIFT ===",
		`{name} | {phase} | profit {profit} | sellers {sellers}{buyerFlag}`,
		`cash: {field(deal and deal.playerCash)} | remaining sellers: {field(snapshot.dealsRemaining)}`,
	}

	if snapshot.phase == "ClosingRush" then
		table.insert(lines, `closing rush buyers: {field(snapshot.closingRushBuyersRemaining)}`)
	end
	if snapshot.ended then
		table.insert(lines, `ended: {field(snapshot.grade)} — {field(snapshot.resultTitle)}`)
	end

	return table.concat(lines, "\n")
end

local function formatDealSection(): string
	local snapshot = lastDealSnapshot
	if not snapshot then
		return "=== DEAL ===\n(no active deal)"
	end

	local phase = snapshot.phase or "?"
	local lines = {
		"=== DEAL ===",
		`phase: {phase}`,
	}

	if phase == "Haggling" then
		table.insert(lines, `archetype: {field(snapshot.dealArchetypeId)} ({field(snapshot.dealArchetypeName)})`)
		table.insert(lines, `seller: {field(snapshot.customerName)} | item: {field(snapshot.itemName)} ({field(snapshot.category)})`)
		table.insert(
			lines,
			`ask {field(snapshot.debugOriginalAsk or snapshot.currentSellerPrice)} | min {field(snapshot.debugMinimumAccept or snapshot.minimumAccept)} | true {field(snapshot.debugTrueValue or snapshot.trueValue)}`
		)
		table.insert(
			lines,
			`seller heat {field(snapshot.sellerHeat)}/{field(snapshot.sellerHeatMax)} | {field(snapshot.lastTactic)} -> {field(snapshot.lastTacticResult)}`
		)
	elseif isBuyerFacingPhase(phase) then
		table.insert(lines, `buyer: {field(snapshot.buyerName)} ({field(snapshot.buyerId)})`)
		table.insert(lines, `display influence: {formatInfluenceBonus(snapshot.displayInfluenceBonus)}`)
		local matchedCats = formatListField(snapshot.displayInfluenceMatchedCategories)
		local matchedTraits = formatListField(snapshot.displayInfluenceMatchedTraits)
		if matchedCats ~= "-" then
			table.insert(lines, `  matched categories: {matchedCats}`)
		end
		if matchedTraits ~= "-" then
			table.insert(lines, `  matched traits: {matchedTraits}`)
		end
		if snapshot.displayInfluenceLabel then
			table.insert(lines, `  note: {snapshot.displayInfluenceLabel}`)
		end
		if phase == "BuyerVisit" then
			table.insert(lines, `buyer wants: {field(snapshot.buyerWants)}`)
			local matchCount = snapshot.inventoryMatches and #snapshot.inventoryMatches or 0
			table.insert(lines, `inventory offers available: {matchCount}`)
		elseif phase == "Selling" then
			table.insert(
				lines,
				`item: {field(snapshot.itemName)} | offer {field(snapshot.currentBuyerOffer)} / max {field(snapshot.buyerMaximum)}`
			)
			table.insert(
				lines,
				`buyer heat {field(snapshot.buyerHeat)}/{field(snapshot.buyerHeatMax)} | match: {field(snapshot.buyerMatchLabel)}`
			)
		end
	else
		table.insert(lines, `customer: {field(snapshot.customerName)} | buyer: {field(snapshot.buyerName)}`)
		table.insert(lines, `item: {field(snapshot.itemName)}`)
		local summary = snapshot.dealSummary
		if summary then
			table.insert(
				lines,
				`result: {field(summary.resultReason)} | profit {field(summary.totalProfit or summary.profit)}`
			)
		end
	end

	if snapshot.lastTacticDebug and snapshot.lastTacticDebug ~= "" then
		table.insert(lines, `last tactic debug: {snapshot.lastTacticDebug}`)
	end

	return table.concat(lines, "\n")
end

local function formatInventorySection(): string
	local snapshot = lastInventorySnapshot
	if not snapshot then
		return "=== INVENTORY ===\n(no data)"
	end

	local lines = {
		"=== INVENTORY ===",
		`stock: {field(snapshot.usedSlots)}/{field(snapshot.maxSlots)}`,
	}

	local items = snapshot.items or {}
	if #items == 0 then
		table.insert(lines, "(empty)")
	else
		for index, entry in ipairs(items) do
			local held = if entry.heldBack then " [held]" else ""
			table.insert(lines, `{index}. {entry.displayName} ({entry.category}) — paid {field(entry.purchasePrice)}{held}`)
		end
	end

	table.insert(lines, `stash: {field(snapshot.stashUsedSlots)}/{field(snapshot.stashMaxSlots)}`)
	local stashItems = snapshot.stashItems or {}
	if #stashItems == 0 then
		table.insert(lines, "stash empty")
	else
		for index, entry in ipairs(stashItems) do
			table.insert(lines, `S{index}. {entry.displayName} ({entry.category}) - paid {field(entry.purchasePrice)}`)
		end
	end

	return table.concat(lines, "\n")
end

local function formatDisplaySection(): string
	local inv = lastInventorySnapshot
	local deal = lastDealSnapshot
	if not inv then
		return "=== DISPLAY ===\n(no data)"
	end

	local lines = {
		"=== DISPLAY ===",
		`shelf: {field(inv.displayUsedSlots)}/{field(inv.displayMaxSlots)} | appeal: {field(inv.displayAppealSummary)}`,
	}

	local displayMax = inv.displayMaxSlots or 3
	local displayItems = InventorySnapshot.indexDisplayItemsBySlot(inv.displayItems)
	local anyItem = false
	for slotIndex = 1, displayMax do
		local entry = displayItems[slotIndex]
		if entry then
			anyItem = true
			table.insert(lines, `D{slotIndex}. {entry.displayName} ({entry.category})`)
		end
	end
	if not anyItem then
		table.insert(lines, "(empty)")
	end

	if deal and isBuyerFacingPhase(deal.phase) then
		table.insert(lines, `buyer influence this visit: {formatInfluenceBonus(deal.displayInfluenceBonus)}`)
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
	local stashBin = HubWorld.findStashBin(shop)

	local scan = {
		world = world ~= nil,
		shop = shop ~= nil,
		inventoryShelf = inventoryShelf ~= nil,
		inventorySlots = {},
		displayShelf = displayShelf ~= nil,
		displaySlots = {},
		stashBin = stashBin ~= nil,
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
		return "=== WORLD ===\n(click Refresh)"
	end

	local function status(found: boolean): string
		return if found then "OK" else "MISSING"
	end

	local problems = {}
	local function check(label: string, found: boolean)
		if not found then
			table.insert(problems, label)
		end
	end

	check("World", scan.world)
	check("Shop", scan.shop)
	check("InventoryShelf", scan.inventoryShelf)
	check("DisplayShelf", scan.displayShelf)
	check("StashBin", scan.stashBin)
	check("CounterItemSpot", scan.counterItemSpot)
	check("CustomerSpot", scan.customerSpot)

	for slotIndex = 1, 3 do
		check(`InventorySlot{slotIndex}`, scan.inventorySlots[slotIndex])
		check(`DisplaySlot{slotIndex}`, scan.displaySlots[slotIndex])
	end

	if #problems > 0 then
		return `=== WORLD ===\nMISSING: {table.concat(problems, ", ")}`
	end

	return "=== WORLD ===\nAll core parts OK"
end

local function formatPromptSection(scan: any): string
	if not scan then
		return "=== PROMPTS ===\n(click Refresh)"
	end

	local legacy = scan.legacyCounts
	local legacyTotal = legacy.ShelfOfferPrompt + legacy.ShelfHoldPrompt + legacy.ShelfDisplayPrompt
	local lines = {
		"=== PROMPTS ===",
		`active: {#scan.prompts} | legacy duplicates: {legacyTotal}`,
	}

	if legacyTotal > 0 then
		table.insert(lines, "Warning: legacy shelf prompts still in world.")
	end

	for _, prompt in scan.prompts do
		local modeText = if prompt.promptMode then ` [{prompt.promptMode}]` else ""
		table.insert(lines, `- {prompt.actionText} ({prompt.name}) enabled={field(prompt.enabled)}{modeText}`)
	end

	if #scan.prompts == 0 then
		table.insert(lines, "(none)")
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
		"=== NOW ===",
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
	logDealSnapshotEvents(snapshot)
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function onInventorySnapshot(snapshot: any?)
	lastInventorySnapshot = snapshot
	lastInventoryUpdateAt = os.time()
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
