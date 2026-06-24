local Services = script:WaitForChild("Services")

local serviceModules = {
	Services:WaitForChild("DataService"),
	Services:WaitForChild("InventoryService"),
	Services:WaitForChild("CustomerService"),
	Services:WaitForChild("ShiftService"),
	Services:WaitForChild("DealService"),
	Services:WaitForChild("DebugService"),
	Services:WaitForChild("ShopService"),
	Services:WaitForChild("ScavengeService"),
}

local loadedServices = {}

for _, serviceModule in serviceModules do
	local ok, service = pcall(require, serviceModule)

	if ok then
		table.insert(loadedServices, service)
	else
		warn(`Failed to require {serviceModule.Name}: {service}`)
	end
end

local function runLifecycle(methodName: string)
	for _, service in loadedServices do
		local method = service[methodName]

		if type(method) == "function" then
			local ok, err = pcall(method, service)

			if not ok then
				warn(`Service {methodName} failed: {err}`)
			end
		end
	end
end

runLifecycle("Init")
runLifecycle("Start")
