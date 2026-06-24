local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientPresentation = require(Shared.Config.ClientPresentation)
local HaggleTuning = require(Shared.Config.HaggleTuning)
local Remotes = require(Shared.Net.Remotes)

local HubWorld = require(script.Parent.HubWorld)
local CameraController = require(script.Parent.CameraController)
local CustomerPresentationController = require(script.Parent.CustomerPresentationController)
local ItemPresentationController = require(script.Parent.ItemPresentationController)
local DealController = require(script.Parent.DealController)
local UIController = require(script.Parent.UIController)

local CounterPresentationController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WORLD_WAIT_SECONDS = 30

local shop: Instance? = nil
local anchors: HubWorld.PresentationAnchors? = nil
local counterModeActive = false
local shelfFocusOverlaySuppressed = false
local anchorWarned = false
local portraitWarned = false

local currentDealSnapshot: any = nil
local currentShiftSnapshot: any = nil
local currentInventorySnapshot: any = nil
local sellerHaggleExpanded = false
local sellHaggleExpanded = false
local tacticButtonsEnabled = true

local screenGui: ScreenGui? = nil
local rootFrame: Frame? = nil
local phaseChip: TextLabel? = nil
local rareBanner: TextLabel? = nil
local cashLabel: TextLabel? = nil
local portraitFrame: ViewportFrame? = nil
local npcNameLabel: TextLabel? = nil
local dialogueLabel: TextLabel? = nil
local itemLabel: TextLabel? = nil
local infoLabel: TextLabel? = nil
local resultLabel: TextLabel? = nil
local heatBarBg: Frame? = nil
local heatBarFill: Frame? = nil

local primaryRow: Frame? = nil
local haggleRow: Frame? = nil
local sellHaggleRow: Frame? = nil
local offerSlotRow: Frame? = nil
local metaRow: Frame? = nil

local TERMINAL_PHASES = {
	Result = true,
	WalkedAway = true,
	BuyerSkipped = true,
}

local LEAVE_CUSTOMER_PHASES = {
	Result = true,
	WalkedAway = true,
	BuyerSkipped = true,
}

local WAIT_FOR_NEXT_PHASES = {
	Result = true,
	WalkedAway = true,
	BuyerSkipped = true,
	Stored = true,
}

local function warnAnchorsOnce(message: string)
	if anchorWarned then
		return
	end
	anchorWarned = true
	warn(message)
end

local function waitForShop(): Instance?
	local world = Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
	if not world then
		return nil
	end
	return world:WaitForChild("Shop", WORLD_WAIT_SECONDS)
end

local function shouldUseCounterMode(): boolean
	if not ClientPresentation.CounterPresentationV1Enabled then
		return false
	end
	if ClientPresentation.ForceLegacyDealUI then
		return false
	end
	if not anchors then
		return false
	end
	return true
end

local function resolveAnchors()
	if not shop then
		shop = waitForShop()
	end
	if not shop then
		anchors = nil
		return
	end
	anchors = HubWorld.resolvePresentationAnchors(shop)
	if not anchors and ClientPresentation.AutoFallbackWithoutCameraAnchors then
		warnAnchorsOnce(
			"CounterPresentation: required camera anchors missing (DealCameraSpot + CounterLookAt). Using legacy deal UI."
		)
	end
end

local function setCounterOverlayVisible(visible: boolean)
	if rootFrame then
		rootFrame.Visible = visible and not shelfFocusOverlaySuppressed
	end
end

local function applyPresentationMode(active: boolean)
	counterModeActive = active and shouldUseCounterMode()
	CustomerPresentationController:setOrchestratedMode(counterModeActive)
	ItemPresentationController:setOrchestratedMode(counterModeActive)
	if counterModeActive and anchors then
		CustomerPresentationController:setPresentationAnchors(anchors)
	end

	if counterModeActive then
		UIController:setDealPanelForceHidden(true)
		setCounterOverlayVisible(true)
	else
		UIController:setDealPanelForceHidden(false)
		setCounterOverlayVisible(false)
		CameraController:exitShopkeeperMode()
		CameraController:setFocusMode("ShopClosed")
	end
