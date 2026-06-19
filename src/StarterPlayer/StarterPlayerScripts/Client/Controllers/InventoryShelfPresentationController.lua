local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local ItemVisuals = require(Shared.Config.ItemVisuals)

local HubWorld = require(script.Parent.HubWorld)
local ItemPropBuilder = require(script.Parent.ItemPropBuilder)

local InventoryShelfPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubInventoryLocal"
local DEFAULT_MAX_SLOTS = 3
local PRIMARY_PROMPT_NAME = "InventoryShelfPrimaryPrompt"
local PROMPT_MODE_OFFER = "offer"
local PROMPT_MODE_HOLD_BACK = "holdBack"

local inventoryShelf: Instance? = nil
local slotParts: { [number]: BasePart? } = {}
local localFolder: Folder? = nil
local slotModels: { [number]: Model? } = {}
local slotKeys: { [number]: string? } = {}
local slotPrompts: { [number]: ProximityPrompt? } = {}
local slotPromptModes: { [number]: string? } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}
local promptGeneration = 0

local shiftActive = false
local lastInventorySnapshot: any? = nil
local currentDealSnapshot: any? = nil
local isBuyerVisit = false
local activeSellingInstanceId: string? = nil
local promptActionPending = false

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

local function resolveInventoryShelf(): Instance?
	if inventoryShelf and inventoryShelf.Parent then
		return inventoryShelf
	end

	local shop = waitForShop()
	if not shop then
		warnShelfOnce("InventoryShelfPresentation: Workspace.World.Shop not found; inventory shelf disabled.")
		return nil
	end

	local shelf = HubWorld.findInventoryShelf(shop)
	if not shelf then
		warnShelfOnce(
			`InventoryShelfPresentation: InventoryShelf not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
		)
		return nil
	end

	inventoryShelf = shelf
	return shelf
end

local function resolveSlotPart(slotIndex: number): BasePart?
	local cached = slotParts[slotIndex]
	if cached and cached.Parent then
		return cached
	end

	local shelf = resolveInventoryShelf()
	if not shelf then
		return nil
	end

	local part = HubWorld.findInventorySlot(shelf, slotIndex)
	if not part then
		warnSlotOnce(
			`InventoryShelfPresentation: InventorySlot{slotIndex} not found as direct child of InventoryShelf. Children: {HubWorld.listChildNames(shelf)}`
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

local function shelfSubtitle(entry: any): string
	return entry.category or ""
end

local function formatRemoteError(prefix: string, result: any): string
	local message = if type(result) == "table" then result.error else nil
	if type(message) == "string" and message ~= "" then
		return `{prefix}: {message}`
	end
	return prefix
end

local function showMessage(message: string)
	local uiOk, UIController = pcall(require, script.Parent.UIController)
	if uiOk then
		UIController:showHubMessage(message)
	else
		warn(message)
	end
end

local function bumpPromptGeneration()
	promptGeneration += 1
end

local function getPrimaryPromptMode(entry: any): string?
	if isBuyerVisit then
		if entry.heldBack == true then
			return nil
		end
		return PROMPT_MODE_OFFER
	end

	return PROMPT_MODE_HOLD_BACK
end

local function buildMatchLookup(snapshot: any?): { [string]: any }
	local lookup = {}
	if snapshot and snapshot.inventoryMatches then
		for _, match in snapshot.inventoryMatches do
			if match.instanceId then
				lookup[match.instanceId] = match
			end
		end
	end
	return lookup
end

local function clearExtraPrompts(model: Model, keepPrompt: ProximityPrompt?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant ~= keepPrompt then
			boundPrompts[descendant] = nil
			descendant:Destroy()
		end
	end
end

local function findPrimaryPrompt(model: Model): ProximityPrompt?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == PRIMARY_PROMPT_NAME then
			return descendant
		end
	end
	return nil
end

local function getOrCreatePrimaryPrompt(model: Model, attachPart: BasePart): ProximityPrompt
	local existing = findPrimaryPrompt(model)
	if existing and existing.Parent == attachPart then
		clearExtraPrompts(model, existing)
		return existing
	elseif existing then
		boundPrompts[existing] = nil
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PRIMARY_PROMPT_NAME
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachPart
	clearExtraPrompts(model, prompt)
	return prompt
end

local function removePrimaryPrompt(slotIndex: number)
	local prompt = slotPrompts[slotIndex]
	if prompt then
		boundPrompts[prompt] = nil
		prompt:Destroy()
	end
	slotPrompts[slotIndex] = nil
	slotPromptModes[slotIndex] = nil
end

local function clearAllShelfPrompts()
	for slotIndex, prompt in slotPrompts do
		if prompt then
			boundPrompts[prompt] = nil
			prompt:Destroy()
		end
		slotPrompts[slotIndex] = nil
		slotPromptModes[slotIndex] = nil
	end
end

local function setAllPromptsEnabled(enabled: boolean)
	for _, prompt in slotPrompts do
		if prompt then
			prompt.Enabled = enabled and prompt:GetAttribute("PromptGeneration") == promptGeneration
		end
	end
end

local function invokeShelfRemote(remoteName: string, instanceId: string, errorPrefix: string): boolean
	if promptActionPending or not shiftActive then
		return false
	end

	promptActionPending = true
	setAllPromptsEnabled(false)

	local remote = Remotes.get(remoteName) :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(instanceId)
	end)

	promptActionPending = false

	if not ok or type(result) ~= "table" or result.ok ~= true then
		local message = if ok then formatRemoteError(errorPrefix, result) else `{errorPrefix}: {result}`
		showMessage(message)
		InventoryShelfPresentationController:syncAllShelfPrompts()
		return false
	end

	InventoryShelfPresentationController:syncAllShelfPrompts()
	return true
end

local function offerInventoryItem(instanceId: string)
	if not isBuyerVisit then
		return
	end
	invokeShelfRemote("SelectInventoryItemForBuyer", instanceId, "Could not offer item")
end

local function displayInventoryItem(instanceId: string)
	if isBuyerVisit then
		return
	end
	invokeShelfRemote("DisplayInventoryItem", instanceId, "Could not hold back item")
end

local function bindPrimaryPrompt(prompt: ProximityPrompt)
	if boundPrompts[prompt] then
		return
	end
	boundPrompts[prompt] = true

	prompt.Triggered:Connect(function()
		if promptActionPending or not shiftActive then
			return
		end

		local instanceId = prompt:GetAttribute("InstanceId")
		local mode = prompt:GetAttribute("PromptMode")
		local slotIndex = prompt:GetAttribute("SlotIndex")
		local generation = prompt:GetAttribute("PromptGeneration")
		if
			type(instanceId) ~= "string"
			or type(mode) ~= "string"
			or type(slotIndex) ~= "number"
			or generation ~= promptGeneration
			or slotPrompts[slotIndex] ~= prompt
			or slotPromptModes[slotIndex] ~= mode
		then
			return
		end

		if mode == PROMPT_MODE_OFFER then
			if not isBuyerVisit then
				return
			end
			offerInventoryItem(instanceId)
		elseif mode == PROMPT_MODE_HOLD_BACK then
			if isBuyerVisit then
				return
			end
			displayInventoryItem(instanceId)
		end
	end)
end

function InventoryShelfPresentationController:syncPrimaryPrompt(slotIndex: number, entry: any, model: Model)
	if not shiftActive then
		removePrimaryPrompt(slotIndex)
		return
	end

	if activeSellingInstanceId and entry.instanceId == activeSellingInstanceId then
		removePrimaryPrompt(slotIndex)
		return
	end

	local desiredMode = getPrimaryPromptMode(entry)
	if not desiredMode then
		removePrimaryPrompt(slotIndex)
		clearExtraPrompts(model, nil)
		return
	end

	if slotPrompts[slotIndex] and slotPromptModes[slotIndex] ~= desiredMode then
		removePrimaryPrompt(slotIndex)
	end

	local attachPart = findPromptAttachPart(model)
	if not attachPart then
		removePrimaryPrompt(slotIndex)
		clearExtraPrompts(model, nil)
		return
	end

	local prompt = getOrCreatePrimaryPrompt(model, attachPart)
	slotPrompts[slotIndex] = prompt
	slotPromptModes[slotIndex] = desiredMode
	prompt:SetAttribute("InstanceId", entry.instanceId)
	prompt:SetAttribute("PromptMode", desiredMode)
	prompt:SetAttribute("SlotIndex", slotIndex)
	prompt:SetAttribute("PromptGeneration", promptGeneration)

	if desiredMode == PROMPT_MODE_OFFER then
		local matchLookup = buildMatchLookup(currentDealSnapshot)
		local match = matchLookup[entry.instanceId]
		prompt.ActionText = `Offer {entry.displayName}`
		prompt.ObjectText = if match and match.matchLabel then match.matchLabel elseif entry.category then entry.category else ""
	else
		prompt.ActionText = "Hold Back"
		prompt.ObjectText = entry.category or ""
	end

	prompt.Enabled = not promptActionPending
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	bindPrimaryPrompt(prompt)
end

function InventoryShelfPresentationController:syncSlotPresentation(
	slotIndex: number,
	entry: any,
	model: Model,
	displayName: string
)
	ItemPropBuilder.updateLabel(model, displayName, shelfSubtitle(entry))
	self:syncPrimaryPrompt(slotIndex, entry, model)
end

function InventoryShelfPresentationController:syncAllShelfPrompts()
	if not shiftActive or not lastInventorySnapshot then
		clearAllShelfPrompts()
		return
	end

	local maxSlots = lastInventorySnapshot.maxSlots or DEFAULT_MAX_SLOTS
	local items = lastInventorySnapshot.items or {}

	for slotIndex = 1, maxSlots do
		local entry = items[slotIndex]
		local model = slotModels[slotIndex]
		if entry and model and model.Parent then
			self:syncPrimaryPrompt(slotIndex, entry, model)
		else
			removePrimaryPrompt(slotIndex)
		end
	end

	for slotIndex, _ in slotPrompts do
		if slotIndex > maxSlots then
			removePrimaryPrompt(slotIndex)
		end
	end
end

function InventoryShelfPresentationController:clearSlot(slotIndex: number)
	removePrimaryPrompt(slotIndex)
	slotKeys[slotIndex] = nil
	ItemPropBuilder.destroy(slotModels[slotIndex])
	slotModels[slotIndex] = nil
end

function InventoryShelfPresentationController:clearAll()
	bumpPromptGeneration()
	clearAllShelfPrompts()
	promptActionPending = false

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

function InventoryShelfPresentationController:showSlot(slotIndex: number, entry: any)
	if activeSellingInstanceId and entry.instanceId == activeSellingInstanceId then
		self:clearSlot(slotIndex)
		return
	end

	local resolved = ItemVisuals.resolve({
		shelfSlot = slotIndex,
		instanceId = entry.instanceId,
		itemId = entry.itemId,
		displayName = entry.displayName,
		category = entry.category,
		traits = entry.traits,
		phase = "Shelf",
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
	model.Name = "HubShelfItem"
	model.Parent = ensureLocalFolder(world)
	slotModels[slotIndex] = model
	self:syncSlotPresentation(slotIndex, entry, model, resolved.displayName)
end

function InventoryShelfPresentationController:refreshShelf(inventorySnapshot: any?)
	if not shiftActive or not inventorySnapshot then
		self:clearAll()
		return
	end

	local maxSlots = inventorySnapshot.maxSlots or DEFAULT_MAX_SLOTS
	local items = inventorySnapshot.items or {}

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

	self:syncAllShelfPrompts()
end

local function onInventorySnapshot(snapshot: any?)
	lastInventorySnapshot = snapshot
	bumpPromptGeneration()
	InventoryShelfPresentationController:refreshShelf(snapshot)
end

local function onShiftSnapshot(snapshot: any?)
	shiftActive = snapshot ~= nil and snapshot.active == true and snapshot.ended ~= true
	bumpPromptGeneration()
	if not shiftActive then
		InventoryShelfPresentationController:clearAll()
		return
	end

	InventoryShelfPresentationController:refreshShelf(lastInventorySnapshot)
end

local function onDealSnapshot(snapshot: any?)
	local wasBuyerVisit = isBuyerVisit
	local previousSellingId = activeSellingInstanceId

	currentDealSnapshot = snapshot
	isBuyerVisit = snapshot ~= nil and snapshot.phase == "BuyerVisit"

	if snapshot and snapshot.phase == "Selling" and snapshot.instanceId then
		activeSellingInstanceId = snapshot.instanceId
	else
		activeSellingInstanceId = nil
	end

	if not shiftActive then
		return
	end

	local sellingIdChanged = previousSellingId ~= activeSellingInstanceId
	local buyerVisitChanged = wasBuyerVisit ~= isBuyerVisit

	if sellingIdChanged then
		bumpPromptGeneration()
		InventoryShelfPresentationController:refreshShelf(lastInventorySnapshot)
	elseif buyerVisitChanged or isBuyerVisit then
		bumpPromptGeneration()
		InventoryShelfPresentationController:syncAllShelfPrompts()
	end
end

function InventoryShelfPresentationController:Init() end

function InventoryShelfPresentationController:Start()
	task.defer(function()
		resolveInventoryShelf()
		for slotIndex = 1, DEFAULT_MAX_SLOTS do
			resolveSlotPart(slotIndex)
		end
	end)

	local inventoryUpdate = Remotes.get("InventoryStateUpdate") :: RemoteEvent
	inventoryUpdate.OnClientEvent:Connect(onInventorySnapshot)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)
end

return InventoryShelfPresentationController
