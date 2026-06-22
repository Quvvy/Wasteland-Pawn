local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local ClientPresentation = require(Shared.Config.ClientPresentation)
local VisitorAppearances = require(Shared.Config.VisitorAppearances)

local HubWorld = require(script.Parent.HubWorld)
local VisitorAppearanceBuilder = require(script.Parent.VisitorAppearanceBuilder)

local CustomerPresentationController = {}

local WORLD_WAIT_SECONDS = 30
local LOCAL_FOLDER_NAME = "HubVisitorLocal"

local shop: Instance? = nil
local presentationAnchors: HubWorld.PresentationAnchors? = nil
local localFolder: Folder? = nil
local activeModel: Model? = nil
local lastAppearanceKey: string? = nil
local orchestratedMode = false
local activeTween: Tween? = nil
local tweenAlpha: NumberValue? = nil
local tweenConn: RBXScriptConnection? = nil
local activeMoveConn: RBXScriptConnection? = nil
local moveToken = 0

local TERMINAL_PHASES = {
	Result = true,
	WalkedAway = true,
	Stored = true,
	BuyerSkipped = true,
}

local function cancelTween()
	moveToken += 1
	if tweenConn then
		tweenConn:Disconnect()
		tweenConn = nil
	end
	if activeMoveConn then
		activeMoveConn:Disconnect()
		activeMoveConn = nil
	end
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	if tweenAlpha then
		tweenAlpha:Destroy()
		tweenAlpha = nil
	end
end

local function waitForWorld(): Instance?
	return Workspace:WaitForChild("World", WORLD_WAIT_SECONDS)
end

local function waitForShop(): Instance?
	local world = waitForWorld()
	if not world then
		return nil
	end
	return world:WaitForChild("Shop", WORLD_WAIT_SECONDS)
end

