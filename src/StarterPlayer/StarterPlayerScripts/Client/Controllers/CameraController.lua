local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientPresentation = require(Shared.Config.ClientPresentation)

local HubWorld = require(script.Parent.HubWorld)

local CameraController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local savedCameraType: Enum.CameraType? = nil
local savedCameraSubject: Instance? = nil
local savedCameraCFrame: CFrame? = nil

local shopkeeperActive = false
local shelfFocusActive = false
local shopkeeperSuspendedForShelfFocus = false
local suspendedShopkeeperAnchors: HubWorld.PresentationAnchors? = nil
local suspendedFocusMode: string? = nil
local suspendedShopkeeperCFrame: CFrame? = nil
local focusMode = "ShopClosed"
local panConnection: RBXScriptConnection? = nil
local enterTweenConn: RBXScriptConnection? = nil
local shelfFocusTweenConn: RBXScriptConnection? = nil

local shelfFocusLookAt: Vector3? = nil

local anchors: HubWorld.PresentationAnchors? = nil
local cameraBasePosition: Vector3? = nil
local currentYawOffset = 0
local currentPitchOffset = 0

local function getConfigNumber(name: string, fallback: number): number
	local value = ClientPresentation[name]
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function degToRad(degrees: number): number
	return math.rad(degrees)
end

local function getCharacterRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getPlayerPanCenter(): Vector3
	if not anchors then
		return Vector3.zero
	end

	if anchors.playerCounter then
		return anchors.playerCounter.Position
	end

	return anchors.counterLookAt.Position
end

local function normalizeAxisWithDeadZone(studs: number, maxStuds: number, deadZoneStuds: number): number
	local magnitude = math.abs(studs)
	if magnitude <= deadZoneStuds then
		return 0
	end

	local usableRange = math.max(maxStuds - deadZoneStuds, 1)
	local normalized = math.clamp((magnitude - deadZoneStuds) / usableRange, 0, 1)
	local curved = normalized * normalized * (3 - (2 * normalized))
	return math.sign(studs) * curved
end

local function getCharacterPanNormalized(): (number, number)
	local root = getCharacterRoot()
	if not root or not cameraBasePosition or not anchors then
		return 0, 0
	end

	local center = getPlayerPanCenter()
	local flatForward = center - cameraBasePosition
	flatForward = Vector3.new(flatForward.X, 0, flatForward.Z)
	if flatForward.Magnitude < 0.01 then
		return 0, 0
	end

	local forward = flatForward.Unit
	local right = forward:Cross(Vector3.yAxis).Unit
	local offset = root.Position - center
	local horizontalStuds = math.max(getConfigNumber("ShopkeeperCharacterPanHorizontalStuds", 14), 1)
	local depthStuds = math.max(getConfigNumber("ShopkeeperCharacterPanDepthStuds", 12), 1)
	local deadZoneStuds = math.max(getConfigNumber("ShopkeeperCharacterPanDeadZoneStuds", 0), 0)

	local x = normalizeAxisWithDeadZone(offset:Dot(right), horizontalStuds, deadZoneStuds)
	local y = normalizeAxisWithDeadZone(offset:Dot(forward), depthStuds, deadZoneStuds)
	return x, y
end

local function computeBaseLookTarget(): Vector3
	if not anchors then
		return Vector3.zero
	end

	local base = anchors.counterLookAt.Position
	if focusMode == "Explore" then
		local root = getCharacterRoot()
		if root then
			local strength = math.clamp(getConfigNumber("ShopkeeperExplorePlayerFocusStrength", 0.25), 0, 1)
			base = base:Lerp(root.Position, strength)
		end
	end
	return base
end

local function getHorizontalDistance(a: Vector3, b: Vector3): number
	local delta = a - b
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function getShelfAssistStrength(target: BasePart?): number
	local root = getCharacterRoot()
	if not root or not target then
		return 0
	end

	local startDistance = math.max(getConfigNumber("ShopkeeperShelfAssistStartDistanceStuds", 7), 0.1)
	local fullDistance = math.clamp(getConfigNumber("ShopkeeperShelfAssistFullDistanceStuds", 3), 0, startDistance)
	local distance = getHorizontalDistance(root.Position, target.Position)
	if distance >= startDistance then
		return 0
	end
	if distance <= fullDistance then
		return 1
	end

	local t = 1 - ((distance - fullDistance) / (startDistance - fullDistance))
	return t * t * (3 - (2 * t))