end

local function createButton(parent: Instance, name: string, text: string, width: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width, 36)
	button.BackgroundColor3 = Color3.fromRGB(58, 58, 64)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	return button
end

local function clearChildren(frame: Frame?)
	if not frame then
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function connectAction(button: TextButton, action: () -> ())
	button.MouseButton1Click:Connect(function()
		if not tacticButtonsEnabled then
			return
		end
		action()
	end)
end

local function setTacticEnabled(enabled: boolean)
	tacticButtonsEnabled = enabled
	if primaryRow then
		for _, child in primaryRow:GetDescendants() do
			if child:IsA("TextButton") then
				child.Active = enabled
				child.AutoButtonColor = enabled
				child.BackgroundTransparency = if enabled then 0 else 0.45
			end
		end
	end
	for _, row in { haggleRow, sellHaggleRow, offerSlotRow, metaRow } do
		if row then
			for _, child in row:GetDescendants() do
				if child:IsA("TextButton") then
					child.Active = enabled
					child.AutoButtonColor = enabled
					child.BackgroundTransparency = if enabled then 0 else 0.45
				end
			end
		end
	end
end

local function updatePortrait()
	if not portraitFrame then
		return
	end
	for _, child in portraitFrame:GetChildren() do
		child:Destroy()
	end

	local snapshot = currentDealSnapshot
	local letter = "?"
	if snapshot then
		local name = snapshot.customerName or snapshot.buyerName or ""
		if name ~= "" then
			letter = string.sub(name, 1, 1)
		end
	end

	local fallback = Instance.new("TextLabel")
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	fallback.BorderSizePixel = 0
	fallback.Font = Enum.Font.GothamBold
	fallback.TextSize = 36
	fallback.TextColor3 = Color3.fromRGB(220, 220, 225)
	fallback.Text = string.upper(letter)
	fallback.Parent = portraitFrame

	if not portraitWarned then
		portraitWarned = true
	end
end

local function formatCurrency(snapshot: any, amount: number?): string
	local cur = snapshot and snapshot.currencyName or "scraps"
	if amount == nil then
		return cur
	end
	return `{amount} {cur}`
end

local function phaseLabel(): string
	local shift = currentShiftSnapshot
	local snap = currentDealSnapshot
	if not shift or shift.active ~= true or shift.ended == true then
		return "Shop Closed"
	end
	if shift.phase == "ClosingRush" then
		return "Closing Rush"
	end
	if snap and snap.rareWalkInBuyer and (snap.phase == "BuyerVisit" or snap.phase == "Selling") then
		return "Rare Walk-In"
	end
	if snap and snap.phase == "Haggling" then
		return "Buying"
	end
	if snap and (snap.phase == "BuyerVisit" or snap.phase == "Selling") then
		return "Selling"
	end
	return "Shop Open"
end

local function updateHeat(snapshot: any)
	if not heatBarBg or not heatBarFill then
		return
	end
	local phase = snapshot.phase
	local show = phase == "Haggling" or phase == "Selling"
	heatBarBg.Visible = show
	if not show then
		return
	end
	local heat = if phase == "Haggling" then snapshot.sellerHeat or 0 else snapshot.buyerHeat or 0
	local maxHeat = snapshot.heatMax or HaggleTuning.heatWalkThreshold or 100
	local ratio = math.clamp(heat / math.max(maxHeat, 1), 0, 1)
	heatBarFill.Size = UDim2.new(ratio, 0, 1, 0)
end

local function buildResultText(snapshot: any): string
	local summary = snapshot.dealSummary
	if not summary then
		return ""
	end
	local lines = {}
	if summary.buyerMatchLabel then
		table.insert(lines, summary.buyerMatchLabel)
	end
	if summary.salePrice then
		table.insert(lines, `Sold for {formatCurrency(snapshot, summary.salePrice)}`)
	end
	for _, bonus in summary.bonuses or {} do
		if bonus.label and bonus.amount then
			table.insert(lines, `{bonus.label}: +{bonus.amount}`)
		end
	end
	local profit = summary.totalProfit or summary.profit
	if profit then
		local sign = if profit >= 0 then "+" else ""
		table.insert(lines, `Profit: {sign}{profit}`)
	end
	if #lines == 0 and summary.resultText then
		local firstLine = string.match(summary.resultText, "^[^\n]+")
		if firstLine then
			table.insert(lines, firstLine)
		end
	end
	return table.concat(lines, "\n")
