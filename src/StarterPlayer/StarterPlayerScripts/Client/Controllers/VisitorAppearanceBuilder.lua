local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisitorAppearances = require(Shared.Config.VisitorAppearances)

local VisitorAppearanceBuilder = {}

local BODY_PART_NAMES = {
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	HumanoidRootPart = true,
	UpperTorso = true,
	LowerTorso = true,
}

local LIMB_PART_NAMES = {
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local function getVisitorsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local visitors = assets and assets:FindFirstChild("Visitors")
	if visitors and visitors:IsA("Folder") then
		return visitors
	end
	return nil
end

local function getBaseRigsFolder(): Folder?
	local visitors = getVisitorsFolder()
	local baseRigs = visitors and visitors:FindFirstChild("BaseRigs")
	if baseRigs and baseRigs:IsA("Folder") then
		return baseRigs
	end
	return nil
end

local function getUniqueVisitorsFolder(): Folder?
	local visitors = getVisitorsFolder()
	local uniqueVisitors = visitors and visitors:FindFirstChild("UniqueVisitors")
	if uniqueVisitors and uniqueVisitors:IsA("Folder") then
		return uniqueVisitors
	end
	return nil
end

local function findBaseRigTemplate(baseRigName: string): Model?
	local baseRigs = getBaseRigsFolder()
	if not baseRigs then
		return nil
	end

	local template = baseRigs:FindFirstChild(baseRigName)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

local function findUniqueTemplate(modelName: string): Model?
	local uniqueVisitors = getUniqueVisitorsFolder()
	if not uniqueVisitors then
		return nil
	end

	local template = uniqueVisitors:FindFirstChild(modelName)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

local function findFirstBasePart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function stripRuntimeScripts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
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
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function createBillboard(attachPart: BasePart, title: string, subtitle: string?): BillboardGui
	local existing = attachPart:FindFirstChild("VisitorLabel")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VisitorLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(200, subtitle and 56 or 36)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = attachPart

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 16
	label.TextWrapped = true
	label.Text = title
	label.Size = UDim2.new(1, 0, if subtitle then 0.55 else 1, 0)
	label.Position = UDim2.fromScale(0, 0)
	label.Parent = billboard

	if subtitle and subtitle ~= "" then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 0.45
		sub.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
		sub.BorderSizePixel = 0
		sub.Font = Enum.Font.Gotham
		sub.TextColor3 = Color3.fromRGB(210, 210, 215)
		sub.TextSize = 13
		sub.TextWrapped = true
		sub.Text = subtitle
		sub.Size = UDim2.new(1, 0, 0.45, 0)
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Parent = billboard
	end

	return billboard
end

local function buildFallbackBlock(
	spotCFrame: CFrame,
	title: string,
	subtitle: string?,
	bodyColor: Color3
): Model
	local model = Instance.new("Model")
	model.Name = "HubVisitor"

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Size = Vector3.new(1.4, 3, 1.4)
	part.Color = bodyColor
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = spotCFrame * CFrame.new(0, part.Size.Y * 0.5, 0)
	part.Parent = model

	model.PrimaryPart = part
	createBillboard(part, title, subtitle)

	return model
end

local function cloneVisitorTemplate(resolved: VisitorAppearances.ResolvedAppearance): Model?
	if resolved.uniqueModel then
		local uniqueTemplate = findUniqueTemplate(resolved.uniqueModel)
		if uniqueTemplate then
			return uniqueTemplate:Clone()
		end
	end

	local archetypeTemplate = findBaseRigTemplate(resolved.baseRig)
	if archetypeTemplate then
		return archetypeTemplate:Clone()
	end

	local defaultTemplate = findBaseRigTemplate("Default")
	if defaultTemplate then
		return defaultTemplate:Clone()
	end

	return nil
end

local function applyArchetypeColors(model: Model, bodyColor: Color3, accentColor: Color3, limbColor: Color3)
	local tintedAny = false

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		local partName = descendant.Name
		if partName == "Head" then
			descendant.Color = accentColor
			tintedAny = true
		elseif LIMB_PART_NAMES[partName] then
			descendant.Color = limbColor
			tintedAny = true
		elseif BODY_PART_NAMES[partName] then
			descendant.Color = bodyColor
			tintedAny = true
		end
	end

	if not tintedAny then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = bodyColor
			end
		end
	end
end

local function placeModelOnSpot(model: Model, spotCFrame: CFrame)
	prepareForDisplay(model)
	model:PivotTo(spotCFrame)

	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local bottomY = bboxCFrame.Position.Y - (bboxSize.Y * 0.5)
	local lift = spotCFrame.Position.Y - bottomY
	if math.abs(lift) > 0.01 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
end

function VisitorAppearanceBuilder.updateLabel(model: Model?, title: string, subtitle: string?)
	if not model then
		return
	end

	local labelPart = findLabelPart(model)
	if labelPart then
		createBillboard(labelPart, title, subtitle)
	end
end

function VisitorAppearanceBuilder.destroy(model: Model?)
	if model then
		model:Destroy()
	end
end

function VisitorAppearanceBuilder.build(resolved: VisitorAppearances.ResolvedAppearance, spotCFrame: CFrame): Model
	local cloned = cloneVisitorTemplate(resolved)
	if not cloned then
		return buildFallbackBlock(spotCFrame, resolved.displayName, resolved.subtitle, resolved.bodyColor)
	end

	cloned.Name = "HubVisitor"
	applyArchetypeColors(cloned, resolved.bodyColor, resolved.accentColor, resolved.limbColor)
	placeModelOnSpot(cloned, spotCFrame)

	local labelPart = findLabelPart(cloned)
	if labelPart then
		createBillboard(labelPart, resolved.displayName, resolved.subtitle)
	end

	return cloned
end

return VisitorAppearanceBuilder
