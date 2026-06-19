local ObjectModel = {}

ObjectModel.Locations = {
	Inventory = "inventory",
	Display = "display",
	Stash = "stash",
}

local function copyList(values)
	local copy = {}
	if type(values) ~= "table" then
		return copy
	end
	for _, value in values do
		table.insert(copy, value)
	end
	return copy
end

local function copyFields(source, target)
	if type(source) ~= "table" then
		return target
	end
	for key, value in source do
		target[key] = value
	end
	return target
end

function ObjectModel.normalizeLocation(location: any): string
	if location == ObjectModel.Locations.Display then
		return ObjectModel.Locations.Display
	elseif location == ObjectModel.Locations.Stash then
		return ObjectModel.Locations.Stash
	end
	return ObjectModel.Locations.Inventory
end

function ObjectModel.getObjectId(entry: any): string?
	if not entry then
		return nil
	end
	return entry.objectId or entry.itemId
end

function ObjectModel.normalizeOwnedObject(entry)
	entry.objectId = entry.objectId or entry.itemId
	entry.itemId = entry.itemId or entry.objectId
	entry.location = ObjectModel.normalizeLocation(entry.location)
	entry.heldBack = entry.heldBack == true
	entry.traits = copyList(entry.traits)
	return entry
end

function ObjectModel.fromDefinition(definition, fields)
	local entry = copyFields(fields, {})
	entry.objectId = entry.objectId or entry.itemId or (definition and definition.id)
	entry.itemId = entry.itemId or entry.objectId
	entry.displayName = entry.displayName or (definition and definition.displayName)
	entry.category = entry.category or (definition and definition.category)
	entry.traits = entry.traits or (definition and definition.traits) or {}
	entry.flavorText = entry.flavorText or (definition and definition.flavorText)
	return ObjectModel.normalizeOwnedObject(entry)
end

function ObjectModel.serializeForInventorySnapshot(entry)
	local objectId = ObjectModel.getObjectId(entry)
	return {
		instanceId = entry.instanceId,
		objectId = objectId,
		itemId = entry.itemId or objectId,
		displayName = entry.displayName,
		dealArchetypeId = entry.dealArchetypeId,
		dealArchetypeName = entry.dealArchetypeName,
		category = entry.category,
		traits = copyList(entry.traits),
		flavorText = entry.flavorText,
		purchasePrice = entry.purchasePrice,
		estimatedLow = entry.estimatedLow,
		estimatedHigh = entry.estimatedHigh,
		sellerName = entry.sellerName,
		sellerTell = entry.sellerTell,
		heldBack = entry.heldBack == true,
		location = ObjectModel.normalizeLocation(entry.location),
		displaySlotIndex = entry.displaySlotIndex,
		stashSlotIndex = entry.stashSlotIndex,
	}
end

return ObjectModel
