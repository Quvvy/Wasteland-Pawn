local Rarities = {
	Common = {
		id = "Common",
		displayName = "Common",
		valueMultiplier = 1,
		weight = 45,
	},
	Uncommon = {
		id = "Uncommon",
		displayName = "Uncommon",
		valueMultiplier = 1.35,
		weight = 28,
	},
	Rare = {
		id = "Rare",
		displayName = "Rare",
		valueMultiplier = 1.9,
		weight = 15,
	},
	Epic = {
		id = "Epic",
		displayName = "Epic",
		valueMultiplier = 2.75,
		weight = 8,
	},
	Legendary = {
		id = "Legendary",
		displayName = "Legendary",
		valueMultiplier = 4.5,
		weight = 3,
	},
	Unknown = {
		id = "Unknown",
		displayName = "???",
		valueMultiplier = 1,
		weight = 1,
		revealOnInspectOnly = true,
	},
}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Unknown" }

function Rarities.getRollWeights(category: string?): { [string]: number }
	local weights = {}
	for _, rarityId in Rarities.Order do
		local rarity = Rarities[rarityId]
		if rarity and rarity.weight and rarityId ~= "Unknown" then
			weights[rarityId] = rarity.weight
		end
	end

	if category == "Cursed Junk" then
		weights.Epic = (weights.Epic or 0) + 4
		weights.Legendary = (weights.Legendary or 0) + 2
		weights.Common = math.max(20, (weights.Common or 0) - 6)
	elseif category == "Collectibles" then
		weights.Rare = (weights.Rare or 0) + 4
		weights.Epic = (weights.Epic or 0) + 2
	elseif category == "Alien Tech" then
		weights.Uncommon = (weights.Uncommon or 0) + 5
		weights.Rare = (weights.Rare or 0) + 3
	end

	return weights
end

return Rarities
