local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WorldMarkers = {}

local warned: { [string]: boolean } = {}

local TAG_PUBLIC_SHELF = "PublicShelf"
local TAG_SHELF_SLOT = "ShelfSlot"
local TAG_STORAGE_BIN = "StorageBin"
local TAG_SHOP_MARKER = "ShopMarker"
local TAG_COUNTER_MARKER = "CounterMarker"
local TAG_CUSTOMER_MARKER = "CustomerMarker"
local TAG_CAMERA_MARKER = "CameraMarker"

local MARKER_TAGS = {
	TAG_SHOP_MARKER,
	TAG_COUNTER_MARKER,
	TAG_CUSTOMER_MARKER,
	TAG_CAMERA_MARKER,
}

local function normalize(name: string): string
	return string.lower((string.gsub(name, "[%s_%-]", "")))
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function resolveBasePart(instance: Instance?): BasePart?
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

local function findChildByNames(parent: Instance?, names: { string }): Instance?
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

local function findDescendantBasePartByNames(root: Instance?, names: { string }): BasePart?
	if not root then
		return nil
	end

	for _, name in names do
		local child = root:FindFirstChild(name, true)
		local part = resolveBasePart(child)
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
			local part = resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	return nil
end

local function taggedUnder(root: Instance, tag: string): { Instance }
	local results = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(root) then
			table.insert(results, inst)
		end
	end
	return results
end

local function findMarkerByTypeUnder(root: Instance, markerType: string): BasePart?
	local wanted = normalize(markerType)
	for _, tag in MARKER_TAGS do
		for _, inst in taggedUnder(root, tag) do
			local attr = inst:GetAttribute("MarkerType")
			if type(attr) == "string" and normalize(attr) == wanted then
				local part = resolveBasePart(inst)
				if part then
					return part
				end
			end
		end
	end

	for _, descendant in root:GetDescendants() do
		local attr = descendant:GetAttribute("MarkerType")
		if type(attr) == "string" and normalize(attr) == wanted then
			local part = resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	return nil
end

local function findShopPart(shop: Instance?, names: { string }, pattern: string?): Instance?
	local found = findChildByNames(shop, names)
	if found then
		return found
	end

	if not shop or not pattern then
		return nil
	end

	local needle = normalize(pattern)
	for _, child in shop:GetChildren() do
		if string.find(normalize(child.Name), needle, 1, true) then
			return child
		end
	end

	for _, descendant in shop:GetDescendants() do
		if string.find(normalize(descendant.Name), needle, 1, true) then
			return descendant
		end
	end

	return nil
end

function WorldMarkers.getShopRoot(): Instance?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	return world:FindFirstChild("Shop")
end

function WorldMarkers.findPublicShelves(shopRoot: Instance?): { Instance }
	if not shopRoot then
		return {}
	end

	local shelves = {}
	local seen: { [Instance]: boolean } = {}

	for _, inst in taggedUnder(shopRoot, TAG_PUBLIC_SHELF) do
		if not seen[inst] then
			seen[inst] = true
			table.insert(shelves, inst)
		end
	end

	local shelvesFolder = findChildByNames(shopRoot, { "Shelves" })
	if shelvesFolder then
		for _, child in shelvesFolder:GetChildren() do
			if not seen[child] then
				seen[child] = true
				table.insert(shelves, child)
			end
		end
	end

	for _, name in { "Shelf", "PublicShelf", "DisplayShelf" } do
		local found = shopRoot:FindFirstChild(name)
		if found and not seen[found] then
			seen[found] = true
			table.insert(shelves, found)
		end
	end

	table.sort(shelves, function(a, b)
		return a.Name < b.Name
	end)

	return shelves
end

function WorldMarkers.findPrimaryShelf(shopRoot: Instance?): Instance?
	if not shopRoot then
		return nil
	end

	local shelves = WorldMarkers.findPublicShelves(shopRoot)
	if shelves[1] then
		local basic = findChildByNames(shelves[1], { "BasicShelf" })
		if basic then
			return basic
		end
		return shelves[1]
	end

	local basicDirect = findChildByNames(shopRoot, { "BasicShelf" })
	if basicDirect then
		return basicDirect
	end

	local legacy = findShopPart(shopRoot, { "Shelf", "PublicShelf", "DisplayShelf", "InventoryShelf" }, "shelf")
		or findShopPart(shopRoot, { "DisplayShelf" }, "displayshelf")
	if legacy then
		warnOnce("legacy_shelf", "WorldMarkers: using legacy shelf path; prefer Shop.Shelves.BasicShelf.")
	end
	return legacy
