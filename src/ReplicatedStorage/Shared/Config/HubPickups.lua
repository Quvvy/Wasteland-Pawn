local HubPickups = {
	Enabled = false,
	SpawnDefs = {
		{
			spawnName = "PickupSpawn1",
			propId = "rusted_can",
			objectId = "scrap_empty_can_stack",
			assetName = "RustedCan",
			displayName = "Rusted Can",
			placeholderSize = Vector3.new(1.2, 1.4, 1.2),
			placeholderColor = Color3.fromRGB(120, 90, 70),
		},
		{
			spawnName = "PickupSpawn2",
			propId = "weird_bottle",
			objectId = "alien_bio_gel",
			assetName = "WeirdBottle",
			displayName = "Weird Bottle",
			placeholderSize = Vector3.new(0.8, 1.6, 0.8),
			placeholderColor = Color3.fromRGB(90, 160, 140),
		},
		{
			spawnName = "PickupSpawn3",
			propId = "broken_radio",
			objectId = "tech_handheld_radio",
			assetName = "BrokenRadio",
			displayName = "Broken Radio",
			placeholderSize = Vector3.new(1.6, 0.9, 1.1),
			placeholderColor = Color3.fromRGB(140, 110, 90),
		},
	},
	DisplaySlots = { "DisplaySlot1", "DisplaySlot2", "DisplaySlot3" },
	PlaceYOffset = 0.35,
}

function HubPickups.getSpawnDef(spawnName: string)
	for _, def in HubPickups.SpawnDefs do
		if def.spawnName == spawnName then
			return def
		end
	end
	return nil
end

function HubPickups.getSpawnDefByPropId(propId: string)
	for _, def in HubPickups.SpawnDefs do
		if def.propId == propId then
			return def
		end
	end
	return nil
end

return HubPickups
