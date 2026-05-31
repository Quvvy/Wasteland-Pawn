local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local labels: { [string]: TextLabel } = {}
local buttons: { [string]: TextButton } = {}
local heatBarBg: Frame
local heatBarFill: Frame

local currentSnapshot: any = nil
local tacticButtonsEnabled = true

local TACTIC_RESULT_DISPLAY = {
	price_drop = "Price dropped",
	price_raise = "Offer raised",
	warning = "Warning",
	walkaway = "Walked away",
	crack = "Intel gained",
	big_win = "Big win!",
	accept = "Accepted",
}

local function currencyLabel(snapshot: any?): string
	return (snapshot and snapshot.currencyName) or HaggleTuning.currencyName or "scraps"
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
	root.Size = UDim2.fromOffset(440, 620)
	root.Parent = screenGui

	labels.title = createLabel(root, "Title", "Wasteland Pawn — Tactics", UDim2.fromOffset(12, 8), UDim2.fromOffset(416, 26))
	labels.title.TextSize = 17
	labels.title.Font = Enum.Font.GothamBold

	labels.customer = createLabel(root, "Customer", "Trader: -", UDim2.fromOffset(12, 38), UDim2.fromOffset(416, 22))
	labels.tell = createLabel(root, "Tell", "Tell: -", UDim2.fromOffset(12, 62), UDim2.fromOffset(416, 36))
	labels.tell.TextColor3 = Color3.fromRGB(180, 220, 255)

	labels.dialogue = createLabel(root, "Dialogue", "...", UDim2.fromOffset(12, 100), UDim2.fromOffset(416, 48))
	labels.item = createLabel(root, "Item", "Item: -", UDim2.fromOffset(12, 150), UDim2.fromOffset(416, 44))
	labels.prices = createLabel(root, "Prices", "", UDim2.fromOffset(12, 196), UDim2.fromOffset(416, 52))
	labels.cash = createLabel(root, "Cash", "Your scraps: -", UDim2.fromOffset(12, 250), UDim2.fromOffset(416, 22))

	labels.outcome = createLabel(root, "Outcome", "", UDim2.fromOffset(12, 274), UDim2.fromOffset(416, 20))
	labels.outcome.Font = Enum.Font.GothamBold

	heatBarBg = Instance.new("Frame")
	heatBarBg.Name = "HeatBarBg"
	heatBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	heatBarBg.BorderSizePixel = 0
	heatBarBg.Position = UDim2.fromOffset(12, 298)
	heatBarBg.Size = UDim2.fromOffset(416, 16)
	heatBarBg.Parent = root

	heatBarFill = Instance.new("Frame")
	heatBarFill.Name = "HeatBarFill"
	heatBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	heatBarFill.BorderSizePixel = 0
	heatBarFill.Size = UDim2.new(0, 0, 1, 0)
	heatBarFill.Parent = heatBarBg

	labels.heat = createLabel(root, "Heat", "Heat: 0", UDim2.fromOffset(12, 318), UDim2.fromOffset(416, 22))
	labels.heat.BackgroundTransparency = 1

	labels.inspect = createLabel(root, "Inspect", "", UDim2.fromOffset(12, 342), UDim2.fromOffset(416, 32))
	labels.result = createLabel(root, "Result", "", UDim2.fromOffset(12, 376), UDim2.fromOffset(416, 80))
	labels.result.Visible = false

	-- Buy tactics
	buttons.lowball = createButton(root, "Lowball", "Lowball", UDim2.fromOffset(12, 464), UDim2.fromOffset(98, 30))
	buttons.split = createButton(root, "Split", "Split Diff", UDim2.fromOffset(116, 464), UDim2.fromOffset(98, 30))
	buttons.flaw = createButton(root, "Flaw", "Point Flaw", UDim2.fromOffset(220, 464), UDim2.fromOffset(98, 30))
	buttons.pressure = createButton(root, "Pressure", "Pressure", UDim2.fromOffset(324, 464), UDim2.fromOffset(104, 30))
	buttons.acceptBuy = createButton(root, "AcceptBuy", "Accept Price", UDim2.fromOffset(12, 500), UDim2.fromOffset(130, 30))
	buttons.pass = createButton(root, "Pass", "Pass", UDim2.fromOffset(148, 500), UDim2.fromOffset(80, 30))
	buttons.inspectBtn = createButton(
		root,
		"InspectBtn",
		`Inspect ({HaggleTuning.inspectCost})`,
		UDim2.fromOffset(234, 500),
		UDim2.fromOffset(100, 30)
	)

	-- Sell tactics
	buttons.smallBump = createButton(root, "SmallBump", "Small Bump", UDim2.fromOffset(12, 464), UDim2.fromOffset(98, 30))
	buttons.pitch = createButton(root, "Pitch", "Pitch Value", UDim2.fromOffset(116, 464), UDim2.fromOffset(98, 30))
	buttons.holdFirm = createButton(root, "HoldFirm", "Hold Firm", UDim2.fromOffset(220, 464), UDim2.fromOffset(98, 30))
	buttons.bluff = createButton(root, "Bluff", "Bluff", UDim2.fromOffset(324, 464), UDim2.fromOffset(104, 30))
	buttons.acceptSell = createButton(root, "AcceptSell", "Accept Offer", UDim2.fromOffset(12, 500), UDim2.fromOffset(130, 30))
	buttons.findBuyer = createButton(root, "FindBuyer", "Find Buyer", UDim2.fromOffset(12, 500), UDim2.fromOffset(120, 30))
	buttons.findAnother = createButton(root, "FindAnother", "Another Buyer", UDim2.fromOffset(148, 500), UDim2.fromOffset(120, 30))
	buttons.keep = createButton(root, "Keep", "Keep Item", UDim2.fromOffset(276, 500), UDim2.fromOffset(100, 30))
	buttons.next = createButton(root, "Next", "Next Customer", UDim2.fromOffset(276, 500), UDim2.fromOffset(152, 30))

	local sellOnly = {
		"smallBump",
		"pitch",
		"holdFirm",
		"bluff",
		"acceptSell",
		"findAnother",
	}
	for _, name in sellOnly do
		buttons[name].Visible = false
	end
	buttons.next.Visible = false
