local Controllers = script:WaitForChild("Controllers")

local controllerModules = {
	Controllers:WaitForChild("UIController"),
	Controllers:WaitForChild("DealController"),
	Controllers:WaitForChild("CameraController"),
}

local loadedControllers = {}

for _, controllerModule in controllerModules do
	local ok, controller = pcall(require, controllerModule)

	if ok then
		table.insert(loadedControllers, controller)
	else
		warn(`Failed to require {controllerModule.Name}: {controller}`)
	end
end

local function runLifecycle(methodName: string)
	for _, controller in loadedControllers do
		local method = controller[methodName]

		if type(method) == "function" then
			local ok, err = pcall(method, controller)

			if not ok then
				warn(`Controller {methodName} failed: {err}`)
			end
		end
	end
end

runLifecycle("Init")
runLifecycle("Start")
