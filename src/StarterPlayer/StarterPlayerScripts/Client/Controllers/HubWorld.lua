local HubWorld = {}

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

	for _, descendant in shelf:GetDescendants() do
		local hay = normalize(descendant.Name)
		if string.find(hay, "displayslot", 1, true) and string.find(hay, tostring(slotIndex), 1, true) then
			part = HubWorld.resolveBasePart(descendant)
			if part then
				return part
			end
		end
	end

	for _, descendant in shelf:GetDescendants() do
		local hay = normalize(descendant.Name)
		if string.find(hay, "slot", 1, true) and string.find(hay, tostring(slotIndex), 1, true) then
			if not string.find(hay, "shelfback", 1, true) and hay ~= "back" then
				part = HubWorld.resolveBasePart(descendant)
				if part then
					return part
				end
			end
		end
	end

	return nil
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
