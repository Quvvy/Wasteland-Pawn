local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local labels: { [string]: TextLabel } = {}
local offerBox: TextBox
local buttons: { [string]: TextButton } = {}
local patienceBarBg: Frame
local patienceBarFill: Frame

local currentSnapshot: any = nil
local lastItemId: string? = nil
local haggleButtonsEnabled = true

local OUTCOME_DISPLAY = {
	accept = "Accepted",
	counter = "Counter",
	reject = "Rejected",
	walkaway = "Walked away",
	crack = "Intel gained",
}

local LOWBALL_DISPLAY = {
	steal = "Lowball steal!",
	crack = "Lowball intel",
	offended = "Lowball failed",
	scam_callout = "Called their bluff",
}

local function createLabel(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextSize = 16
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
	button.TextSize = 14
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
	root.Size = UDim2.fromOffset(420, 540)
	root.Parent = screenGui

	labels.title = createLabel(root, "Title", "Wasteland Pawn — Counter", UDim2.fromOffset(12, 8), UDim2.fromOffset(396, 28))
	labels.title.TextSize = 18
	labels.title.Font = Enum.Font.GothamBold

	labels.customer = createLabel(root, "Customer", "Customer: —", UDim2.fromOffset(12, 44), UDim2.fromOffset(396, 24))
	labels.dialogue = createLabel(root, "Dialogue", "...", UDim2.fromOffset(12, 72), UDim2.fromOffset(396, 56))
	labels.item = createLabel(root, "Item", "Item: —", UDim2.fromOffset(12, 132), UDim2.fromOffset(396, 48))
	labels.prices = createLabel(root, "Prices", "Ask: —", UDim2.fromOffset(12, 184), UDim2.fromOffset(396, 48))
	labels.cash = createLabel(root, "Cash", "Your caps: —", UDim2.fromOffset(12, 236), UDim2.fromOffset(396, 24))

	labels.outcome = createLabel(root, "Outcome", "", UDim2.fromOffset(12, 262), UDim2.fromOffset(396, 20))
	labels.outcome.TextSize = 14
	labels.outcome.Font = Enum.Font.GothamBold

	patienceBarBg = Instance.new("Frame")
	patienceBarBg.Name = "PatienceBarBg"
	patienceBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	patienceBarBg.BorderSizePixel = 0
	patienceBarBg.Position = UDim2.fromOffset(12, 286)
	patienceBarBg.Size = UDim2.fromOffset(396, 14)
	patienceBarBg.Parent = root

	patienceBarFill = Instance.new("Frame")
	patienceBarFill.Name = "PatienceBarFill"
	patienceBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	patienceBarFill.BorderSizePixel = 0
	patienceBarFill.Size = UDim2.new(1, 0, 1, 0)
	patienceBarFill.Parent = patienceBarBg

	labels.patience = createLabel(root, "Patience", "Patience: —", UDim2.fromOffset(12, 304), UDim2.fromOffset(396, 22))
	labels.patience.BackgroundTransparency = 1

	labels.inspect = createLabel(root, "Inspect", "", UDim2.fromOffset(12, 330), UDim2.fromOffset(396, 36))
	labels.result = createLabel(root, "Result", "", UDim2.fromOffset(12, 370), UDim2.fromOffset(396, 56))
	labels.result.Visible = false

	offerBox = Instance.new("TextBox")
	offerBox.Name = "OfferBox"
	offerBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	offerBox.BorderSizePixel = 0
	offerBox.ClearTextOnFocus = false
	offerBox.Font = Enum.Font.Gotham
	offerBox.PlaceholderText = "Offer amount (caps)"
	offerBox.Text = ""
	offerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	offerBox.TextSize = 16
	offerBox.Position = UDim2.fromOffset(12, 432)
	offerBox.Size = UDim2.fromOffset(200, 32)
	offerBox.Parent = root

	buttons.offer = createButton(root, "OfferBtn", "Make Offer", UDim2.fromOffset(220, 432), UDim2.fromOffset(90, 32))
	buttons.inspect = createButton(
		root,
		"InspectBtn",
		`Inspect ({HaggleTuning.inspectCost})`,
		UDim2.fromOffset(318, 432),
		UDim2.fromOffset(90, 32)
	)
	buttons.lowball = createButton(root, "LowballBtn", "Lowball", UDim2.fromOffset(12, 472), UDim2.fromOffset(90, 32))
	buttons.fair = createButton(root, "FairBtn", "Fair Offer", UDim2.fromOffset(108, 472), UDim2.fromOffset(90, 32))
	buttons.ask = createButton(root, "AskBtn", "Match Ask", UDim2.fromOffset(204, 472), UDim2.fromOffset(90, 32))
	buttons.acceptCounter = createButton(root, "AcceptCounterBtn", "Accept Counter", UDim2.fromOffset(12, 472), UDim2.fromOffset(130, 32))
	buttons.pass = createButton(
		root,
		"PassBtn",
		`Pass (-{HaggleTuning.passPenaltyCaps})`,
		UDim2.fromOffset(300, 472),
		UDim2.fromOffset(108, 32)
	)
	buttons.sell = createButton(root, "SellBtn", "Sell Item", UDim2.fromOffset(12, 472), UDim2.fromOffset(120, 32))
	buttons.keep = createButton(root, "KeepBtn", "Keep Item", UDim2.fromOffset(140, 472), UDim2.fromOffset(120, 32))
	buttons.next = createButton(root, "NextBtn", "Next Customer", UDim2.fromOffset(270, 472), UDim2.fromOffset(138, 32))

	buttons.acceptCounter.Visible = false
	buttons.sell.Visible = false
	buttons.keep.Visible = false
	buttons.next.Visible = false
end

function UIController:getSnapshot()
	return currentSnapshot
end

function UIController:getOfferAmount(): number?
	local amount = tonumber(offerBox.Text)
	if not amount then
		return nil
	end
	return math.floor(amount + 0.5)
end

function UIController:setOfferAmount(amount: number)
	offerBox.Text = tostring(amount)
end

function UIController:setHaggleButtonsEnabled(enabled: boolean)
	haggleButtonsEnabled = enabled
	local alpha = if enabled then 0 else 0.45
	for _, name in { "offer", "lowball", "fair", "ask", "inspect", "acceptCounter" } do
		local button = buttons[name]
		if button then
			button.Active = enabled
			button.AutoButtonColor = enabled
			button.BackgroundTransparency = alpha
		end
	end
end

local function updatePatienceBar(patience: number, maxPatience: number, patienceDelta: number?)
	local ratio = math.clamp(patience / math.max(maxPatience, 1), 0, 1)
	patienceBarFill.Size = UDim2.new(ratio, 0, 1, 0)

	if patience <= 30 then
		patienceBarFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
	elseif patience <= 60 then
		patienceBarFill.BackgroundColor3 = Color3.fromRGB(220, 180, 70)
	else
		patienceBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	end

	if patienceDelta and patienceDelta <= -10 then
		patienceBarBg.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
		task.delay(0.35, function()
			patienceBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		end)
	end
end

function UIController:setPhaseControls(phase: string)
	local haggling = phase == "Haggling" or phase == "Counter"
	local purchased = phase == "Purchased"
	local terminal = phase == "WalkedAway" or phase == "Result"

	offerBox.Visible = haggling
	buttons.offer.Visible = haggling
	buttons.inspect.Visible = haggling
	buttons.lowball.Visible = phase == "Haggling"
	buttons.fair.Visible = phase == "Haggling"
	buttons.ask.Visible = phase == "Haggling"
	buttons.acceptCounter.Visible = phase == "Counter"
	buttons.pass.Visible = haggling
	buttons.sell.Visible = purchased
	buttons.keep.Visible = purchased
	buttons.next.Visible = terminal

	patienceBarBg.Visible = haggling
	labels.patience.Visible = haggling
	labels.outcome.Visible = haggling

	labels.result.Visible = purchased or terminal
end

function UIController:updateSnapshot(snapshot)
	currentSnapshot = snapshot
	if not snapshot then
		return
	end

	local phase = snapshot.phase or "Haggling"
	self:setPhaseControls(phase)

	labels.customer.Text = `Customer: {snapshot.customerName or "?"}`
	labels.dialogue.Text = snapshot.dialogue or "..."
	labels.item.Text = `{snapshot.itemName or "?"} ({snapshot.category or "?"})`
		.. `\n{snapshot.flavorText or ""}`

	local priceLines = { `Asking: {snapshot.askingPrice or "?"} caps` }
	if snapshot.counterOffer then
		table.insert(priceLines, `Counter: {snapshot.counterOffer} caps`)
	end
	if snapshot.requiredNextOffer and snapshot.phase == "Counter" then
		table.insert(priceLines, `Need at least: {snapshot.requiredNextOffer} caps`)
	end
	if snapshot.estimatedLow and snapshot.estimatedHigh then
		table.insert(priceLines, `Estimate: {snapshot.estimatedLow}-{snapshot.estimatedHigh} caps`)
	end
	if snapshot.trueValue then
		table.insert(priceLines, `TRUE VALUE: {snapshot.trueValue} caps ({snapshot.rarityName or "?"})`)
	end
	if snapshot.purchasePrice then
		table.insert(priceLines, `Paid: {snapshot.purchasePrice} caps`)
	end
	if snapshot.profitPreview then
		table.insert(priceLines, `Sell profit preview: {snapshot.profitPreview} caps`)
	end
	labels.prices.Text = table.concat(priceLines, "\n")

	labels.cash.Text = `Your caps: {snapshot.playerCash or 0}`

	local maxPatience = snapshot.maxPatience or HaggleTuning.startingPatience
	local patience = snapshot.patience or maxPatience
	updatePatienceBar(patience, maxPatience, snapshot.patienceDelta)
	labels.patience.Text = `Patience: {patience}/{maxPatience}`

	if snapshot.lowballResult then
		local lowballText = LOWBALL_DISPLAY[snapshot.lowballResult] or snapshot.lowballResult
		labels.outcome.Text = lowballText
	elseif snapshot.lastOutcome then
		local display = OUTCOME_DISPLAY[snapshot.lastOutcome] or snapshot.lastOutcome
		local deltaText = ""
		if snapshot.patienceDelta and snapshot.patienceDelta < 0 then
			deltaText = ` ({snapshot.patienceDelta})`
		end
		labels.outcome.Text = `Last: {display}{deltaText}`
	else
		labels.outcome.Text = ""
	end

	if snapshot.repeatBlocked then
		labels.outcome.Text ..= " — raise your offer!"
	end

	if snapshot.penaltyMessage then
		labels.outcome.Text = `{labels.outcome.Text}\n{snapshot.penaltyMessage}`
	end

	if snapshot.inspected and snapshot.inspectHint then
		labels.inspect.Text = snapshot.inspectHint
	else
		labels.inspect.Text = `Inspect costs {HaggleTuning.inspectCost} caps.`
	end

	if snapshot.resultMessage or snapshot.trueValue then
		labels.result.Text = snapshot.resultMessage
			or `Revealed: {snapshot.trueValue} caps ({snapshot.rarityName}). Sell or keep?`
		labels.result.Visible = true
	else
		labels.result.Text = ""
	end

	if snapshot.itemId and snapshot.itemId ~= lastItemId then
		lastItemId = snapshot.itemId
		offerBox.Text = ""
	end

	if snapshot.askingPrice and phase ~= "Purchased" and phase ~= "Result" and phase ~= "WalkedAway" then
		if snapshot.counterOffer and phase == "Counter" then
			self:setOfferAmount(snapshot.counterOffer)
		elseif offerBox.Text == "" then
			self:setOfferAmount(math.floor(snapshot.askingPrice * 0.82))
		end
	end
end

function UIController:onOffer(callback: () -> ())
	buttons.offer.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback()
	end)
end

function UIController:onInspect(callback: () -> ())
	buttons.inspect.MouseButton1Click:Connect(callback)
end

function UIController:onPass(callback: () -> ())
	buttons.pass.MouseButton1Click:Connect(callback)
end

function UIController:onAcceptCounter(callback: () -> ())
	buttons.acceptCounter.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback()
	end)
end

function UIController:onSell(callback: () -> ())
	buttons.sell.MouseButton1Click:Connect(callback)
end

function UIController:onKeep(callback: () -> ())
	buttons.keep.MouseButton1Click:Connect(callback)
end

function UIController:onNext(callback: () -> ())
	buttons.next.MouseButton1Click:Connect(callback)
end

function UIController:onQuickOffer(callback: (string) -> ())
	buttons.lowball.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback("lowball")
	end)
	buttons.fair.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback("fair")
	end)
	buttons.ask.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback("ask")
	end)
end

function UIController:Start() end

return UIController
