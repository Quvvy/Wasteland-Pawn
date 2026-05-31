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

local function currencyLabel(snapshot: any?): string
	if snapshot and snapshot.currencyName then
		return snapshot.currencyName
	end
	return HaggleTuning.currencyName or "scraps"
end

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
	root.Size = UDim2.fromOffset(420, 560)
	root.Parent = screenGui

	labels.title = createLabel(root, "Title", "Wasteland Pawn - Counter", UDim2.fromOffset(12, 8), UDim2.fromOffset(396, 28))
	labels.title.TextSize = 18
	labels.title.Font = Enum.Font.GothamBold

	labels.customer = createLabel(root, "Customer", "Trader: -", UDim2.fromOffset(12, 44), UDim2.fromOffset(396, 24))
	labels.dialogue = createLabel(root, "Dialogue", "...", UDim2.fromOffset(12, 72), UDim2.fromOffset(396, 56))
	labels.item = createLabel(root, "Item", "Item: -", UDim2.fromOffset(12, 132), UDim2.fromOffset(396, 48))
	labels.prices = createLabel(root, "Prices", "Ask: -", UDim2.fromOffset(12, 184), UDim2.fromOffset(396, 56))
	labels.cash = createLabel(root, "Cash", "Your scraps: -", UDim2.fromOffset(12, 244), UDim2.fromOffset(396, 24))

	labels.outcome = createLabel(root, "Outcome", "", UDim2.fromOffset(12, 270), UDim2.fromOffset(396, 20))
	labels.outcome.TextSize = 14
	labels.outcome.Font = Enum.Font.GothamBold

	patienceBarBg = Instance.new("Frame")
	patienceBarBg.Name = "PatienceBarBg"
	patienceBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	patienceBarBg.BorderSizePixel = 0
	patienceBarBg.Position = UDim2.fromOffset(12, 294)
	patienceBarBg.Size = UDim2.fromOffset(396, 14)
	patienceBarBg.Parent = root

	patienceBarFill = Instance.new("Frame")
	patienceBarFill.Name = "PatienceBarFill"
	patienceBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	patienceBarFill.BorderSizePixel = 0
	patienceBarFill.Size = UDim2.new(1, 0, 1, 0)
	patienceBarFill.Parent = patienceBarBg

	labels.patience = createLabel(root, "Patience", "Patience: -", UDim2.fromOffset(12, 312), UDim2.fromOffset(396, 22))
	labels.patience.BackgroundTransparency = 1

	labels.inspect = createLabel(root, "Inspect", "", UDim2.fromOffset(12, 338), UDim2.fromOffset(396, 36))
	labels.result = createLabel(root, "Result", "", UDim2.fromOffset(12, 378), UDim2.fromOffset(396, 72))
	labels.result.Visible = false

	offerBox = Instance.new("TextBox")
	offerBox.Name = "OfferBox"
	offerBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	offerBox.BorderSizePixel = 0
	offerBox.ClearTextOnFocus = false
	offerBox.Font = Enum.Font.Gotham
	offerBox.PlaceholderText = "Amount (scraps)"
	offerBox.Text = ""
	offerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	offerBox.TextSize = 16
	offerBox.Position = UDim2.fromOffset(12, 456)
	offerBox.Size = UDim2.fromOffset(200, 32)
	offerBox.Parent = root

	buttons.offer = createButton(root, "OfferBtn", "Make Offer", UDim2.fromOffset(220, 456), UDim2.fromOffset(90, 32))
	buttons.inspect = createButton(
		root,
		"InspectBtn",
		`Inspect ({HaggleTuning.inspectCost})`,
		UDim2.fromOffset(318, 456),
		UDim2.fromOffset(90, 32)
	)
	buttons.lowball = createButton(root, "LowballBtn", "Lowball", UDim2.fromOffset(12, 496), UDim2.fromOffset(90, 32))
	buttons.fair = createButton(root, "FairBtn", "Fair Offer", UDim2.fromOffset(108, 496), UDim2.fromOffset(90, 32))
	buttons.ask = createButton(root, "AskBtn", "Match Ask", UDim2.fromOffset(204, 496), UDim2.fromOffset(90, 32))
	buttons.acceptCounter = createButton(root, "AcceptCounterBtn", "Accept Counter", UDim2.fromOffset(12, 496), UDim2.fromOffset(130, 32))
	buttons.pass = createButton(root, "PassBtn", "Pass", UDim2.fromOffset(300, 496), UDim2.fromOffset(108, 32))
	buttons.findBuyer = createButton(root, "FindBuyerBtn", "Find Buyer", UDim2.fromOffset(12, 496), UDim2.fromOffset(120, 32))
	buttons.acceptBuyer = createButton(root, "AcceptBuyerBtn", "Accept Offer", UDim2.fromOffset(140, 496), UDim2.fromOffset(120, 32))
	buttons.sellBump = createButton(root, "SellBumpBtn", "Ask +10%", UDim2.fromOffset(12, 496), UDim2.fromOffset(90, 32))
	buttons.keep = createButton(root, "KeepBtn", "Keep Item", UDim2.fromOffset(270, 496), UDim2.fromOffset(138, 32))
	buttons.next = createButton(root, "NextBtn", "Next Customer", UDim2.fromOffset(270, 496), UDim2.fromOffset(138, 32))

	for _, name in { "acceptCounter", "findBuyer", "acceptBuyer", "sellBump", "keep", "next" } do
		buttons[name].Visible = false
	end
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
	for _, name in { "offer", "lowball", "fair", "ask", "inspect", "acceptCounter", "acceptBuyer", "sellBump" } do
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
	local buyHaggle = phase == "Haggling" or phase == "Counter"
	local purchased = phase == "Purchased"
	local sellHaggle = phase == "Selling" or phase == "BuyerCounter"
	local terminal = phase == "WalkedAway" or phase == "Result"

	offerBox.Visible = buyHaggle or sellHaggle
	offerBox.PlaceholderText = if sellHaggle then "Your ask (scraps)" else "Offer amount (scraps)"

	buttons.offer.Visible = buyHaggle or sellHaggle
	buttons.offer.Text = if sellHaggle then "Make Ask" else "Make Offer"

	buttons.inspect.Visible = buyHaggle
	buttons.lowball.Visible = phase == "Haggling"
	buttons.fair.Visible = buyHaggle and not sellHaggle
	buttons.ask.Visible = buyHaggle and not sellHaggle
	buttons.acceptCounter.Visible = phase == "Counter"
	buttons.findBuyer.Visible = purchased
	buttons.acceptBuyer.Visible = sellHaggle
	buttons.sellBump.Visible = sellHaggle
	buttons.pass.Visible = buyHaggle or sellHaggle
	buttons.keep.Visible = purchased or sellHaggle
	buttons.next.Visible = terminal

	patienceBarBg.Visible = buyHaggle or sellHaggle
	labels.patience.Visible = buyHaggle or sellHaggle
	labels.outcome.Visible = buyHaggle or sellHaggle or purchased
	labels.inspect.Visible = buyHaggle
	labels.result.Visible = purchased or sellHaggle or terminal