end

function WorldMarkers.findShelfSlots(shelfModel: Instance?): { BasePart }
	if not shelfModel then
		return {}
	end

	local slots: { { order: number, part: BasePart } } = {}

	for _, inst in taggedUnder(shelfModel, TAG_SHELF_SLOT) do
		local part = resolveBasePart(inst)
		if part then
			local order = inst:GetAttribute("SlotOrder")
			table.insert(slots, {
				order = if type(order) == "number" then order else 999,
				part = part,
			})
		end
	end

	if #slots == 0 then
		local slotMarkers = findChildByNames(shelfModel, { "SlotMarkers" })
		if slotMarkers then
			local index = 1
			for _, child in slotMarkers:GetChildren() do
				local part = resolveBasePart(child)
				if part then
					local order = child:GetAttribute("SlotOrder")
					table.insert(slots, {
						order = if type(order) == "number" then order else index,
						part = part,
					})
					index += 1
				end
			end
		end
	end

	if #slots == 0 then
		for slotIndex = 1, 6 do
			local part = findDescendantBasePartByNames(shelfModel, {
				`ShelfSlot{slotIndex}`,
				`DisplaySlot{slotIndex}`,
				`Slot{slotIndex}`,
			})
			if part then
				table.insert(slots, { order = slotIndex, part = part })
			end
		end
	end

	table.sort(slots, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.part.Name < b.part.Name
	end)

	local ordered: { BasePart } = {}
	for _, entry in slots do
		table.insert(ordered, entry.part)
	end
	return ordered
end

function WorldMarkers.findShelfSlot(shelfModel: Instance?, slotIndex: number): BasePart?
	local slots = WorldMarkers.findShelfSlots(shelfModel)
	if slots[slotIndex] then
		return slots[slotIndex]
	end
	return findDescendantBasePartByNames(shelfModel, {
		`ShelfSlot{slotIndex}`,
		`DisplaySlot{slotIndex}`,
		`Slot{slotIndex}`,
	})
end

function WorldMarkers.findStorageBin(shopRoot: Instance?): Instance?
	if not shopRoot then
		return nil
	end

	for _, inst in taggedUnder(shopRoot, TAG_STORAGE_BIN) do
		return inst
	end

	local storageFolder = findChildByNames(shopRoot, { "Storage" })
	if storageFolder then
		local bin = findChildByNames(storageFolder, { "StorageBin", "Storage_Bin" })
		if bin then
			return bin
		end
	end

	local loose = findChildByNames(shopRoot, {
		"StorageBin",
		"Storage_Bin",
		"StashBin",
		"Stash_Bin",
	})
	if loose then
		warnOnce("legacy_storage", "WorldMarkers: using legacy StorageBin path; prefer Shop.Storage.StorageBin.")
		return loose
	end

	return findShopPart(shopRoot, {}, "storagebin") or findShopPart(shopRoot, {}, "stashbin")
end

function WorldMarkers.findShopMarker(shopRoot: Instance?, markerType: string): BasePart?
	if not shopRoot then
		return nil
	end
	return findMarkerByTypeUnder(shopRoot, markerType)
end

export type CounterMarkers = {
	counterItemSpot: BasePart?,
	counterLookAt: BasePart?,
	dealCameraSpot: BasePart?,
}

