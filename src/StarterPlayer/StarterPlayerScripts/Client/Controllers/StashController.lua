local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)
local HubPickupController = require(script.Parent.HubPickupController)
local HubWorld = require(script.Parent.HubWorld)

local StashController = {}

local WORLD_WAIT_SECONDS = 30
local DEBUG_STASH_WARNINGS = false

local stashPrompt: ProximityPrompt? = nil
local boundPrompts: { [ProximityPrompt]: boolean } = {}
local warnedMissing: { [string]: boolean } = {}
local actionPending = false

local function warnOnce(key: string, message: string)
	if warnedMissing[key] then
		return
	end
	warnedMissing[key] = true
	if DEBUG_STASH_WARNINGS then
		warn(message)
	end
end

local function waitForWorld(): Instance?
	return Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
end

local function formatRemoteError(prefix: string, result: any): string
	local message = if type(result) == "table" then result.error else nil
	if type(message) == "string" and message ~= "" then
		return `{prefix}: {message}`
	end
	return prefix
end

local function findExistingPrompt(root: Instance?, promptParent: Instance): ProximityPrompt?
	if not root then
		return nil
	end

	local direct = promptParent:FindFirstChild("StashPrompt")
	if direct and direct:IsA("ProximityPrompt") then
		return direct
	end

	local descendant = root:FindFirstChild("StashPrompt", true)
	if descendant and descendant:IsA("ProximityPrompt") then
		descendant.Parent = promptParent
		return descendant
	end

	return nil
end

local function getOrCreatePrompt(stash: Instance, promptParent: BasePart): ProximityPrompt
	local existing = findExistingPrompt(stash, promptParent)
	if existing then
		return existing
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StashPrompt"
	prompt.Parent = promptParent
	return prompt
end

local STORAGE_LABEL_NAME = "StorageWorldLabel"

local function ensureStorageWorldLabel(attachPart: BasePart)
	local existing = attachPart:FindFirstChild(STORAGE_LABEL_NAME)
	if existing and existing:IsA("BillboardGui") then
		local label = existing:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = "STORAGE — Saved for later"
		end
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = STORAGE_LABEL_NAME
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = attachPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(200, 220, 200)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "STORAGE — Saved for later"
	label.Parent = billboard
end

local function clearDuplicateStashPrompts(stash: Instance, keepPrompt: ProximityPrompt)
	for _, descendant in stash:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "StashPrompt" and descendant ~= keepPrompt then
			boundPrompts[descendant] = nil
			descendant:Destroy()
		end
	end
end

function StashController:_refreshPrompt()
	if not stashPrompt then
		return
	end

	if HubPickupController:isHolding() then
		stashPrompt.ActionText = "Drop in Storage"
	else
		stashPrompt.ActionText = "Open Storage"
	end
	stashPrompt.ObjectText = "Saved for later"
	stashPrompt.HoldDuration = 0
	stashPrompt.MaxActivationDistance = 10
	stashPrompt.RequiresLineOfSight = false
	stashPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
end

function StashController:_bindPrompt(prompt: ProximityPrompt)
	if boundPrompts[prompt] then
		return
	end
	boundPrompts[prompt] = true

	prompt.Triggered:Connect(function()
		if HubPickupController:isHolding() then
			HubPickupController:dropHeldInStash()
			self:_refreshPrompt()
			return
		end

		UIController:openStash()
	end)
end

function StashController:_resolvePrompt(world: Instance?): ProximityPrompt?
	if stashPrompt and stashPrompt.Parent then
		self:_refreshPrompt()
		return stashPrompt
	end

	world = world or waitForWorld()
	if not world then
		warnOnce("world", "StashController: Workspace.World not found; stash disabled")
		return nil
	end

	local shop = HubWorld.findChildByNames(world, { "Shop" })
	local stash = HubWorld.findStashBin(shop)
	if not stash then
		warnOnce("stash_bin", `StashController: StashBin not found. Shop children: {HubWorld.listChildNames(shop)}`)
		return nil
	end

	local promptParent = HubWorld.resolveBasePart(stash)
	if not promptParent then
		warnOnce("stash_part", "StashController: StashBin has no BasePart for ProximityPrompt")
		return nil
	end

	local prompt = getOrCreatePrompt(stash, promptParent)
	stashPrompt = prompt
	clearDuplicateStashPrompts(stash, prompt)
	ensureStorageWorldLabel(promptParent)
	self:_refreshPrompt()
	self:_bindPrompt(prompt)
	return prompt
end

function StashController:_invokeStashRoute(remoteName: string, instanceId: string)
	if actionPending then
		return
	end

	actionPending = true
	UIController:setStashActionsEnabled(false)

	local remote = Remotes.get(remoteName) :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(instanceId)
	end)

	actionPending = false
	UIController:setStashActionsEnabled(true)

	if not ok or type(result) ~= "table" or result.ok ~= true then
		local message = if ok then formatRemoteError("Could not move item", result) else `Could not move item: {result}`
		UIController:showHubMessage(message)
	end
end

function StashController:_watchWorld()
	local world = waitForWorld()
	if not world then
		warnOnce("world", "StashController: Workspace.World not found; stash disabled")
		return
	end

	self:_resolvePrompt(world)

	local debounceToken = 0
	world.DescendantAdded:Connect(function()
		debounceToken += 1
		local token = debounceToken
		task.delay(0.25, function()
			if token == debounceToken then
				self:_resolvePrompt(world)
			end
		end)
	end)
end

function StashController:Init() end

function StashController:Start()
	UIController:onStashAction(function(remoteName: string, instanceId: string)
		self:_invokeStashRoute(remoteName, instanceId)
	end)

	HubPickupController:onHoldingChanged(function()
		self:_refreshPrompt()
	end)

	task.spawn(function()
		self:_watchWorld()
	end)
end

return StashController