end

function UIController:updateSnapshot(snapshot)
	currentSnapshot = snapshot
	if not snapshot then
		return
	end

	local phase = snapshot.phase or "Haggling"
	local cur = currencyLabel(snapshot)
	self:setPhaseControls(phase)

	local traderLabel = if phase == "Selling" or phase == "BuyerCounter"
		then `Buyer: {snapshot.buyerName or "?"}`
		else `Seller: {snapshot.customerName or "?"}`
	labels.customer.Text = traderLabel
	labels.dialogue.Text = snapshot.dialogue or "..."
	labels.item.Text = `{snapshot.itemName or "?"} ({snapshot.category or "?"})`
		.. `\n{snapshot.flavorText or ""}`

	local priceLines = {}
	if snapshot.askingPrice and phase ~= "Selling" and phase ~= "BuyerCounter" then
		table.insert(priceLines, `Seller ask: {snapshot.askingPrice} {cur}`)
	end
	if snapshot.counterOffer and (phase == "Counter" or phase == "Haggling") then
		table.insert(priceLines, `Seller counter: {snapshot.counterOffer} {cur}`)
	end
	if snapshot.buyerOffer and (phase == "Selling" or phase == "BuyerCounter" or phase == "Purchased") then
		table.insert(priceLines, `Buyer offer: {snapshot.buyerOffer} {cur}`)
	end
	if snapshot.buyerCounterOffer and phase == "BuyerCounter" then
		table.insert(priceLines, `Buyer counter: {snapshot.buyerCounterOffer} {cur}`)
	end
	if snapshot.requiredNextOffer and (phase == "Counter" or phase == "BuyerCounter") then
		table.insert(priceLines, `Need at least: {snapshot.requiredNextOffer} {cur}`)
	end
	if snapshot.estimatedLow and snapshot.estimatedHigh and phase ~= "Result" then
		table.insert(priceLines, `Estimate: {snapshot.estimatedLow}-{snapshot.estimatedHigh} {cur}`)
	end
	if snapshot.trueValue then
		table.insert(priceLines, `TRUE VALUE: {snapshot.trueValue} {cur} ({snapshot.rarityName or "?"})`)
	end
	if snapshot.purchasePrice then
		table.insert(priceLines, `Paid: {snapshot.purchasePrice} {cur}`)
	end
	if snapshot.salePrice then
		table.insert(priceLines, `Sold for: {snapshot.salePrice} {cur}`)
	end
	if #priceLines == 0 then
		table.insert(priceLines, "—")
	end
	labels.prices.Text = table.concat(priceLines, "\n")

	labels.cash.Text = `Your {cur}: {snapshot.playerCash or 0}`

	local isSell = phase == "Selling" or phase == "BuyerCounter"
	local patience = if isSell then snapshot.buyerPatience else snapshot.patience
	local maxPatience = if isSell then snapshot.buyerMaxPatience else snapshot.maxPatience
	patience = patience or maxPatience or HaggleTuning.startingPatience
	maxPatience = maxPatience or HaggleTuning.startingPatience
	updatePatienceBar(patience, maxPatience, snapshot.patienceDelta)
	labels.patience.Text = `{if isSell then "Buyer" else "Seller"} patience: {patience}/{maxPatience}`

	if snapshot.buyRoundCount or snapshot.sellRoundCount then
		labels.patience.Text ..= ` | Buy rounds: {snapshot.buyRoundCount or 0} Sell: {snapshot.sellRoundCount or 0}`
	end

	if snapshot.lowballResult then
		labels.outcome.Text = LOWBALL_DISPLAY[snapshot.lowballResult] or snapshot.lowballResult
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
		labels.outcome.Text ..= " — raise your amount!"
	end

	if snapshot.dealSummary then
		local s = snapshot.dealSummary
		labels.result.Text = snapshot.resultMessage
			or `{s.resultText}\nBuy rounds: {s.buyRounds} | Sell rounds: {s.sellRounds} | Inspected: {s.inspected}`
	elseif snapshot.resultMessage then
		labels.result.Text = snapshot.resultMessage
	elseif snapshot.trueValue and phase == "Purchased" then
		labels.result.Text = `True value: {snapshot.trueValue} {cur}. Find a buyer or keep.`
	else
		labels.result.Text = ""
	end

	if snapshot.inspected and snapshot.inspectHint then
		labels.inspect.Text = snapshot.inspectHint
	elseif phase == "Haggling" or phase == "Counter" then
		labels.inspect.Text = `Inspect costs {HaggleTuning.inspectCost} {cur}.`
	end

	if snapshot.itemId and snapshot.itemId ~= lastItemId then
		lastItemId = snapshot.itemId
		offerBox.Text = ""
	end

	if phase == "Haggling" and snapshot.askingPrice and offerBox.Text == "" then
		self:setOfferAmount(math.floor(snapshot.askingPrice * 0.82))
	elseif phase == "Counter" and snapshot.counterOffer then
		self:setOfferAmount(snapshot.counterOffer)
	elseif (phase == "Selling" or phase == "BuyerCounter") and offerBox.Text == "" then
		local base = snapshot.buyerCounterOffer or snapshot.buyerOffer or snapshot.trueValue or 0
		self:setOfferAmount(math.floor(base * 1.15))
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

function UIController:onFindBuyer(callback: () -> ())
	buttons.findBuyer.MouseButton1Click:Connect(callback)
end

function UIController:onAcceptBuyer(callback: () -> ())
	buttons.acceptBuyer.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback()
	end)
end

function UIController:onSellBump(callback: () -> ())
	buttons.sellBump.MouseButton1Click:Connect(function()
		if not haggleButtonsEnabled then
			return
		end
		callback()
	end)
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