end

local function blendShelfLookTarget(base: Vector3): (Vector3, number)
	if not anchors then
		return base, 0
	end

	local strength = math.clamp(
		getConfigNumber("ShopkeeperShelfAimStrength", getConfigNumber("ShopkeeperShelfBiasStrength", 1)),
		0,
		1
	)
	local blended = base
	local strongestShelfBlend = 0

	if anchors.sellShelfLookAt then
		local t = getShelfAssistStrength(anchors.sellShelfLookAt) * strength
		strongestShelfBlend = math.max(strongestShelfBlend, t)
		blended = blended:Lerp(anchors.sellShelfLookAt.Position, t)
	end
	if anchors.displayShelfLookAt then
		local t = getShelfAssistStrength(anchors.displayShelfLookAt) * strength
		strongestShelfBlend = math.max(strongestShelfBlend, t)
		blended = blended:Lerp(anchors.displayShelfLookAt.Position, t)
	end
	if anchors.stashLookAt then
		local t = getShelfAssistStrength(anchors.stashLookAt) * strength
		strongestShelfBlend = math.max(strongestShelfBlend, t)
		blended = blended:Lerp(anchors.stashLookAt.Position, t)
	end

	return blended, strongestShelfBlend
end

local function getPanLimits(): (number, number)
	if focusMode == "ShopClosed" then
		return 0, 0
	end

	if focusMode == "DealActive" then
		return degToRad(getConfigNumber("ShopkeeperDealPanMaxYawDegrees", 40)),
			degToRad(getConfigNumber("ShopkeeperDealPanMaxPitchDegrees", 8))
	end

	return degToRad(getConfigNumber("ShopkeeperExplorePanMaxYawDegrees", getConfigNumber("ShopkeeperPanMaxYawDegrees", 58))),
		degToRad(getConfigNumber("ShopkeeperExplorePanMaxPitchDegrees", getConfigNumber("ShopkeeperPanMaxPitchDegrees", 10)))
end

local function computePanOffsets(): (number, number)
	if not cameraBasePosition or not anchors then
		return 0, 0
	end

	local panX, panY = getCharacterPanNormalized()
	local maxYaw, maxPitch = getPanLimits()

	local targetYaw = -panX * maxYaw
	local targetPitch = -panY * maxPitch

	return targetYaw, targetPitch
end

local function buildCameraCFrame(camPos: Vector3, yawOffset: number, pitchOffset: number): CFrame
	if not anchors then
		return CFrame.new(camPos)
	end

	local base = computeBaseLookTarget()
	if focusMode == "DealActive" and anchors.counterItem then
		local focusStrength = math.clamp(getConfigNumber("ShopkeeperDealCounterItemFocusStrength", 0.28), 0, 1)
		base = base:Lerp(anchors.counterItem.Position, focusStrength)
	end
	local shelfTarget, shelfBlend = blendShelfLookTarget(base)

	local toBase = shelfTarget - camPos
	if toBase.Magnitude < 0.01 then
		return CFrame.new(camPos)
	end

	local baseLook = CFrame.lookAt(camPos, camPos + toBase.Unit)
	local yawScale = 1 - (shelfBlend * 0.2)
	return baseLook * CFrame.Angles(pitchOffset, yawOffset * yawScale, 0)
end

local function applyCameraLook()
	if not shopkeeperActive or not cameraBasePosition then
		return
	end

	local targetYaw, targetPitch = computePanOffsets()
	local smooth = math.clamp(ClientPresentation.ShopkeeperPanSmoothness, 0.02, 1)

	currentYawOffset += (targetYaw - currentYawOffset) * smooth
	currentPitchOffset += (targetPitch - currentPitchOffset) * smooth

	camera.CFrame = buildCameraCFrame(cameraBasePosition, currentYawOffset, currentPitchOffset)
end

local function stopShelfFocusTween()
	if shelfFocusTweenConn then
		shelfFocusTweenConn:Disconnect()
		shelfFocusTweenConn = nil
	end
end

local function stopPanLoop()
	if panConnection then
		panConnection:Disconnect()
		panConnection = nil
	end
end

local function stopEnterTween()
	if enterTweenConn then
		enterTweenConn:Disconnect()
		enterTweenConn = nil
	end
