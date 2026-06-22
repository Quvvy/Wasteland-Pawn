local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local ItemVisuals = require(Shared.Config.ItemVisuals)

local HubWorld = require(script.Parent.HubWorld)
local ItemPropBuilder = require(script.Parent.ItemPropBuilder)

local ItemPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubItemLocal"

local counterItemSpot: BasePart? = nil
local localFolder: Folder? = nil
local activeModel: Model? = nil
local lastItemKey: string? = nil
local spotWarned = false
local orchestratedMode = false

local TERMINAL_PHASES = {
	Result = true,
	WalkedAway = true,
	Stored = true,
	BuyerSkipped = true,
}

local function warnSpotOnce(message: string)
	if spotWarned then
		return
	end
	spotWarned = true
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

local function resolveCounterItemSpot(): BasePart?
	if counterItemSpot and counterItemSpot.Parent then
		return counterItemSpot
	end

	local shop = waitForShop()
	if not shop then
		warnSpotOnce("ItemPresentation: Workspace.World.Shop not found; counter item disabled.")
		return nil
	end

	local part = HubWorld.findCounterItemSpot(shop)
	if not part then
		warnSpotOnce(
			`ItemPresentation: CounterItemSpot not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
		)
		return nil
	end

	counterItemSpot = part
	return part
end

function ItemPresentationController:setOrchestratedMode(enabled: boolean)
	orchestratedMode = enabled
end

function ItemPresentationController:clearItem()
	lastItemKey = nil
	ItemPropBuilder.destroy(activeModel)
	activeModel = nil
end

function ItemPresentationController:showItem(itemData: ItemVisuals.ItemData)
	local resolved = ItemVisuals.resolve(itemData)
	if not resolved then
		self:clearItem()
		return
	end

	if lastItemKey == resolved.itemKey and activeModel and activeModel.Parent then
		ItemPropBuilder.updateLabel(activeModel, resolved.displayName, resolved.subtitle)
		return
	end

	local spot = resolveCounterItemSpot()
	if not spot then
		self:clearItem()
		return
	end

	local world = waitForWorld()
	if not world then
		return
	end

	self:clearItem()
	lastItemKey = resolved.itemKey

	local model = ItemPropBuilder.build(resolved, spot.CFrame)
	model.Parent = ensureLocalFolder(world)
	activeModel = model
end

function ItemPresentationController:showSellerItem(snapshot: any)
	self:showItem({
		phase = "Haggling",
		itemId = snapshot.itemId,
		itemName = snapshot.itemName,
		category = snapshot.category,
		traits = snapshot.traits,
	})
end

function ItemPresentationController:showSellingItem(snapshot: any)
	self:showItem({
		phase = "Selling",
		itemId = snapshot.itemId,
		itemName = snapshot.itemName,
		category = snapshot.category,
		traits = snapshot.traits,
		instanceId = snapshot.instanceId,
	})
end

function ItemPresentationController:showBuyerPreviewItem(snapshot: any)
	local match = snapshot.inventoryMatches and snapshot.inventoryMatches[1]
	if not match then
		self:clearItem()
		return
	end
	self:showItem({
		phase = "BuyerVisit",
		itemId = match.itemId,
		itemName = match.displayName or match.itemName,
		category = match.category,
		traits = match.traits,
		instanceId = match.instanceId,
	})
end

local function onDealSnapshot(snapshot: any?)
	if orchestratedMode then
		return
	end
	if not snapshot then
		ItemPresentationController:clearItem()
		return
	end

	local phase = snapshot.phase
	if phase == "Haggling" then
		ItemPresentationController:showSellerItem(snapshot)
	elseif phase == "Selling" then
		ItemPresentationController:showSellingItem(snapshot)
	elseif phase == "BuyerVisit" or TERMINAL_PHASES[phase] then
		ItemPresentationController:clearItem()
	else
		ItemPresentationController:clearItem()
	end
end

local function onShiftSnapshot(snapshot: any?)
	if orchestratedMode then
		return
	end
	if not snapshot or snapshot.active ~= true or snapshot.ended == true then
		ItemPresentationController:clearItem()
	end
end

function ItemPresentationController:Init() end

function ItemPresentationController:Start()
	task.defer(function()
		resolveCounterItemSpot()
	end)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)
end

return ItemPresentationController