end

local function rebuildSellerHaggleRow()
	clearChildren(haggleRow)
	local phase = currentDealSnapshot and currentDealSnapshot.phase
	if not haggleRow or not sellerHaggleExpanded or phase ~= "Haggling" then
		if haggleRow then
			haggleRow.Visible = false
		end
		return
	end
	haggleRow.Visible = true
	local buttons = {
		{ key = "split", text = "Split Diff", width = 90 },
		{ key = "flaw", text = "Flaw", width = 70 },
		{ key = "pressure", text = "Pressure", width = 90 },
		{ key = "acceptBuy", text = "Accept", width = 80 },
		{ key = "lowball", text = "Lowball", width = 80 },
	}
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = haggleRow
	for _, spec in buttons do
		local btn = createButton(haggleRow, spec.key, spec.text, spec.width)
		connectAction(btn, function()
			DealController:performBuyTactic(spec.key)
		end)
	end
end

local function rebuildSellHaggleRow()
	clearChildren(sellHaggleRow)
	local phase = currentDealSnapshot and currentDealSnapshot.phase
	if not sellHaggleRow or not sellHaggleExpanded or phase ~= "Selling" then
		if sellHaggleRow then
			sellHaggleRow.Visible = false
		end
		return
	end
	sellHaggleRow.Visible = true
	local buttons = {
		{ key = "smallBump", text = "Small Bump", width = 100 },
		{ key = "holdFirm", text = "Hold Firm", width = 90 },
		{ key = "bluff", text = "Bluff", width = 70 },
	}
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = sellHaggleRow
	for _, spec in buttons do
		local btn = createButton(sellHaggleRow, spec.key, spec.text, spec.width)
		connectAction(btn, function()
			DealController:performSellTactic(spec.key)
		end)
	end
end

