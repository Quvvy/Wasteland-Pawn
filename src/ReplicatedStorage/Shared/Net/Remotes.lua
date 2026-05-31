local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "WastelandPawnRemotes"

local REMOTE_DEFINITIONS = {
	DealStateUpdate = "RemoteEvent",
	MakeOffer = "RemoteFunction",
	InspectItem = "RemoteFunction",
	AcceptCounter = "RemoteFunction",
	PassDeal = "RemoteFunction",
	SellItem = "RemoteFunction",
	KeepItem = "RemoteFunction",
	StartDeal = "RemoteFunction",
}

local cache: { [string]: Instance } = {}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.setup()
	if not RunService:IsServer() then
		return
	end

	local folder = getFolder()

	for remoteName, className in REMOTE_DEFINITIONS do
		if folder:FindFirstChild(remoteName) then
			continue
		end

		local remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = folder
	end
end

function Remotes.get(remoteName: string): Instance
	if cache[remoteName] then
		return cache[remoteName]
	end

	local folder = getFolder()
	local remote = folder:WaitForChild(remoteName, 10)
	if not remote then
		error(`Remote not found: {remoteName}`)
	end

	cache[remoteName] = remote
	return remote
end

Remotes.Names = REMOTE_DEFINITIONS

return Remotes
