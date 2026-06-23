local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)
local WorldMarkers = require(Shared.Util.WorldMarkers)
local HubWorld = require(script.Parent.HubWorld)

local DebugOverlayController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOG_MAX_LINES = 20
local SCAN_INTERVAL = 1
local TITLE_BAR_HEIGHT = 32
local TAB_BAR_HEIGHT = 28
local TOOLBAR_HEIGHT = 34
local MIN_PANEL_SIZE = Vector2.new(320, 240)
local MAX_PANEL_SCALE = 0.9
local COLLAPSED_HEIGHT = TITLE_BAR_HEIGHT

local PROMPT_KEYWORDS = { "prompt", "shelf", "offer", "hold", "display", "return", "inventory", "stash", "storage" }
local LEGACY_PROMPT_NAMES = {
	ShelfOfferPrompt = true,
	ShelfHoldPrompt = true,
	ShelfDisplayPrompt = true,
	ShelfPrimaryPrompt = true,
	InventoryShelfPrimaryPrompt = true,
}
local LOCAL_FOLDERS = {
	"HubInventoryLocal",
	"HubDisplayLocal",
	"HubItemLocal",
	"HubVisitorLocal",
	"HubPickupsLocal",
}
local OPEN_CLOSED_SIGN_NAMES = { "OpenClosedSign", "Open_Sign", "OpenClosed", "Sign" }

local TABS = {
	{ id = "Overview", label = "Overview" },
	{ id = "ShopDay", label = "Shop Day" },
	{ id = "Shelf", label = "Shelf" },
	{ id = "Deal", label = "Deal" },
	{ id = "Persistence", label = "Persistence" },
	{ id = "Camera", label = "Camera" },
	{ id = "Actions", label = "Actions" },
	{ id = "Log", label = "Log" },
}

local DANGEROUS_ACTIONS = {
	{ id = "GiveRandomItem", label = "Give Random Item" },
	{ id = "GiveRandomTech", label = "Give Random Tech" },
	{ id = "GiveRandomCollectible", label = "Give Random Collectible" },
	{ id = "FillInventory", label = "Fill Shelf" },
	{ id = "ClearInventory", label = "Clear Legacy Stock" },
	{ id = "ClearDisplay", label = "Clear Shelf" },
	{ id = "GiveRandomDisplayItem", label = "Give Random Shelf Item" },
	{ id = "ForceBuyerVisit", label = "Force Buyer Visit" },
	{ id = "ForceRareBuyerVisit", label = "Force Rare Buyer" },
	{ id = "SkipToClosingRush", label = "Skip To Closing Rush" },
	{ id = "EndShift", label = "Close Shop" },
	{ id = "ResetSaveData", label = "Reset Save Data", requires = "resetSave" },
}

local screenGui: ScreenGui? = nil
local rootFrame: Frame? = nil
local bodyFrame: Frame? = nil
local contentLabel: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil
local actionsPanel: Frame? = nil
local roleBadge: TextLabel? = nil
local titleLabel: TextLabel? = nil
local tabButtons: { [string]: TextButton } = {}
local actionButtons: { TextButton } = {}
local setScrapsInput: TextBox? = nil

local ACTION_BTN_W = 156
local ACTION_BTN_H = 24
local ACTION_BTN_GAP = 6

local actionsContentFrame: Frame? = nil
local actionsTopSection: Frame? = nil
local actionsBottomSection: Frame? = nil
local dangerousButtonGrid: Frame? = nil
local dangerousActionButtons: { TextButton } = {}
local updateActionsPanelLayout: (() -> ())? = nil

local debugAccess: any? = nil
local activeTabId = "Overview"
local overlayVisible = false
local overlayCollapsed = false
local actionPending = false
local scanTaskToken = 0
local isDragging = false
local isResizing = false
local dragStartMouse: Vector2? = nil
local dragStartPos: UDim2? = nil
local resizeStartMouse: Vector2? = nil
local resizeStartSize: UDim2? = nil
local savedExpandedSize: UDim2? = nil

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
local shelfFocusDebugSnapshot = {
	active = false,
	selectedName = nil :: string?,
	instanceId = nil :: string?,
}

local function canViewHiddenEconomy(): boolean
	return debugAccess ~= nil and debugAccess.canViewHiddenEconomy == true
end

local function canRunDangerousActions(): boolean
	local permissions = debugAccess and debugAccess.permissions
	return permissions ~= nil and permissions.dangerous == true
end

local function canRunAction(actionId: string): boolean
	local permissions = debugAccess and debugAccess.permissions
	if not permissions then
		return false
	end
	for _, action in DANGEROUS_ACTIONS do
		if action.id == actionId then
			if action.requires == "resetSave" then
				return permissions.resetSave == true
			end
			return permissions.dangerous == true
		end
	end
	if actionId == "SetScraps" then
		return permissions.setScraps == true
	end
	return false
end

local function showHubMessage(message: string)
	local uiOk, UIController = pcall(require, script.Parent.UIController)
	if uiOk then
		UIController:showHubMessage(message)
	else
		warn(message)
	end
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

function DebugOverlayController:appendClientLog(line: string)
	appendLog(line)
end

function DebugOverlayController:updateShelfFocusDebugState(state: {
	active: boolean,
	selectedName: string?,
	instanceId: string?,
})
	shelfFocusDebugSnapshot = {
		active = state.active == true,
		selectedName = state.selectedName,
		instanceId = state.instanceId,
	}
	if overlayVisible then
		DebugOverlayController:rebuildText()
	end
end

local function shortenInstanceId(instanceId: string?): string
	if type(instanceId) ~= "string" or instanceId == "" then
		return "-"
	end
	if #instanceId <= 8 then
		return instanceId
	end
	return string.sub(instanceId, 1, 8) .. "..."
end

local function formatShelfFocusDebugSection(): string
	local snapshot = shelfFocusDebugSnapshot
	local selectedLabel = if snapshot.selectedName and snapshot.selectedName ~= ""
		then snapshot.selectedName
		elseif snapshot.active then "none"
		else "-"
	return table.concat({
		"=== SHELF FOCUS ===",
		`active: {field(snapshot.active)}`,
		`selected: {selectedLabel}`,
		`instanceId: {shortenInstanceId(snapshot.instanceId)}`,
	}, "\n")
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