local function rebuildOfferSlots(snapshot: any)
	clearChildren(offerSlotRow)
	if not offerSlotRow then
		return
	end
	offerSlotRow.Visible = snapshot.phase == "BuyerVisit"
	if snapshot.phase ~= "BuyerVisit" then
		return
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = offerSlotRow
	local matches = snapshot.inventoryMatches or {}
	for index = 1, math.min(3, #matches) do
		local match = matches[index]
		local label = match.displayName or match.itemName or `Item {index}`
		local btn = createButton(offerSlotRow, `offer{index}`, label, 140)
		connectAction(btn, function()
			if match.instanceId then
				DealController:performOfferInventoryItem(match.instanceId)
			end
		end)
	end
end

local function rebuildMetaRow(snapshot: any)
	clearChildren(metaRow)
	if not metaRow then
		return
	end
	local shift = currentShiftSnapshot
	if not shift or shift.active ~= true then
		metaRow.Visible = false
		return
	end
	metaRow.Visible = true
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = metaRow

	local phase = snapshot.phase
	local closingRush = shift.phase == "ClosingRush"
	local buyerSkipped = phase == "BuyerSkipped"
	local waitForNext = WAIT_FOR_NEXT_PHASES[phase] == true
	local shelfCount = currentInventorySnapshot
		and (currentInventorySnapshot.shelfUsedSlots or currentInventorySnapshot.displayUsedSlots)
		or 0
	local sellersRemaining = (shift.dealsRemaining or 0) > 0
	local closingRushBuyersAvailable = closingRush
		and shelfCount > 0
		and ((shift.closingRushBuyersRemaining or 0) > 0 or shift.pendingBuyerVisit == true)
	if phase == "BuyerVisit" then
		local skip = createButton(metaRow, "skipBuyer", "Skip Buyer", 110)
		connectAction(skip, function()
			DealController:performKeep()
		end)
	end
	if buyerSkipped or (waitForNext and (sellersRemaining or closingRushBuyersAvailable)) then
		local nextText = if buyerSkipped then "Continue" else "Next Customer"
		local nextBtn = createButton(metaRow, "next", nextText, 130)
		connectAction(nextBtn, function()
			DealController:performNextCustomer()
		end)
	end
	if closingRush and phase ~= "Selling" then
		local closeBtn = createButton(metaRow, "closeShop", "Close Shop", 110)
		connectAction(closeBtn, function()
			DealController:performCloseShop()
		end)
	end
end

local function rebuildPrimaryActions(snapshot: any)
	clearChildren(primaryRow)
	if not primaryRow then
		return
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = primaryRow

	local phase = snapshot.phase
	primaryRow.Visible = phase == "Haggling" or phase == "BuyerVisit" or phase == "Selling"
	if phase == "Haggling" then
		local offerBtn = createButton(primaryRow, "offer", "Offer", 90)
		connectAction(offerBtn, function()
			sellerHaggleExpanded = not sellerHaggleExpanded
			rebuildSellerHaggleRow()
		end)
		local inspectBtn = createButton(primaryRow, "inspect", "Inspect", 90)
		connectAction(inspectBtn, function()
			DealController:performInspect()
		end)
		local passBtn = createButton(primaryRow, "pass", "Pass", 80)
		connectAction(passBtn, function()
			DealController:performPass()
		end)
	elseif phase == "BuyerVisit" then
		-- slots in offerSlotRow
	elseif phase == "Selling" then
		local pitchBtn = createButton(primaryRow, "pitch", "Pitch", 90)
		connectAction(pitchBtn, function()
			DealController:performSellTactic("pitch")
		end)
		local acceptBtn = createButton(primaryRow, "acceptSell", "Accept", 90)
		connectAction(acceptBtn, function()
			DealController:performSellTactic("acceptSell")
		end)
		local declineBtn = createButton(primaryRow, "decline", "Decline", 90)
		connectAction(declineBtn, function()
			DealController:performSellTactic("findAnother")
		end)
	end
end

local function updateOverlay(snapshot: any)
	if not counterModeActive or not rootFrame then
		return
	end

	currentDealSnapshot = snapshot
	if phaseChip then
		phaseChip.Text = phaseLabel()
	end
	if rareBanner then
		local showRare = snapshot.rareWalkInBuyer == true or snapshot.buyerVisitLabel == "Rare Walk-In"
		rareBanner.Visible = showRare
		if showRare then
			rareBanner.Text = "Rare Walk-In!"
		end
	end
	if cashLabel then
		local cur = snapshot.currencyName or "scraps"
		cashLabel.Text = `Your {cur}: {snapshot.playerCash or 0}`
		cashLabel.Visible = true
	end

	local phase = snapshot.phase
	if phase ~= "Haggling" then
		sellerHaggleExpanded = false
	end
	if phase == "Selling" then
		sellHaggleExpanded = (snapshot.sellRoundCount or 0) >= 1
	else
		sellHaggleExpanded = false
	end
	if npcNameLabel then
		if phase == "Haggling" then
			npcNameLabel.Text = snapshot.customerName or "Seller"
		elseif phase == "BuyerVisit" or phase == "Selling" then
			npcNameLabel.Text = snapshot.buyerName or "Buyer"
		else
			npcNameLabel.Text = ""
		end
	end
	if dialogueLabel then
		dialogueLabel.Text = snapshot.dialogue or ""
	end
	if itemLabel then
		if phase == "Haggling" or phase == "Selling" or phase == "BuyerVisit" then
			itemLabel.Text = snapshot.itemName or ""
		else
			itemLabel.Text = ""
		end
	end
	if infoLabel then
		if phase == "Haggling" then
			infoLabel.Text =
				`Estimate: {snapshot.estimatedLow or "?"}-{snapshot.estimatedHigh or "?"}\nAsking: {snapshot.currentSellerPrice or snapshot.askingPrice or "?"}`
		elseif phase == "Selling" then
			infoLabel.Text = `Match: {snapshot.buyerMatchLabel or "?"}\nOffer: {snapshot.currentBuyerOffer or snapshot.buyerOffer or "?"}`
		elseif phase == "BuyerVisit" then
			infoLabel.Text = snapshot.buyerInterest or snapshot.buyerWants or "Choose a shelf item to offer"
		else
			infoLabel.Text = ""
		end
	end
	if resultLabel then
		if TERMINAL_PHASES[phase] then
			resultLabel.Text = buildResultText(snapshot)
			resultLabel.Visible = resultLabel.Text ~= ""
		else
			resultLabel.Visible = false
			resultLabel.Text = ""
		end
	end

	updateHeat(snapshot)
	updatePortrait()
	rebuildPrimaryActions(snapshot)
	rebuildSellerHaggleRow()
	rebuildSellHaggleRow()
	rebuildOfferSlots(snapshot)
	rebuildMetaRow(snapshot)
	CustomerPresentationController:setBillboardVisible(false)
end

local function isDealFocusPhase(phase: string?): boolean
	return phase == "Haggling" or phase == "BuyerVisit" or phase == "Selling"
end

local function handleDealPresentation(snapshot: any?)
	if not counterModeActive then
		return
	end

	if not snapshot then
		CustomerPresentationController:clearVisitor()
		ItemPresentationController:clearItem()
		setCounterOverlayVisible(false)
		CameraController:setFocusMode("Explore")
		return
	end

	local phase = snapshot.phase
	setCounterOverlayVisible(
		phase == "Haggling"
			or phase == "BuyerVisit"
			or phase == "Selling"
			or phase == "Stored"
			or TERMINAL_PHASES[phase] == true
	)

	updateOverlay(snapshot)

	if isDealFocusPhase(phase) then
		CameraController:setFocusMode("DealActive")
	else
		CameraController:setFocusMode("Explore")
	end

	if phase == "Haggling" then
		CustomerPresentationController:showSeller(snapshot)
		ItemPresentationController:showSellerItem(snapshot)
	elseif phase == "BuyerVisit" then
		CustomerPresentationController:showBuyer(snapshot)
		ItemPresentationController:showBuyerPreviewItem(snapshot)
	elseif phase == "Selling" then
		CustomerPresentationController:showBuyer(snapshot)
		ItemPresentationController:showSellingItem(snapshot)
	elseif TERMINAL_PHASES[phase] or phase == "Stored" then
		if LEAVE_CUSTOMER_PHASES[phase] then
			CustomerPresentationController:leaveVisitor()
		end
		if phase ~= "Haggling" and phase ~= "Selling" and phase ~= "BuyerVisit" then
			ItemPresentationController:clearItem()
		end
	else
		CustomerPresentationController:clearVisitor()
		ItemPresentationController:clearItem()
	end
end

local function handleShiftPresentation(snapshot: any?)
	currentShiftSnapshot = snapshot
	local shopOpen = snapshot and snapshot.active == true and snapshot.ended ~= true

	if not shopOpen then
		sellerHaggleExpanded = false
		sellHaggleExpanded = false
		applyPresentationMode(false)
		CustomerPresentationController:clearVisitor()
		ItemPresentationController:clearItem()
		return
	end

	resolveAnchors()
	applyPresentationMode(true)

	if counterModeActive and anchors then
		CameraController:enterShopkeeperMode(shop :: Instance, anchors)
		if currentDealSnapshot then
			handleDealPresentation(currentDealSnapshot)
		else
			CameraController:setFocusMode("Explore")
			setCounterOverlayVisible(false)
		end
	else
		CameraController:exitShopkeeperMode()
	end
end

local function buildOverlayUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WastelandPawnCounterUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 55
	screenGui.Parent = playerGui

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "CounterOverlay"
	rootFrame.AnchorPoint = Vector2.new(0.5, 1)
	rootFrame.Position = UDim2.new(0.5, 0, 1, -24)
	rootFrame.Size = UDim2.fromOffset(540, 300)
	rootFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	rootFrame.BackgroundTransparency = 0.15
	rootFrame.BorderSizePixel = 0
	rootFrame.Visible = false
	rootFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = rootFrame

	phaseChip = Instance.new("TextLabel")
	phaseChip.Name = "PhaseChip"
	phaseChip.Size = UDim2.fromOffset(120, 22)
	phaseChip.Position = UDim2.fromOffset(12, 8)
	phaseChip.BackgroundColor3 = Color3.fromRGB(50, 70, 90)
	phaseChip.TextColor3 = Color3.fromRGB(235, 235, 240)
	phaseChip.Font = Enum.Font.GothamBold
	phaseChip.TextSize = 12
	phaseChip.Text = "Shop Open"
	phaseChip.Parent = rootFrame

	rareBanner = Instance.new("TextLabel")
	rareBanner.Name = "RareBanner"
	rareBanner.Size = UDim2.fromOffset(140, 22)
	rareBanner.Position = UDim2.fromOffset(140, 8)
	rareBanner.BackgroundColor3 = Color3.fromRGB(120, 70, 30)
	rareBanner.TextColor3 = Color3.fromRGB(255, 230, 180)
	rareBanner.Font = Enum.Font.GothamBold
	rareBanner.TextSize = 12
	rareBanner.Text = "Rare Walk-In!"
	rareBanner.Visible = false
	rareBanner.Parent = rootFrame

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.Size = UDim2.fromOffset(200, 22)
	cashLabel.Position = UDim2.new(1, -212, 0, 8)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextSize = 13
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
	cashLabel.Text = "Your scraps: 0"
	cashLabel.Visible = false
	cashLabel.Parent = rootFrame

	portraitFrame = Instance.new("ViewportFrame")
	portraitFrame.Name = "Portrait"
	portraitFrame.Size = UDim2.fromOffset(72, 72)
	portraitFrame.Position = UDim2.fromOffset(12, 36)
	portraitFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	portraitFrame.BorderSizePixel = 0
	portraitFrame.Parent = rootFrame

	npcNameLabel = Instance.new("TextLabel")
	npcNameLabel.Size = UDim2.new(1, -100, 0, 22)
	npcNameLabel.Position = UDim2.fromOffset(96, 36)
	npcNameLabel.BackgroundTransparency = 1
	npcNameLabel.Font = Enum.Font.GothamBold
	npcNameLabel.TextSize = 18
	npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	npcNameLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	npcNameLabel.Parent = rootFrame

	dialogueLabel = Instance.new("TextLabel")
	dialogueLabel.Size = UDim2.new(1, -100, 0, 44)
	dialogueLabel.Position = UDim2.fromOffset(96, 58)
	dialogueLabel.BackgroundTransparency = 1
	dialogueLabel.Font = Enum.Font.Gotham
	dialogueLabel.TextSize = 14
	dialogueLabel.TextWrapped = true
	dialogueLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogueLabel.TextYAlignment = Enum.TextYAlignment.Top
	dialogueLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
	dialogueLabel.Parent = rootFrame

	itemLabel = Instance.new("TextLabel")
	itemLabel.Size = UDim2.new(1, -24, 0, 20)
	itemLabel.Position = UDim2.fromOffset(12, 112)
	itemLabel.BackgroundTransparency = 1
	itemLabel.Font = Enum.Font.GothamBold
	itemLabel.TextSize = 15
	itemLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	itemLabel.Parent = rootFrame

	infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -24, 0, 40)
	infoLabel.Position = UDim2.fromOffset(12, 132)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 13
	infoLabel.TextWrapped = true
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	infoLabel.Parent = rootFrame

	heatBarBg = Instance.new("Frame")
	heatBarBg.Size = UDim2.new(1, -24, 0, 8)
	heatBarBg.Position = UDim2.fromOffset(12, 174)
	heatBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	heatBarBg.BorderSizePixel = 0
	heatBarBg.Visible = false
	heatBarBg.Parent = rootFrame

	heatBarFill = Instance.new("Frame")
	heatBarFill.Size = UDim2.fromScale(0, 1)
	heatBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	heatBarFill.BorderSizePixel = 0
	heatBarFill.Parent = heatBarBg

	resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(1, -24, 0, 48)
	resultLabel.Position = UDim2.fromOffset(12, 186)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Font = Enum.Font.Gotham
	resultLabel.TextSize = 13
	resultLabel.TextWrapped = true
	resultLabel.TextXAlignment = Enum.TextXAlignment.Left
	resultLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultLabel.TextColor3 = Color3.fromRGB(180, 230, 180)
	resultLabel.Visible = false
	resultLabel.Parent = rootFrame

	primaryRow = Instance.new("Frame")
	primaryRow.Name = "PrimaryActions"
	primaryRow.Size = UDim2.new(1, -24, 0, 40)
	primaryRow.Position = UDim2.fromOffset(12, 238)
	primaryRow.BackgroundTransparency = 1
	primaryRow.Parent = rootFrame

	haggleRow = Instance.new("Frame")
	haggleRow.Name = "HaggleActions"
	haggleRow.Size = UDim2.new(1, -24, 0, 40)
	haggleRow.Position = UDim2.fromOffset(12, 200)
	haggleRow.BackgroundTransparency = 1
	haggleRow.Visible = false
	haggleRow.Parent = rootFrame

	sellHaggleRow = Instance.new("Frame")
	sellHaggleRow.Name = "SellHaggleActions"
	sellHaggleRow.Size = UDim2.new(1, -24, 0, 40)
	sellHaggleRow.Position = UDim2.fromOffset(12, 200)
	sellHaggleRow.BackgroundTransparency = 1
	sellHaggleRow.Visible = false
	sellHaggleRow.Parent = rootFrame

	offerSlotRow = Instance.new("Frame")
	offerSlotRow.Name = "OfferSlots"
	offerSlotRow.Size = UDim2.new(1, -24, 0, 40)
	offerSlotRow.Position = UDim2.fromOffset(12, 238)
	offerSlotRow.BackgroundTransparency = 1
	offerSlotRow.Visible = false
	offerSlotRow.Parent = rootFrame

	metaRow = Instance.new("Frame")
	metaRow.Name = "MetaActions"
	metaRow.Size = UDim2.new(1, -24, 0, 36)
	metaRow.Position = UDim2.fromOffset(12, 268)
	metaRow.BackgroundTransparency = 1
	metaRow.Visible = false
	metaRow.Parent = rootFrame