end

local function startPanLoop()
	stopPanLoop()
	panConnection = RunService.RenderStepped:Connect(applyCameraLook)
end

local function snapCameraToBaseLook()
	if not cameraBasePosition then
		return
	end
	camera.CFrame = buildCameraCFrame(cameraBasePosition, currentYawOffset, currentPitchOffset)
end

local function restorePlayerCamera()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function CameraController:isShelfFocusActive(): boolean
	return shelfFocusActive
end

local function getLookPointFromCFrame(cf: CFrame, fallbackTarget: Vector3): Vector3
	local offset = fallbackTarget - cf.Position
	local depth = math.max(offset.Magnitude, 4)
	return cf.Position + cf.LookVector * depth
end

function CameraController:suspendShopkeeperForShelfFocus(): boolean
	if not shopkeeperActive or not anchors then
		return false
	end

	stopPanLoop()
	stopEnterTween()

	suspendedShopkeeperCFrame = camera.CFrame
	shopkeeperSuspendedForShelfFocus = true
	suspendedShopkeeperAnchors = anchors
	suspendedFocusMode = focusMode

	shopkeeperActive = false
	focusMode = "ShopClosed"
	anchors = nil
	cameraBasePosition = nil
	currentYawOffset = 0
	currentPitchOffset = 0

	return true
end

function CameraController:cancelShopkeeperShelfFocusSuspension()
	shopkeeperSuspendedForShelfFocus = false
	suspendedShopkeeperAnchors = nil
	suspendedFocusMode = nil
	suspendedShopkeeperCFrame = nil
end

function CameraController:restoreShopkeeperAfterShelfFocus(shop: Instance?, presentationAnchors: HubWorld.PresentationAnchors?)
	if not shopkeeperSuspendedForShelfFocus then
		return
	end

	shopkeeperSuspendedForShelfFocus = false
	local anchorsToRestore = presentationAnchors or suspendedShopkeeperAnchors
	local focusToRestore = suspendedFocusMode
	local handoffCFrame = suspendedShopkeeperCFrame
	suspendedShopkeeperAnchors = nil
	suspendedFocusMode = nil
	suspendedShopkeeperCFrame = nil

	if not anchorsToRestore then
		return
	end

	if handoffCFrame then
		camera.CFrame = handoffCFrame
	end

	self:enterShopkeeperMode(shop :: Instance, anchorsToRestore)
	if focusToRestore then
		focusMode = focusToRestore
		snapCameraToBaseLook()
	end
end

function CameraController:exitShelfFocusMode(restoreShopkeeper: boolean?)
	stopShelfFocusTween()

	if not shelfFocusActive then
		return
	end

	shelfFocusActive = false
	shelfFocusLookAt = nil
	cameraBasePosition = nil

	local skipRestoreSnap = shopkeeperSuspendedForShelfFocus and restoreShopkeeper == true

	pcall(function()
		if skipRestoreSnap then
			if suspendedShopkeeperCFrame then
				camera.CFrame = suspendedShopkeeperCFrame
			end
			camera.CameraType = Enum.CameraType.Scriptable
		else
			restorePlayerCamera()
		end
	end)

	if not skipRestoreSnap then
		self:cancelShopkeeperShelfFocusSuspension()
	end

	savedCameraType = nil
	savedCameraSubject = nil
	savedCameraCFrame = nil
	if not skipRestoreSnap then
		suspendedShopkeeperCFrame = nil
	end
end

