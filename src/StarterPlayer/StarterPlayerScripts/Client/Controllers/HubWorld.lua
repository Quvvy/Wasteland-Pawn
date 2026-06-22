local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HubWorld = {}

local spotRaycastParams: RaycastParams? = nil

local function getSpotRaycastParams(extraExclude: Instance?): RaycastParams
	if spotRaycastParams and not extraExclude then
		return spotRaycastParams
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local world = Workspace:FindFirstChild("World")
	if world then
		local visitorFolder = world:FindFirstChild("HubVisitorLocal")
		if visitorFolder then
			table.insert(exclude, visitorFolder)
		end
	end
	local player = Players.LocalPlayer
	if player and player.Character then
		table.insert(exclude, player.Character)
	end
	if extraExclude then
		table.insert(exclude, extraExclude)
	end
	params.FilterDescendantsInstances = exclude
	if not extraExclude then
		spotRaycastParams = params
	end
	return params
end

function HubWorld.getSpotStandingCFrame(part: BasePart): CFrame
	local cf = part.CFrame
	local markerBottomY = cf.Position.Y - part.Size.Y * 0.5
	local origin = cf.Position + Vector3.new(0, 4, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -40, 0), getSpotRaycastParams(part))
	local floorY = if hit then hit.Position.Y else markerBottomY
	return CFrame.new(cf.Position.X, floorY, cf.Position.Z) * cf.Rotation
end

local function normalize(name: string): string
	return string.lower((string.gsub(name, "[%s_%-]", "")))
end

function HubWorld.normalizeName(name: string): string
	return normalize(name)
end

function HubWorld.findChildByNames(parent: Instance?, names: { string }): Instance?
	if not parent then
		return nil
	end

	for _, name in names do
		local child = parent:FindFirstChild(name)
		if child then
			return child
		end
	end

	local wanted = {}
	for _, name in names do
		wanted[normalize(name)] = true
	end

	for _, child in parent:GetChildren() do
		if wanted[normalize(child.Name)] then
			return child
		end
	end

	return nil
end

function HubWorld.resolveBasePart(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function HubWorld.findBasePartByNames(parent: Instance?, names: { string }): BasePart?
	return HubWorld.resolveBasePart(HubWorld.findChildByNames(parent, names))
end

function HubWorld.findDescendantBasePartByNames(root: Instance?, names: { string }): BasePart?
	if not root then
		return nil
	end

	for _, name in names do
		local child = root:FindFirstChild(name, true)
		local part = HubWorld.resolveBasePart(child)
		if part then
			return part
		end
	end

	local wanted = {}
	for _, name in names do
		wanted[normalize(name)] = true
	end

	for _, descendant in root:GetDescendants() do
		if wanted[normalize(descendant.Name)] then
			local part = HubWorld.resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	return nil
end

function HubWorld.findChildrenMatching(parent: Instance?, pattern: string): { Instance }
	local results = {}
	if not parent then
		return results
	end

	local needle = normalize(pattern)
	for _, child in parent:GetChildren() do
		local hay = normalize(child.Name)
		if string.find(hay, needle, 1, true) then
			table.insert(results, child)
		end
	end

	table.sort(results, function(a, b)
		return a.Name < b.Name
	end)

	return results
end

function HubWorld.findPickupSpawn(junkLot: Instance?, spawnIndex: number, spawnName: string): BasePart?
	local exactNames = {
		spawnName,
		`PickupSpawn{spawnIndex}`,
		`Pickup_Spawn{spawnIndex}`,
		`Spawn{spawnIndex}`,
	}
	local part = HubWorld.findDescendantBasePartByNames(junkLot, exactNames)
	if part then
		return part
	end
	if not junkLot then
		return nil
	end

	for _, descendant in junkLot:GetDescendants() do
		local hay = normalize(descendant.Name)
		if string.find(hay, "pickupspawn", 1, true) and string.find(hay, tostring(spawnIndex), 1, true) then
			part = HubWorld.resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	for _, descendant in junkLot:GetDescendants() do
		local hay = normalize(descendant.Name)
		if string.find(hay, "spawn", 1, true) and string.find(hay, tostring(spawnIndex), 1, true) then
			part = HubWorld.resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	return nil
end

function HubWorld.findDisplaySlot(shelf: Instance?, slotIndex: number, slotName: string): BasePart?
	local exactNames = {
		slotName,
		`DisplaySlot{slotIndex}`,
		`Display_Slot{slotIndex}`,
		`Slot{slotIndex}`,
	}
	local part = HubWorld.findDescendantBasePartByNames(shelf, exactNames)
	if part then
		return part
	end
	if not shelf then
		return nil
	end

	for _, child in shelf:GetChildren() do
		local hay = normalize(child.Name)
		if hay == `displayslot{slotIndex}` or hay == `displayslot{slotIndex}` or hay == `slot{slotIndex}` then
			part = HubWorld.resolveBasePart(child)
			if part then
				return part
			end
		end
	end

	for _, descendant in shelf:GetDescendants() do
		local hay = normalize(descendant.Name)
		if hay == `displayslot{slotIndex}` or hay == `displayslot{slotIndex}` then
			part = HubWorld.resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	return nil
end

local CUSTOMER_SPOT_EXACT_NAMES = {
	"CustomerSpot",
	"Customer_Spot",
}

function HubWorld.findCustomerSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end

	local found = HubWorld.findShopPart(shop, CUSTOMER_SPOT_EXACT_NAMES, "customerspot")
	return HubWorld.resolveBasePart(found)
end

local COUNTER_ITEM_SPOT_EXACT_NAMES = {
	"CounterItemSpot",
	"Counter_Item_Spot",
}

function HubWorld.findCounterItemSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end

	local found = HubWorld.findShopPart(shop, COUNTER_ITEM_SPOT_EXACT_NAMES, "counteritemspot")
	return HubWorld.resolveBasePart(found)
end

local DEAL_CAMERA_SPOT_NAMES = {
	"DealCameraSpot",
	"ShopCameraSpot",
	"Deal_Camera_Spot",
	"Shop_Camera_Spot",
}

function HubWorld.findDealCameraSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, DEAL_CAMERA_SPOT_NAMES, "dealcameraspot")
	if not found then
		found = HubWorld.findShopPart(shop, DEAL_CAMERA_SPOT_NAMES, "shopcameraspot")
	end
	return HubWorld.resolveBasePart(found)
