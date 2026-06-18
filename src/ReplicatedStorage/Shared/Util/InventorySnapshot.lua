local InventorySnapshot = {}

function InventorySnapshot.indexDisplayItemsBySlot(displayItems: any): { [number]: any }
	local bySlot: { [number]: any } = {}
	if type(displayItems) ~= "table" then
		return bySlot
	end

	for key, entry in displayItems do
		if type(entry) ~= "table" then
			continue
		end

		local slotIndex = entry.displaySlotIndex
		if type(slotIndex) ~= "number" then
			if type(key) == "number" then
				slotIndex = key
			else
				continue
			end
		end

		bySlot[slotIndex] = entry
	end

	return bySlot
end

return InventorySnapshot