local function ensureLocalFolder(world: Instance): Folder
	if localFolder and localFolder.Parent then
		return localFolder
	end

	local existing = world:FindFirstChild(LOCAL_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		localFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LOCAL_FOLDER_NAME
	folder.Parent = world
	localFolder = folder
	return folder
end

function CustomerPresentationController:setOrchestratedMode(enabled: boolean)
	orchestratedMode = enabled
end

function CustomerPresentationController:setPresentationAnchors(anchors: HubWorld.PresentationAnchors?)
	presentationAnchors = anchors
end

function CustomerPresentationController:setBillboardVisible(visible: boolean)
	if not activeModel then
		return
	end
	local head = activeModel:FindFirstChild("Head", true)
	local attach = if head and head:IsA("BasePart") then head else activeModel.PrimaryPart
	if not attach then
		return
	end
	local label = attach:FindFirstChild("VisitorLabel")
	if label then
		label.Enabled = visible
	end
end

function CustomerPresentationController:clearVisitor()
	cancelTween()
	lastAppearanceKey = nil
	VisitorAppearanceBuilder.destroy(activeModel)
	activeModel = nil
end

local function pivotModelTo(model: Model, cf: CFrame)
	VisitorAppearanceBuilder.alignToSpot(model, cf)
end

local function tweenModelTo(model: Model, goalCF: CFrame, onComplete: (() -> ())?)
	cancelTween()
	local startCF = model:GetPivot()
	tweenAlpha = Instance.new("NumberValue")
	tweenAlpha.Value = 0
	activeTween = TweenService:Create(
		tweenAlpha,
		TweenInfo.new(ClientPresentation.CustomerMoveSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tweenConn = tweenAlpha.Changed:Connect(function()
		if model.Parent then
			pivotModelTo(model, startCF:Lerp(goalCF, tweenAlpha.Value))
		end
	end)
	activeTween.Completed:Connect(function()
		cancelTween()
		if model.Parent then
			pivotModelTo(model, goalCF)
		end
		if onComplete then
			onComplete()
		end
	end)
	activeTween:Play()
end

local function faceCounter(model: Model)
	if not presentationAnchors then
		return
	end
	local lookAt = presentationAnchors.counterLookAt.Position
	local pivot = model:GetPivot()
	local flatTarget = Vector3.new(lookAt.X, pivot.Position.Y, lookAt.Z)
	if (flatTarget - pivot.Position).Magnitude > 0.05 then
		local faced = CFrame.lookAt(pivot.Position, flatTarget)
		model:PivotTo(faced)
	else
		model:PivotTo(pivot)
	end
end

local function getHumanoidMoveParts(model: Model): (Humanoid?, BasePart?)
	local humanoid = VisitorAppearanceBuilder.getHumanoid(model)
	if not humanoid then
		return nil, nil
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return humanoid, root
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return humanoid, model.PrimaryPart
	end
	return humanoid, nil
end

local function computeWaypoints(startPos: Vector3, goalPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = ClientPresentation.CustomerAgentRadius or 2,
		AgentHeight = ClientPresentation.CustomerAgentHeight or 5,
		AgentCanJump = false,
	})

	local ok = pcall(function()
		path:ComputeAsync(startPos, goalPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	local waypoints = path:GetWaypoints()
	return if #waypoints > 1 then waypoints else nil
end

local function moveRigTo(model: Model, goalCF: CFrame, onComplete: (() -> ())?): boolean
	local humanoid, root = getHumanoidMoveParts(model)
	if not humanoid or not root then
		return false
	end

	cancelTween()
	local token = moveToken
	local completed = false
	humanoid.WalkSpeed = ClientPresentation.CustomerWalkSpeed or humanoid.WalkSpeed
	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	local walkSpeed = math.max(humanoid.WalkSpeed, 1)
	local distance = (goalCF.Position - root.Position).Magnitude
	local timeoutSeconds = math.max(ClientPresentation.CustomerMoveTimeoutSeconds or 8, distance / walkSpeed + 3)
	local waypoints = computeWaypoints(root.Position, goalCF.Position)
	local waypointIndex = 1

	local function finish(reached: boolean)
		if completed or token ~= moveToken then
			return
		end
		if reached and waypoints and waypointIndex < #waypoints then
			waypointIndex += 1
			humanoid:MoveTo(waypoints[waypointIndex].Position)
			return
		end

		completed = true
		if activeMoveConn then
			activeMoveConn:Disconnect()
			activeMoveConn = nil
		end

		if model.Parent and not reached then
			pivotModelTo(model, goalCF)
		end
		if onComplete then
			onComplete()
		end
	end

	activeMoveConn = humanoid.MoveToFinished:Connect(finish)
	if waypoints then
		humanoid:MoveTo(waypoints[waypointIndex].Position)
	else
		humanoid:MoveTo(goalCF.Position)
	end
	task.delay(timeoutSeconds, function()
		finish(false)
	end)
	return true
end

function CustomerPresentationController:showVisitorAt(profile: {
	visitorKind: string,
	buyerId: string?,
	customerId: string?,
	uniqueVisitorId: string?,
	displayName: string?,
	subtitle: string?,
}, worldCFrame: CFrame, snap: boolean?)
	local resolved = VisitorAppearances.resolve({
		visitorKind = profile.visitorKind,
		buyerId = profile.buyerId,
		customerId = profile.customerId,
		uniqueVisitorId = profile.uniqueVisitorId,
		displayName = profile.displayName,
		subtitle = profile.subtitle,
	})

	local world = waitForWorld()
	if not world then
		return
	end

	if lastAppearanceKey == resolved.appearanceKey and activeModel and activeModel.Parent then
		VisitorAppearanceBuilder.updateLabel(activeModel, resolved.displayName, resolved.subtitle)
		if snap then
			pivotModelTo(activeModel, worldCFrame)
			faceCounter(activeModel)
		end
		return
	end

	self:clearVisitor()
	lastAppearanceKey = resolved.appearanceKey

	local model = VisitorAppearanceBuilder.build(resolved, worldCFrame)
	model.Parent = ensureLocalFolder(world)
	activeModel = model

	if snap then
		faceCounter(model)
	end
end

function CustomerPresentationController:presentVisitor(profile: {
	visitorKind: string,
	buyerId: string?,
	customerId: string?,
	uniqueVisitorId: string?,
	displayName: string?,
	subtitle: string?,
})
	local counterCF = if presentationAnchors and presentationAnchors.customerCounter
		then HubWorld.getSpotStandingCFrame(presentationAnchors.customerCounter)
		else nil
	local entryCF = if presentationAnchors and presentationAnchors.customerEntry
		then HubWorld.getSpotStandingCFrame(presentationAnchors.customerEntry)
		else counterCF

	if not counterCF then
		local spot = HubWorld.findCustomerCounterSpot(shop)
		counterCF = if spot then HubWorld.getSpotStandingCFrame(spot) else nil
		entryCF = counterCF
	end

	if not counterCF then
		return
	end

	local spawnCF = entryCF or counterCF
	local sameSpot = entryCF ~= nil and counterCF ~= nil and entryCF.Position == counterCF.Position

	self:showVisitorAt(profile, spawnCF, sameSpot)

	if activeModel and not sameSpot then
		local model = activeModel
		local movedWithHumanoid = moveRigTo(model, counterCF, function()
			if activeModel then
				faceCounter(activeModel)
			end
		end)
		if not movedWithHumanoid then
			tweenModelTo(model, counterCF, function()
				if activeModel then
					faceCounter(activeModel)
				end
			end)
		end
	elseif activeModel then
		pivotModelTo(activeModel, counterCF)
		faceCounter(activeModel)
	end
end

function CustomerPresentationController:leaveVisitor(onComplete: (() -> ())?)
	if not activeModel then
		if onComplete then
			onComplete()
		end
		return
	end

	local exitCF = if presentationAnchors and presentationAnchors.customerExit
		then HubWorld.getSpotStandingCFrame(presentationAnchors.customerExit)
		else nil

	if not exitCF then
		self:clearVisitor()
		if onComplete then
			onComplete()
		end
		return
	end

	local model = activeModel
	if moveRigTo(model, exitCF, function()
		CustomerPresentationController:clearVisitor()
		if onComplete then
			onComplete()
		end
	end) then
		return
	end

	tweenModelTo(model, exitCF, function()
		CustomerPresentationController:clearVisitor()
		if onComplete then
			onComplete()
		end
	end)
end

function CustomerPresentationController:showSeller(snapshot: any)
	local subtitle = nil
	if snapshot.itemName and snapshot.itemName ~= "" then
		subtitle = snapshot.itemName
	end

	self:presentVisitor({
		visitorKind = "seller",
		customerId = snapshot.customerId,
		displayName = snapshot.customerName or "Seller",
		subtitle = subtitle,
	})
end

function CustomerPresentationController:showBuyer(snapshot: any)
	local subtitle = snapshot.buyerMatchLabel or snapshot.buyerInterest
	if subtitle == "" then
		subtitle = nil
	end

	self:presentVisitor({
		visitorKind = "buyer",
		buyerId = snapshot.buyerId,
		displayName = snapshot.buyerName,
		subtitle = subtitle,
	})
end

local function onDealSnapshot(snapshot: any?)
	if orchestratedMode then
		return
	end
	if not snapshot then
		CustomerPresentationController:clearVisitor()
		return
	end

	local phase = snapshot.phase
	if phase == "Haggling" then
		CustomerPresentationController:showSeller(snapshot)
	elseif phase == "BuyerVisit" or phase == "Selling" then
		CustomerPresentationController:showBuyer(snapshot)
	elseif TERMINAL_PHASES[phase] then
		CustomerPresentationController:clearVisitor()
	else
		CustomerPresentationController:clearVisitor()
	end
end

local function onShiftSnapshot(snapshot: any?)
	if orchestratedMode then
		return
	end
	if not snapshot or snapshot.active ~= true or snapshot.ended == true then
		CustomerPresentationController:clearVisitor()
	end
end

function CustomerPresentationController:Init()
	task.defer(function()
		shop = waitForShop()
	end)
end

function CustomerPresentationController:Start()
	local dealUpdate = Remotes.get("DealStateUpdate") :: RemoteEvent
	dealUpdate.OnClientEvent:Connect(onDealSnapshot)

	local shiftUpdate = Remotes.get("ShiftStateUpdate") :: RemoteEvent
	shiftUpdate.OnClientEvent:Connect(onShiftSnapshot)
end

return CustomerPresentationController
