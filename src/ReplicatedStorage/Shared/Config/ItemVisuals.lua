-- Item prop mapping. Models live in Studio under ReplicatedStorage.Assets.Items.

local ItemVisuals = {}

ItemVisuals.defaultProp = "Default"

ItemVisuals.categoryProps = {
	Scrap = "Junk",
	["Old World Tech"] = "Tech",
	["Alien Tech"] = "Tech",
	["Cursed Junk"] = "Relic",
	Collectibles = "Toy",
}

-- Optional explicit unique item models in Assets.Items.UniqueItems.
ItemVisuals.uniqueItems = {
	["Alien Battery"] = "AlienBattery",
	["Cursed Traffic Cone"] = "CursedTrafficCone",
	["Suspicious Leek"] = "SuspiciousLeek",
	["Golden Traffic Cone"] = "GoldenTrafficCone",
}

export type ItemData = {
	objectId: string?,
	itemId: string?,
	itemName: string?,
	displayName: string?,
	category: string?,
	traits: { string }?,
	instanceId: string?,
	phase: string?,
	shelfSlot: number?,
	displaySlot: number?,
}

export type ResolvedItemVisual = {
	itemKey: string,
	propName: string,
	uniqueModel: string?,
	displayName: string,
	subtitle: string,
}

local function itemDisplayName(itemData: ItemData): string?
	local name = itemData.itemName or itemData.displayName
	if name and name ~= "" then
		return name
	end
	return nil
end

local function buildItemKey(itemData: ItemData): string
	local name = itemDisplayName(itemData)
	local objectId = itemData.objectId or itemData.itemId
	if itemData.shelfSlot and itemData.instanceId then
		return `{itemData.shelfSlot}:{itemData.instanceId}:{objectId or name or "?"}:{itemData.category or "?"}`
	end
	if itemData.displaySlot and itemData.instanceId then
		return `d:{itemData.displaySlot}:{itemData.instanceId}:{objectId or name or "?"}:{itemData.category or "?"}`
	end

	local phase = itemData.phase or "unknown"
	if phase == "Selling" and itemData.instanceId then
		return `sell:{itemData.instanceId}:{name or "?"}:{itemData.category or "?"}`
	end
	return `seller:{objectId or name or "?"}:{itemData.category or "?"}`
end

function ItemVisuals.resolvePropName(itemData: ItemData): (string, string?)
	local itemName = itemDisplayName(itemData)
	if itemName and ItemVisuals.uniqueItems[itemName] then
		return ItemVisuals.uniqueItems[itemName], ItemVisuals.uniqueItems[itemName]
	end

	local category = itemData.category
	if category and ItemVisuals.categoryProps[category] then
		return ItemVisuals.categoryProps[category], nil
	end

	return ItemVisuals.defaultProp, nil
end

function ItemVisuals.resolve(itemData: ItemData): ResolvedItemVisual?
	local displayName = itemDisplayName(itemData)
	if not displayName then
		return nil
	end

	local propName, uniqueModel = ItemVisuals.resolvePropName(itemData)

	return {
		itemKey = buildItemKey(itemData),
		propName = propName,
		uniqueModel = uniqueModel,
		displayName = displayName,
		subtitle = itemData.category or "",
	}
end

return ItemVisuals