end

function CounterPresentationController:isCounterModeActive(): boolean
	return counterModeActive
end

function CounterPresentationController:prepareForShelfFocus()
	shelfFocusOverlaySuppressed = true
	setCounterOverlayVisible(false)
	if counterModeActive and CameraController:isShopkeeperModeActive() then
		CameraController:suspendShopkeeperForShelfFocus()
	end
end

function CounterPresentationController:restoreAfterShelfFocus()
	shelfFocusOverlaySuppressed = false
	local shopOpen = currentShiftSnapshot
		and currentShiftSnapshot.active == true
		and currentShiftSnapshot.ended ~= true
	if counterModeActive and shopOpen and anchors and shop then
		CameraController:restoreShopkeeperAfterShelfFocus(shop, anchors)
		handleDealPresentation(currentDealSnapshot)
	else
		CameraController:cancelShopkeeperShelfFocusSuspension()
	end
end

function CounterPresentationController:setLegacyDealUiForced(forced: boolean)
	ClientPresentation.ForceLegacyDealUI = forced
	if currentShiftSnapshot then
		handleShiftPresentation(currentShiftSnapshot)
	elseif forced then
		applyPresentationMode(false)
	end
end

function CounterPresentationController:Init()
	buildOverlayUi()
	resolveAnchors()

	local originalSetTactic = UIController.setTacticButtonsEnabled
	UIController.setTacticButtonsEnabled = function(self, enabled: boolean)
		originalSetTactic(self, enabled)
		setTacticEnabled(enabled)
	end
end

function CounterPresentationController:Start()
	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(function(snapshot)
		currentDealSnapshot = snapshot
		if counterModeActive then
			handleDealPresentation(snapshot)
		end
	end)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(function(snapshot)
		currentShiftSnapshot = snapshot
		handleShiftPresentation(snapshot)
	end)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(function(snapshot)
		currentInventorySnapshot = snapshot
		if counterModeActive and currentDealSnapshot then
			rebuildMetaRow(currentDealSnapshot)
		end
	end)
end

return CounterPresentationController
