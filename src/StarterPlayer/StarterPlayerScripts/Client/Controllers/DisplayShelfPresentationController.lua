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
local PRIMARY_PROMPT_NAME = "ShelfPrimaryPrompt"
local PROMPT_MODE_OFFER = "offer"
local PROMPT_MODE_STORAGE = "storage"
local SHELF_LABEL_NAME = "ShelfWorldLabel"

local displayShelf: Instance? = nil
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

local function ensureShelfWorldLabel(shelf: Instance)
	local attachPart = HubWorld.resolveBasePart(shelf:FindFirstChild("ShelfBack")) or HubWorld.resolveBasePart(shelf)
	if not attachPart then
		return
	end

	local existing = attachPart:FindFirstChild(SHELF_LABEL_NAME)
	if existing and existing:IsA("BillboardGui") then
		local label = existing:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = "SHELF — For sale • Attracts buyers"
		end
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = SHELF_LABEL_NAME
	billboard.Size = UDim2.fromOffset(220, 48)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = attachPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(235, 220, 180)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "SHELF — For sale • Attracts buyers"
	label.Parent = billboard
end

local function resolveShelf(): Instance?
	if displayShelf and displayShelf.Parent then
		return displayShelf
	end

	local shop = waitForShop()
	if not shop then
		warnShelfOnce("ShelfPresentation: Workspace.World.Shop not found; shelf disabled.")
		return nil
	end

	local shelf = HubWorld.findShelf(shop)
	if not shelf then
		warnShelfOnce(
			`ShelfPresentation: Shelf not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
		)
		return nil
	end

	displayShelf = shelf
	ensureShelfWorldLabel(shelf)
	return shelf
end

local function resolveSlotPart(slotIndex: number): BasePart?
	local cached = slotParts[slotIndex]
	if cached and cached.Parent then
		return cached
	end

	local shelf = resolveShelf()
	if not shelf then
		return nil
	end

	local part = HubWorld.findShelfSlot(shelf, slotIndex)
	if not part then
		warnSlotOnce(
			`ShelfPresentation: ShelfSlot{slotIndex} not found under Shelf. Children: {HubWorld.listChildNames(shelf)}`
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
	if entry.category and entry.category ~= "" then
		return entry.category
	end
	return "On Shelf"
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

local function getPrimaryPromptMode(_entry: any): string?
	if isBuyerVisit then
		return PROMPT_MODE_OFFER
	end
	return PROMPT_MODE_STORAGE
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
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
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
		DisplayShelfPresentationController:syncAllShelfPrompts()
		return false
	end

	DisplayShelfPresentationController:syncAllShelfPrompts()
	return true
end

local function offerShelfItem(instanceId: string)
	if not isBuyerVisit then
		return
	end
	invokeShelfRemote("SelectInventoryItemForBuyer", instanceId, "Could not offer item")
end

local function moveShelfItemToStorage(instanceId: string)
	if isBuyerVisit then
		return
	end
	invokeShelfRemote("MoveDisplayItemToStash", instanceId, "Could not move item to Storage")
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
			offerShelfItem(instanceId)
		elseif mode == PROMPT_MODE_STORAGE then
			if isBuyerVisit then
				return
			end
			moveShelfItemToStorage(instanceId)
		end
	end)
end

function DisplayShelfPresentationController:syncPrimaryPrompt(slotIndex: number, entry: any, model: Model)
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
		prompt.ActionText = "Move to Storage"
		prompt.ObjectText = entry.category or ""
	end

	prompt.Enabled = not promptActionPending
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	bindPrimaryPrompt(prompt)
end

function DisplayShelfPresentationController:syncSlotPresentation(slotIndex: number, entry: any, model: Model, displayName: string)
	ItemPropBuilder.updateLabel(model, displayName, shelfSubtitle(entry))
	self:syncPrimaryPrompt(slotIndex, entry, model)
end

function DisplayShelfPresentationController:syncAllShelfPrompts()
	if not shiftActive or not lastInventorySnapshot then
		clearAllShelfPrompts()
		return
	end

	local maxSlots = lastInventorySnapshot.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
	local items = InventorySnapshot.indexShelfItemsBySlot(lastInventorySnapshot.displayItems)

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

function DisplayShelfPresentationController:clearSlot(slotIndex: number)
	removePrimaryPrompt(slotIndex)
	slotKeys[slotIndex] = nil
	ItemPropBuilder.destroy(slotModels[slotIndex])
	slotModels[slotIndex] = nil
end

function DisplayShelfPresentationController:clearAll()
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

function DisplayShelfPresentationController:showSlot(slotIndex: number, entry: any)
	if activeSellingInstanceId and entry.instanceId == activeSellingInstanceId then
		self:clearSlot(slotIndex)
		return
	end

	local resolved = ItemVisuals.resolve({
		displaySlot = slotIndex,
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

function DisplayShelfPresentationController:refreshDisplayShelf(inventorySnapshot: any?)
	if not inventorySnapshot then
		self:clearAll()
		return
	end

	local maxSlots = inventorySnapshot.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
	local items = InventorySnapshot.indexShelfItemsBySlot(inventorySnapshot.displayItems)

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
	DisplayShelfPresentationController:refreshDisplayShelf(snapshot)
end

local function onShiftSnapshot(snapshot: any?)
	shiftActive = snapshot ~= nil and snapshot.active == true and snapshot.ended ~= true
	bumpPromptGeneration()
	DisplayShelfPresentationController:refreshDisplayShelf(lastInventorySnapshot)
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
		DisplayShelfPresentationController:refreshDisplayShelf(lastInventorySnapshot)
	elseif buyerVisitChanged or isBuyerVisit then
		bumpPromptGeneration()
		DisplayShelfPresentationController:syncAllShelfPrompts()
	end
end

function DisplayShelfPresentationController:Init() end

function DisplayShelfPresentationController:Start()
	task.defer(function()
		resolveShelf()
		for slotIndex = 1, DEFAULT_DISPLAY_SLOTS do
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

return DisplayShelfPresentationController
