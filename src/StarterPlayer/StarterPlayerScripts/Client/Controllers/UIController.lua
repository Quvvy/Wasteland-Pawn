local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)
local Shifts = require(Shared.Config.Shifts)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local labels: { [string]: TextLabel } = {}
local buttons: { [string]: TextButton } = {}
local heatBarBg: Frame
local heatBarFill: Frame

local currentSnapshot: any = nil
local currentShiftSnapshot: any = nil
local currentInventorySnapshot: any = nil
local tacticButtonsEnabled = true

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

	local lines = {
		`Inventory: {inventory.usedSlots or 0}/{inventory.maxSlots or 3}`,
	}
	for index = 1, inventory.maxSlots or 3 do
		local item = inventory.items and inventory.items[index]
		if item then
			table.insert(lines, `{index}. {item.displayName} ({item.category}) - paid {item.purchasePrice}`)
		else
			table.insert(lines, `{index}. Empty`)
		end
	end
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

local function formatInventoryMatches(matches): string
	if not matches or #matches == 0 then
		return "No inventory to offer."
	end

	local lines = {}
	for index, item in matches do
		table.insert(
			lines,
			`{index}. {item.displayName} ({item.category}) - {item.matchLabel or "Curious"} | Paid {item.purchasePrice or 0}`
		)
	end
	return table.concat(lines, "\n")
end

local function formatLiquidationSummary(summary, cur: string): string
	if not summary or (summary.itemCount or 0) <= 0 then
		return ""
	end

	local rate = liquidationRatePercent(summary.rate)
	return `\nLiquidated {summary.itemCount} item(s) at {rate}% value.\nLiquidation cash: {summary.totalCash or 0} {cur} | Profit: {formatSignedAmount(summary.totalProfit)} {cur}`
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

function UIController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WastelandPawnDealUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	root.BorderSizePixel = 0
	root.Position = UDim2.fromOffset(20, 20)
	root.Size = UDim2.fromOffset(440, 700)
	root.Parent = screenGui

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

	labels.inspect = createLabel(root, "Inspect", "", UDim2.fromOffset(12, 442), UDim2.fromOffset(416, 30))
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

	buttons.shiftScrapRush = createButton(root, "ShiftScrapRush", "Scrap Rush", UDim2.fromOffset(12, 634), UDim2.fromOffset(130, 30))
	buttons.shiftCollector = createButton(root, "ShiftCollector", "Collector Convention", UDim2.fromOffset(148, 634), UDim2.fromOffset(150, 30))
	buttons.shiftBlackMarket = createButton(root, "ShiftBlackMarket", "Black Market Night", UDim2.fromOffset(304, 634), UDim2.fromOffset(124, 30))
	buttons.shiftCollector.TextSize = 11
	buttons.shiftBlackMarket.TextSize = 11

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
	self:updateShiftSnapshot({ active = false, ended = false })
end

function UIController:getSnapshot()
	return currentSnapshot
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
	for _, button in buttons do
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.BackgroundTransparency = alpha
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
	buttons.next.Visible = hasShift and terminal and ((currentShiftSnapshot and currentShiftSnapshot.dealsRemaining or 0) > 0)

	for _, name in { "customer", "dialogue", "item", "prices", "cash", "outcome" } do
		labels[name].Visible = showDeal
	end
	heatBarBg.Visible = showDeal and (buy or sell)
	labels.heat.Visible = showDeal and (buy or sell)
	labels.tell.Visible = showDeal and (buy or sell or buyerVisit or phase == "Stored")
	labels.inspect.Visible = showDeal and buy
	labels.result.Visible = showDeal and (buyerVisit or sell or terminal)
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
	self:setPhaseControls(phase)

	local isSell = phase == "Selling"
	local isBuyerVisit = phase == "BuyerVisit"
	labels.customer.Text = if isSell or isBuyerVisit
		then `Buyer: {snapshot.buyerName or "?"}`
		else `Seller: {snapshot.customerName or "?"}`
	local readHint = if isSell or isBuyerVisit then snapshot.buyerReadHint or snapshot.buyerWants else snapshot.sellerReadHint
	labels.tell.Text = `Tell: {if isSell or isBuyerVisit then snapshot.buyerTell or "?" else snapshot.sellerTell or "?"}`
	if readHint then
		labels.tell.Text ..= `\n{readHint}`
	end
	labels.dialogue.Text = snapshot.dialogue or "..."
	if isBuyerVisit then
		labels.item.Text = "Buyer Visit\nChoose one inventory item to offer.\nA bad match can be worth skipping."
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
		if snapshot.buyerWants then
			table.insert(lines, snapshot.buyerWants)
		end
	end
	if isBuyerVisit then
		if snapshot.buyerWants then
			table.insert(lines, snapshot.buyerWants)
		end
		table.insert(lines, formatInventoryMatches(snapshot.inventoryMatches))
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
		labels.result.Text = formatInventoryMatches(snapshot.inventoryMatches)
	elseif phase == "Stored" then
		labels.result.Text = "Stored on your shelf. Wait for the right buyer."
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

	if snapshot.inspected and snapshot.inspectHint then
		labels.inspect.Text = snapshot.inspectHint
	elseif phase == "Haggling" then
		labels.inspect.Text = `Inspect ({HaggleTuning.inspectCost} {cur}) helps Point Out Flaw.`
	end

	refreshAcceptBuyButton()
end

function UIController:updateShiftSnapshot(snapshot)
	currentShiftSnapshot = snapshot or { active = false, ended = false }
	local cur = currencyLabel(currentSnapshot)

	for _, name in { "shiftScrapRush", "shiftCollector", "shiftBlackMarket" } do
		buttons[name].Visible = not currentShiftSnapshot.active
	end

	if currentShiftSnapshot.active then
		local phase = currentShiftSnapshot.phase or "Buying"
		local buyerText = if currentShiftSnapshot.pendingBuyerVisit then " | Buyer waiting" else ""
		if phase == "ClosingRush" then
			local inventoryCount = currentInventorySnapshot and currentInventorySnapshot.usedSlots or 0
			local inventoryMax = currentInventorySnapshot and currentInventorySnapshot.maxSlots or currentShiftSnapshot.inventoryMaxSlots or 3
			labels.shift.Size = UDim2.fromOffset(416, 54)
			labels.shift.Text = formatClosingRushShiftText(currentShiftSnapshot, cur, inventoryCount, inventoryMax)
		else
			local activeDealPhase = currentSnapshot and currentSnapshot.phase
			local activityText = if activeDealPhase == "BuyerVisit" or activeDealPhase == "Selling"
				then "Buyer Visit"
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
			`{resultTitle}\nTarget: {currentShiftSnapshot.targetProfit or 0} {cur} | Profit: {formatSignedAmount(currentShiftSnapshot.shiftProfit)} {cur}\nGrade: {grade}{formatLiquidationSummary(currentShiftSnapshot.liquidationSummary, cur)}`
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
end

function UIController:updateInventorySnapshot(snapshot)
	currentInventorySnapshot = snapshot
	refreshInventoryLabel()
	self:setPhaseControls(currentSnapshot and currentSnapshot.phase or "")
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

function UIController:onStartShift(callback: (string) -> ())
	buttons.shiftScrapRush.MouseButton1Click:Connect(function()
		callback("scrap_rush")
	end)
	buttons.shiftCollector.MouseButton1Click:Connect(function()
		callback("collector_convention")
	end)
	buttons.shiftBlackMarket.MouseButton1Click:Connect(function()
		callback("black_market_night")
	end)
end

function UIController:Start() end

return UIController