end

local COUNTER_LOOK_AT_NAMES = {
	"CounterLookAt",
	"Counter_Look_At",
}

function HubWorld.findCounterLookAt(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, COUNTER_LOOK_AT_NAMES, "counterlookat")
	return HubWorld.resolveBasePart(found)
end

local CUSTOMER_ENTRY_SPOT_NAMES = {
	"CustomerEntrySpot",
	"Customer_Entry_Spot",
}

function HubWorld.findCustomerEntrySpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, CUSTOMER_ENTRY_SPOT_NAMES, "customerentryspot")
	return HubWorld.resolveBasePart(found)
end

local CUSTOMER_COUNTER_SPOT_NAMES = {
	"CustomerCounterSpot",
	"Customer_Counter_Spot",
}

function HubWorld.findCustomerCounterSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, CUSTOMER_COUNTER_SPOT_NAMES, "customercounterspot")
	if found then
		return HubWorld.resolveBasePart(found)
	end
	return HubWorld.findCustomerSpot(shop)
end

local CUSTOMER_EXIT_SPOT_NAMES = {
	"CustomerExitSpot",
	"Customer_Exit_Spot",
}

function HubWorld.findCustomerExitSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, CUSTOMER_EXIT_SPOT_NAMES, "customerexitspot")
	return HubWorld.resolveBasePart(found)
end

local SELL_SHELF_LOOK_AT_NAMES = {
	"SellShelfLookAt",
	"InventoryShelfLookAt",
	"Sell_Shelf_Look_At",
}

function HubWorld.findSellShelfLookAt(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, SELL_SHELF_LOOK_AT_NAMES, "sellshelflookat")
	if not found then
		found = HubWorld.findShopPart(shop, SELL_SHELF_LOOK_AT_NAMES, "inventoryshelflookat")
	end
	local part = HubWorld.resolveBasePart(found)
	if part then
		return part
	end

	local shelf = HubWorld.findShelf(shop)
	if not shelf then
		return nil
	end
	if shelf:IsA("Model") then
		local model = shelf :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
	end
	local slot1 = HubWorld.findShelfSlot(shelf, 1)
	if slot1 then
		return slot1
	end
	return HubWorld.resolveBasePart(shelf)
end

local DISPLAY_SHELF_LOOK_AT_NAMES = {
	"DisplayShelfLookAt",
	"Display_Shelf_Look_At",
}

function HubWorld.findDisplayShelfLookAt(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, DISPLAY_SHELF_LOOK_AT_NAMES, "displayshelflookat")
	return HubWorld.resolveBasePart(found)
