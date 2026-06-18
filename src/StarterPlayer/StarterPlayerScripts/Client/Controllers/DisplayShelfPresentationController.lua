local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local ItemVisuals = require(Shared.Config.ItemVisuals)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)

local HubWorld = require(script.Parent.HubWorld)
local ItemPropBuilder = require(script.Parent.ItemPropBuilder)

local DisplayShelfPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubDisplayLocal"
local DEFAULT_DISPLAY_SLOTS = 3
local RETURN_PROMPT_NAME = "DisplayShelfPrimaryPrompt"

local displayShelf: Instance? = nil
local slotParts: { [number]: BasePart? } = {}
local localFolder: Folder? = nil
local slotModels: { [number]: Model? } = {}
local slotKeys: { [number]: string? } = {}
local slotReturnPrompts: { [number]: ProximityPrompt? } = {}
local boundReturnPrompts: { [ProximityPrompt]: boolean } = {}

local shiftActive = false
local lastInventorySnapshot: any? = nil
local returnTogglePending = false

local shelfWarned = false
local slotWarned = false

local function warnShelfOnce(message: string)
	if shelfWarned then
		return
	end
	shelfWarned = true
	warn(message)
end

local function warnSlotOnce(message: string)
	if slotWarned then
		return
	end
	slotWarned = true
	warn(message)
end

local function waitForWorld(): Instance?
	return Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
end

local function waitForShop(): Instance?
	local world = waitForWorld()
	if not world then
		return nil
	end
	return world:WaitForChild("Shop", WORLD_WAIT_SECONDS)
end