end

function UIController:getSnapshot()
	return currentSnapshot
end

function UIController:setTacticButtonsEnabled(enabled: boolean)
	tacticButtonsEnabled = enabled
	local alpha = if enabled then 0 else 0.45
	for _, button in buttons do
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.BackgroundTransparency = alpha
	end
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
	local buy = phase == "Haggling"
	local purchased = phase == "Purchased"
	local sell = phase == "Selling"
	local terminal = phase == "WalkedAway" or phase == "Result"

	for _, name in { "lowball", "split", "flaw", "pressure", "acceptBuy", "pass", "inspectBtn" } do
		buttons[name].Visible = buy
	end
	for _, name in { "smallBump", "pitch", "holdFirm", "bluff", "acceptSell", "findAnother" } do
		buttons[name].Visible = sell
	end
	buttons.findBuyer.Visible = purchased
	buttons.keep.Visible = purchased or sell
	buttons.next.Visible = terminal

	heatBarBg.Visible = buy or sell
	labels.heat.Visible = buy or sell
	labels.tell.Visible = buy or sell or purchased
	labels.inspect.Visible = buy
	labels.result.Visible = purchased or sell or terminal
end

function UIController:updateSnapshot(snapshot)
	currentSnapshot = snapshot
	if not snapshot then
		return
	end

	local phase = snapshot.phase or "Haggling"
	local cur = currencyLabel(snapshot)
	self:setPhaseControls(phase)

	local isSell = phase == "Selling"
	labels.customer.Text = if isSell
		then `Buyer: {snapshot.buyerName or "?"}`
		else `Seller: {snapshot.customerName or "?"}`
	labels.tell.Text = `Tell: {if isSell then snapshot.buyerTell or "?" else snapshot.sellerTell or "?"}`
	labels.dialogue.Text = snapshot.dialogue or "..."
	labels.item.Text = `{snapshot.itemName or "?"} ({snapshot.category or "?"})\n{snapshot.flavorText or ""}`

	local lines = {}
	if phase == "Haggling" or phase == "Purchased" then
		if snapshot.currentSellerPrice then
			table.insert(lines, `Seller price: {snapshot.currentSellerPrice} {cur}`)
		end
		if snapshot.originalAskingPrice and snapshot.originalAskingPrice ~= snapshot.currentSellerPrice then
			table.insert(lines, `Started at: {snapshot.originalAskingPrice} {cur}`)
		end
	end
	if isSell and snapshot.currentBuyerOffer then
		table.insert(lines, `Buyer offer: {snapshot.currentBuyerOffer} {cur}`)
		if snapshot.buyerMaximum then
			table.insert(lines, `Buyer max (~): {snapshot.buyerMaximum} {cur}`)
		end
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
	labels.prices.Text = if #lines > 0 then table.concat(lines, "\n") else "—"

	labels.cash.Text = `Your {cur}: {snapshot.playerCash or 0}`

	local heat = if isSell then snapshot.buyerHeat or 0 else snapshot.sellerHeat or 0
	local heatMax = if isSell then snapshot.buyerHeatMax or 100 else snapshot.sellerHeatMax or 100
	updateHeatBar(heat, heatMax)
	labels.heat.Text = `{if isSell then "Buyer" else "Seller"} heat: {heat}/{heatMax}`
	if snapshot.heatWarning then
		labels.heat.Text ..= ` — {snapshot.heatWarning}`
	end

	if snapshot.lastTacticResult then
		local display = TACTIC_RESULT_DISPLAY[snapshot.lastTacticResult] or snapshot.lastTacticResult
		labels.outcome.Text = `Last: {snapshot.lastTactic or "?"} → {display}`
	else
		labels.outcome.Text = ""
	end

	if snapshot.dealSummary then
		labels.result.Text = snapshot.dealSummary.resultText or ""
	elseif snapshot.trueValue and phase == "Purchased" then
		labels.result.Text = `True value: {snapshot.trueValue} {cur}. Find a buyer.`
	else
		labels.result.Text = ""
	end

	if snapshot.inspected and snapshot.inspectHint then
		labels.inspect.Text = snapshot.inspectHint
	elseif phase == "Haggling" then
		labels.inspect.Text = `Inspect ({HaggleTuning.inspectCost} {cur}) helps Point Out Flaw.`
	end
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

function UIController:onKeep(callback: () -> ())
	buttons.keep.MouseButton1Click:Connect(callback)
end

function UIController:onNext(callback: () -> ())
	buttons.next.MouseButton1Click:Connect(callback)
end

function UIController:Start() end

return UIController
