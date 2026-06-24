local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local DisplayInfluence = require(Shared.Economy.DisplayInfluence)
local ObjectModel = require(Shared.Util.ObjectModel)

local InventoryService = {}

local DEFAULT_MAX_SLOTS = 3
local DEFAULT_DISPLAY_SLOTS = 3
local DEFAULT_STASH_SLOTS = 2

local LOCATION_INVENTORY = ObjectModel.Locations.Inventory
local LOCATION_DISPLAY = ObjectModel.Locations.Display
local LOCATION_STASH = ObjectModel.Locations.Stash

local DataService = require(script.Parent.DataService)

local inventories: { [Player]: { items: { any }, maxSlots: number, displayMaxSlots: number, stashMaxSlots: number } } = {}
local nextInstanceId = 0

function InventoryService:Init()
	Remotes.setup()
	DataService:setShopStateProvider(function(player)
		return self:getPersistentShopState(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1.5, function()
			if player.Parent then
				self:_ensureInventory(player)
				self:_pushState(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService:savePlayer(player, "inventory_leave")
		task.defer(function()
			inventories[player] = nil
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.delay(1.5, function()
			if player.Parent then
				self:_ensureInventory(player)
				self:_pushState(player)
			end
		end)
	end
end

function InventoryService:Start() end

function InventoryService:_nextInstanceId(): string
	nextInstanceId += 1
	return `item_{nextInstanceId}`
end

function InventoryService:_newPermanentId(): string
	return HttpService:GenerateGUID(false)
end

function InventoryService:_markPersistentDirty(player: Player)
	DataService:markShopStateDirty(player)
	task.spawn(function()
		if player.Parent then
			DataService:savePlayer(player, "shop_state_changed")
		end
	end)
end

function InventoryService:_applyPermanentHome(entry, location: string, slotIndex: number)
	entry.permanentId = entry.permanentId or self:_newPermanentId()
	entry.permanentOrigin = true
	entry.permanentHomeLocation = location
	entry.permanentHomeSlotIndex = slotIndex
end

function InventoryService:_updatePermanentHomeFromLocation(entry)
	local location = self:_itemLocation(entry)
	if location == LOCATION_DISPLAY and entry.displaySlotIndex then
		self:_applyPermanentHome(entry, LOCATION_DISPLAY, entry.displaySlotIndex)
	elseif location == LOCATION_STASH and entry.stashSlotIndex then
		self:_applyPermanentHome(entry, LOCATION_STASH, entry.stashSlotIndex)
	end
end

function InventoryService:_copyLoadedEntry(raw, location: string, slotIndex: number)
	local entry = {
		instanceId = self:_nextInstanceId(),
		permanentId = raw.permanentId or self:_newPermanentId(),
		permanentOrigin = true,
		permanentHomeLocation = location,
		permanentHomeSlotIndex = slotIndex,
		objectId = raw.objectId or raw.itemId,
		itemId = raw.itemId or raw.objectId,
		displayName = raw.displayName,
		dealArchetypeId = raw.dealArchetypeId,
		dealArchetypeName = raw.dealArchetypeName,
		category = raw.category,
		traits = raw.traits or {},
		flavorText = raw.flavorText,
		rarityId = raw.rarityId,
		trueValue = raw.trueValue,
		purchasePrice = raw.purchasePrice,
		estimatedLow = raw.estimatedLow,
		estimatedHigh = raw.estimatedHigh,
		sellerId = raw.sellerId,
		sellerName = raw.sellerName,
		sellerTell = raw.sellerTell,
		sellerAsk = raw.sellerAsk,
		sellerMinimum = raw.sellerMinimum,
		inspected = raw.inspected == true,
		buyRoundCount = raw.buyRoundCount,
		tacticsUsed = raw.tacticsUsed or {},
		location = location,
		heldBack = false,
		displaySlotIndex = if location == LOCATION_DISPLAY then slotIndex else nil,
		stashSlotIndex = if location == LOCATION_STASH then slotIndex else nil,
	}
	return ObjectModel.normalizeOwnedObject(entry)
end

function InventoryService:_applyLoadedPersistentState(player: Player, inventory)
	if inventory.persistentStateLoaded then
		return
	end
	inventory.persistentStateLoaded = true

	local state = DataService:getLoadedPersistentState(player)
	local usedPermanentIds = {}
	local usedDisplaySlots = {}
	local usedStashSlots = {}

	for _, raw in (state.display or {}) do
		local slotIndex = raw.displaySlotIndex
		local permanentId = raw.permanentId
		if
			type(slotIndex) == "number"
			and slotIndex >= 1
			and slotIndex <= inventory.displayMaxSlots
			and not usedDisplaySlots[slotIndex]
			and (not permanentId or not usedPermanentIds[permanentId])
		then
			local entry = self:_copyLoadedEntry(raw, LOCATION_DISPLAY, slotIndex)
			usedDisplaySlots[slotIndex] = true
			usedPermanentIds[entry.permanentId] = true
			table.insert(inventory.items, entry)
		end
	end

	for _, raw in (state.stash or {}) do
		local slotIndex = raw.stashSlotIndex
		local permanentId = raw.permanentId
		if
			type(slotIndex) == "number"
			and slotIndex >= 1
			and slotIndex <= inventory.stashMaxSlots
			and not usedStashSlots[slotIndex]
			and (not permanentId or not usedPermanentIds[permanentId])
		then
			local entry = self:_copyLoadedEntry(raw, LOCATION_STASH, slotIndex)
			usedStashSlots[slotIndex] = true
			usedPermanentIds[entry.permanentId] = true
			table.insert(inventory.items, entry)
		end
	end
end

function InventoryService:_ensureInventory(player: Player)
	local inventory = inventories[player]
	if not inventory then
		inventory = {
			items = {},
			maxSlots = DEFAULT_MAX_SLOTS,
			displayMaxSlots = DEFAULT_DISPLAY_SLOTS,
			stashMaxSlots = DEFAULT_STASH_SLOTS,
		}
		inventories[player] = inventory
	end
	if inventory.displayMaxSlots == nil then
		inventory.displayMaxSlots = DEFAULT_DISPLAY_SLOTS
	end
	if inventory.stashMaxSlots == nil then
		inventory.stashMaxSlots = DEFAULT_STASH_SLOTS
	end
	self:_applyLoadedPersistentState(player, inventory)
	return inventory
end

function InventoryService:_itemLocation(entry): string
	return ObjectModel.normalizeLocation(entry.location)
end

function InventoryService:_serializeItem(entry)
	return ObjectModel.serializeForInventorySnapshot(entry)
end

function InventoryService:_pushState(player: Player)
	(Remotes.get("InventoryStateUpdate") :: RemoteEvent):FireClient(player, self:getSnapshot(player))
end

function InventoryService:pushSnapshot(player: Player)
	self:_pushState(player)
end

function InventoryService:startShiftInventory(player: Player, maxSlots: number?)
	self:restorePermanentInventoryItems(player)
	local existing = inventories[player]
	local preservedItems = {}
	local displayMaxSlots = DEFAULT_DISPLAY_SLOTS
	local stashMaxSlots = DEFAULT_STASH_SLOTS
	local persistentStateLoaded = true

	if existing then
		displayMaxSlots = existing.displayMaxSlots or DEFAULT_DISPLAY_SLOTS
		stashMaxSlots = existing.stashMaxSlots or DEFAULT_STASH_SLOTS
		persistentStateLoaded = existing.persistentStateLoaded == true
		for _, entry in existing.items do
			local location = self:_itemLocation(entry)
			if not entry.disposed and (location == LOCATION_DISPLAY or location == LOCATION_STASH) then
				table.insert(preservedItems, entry)
			end
		end
	end

	inventories[player] = {
		items = preservedItems,
		maxSlots = maxSlots or DEFAULT_MAX_SLOTS,
		displayMaxSlots = displayMaxSlots,
		stashMaxSlots = stashMaxSlots,
		persistentStateLoaded = persistentStateLoaded,
	}
	self:migrateLegacyInventoryToShelf(player)
	self:_pushState(player)
end

function InventoryService:migrateLegacyInventoryToShelf(player: Player): number
	local inventory = inventories[player]
	if not inventory then
		return 0
	end

	local migrated = 0
	for _, entry in inventory.items do
		if entry.disposed or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
			continue
		end

		local displaySlotIndex = self:findFirstEmptyDisplaySlot(player, entry.instanceId)
		if not displaySlotIndex then
			continue
		end

		entry.location = LOCATION_DISPLAY
		entry.heldBack = false
		entry.displaySlotIndex = displaySlotIndex
		entry.stashSlotIndex = nil
		self:_applyPermanentHome(entry, LOCATION_DISPLAY, displaySlotIndex)
		migrated += 1
	end

	if migrated > 0 then
		self:_markPersistentDirty(player)
	end
	return migrated
end

function InventoryService:addPurchasedItemToShelf(player: Player, entry)
	if not self:canAddToDisplay(player) then
		return nil
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return nil
	end

	local inventory = self:_ensureInventory(player)
	entry.instanceId = entry.instanceId or self:_nextInstanceId()
	ObjectModel.normalizeOwnedObject(entry)
	entry.location = LOCATION_DISPLAY
	entry.heldBack = false
	entry.displaySlotIndex = displaySlotIndex
	entry.stashSlotIndex = nil
	self:_applyPermanentHome(entry, LOCATION_DISPLAY, displaySlotIndex)
	table.insert(inventory.items, entry)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return entry.instanceId
end

function InventoryService:addAcquiredItemToStash(player: Player, entry)
	if not self:canAddToStash(player) then
		return nil
	end

	local stashSlotIndex = self:findFirstEmptyStashSlot(player)
	if not stashSlotIndex then
		return nil
	end

	local inventory = self:_ensureInventory(player)
	entry.instanceId = entry.instanceId or self:_nextInstanceId()
	ObjectModel.normalizeOwnedObject(entry)
	entry.location = LOCATION_STASH
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = stashSlotIndex
	self:_applyPermanentHome(entry, LOCATION_STASH, stashSlotIndex)
	table.insert(inventory.items, entry)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return entry.instanceId
end

function InventoryService:addAcquiredItemToShelfOrStash(player: Player, entry): (boolean, string?, string?)
	if self:canAddToDisplay(player) then
		local instanceId = self:addPurchasedItemToShelf(player, entry)
		if instanceId then
			return true, LOCATION_DISPLAY, instanceId
		end
	end

	if self:canAddToStash(player) then
		local instanceId = self:addAcquiredItemToStash(player, entry)
		if instanceId then
			return true, LOCATION_STASH, instanceId
		end
	end

	return false, nil, nil
end

function InventoryService:addPurchasedItem(player: Player, entry)
	if not self:canAdd(player) then
		return nil
	end

	local inventory = self:_ensureInventory(player)
	local list = inventory.items
	entry.instanceId = entry.instanceId or self:_nextInstanceId()
	ObjectModel.normalizeOwnedObject(entry)
	entry.location = LOCATION_INVENTORY
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = nil
	table.insert(list, entry)
	self:_pushState(player)
	return entry.instanceId
end

function InventoryService:getOwnedItem(player: Player, instanceId: string)
	local inventory = inventories[player]
	if not inventory then
		return nil
	end

	for _, entry in inventory.items do
		if entry.instanceId == instanceId and not entry.disposed then
			return entry
		end
	end

	return nil
end

function InventoryService:setItemHeldBack(player: Player, instanceId: string, heldBack: boolean): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	entry.heldBack = heldBack == true
	self:_pushState(player)
	return true
end

function InventoryService:_reserveHomeSlotIfNeeded(entry, location: string, taken: { [number]: boolean }, ignoreInstanceId: string?)
	if entry.disposed or entry.permanentOrigin ~= true then
		return
	end
	if ignoreInstanceId and entry.instanceId == ignoreInstanceId then
		return
	end
	if self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return
	end
	if entry.permanentHomeLocation ~= location then
		return
	end
	local slotIndex = entry.permanentHomeSlotIndex
	if type(slotIndex) == "number" then
		taken[slotIndex] = true
	end
end

function InventoryService:findFirstEmptyDisplaySlot(player: Player, ignoreInstanceId: string?): number?
	local inventory = self:_ensureInventory(player)
	local taken = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_DISPLAY and entry.displaySlotIndex then
			taken[entry.displaySlotIndex] = true
		end
		self:_reserveHomeSlotIfNeeded(entry, LOCATION_DISPLAY, taken, ignoreInstanceId)
	end

	for slotIndex = 1, inventory.displayMaxSlots do
		if not taken[slotIndex] then
			return slotIndex
		end
	end

	return nil
end

function InventoryService:findFirstEmptyStashSlot(player: Player, ignoreInstanceId: string?): number?
	local inventory = self:_ensureInventory(player)
	local taken = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_STASH and entry.stashSlotIndex then
			taken[entry.stashSlotIndex] = true
		end
		self:_reserveHomeSlotIfNeeded(entry, LOCATION_STASH, taken, ignoreInstanceId)
	end

	for slotIndex = 1, inventory.stashMaxSlots do
		if not taken[slotIndex] then
			return slotIndex
		end
	end

	return nil
end

function InventoryService:moveItemToDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player, instanceId)
	if not displaySlotIndex then
		return false
	end

	entry.location = LOCATION_DISPLAY
	entry.heldBack = false
	entry.displaySlotIndex = displaySlotIndex
	entry.stashSlotIndex = nil
	self:_applyPermanentHome(entry, LOCATION_DISPLAY, displaySlotIndex)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return true
end

function InventoryService:returnItemFromDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_DISPLAY then
		return false
	end
	if not self:canAdd(player) then
		return false
	end

	entry.location = LOCATION_INVENTORY
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = nil
	self:_pushState(player)
	if entry.permanentOrigin == true then
		self:_markPersistentDirty(player)
	end
	return true
end

function InventoryService:moveInventoryItemToStash(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
		return false
	end

	local stashSlotIndex = self:findFirstEmptyStashSlot(player, instanceId)
	if not stashSlotIndex then
		return false
	end

	entry.location = LOCATION_STASH
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = stashSlotIndex
	self:_applyPermanentHome(entry, LOCATION_STASH, stashSlotIndex)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return true
end

function InventoryService:returnItemFromStash(player: Player, instanceId: string): boolean
	return self:moveStashItemToDisplay(player, instanceId)
end

function InventoryService:moveDisplayItemToStash(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_DISPLAY then
		return false
	end

	local stashSlotIndex = self:findFirstEmptyStashSlot(player)
	if not stashSlotIndex then
		return false
	end

	entry.location = LOCATION_STASH
	entry.heldBack = false
	entry.displaySlotIndex = nil
	entry.stashSlotIndex = stashSlotIndex
	self:_applyPermanentHome(entry, LOCATION_STASH, stashSlotIndex)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return true
end

function InventoryService:moveDisplayItemToDisplaySlot(
	player: Player,
	instanceId: string,
	targetSlotIndex: number
): (boolean, string?)
	local inventory = self:_ensureInventory(player)
	local entry = self:getOwnedItem(player, instanceId)
	if not entry then
		return false, "Item not found"
	end
	if self:_itemLocation(entry) ~= LOCATION_DISPLAY then
		return false, "Item not on Shelf"
	end
	if type(targetSlotIndex) ~= "number" or targetSlotIndex ~= targetSlotIndex then
		return false, "Invalid Shelf slot"
	end

	targetSlotIndex = math.floor(targetSlotIndex)
	if targetSlotIndex < 1 or targetSlotIndex > inventory.displayMaxSlots then
		return false, "Invalid Shelf slot"
	end
	if entry.displaySlotIndex == targetSlotIndex then
		return false, "Choose a different Shelf slot."
	end

	local sourceSlotIndex = entry.displaySlotIndex
	if type(sourceSlotIndex) ~= "number" then
		return false, "Item has no Shelf slot"
	end

	local swapEntry = nil
	for _, other in inventory.items do
		if other.disposed or other.instanceId == instanceId then
			continue
		end

		local location = self:_itemLocation(other)
		if location == LOCATION_DISPLAY and other.displaySlotIndex == targetSlotIndex then
			swapEntry = other
		end
		if
			location == LOCATION_INVENTORY
			and other.permanentOrigin == true
			and other.permanentHomeLocation == LOCATION_DISPLAY
			and other.permanentHomeSlotIndex == targetSlotIndex
		then
			return false, "Shelf slot is reserved."
		end
	end

	entry.displaySlotIndex = targetSlotIndex
	entry.heldBack = false
	entry.stashSlotIndex = nil
	self:_applyPermanentHome(entry, LOCATION_DISPLAY, targetSlotIndex)
	if swapEntry then
		swapEntry.displaySlotIndex = sourceSlotIndex
		swapEntry.heldBack = false
		swapEntry.stashSlotIndex = nil
		self:_applyPermanentHome(swapEntry, LOCATION_DISPLAY, sourceSlotIndex)
	end
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return true, nil
end

function InventoryService:moveStashItemToDisplay(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry or self:_itemLocation(entry) ~= LOCATION_STASH then
		return false
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return false
	end

	entry.location = LOCATION_DISPLAY
	entry.heldBack = false
	entry.displaySlotIndex = displaySlotIndex
	entry.stashSlotIndex = nil
	self:_applyPermanentHome(entry, LOCATION_DISPLAY, displaySlotIndex)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return true
end

function InventoryService:markDisposed(player: Player, instanceId: string): boolean
	local entry = self:getOwnedItem(player, instanceId)
	if not entry then
		return false
	end

	entry.disposed = true
	self:_pushState(player)
	if entry.permanentOrigin == true then
		self:_markPersistentDirty(player)
	end
	return true
end

function InventoryService:_serializePersistentItem(entry, location: string, slotIndex: number)
	return {
		permanentId = entry.permanentId,
		itemId = entry.itemId or entry.objectId,
		objectId = entry.objectId or entry.itemId,
		displayName = entry.displayName,
		dealArchetypeId = entry.dealArchetypeId,
		dealArchetypeName = entry.dealArchetypeName,
		category = entry.category,
		traits = entry.traits or {},
		flavorText = entry.flavorText,
		rarityId = entry.rarityId,
		trueValue = entry.trueValue,
		purchasePrice = entry.purchasePrice,
		estimatedLow = entry.estimatedLow,
		estimatedHigh = entry.estimatedHigh,
		sellerId = entry.sellerId,
		sellerName = entry.sellerName,
		sellerTell = entry.sellerTell,
		sellerAsk = entry.sellerAsk,
		sellerMinimum = entry.sellerMinimum,
		inspected = entry.inspected == true,
		buyRoundCount = entry.buyRoundCount,
		tacticsUsed = entry.tacticsUsed or {},
		displaySlotIndex = if location == LOCATION_DISPLAY then slotIndex else nil,
		stashSlotIndex = if location == LOCATION_STASH then slotIndex else nil,
	}
end

function InventoryService:getPersistentShopState(player: Player)
	local inventory = self:_ensureInventory(player)
	local display = {}
	local stash = {}
	local seenPermanentIds = {}

	for _, entry in inventory.items do
		if entry.disposed then
			continue
		end

		local location = self:_itemLocation(entry)
		local saveLocation = nil
		local slotIndex = nil

		if location == LOCATION_DISPLAY and entry.displaySlotIndex then
			saveLocation = LOCATION_DISPLAY
			slotIndex = entry.displaySlotIndex
			self:_updatePermanentHomeFromLocation(entry)
		elseif location == LOCATION_STASH and entry.stashSlotIndex then
			saveLocation = LOCATION_STASH
			slotIndex = entry.stashSlotIndex
			self:_updatePermanentHomeFromLocation(entry)
		elseif location == LOCATION_INVENTORY and entry.permanentOrigin == true then
			saveLocation = entry.permanentHomeLocation
			slotIndex = entry.permanentHomeSlotIndex
		end

		if saveLocation ~= LOCATION_DISPLAY and saveLocation ~= LOCATION_STASH then
			continue
		end
		if type(slotIndex) ~= "number" then
			continue
		end

		entry.permanentId = entry.permanentId or self:_newPermanentId()
		if seenPermanentIds[entry.permanentId] then
			continue
		end
		seenPermanentIds[entry.permanentId] = true

		local payload = self:_serializePersistentItem(entry, saveLocation, slotIndex)
		if saveLocation == LOCATION_DISPLAY then
			table.insert(display, payload)
		else
			table.insert(stash, payload)
		end
	end

	table.sort(display, function(a, b)
		return (a.displaySlotIndex or 0) < (b.displaySlotIndex or 0)
	end)
	table.sort(stash, function(a, b)
		return (a.stashSlotIndex or 0) < (b.stashSlotIndex or 0)
	end)

	return {
		display = display,
		stash = stash,
	}
end

function InventoryService:restorePermanentInventoryItems(player: Player): number
	local inventory = self:_ensureInventory(player)
	local restored = 0
	for _, entry in inventory.items do
		if entry.disposed or entry.permanentOrigin ~= true or self:_itemLocation(entry) ~= LOCATION_INVENTORY then
			continue
		end

		local homeLocation = entry.permanentHomeLocation
		local homeSlot = entry.permanentHomeSlotIndex
		if homeLocation == LOCATION_DISPLAY and type(homeSlot) == "number" then
			entry.location = LOCATION_DISPLAY
			entry.heldBack = false
			entry.displaySlotIndex = homeSlot
			entry.stashSlotIndex = nil
			restored += 1
		elseif homeLocation == LOCATION_STASH and type(homeSlot) == "number" then
			entry.location = LOCATION_STASH
			entry.heldBack = false
			entry.displaySlotIndex = nil
			entry.stashSlotIndex = homeSlot
			restored += 1
		end
	end

	if restored > 0 then
		self:_pushState(player)
		self:_markPersistentDirty(player)
	end
	return restored
end

function InventoryService:getLiquidatableInventoryItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_INVENTORY and entry.permanentOrigin ~= true then
			table.insert(items, entry)
		end
	end
	return items
end

function InventoryService:getActiveItems(player: Player): { any }
	-- All non-disposed items (inventory + display). Do not use for liquidation.
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local active = {}
	for _, entry in inventory.items do
		if not entry.disposed then
			table.insert(active, entry)
		end
	end
	return active
end

function InventoryService:getInventoryItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_INVENTORY then
			table.insert(items, entry)
		end
	end
	return items
end

function InventoryService:getDisplayItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_DISPLAY then
			table.insert(items, entry)
		end
	end

	table.sort(items, function(a, b)
		return (a.displaySlotIndex or 0) < (b.displaySlotIndex or 0)
	end)

	return items
end

function InventoryService:getStashItems(player: Player): { any }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local items = {}
	for _, entry in inventory.items do
		if not entry.disposed and self:_itemLocation(entry) == LOCATION_STASH then
			table.insert(items, entry)
		end
	end

	table.sort(items, function(a, b)
		return (a.stashSlotIndex or 0) < (b.stashSlotIndex or 0)
	end)

	return items
end

function InventoryService:getCount(player: Player): number
	return #self:getInventoryItems(player)
end

function InventoryService:getDisplayCount(player: Player): number
	return #self:getDisplayItems(player)
end

function InventoryService:getStashCount(player: Player): number
	return #self:getStashItems(player)
end

function InventoryService:getMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.maxSlots
end

function InventoryService:getDisplayMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.displayMaxSlots
end

function InventoryService:getStashMaxSlots(player: Player): number
	local inventory = self:_ensureInventory(player)
	return inventory.stashMaxSlots
end

function InventoryService:canAdd(player: Player): boolean
	return self:getCount(player) < self:getMaxSlots(player)
end

function InventoryService:canAddToDisplay(player: Player, ignoreInstanceId: string?): boolean
	return self:findFirstEmptyDisplaySlot(player, ignoreInstanceId) ~= nil
end

function InventoryService:canAddToStash(player: Player, ignoreInstanceId: string?): boolean
	return self:findFirstEmptyStashSlot(player, ignoreInstanceId) ~= nil
end

local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)

local function assertDebugDangerous(player: Player): boolean
	return DebugAccess.canUseDangerousActions(player)
end

local function assertDebugReset(player: Player): boolean
	return DebugAccess.canResetSave(player)
end

function InventoryService:debugAddInventoryItem(player: Player, itemDef: any): (string?, string?)
	if not assertDebugDangerous(player) then
		return nil, "Forbidden"
	end
	if not itemDef then
		return nil, "No item configured"
	end
	if not self:canAddToDisplay(player) then
		return nil, "Shelf full"
	end

	local baseValue = itemDef.baseValue or 10
	local instanceId = self:addPurchasedItemToShelf(player, ObjectModel.fromDefinition(itemDef, {
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
	}))
	if not instanceId then
		return nil, "Shelf full"
	end

	return instanceId, itemDef.displayName
end

function InventoryService:debugAddDisplayItem(player: Player, itemDef: any): (string?, string?)
	if not assertDebugDangerous(player) then
		return nil, "Forbidden"
	end
	if not itemDef then
		return nil, "No item configured"
	end
	if not self:canAddToDisplay(player) then
		return nil, "Shelf full"
	end

	local displaySlotIndex = self:findFirstEmptyDisplaySlot(player)
	if not displaySlotIndex then
		return nil, "Shelf full"
	end

	local inventory = self:_ensureInventory(player)
	local baseValue = itemDef.baseValue or 10
	local entry = ObjectModel.fromDefinition(itemDef, {
		instanceId = self:_nextInstanceId(),
		purchasePrice = baseValue,
		trueValue = baseValue,
		rarityId = "Common",
		estimatedLow = math.floor(baseValue * 0.8),
		estimatedHigh = math.ceil(baseValue * 1.2),
		sellerName = "Debug",
		location = LOCATION_DISPLAY,
		heldBack = false,
		displaySlotIndex = displaySlotIndex,
		stashSlotIndex = nil,
	})
	self:_applyPermanentHome(entry, LOCATION_DISPLAY, displaySlotIndex)
	table.insert(inventory.items, entry)
	self:_pushState(player)
	self:_markPersistentDirty(player)
	return entry.instanceId, itemDef.displayName
end

function InventoryService:debugClearWorkingInventory(player: Player): (number, string?)
	if not assertDebugDangerous(player) then
		return 0, "Forbidden"
	end

	local cleared = 0
	for _, entry in self:getInventoryItems(player) do
		if self:markDisposed(player, entry.instanceId) then
			cleared += 1
		end
	end

	return cleared, nil
end

function InventoryService:debugClearDisplay(player: Player): (number, string?)
	if not assertDebugDangerous(player) then
		return 0, "Forbidden"
	end

	local cleared = 0
	for _, entry in self:getDisplayItems(player) do
		if self:markDisposed(player, entry.instanceId) then
			cleared += 1
		end
	end

	return cleared, nil
end

function InventoryService:debugClearPersistentShopState(player: Player): (number, string?)
	if not assertDebugReset(player) then
		return 0, "Forbidden"
	end

	local cleared = 0
	local inventory = self:_ensureInventory(player)
	for _, entry in inventory.items do
		local location = self:_itemLocation(entry)
		if not entry.disposed and (entry.permanentOrigin == true or location == LOCATION_DISPLAY or location == LOCATION_STASH) then
			entry.disposed = true
			cleared += 1
		end
	end

	self:_pushState(player)
	self:_markPersistentDirty(player)
	return cleared, nil
end

function InventoryService:getSnapshot(player: Player)
	local inventory = self:_ensureInventory(player)
	local items = {}
	local displayBySlot: { [number]: any } = {}
	local stashBySlot: { [number]: any } = {}

	for _, entry in inventory.items do
		if entry.disposed then
			continue
		end

		local location = self:_itemLocation(entry)
		if location == LOCATION_INVENTORY then
			table.insert(items, self:_serializeItem(entry))
		elseif location == LOCATION_DISPLAY and entry.displaySlotIndex then
			displayBySlot[entry.displaySlotIndex] = entry
		elseif location == LOCATION_STASH and entry.stashSlotIndex then
			stashBySlot[entry.stashSlotIndex] = entry
		end
	end

	local displayItems = {}
	local displayUsedSlots = 0
	for slotIndex = 1, inventory.displayMaxSlots do
		local entry = displayBySlot[slotIndex]
		if entry then
			table.insert(displayItems, self:_serializeItem(entry))
			displayUsedSlots += 1
		end
	end

	local stashItems = {}
	local stashUsedSlots = 0
	for slotIndex = 1, inventory.stashMaxSlots do
		local entry = stashBySlot[slotIndex]
		if entry then
			table.insert(stashItems, self:_serializeItem(entry))
			stashUsedSlots += 1
		end
	end

	return {
		maxSlots = inventory.maxSlots,
		usedSlots = #items,
		items = items,
		displayMaxSlots = inventory.displayMaxSlots,
		displayUsedSlots = displayUsedSlots,
		displayItems = displayItems,
		shelfMaxSlots = inventory.displayMaxSlots,
		shelfUsedSlots = displayUsedSlots,
		shelfItems = displayItems,
		stashMaxSlots = inventory.stashMaxSlots,
		stashUsedSlots = stashUsedSlots,
		stashItems = stashItems,
		displayAppealSummary = DisplayInfluence.summarizeDisplayAppeal(self:getDisplayItems(player)),
		shelfAppealSummary = DisplayInfluence.summarizeDisplayAppeal(self:getDisplayItems(player)),
		persistenceDebug = DataService:getDebugSnapshot(player),
	}
end

return InventoryService
