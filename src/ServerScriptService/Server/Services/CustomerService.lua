local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Customers = require(Shared.Config.Customers)
local Items = require(Shared.Config.Items)
local TableUtil = require(Shared.Util.TableUtil)

local CustomerService = {}

local validCategories = {}
local validTraits = {}
for _, item in Items.List do
	validCategories[item.category] = true
	for _, trait in item.traits or {} do
		validTraits[trait] = true
	end
end

local function getValidWeights(source, validMap)
	if type(source) ~= "table" then
		return nil
	end

	local weights = {}
	local hasWeight = false
	for id, weight in source do
		if validMap[id] and type(weight) == "number" and weight > 0 then
			weights[id] = weight
			hasWeight = true
		end
	end

	return if hasWeight then weights else nil
end

local function getValidCustomerWeights(source)
	if type(source) ~= "table" then
		return nil
	end

	local weights = {}
	local hasWeight = false
	for customerId, weight in source do
		if Customers.get(customerId) and type(weight) == "number" and weight > 0 then
			weights[customerId] = weight
			hasWeight = true
		end
	end

	return if hasWeight then weights else nil
end

local function getTraitWeight(item, traitWeights)
	local weight = 0
	for _, trait in item.traits or {} do
		weight += traitWeights[trait] or 0
	end
	return weight
end

function CustomerService:Init() end

function CustomerService:Start() end

function CustomerService:rollCustomer(rng: Random?, sellerWeights)
	local validWeights = getValidCustomerWeights(sellerWeights)
	if validWeights then
		local customerId = TableUtil.pickWeighted(validWeights, rng)
		local customer = if customerId then Customers.get(customerId) else nil
		if customer then
			return customer
		end
	end

	return Customers.getRandom(rng)
end

function CustomerService:rollItem(rng: Random?, itemBias)
	local categoryWeights = getValidWeights(itemBias and itemBias.itemCategoryWeights, validCategories)
	local traitWeights = getValidWeights(itemBias and itemBias.itemTraitWeights, validTraits)

	if categoryWeights or traitWeights then
		local itemWeights = {}
		for _, item in Items.List do
			local weight = 1
			if categoryWeights then
				weight = categoryWeights[item.category] or 0
			end
			if weight > 0 and traitWeights then
				local traitWeight = getTraitWeight(item, traitWeights)
				weight *= if traitWeight > 0 then traitWeight else 0.4
			end
			if weight > 0 then
				itemWeights[item.id] = weight
			end
		end

		local itemId = TableUtil.pickWeighted(itemWeights, rng)
		local item = if itemId then Items.get(itemId) else nil
		if item then
			return item
		end
	end

	return Items.getRandom(rng)
end

function CustomerService:getCustomer(customerId: string)
	return Customers.get(customerId)
end

function CustomerService:getItem(itemId: string)
	return Items.get(itemId)
end

return CustomerService
