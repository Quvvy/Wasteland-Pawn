local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local VisitorAppearances = require(Shared.Config.VisitorAppearances)

local HubWorld = require(script.Parent.HubWorld)
local VisitorAppearanceBuilder = require(script.Parent.VisitorAppearanceBuilder)

local CustomerPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubVisitorLocal"

local customerSpot: BasePart? = nil
local localFolder: Folder? = nil
local activeModel: Model? = nil
local lastAppearanceKey: string? = nil
local spotWarned = false

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

local function resolveCustomerSpot(): BasePart?
	if customerSpot and customerSpot.Parent then
		return customerSpot
	end

	local shop = waitForShop()
	if not shop then
		warnSpotOnce("CustomerPresentation: Workspace.World.Shop not found; counter visitor disabled.")
		return nil
	end

	local part = HubWorld.findCustomerSpot(shop)
	if not part then
		warnSpotOnce(
			`CustomerPresentation: CustomerSpot not found under Workspace.World.Shop. Children: {HubWorld.listChildNames(shop)}`
		)
		return nil
	end

	customerSpot = part
	return part
end

local function getSpotCFrame(): CFrame?
	local spot = resolveCustomerSpot()
	if not spot then
		return nil
	end
	return spot.CFrame
end

function CustomerPresentationController:clearVisitor()
	lastAppearanceKey = nil
	VisitorAppearanceBuilder.destroy(activeModel)
	activeModel = nil
end

function CustomerPresentationController:showVisitor(profile: {
	visitorKind: string,
	buyerId: string?,
	customerId: string?,
	uniqueVisitorId: string?,
	displayName: string?,
	subtitle: string?,
})
	local resolved = VisitorAppearances.resolve({
		visitorKind = profile.visitorKind,
		buyerId = profile.buyerId,
		customerId = profile.customerId,
		uniqueVisitorId = profile.uniqueVisitorId,
		displayName = profile.displayName,
		subtitle = profile.subtitle,
	})

	if lastAppearanceKey == resolved.appearanceKey and activeModel and activeModel.Parent then
		VisitorAppearanceBuilder.updateLabel(activeModel, resolved.displayName, resolved.subtitle)
		return
	end

	local spotCFrame = getSpotCFrame()
	if not spotCFrame then
		self:clearVisitor()
		return
	end

	local world = waitForWorld()
	if not world then
		return
	end

	self:clearVisitor()
	lastAppearanceKey = resolved.appearanceKey

	local model = VisitorAppearanceBuilder.build(resolved, spotCFrame)
	model.Parent = ensureLocalFolder(world)
	activeModel = model
end

function CustomerPresentationController:showSeller(snapshot: any)
	local subtitle = nil
	if snapshot.itemName and snapshot.itemName ~= "" then
		subtitle = snapshot.itemName
	end

	self:showVisitor({
		visitorKind = "seller",
		customerId = snapshot.customerId,
		displayName = snapshot.customerName or "Seller",
		subtitle = subtitle,
	})
end

function CustomerPresentationController:showBuyer(snapshot: any)
	local subtitle = snapshot.buyerMatchLabel or snapshot.buyerInterest
	if subtitle == "" then
		subtitle = nil
	end

	self:showVisitor({
		visitorKind = "buyer",
		buyerId = snapshot.buyerId,
		displayName = snapshot.buyerName,
		subtitle = subtitle,
	})
end

local function onDealSnapshot(snapshot: any?)
	if not snapshot then
		CustomerPresentationController:clearVisitor()
		return
	end

	local phase = snapshot.phase
	if phase == "Haggling" then
		CustomerPresentationController:showSeller(snapshot)
	elseif phase == "BuyerVisit" or phase == "Selling" then
		CustomerPresentationController:showBuyer(snapshot)
	elseif TERMINAL_PHASES[phase] then
		CustomerPresentationController:clearVisitor()
	else
		CustomerPresentationController:clearVisitor()
	end
end

local function onShiftSnapshot(snapshot: any?)
	if not snapshot or snapshot.active ~= true or snapshot.ended == true then
		CustomerPresentationController:clearVisitor()
	end
end

function CustomerPresentationController:Init() end

function CustomerPresentationController:Start()
	task.defer(function()
		resolveCustomerSpot()
	end)

	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)
end

return CustomerPresentationController