function WorldMarkers.findCounterMarkers(shopRoot: Instance?): CounterMarkers
	local result: CounterMarkers = {}
	if not shopRoot then
		return result
	end

	local counter = findChildByNames(shopRoot, { "Counter" })
	if counter then
		local markers = findChildByNames(counter, { "Markers" })
		if markers then
			result.counterItemSpot = resolveBasePart(findChildByNames(markers, { "CounterItemSpot" }))
			result.counterLookAt = resolveBasePart(findChildByNames(markers, { "CounterLookAt" }))
			result.dealCameraSpot = resolveBasePart(findChildByNames(markers, { "DealCameraSpot", "ShopCameraSpot" }))
		end
	end

	result.counterItemSpot = result.counterItemSpot
		or findMarkerByTypeUnder(shopRoot, "CounterItemSpot")
		or findDescendantBasePartByNames(shopRoot, { "CounterItemSpot" })
	result.counterLookAt = result.counterLookAt
		or findMarkerByTypeUnder(shopRoot, "CounterLookAt")
		or findDescendantBasePartByNames(shopRoot, { "CounterLookAt" })
	result.dealCameraSpot = result.dealCameraSpot
		or findMarkerByTypeUnder(shopRoot, "DealCameraSpot")
		or findDescendantBasePartByNames(shopRoot, { "DealCameraSpot", "ShopCameraSpot" })

	return result
end

export type CustomerPathMarkers = {
	entry: BasePart?,
	counter: BasePart?,
	exit: BasePart?,
}

function WorldMarkers.findCustomerPathMarkers(shopRoot: Instance?): CustomerPathMarkers
	local result: CustomerPathMarkers = {}
	if not shopRoot then
		return result
	end

	local path = findChildByNames(shopRoot, { "CustomerPath" })
	if path then
		result.entry = resolveBasePart(findChildByNames(path, { "CustomerEntrySpot" }))
		result.counter = resolveBasePart(findChildByNames(path, { "CustomerSpot", "CustomerCounterSpot" }))
		result.exit = resolveBasePart(findChildByNames(path, { "CustomerExitSpot" }))
	end

	result.entry = result.entry
		or findMarkerByTypeUnder(shopRoot, "CustomerEntry")
		or findDescendantBasePartByNames(shopRoot, { "CustomerEntrySpot" })
	result.counter = result.counter
		or findMarkerByTypeUnder(shopRoot, "CustomerCounter")
		or findDescendantBasePartByNames(shopRoot, { "CustomerSpot", "CustomerCounterSpot" })
	result.exit = result.exit
		or findMarkerByTypeUnder(shopRoot, "CustomerExit")
		or findDescendantBasePartByNames(shopRoot, { "CustomerExitSpot" })

	return result
end

export type ShelfFocusMarkers = {
	camera: BasePart?,
	lookAt: BasePart?,
	source: string,
	cameraPosition: Vector3?,
	lookAtPosition: Vector3?,
}

local function deriveShelfFocusPose(shelfModel: Instance): (Vector3?, Vector3?)
	local lookParts = WorldMarkers.findShelfSlots(shelfModel)
	local lookAt = Vector3.zero
	if #lookParts > 0 then
		for _, part in lookParts do
			lookAt += part.Position
		end
		lookAt /= #lookParts
	else
		local part = resolveBasePart(shelfModel)
		if not part then
			return nil, nil
		end
		lookAt = part.Position
	end

	local cameraPos: Vector3
	if shelfModel:IsA("Model") then
		local cf, size = (shelfModel :: Model):GetBoundingBox()
		local forward = cf.LookVector
		cameraPos = lookAt - forward * math.max(size.Z, size.X, 4) + Vector3.new(0, math.clamp(size.Y * 0.35, 1.5, 5), 0)
	else
		local part = resolveBasePart(shelfModel)
		if not part then
			return nil, nil
		end
		cameraPos = part.Position + part.CFrame.LookVector * -6 + Vector3.new(0, 3, 0)
	end
	return cameraPos, lookAt
end

