local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Customers = require(Shared.Config.Customers)
local Items = require(Shared.Config.Items)

local CustomerService = {}

function CustomerService:Init() end

function CustomerService:Start() end

function CustomerService:rollCustomer(rng: Random?)
	return Customers.getRandom(rng)
end

function CustomerService:rollItem(rng: Random?)
	return Items.getRandom(rng)
end

function CustomerService:getCustomer(customerId: string)
	return Customers.get(customerId)
end

function CustomerService:getItem(itemId: string)
	return Items.get(itemId)
end

return CustomerService