local function ensureLocalFolder(world: Instance): Folder
	if localFolder and localFolder.Parent then
		return localFolder
	end

	local existing = world:FindFirstChild(LOCAL_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		localFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LOCAL_FOLDER_NAME
	folder.Parent = world
	localFolder = folder
	return folder
end

local function resolveDisplayShelf(): Instance?
	if displayShelf and displayShelf.Parent then
		return displayShelf
	end

	local shop = waitForShop()
	if not shop then
		warnShelfOnce("DisplayShelfPresentation: Workspace.World.Shop not found; display shelf disabled.")
		return nil
	end

	local shelf = HubWorld.findDisplayShelf(shop)
	if not shelf then
		warnShelfOnce(
			`DisplayShelfPresentation: DisplayShelf not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
		)
		return nil
	end

	displayShelf = shelf
	return shelf
end

local function resolveSlotPart(slotIndex: number): BasePart?
	local cached = slotParts[slotIndex]
	if cached and cached.Parent then
		return cached
	end

	local shelf = resolveDisplayShelf()
	if not shelf then
		return nil
	end

	local part = HubWorld.findDisplayShelfSlot(shelf, slotIndex)
	if not part then
		warnSlotOnce(
			`DisplayShelfPresentation: DisplaySlot{slotIndex} not found under DisplayShelf. Children: {HubWorld.listChildNames(shelf)}`
		)
		return nil
	end

	slotParts[slotIndex] = part
	return part
end

local function findPromptAttachPart(model: Model): BasePart?
	local promptPart = model:FindFirstChild("PromptPart")
	if promptPart and promptPart:IsA("BasePart") then
		return promptPart
	end

	local labelPart = model:FindFirstChild("LabelPart")
	if labelPart and labelPart:IsA("BasePart") then
		return labelPart
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function displaySubtitle(entry: any): string
	if entry.category and entry.category ~= "" then
		return `On Display - {entry.category}`
	end
	return "On Display"
end

local function formatRemoteError(prefix: string, result: any): string
	local message = if type(result) == "table" then result.error else nil
	if type(message) == "string" and message ~= "" then
		return `{prefix}: {message}`
	end
	return prefix
end

local function clearExtraPrompts(model: Model, keepPrompt: ProximityPrompt?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant ~= keepPrompt then
			boundReturnPrompts[descendant] = nil
			descendant:Destroy()
		end
	end
end

local function findReturnPrompt(model: Model): ProximityPrompt?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == RETURN_PROMPT_NAME then
			return descendant
		end
	end
	return nil
end

local function getOrCreateReturnPrompt(model: Model, attachPart: BasePart): ProximityPrompt
	local existing = findReturnPrompt(model)
	if existing and existing.Parent == attachPart then
		clearExtraPrompts(model, existing)
		return existing
	elseif existing then
		boundReturnPrompts[existing] = nil
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = RETURN_PROMPT_NAME
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachPart
	clearExtraPrompts(model, prompt)
	return prompt
end

local function removeReturnPrompt(slotIndex: number)
	local prompt = slotReturnPrompts[slotIndex]
	if prompt then
		boundReturnPrompts[prompt] = nil
		prompt:Destroy()
	end
	slotReturnPrompts[slotIndex] = nil
end

local function clearAllReturnPrompts()
	for slotIndex, prompt in slotReturnPrompts do
		if prompt then
			boundReturnPrompts[prompt] = nil
			prompt:Destroy()
		end
		slotReturnPrompts[slotIndex] = nil
	end
end

local function returnDisplayItem(instanceId: string)
	if returnTogglePending or not shiftActive then
		return
	end

	returnTogglePending = true
	for _, prompt in slotReturnPrompts do
		if prompt then
			prompt.Enabled = false
		end
	end

	local remote = Remotes.get("ReturnDisplayItemToInventory") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(instanceId)
	end)

	returnTogglePending = false

	if not ok or type(result) ~= "table" or result.ok ~= true then
		local message = if ok
			then formatRemoteError("Could not return item", result)
			else `Could not return item: {result}`
		local uiOk, UIController = pcall(require, script.Parent.UIController)
		if uiOk then
			UIController:showHubMessage(message)
		else
			warn(message)
		end
		DisplayShelfPresentationController:syncAllReturnPrompts()
		return
	end
end

local function bindReturnPrompt(prompt: ProximityPrompt)
	if boundReturnPrompts[prompt] then
		return
	end
	boundReturnPrompts[prompt] = true

	prompt.Triggered:Connect(function()
		local instanceId = prompt:GetAttribute("InstanceId")
		if type(instanceId) ~= "string" then
			return
		end

		returnDisplayItem(instanceId)
	end)
end

function DisplayShelfPresentationController:syncReturnPrompt(slotIndex: number, entry: any, model: Model)
	if not shiftActive then
		removeReturnPrompt(slotIndex)
		return
	end

	local attachPart = findPromptAttachPart(model)
	if not attachPart then
		removeReturnPrompt(slotIndex)
		clearExtraPrompts(model, nil)
		return
	end

	local prompt = getOrCreateReturnPrompt(model, attachPart)
	slotReturnPrompts[slotIndex] = prompt
	prompt:SetAttribute("InstanceId", entry.instanceId)

	prompt.ActionText = "Return to Shelf"
	prompt.ObjectText = entry.category or ""
	prompt.Enabled = not returnTogglePending
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	bindReturnPrompt(prompt)
end

function DisplayShelfPresentationController:syncSlotPresentation(slotIndex: number, entry: any, model: Model, displayName: string)
	ItemPropBuilder.updateLabel(model, displayName, displaySubtitle(entry))
	self:syncReturnPrompt(slotIndex, entry, model)
end

function DisplayShelfPresentationController:syncAllReturnPrompts()
	if not shiftActive or not lastInventorySnapshot then
		clearAllReturnPrompts()
		return
	end

	local maxSlots = lastInventorySnapshot.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
	local items = InventorySnapshot.indexDisplayItemsBySlot(lastInventorySnapshot.displayItems)

	for slotIndex = 1, maxSlots do
		local entry = items[slotIndex]
		local model = slotModels[slotIndex]
		if entry and model and model.Parent then
			self:syncReturnPrompt(slotIndex, entry, model)
		else
			removeReturnPrompt(slotIndex)
		end
	end

	for slotIndex, _ in slotReturnPrompts do
		if slotIndex > maxSlots then
			removeReturnPrompt(slotIndex)
		end
	end
end

function DisplayShelfPresentationController:clearSlot(slotIndex: number)
	removeReturnPrompt(slotIndex)
	slotKeys[slotIndex] = nil
	ItemPropBuilder.destroy(slotModels[slotIndex])
	slotModels[slotIndex] = nil
end

function DisplayShelfPresentationController:clearAll()
	clearAllReturnPrompts()
	returnTogglePending = false

	local slotIndices = {}
	for slotIndex in slotModels do
		table.insert(slotIndices, slotIndex)
	end
	for _, slotIndex in slotIndices do
		slotKeys[slotIndex] = nil
		ItemPropBuilder.destroy(slotModels[slotIndex])
		slotModels[slotIndex] = nil
	end
	for slotIndex in slotKeys do
		slotKeys[slotIndex] = nil
	end
end

function DisplayShelfPresentationController:showSlot(slotIndex: number, entry: any)
	local resolved = ItemVisuals.resolve({
		displaySlot = slotIndex,
		instanceId = entry.instanceId,
		itemId = entry.itemId,
		displayName = entry.displayName,
		category = entry.category,
		traits = entry.traits,
		phase = "Display",
	})
	if not resolved then
		self:clearSlot(slotIndex)
		return
	end

	if slotKeys[slotIndex] == resolved.itemKey and slotModels[slotIndex] and slotModels[slotIndex].Parent then
		self:syncSlotPresentation(slotIndex, entry, slotModels[slotIndex], resolved.displayName)
		return
	end

	local slotPart = resolveSlotPart(slotIndex)
	if not slotPart then
		self:clearSlot(slotIndex)
		return
	end

	local world = waitForWorld()
	if not world then
		return
	end

	self:clearSlot(slotIndex)
	slotKeys[slotIndex] = resolved.itemKey

	local model = ItemPropBuilder.build(resolved, slotPart.CFrame)
	model.Name = "HubDisplayItem"
	model.Parent = ensureLocalFolder(world)
	slotModels[slotIndex] = model
	self:syncSlotPresentation(slotIndex, entry, model, resolved.displayName)
end

function DisplayShelfPresentationController:refreshDisplayShelf(inventorySnapshot: any?)
	if not shiftActive then
		self:clearAll()
		return
	end

	if not inventorySnapshot then
		self:clearAll()
		return
	end

	local maxSlots = inventorySnapshot.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
	local items = InventorySnapshot.indexDisplayItemsBySlot(inventorySnapshot.displayItems)

	for slotIndex = 1, maxSlots do
		local entry = items[slotIndex]
		if entry then
			self:showSlot(slotIndex, entry)
		else
			self:clearSlot(slotIndex)
		end
	end

	for slotIndex, _ in slotModels do
		if slotIndex > maxSlots then
			self:clearSlot(slotIndex)
		end
	end

	self:syncAllReturnPrompts()
end

local function onInventorySnapshot(snapshot: any?)
	lastInventorySnapshot = snapshot
	DisplayShelfPresentationController:refreshDisplayShelf(snapshot)
end

local function onShiftSnapshot(snapshot: any?)
	shiftActive = snapshot ~= nil and snapshot.active == true and snapshot.ended ~= true
	if not shiftActive then
		DisplayShelfPresentationController:clearAll()
		return
	end

	DisplayShelfPresentationController:refreshDisplayShelf(lastInventorySnapshot)
end

function DisplayShelfPresentationController:Init() end

function DisplayShelfPresentationController:Start()
	task.defer(function()
		resolveDisplayShelf()
		for slotIndex = 1, DEFAULT_DISPLAY_SLOTS do
			resolveSlotPart(slotIndex)
		end
	end)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(onInventorySnapshot)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)
end

return DisplayShelfPresentationController