local function formatTrafficUpcomingNames(traffic: any): string
	if type(traffic) ~= "table" or type(traffic.upcomingBoards) ~= "table" then
		return "-"
	end

	local names = {}
	for _, board in traffic.upcomingBoards do
		if type(board.boardName) == "string" and board.boardName ~= "" then
			table.insert(names, board.boardName)
		end
	end
	return if #names > 0 then table.concat(names, ", ") else "-"
end

local function formatTrafficAvailableNames(traffic: any): string
	if type(traffic) ~= "table" or type(traffic.availableWindows) ~= "table" then
		return "-"
	end

	local names = {}
	for _, window in traffic.availableWindows do
		local name = window.displayName or window.trafficLabel or window.shiftId
		if type(name) == "string" and name ~= "" then
			table.insert(names, name)
		end
	end
	return if #names > 0 then table.concat(names, ", ") else "-"
end

local function formatInfluenceBonus(bonus: any): string
	if type(bonus) ~= "number" then
		return "n/a"
	end
	local percent = math.floor(bonus * 100 + 0.5)
	if percent <= 0 then
		return "0% (no shelf match)"
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
	if canViewHiddenEconomy() then
		return `DEAL START | archetype={field(snapshot.dealArchetypeId)} | {field(snapshot.customerName)} | {field(snapshot.itemName)} | ask={field(snapshot.debugOriginalAsk or snapshot.currentSellerPrice)} min={field(snapshot.debugMinimumAccept or snapshot.minimumAccept)} true={field(snapshot.debugTrueValue or snapshot.trueValue)} tell="{field(snapshot.sellerTell)}"`
	end
	return `DEAL START | archetype={field(snapshot.dealArchetypeId)} | {field(snapshot.customerName)} | {field(snapshot.itemName)} | ask={field(snapshot.currentSellerPrice)} tell="{field(snapshot.sellerTell)}"`
end

local function formatDealDoneLog(snapshot: any): string
	if not snapshot or not snapshot.dealSummary then
		return ""
	end
	local s = snapshot.dealSummary
	if canViewHiddenEconomy() then
		return `DEAL DONE | archetype={field(s.dealArchetypeId or snapshot.dealArchetypeId)} | true={field(s.trueValue)} ask={field(s.sellerAsk)} min={field(s.sellerMinimum)} bought={field(s.purchasePrice)} buyer={field(s.buyerId)} open={field(s.buyerOpeningOffer)} max={field(s.buyerMaximum)} sold={field(s.salePrice or "kept")} profit={field(s.totalProfit or s.profit)} inspected={field(s.inspected)} tactics={field(s.tacticsUsed)} sellerTell="{field(snapshot.sellerTell)}" buyerTell="{field(snapshot.buyerTell)}" heat={field(snapshot.sellerHeat)}/{field(snapshot.buyerHeat)}`
	end
	return `DEAL DONE | archetype={field(s.dealArchetypeId or snapshot.dealArchetypeId)} | bought={field(s.purchasePrice)} buyer={field(s.buyerId)} sold={field(s.salePrice or "kept")} profit={field(s.totalProfit or s.profit)} inspected={field(s.inspected)} tactics={field(s.tacticsUsed)}`
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
			`BUYER VISIT | {field(snapshot.buyerName)} | kind={field(snapshot.buyerVisitKind)} | shelf influence: {formatInfluenceBonus(snapshot.displayInfluenceBonus)}`
		)
	end

	if TERMINAL_DEAL_PHASES[phase] and lastLoggedPhase ~= phase then
		local doneLine = formatDealDoneLog(snapshot)
		if doneLine ~= "" then
			appendLog(doneLine)
		end
	end

	if canViewHiddenEconomy() then
		local tacticLine = snapshot.lastTacticDebug
		if type(tacticLine) == "string" and tacticLine ~= "" and tacticLine ~= lastLoggedTacticDebug then
			appendLog(tacticLine)
			lastLoggedTacticDebug = tacticLine
		end
	end

	lastLoggedPhase = phase
end

local function formatExpectedInteraction(phase: string?): string
	if phase == "BuyerVisit" then
		return "Offer from public shelf. Storage items cannot be offered."
	elseif phase == "Selling" then
		return "Sell tactics on counter item."
	elseif phase == "Haggling" then
		return "Buy from seller at counter."
	elseif phase == "WalkedAway" or phase == "Result" or phase == "Stored" or phase == "BuyerSkipped" then
		return "Terminal — click Next Customer."
	elseif phase == nil or phase == "" then
		return "No deal — Inspect Shelf on BasicShelf when needed."
	end
	return `Phase {phase}.`
end