function WorldMarkers.findShelfFocusMarkers(shopRoot: Instance?, shelfModel: Instance?): ShelfFocusMarkers
	local empty: ShelfFocusMarkers = { source = "none" }
	if not shelfModel then
		return empty
	end

	local camera = findMarkerByTypeUnder(shelfModel, "ShelfFocusCamera")
	local lookAt = findMarkerByTypeUnder(shelfModel, "ShelfFocusLookAt")
	if camera and lookAt then
		return {
			camera = camera,
			lookAt = lookAt,
			source = "tag",
			cameraPosition = camera.Position,
			lookAtPosition = lookAt.Position,
		}
	end

	local markersFolder = findChildByNames(shelfModel, { "Markers" })
	if markersFolder then
		camera = camera or resolveBasePart(findChildByNames(markersFolder, { "ShelfCameraSpot", "Shelf_Camera_Spot" }))
		lookAt = lookAt or resolveBasePart(findChildByNames(markersFolder, { "ShelfLookAt", "Shelf_Look_At" }))
		if camera and lookAt then
			return {
				camera = camera,
				lookAt = lookAt,
				source = "hierarchy",
				cameraPosition = camera.Position,
				lookAtPosition = lookAt.Position,
			}
		end
	end

	camera = camera
		or findDescendantBasePartByNames(shelfModel, { "ShelfCameraSpot", "Shelf_Camera_Spot" })
	lookAt = lookAt or findDescendantBasePartByNames(shelfModel, { "ShelfLookAt", "Shelf_Look_At" })
	if shopRoot then
		lookAt = lookAt
			or findDescendantBasePartByNames(shopRoot, { "DisplayShelfLookAt", "SellShelfLookAt" })
	end

	if camera and lookAt then
		warnOnce("legacy_shelf_focus", "WorldMarkers: using legacy shelf focus markers; prefer BasicShelf.Markers.")
		return {
			camera = camera,
			lookAt = lookAt,
			source = "legacy",
			cameraPosition = camera.Position,
			lookAtPosition = lookAt.Position,
		}
	end

	local camPos, lookPos = deriveShelfFocusPose(shelfModel)
	if camPos and lookPos then
		warnOnce("derived_shelf_focus", "WorldMarkers: derived shelf focus camera from shelf bounds; add BasicShelf.Markers.")
		return {
			source = "derived",
			cameraPosition = camPos,
			lookAtPosition = lookPos,
		}
	end

	return empty
end

export type ResolvedMarker = {
	part: BasePart?,
	source: string,
}

export type MarkerSources = {
	shelf: string,
	shelfFocus: string,
	counter: string,
	customer: string,
	storage: string,
}

function WorldMarkers.getPrimaryShelfSource(shopRoot: Instance?): string
	if not shopRoot then
		return "none"
	end
	for _, inst in taggedUnder(shopRoot, TAG_PUBLIC_SHELF) do
		return "tag"
	end
	local shelvesFolder = findChildByNames(shopRoot, { "Shelves" })
	if shelvesFolder and findChildByNames(shelvesFolder, { "BasicShelf" }) then
		return "hierarchy"
	end
	if findChildByNames(shopRoot, { "BasicShelf" }) then
		return "hierarchy"
	end
	local legacy = findShopPart(shopRoot, { "Shelf", "PublicShelf", "DisplayShelf", "InventoryShelf" }, "shelf")
	if legacy then
		return "legacy"
	end
	return "none"
end

function WorldMarkers.findShelfLookAt(shopRoot: Instance?): ResolvedMarker
	local empty: ResolvedMarker = { source = "none" }
	if not shopRoot then
		return empty
	end

	local shelf = WorldMarkers.findPrimaryShelf(shopRoot)
	if shelf then
		local tagged = findMarkerByTypeUnder(shelf, "ShelfFocusLookAt")
		if tagged then
			return { part = tagged, source = "tag" }
		end
		local markersFolder = findChildByNames(shelf, { "Markers" })
		if markersFolder then
			local part = resolveBasePart(findChildByNames(markersFolder, { "ShelfLookAt", "Shelf_Look_At" }))
			if part then
				return { part = part, source = "hierarchy" }
			end
		end
	end

	local legacy = findDescendantBasePartByNames(shopRoot, {
		"DisplayShelfLookAt",
		"SellShelfLookAt",
		"ShelfLookAt",
	})
	if legacy then
		return { part = legacy, source = "legacy" }
	end

	if shelf then
		local slots = WorldMarkers.findShelfSlots(shelf)
		if slots[1] then
			return { part = slots[1], source = "derived" }
		end
		local part = resolveBasePart(shelf)
		if part then
			return { part = part, source = "derived" }
		end
	end

	return empty
end