end

local STORAGE_LOOK_AT_NAMES = {
	"StorageLookAt",
	"StorageBinLookAt",
	"Storage_Look_At",
	"StashLookAt",
	"StashBinLookAt",
	"Stash_Look_At",
}

function HubWorld.findStorageLookAt(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, STORAGE_LOOK_AT_NAMES, "storagelookat")
	if not found then
		found = HubWorld.findShopPart(shop, STORAGE_LOOK_AT_NAMES, "storagebinlookat")
	end
	if not found then
		found = HubWorld.findShopPart(shop, STORAGE_LOOK_AT_NAMES, "stashlookat")
	end
	if not found then
		found = HubWorld.findShopPart(shop, STORAGE_LOOK_AT_NAMES, "stashbinlookat")
	end
	local part = HubWorld.resolveBasePart(found)
	if part then
		return part
	end

	local bin = HubWorld.findStorageBin(shop)
	if not bin then
		return nil
	end
	if bin:IsA("Model") then
		local model = bin :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
	end
	return HubWorld.resolveBasePart(bin)
end

function HubWorld.findStashLookAt(shop: Instance?): BasePart?
	return HubWorld.findStorageLookAt(shop)
end

local PLAYER_COUNTER_SPOT_NAMES = {
	"PlayerCounterSpot",
	"Player_Counter_Spot",
}

function HubWorld.findPlayerCounterSpot(shop: Instance?): BasePart?
	if not shop then
		return nil
	end
	local found = HubWorld.findShopPart(shop, PLAYER_COUNTER_SPOT_NAMES, "playercounterspot")
	return HubWorld.resolveBasePart(found)
end

export type PresentationAnchors = {
	cameraSpot: BasePart,
	counterLookAt: BasePart,
	customerEntry: BasePart?,
	customerCounter: BasePart?,
	customerExit: BasePart?,
	counterItem: BasePart?,
	playerCounter: BasePart?,
	sellShelfLookAt: BasePart?,
	displayShelfLookAt: BasePart?,
	stashLookAt: BasePart?,
}

function HubWorld.resolvePresentationAnchors(shop: Instance?): PresentationAnchors?
	if not shop then
		return nil
	end

	local cameraSpot = HubWorld.findDealCameraSpot(shop)
	local counterLookAt = HubWorld.findCounterLookAt(shop)
		or HubWorld.findCounterItemSpot(shop)
		or HubWorld.findCustomerCounterSpot(shop)

	if not cameraSpot or not counterLookAt then
		return nil
	end

	local customerCounter = HubWorld.findCustomerCounterSpot(shop)
	local customerEntry = HubWorld.findCustomerEntrySpot(shop) or customerCounter

	return {
		cameraSpot = cameraSpot,
		counterLookAt = counterLookAt,
		customerEntry = customerEntry,
		customerCounter = customerCounter,
		customerExit = HubWorld.findCustomerExitSpot(shop),
		counterItem = HubWorld.findCounterItemSpot(shop),
		playerCounter = HubWorld.findPlayerCounterSpot(shop),
		sellShelfLookAt = HubWorld.findSellShelfLookAt(shop),
		displayShelfLookAt = HubWorld.findDisplayShelfLookAt(shop),
		stashLookAt = HubWorld.findStorageLookAt(shop),
	}
end

local INVENTORY_SHELF_EXACT_NAMES = {
	"InventoryShelf",
	"Inventory_Shelf",
	"HeldItemSlots",
	"Held_Item_Slots",
}

function HubWorld.findInventoryShelf(shop: Instance?): Instance?
	if not shop then
		return nil
	end

	local found = HubWorld.findShopPart(shop, INVENTORY_SHELF_EXACT_NAMES, "inventoryshelf")
	if found then
		return found
	end

	return HubWorld.findShopPart(shop, INVENTORY_SHELF_EXACT_NAMES, "helditemslots")
end