local function formatShiftSection(): string
	local snapshot = lastShiftSnapshot
	local deal = lastDealSnapshot
	if not snapshot then
		return "=== SHOP DAY ===\n(no data)"
	end

	local name = snapshot.displayName or snapshot.shiftId or "?"
	local phase = snapshot.phase or "?"
	local profit = `{field(snapshot.shiftProfit)}/{field(snapshot.targetProfit)}`
	local sellers = `{field(snapshot.dealsCompleted or snapshot.sellerVisitsResolved)}/{field(snapshot.sellerVisitCount or snapshot.dealCount)}`
	local buyerFlag = if snapshot.pendingBuyerVisit
		then ` | {if snapshot.pendingBuyerVisitKind == "rare" then "rare buyer" else "buyer"} waiting`
		else ""

	local lines = {
		"=== SHOP DAY ===",
		`{name} | {phase} | profit {profit} | sellers {sellers}{buyerFlag}`,
		`scraps: {field(deal and deal.playerCash)} | remaining sellers: {field(snapshot.dealsRemaining)}`,
	}

	local shopDay = snapshot.shopDay
	if type(shopDay) == "table" then
		table.insert(
			lines,
			`variables: {field(shopDay.buyerDemandLabel)} | {field(shopDay.sellerFlowLabel)} | {field(shopDay.riskLabel)}`
		)
		table.insert(
			lines,
			`effects: {field(shopDay.buyerEffectText)} / {field(shopDay.sellerEffectText)} | shelf helped={field(shopDay.displayHelped)}`
		)
	end

	local traffic = snapshot.traffic
	if type(traffic) == "table" then
		table.insert(
			lines,
			`traffic: {field(traffic.boardName)} (#{field(traffic.boardIndex)}) | completed windows: {field(traffic.completedWindows)}`
		)
		table.insert(lines, `available: {formatTrafficAvailableNames(traffic)}`)
		table.insert(lines, `next: {formatTrafficUpcomingNames(traffic)}`)
	end
	table.insert(
		lines,
		`traffic progress: meaningful={field(snapshot.meaningfulProgress)} | advanced={field(snapshot.trafficAdvanced)} | skipped={field(snapshot.trafficAdvanceSkipped)}`
	)
	table.insert(
		lines,
		`rare walk-in: used={field((snapshot.rareBuyerVisitsSeen or 0) > 0)} | queued={field(snapshot.pendingBuyerVisitKind == "rare")} | pending={field(snapshot.pendingBuyerVisitKind)} | rare id={field(snapshot.pendingRareBuyerId)} | cap {field(snapshot.rareBuyerVisitsSeen)}/{field(snapshot.rareBuyerMax)}`
	)
	local onboarding = snapshot.onboarding or (deal and deal.onboarding)
	if type(onboarding) == "table" then
		table.insert(
			lines,
			`onboarding: active={field(onboarding.active)} | step={field(onboarding.stepId)} | first shop day done={field(onboarding.firstShiftCompleted)}`
		)
	end

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
		if canViewHiddenEconomy() then
			table.insert(
				lines,
				`ask {field(snapshot.debugOriginalAsk or snapshot.currentSellerPrice)} | min {field(snapshot.debugMinimumAccept or snapshot.minimumAccept)} | true {field(snapshot.debugTrueValue or snapshot.trueValue)}`
			)
		else
			table.insert(lines, `ask {field(snapshot.currentSellerPrice)}`)
		end
		table.insert(
			lines,
			`seller heat {field(snapshot.sellerHeat)}/{field(snapshot.sellerHeatMax)} | {field(snapshot.lastTactic)} -> {field(snapshot.lastTacticResult)}`
		)
	elseif isBuyerFacingPhase(phase) then
		table.insert(lines, `buyer: {field(snapshot.buyerName)} ({field(snapshot.buyerId)})`)
		table.insert(lines, `visit kind: {field(snapshot.buyerVisitKind)} | rare: {field(snapshot.rareWalkInBuyer)}`)
		table.insert(lines, `shelf influence: {formatInfluenceBonus(snapshot.displayInfluenceBonus)}`)
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
			table.insert(lines, `shelf offers available: {matchCount}`)
		elseif phase == "Selling" then
			if canViewHiddenEconomy() then
				table.insert(
					lines,
					`item: {field(snapshot.itemName)} | offer {field(snapshot.currentBuyerOffer)} / max {field(snapshot.buyerMaximum)}`
				)
			else
				table.insert(lines, `item: {field(snapshot.itemName)} | offer {field(snapshot.currentBuyerOffer)}`)
			end
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

	if canViewHiddenEconomy() and snapshot.lastTacticDebug and snapshot.lastTacticDebug ~= "" then
		table.insert(lines, `last tactic debug: {snapshot.lastTacticDebug}`)
	end

	return table.concat(lines, "\n")
end

local function formatShelfSection(): string
	local snapshot = lastInventorySnapshot
	if not snapshot then
		return "=== SHELF & STORAGE ===\n(no data)"
	end

	local shelfUsed = snapshot.shelfUsedSlots or snapshot.displayUsedSlots
	local shelfMax = snapshot.shelfMaxSlots or snapshot.displayMaxSlots
	local lines = {
		"=== SHELF & STORAGE ===",
		`shelf: {field(shelfUsed)}/{field(shelfMax)} | appeal: {field(snapshot.shelfAppealSummary or snapshot.displayAppealSummary)}`,
	}

	local shelfItems = InventorySnapshot.indexShelfItemsBySlot(snapshot.shelfItems or snapshot.displayItems)
	local anyShelf = false
	for slotIndex = 1, shelfMax or 3 do
		local entry = shelfItems[slotIndex]
		if entry then
			anyShelf = true
			table.insert(lines, `{slotIndex}. {entry.displayName} ({entry.category}) — paid {field(entry.purchasePrice)}`)
		end
	end
	if not anyShelf then
		table.insert(lines, "shelf empty")
	end

	table.insert(lines, `storage: {field(snapshot.stashUsedSlots)}/{field(snapshot.stashMaxSlots)}`)
	local stashItems = snapshot.stashItems or {}
	if #stashItems == 0 then
		table.insert(lines, "storage empty")
	else
		for index, entry in ipairs(stashItems) do
			table.insert(lines, `S{index}. {entry.displayName} ({entry.category}) - paid {field(entry.purchasePrice)}`)
		end
	end

	local deal = lastDealSnapshot
	table.insert(lines, "")
	table.insert(lines, "=== BUYER VISIT ===")
	if deal and isBuyerFacingPhase(deal.phase) then
		table.insert(lines, `shelf influence this visit: {formatInfluenceBonus(deal.displayInfluenceBonus)}`)
	else
		table.insert(lines, "(no active buyer visit)")
	end

	return table.concat(lines, "\n")
end

