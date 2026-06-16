local archetypeList = {
	{
		id = "safe_flip",
		displayName = "Safe Flip",
		description = "A readable, low-risk buy that should usually be worth considering.",
		sellerWeights = {
			desperate_survivor = 3,
			nervous_rookie = 3,
			junk_dealer = 1,
			shady_scammer = 1,
		},
		weakClues = {
			"The asking price sits close to your estimate.",
			"The item looks worn but usable.",
			"The seller seems ready to move on.",
			"Nothing flashy, but the parts look salvageable.",
		},
		inspectClues = {
			"Wear is surface-level; core parts look intact.",
			"Maker marks match the materials underneath.",
			"Serial numbers line up with the casing age.",
			"Practical scrap value seems real, not padded.",
		},
		itemCategoryWeights = {
			Scrap = 3,
			["Old World Tech"] = 2,
		},
		itemTraitWeights = {
			Useful = 2,
			Damaged = 1.5,
		},
		rarityWeightMultipliers = {
			Common = 1.15,
			Uncommon = 1.1,
			Rare = 0.9,
			Epic = 0.75,
			Legendary = 0.6,
		},
		trueValueMultiplier = 1.08,
		estimateCenterMultiplier = 1,
		estimateSpreadMultiplier = 0.9,
		askMultiplier = 0.94,
	},
	{
		id = "scam_trap",
		displayName = "Scam Trap",
		description = "A suspicious setup where the seller makes junk look better than it is.",
		sellerWeights = {
			shady_scammer = 4,
			junk_dealer = 2,
			silent_stranger = 1,
			desperate_survivor = 1,
			nervous_rookie = 1,
		},
		weakClues = {
			"The item looks cleaner than the story suggests.",
			"The asking price sits above your estimate.",
			"Seller avoids saying where they found it.",
			"Estimate range is wide.",
		},
		inspectClues = {
			"Serial number looks recently scratched.",
			"Paint is covering older damage.",
			"The maker mark does not match the material.",
			"Shine looks applied, not original.",
		},
		itemCategoryWeights = {
			Scrap = 2,
			Collectibles = 2,
			["Cursed Junk"] = 1,
		},
		itemTraitWeights = {
			Fake = 3,
			Damaged = 1.5,
			Shiny = 1.2,
		},
		rarityWeightMultipliers = {
			Common = 1.15,
			Uncommon = 1,
			Rare = 0.9,
			Epic = 0.8,
			Legendary = 0.7,
		},
		trueValueMultiplier = 0.88,
		estimateCenterMultiplier = 1.18,
		estimateSpreadMultiplier = 1.1,
		askMultiplier = 1.08,
	},
	{
		id = "desperate_seller",
		displayName = "Desperate Seller",
		description = "A seller under pressure, often with practical but imperfect stock.",
		sellerWeights = {
			desperate_survivor = 4,
			nervous_rookie = 3,
			mutant_drifter = 2,
			soldier = 1,
		},
		weakClues = {
			"Seller keeps rushing the conversation.",
			"Seller keeps checking your reaction.",
			"The seller's story is thin.",
			"The item has obvious wear.",
		},
		inspectClues = {
			"Damage is real, but the useful parts remain.",
			"Repairs look hasty, not fraudulent.",
			"Wear matches a hard life, not a repaint job.",
			"Parts still move; nothing critical is missing.",
		},
		itemCategoryWeights = {
			Scrap = 2,
			["Old World Tech"] = 1,
			["Alien Tech"] = 1,
			["Cursed Junk"] = 1,
			Collectibles = 1,
		},
		itemTraitWeights = {
			Damaged = 2,
			Useful = 2,
		},
		rarityWeightMultipliers = {
			Common = 1,
			Uncommon = 1,
			Rare = 1,
			Epic = 1,
			Legendary = 1,
		},
		trueValueMultiplier = 1,
		estimateCenterMultiplier = 1,
		estimateSpreadMultiplier = 1,
		askMultiplier = 0.9,
	},
	{
		id = "perfect_buyer_setup",
		displayName = "Perfect Buyer Setup",
		description = "A hold-worthy item with traits likely to create buyer matching moments.",
		sellerWeights = {
			rich_collector = 2,
			alien_tourist = 2,
			robot_trader = 1,
			soldier = 1,
			shady_scammer = 1,
		},
		weakClues = {
			"Unusual markings catch the light.",
			"The seller undersells how odd this looks.",
			"Traits stand out more than the price suggests.",
			"Collectors might notice details like these.",
		},
		inspectClues = {
			"Collectors sometimes chase markings like this.",
			"Hidden detail under the grime looks deliberate.",
			"Material quality exceeds the outer wear.",
			"Small quirks suggest niche buyer interest.",
		},
		itemCategoryWeights = {
			Collectibles = 3,
			["Cursed Junk"] = 2,
			["Alien Tech"] = 2,
			["Old World Tech"] = 1,
		},
		itemTraitWeights = {
			Collectible = 2,
			Cursed = 1.5,
			Alien = 1.5,
			Weird = 1.5,
			Shiny = 1.25,
			Useful = 1.25,
		},
		rarityWeightMultipliers = {
			Common = 0.95,
			Uncommon = 1.05,
			Rare = 1.15,
			Epic = 1.05,
			Legendary = 0.9,
		},
		trueValueMultiplier = 1.08,
		estimateCenterMultiplier = 1,
		estimateSpreadMultiplier = 1,
		askMultiplier = 1,
	},
	{
		id = "jackpot_junk",
		displayName = "Jackpot Junk",
		description = "Strange-looking inventory with a modest chance to be secretly valuable.",
		sellerWeights = {
			alien_tourist = 2,
			silent_stranger = 2,
			junk_dealer = 1,
			shady_scammer = 1,
			desperate_survivor = 1,
		},
		weakClues = {
			"Looks like junk until you stare longer.",
			"Estimate range is wide.",
			"Seller seems unsure what they have.",
			"Weird details do not match the low ask.",
		},
		inspectClues = {
			"There is alien alloy under the rust.",
			"The casing hums faintly when handled.",
			"Odd residue glows under scrap dust.",
			"Inner parts look far newer than the shell.",
		},
		itemCategoryWeights = {
			["Cursed Junk"] = 3,
			["Alien Tech"] = 3,
			Collectibles = 2,
		},
		itemTraitWeights = {
			Weird = 2,
			Cursed = 2,
			Alien = 2,
			Collectible = 1.5,
		},
		rarityWeightMultipliers = {
			Common = 0.75,
			Uncommon = 0.95,
			Rare = 1.3,
			Epic = 1.35,
			Legendary = 1.25,
		},
		trueValueMultiplier = 1.18,
		estimateCenterMultiplier = 0.92,
		estimateSpreadMultiplier = 1.08,
		askMultiplier = 0.98,
	},
	{
		id = "bad_deal",
		displayName = "Bad Deal",
		description = "A deal that should often tempt a pass unless haggling goes well.",
		sellerWeights = {
			rich_collector = 2,
			robot_trader = 2,
			junk_dealer = 2,
			silent_stranger = 1,
			desperate_survivor = 1,
			nervous_rookie = 1,
		},
		weakClues = {
			"The asking price sits above your estimate.",
			"Estimate range is wide.",
			"The seller's story is thin.",
			"The item has obvious wear.",
		},
		inspectClues = {
			"Critical parts look stripped or missing.",
			"Repairs hide more problems underneath.",
			"Value looks mostly in scrap weight.",
			"Wear goes deeper than the seller admitted.",
		},
		itemCategoryWeights = {
			Scrap = 3,
			Collectibles = 2,
		},
		itemTraitWeights = {
			Fake = 2.5,
			Damaged = 2,
		},
		rarityWeightMultipliers = {
			Common = 1.25,
			Uncommon = 1,
			Rare = 0.75,
			Epic = 0.6,
			Legendary = 0.45,
		},
		trueValueMultiplier = 0.82,
		estimateCenterMultiplier = 1.08,
		estimateSpreadMultiplier = 1.05,
		askMultiplier = 1.12,
	},
}

local byId = {}
for _, archetype in archetypeList do
	byId[archetype.id] = archetype
end

local DealArchetypes = {
	List = archetypeList,
	ById = byId,
}

function DealArchetypes.get(archetypeId: string)
	return DealArchetypes.ById[archetypeId]
end

function DealArchetypes.getAll()
	return DealArchetypes.List
end

return DealArchetypes
