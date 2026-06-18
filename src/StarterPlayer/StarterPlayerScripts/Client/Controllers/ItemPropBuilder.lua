local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemVisuals = require(Shared.Config.ItemVisuals)

local ItemPropBuilder = {}

local FALLBACK_COLOR = Color3.fromRGB(130, 125, 115)

local function getItemsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local items = assets and assets:FindFirstChild("Items")
	if items and items:IsA("Folder") then
		return items
	end
	return nil
end

local function getBasePropsFolder(): Folder?
	local items = getItemsFolder()
	local baseProps = items and items:FindFirstChild("BaseProps")
	if baseProps and baseProps:IsA("Folder") then
		return baseProps
	end
	return nil
end

local function getUniqueItemsFolder(): Folder?
	local items = getItemsFolder()
	local uniqueItems = items and items:FindFirstChild("UniqueItems")
	if uniqueItems and uniqueItems:IsA("Folder") then
		return uniqueItems
	end
	return nil
end

local function findUniqueTemplate(modelName: string): Model?
	local uniqueItems = getUniqueItemsFolder()
	if not uniqueItems then
		return nil
	end

	local template = uniqueItems:FindFirstChild(modelName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function findBasePropTemplate(propName: string): Model?
	local baseProps = getBasePropsFolder()
	if not baseProps then
		return nil
	end

	local template = baseProps:FindFirstChild(propName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function findFirstBasePart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	local labelPart = model:FindFirstChild("LabelPart")
	if labelPart and labelPart:IsA("BasePart") then
		return labelPart
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function stripRuntimeScripts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end

	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
end

local function prepareForDisplay(model: Model)
	stripRuntimeScripts(model)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	local root = findFirstBasePart(model)
	if root then
		model.PrimaryPart = root
	end
end

local function findLabelPart(model: Model): BasePart?
	local labelPart = model:FindFirstChild("LabelPart")
	if labelPart and labelPart:IsA("BasePart") then
		return labelPart
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function createBillboard(attachPart: BasePart, title: string, subtitle: string): BillboardGui
	local existing = attachPart:FindFirstChild("ItemLabel")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, subtitle ~= "" and 48 or 32)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.Parent = attachPart

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 14
	label.TextWrapped = true
	label.Text = title
	label.Size = UDim2.new(1, 0, if subtitle ~= "" then 0.55 else 1, 0)
	label.Position = UDim2.fromScale(0, 0)
	label.Parent = billboard

	if subtitle ~= "" then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 0.45
		sub.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
		sub.BorderSizePixel = 0
		sub.Font = Enum.Font.Gotham
		sub.TextColor3 = Color3.fromRGB(210, 210, 215)
		sub.TextSize = 12
		sub.TextWrapped = true
		sub.Text = subtitle
		sub.Size = UDim2.new(1, 0, 0.45, 0)
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Parent = billboard
	end

	return billboard
end

local function buildFallbackBlock(spotCFrame: CFrame, title: string, subtitle: string): Model
	local model = Instance.new("Model")
	model.Name = "HubItem"

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Size = Vector3.new(1, 1, 1)
	part.Color = FALLBACK_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = spotCFrame
	part.Parent = model

	model.PrimaryPart = part
	createBillboard(part, title, subtitle)

	return model
end

local function cloneItemTemplate(resolved: ItemVisuals.ResolvedItemVisual): Model?
	if resolved.uniqueModel then
		local uniqueTemplate = findUniqueTemplate(resolved.uniqueModel)
		if uniqueTemplate then
			return uniqueTemplate:Clone()
		end
	end

	local categoryTemplate = findBasePropTemplate(resolved.propName)
	if categoryTemplate then
		return categoryTemplate:Clone()
	end

	local defaultTemplate = findBasePropTemplate(ItemVisuals.defaultProp)
	if defaultTemplate then
		return defaultTemplate:Clone()
	end

	return nil
end

function ItemPropBuilder.updateLabel(model: Model?, title: string, subtitle: string)
	if not model then
		return
	end

	local labelPart = findLabelPart(model)
	if labelPart then
		createBillboard(labelPart, title, subtitle)
	end
end

function ItemPropBuilder.destroy(model: Model?)
	if model then
		model:Destroy()
	end
end

function ItemPropBuilder.build(resolved: ItemVisuals.ResolvedItemVisual, spotCFrame: CFrame): Model
	local cloned = cloneItemTemplate(resolved)
	if not cloned then
		return buildFallbackBlock(spotCFrame, resolved.displayName, resolved.subtitle)
	end

	cloned.Name = "HubItem"
	prepareForDisplay(cloned)
	cloned:PivotTo(spotCFrame)

	local labelPart = findLabelPart(cloned)
	if labelPart then
		createBillboard(labelPart, resolved.displayName, resolved.subtitle)
	end

	return cloned
end

return ItemPropBuilder