local function formatPersistenceSection(): string
	local persistence = lastInventorySnapshot and lastInventorySnapshot.persistenceDebug
	if type(persistence) ~= "table" then
		return "=== PERSISTENCE ===\n(no data)"
	end

	local lines = {
		"=== PERSISTENCE ===",
		`store: {field(persistence.storeName)}`,
		`key: {field(persistence.key)}`,
		`load={field(persistence.loadStatus)} | save={field(persistence.saveStatus)} | disabled={field(persistence.saveDisabled)} | dirty={field(persistence.dirty)}`,
		`saved scraps={field(persistence.savedScraps)} | storage (internal stash)={field(persistence.permanentStashCount)} | shelf (internal display)={field(persistence.permanentDisplayCount)}`,
	}

	if persistence.lastLoadError then
		table.insert(lines, `load error: {field(persistence.lastLoadError)}`)
	end
	if persistence.lastSaveError then
		table.insert(lines, `save error: {field(persistence.lastSaveError)}`)
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
	local shelf = HubWorld.findShelf(shop)
	local stashBin = HubWorld.findStorageBin(shop)

	local scan = {
		world = world ~= nil,
		shop = shop ~= nil,
		shelf = shelf ~= nil,
		shelfSlots = {},
		stashBin = stashBin ~= nil,
		storageBin = stashBin ~= nil,
		counterItemSpot = HubWorld.findCounterItemSpot(shop) ~= nil,
		customerSpot = HubWorld.findCustomerSpot(shop) ~= nil,
		dealCameraSpot = HubWorld.findDealCameraSpot(shop) ~= nil,
		counterLookAt = HubWorld.findCounterLookAt(shop) ~= nil,
		customerEntrySpot = HubWorld.findCustomerEntrySpot(shop) ~= nil,
		customerCounterSpot = HubWorld.findCustomerCounterSpot(shop) ~= nil,
		customerExitSpot = HubWorld.findCustomerExitSpot(shop) ~= nil,
		playerCounterSpot = HubWorld.findPlayerCounterSpot(shop) ~= nil,
		sellShelfLookAt = HubWorld.findSellShelfLookAt(shop) ~= nil,
		displayShelfLookAt = HubWorld.findDisplayShelfLookAt(shop) ~= nil,
		storageLookAt = HubWorld.findStorageLookAt(shop) ~= nil,
		stashLookAt = HubWorld.findStorageLookAt(shop) ~= nil,
		presentationReady = HubWorld.resolvePresentationAnchors(shop) ~= nil,
		openClosedSign = findOpenClosedSign(shop) ~= nil,
		localFolders = {},
	}

	for slotIndex = 1, 3 do
		scan.shelfSlots[slotIndex] = HubWorld.findShelfSlot(shelf, slotIndex) ~= nil
	end

	local focusMarkers = WorldMarkers.findShelfFocusMarkers(shop, shelf)
	scan.shelfFocusCamera = focusMarkers.camera ~= nil or focusMarkers.cameraPosition ~= nil
	scan.shelfFocusLookAt = focusMarkers.lookAt ~= nil or focusMarkers.lookAtPosition ~= nil
	scan.shelfFocusSource = focusMarkers.source
	scan.shelfPromptAnchor = WorldMarkers.findShelfPromptAnchor(shelf) ~= nil

	local sources = WorldMarkers.collectMarkerSources(shop)
	scan.markerSources = sources
	scan.shelfSource = sources.shelf
	scan.counterSource = sources.counter
	scan.customerSource = sources.customer
	scan.storageSource = sources.storage

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
		ShelfPrimaryPrompt = 0,
		InventoryShelfPrimaryPrompt = 0,
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

local function formatCameraSection(scan: any, promptScan: any): string
	local function status(found: boolean): string
		return if found then "OK" else "MISSING"
	end

	local lines = { "=== CAMERA & ANCHORS ===" }
	if not scan then
		table.insert(lines, "(click Refresh on Overview)")
		return table.concat(lines, "\n")
	end

	table.insert(lines, `presentation ready: {field(scan.presentationReady)}`)
	local function sourceLine(label: string, source: string?)
		local value = field(source)
		if source == "legacy" or source == "derived" then
			return `{label} source: {value} (warning)`
		end
		return `{label} source: {value}`
	end
	table.insert(lines, sourceLine("shelf", scan.shelfSource))
	table.insert(lines, sourceLine("counter", scan.counterSource))
	table.insert(lines, sourceLine("customer path", scan.customerSource))
	table.insert(lines, sourceLine("storage", scan.storageSource))
	table.insert(lines, `deal camera spot: {status(scan.dealCameraSpot)}`)
	table.insert(lines, `counter look-at: {status(scan.counterLookAt)}`)
	table.insert(lines, `sell shelf look-at: {status(scan.sellShelfLookAt)}`)
	table.insert(lines, `display shelf look-at (internal): {status(scan.displayShelfLookAt)}`)
	table.insert(lines, `shelf focus camera: {status(scan.shelfFocusCamera)} | look-at: {status(scan.shelfFocusLookAt)} | source: {field(scan.shelfFocusSource)}`)
	table.insert(lines, `shelf prompt anchor: {status(scan.shelfPromptAnchor)}`)
	table.insert(lines, `storage look-at: {status(scan.storageLookAt)}`)
	table.insert(lines, `player counter spot: {status(scan.playerCounterSpot)}`)
	table.insert(lines, `customer entry: {status(scan.customerEntrySpot)} | counter: {status(scan.customerCounterSpot)} | exit: {status(scan.customerExitSpot)}`)
	table.insert(lines, `open/closed sign: {status(scan.openClosedSign)}`)

	table.insert(lines, "")
	table.insert(lines, formatShelfFocusDebugSection())

	table.insert(lines, "")
	table.insert(lines, "=== WORLD PARTS ===")
	local problems = {}
	local function check(label: string, found: boolean)
		if not found then
			table.insert(problems, label)
		end
	end

	check("World", scan.world)
	check("Shop", scan.shop)
	check("Shelf", scan.shelf)
	check("StorageBin", scan.stashBin or scan.storageBin)
	check("CounterItemSpot", scan.counterItemSpot)
	check("CustomerSpot", scan.customerSpot)
	for slotIndex = 1, 3 do
		check(`ShelfSlot{slotIndex}`, scan.shelfSlots[slotIndex])
	end

	if #problems > 0 then
		table.insert(lines, `MISSING: {table.concat(problems, ", ")}`)
	else
		table.insert(lines, "All core parts OK")
	end

	table.insert(lines, "")
	table.insert(lines, "=== PROMPTS ===")
	if not promptScan then
		table.insert(lines, "(click Refresh on Overview)")
	else
		local legacy = promptScan.legacyCounts
		local legacyTotal = legacy.ShelfOfferPrompt
			+ legacy.ShelfHoldPrompt
			+ legacy.ShelfDisplayPrompt
			+ legacy.ShelfPrimaryPrompt
			+ legacy.InventoryShelfPrimaryPrompt
		local stationCount = 0
		for _, prompt in promptScan.prompts do
			if prompt.name == "ShelfStationPrompt" then
				stationCount += 1
			end
		end
		table.insert(lines, `active: {#promptScan.prompts} | legacy duplicates: {legacyTotal} | ShelfStationPrompt: {stationCount}`)
		if legacyTotal > 0 then
			table.insert(lines, "Warning: legacy shelf prompts still in world (expect only ShelfStationPrompt on BasicShelf).")
		end
		if stationCount > 1 then
			table.insert(lines, "Warning: multiple ShelfStationPrompt instances found.")
		end
		for _, prompt in promptScan.prompts do
			local modeText = if prompt.promptMode then ` [{prompt.promptMode}]` else ""
			table.insert(lines, `- {prompt.actionText} ({prompt.name}) enabled={field(prompt.enabled)}{modeText}`)
		end
		if #promptScan.prompts == 0 then
			table.insert(lines, "(none)")
		end
	end

	return table.concat(lines, "\n")