function WorldMarkers.findStorageLookAt(shopRoot: Instance?): ResolvedMarker
	local empty: ResolvedMarker = { source = "none" }
	if not shopRoot then
		return empty
	end

	local tagged = findMarkerByTypeUnder(shopRoot, "StorageLookAt")
	if tagged then
		return { part = tagged, source = "tag" }
	end

	local storageModel = findChildByNames(shopRoot, { "Storage" })
	if storageModel then
		local bin = findChildByNames(storageModel, { "StorageBin", "Storage_Bin" })
		local part = resolveBasePart(bin)
		if part then
			return { part = part, source = "hierarchy" }
		end
	end

	local legacy = findDescendantBasePartByNames(shopRoot, {
		"StorageLookAt",
		"StorageBinLookAt",
		"StashLookAt",
		"StashBinLookAt",
	})
	if legacy then
		return { part = legacy, source = "legacy" }
	end

	local bin = WorldMarkers.findStorageBin(shopRoot)
	local part = resolveBasePart(bin)
	if part then
		return { part = part, source = "derived" }
	end

	return empty
end

function WorldMarkers.findCustomerSpot(shopRoot: Instance?): ResolvedMarker
	local empty: ResolvedMarker = { source = "none" }
	if not shopRoot then
		return empty
	end

	local path = findChildByNames(shopRoot, { "CustomerPath" })
	if path then
		local part = resolveBasePart(findChildByNames(path, { "CustomerSpot", "CustomerCounterSpot" }))
		if part then
			return { part = part, source = "hierarchy" }
		end
	end

	local tagged = findMarkerByTypeUnder(shopRoot, "CustomerCounter")
	if tagged then
		return { part = tagged, source = "tag" }
	end

	local legacy = findDescendantBasePartByNames(shopRoot, { "CustomerSpot", "CustomerCounterSpot" })
	if legacy then
		return { part = legacy, source = "legacy" }
	end

	return empty
end

function WorldMarkers.getCounterMarkersSource(shopRoot: Instance?): string
	if not shopRoot then
		return "none"
	end
	local counter = findChildByNames(shopRoot, { "Counter" })
	local markers = counter and findChildByNames(counter, { "Markers" })
	if markers then
		if resolveBasePart(findChildByNames(markers, { "CounterItemSpot" }))
			or resolveBasePart(findChildByNames(markers, { "CounterLookAt" }))
			or resolveBasePart(findChildByNames(markers, { "DealCameraSpot", "ShopCameraSpot" }))
		then
			return "hierarchy"
		end
	end
	for _, tag in MARKER_TAGS do
		for _, inst in taggedUnder(shopRoot, tag) do
			local attr = inst:GetAttribute("MarkerType")
			if type(attr) == "string" then
				local n = normalize(attr)
				if n == "counteritemspot" or n == "counterlookat" or n == "dealcameraspot" then
					return "tag"
				end
			end
		end
	end
	local legacy = findDescendantBasePartByNames(shopRoot, { "CounterItemSpot", "CounterLookAt", "DealCameraSpot" })
	if legacy then
		return "legacy"
	end
	return "none"
end

function WorldMarkers.getCustomerPathSource(shopRoot: Instance?): string
	if not shopRoot then
		return "none"
	end
	local path = findChildByNames(shopRoot, { "CustomerPath" })
	if path then
		if resolveBasePart(findChildByNames(path, { "CustomerEntrySpot" }))
			or resolveBasePart(findChildByNames(path, { "CustomerSpot", "CustomerCounterSpot" }))
			or resolveBasePart(findChildByNames(path, { "CustomerExitSpot" }))
		then
			return "hierarchy"
		end
	end
	for _, tag in { TAG_CUSTOMER_MARKER, TAG_SHOP_MARKER } do
		for _, inst in taggedUnder(shopRoot, tag) do
			local attr = inst:GetAttribute("MarkerType")
			if type(attr) == "string" then
				local n = normalize(attr)
				if n == "customerentry" or n == "customercounter" or n == "customerexit" then
					return "tag"
				end
			end
		end
	end
	local legacy = findDescendantBasePartByNames(shopRoot, {
		"CustomerEntrySpot",
		"CustomerSpot",
		"CustomerExitSpot",
	})
	if legacy then
		return "legacy"
	end
	return "none"
end

