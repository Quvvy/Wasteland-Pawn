local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = require(script.Parent.UIController)

local ScavengeNodeController = {}

local WORLD_WAIT_SECONDS = 30
local PROMPT_PART_NAME = "ScavengePromptPart"
local PROMPT_NAME = "ScavengeNodePrompt"

local DEBUG_SCAVENGE = false

local boundPrompts: { [ProximityPrompt]: boolean } = {}
local promptNodeIds: { [ProximityPrompt]: string } = {}

local currentShiftSnapshot: any? = nil
local currentDealSnapshot: any? = nil
local currentInventorySnapshot: any? = nil
local actionPending = false
local nodeIdRetryQueued = false
local scanNodes: (() -> ())? = nil

local function debugLog(...)
	if DEBUG_SCAVENGE then
		warn("[ScavengeNodeController]", ...)
	end
end

local function isShiftOpen(): boolean
	return currentShiftSnapshot ~= nil
		and currentShiftSnapshot.active == true
		and currentShiftSnapshot.ended ~= true
end

local function isDealBlocking(): boolean
	local phase = currentDealSnapshot and currentDealSnapshot.phase
	return phase == "Haggling" or phase == "Selling" or phase == "BuyerVisit"
end

local function hasShelfOrStorageRoom(): boolean
	if not currentInventorySnapshot then
		return true
	end

	local shelfUsed = currentInventorySnapshot.shelfUsedSlots or 0
	local shelfMax = currentInventorySnapshot.shelfMaxSlots or 3
	local stashUsed = currentInventorySnapshot.stashUsedSlots or 0
	local stashMax = currentInventorySnapshot.stashMaxSlots or 2
	return shelfUsed < shelfMax or stashUsed < stashMax
end

local function refreshPrompts()
	local enabled = not isShiftOpen()
		and not isDealBlocking()
		and not actionPending
		and hasShelfOrStorageRoom()

	for prompt in boundPrompts do
		if prompt.Parent then
			prompt.Enabled = enabled
		else
			boundPrompts[prompt] = nil
			promptNodeIds[prompt] = nil
		end
	end
end

local function getScavengeNodesFolder(): Instance?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end

	local outside = world:FindFirstChild("Outside")
	if not outside then
		return nil
	end

	return outside:FindFirstChild("ScavengeNodes")
end

local function isValidNodeContainer(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("Folder")
end

local function findPromptPart(node: Instance): BasePart?
	local part = node:FindFirstChild(PROMPT_PART_NAME, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function getNodeId(node: Instance, prompt: ProximityPrompt): string?
	local value = node:GetAttribute("NodeId")
	if type(value) == "string" and value ~= "" then
		return value
	end

	value = prompt:GetAttribute("NodeId")
	if type(value) == "string" and value ~= "" then
		return value
	end

	return nil
end

local function invokeSearch(prompt: ProximityPrompt)
	local nodeId = promptNodeIds[prompt]
	if type(nodeId) ~= "string" or nodeId == "" then
		UIController:showHubMessage("Scavenge node not found")
		return
	end

	if actionPending or not prompt.Enabled then
		return
	end

	actionPending = true
	refreshPrompts()

	debugLog("Sending node id:", nodeId)

	local remote = Remotes.get("SearchScavengeNode") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(nodeId)
	end)

	actionPending = false
	refreshPrompts()

	if not ok or type(result) ~= "table" then
		UIController:showHubMessage("Could not search junk pile.")
		return
	end

	if result.ok == true and type(result.message) == "string" then
		UIController:showHubMessage(result.message)
		return
	end

	local errorText = if type(result.error) == "string" and result.error ~= "" then result.error else "Could not search junk pile."
	UIController:showHubMessage(errorText)
end

local function bindPrompt(node: Instance, prompt: ProximityPrompt)
	local nodeId = getNodeId(node, prompt)
	if not nodeId then
		if not nodeIdRetryQueued then
			nodeIdRetryQueued = true
			task.delay(0.25, function()
				nodeIdRetryQueued = false
				if scanNodes then
					scanNodes()
				end
			end)
		end
		return
	end

	promptNodeIds[prompt] = nodeId
	if boundPrompts[prompt] then
		return
	end

	boundPrompts[prompt] = true
	debugLog("Bound node:", nodeId, node:GetFullName())

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer and triggeringPlayer ~= Players.LocalPlayer then
			return
		end
		invokeSearch(prompt)
	end)
end

scanNodes = function()
	local scavengeNodes = getScavengeNodesFolder()
	if not scavengeNodes then
		return
	end

	for _, node in scavengeNodes:GetChildren() do
		if not isValidNodeContainer(node) then
			continue
		end

		local promptPart = findPromptPart(node)
		if not promptPart then
			continue
		end

		local prompt = promptPart:FindFirstChild(PROMPT_NAME)
		if prompt and prompt:IsA("ProximityPrompt") then
			bindPrompt(node, prompt)
		end
	end

	refreshPrompts()
end

local function watchWorld()
	local world = Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
	if not world then
		warn("ScavengeNodeController: Workspace.World not found; scavenge prompts disabled")
		return
	end

	scanNodes()

	local debounceToken = 0
	world.DescendantAdded:Connect(function(descendant)
		if descendant.Name ~= PROMPT_NAME and descendant.Name ~= PROMPT_PART_NAME and descendant.Name ~= "ScavengeNodes" then
			return
		end

		debounceToken += 1
		local token = debounceToken
		task.delay(0.2, function()
			if token == debounceToken then
				scanNodes()
			end
		end)
	end)
end

function ScavengeNodeController:Init() end

function ScavengeNodeController:Start()
	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(function(snapshot)
		currentShiftSnapshot = snapshot
		refreshPrompts()
	end)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(function(snapshot)
		currentDealSnapshot = snapshot
		refreshPrompts()
	end)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(function(snapshot)
		currentInventorySnapshot = snapshot
		refreshPrompts()
	end)

	task.spawn(watchWorld)
end

return ScavengeNodeController