end

local function formatOverviewSection(): string
	local phase = lastDealSnapshot and lastDealSnapshot.phase
	local shift = lastShiftSnapshot
	local lines = {
		"=== NOW ===",
		formatExpectedInteraction(phase),
		"",
	}

	if shift then
		table.insert(lines, `shop day: {field(shift.displayName or shift.shiftId)} | phase: {field(shift.phase)}`)
		table.insert(lines, `profit: {field(shift.shiftProfit)}/{field(shift.targetProfit)} | scraps: {field(lastDealSnapshot and lastDealSnapshot.playerCash)}`)
	else
		table.insert(lines, "shop day: (no data)")
	end

	if lastDealSnapshot then
		table.insert(lines, `deal phase: {field(lastDealSnapshot.phase)} | item: {field(lastDealSnapshot.itemName)}`)
	end

	if lastInventorySnapshot then
		local shelfUsed = lastInventorySnapshot.shelfUsedSlots or lastInventorySnapshot.displayUsedSlots
		local shelfMax = lastInventorySnapshot.shelfMaxSlots or lastInventorySnapshot.displayMaxSlots
		table.insert(
			lines,
			`shelf: {field(shelfUsed)}/{field(shelfMax)} | storage: {field(lastInventorySnapshot.stashUsedSlots)}/{field(lastInventorySnapshot.stashMaxSlots)}`
		)
	end

	table.insert(lines, "")
	table.insert(lines, formatShelfFocusDebugSection())

	table.insert(lines, "")
	table.insert(lines, "Use Refresh to rescan world prompts and anchors.")
	return table.concat(lines, "\n")
end

local function formatRemoteLogSection(): string
	local lines = { "=== EVENT LOG ===" }
	if #remoteLog == 0 then
		table.insert(lines, "(empty)")
	else
		for _, line in remoteLog do
			table.insert(lines, line)
		end
	end
	return table.concat(lines, "\n")
end

local function formatActionsHelpSection(): string
	local lines = {
		"=== SAFE (CLIENT) ===",
		"Refresh — rescan world and prompts",
		"Clear Log — clear event log",
		"Print Tab Text — print active tab to Output",
		"Toggle Legacy Deal UI — presentation preference only",
		"",
		"=== DANGEROUS (SERVER) ===",
		"Clear Legacy Stock removes internal inventory-location items only.",
	}

	if canRunDangerousActions() then
		for _, action in DANGEROUS_ACTIONS do
			if not action.requires or canRunAction(action.id) then
				table.insert(lines, `- {action.label} ({action.id})`)
			end
		end
		if canRunAction("SetScraps") then
			table.insert(lines, "- Set Scraps (owner, self only)")
		end
	else
		table.insert(lines, "(not permitted for your role)")
	end

	return table.concat(lines, "\n")
end

local function getTabText(tabId: string): string
	if tabId == "Overview" then
		return formatOverviewSection()
	elseif tabId == "ShopDay" then
		return formatShiftSection()
	elseif tabId == "Shelf" then
		return formatShelfSection()
	elseif tabId == "Deal" then
		return formatDealSection()
	elseif tabId == "Persistence" then
		return formatPersistenceSection()
	elseif tabId == "Camera" then
		return formatCameraSection(worldScanCache, promptScanCache)
	elseif tabId == "Actions" then
		return formatActionsHelpSection()
	elseif tabId == "Log" then
		return formatRemoteLogSection()
	end
	return ""
end

local function updateTabVisuals()
	for tabId, button in tabButtons do
		local selected = tabId == activeTabId
		button.BackgroundColor3 = if selected then Color3.fromRGB(58, 58, 68) else Color3.fromRGB(40, 40, 48)
		button.TextColor3 = if selected then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(180, 180, 190)
	end

	local showScroll = activeTabId ~= "Actions"
	if scrollFrame then
		scrollFrame.Visible = showScroll
	end
	if actionsPanel then
		actionsPanel.Visible = activeTabId == "Actions"
	end
end

function DebugOverlayController:rebuildText()
	updateTabVisuals()

	if activeTabId == "Actions" then
		if updateActionsPanelLayout then
			updateActionsPanelLayout()
		end
		return
	end

	if not contentLabel then
		return
	end

	contentLabel.Text = getTabText(activeTabId)
	if scrollFrame and contentLabel then
		scrollFrame.CanvasSize = UDim2.fromOffset(0, contentLabel.TextBounds.Y + 16)
	end
end

local function setActionButtonsEnabled(enabled: boolean)
	for _, button in actionButtons do
		button.Active = enabled
		button.AutoButtonColor = enabled
	end
	if setScrapsInput then
		setScrapsInput.Active = enabled
	end
