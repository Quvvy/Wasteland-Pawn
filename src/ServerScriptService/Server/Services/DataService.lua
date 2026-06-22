local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HaggleTuning = require(Shared.Config.HaggleTuning)

local DataService = {}

DataService.STARTING_CASH = HaggleTuning.startingCash

local STORE_NAME = "WastelandPawn_PlayerData_v1"
local SAVE_VERSION = 1
local MAX_SCRAPS = 999999999
local MAX_STASH_ITEMS = 2
local MAX_DISPLAY_ITEMS = 3
local SAVE_DEBOUNCE_SECONDS = 30

local playerData: { [Player]: any } = {}
local shopStateProvider: any = nil
local pendingSaveTokens: { [Player]: number } = {}
local saveTokenCounter = 0

local store = DataStoreService:GetDataStore(STORE_NAME)

local function clampCash(amount: any): number
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return HaggleTuning.startingCash
	end
	return math.clamp(math.floor(amount + 0.5), 0, MAX_SCRAPS)
end

local function copyStringList(values: any): { string }
	local copy = {}
	if type(values) ~= "table" then
		return copy
	end
	for _, value in values do
		if type(value) == "string" and value ~= "" then
			table.insert(copy, value)
		end
	end
	return copy
end

local function copyNumber(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.floor(value + 0.5)
end

local function copyString(value: any): string?
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function sanitizeSlot(value: any, maxSlots: number): number?
	local slot = copyNumber(value)
	if not slot then
		return nil
	end
	if slot < 1 or slot > maxSlots then
		return nil
	end
	return slot
end

local function sanitizeSavedItem(raw: any, location: string, maxSlots: number): any?
	if type(raw) ~= "table" then
		return nil
	end

	local slotIndex = sanitizeSlot(raw.slotIndex or raw.displaySlotIndex or raw.stashSlotIndex, maxSlots)
	if not slotIndex then
		return nil
	end

	local displayName = copyString(raw.displayName)
	local itemId = copyString(raw.itemId or raw.objectId)
	if not displayName or not itemId then
		return nil
	end

	local payload = {
		permanentId = copyString(raw.permanentId),
		itemId = itemId,
		objectId = copyString(raw.objectId) or itemId,
		displayName = displayName,
		category = copyString(raw.category),
		traits = copyStringList(raw.traits),
		flavorText = copyString(raw.flavorText),
		dealArchetypeId = copyString(raw.dealArchetypeId),
		dealArchetypeName = copyString(raw.dealArchetypeName),
		rarityId = copyString(raw.rarityId),
		trueValue = copyNumber(raw.trueValue),
		purchasePrice = copyNumber(raw.purchasePrice),
		estimatedLow = copyNumber(raw.estimatedLow),
		estimatedHigh = copyNumber(raw.estimatedHigh),
		sellerId = copyString(raw.sellerId),
		sellerName = copyString(raw.sellerName),
		sellerTell = copyString(raw.sellerTell),
		sellerAsk = copyNumber(raw.sellerAsk),
		sellerMinimum = copyNumber(raw.sellerMinimum),
		inspected = raw.inspected == true,
		buyRoundCount = copyNumber(raw.buyRoundCount),
		tacticsUsed = copyStringList(raw.tacticsUsed),
	}

	if location == "display" then
		payload.displaySlotIndex = slotIndex
	else
		payload.stashSlotIndex = slotIndex
	end

	return payload
end

local function sanitizeSavedItems(rawItems: any, location: string, maxCount: number, maxSlots: number): { any }
	local items = {}
	local usedSlots = {}
	local seenIds = {}
	if type(rawItems) ~= "table" then
		return items
	end

	for _, raw in rawItems do
		if #items >= maxCount then
			break
		end

		local item = sanitizeSavedItem(raw, location, maxSlots)
		if not item then
			continue
		end

		local slotIndex = if location == "display" then item.displaySlotIndex else item.stashSlotIndex
		if usedSlots[slotIndex] then
			continue
		end

		local identity = item.permanentId or `{location}:{slotIndex}:{item.itemId}:{item.displayName}`
		if seenIds[identity] then
			continue
		end

		usedSlots[slotIndex] = true
		seenIds[identity] = true
		table.insert(items, item)
	end

	table.sort(items, function(a, b)
		local slotA = if location == "display" then a.displaySlotIndex else a.stashSlotIndex
		local slotB = if location == "display" then b.displaySlotIndex else b.stashSlotIndex
		return (slotA or 0) < (slotB or 0)
	end)

	return items
end

local function saveKey(player: Player): string
	return `player_{player.UserId}`
end

local function warnPersistence(message: string)
	warn(`[WastelandPawn] Persistence: {message}`)
end

local function canSeePersistenceDebug(player: Player): boolean
	local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
	return DebugAccess.canViewDebug(player)
end

local function newDefaultData()
	return {
		cash = HaggleTuning.startingCash,
		loadedPersistentState = {
			stash = {},
			display = {},
		},
		loadStatus = "not_loaded",
		saveStatus = "idle",
		lastLoadError = nil,
		lastSaveError = nil,
		saveDisabled = false,
		dirty = false,
		savedScraps = HaggleTuning.startingCash,
		savedStashCount = 0,
		savedDisplayCount = 0,
	}
end

local function sanitizeLoadedPayload(payload: any): (any?, string?)
	if payload == nil then
		return {
			version = SAVE_VERSION,
			scraps = HaggleTuning.startingCash,
			stash = {},
			display = {},
			updatedAt = nil,
		}, nil
	end

	if type(payload) ~= "table" then
		return nil, "Malformed save payload"
	end

	local version = payload.version
	if type(version) ~= "number" then
		return nil, "Malformed save version"
	end
	if version > SAVE_VERSION then
		return nil, `Unsupported future save version {version}`
	end
	if version ~= SAVE_VERSION then
		return nil, `Unsupported save version {version}`
	end

	return {
		version = SAVE_VERSION,
		scraps = clampCash(payload.scraps),
		stash = sanitizeSavedItems(payload.stash, "stash", MAX_STASH_ITEMS, MAX_STASH_ITEMS),
		display = sanitizeSavedItems(payload.display, "display", MAX_DISPLAY_ITEMS, MAX_DISPLAY_ITEMS),
		updatedAt = copyNumber(payload.updatedAt),
	}, nil
end

function DataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_ensurePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:savePlayer(player, "leave")
		playerData[player] = nil
		pendingSaveTokens[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			self:savePlayer(player, "shutdown")
		end
	end)

	for _, player in Players:GetPlayers() do
		self:_ensurePlayer(player)
	end
end

function DataService:Start() end

function DataService:setShopStateProvider(provider: (Player) -> any?)
	shopStateProvider = provider
end

function DataService:_loadPlayerData(player: Player, data)
	data.loadStatus = "loading"
	local ok, result = pcall(function()
		return store:GetAsync(saveKey(player))
	end)

	if not ok then
		data.loadStatus = "failed"
		data.saveStatus = "disabled"
		data.saveDisabled = true
		data.lastLoadError = tostring(result)
		data.cash = HaggleTuning.startingCash
		data.loadedPersistentState = {
			stash = {},
			display = {},
		}
		warnPersistence(`load failed for {player.Name}: {result}`)
		return
	end

	local sanitized, validationError = sanitizeLoadedPayload(result)
	if not sanitized then
		data.lastLoadError = validationError
		if validationError and string.find(validationError, "future save version", 1, true) then
			data.loadStatus = "future_version"
			data.saveStatus = "disabled"
			data.saveDisabled = true
			warnPersistence(`future save version for {player.Name}; saving disabled this session`)
		else
			data.loadStatus = "failed"
			warnPersistence(`invalid save for {player.Name}: {validationError or "unknown error"}`)
		end
		data.cash = HaggleTuning.startingCash
		data.loadedPersistentState = {
			stash = {},
			display = {},
		}
		return
	end

	data.cash = sanitized.scraps
	data.loadedPersistentState = {
		stash = sanitized.stash,
		display = sanitized.display,
	}
	data.loadStatus = if result == nil then "default" else "loaded"
	data.lastLoadError = nil
	data.savedScraps = sanitized.scraps
	data.savedStashCount = #sanitized.stash
	data.savedDisplayCount = #sanitized.display
end

function DataService:_ensurePlayer(player: Player)
	if playerData[player] then
		return
	end

	local data = newDefaultData()
	playerData[player] = data
	self:_loadPlayerData(player, data)
end

function DataService:getLoadedPersistentState(player: Player): any
	self:_ensurePlayer(player)
	local data = playerData[player]
	return {
		stash = data.loadedPersistentState.stash or {},
		display = data.loadedPersistentState.display or {},
	}
end

function DataService:getCash(player: Player): number
	self:_ensurePlayer(player)
	return playerData[player].cash
end

function DataService:_markDirty(player: Player)
	local data = playerData[player]
	if not data then
		return
	end
	data.dirty = true
	self:requestSave(player)
end

function DataService:setCash(player: Player, amount: number)
	self:_ensurePlayer(player)
	playerData[player].cash = clampCash(amount)
	self:_markDirty(player)
end

function DataService:canAfford(player: Player, amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end

	return self:getCash(player) >= amount
end

function DataService:spend(player: Player, amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end

	self:_ensurePlayer(player)
	local data = playerData[player]

	if data.cash < amount then
		return false
	end

	data.cash = clampCash(data.cash - amount)
	self:_markDirty(player)
	return true
end

function DataService:addCash(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end

	self:_ensurePlayer(player)
	local data = playerData[player]
	data.cash = clampCash(data.cash + amount)
	self:_markDirty(player)
end

function DataService:markShopStateDirty(player: Player)
	self:_ensurePlayer(player)
	self:_markDirty(player)
end

function DataService:_buildSavePayload(player: Player, data)
	local shopState = {}
	if shopStateProvider then
		local ok, result = pcall(function()
			return shopStateProvider(player)
		end)
		if ok and type(result) == "table" then
			shopState = result
		elseif not ok then
			data.lastSaveError = tostring(result)
			warnPersistence(`shop state provider failed for {player.Name}: {result}`)
		end
	end

	local stash = sanitizeSavedItems(shopState.stash, "stash", MAX_STASH_ITEMS, MAX_STASH_ITEMS)
	local display = sanitizeSavedItems(shopState.display, "display", MAX_DISPLAY_ITEMS, MAX_DISPLAY_ITEMS)

	return {
		version = SAVE_VERSION,
		scraps = clampCash(data.cash),
		stash = stash,
		display = display,
		updatedAt = os.time(),
	}
end

function DataService:requestSave(player: Player)
	local data = playerData[player]
	if not data or data.saveDisabled then
		return
	end

	saveTokenCounter += 1
	local token = saveTokenCounter
	pendingSaveTokens[player] = token

	task.delay(SAVE_DEBOUNCE_SECONDS, function()
		if pendingSaveTokens[player] ~= token then
			return
		end
		pendingSaveTokens[player] = nil
		self:savePlayer(player, "debounced")
	end)
end

function DataService:savePlayer(player: Player, _reason: string?): boolean
	local data = playerData[player]
	if not data then
		return false
	end
	if data.saveDisabled then
		return false
	end

	pendingSaveTokens[player] = nil
	local payload = self:_buildSavePayload(player, data)
	data.saveStatus = "saving"

	local blockedByFutureVersion = false
	local ok, result = pcall(function()
		return store:UpdateAsync(saveKey(player), function(oldPayload)
			if type(oldPayload) == "table" and type(oldPayload.version) == "number" and oldPayload.version > SAVE_VERSION then
				blockedByFutureVersion = true
				return oldPayload
			end
			return payload
		end)
	end)

	if not ok then
		data.saveStatus = "failed"
		data.lastSaveError = tostring(result)
		warnPersistence(`save failed for {player.Name}: {result}`)
		return false
	end

	if blockedByFutureVersion then
		data.saveStatus = "disabled"
		data.saveDisabled = true
		data.lastSaveError = "Unsupported future save version; save skipped"
		warnPersistence(`save skipped for {player.Name}: future version already exists`)
		return false
	end

	data.saveStatus = "saved"
	data.lastSaveError = nil
	data.dirty = false
	data.savedScraps = payload.scraps
	data.savedStashCount = #payload.stash
	data.savedDisplayCount = #payload.display
	return true
end

function DataService:getDebugSnapshot(player: Player): any?
	if not canSeePersistenceDebug(player) then
		return nil
	end

	self:_ensurePlayer(player)
	local data = playerData[player]
	local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
	local key = saveKey(player)
	if not DebugAccess.canViewHiddenEconomy(player) then
		key = "(redacted)"
	end
	return {
		storeName = STORE_NAME,
		key = key,
		loadStatus = data.loadStatus,
		saveStatus = data.saveStatus,
		saveDisabled = data.saveDisabled == true,
		dirty = data.dirty == true,
		savedScraps = data.savedScraps,
		permanentStashCount = data.savedStashCount,
		permanentDisplayCount = data.savedDisplayCount,
		lastLoadError = data.lastLoadError,
		lastSaveError = data.lastSaveError,
	}
end

function DataService:debugResetPlayerData(player: Player): (boolean, string?)
	local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
	if not DebugAccess.canResetSave(player) then
		return false, "Forbidden"
	end

	self:_ensurePlayer(player)
	local ok, result = pcall(function()
		store:RemoveAsync(saveKey(player))
	end)
	if not ok then
		local message = tostring(result)
		playerData[player].lastSaveError = message
		playerData[player].saveStatus = "failed"
		return false, message
	end

	local data = playerData[player]
	data.cash = HaggleTuning.startingCash
	data.loadedPersistentState = {
		stash = {},
		display = {},
	}
	data.loadStatus = "reset"
	data.saveStatus = "reset"
	data.lastLoadError = nil
	data.lastSaveError = nil
	data.saveDisabled = false
	data.dirty = false
	data.savedScraps = HaggleTuning.startingCash
	data.savedStashCount = 0
	data.savedDisplayCount = 0
	return true, nil
end

function DataService:debugSetScraps(player: Player, amount: number): (boolean, string?)
	local DebugAccess = require(script.Parent.Parent.Config.DebugAccess)
	if not DebugAccess.canSetScraps(player) then
		return false, "Forbidden"
	end

	self:setCash(player, amount)
	self:requestSave(player)
	return true, nil
end

return DataService
