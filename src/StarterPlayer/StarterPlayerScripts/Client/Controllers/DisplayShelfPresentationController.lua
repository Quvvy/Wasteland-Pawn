local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local ItemVisuals = require(Shared.Config.ItemVisuals)
local InventorySnapshot = require(Shared.Util.InventorySnapshot)
local WorldMarkers = require(Shared.Util.WorldMarkers)

local HubWorld = require(script.Parent.HubWorld)
local ItemPropBuilder = require(script.Parent.ItemPropBuilder)

local DisplayShelfPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubDisplayLocal"
local DEFAULT_DISPLAY_SLOTS = 3
local SHELF_LABEL_NAME = "ShelfWorldLabel"

local displayShelf: Instance? = nil
local slotParts: { [number]: BasePart? } = {}
local localFolder: Folder? = nil
local slotModels: { [number]: Model? } = {}
local slotKeys: { [number]: string? } = {}

local lastInventorySnapshot: any? = nil
local activeSellingInstanceId: string? = nil

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
	local attachPart = HubWorld.resolveBasePart(shelf:FindFirstChild("ShelfParts"))
		or HubWorld.resolveBasePart(shelf:FindFirstChild("ShelfBack"))
		or HubWorld.resolveBasePart(shelf)
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

	local shop = WorldMarkers.getShopRoot()
	if not shop then
		warnShelfOnce("ShelfPresentation: Workspace.World.Shop not found; shelf disabled.")
		return nil
	end

	local shelf = WorldMarkers.findPrimaryShelf(shop)
	if not shelf then
		warnShelfOnce(
			`ShelfPresentation: Shop.Shelves.BasicShelf not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
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
			`ShelfPresentation: BasicShelf slot {slotIndex} not found (Shop.Shelves.BasicShelf.SlotMarkers). Children: {HubWorld.listChildNames(shelf)}`
		)
		return nil
	end

	slotParts[slotIndex] = part
	return part
end

local function shelfSubtitle(entry: any): string
	if entry.category and entry.category ~= "" then
		return entry.category
	end
	return "On Shelf"
end

local function tagShelfItemModel(model: Model, entry: any, slotIndex: number)
	model:SetAttribute("InstanceId", entry.instanceId)
	model:SetAttribute("SlotIndex", slotIndex)
	model:SetAttribute("ShelfItem", true)
end

local function clearItemPrompts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
end

function DisplayShelfPresentationController:syncSlotPresentation(slotIndex: number, entry: any, model: Model, displayName: string)
	ItemPropBuilder.updateLabel(model, displayName, shelfSubtitle(entry))
	tagShelfItemModel(model, entry, slotIndex)
	clearItemPrompts(model)
	ItemPropBuilder.ensureSelectionHitbox(model)
end

function DisplayShelfPresentationController:getPrimaryShelfModel(): Instance?
	return resolveShelf()
end

function DisplayShelfPresentationController:getSlotModels(): { [number]: Model }
	local copy: { [number]: Model } = {}
	for slotIndex, model in slotModels do
		if model and model.Parent then
			copy[slotIndex] = model
		end
	end
	return copy
end

function DisplayShelfPresentationController:findModelByInstanceId(instanceId: string): Model?
	for _, model in slotModels do
		if model and model.Parent and model:GetAttribute("InstanceId") == instanceId then
			return model
		end
	end
	return nil
end

function DisplayShelfPresentationController:getSlotParts(maxSlots: number?): { [number]: BasePart }
	local limit = maxSlots or DEFAULT_DISPLAY_SLOTS
	local copy: { [number]: BasePart } = {}
	for slotIndex = 1, limit do
		local part = resolveSlotPart(slotIndex)
		if part then
			copy[slotIndex] = part
		end
	end
	return copy
end

function DisplayShelfPresentationController:findModelBySlotIndex(slotIndex: number): Model?
	local model = slotModels[slotIndex]
	if model and model.Parent then
		return model
	end
	return nil
end

function DisplayShelfPresentationController:getLastInventorySnapshot(): any?
	return lastInventorySnapshot
end

function DisplayShelfPresentationController:clearSlot(slotIndex: number)
	slotKeys[slotIndex] = nil
	ItemPropBuilder.destroy(slotModels[slotIndex])
	slotModels[slotIndex] = nil
end

function DisplayShelfPresentationController:clearAll()
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

	local model = ItemPropBuilder.build(resolved, slotPart.CFrame, slotPart)
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
end

local function onInventorySnapshot(snapshot: any?)
	lastInventorySnapshot = snapshot
	DisplayShelfPresentationController:refreshDisplayShelf(snapshot)
end

local function onDealSnapshot(snapshot: any?)
	if snapshot and snapshot.phase == "Selling" and snapshot.instanceId then
		activeSellingInstanceId = snapshot.instanceId
	else
		activeSellingInstanceId = nil
		DisplayShelfPresentationController:refreshDisplayShelf(lastInventorySnapshot)
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

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)
end

return DisplayShelfPresentationController
