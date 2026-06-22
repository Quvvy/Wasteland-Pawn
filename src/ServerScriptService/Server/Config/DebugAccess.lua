-- Server-only debug access allowlist and permissions. Never replicate to clients.
local RunService = game:GetService("RunService")

local SET_SCRAPS_MIN = 0
local SET_SCRAPS_MAX = 999_999

local Config = {
	EnabledInLive = true,
	StudioBypass = true,
	Users = {
		[86845593] = "owner",
		[87696934] = "owner",
	},
	Roles = {
		owner = {
			canView = true,
			canViewHiddenEconomy = true,
			canUseSafeActions = true,
			canUseDangerousActions = true,
			canResetSave = true,
			canSetScraps = true,
		},
		tester = {
			canView = true,
			canViewHiddenEconomy = false,
			canUseSafeActions = true,
			canUseDangerousActions = false,
			canResetSave = false,
			canSetScraps = false,
		},
	},
	Actions = {
		GiveRandomItem = { tier = "dangerous" },
		GiveRandomTech = { tier = "dangerous" },
		GiveRandomCollectible = { tier = "dangerous" },
		FillInventory = { tier = "dangerous" },
		ClearInventory = { tier = "dangerous" },
		ClearDisplay = { tier = "dangerous" },
		GiveRandomDisplayItem = { tier = "dangerous" },
		ForceBuyerVisit = { tier = "dangerous" },
		ForceRareBuyerVisit = { tier = "dangerous" },
		SkipToClosingRush = { tier = "dangerous" },
		EndShift = { tier = "dangerous" },
		ResetSaveData = { tier = "dangerous", requires = "canResetSave" },
		SetScraps = { tier = "dangerous", requires = "canSetScraps" },
	},
}

local DebugAccess = {}

local function isStudioSession(): boolean
	return RunService:IsStudio()
end

local function resolveRoleName(player: Player): string?
	if isStudioSession() and Config.StudioBypass then
		return "owner"
	end

	if not Config.EnabledInLive then
		return nil
	end

	return Config.Users[player.UserId]
end

local function getRolePermissions(roleName: string?): any?
	if not roleName then
		return nil
	end
	return Config.Roles[roleName]
end

function DebugAccess.getRole(player: Player): string?
	return resolveRoleName(player)
end

function DebugAccess.canViewDebug(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canView == true
end

function DebugAccess.canViewHiddenEconomy(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canViewHiddenEconomy == true
end

function DebugAccess.canUseSafeActions(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canUseSafeActions == true
end

function DebugAccess.canUseDangerousActions(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canUseDangerousActions == true
end

function DebugAccess.canResetSave(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canResetSave == true
end

function DebugAccess.canSetScraps(player: Player): boolean
	local perms = getRolePermissions(resolveRoleName(player))
	return perms ~= nil and perms.canSetScraps == true
end

function DebugAccess.canRunDebugAction(player: Player, actionName: string): boolean
	if not DebugAccess.canViewDebug(player) then
		return false
	end

	local action = Config.Actions[actionName]
	if not action then
		return false
	end

	local perms = getRolePermissions(resolveRoleName(player))
	if not perms then
		return false
	end

	if action.tier == "dangerous" and not perms.canUseDangerousActions then
		return false
	end

	if action.requires then
		return perms[action.requires] == true
	end

	return true
end

function DebugAccess.validateSetScrapsArgs(_player: Player, payload: any): (boolean, number?, string?)
	if type(payload) ~= "table" then
		return false, nil, "Invalid payload"
	end

	for key in payload do
		if key ~= "amount" then
			return false, nil, "Invalid payload"
		end
	end

	local amount = payload.amount
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return false, nil, "Invalid amount"
	end

	local clamped = math.clamp(math.floor(amount), SET_SCRAPS_MIN, SET_SCRAPS_MAX)
	return true, clamped, nil
end

function DebugAccess.validateDebugActionArgs(player: Player, actionName: string, payload: any): (boolean, string?)
	if actionName == "SetScraps" then
		local ok, _, err = DebugAccess.validateSetScrapsArgs(player, payload)
		return ok, err
	end

	if payload ~= nil and type(payload) == "table" and next(payload) ~= nil then
		return false, "Unexpected payload"
	end

	return true, nil
end

function DebugAccess.buildAccessSnapshot(player: Player): { ok: boolean, error: string? } & {
	canView: boolean?,
	role: string?,
	canViewHiddenEconomy: boolean?,
	permissions: {
		safe: boolean?,
		dangerous: boolean?,
		resetSave: boolean?,
		setScraps: boolean?,
	}?,
}
	local role = resolveRoleName(player)
	local perms = getRolePermissions(role)
	if not perms or not perms.canView then
		return { ok = true, canView = false }
	end

	return {
		ok = true,
		canView = true,
		role = role,
		canViewHiddenEconomy = perms.canViewHiddenEconomy == true,
		permissions = {
			safe = perms.canUseSafeActions == true,
			dangerous = perms.canUseDangerousActions == true,
			resetSave = perms.canResetSave == true,
			setScraps = perms.canSetScraps == true,
		},
	}
end

function DebugAccess.sanitizeArgsForLog(actionName: string, payload: any): any
	if actionName == "SetScraps" and type(payload) == "table" then
		return { amount = payload.amount }
	end
	return nil
end

return DebugAccess
