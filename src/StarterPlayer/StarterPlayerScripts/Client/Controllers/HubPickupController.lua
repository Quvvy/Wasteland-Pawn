local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubPickups = require(Shared.Config.HubPickups)

local UIController = require(script.Parent.UIController)
local HubWorld = require(script.Parent.HubWorld)

local HubPickupController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubPickupsLocal"

local heldProp: any = nil
local spawnedAtPickup: { [string]: Model } = {}
local placedOnSlot: { [string]: Model } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}
local slotPrompts: { [string]: ProximityPrompt } = {}
local stashPrompt: ProximityPrompt? = nil
local localFolder: Folder? = nil

local warnedMissing: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if warnedMissing[key] then
		return
	end
	warnedMissing[key] = true
	warn(message)
end

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

local function waitForWorld(): Instance?
	return Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
end

local function getAssetTemplate(assetName: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local hubPickups = assets and assets:FindFirstChild("HubPickups")
	return hubPickups and hubPickups:FindFirstChild(assetName)
end

local function getPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
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

function HubPickupController:_applyPropMetadata(model: Model, def)
	model:SetAttribute("HubPropId", def.propId)
	model:SetAttribute("HubDisplayName", def.displayName)
	model:SetAttribute("HubAssetName", def.assetName)
end

function HubPickupController:_createPlaceholderModel(def): Model
	local model = Instance.new("Model")
	model.Name = def.assetName

	local part = Instance.new("Part")
	part.Name = "Primary"
	part.Size = def.placeholderSize
	part.Color = def.placeholderColor
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	model.PrimaryPart = part

	self:_applyPropMetadata(model, def)
	return model
end

function HubPickupController:_createPickupModel(def): Model
	local template = getAssetTemplate(def.assetName)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	elseif template and template:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = def.assetName
		local part = template:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		model.PrimaryPart = part
	else
		model = self:_createPlaceholderModel(def)
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	if not model.PrimaryPart then
		local primary = getPrimaryPart(model)
		if primary then
			model.PrimaryPart = primary
		end
	end

	self:_applyPropMetadata(model, def)
	return model
end

function HubPickupController:_defFromModel(model: Model)
	local def = {
		propId = model:GetAttribute("HubPropId"),
		displayName = model:GetAttribute("HubDisplayName"),
		assetName = model:GetAttribute("HubAssetName"),
		placeholderSize = Vector3.new(1, 1, 1),
		placeholderColor = Color3.fromRGB(140, 140, 140),
	}

	for _, spawnDef in HubPickups.SpawnDefs do
		if spawnDef.propId == def.propId then
			def.placeholderSize = spawnDef.placeholderSize
			def.placeholderColor = spawnDef.placeholderColor
			break
		end
	end

	return def
end

function HubPickupController:_isHolding(): boolean
	return heldProp ~= nil
end

function HubPickupController:_refreshPlacementPrompts()
	local holding = self:_isHolding()
	local displayName = heldProp and heldProp.displayName or ""

	for _, prompt in slotPrompts do
		if holding then
			prompt.ActionText = `Place {displayName}`
		else
			prompt.ActionText = "Need a prop to place"
		end
	end

	if stashPrompt then
		stashPrompt.ActionText = "Drop in Stash"
	end
end

function HubPickupController:_pickUpProp(model: Model, spawnName: string?)
	if self:_isHolding() then
		UIController:showHubMessage("Already holding something.")
		return
	end

	local def = self:_defFromModel(model)
	if not def.propId or not def.displayName then
		UIController:showHubMessage("Can't pick that up.")
		return
	end

	heldProp = def
	model:Destroy()

	if spawnName then
		spawnedAtPickup[spawnName] = nil
	end

	UIController:setHubHolding(def.displayName)
	self:_refreshPlacementPrompts()
end

function HubPickupController:_placeOnSlot(slotName: string, slotPart: BasePart)
	if not self:_isHolding() then
		UIController:showHubMessage("Pick up a prop first.")
		return
	end

	if placedOnSlot[slotName] then
		UIController:showHubMessage("Slot already has something.")
		return
	end

	local world = findChildChain(Workspace, "World")
	if not world then
		return
	end

	local placed = self:_createPickupModel(heldProp)
	local pivot = slotPart:GetPivot() * CFrame.new(0, HubPickups.PlaceYOffset, 0)
	placed:PivotTo(pivot)
	placed.Parent = ensureLocalFolder(world)

	local prompt = placed:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end

	placedOnSlot[slotName] = placed
	heldProp = nil
	UIController:setHubHolding(nil)
	self:_refreshPlacementPrompts()
	UIController:showHubMessage(`Placed on {slotName}.`)
end

function HubPickupController:_dropInStash()
	if not self:_isHolding() then
		UIController:showHubMessage("Nothing to drop.")
		return
	end

	heldProp = nil
	UIController:setHubHolding(nil)
	self:_refreshPlacementPrompts()
	UIController:showHubMessage("Dropped in stash.")
end

function HubPickupController:_bindPickupPrompt(prompt: ProximityPrompt, model: Model, spawnName: string)
	if boundPrompts[prompt] then
		return
	end
	boundPrompts[prompt] = true

	local displayName = model:GetAttribute("HubDisplayName") or "item"
	prompt.ActionText = `Pick up {displayName}`
	prompt.ObjectText = ""

	prompt.Triggered:Connect(function()
		self:_pickUpProp(model, spawnName)
	end)
end

function HubPickupController:_spawnPickupAt(spawnPart: BasePart, def)
	local world = spawnPart:FindFirstAncestor("World")
	if not world then
		return
	end

	local model = self:_createPickupModel(def)
	local pivot = spawnPart:GetPivot() * CFrame.new(0, HubPickups.PlaceYOffset, 0)
	model:PivotTo(pivot)
	model.Parent = ensureLocalFolder(world)

	local primary = getPrimaryPart(model)
	if not primary then
		model:Destroy()
		warnOnce(`spawn_{def.spawnName}`, `HubPickup: Could not spawn prop at {def.spawnName}`)
		return
	end

	local prompt = getOrCreatePrompt(primary, "PickupPrompt")
	self:_bindPickupPrompt(prompt, model, def.spawnName)
	spawnedAtPickup[def.spawnName] = model
end

function HubPickupController:_setupOutdoorPickups(world: Instance)
	local outside = HubWorld.findChildByNames(world, { "Outside" })
	local junkLot = outside and HubWorld.findChildByNames(outside, { "JunkLot", "Junk_Lot", "Junklot" })
	if not junkLot then
		local outside = HubWorld.findChildByNames(world, { "Outside" })
		warnOnce(
			"junk_lot",
			`HubPickup: JunkLot not found under Outside. Outside children: {HubWorld.listChildNames(outside)}`
		)
		return
	end

	for index, def in HubPickups.SpawnDefs do
		if spawnedAtPickup[def.spawnName] then
			continue
		end

		local spawn = HubWorld.findPickupSpawn(junkLot, index, def.spawnName)
		if not spawn then
			warnOnce(
				`spawn_{def.spawnName}`,
				`HubPickup: {def.spawnName} not found under JunkLot. Children: {HubWorld.listChildNames(junkLot)}`
			)
			continue
		end
		self:_spawnPickupAt(spawn, def)
	end
end

function HubPickupController:_bindDisplaySlots(world: Instance)
	local shop = HubWorld.findChildByNames(world, { "Shop" })
	local shelf = shop
		and HubWorld.findChildByNames(shop, { "DisplayShelf", "Display_Shelf", "Shelf", "Display" })
	if not shelf then
		warnOnce(
			"display_shelf",
			`HubPickup: DisplayShelf not found. Shop children: {HubWorld.listChildNames(shop)}`
		)
		return
	end

	local shelfBack = HubWorld.findChildByNames(shelf, { "ShelfBack", "Back" })
	if not shelfBack then
		warnOnce("shelf_back", "HubPickup: ShelfBack/Back not found on DisplayShelf (optional)")
	end

	for index, slotName in HubPickups.DisplaySlots do
		if slotPrompts[slotName] then
			continue
		end

		local slot = HubWorld.findDisplaySlot(shelf, index, slotName)
		if not slot then
			warnOnce(
				`slot_{slotName}`,
				`HubPickup: {slotName} not found under DisplayShelf. Children: {HubWorld.listChildNames(shelf)}`
			)
			continue
		end

		local prompt = getOrCreatePrompt(slot, "PlacePrompt")
		slotPrompts[slotName] = prompt

		if boundPrompts[prompt] then
			continue
		end
		boundPrompts[prompt] = true

		prompt.Triggered:Connect(function()
			self:_placeOnSlot(slotName, slot)
		end)
	end
end

function HubPickupController:_bindStashBin(world: Instance)
	local shop = HubWorld.findChildByNames(world, { "Shop" })
	local stash = shop
		and (
			HubWorld.findChildByNames(shop, { "StashBin", "Stash_Bin", "Stash", "Bin" })
			or HubWorld.findShopPart(shop, {}, "stash")
		)
	if not stash then
		warnOnce("stash_bin", `HubPickup: StashBin not found. Shop children: {HubWorld.listChildNames(shop)}`)
		return
	end

	if stashPrompt then
		return
	end

	local promptParent = HubWorld.resolveBasePart(stash)
	if not promptParent then
		warnOnce("stash_part", "HubPickup: StashBin has no BasePart for ProximityPrompt")
		return
	end

	local prompt = getOrCreatePrompt(promptParent, "StashPrompt")
	stashPrompt = prompt

	if boundPrompts[prompt] then
		return
	end
	boundPrompts[prompt] = true

	prompt.Triggered:Connect(function()
		self:_dropInStash()
	end)
end

function HubPickupController:_waitAndSetup(world: Instance?)
	world = world or waitForWorld()
	if not world then
		warnOnce("world", "HubPickup: Workspace.World not found; hub pickups disabled")
		return
	end

	self:_setupOutdoorPickups(world)
	self:_bindDisplaySlots(world)
	self:_bindStashBin(world)
	self:_refreshPlacementPrompts()
end

function HubPickupController:_watchWorld()
	local world = waitForWorld()
	if not world then
		warnOnce("world", "HubPickup: Workspace.World not found; hub pickups disabled")
		return
	end

	self:_waitAndSetup(world)

	local debounceToken = 0
	world.DescendantAdded:Connect(function()
		debounceToken += 1
		local token = debounceToken
		task.delay(0.25, function()
			if token == debounceToken then
				self:_waitAndSetup(world)
			end
		end)
	end)
end

function HubPickupController:Init() end

function HubPickupController:Start()
	task.spawn(function()
		self:_watchWorld()
	end)
end

return HubPickupController
