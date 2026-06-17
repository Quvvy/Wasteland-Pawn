local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)
local HubWorld = require(script.Parent.HubWorld)

local ShopHubController = {}

local signWarned = false
local hubWarned = false
local boundPrompts: { [ProximityPrompt]: boolean } = {}

local OPEN_COLOR = Color3.fromRGB(80, 200, 100)
local CLOSED_COLOR = Color3.fromRGB(200, 70, 70)

local SHOP_WAIT_SECONDS = 30
local DEBUG_HUB_WARNINGS = false

local SHIFT_PART_ALIASES = {
	shiftboard = { "ShiftBoard", "Shift_Board" },
	frontdoor = { "FrontDoor", "Front_Door", "Door" },
	openclosedsign = { "OpenClosedSign", "Open_Sign", "OpenClosed", "Sign" },
}

local SHIFT_PROMPT_ALIASES = {
	"ShiftStartPrompt",
	"StartShiftPrompt",
	"ShiftBoardPrompt",
	"OpenShiftPrompt",
}

local function findChildChain(root: Instance?, ...: string): Instance?
	local current = root
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function waitForShop(): Instance?
	local world = Workspace:WaitForChild("World", SHOP_WAIT_SECONDS)
	if not world then
		return nil
	end
	return world:WaitForChild("Shop", SHOP_WAIT_SECONDS)
end

local function getOrCreatePrompt(parent: Instance, name: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = parent
	return prompt
end

local function warnOptional(message: string)
	if DEBUG_HUB_WARNINGS then
		warn(message)
	end
end

local function isShiftHubPart(instance: Instance): boolean
	local current: Instance? = instance
	while current and current ~= Workspace do
		local key = HubWorld.normalizeName(current.Name)
		if key == "door" or string.find(key, "shiftboard", 1, true) or string.find(key, "frontdoor", 1, true) then
			return true
		end
		for _, aliases in { SHIFT_PART_ALIASES.shiftboard, SHIFT_PART_ALIASES.frontdoor } do
			for _, alias in aliases do
				if HubWorld.normalizeName(alias) == key then
					return true
				end
			end
		end
		if current.Name == "Shop" then
			break
		end
		current = current.Parent
	end
	return false
end

local function isKnownShiftPromptName(prompt: ProximityPrompt): boolean
	local key = HubWorld.normalizeName(prompt.Name)
	for _, alias in SHIFT_PROMPT_ALIASES do
		if HubWorld.normalizeName(alias) == key then
			return true
		end
	end
	return false
end

local function findOpenClosedSign(shop: Instance?): Instance?
	if not shop then
		return nil
	end
	return HubWorld.findShopPart(shop, SHIFT_PART_ALIASES.openclosedsign, "sign")
		or HubWorld.findChildByNames(shop, { "OpenClosedSign" })
end

local function findSignTextTarget(sign: Instance): (Instance?, string?)
	for _, descendant in sign:GetDescendants() do
		if descendant:IsA("TextLabel") then
			return descendant, "text"
		end
	end
	if sign:IsA("BasePart") then
		return sign, "color"
	end
	return HubWorld.resolveBasePart(sign), "color"
end

local function invokeRemote(remoteName: string, ...: any): (boolean, any)
	local remote = Remotes.get(remoteName) :: RemoteFunction
	local ok, result = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if not ok then
		warn(`ShopHub remote {remoteName} failed: {result}`)
		return false, nil
	end
	return true, result
end

local function shouldBindShiftPrompt(prompt: ProximityPrompt): boolean
	if isKnownShiftPromptName(prompt) or isShiftHubPart(prompt) then
		return true
	end

	return false
end

function ShopHubController:updateOpenClosedSign(snapshot)
	local shop = findChildChain(Workspace, "World", "Shop")
	local sign = findOpenClosedSign(shop)
	if not sign then
		if not signWarned then
			signWarned = true
			local childList = if shop then HubWorld.listChildNames(shop) else "(no shop)"
			warnOptional(`ShopHub: OpenClosedSign not found under Workspace.World.Shop. Children: {childList}`)
		end
		return
	end

	local isOpen = snapshot and snapshot.active == true and snapshot.ended ~= true
	local target, mode = findSignTextTarget(sign)
	if mode == "text" and target then
		(target :: TextLabel).Text = if isOpen then "OPEN" else "CLOSED"
	elseif mode == "color" and target and target:IsA("BasePart") then
		target.Color = if isOpen then OPEN_COLOR else CLOSED_COLOR
	elseif not signWarned then
		signWarned = true
		warnOptional("ShopHub: OpenClosedSign has no TextLabel or BasePart to update")
	end
end

function ShopHubController:_onShiftStartPromptTriggered(_prompt: ProximityPrompt)
	if UIController:isShiftActive() then
		UIController:showHubMessage("Shift already in progress. Finish or end it first.")
		return
	end

	local ok, result = invokeRemote("GetShiftOptions")
	if not ok or not result or not result.ok then
		UIController:showHubMessage("Could not load shift options.")
		return
	end

	local opened = UIController:openShiftSelect(result.options)
	if not opened then
		UIController:showHubMessage("Could not open shift selection.")
	end
end

function ShopHubController:_bindShiftStartPrompt(prompt: ProximityPrompt)
	if boundPrompts[prompt] then
		return
	end
	boundPrompts[prompt] = true

	prompt.Triggered:Connect(function()
		self:_onShiftStartPromptTriggered(prompt)
	end)
end

function ShopHubController:_ensureShiftBoardPrompt(shop: Instance): boolean
	local boardPart = HubWorld.findDescendantBasePartByNames(shop, SHIFT_PART_ALIASES.shiftboard)
	if not boardPart then
		return false
	end

	local prompt = getOrCreatePrompt(boardPart, "ShiftStartPrompt")
	if prompt.ActionText == "" or prompt.ActionText == "Interact" then
		prompt.ActionText = "Open Shop"
	end
	self:_bindShiftStartPrompt(prompt)
	return true
end

function ShopHubController:_bindShopPrompts(shop: Instance): number
	local boundCount = 0

	for _, descendant in shop:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and shouldBindShiftPrompt(descendant) then
			self:_bindShiftStartPrompt(descendant)
			boundCount += 1
		end
	end

	if self:_ensureShiftBoardPrompt(shop) then
		boundCount += 1
	end

	if boundCount == 0 then
		if not hubWarned then
			hubWarned = true
			warnOptional(
				`ShopHub: No shift-start ProximityPrompts found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
			)
		end
	else
		hubWarned = false
	end

	return boundCount
end

function ShopHubController:_waitAndBindShopHub()
	local shop = waitForShop()
	if not shop then
		if not hubWarned then
			hubWarned = true
			warnOptional("ShopHub: Workspace.World.Shop not found; shift-start prompts not bound")
		end
		return
	end

	self:_bindShopPrompts(shop)

	local debounceToken = 0
	shop.DescendantAdded:Connect(function()
		debounceToken += 1
		local token = debounceToken
		task.delay(0.25, function()
			if token == debounceToken then
				self:_bindShopPrompts(shop)
			end
		end)
	end)
end

function ShopHubController:Init() end

function ShopHubController:Start()
	task.spawn(function()
		self:_waitAndBindShopHub()
	end)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(function(snapshot)
		self:updateOpenClosedSign(snapshot)
	end)

	self:updateOpenClosedSign(UIController:getShiftSnapshot())
end

return ShopHubController