function HubWorld.findInventorySlot(shelf: Instance?, slotIndex: number): BasePart?
	if not shelf then
		return nil
	end

	local exactNames = {
		`InventorySlot{slotIndex}`,
		`Inventory_Slot{slotIndex}`,
		`Slot{slotIndex}`,
	}
	local part = HubWorld.resolveBasePart(HubWorld.findChildByNames(shelf, exactNames))
	if part then
		return part
	end

	for _, child in shelf:GetChildren() do
		local hay = normalize(child.Name)
		if string.find(hay, "inventoryslot", 1, true) and string.find(hay, tostring(slotIndex), 1, true) then
			part = HubWorld.resolveBasePart(child)
			if part then
				return part
			end
		end
	end

	for _, child in shelf:GetChildren() do
		local hay = normalize(child.Name)
		if hay == `slot{slotIndex}` or (string.find(hay, "slot", 1, true) and string.find(hay, tostring(slotIndex), 1, true)) then
			if not string.find(hay, "displayslot", 1, true) and not string.find(hay, "shelfback", 1, true) then
				part = HubWorld.resolveBasePart(child)
				if part then
					return part
				end
			end
		end
	end

	return nil
end

local SHELF_EXACT_NAMES = {
	"Shelf",
	"PublicShelf",
	"Public_Shelf",
}

function HubWorld.findShelf(shop: Instance?): Instance?
	if not shop then
		return nil
	end

	local found = HubWorld.findShopPart(shop, SHELF_EXACT_NAMES, "shelf")
	if found then
		return found
	end

	return HubWorld.findDisplayShelf(shop) or HubWorld.findInventoryShelf(shop)
end

function HubWorld.findShelfSlot(shelf: Instance?, slotIndex: number): BasePart?
	if not shelf then
		return nil
	end

	local exactNames = {
		`ShelfSlot{slotIndex}`,
		`Shelf_Slot{slotIndex}`,
		`DisplaySlot{slotIndex}`,
		`Display_Slot{slotIndex}`,
		`Slot{slotIndex}`,
	}
	local part = HubWorld.findDescendantBasePartByNames(shelf, exactNames)
	if part then
		return part
	end

	for _, child in shelf:GetChildren() do
		local hay = normalize(child.Name)
		if hay == `shelfslot{slotIndex}` or hay == `displayslot{slotIndex}` then
			if hay ~= "shelfback" and not string.find(hay, "shelfback", 1, true) then
				part = HubWorld.resolveBasePart(child)
				if part then
					return part
				end
			end
		end
	end

	return HubWorld.findDisplaySlot(shelf, slotIndex, `ShelfSlot{slotIndex}`)
end

local DISPLAY_SHELF_EXACT_NAMES = {
	"DisplayShelf",
	"Display_Shelf",
}

function HubWorld.findDisplayShelf(shop: Instance?): Instance?
	if not shop then
		return nil
	end

	return HubWorld.findShopPart(shop, DISPLAY_SHELF_EXACT_NAMES, "displayshelf")
end

function HubWorld.findDisplayShelfSlot(shelf: Instance?, slotIndex: number): BasePart?
	return HubWorld.findShelfSlot(shelf, slotIndex)
end

function HubWorld.findStorageBin(shop: Instance?): Instance?
	if not shop then
		return nil
	end

	return HubWorld.findChildByNames(shop, {
		"StorageBin",
		"Storage_Bin",
		"Storage",
		"StashBin",
		"Stash_Bin",
		"Stash",
		"Bin",
	})
		or HubWorld.findShopPart(shop, {}, "storagebin")
		or HubWorld.findShopPart(shop, {}, "storage")
		or HubWorld.findShopPart(shop, {}, "stash")
end

function HubWorld.findStashBin(shop: Instance?): Instance?
	return HubWorld.findStorageBin(shop)
end

function HubWorld.findShopPart(shop: Instance?, names: { string }, pattern: string?): Instance?
	local found = HubWorld.findChildByNames(shop, names)
	if found then
		return found
	end

	if pattern then
		local matches = HubWorld.findChildrenMatching(shop, pattern)
		if matches[1] then
			return matches[1]
		end

		local needle = normalize(pattern)
		for _, descendant in shop:GetDescendants() do
			if string.find(normalize(descendant.Name), needle, 1, true) then
				return descendant
			end
		end
	end

	return nil
end

function HubWorld.listChildNames(parent: Instance?, limit: number?): string
	if not parent then
		return "(nil)"
	end
	local names = {}
	for _, child in parent:GetChildren() do
		table.insert(names, child.Name)
	end
	table.sort(names)
	local maxCount = limit or 12
	if #names > maxCount then
		local trimmed = {}
		for index = 1, maxCount do
			trimmed[index] = names[index]
		end
		return table.concat(trimmed, ", ") .. ` ... (+{#names - maxCount} more)`
	end
	return if #names > 0 then table.concat(names, ", ") else "(empty)"
end

return HubWorld
