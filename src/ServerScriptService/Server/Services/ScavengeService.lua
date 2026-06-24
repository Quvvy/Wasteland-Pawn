local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemValuation = require(Shared.Economy.ItemValuation)
local ScavengeLoot = require(Shared.Config.ScavengeLoot)
local Remotes = require(Shared.Net.Remotes)
local ObjectModel = require(Shared.Util.ObjectModel)

local DealService = require(script.Parent.DealService)
local InventoryService = require(script.Parent.InventoryService)
local ShiftService = require(script.Parent.ShiftService)

local ScavengeService = {}

local DEFAULT_LOOT_TABLE = "BasicJunk"
local DEFAULT_USES_PER_CYCLE = 1
local PROMPT_PART_NAME = "ScavengePromptPart"
local PROMPT_NAME = "ScavengeNodePrompt"

local DEBUG_SCAVENGE = false

type ScavengeNodeRecord = {
	nodeId: string,
	node: Instance,
	promptPart: BasePart,
	prompt: ProximityPrompt,
	lootTable: string,
	usesPerCycle: number,
}

local nodeRecordsById: { [string]: ScavengeNodeRecord } = {}
local playerNodeUses: { [Player]: { [string]: { cycle: number, uses: number } } } = {}

local scanQueued = false
local scavengeNodesConnection: RBXScriptConnection? = nil
local scavengeNodesRemovingConnection: RBXScriptConnection? = nil
local worldConnection: RBXScriptConnection? = nil

local function debugLog(...)
	if DEBUG_SCAVENGE then
		warn("[Scavenge]", ...)
	end
end

local function getScavengeNodesFolder(): Instance?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end

	local outside = world:FindFirstChild("Outside")
	if not outside then
		return nil
	end

	return outside:FindFirstChild("ScavengeNodes")
end