function CameraController:enterShelfFocusMode(cameraPosition: Vector3, lookAtPosition: Vector3): boolean
	if shopkeeperActive then
		self:suspendShopkeeperForShelfFocus()
	end

	if shelfFocusActive then
		shelfFocusLookAt = lookAtPosition
		cameraBasePosition = cameraPosition
		camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
		return true
	end

	local ok, err = pcall(function()
		local startCFrame = suspendedShopkeeperCFrame or camera.CFrame

		savedCameraType = camera.CameraType
		savedCameraSubject = camera.CameraSubject
		savedCameraCFrame = camera.CFrame

		shelfFocusLookAt = lookAtPosition
		local startPos = startCFrame.Position
		local startLook = getLookPointFromCFrame(startCFrame, lookAtPosition)
		cameraBasePosition = startPos

		camera.CameraType = Enum.CameraType.Scriptable
		shelfFocusActive = true

		local tweenAlpha = Instance.new("NumberValue")
		tweenAlpha.Value = 0
		local tween = TweenService:Create(
			tweenAlpha,
			TweenInfo.new(ClientPresentation.CameraTweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = 1 }
		)
		tween:Play()
		shelfFocusTweenConn = tweenAlpha.Changed:Connect(function()
			if not shelfFocusActive or not shelfFocusLookAt then
				return
			end
			local alpha = tweenAlpha.Value
			local pos = startPos:Lerp(cameraPosition, alpha)
			local look = startLook:Lerp(lookAtPosition, alpha)
			cameraBasePosition = pos
			camera.CFrame = CFrame.lookAt(pos, look)
		end)
		tween.Completed:Connect(function()
			stopShelfFocusTween()
			tweenAlpha:Destroy()
			cameraBasePosition = cameraPosition
			if shelfFocusLookAt then
				camera.CFrame = CFrame.lookAt(cameraPosition, shelfFocusLookAt)
			end
		end)
	end)

	if not ok then
		warn(`CameraController: enterShelfFocusMode failed: {err}`)
		self:exitShelfFocusMode()
		return false
	end

	return true
end

function CameraController:isShopkeeperModeActive(): boolean
	return shopkeeperActive
end

function CameraController:setFocusMode(mode: string)
	focusMode = mode
end

function CameraController:getFocusMode(): string
	return focusMode
end

function CameraController:exitShopkeeperMode()
	stopPanLoop()
	stopEnterTween()

	if not shopkeeperActive then
		return
	end

	shopkeeperActive = false
	focusMode = "ShopClosed"
	anchors = nil
	cameraBasePosition = nil
	currentYawOffset = 0
	currentPitchOffset = 0

	pcall(function()
		restorePlayerCamera()
	end)

	savedCameraType = nil
	savedCameraSubject = nil
	savedCameraCFrame = nil
end

function CameraController:enterShopkeeperMode(shop: Instance, presentationAnchors: HubWorld.PresentationAnchors): boolean
	if shelfFocusActive then
		self:exitShelfFocusMode()
	end

	if shopkeeperActive then
		anchors = presentationAnchors
		cameraBasePosition = presentationAnchors.cameraSpot.Position
		return true
	end

	local ok, err = pcall(function()
		savedCameraType = camera.CameraType
		savedCameraSubject = camera.CameraSubject
		savedCameraCFrame = camera.CFrame

		anchors = presentationAnchors
		local goalPos = presentationAnchors.cameraSpot.Position
		local startPos = if savedCameraCFrame then savedCameraCFrame.Position else goalPos

		cameraBasePosition = startPos
		currentYawOffset = 0
		currentPitchOffset = 0

		camera.CameraType = Enum.CameraType.Scriptable
		shopkeeperActive = true
		focusMode = "Explore"

		snapCameraToBaseLook()

		local tweenAlpha = Instance.new("NumberValue")
		tweenAlpha.Value = 0
		local tween = TweenService:Create(
			tweenAlpha,
			TweenInfo.new(ClientPresentation.CameraTweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = 1 }
		)
		tween:Play()
		enterTweenConn = tweenAlpha.Changed:Connect(function()
			if not shopkeeperActive then
				return
			end
			cameraBasePosition = startPos:Lerp(goalPos, tweenAlpha.Value)
			snapCameraToBaseLook()
		end)
		tween.Completed:Connect(function()
			stopEnterTween()
			tweenAlpha:Destroy()
			cameraBasePosition = goalPos
		end)

		startPanLoop()
	end)

	if not ok then
		warn(`CameraController: enterShopkeeperMode failed: {err}`)
		self:exitShopkeeperMode()
		return false
	end

	return true
end

function CameraController:Init()
	player.CharacterAdded:Connect(function()
		shopkeeperSuspendedForShelfFocus = false
		suspendedShopkeeperAnchors = nil
		suspendedFocusMode = nil
		suspendedShopkeeperCFrame = nil
		if shopkeeperActive then
			self:exitShopkeeperMode()
		end
		if shelfFocusActive then
			self:exitShelfFocusMode()
		end
	end)
end

function CameraController:Start()
	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:exitShopkeeperMode()
			self:exitShelfFocusMode()
		end
	end)
end

return CameraController