end

function DebugOverlayController:runDebugAction(actionId: string, payload: any?)
	if actionPending or not canRunAction(actionId) then
		return
	end

	actionPending = true
	setActionButtonsEnabled(false)

	local remote = Remotes.get("DebugRunAction") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(actionId, payload)
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

local function getViewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function clampFrameToViewport(frame: Frame)
	local viewport = getViewportSize()
	local absoluteSize = frame.AbsoluteSize
	local absolutePos = frame.AbsolutePosition

	local minX = 0
	local minY = 0
	local maxX = math.max(0, viewport.X - absoluteSize.X)
	local maxY = math.max(0, viewport.Y - absoluteSize.Y)

	local x = math.clamp(absolutePos.X, minX, maxX)
	local y = math.clamp(absolutePos.Y, minY, maxY)

	frame.Position = UDim2.fromOffset(x, y)
end

local function applyCollapsedState()
	if not rootFrame or not bodyFrame then
		return
	end

	if overlayCollapsed then
		if rootFrame.AbsoluteSize.Y > COLLAPSED_HEIGHT + 4 then
			savedExpandedSize = rootFrame.Size
		end
		bodyFrame.Visible = false
		rootFrame.Size = UDim2.new(rootFrame.Size.X.Scale, rootFrame.Size.X.Offset, 0, COLLAPSED_HEIGHT)
	else
		bodyFrame.Visible = true
		if savedExpandedSize then
			rootFrame.Size = savedExpandedSize
		end
	end
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
		if activeTabId == "Actions" and updateActionsPanelLayout then
			task.defer(updateActionsPanelLayout)
		end
	else
		stopScanLoop()
	end
end

function DebugOverlayController:toggleVisible()
	self:setVisible(not overlayVisible)
end

local function selectTab(tabId: string)
	activeTabId = tabId
	DebugOverlayController:rebuildText()
	if tabId == "Actions" and updateActionsPanelLayout then
		updateActionsPanelLayout()
	end
end