local function isValidNodeContainer(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("Folder")
end

local function findPromptPart(node: Instance): BasePart?
	local part = node:FindFirstChild(PROMPT_PART_NAME, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function getPositiveIntegerAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value <= 0 then
		return fallback
	end
	return math.max(1, math.floor(value))
end

local function getLootTable(node: Instance): string
	local value = node:GetAttribute("LootTable")
	if type(value) == "string" and value ~= "" then
		return value
	end
	return DEFAULT_LOOT_TABLE
end

local function makeUniqueNodeId(base: string, usedIds: { [string]: boolean }): string
	local root = if base ~= "" then base else "ScavengeNode"
	local candidate = root
	local suffix = 2
	while usedIds[candidate] do
		candidate = `{root}_{suffix}`
		suffix += 1
	end
	usedIds[candidate] = true
	return candidate
end

local function resolveNodeId(node: Instance, usedIds: { [string]: boolean }): string
	local attributeValue = node:GetAttribute("NodeId")
	local requestedId = if type(attributeValue) == "string" and attributeValue ~= "" then attributeValue else node.Name
	local nodeId = makeUniqueNodeId(requestedId, usedIds)
	if attributeValue ~= nodeId then
		node:SetAttribute("NodeId", nodeId)
	end
	return nodeId
end

local function configurePrompt(prompt: ProximityPrompt, nodeId: string)
	prompt.ActionText = "Search Junk"
	prompt.ObjectText = "Junk Pile"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("NodeId", nodeId)
end

local function ensurePrompt(promptPart: BasePart, nodeId: string): ProximityPrompt
	local prompt: ProximityPrompt? = nil
	for _, child in promptPart:GetChildren() do
		if child:IsA("ProximityPrompt") then
			if not prompt then
				prompt = child
			else
				child:Destroy()
			end
		end
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
	end

	prompt.Name = PROMPT_NAME
	configurePrompt(prompt, nodeId)
	promptPart:SetAttribute("NodeId", nodeId)
	if not prompt.Parent then
		prompt.Parent = promptPart
	end
	return prompt
end

local function isShopOpen(player: Player): boolean
	local shift = ShiftService:getShift(player)
	return shift ~= nil and shift.active == true and shift.ended ~= true
end

local function getUseInfo(player: Player, nodeId: string)
	local usesByNode = playerNodeUses[player]
	if not usesByNode then
		usesByNode = {}
		playerNodeUses[player] = usesByNode
	end

	local cycle = ShiftService:getScavengeWindowToken(player)
	local info = usesByNode[nodeId]
	if not info or info.cycle ~= cycle then
		info = {
			cycle = cycle,
			uses = 0,
		}
		usesByNode[nodeId] = info
	end

	return info
end

local function buildScavengedEntry(itemDef: any, hiddenOutcome: any)
	local trueValue = hiddenOutcome.trueValue
	return ObjectModel.fromDefinition(itemDef, {
		rarityId = hiddenOutcome.rarityId,
		trueValue = trueValue,
		purchasePrice = 0,
		estimatedLow = math.max(1, math.floor(trueValue * 0.8)),
		estimatedHigh = math.max(1, math.ceil(trueValue * 1.2)),
		sellerName = "Junk Pile",
	})
end

function ScavengeService:_scanNodes()
	local scavengeNodes = getScavengeNodesFolder()
	local records: { [string]: ScavengeNodeRecord } = {}
	local usedIds: { [string]: boolean } = {}

	if not scavengeNodes then
		nodeRecordsById = records
		debugLog("ScavengeNodes folder not found under Workspace.World.Outside")
		return
	end

	for _, node in scavengeNodes:GetChildren() do
		if not isValidNodeContainer(node) then
			continue
		end

		local promptPart = findPromptPart(node)
		if not promptPart then
			debugLog("Skipping node without ScavengePromptPart:", node:GetFullName())
			continue
		end

		local nodeId = resolveNodeId(node, usedIds)
		local prompt = ensurePrompt(promptPart, nodeId)
		local record: ScavengeNodeRecord = {
			nodeId = nodeId,
			node = node,
			promptPart = promptPart,
			prompt = prompt,
			lootTable = getLootTable(node),
			usesPerCycle = getPositiveIntegerAttribute(node, "UsesPerCycle", DEFAULT_USES_PER_CYCLE),
		}
		records[nodeId] = record
		debugLog("Discovered node", nodeId, node:GetFullName())
	end

	nodeRecordsById = records
end

function ScavengeService:_queueScan()
	if scanQueued then
		return
	end

	scanQueued = true
	task.defer(function()
		scanQueued = false
		self:_scanNodes()
		self:_watchScavengeNodesFolder()
	end)
end

function ScavengeService:_watchScavengeNodesFolder()
	local scavengeNodes = getScavengeNodesFolder()
	if not scavengeNodes then
		return
	end

	if scavengeNodesConnection then
		scavengeNodesConnection:Disconnect()
	end
	if scavengeNodesRemovingConnection then
		scavengeNodesRemovingConnection:Disconnect()
	end

	scavengeNodesConnection = scavengeNodes.DescendantAdded:Connect(function()
		self:_queueScan()
	end)
	scavengeNodesRemovingConnection = scavengeNodes.DescendantRemoving:Connect(function()
		self:_queueScan()
	end)
end

function ScavengeService:_watchWorld()
	if worldConnection then
		worldConnection:Disconnect()
	end

	worldConnection = Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "World" or descendant.Name == "Outside" or descendant.Name == "ScavengeNodes" then
			self:_queueScan()
		end
	end)
end

function ScavengeService:searchNode(player: Player, nodeId: any)
	if type(nodeId) ~= "string" or nodeId == "" then
		return { ok = false, error = "Scavenge node not found" }
	end

	local record = nodeRecordsById[nodeId]
	if not record or not record.node.Parent or not record.promptPart.Parent then
		self:_scanNodes()
		record = nodeRecordsById[nodeId]
	end

	if not record then
		debugLog("Rejected unknown node id:", nodeId)
		return { ok = false, error = "Scavenge node not found" }
	end

	if isShopOpen(player) then
		debugLog("Blocked active shop:", player.Name, nodeId)
		return { ok = false, error = "Search while the shop is closed." }
	end

	if DealService:hasBlockingDealForScavenge(player) then
		debugLog("Blocked active deal:", player.Name, nodeId)
		return { ok = false, error = "Finish the current deal first." }
	end

	local useInfo = getUseInfo(player, nodeId)
	if useInfo.uses >= record.usesPerCycle then
		debugLog("Blocked use limit:", player.Name, nodeId)
		return { ok = false, error = "Search again later." }
	end

	if not InventoryService:canAddToDisplay(player) and not InventoryService:canAddToStash(player) then
		debugLog("Blocked no room:", player.Name, nodeId)
		return { ok = false, error = "No room on Shelf or in Storage." }
	end

	local rng = Random.new()
	local itemDef = ScavengeLoot.roll(record.lootTable, rng)
	if not itemDef then
		debugLog("Loot roll failed:", nodeId, record.lootTable)
		return { ok = false, error = "Could not find anything useful." }
	end

	local hiddenOutcome = ItemValuation.createHiddenOutcome(itemDef, nil, rng)
	local entry = buildScavengedEntry(itemDef, hiddenOutcome)
	local placed, location = InventoryService:addAcquiredItemToShelfOrStash(player, entry)
	if not placed then
		debugLog("Placement failed after roll:", player.Name, nodeId)
		return { ok = false, error = "No room on Shelf or in Storage." }
	end

	useInfo.uses += 1

	local placement = if location == ObjectModel.Locations.Display then "Shelf" else "Storage"
	local itemName = itemDef.displayName or "Item"
	local message = if placement == "Shelf"
		then `Found: {itemName}\nAdded to Shelf.`
		else `Found: {itemName}\nShelf full. Added to Storage.`

	debugLog("Search success:", player.Name, nodeId, itemName, placement)
	return {
		ok = true,
		message = message,
		itemName = itemName,
		placement = placement,
		nodeId = nodeId,
	}
end

function ScavengeService:Init()
	Remotes.setup()

	Players.PlayerRemoving:Connect(function(player)
		playerNodeUses[player] = nil
	end)
end

function ScavengeService:Start()
	self:_scanNodes()
	self:_watchScavengeNodesFolder()
	self:_watchWorld()

	local remote = Remotes.get("SearchScavengeNode") :: RemoteFunction
	remote.OnServerInvoke = function(player, nodeId)
		debugLog("Server received node id:", player.Name, nodeId)
		return self:searchNode(player, nodeId)
	end
end

return ScavengeService