function WorldMarkers.getStorageBinSource(shopRoot: Instance?): string
	if not shopRoot then
		return "none"
	end
	for _, _ in taggedUnder(shopRoot, TAG_STORAGE_BIN) do
		return "tag"
	end
	local storageModel = findChildByNames(shopRoot, { "Storage" })
	if storageModel and findChildByNames(storageModel, { "StorageBin", "Storage_Bin" }) then
		return "hierarchy"
	end
	local loose = findChildByNames(shopRoot, { "StorageBin", "StashBin" })
	if loose then
		return "legacy"
	end
	if findShopPart(shopRoot, {}, "storagebin") or findShopPart(shopRoot, {}, "stashbin") then
		return "legacy"
	end
	return "none"
end

function WorldMarkers.collectMarkerSources(shopRoot: Instance?): MarkerSources
	local shelf = WorldMarkers.findPrimaryShelf(shopRoot)
	local focus = WorldMarkers.findShelfFocusMarkers(shopRoot, shelf)
	return {
		shelf = WorldMarkers.getPrimaryShelfSource(shopRoot),
		shelfFocus = focus.source,
		counter = WorldMarkers.getCounterMarkersSource(shopRoot),
		customer = WorldMarkers.getCustomerPathSource(shopRoot),
		storage = WorldMarkers.getStorageBinSource(shopRoot),
	}
end

function WorldMarkers.findShelfPromptAnchor(shelfModel: Instance?): BasePart?
	if not shelfModel then
		return nil
	end

	local markersFolder = findChildByNames(shelfModel, { "Markers" })
	if markersFolder then
		local anchor = findChildByNames(markersFolder, { "ShelfPromptAnchor", "Shelf_Prompt_Anchor" })
		local part = resolveBasePart(anchor)
		if part then
			return part
		end
	end

	local shelfParts = findChildByNames(shelfModel, { "ShelfParts" })
	return resolveBasePart(shelfParts) or resolveBasePart(shelfModel)
end

function WorldMarkers.findOutsidePickupParent(outside: Instance?): Instance?
	if not outside then
		return nil
	end
	local scavengeNodes = findChildByNames(outside, { "ScavengeNodes", "Scavenge_Nodes" })
	if scavengeNodes then
		return scavengeNodes
	end
	return findChildByNames(outside, { "JunkLot", "Junk_Lot", "Junklot" })
end

export type PresentationAnchorsBundle = {
	cameraSpot: BasePart?,
	counterLookAt: BasePart?,
	customerEntry: BasePart?,
	customerCounter: BasePart?,
	customerExit: BasePart?,
	counterItem: BasePart?,
	playerCounter: BasePart?,
	sellShelfLookAt: BasePart?,
	displayShelfLookAt: BasePart?,
	stashLookAt: BasePart?,
	sources: MarkerSources,
}

function WorldMarkers.resolvePresentationAnchors(shopRoot: Instance?): PresentationAnchorsBundle?
	if not shopRoot then
		return nil
	end

	local counter = WorldMarkers.findCounterMarkers(shopRoot)
	local customer = WorldMarkers.findCustomerPathMarkers(shopRoot)
	local shelfLook = WorldMarkers.findShelfLookAt(shopRoot)
	local storageLook = WorldMarkers.findStorageLookAt(shopRoot)
	local sources = WorldMarkers.collectMarkerSources(shopRoot)

	local cameraSpot = counter.dealCameraSpot
	local counterLookAt = counter.counterLookAt or counter.counterItemSpot or customer.counter

	if not cameraSpot or not counterLookAt then
		return nil
	end

	local playerCounter = findDescendantBasePartByNames(shopRoot, { "PlayerCounterSpot", "Player_Counter_Spot" })

	return {
		cameraSpot = cameraSpot,
		counterLookAt = counterLookAt,
		customerEntry = customer.entry or customer.counter,
		customerCounter = customer.counter,
		customerExit = customer.exit,
		counterItem = counter.counterItemSpot,
		playerCounter = playerCounter,
		sellShelfLookAt = shelfLook.part,
		displayShelfLookAt = shelfLook.part,
		stashLookAt = storageLook.part,
		sources = sources,
	}
end

return WorldMarkers