local function layoutDangerousButtonGrid(grid: Frame, buttons: { GuiObject }, width: number)
	if #buttons == 0 then
		grid.Size = UDim2.new(1, 0, 0, 0)
		return
	end

	local cols = math.max(1, math.floor((width + ACTION_BTN_GAP) / (ACTION_BTN_W + ACTION_BTN_GAP)))
	for index, button in buttons do
		local col = (index - 1) % cols
		local row = math.floor((index - 1) / cols)
		button.Position = UDim2.fromOffset(col * (ACTION_BTN_W + ACTION_BTN_GAP), row * (ACTION_BTN_H + ACTION_BTN_GAP))
		button.Size = UDim2.fromOffset(ACTION_BTN_W, ACTION_BTN_H)
	end

	local rows = math.ceil(#buttons / cols)
	grid.Size = UDim2.new(1, 0, 0, rows * (ACTION_BTN_H + ACTION_BTN_GAP) - ACTION_BTN_GAP)
end

local function makeActionsSectionLabel(text: string, parent: Instance, layoutOrder: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Text = text
	label.LayoutOrder = layoutOrder
	label.Parent = parent
	return label
end

local function inputPosition2(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function bindDragHandle(root: Frame, dragHandle: GuiObject)
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		isDragging = true
		dragStartMouse = inputPosition2(input)
		dragStartPos = root.Position
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not isDragging or not dragStartMouse or not dragStartPos or not rootFrame then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = inputPosition2(input) - dragStartMouse
		rootFrame.Position = UDim2.new(
			dragStartPos.X.Scale,
			dragStartPos.X.Offset + delta.X,
			dragStartPos.Y.Scale,
			dragStartPos.Y.Offset + delta.Y
		)
		clampFrameToViewport(rootFrame)
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

local function bindResizeHandle(root: Frame, handle: GuiObject)
	handle.InputBegan:Connect(function(input)
		if overlayCollapsed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		isResizing = true
		resizeStartMouse = inputPosition2(input)
		resizeStartSize = root.Size
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not isResizing or not resizeStartMouse or not resizeStartSize or not rootFrame then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local viewport = getViewportSize()
		local maxSize = viewport * MAX_PANEL_SCALE
		local delta = inputPosition2(input) - resizeStartMouse
		local startOffset = Vector2.new(resizeStartSize.X.Offset, resizeStartSize.Y.Offset)
		local newSize = startOffset + delta
		newSize = Vector2.new(
			math.clamp(newSize.X, MIN_PANEL_SIZE.X, maxSize.X),
			math.clamp(newSize.Y, MIN_PANEL_SIZE.Y, maxSize.Y)
		)
		rootFrame.Size = UDim2.fromOffset(newSize.X, newSize.Y)
		savedExpandedSize = rootFrame.Size
		clampFrameToViewport(rootFrame)
		if updateActionsPanelLayout then
			updateActionsPanelLayout()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		isResizing = false
		resizeStartMouse = nil
		resizeStartSize = nil
	end)
end

local function buildOverlay(access: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WastelandPawnDevTools"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.fromOffset(12, 12)
	root.Size = UDim2.fromOffset(520, 420)
	root.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Parent = gui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = MIN_PANEL_SIZE
	sizeConstraint.MaxSize = getViewportSize() * MAX_PANEL_SCALE
	sizeConstraint.Parent = root

	local dragHandle = Instance.new("TextButton")
	dragHandle.Name = "DragHandle"
	dragHandle.AutoButtonColor = false
	dragHandle.Text = ""
	dragHandle.Position = UDim2.fromOffset(0, 0)
	dragHandle.Size = UDim2.new(1, -148, 0, TITLE_BAR_HEIGHT)
	dragHandle.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	dragHandle.BackgroundTransparency = 0.35
	dragHandle.BorderSizePixel = 0
	dragHandle.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -200, 0, 24)
	title.Font = Enum.Font.Code
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(230, 230, 230)
	title.Text = "Wasteland Pawn DevTools"
	title.Parent = root
	titleLabel = title

	local badge = Instance.new("TextLabel")
	badge.Name = "RoleBadge"
	badge.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
	badge.BackgroundTransparency = 0.2
	badge.Position = UDim2.new(1, -140, 0, 6)
	badge.Size = UDim2.fromOffset(56, 20)
	badge.Font = Enum.Font.Code
	badge.TextSize = 11
	badge.TextColor3 = Color3.fromRGB(200, 220, 255)
	badge.Text = if type(access.role) == "string" then access.role else "?"
	badge.Parent = root
	roleBadge = badge

	local collapseButton = Instance.new("TextButton")
	collapseButton.Name = "Collapse"
	collapseButton.Position = UDim2.new(1, -108, 0, 4)
	collapseButton.Size = UDim2.fromOffset(28, 24)
	collapseButton.Font = Enum.Font.Code
	collapseButton.TextSize = 14
	collapseButton.Text = "_"
	collapseButton.Parent = root

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Position = UDim2.new(1, -72, 0, 4)
	closeButton.Size = UDim2.fromOffset(64, 24)
	closeButton.Font = Enum.Font.Code
	closeButton.TextSize = 13
	closeButton.Text = "Close"
	closeButton.Parent = root

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
	body.Parent = root
	bodyFrame = body

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(4, 0)
	tabBar.Size = UDim2.new(1, -8, 0, TAB_BAR_HEIGHT)
	tabBar.Parent = body

	local tabX = 0
	for _, tab in TABS do
		local button = Instance.new("TextButton")
		button.Name = tab.id
		button.Position = UDim2.fromOffset(tabX, 2)
		button.Size = UDim2.fromOffset(72, 22)
		button.Font = Enum.Font.Code
		button.TextSize = 11
		button.Text = tab.label
		button.Parent = tabBar
		tabButtons[tab.id] = button
		tabX += 76

		local tabId = tab.id
		button.MouseButton1Click:Connect(function()
			selectTab(tabId)
		end)
	end

	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.BackgroundTransparency = 1
	toolbar.Position = UDim2.fromOffset(8, TAB_BAR_HEIGHT)
	toolbar.Size = UDim2.new(1, -16, 0, TOOLBAR_HEIGHT)
	toolbar.Parent = body

	local function makeTopButton(name: string, text: string, x: number)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 2)
		button.Size = UDim2.fromOffset(108, 26)
		button.Font = Enum.Font.Code
		button.TextSize = 11
		button.Text = text
		button.Parent = toolbar
		return button
	end

	local refreshButton = makeTopButton("Refresh", "Refresh", 0)
	local clearLogButton = makeTopButton("ClearLog", "Clear Log", 114)
	local printButton = makeTopButton("PrintDebug", "Print Tab", 228)

	local contentTop = TAB_BAR_HEIGHT + TOOLBAR_HEIGHT + 4
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ContentScroll"
	scroll.Position = UDim2.fromOffset(8, contentTop)
	scroll.Size = UDim2.new(1, -24, 1, -(contentTop + 8))
	scroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	scroll.BackgroundTransparency = 0.2
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = body

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

	local actions = Instance.new("ScrollingFrame")
	actions.Name = "ActionsPanel"
	actions.Visible = false
	actions.Position = UDim2.fromOffset(8, contentTop)
	actions.Size = UDim2.new(1, -24, 1, -(contentTop + 8))
	actions.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	actions.BackgroundTransparency = 0.2
	actions.BorderSizePixel = 0
	actions.ScrollBarThickness = 8
	actions.CanvasSize = UDim2.fromOffset(0, 0)
	actions.Parent = body
	actionsPanel = actions

	local content = Instance.new("Frame")
	content.Name = "ActionsContent"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 0)
	content.Size = UDim2.new(1, 0, 0, 0)
	content.Parent = actions
	actionsContentFrame = content

	local topSection = Instance.new("Frame")
	topSection.Name = "TopSection"
	topSection.BackgroundTransparency = 1
	topSection.Position = UDim2.fromOffset(8, 8)
	topSection.Size = UDim2.new(1, -16, 0, 0)
	topSection.AutomaticSize = Enum.AutomaticSize.Y
	topSection.Parent = content
	actionsTopSection = topSection

	local topLayout = Instance.new("UIListLayout")
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Padding = UDim.new(0, 6)
	topLayout.Parent = topSection

	local intro = Instance.new("TextLabel")
	intro.Name = "Intro"
	intro.BackgroundTransparency = 1
	intro.Size = UDim2.new(1, 0, 0, 0)
	intro.AutomaticSize = Enum.AutomaticSize.Y
	intro.Font = Enum.Font.Code
	intro.TextSize = 12
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.TextYAlignment = Enum.TextYAlignment.Top
	intro.TextColor3 = Color3.fromRGB(200, 200, 210)
	intro.TextWrapped = true
	intro.Text = "Safe actions run on the client. Dangerous actions call the server and stay pinned to the bottom of this panel."
	intro.LayoutOrder = 1
	intro.Parent = topSection

	makeActionsSectionLabel("Safe", topSection, 2)

	local legacyButton = Instance.new("TextButton")
	legacyButton.Name = "LegacyDealUI"
	legacyButton.Size = UDim2.fromOffset(200, ACTION_BTN_H)
	legacyButton.Font = Enum.Font.Code
	legacyButton.TextSize = 11
	legacyButton.Text = "Toggle Legacy Deal UI"
	legacyButton.LayoutOrder = 3
	legacyButton.Parent = topSection
	legacyButton.MouseButton1Click:Connect(function()
		local ClientPresentation = require(Shared.Config.ClientPresentation)
		local CounterPresentationController = require(script.Parent.CounterPresentationController)
		ClientPresentation.ForceLegacyDealUI = not ClientPresentation.ForceLegacyDealUI
		CounterPresentationController:setLegacyDealUiForced(ClientPresentation.ForceLegacyDealUI)
	end)

	local bottomSection = Instance.new("Frame")
	bottomSection.Name = "BottomSection"
	bottomSection.BackgroundTransparency = 1
	bottomSection.AnchorPoint = Vector2.new(0, 1)
	bottomSection.Position = UDim2.new(0, 8, 1, -8)
	bottomSection.Size = UDim2.new(1, -16, 0, 0)
	bottomSection.AutomaticSize = Enum.AutomaticSize.Y
	bottomSection.Parent = content
	actionsBottomSection = bottomSection

	local bottomLayout = Instance.new("UIListLayout")
	bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bottomLayout.Padding = UDim.new(0, 6)
	bottomLayout.Parent = bottomSection

	local dangerousTitle = makeActionsSectionLabel(
		if canRunDangerousActions() then "Dangerous" else "Dangerous (read-only role)",
		bottomSection,
		1
	)
	dangerousTitle.Name = "DangerousTitle"

	local buttonGrid = Instance.new("Frame")
	buttonGrid.Name = "DangerousGrid"
	buttonGrid.BackgroundTransparency = 1
	buttonGrid.Size = UDim2.new(1, 0, 0, 0)
	buttonGrid.LayoutOrder = 2
	buttonGrid.Parent = bottomSection
	dangerousButtonGrid = buttonGrid

	table.clear(dangerousActionButtons)
	for _, action in DANGEROUS_ACTIONS do
		if action.requires == "resetSave" and not canRunAction(action.id) then
			continue
		end
		if not canRunDangerousActions() and not (action.requires and canRunAction(action.id)) then
			continue
		end

		local button = Instance.new("TextButton")
		button.Name = action.id
		button.Font = Enum.Font.Code
		button.TextSize = 11
		button.Text = action.label
		button.Parent = buttonGrid
		table.insert(actionButtons, button)
		table.insert(dangerousActionButtons, button)

		local actionId = action.id
		button.MouseButton1Click:Connect(function()
			DebugOverlayController:runDebugAction(actionId)
		end)
	end

	local scrapsRow: Frame? = nil
	if canRunAction("SetScraps") then
		scrapsRow = Instance.new("Frame")
		scrapsRow.Name = "SetScrapsRow"
		scrapsRow.BackgroundTransparency = 1
		scrapsRow.Size = UDim2.new(1, 0, 0, ACTION_BTN_H)
		scrapsRow.LayoutOrder = 3
		scrapsRow.Parent = bottomSection

		local scrapsInput = Instance.new("TextBox")
		scrapsInput.Name = "SetScrapsInput"
		scrapsInput.Position = UDim2.fromOffset(0, 0)
		scrapsInput.Size = UDim2.fromOffset(120, ACTION_BTN_H)
		scrapsInput.Font = Enum.Font.Code
		scrapsInput.TextSize = 11
		scrapsInput.PlaceholderText = "Scraps"
		scrapsInput.Text = ""
		scrapsInput.Parent = scrapsRow
		setScrapsInput = scrapsInput

		local scrapsButton = Instance.new("TextButton")
		scrapsButton.Name = "SetScraps"
		scrapsButton.Position = UDim2.fromOffset(126, 0)
		scrapsButton.Size = UDim2.fromOffset(100, ACTION_BTN_H)
		scrapsButton.Font = Enum.Font.Code
		scrapsButton.TextSize = 11
		scrapsButton.Text = "Set Scraps"
		scrapsButton.Parent = scrapsRow
		table.insert(actionButtons, scrapsButton)
		scrapsButton.MouseButton1Click:Connect(function()
			local amount = tonumber(scrapsInput.Text)
			if amount == nil then
				showHubMessage("SetScraps: enter a number")
				return
			end
			DebugOverlayController:runDebugAction("SetScraps", { amount = amount })
		end)
	end

	updateActionsPanelLayout = function()
		if not actionsPanel or not actionsContentFrame or not actionsTopSection or not actionsBottomSection or not dangerousButtonGrid then
			return
		end

		local scroll = actionsPanel :: ScrollingFrame
		local gridWidth = math.max(scroll.AbsoluteSize.X - 32, MIN_PANEL_SIZE.X - 32)
		layoutDangerousButtonGrid(dangerousButtonGrid, dangerousActionButtons, gridWidth)

		local viewportH = scroll.AbsoluteSize.Y
		local topH = actionsTopSection.AbsoluteSize.Y
		local bottomH = actionsBottomSection.AbsoluteSize.Y
		local totalH = math.max(topH + bottomH + 24, viewportH)

		actionsContentFrame.Size = UDim2.new(1, 0, 0, totalH)
		actionsBottomSection.Position = UDim2.new(0, 8, 1, -8)
		scroll.CanvasSize = UDim2.fromOffset(0, totalH)
	end

	actions:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if activeTabId == "Actions" and updateActionsPanelLayout then
			updateActionsPanelLayout()
		end
	end)

	updateActionsPanelLayout()

	task.defer(function()
		if updateActionsPanelLayout then
			updateActionsPanelLayout()
		end
	end)

	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.AutoButtonColor = false
	resizeHandle.AnchorPoint = Vector2.new(1, 1)
	resizeHandle.Position = UDim2.new(1, -2, 1, -2)
	resizeHandle.Size = UDim2.fromOffset(14, 14)
	resizeHandle.Text = ""
	resizeHandle.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	resizeHandle.BorderSizePixel = 0
	resizeHandle.Parent = root

	collapseButton.MouseButton1Click:Connect(function()
		overlayCollapsed = not overlayCollapsed
		collapseButton.Text = if overlayCollapsed then "+" else "_"
		applyCollapsedState()
	end)

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
		local text = if activeTabId == "Actions"
			then formatActionsHelpSection()
			else (contentLabel and contentLabel.Text or "")
		print(text)
	end)

	screenGui = gui
	rootFrame = root
	scrollFrame = scroll
	contentLabel = label
	savedExpandedSize = root.Size

	bindDragHandle(root, dragHandle)
	bindResizeHandle(root, resizeHandle)
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

function DebugOverlayController:Init() end

function DebugOverlayController:Start()
	local remote = Remotes.get("DebugGetAccess") :: RemoteFunction
	local ok, access = pcall(function()
		return remote:InvokeServer()
	end)
	if not ok or type(access) ~= "table" or access.canView ~= true then
		return
	end

	debugAccess = access
	buildOverlay(access)

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
