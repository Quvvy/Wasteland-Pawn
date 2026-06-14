local archetypeList = {
	{
		id = "safe_flip",
		displayName = "Safe Flip",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
	},
	{
		id = "scam_trap",
		displayName = "Scam Trap",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
	},
	{
		id = "desperate_seller",
		displayName = "Desperate Seller",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
	},
	{
		id = "perfect_buyer_setup",
		displayName = "Perfect Buyer Setup",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
	},
	{
		id = "jackpot_junk",
		displayName = "Jackpot Junk",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
	},
	{
		id = "bad_deal",
		displayName = "Bad Deal",
		itemCategoryWeights = {},
		sellerWeights = {},
		buyerSetupHint = nil,
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
