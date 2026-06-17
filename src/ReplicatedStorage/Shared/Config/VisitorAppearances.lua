-- Visitor archetype mapping and rig names. Models live in Studio under ReplicatedStorage.Assets.Visitors.

local VisitorAppearances = {}

VisitorAppearances.defaultArchetype = "default"

VisitorAppearances.archetypes = {
	default = {
		label = "Visitor",
		baseRig = "Default",
		bodyColor = Color3.fromRGB(140, 125, 110),
		accentColor = Color3.fromRGB(170, 155, 130),
	},

	engineer = {
		label = "Engineer",
		baseRig = "Engineer",
		bodyColor = Color3.fromRGB(100, 110, 120),
		accentColor = Color3.fromRGB(200, 160, 60),
		accessoryFolder = "Engineer",
		accessories = { "HardHat", "Goggles", "ToolBelt" },
	},

	collector = {
		label = "Collector",
		baseRig = "Collector",
		bodyColor = Color3.fromRGB(85, 70, 105),
		accentColor = Color3.fromRGB(210, 180, 90),
		accessoryFolder = "Collector",
		accessories = { "FancyHat", "Satchel", "DisplayCase" },
	},

	black_market = {
		label = "Black Market Dealer",
		baseRig = "BlackMarket",
		bodyColor = Color3.fromRGB(40, 42, 48),
		accentColor = Color3.fromRGB(80, 120, 70),
		accessoryFolder = "BlackMarket",
		accessories = { "Hood", "Mask", "ContrabandBag" },
	},

	scrapper = {
		label = "Scrapper",
		baseRig = "Scrapper",
		bodyColor = Color3.fromRGB(115, 100, 80),
		accentColor = Color3.fromRGB(150, 130, 90),
		accessoryFolder = "Scrapper",
		accessories = { "RagCap", "JunkSack" },
	},

	alien = {
		label = "Alien Tourist",
		baseRig = "Alien",
		bodyColor = Color3.fromRGB(80, 210, 170),
		accentColor = Color3.fromRGB(200, 100, 255),
		accessoryFolder = "Alien",
		accessories = { "AntennaHeadband", "SouvenirBag" },
	},

	robot = {
		label = "Robot",
		baseRig = "Robot",
		bodyColor = Color3.fromRGB(175, 180, 190),
		accentColor = Color3.fromRGB(60, 200, 255),
		accessoryFolder = "Robot",
		accessories = { "SensorDome", "CircuitPanel" },
	},

	cultist = {
		label = "Cultist",
		baseRig = "Cultist",
		bodyColor = Color3.fromRGB(60, 40, 70),
		accentColor = Color3.fromRGB(180, 60, 200),
		accessoryFolder = "Cultist",
		accessories = { "HoodedRobeCap", "CharmBundle" },
	},

	soldier = {
		label = "Soldier",
		baseRig = "Soldier",
		bodyColor = Color3.fromRGB(80, 90, 65),
		accentColor = Color3.fromRGB(110, 100, 70),
		accessoryFolder = "Soldier",
		accessories = { "Helmet", "AmmoPouch" },
	},
}

VisitorAppearances.buyerArchetypes = {
	cheap_scavenger = "scrapper",
	rich_collector = "collector",
	desperate_mechanic = "engineer",
	alien_tourist = "alien",
	robot_appraiser = "robot",
	black_market_dealer = "black_market",
}

VisitorAppearances.customerArchetypes = {
	shady_scammer = "black_market",
	silent_stranger = "black_market",
	rich_collector = "collector",
	robot_trader = "robot",
	alien_tourist = "alien",
	soldier = "soldier",
	junk_dealer = "scrapper",
	mutant_drifter = "scrapper",
	desperate_survivor = "scrapper",
	nervous_rookie = "default",
}

-- Future rare visitors. Config only; no natural spawning in V1.
VisitorAppearances.uniqueVisitors = {
	synth_idol = {
		label = "Synth Idol",
		model = "SynthIdol",
	},

	broken_robot = {
		label = "Broken Robot",
		model = "BrokenRobot",
	},

	masked_courier = {
		label = "Masked Courier",
		model = "MaskedCourier",
	},

	vault_widow = {
		label = "Vault Widow",
		model = "VaultWidow",
	},

	cult_kid = {
		label = "Cult Kid",
		model = "CultKid",
	},

	traveling_collector = {
		label = "Traveling Collector",
		model = "TravelingCollector",
	},
}

export type ResolveInput = {
	visitorKind: string,
	buyerId: string?,
	customerId: string?,
	uniqueVisitorId: string?,
	displayName: string?,
	subtitle: string?,
}

export type ResolvedAppearance = {
	appearanceKey: string,
	archetypeId: string,
	baseRig: string,
	uniqueModel: string?,
	displayName: string,
	subtitle: string?,
	label: string,
	bodyColor: Color3,
	accentColor: Color3,
	limbColor: Color3,
}

function VisitorAppearances.getColors(archetypeId: string, uniqueEntry: any?): (Color3, Color3, Color3)
	if uniqueEntry and uniqueEntry.bodyColor then
		local body = uniqueEntry.bodyColor
		local accent = uniqueEntry.accentColor or body
		local limb = uniqueEntry.limbColor or body:Lerp(Color3.new(0, 0, 0), 0.15)
		return body, accent, limb
	end

	local archetype = VisitorAppearances.getArchetype(archetypeId)
	local body = archetype.bodyColor or Color3.fromRGB(130, 120, 110)
	local accent = archetype.accentColor or body
	local limb = body:Lerp(Color3.new(0, 0, 0), 0.15)
	return body, accent, limb
end

function VisitorAppearances.getArchetype(archetypeId: string)
	return VisitorAppearances.archetypes[archetypeId] or VisitorAppearances.archetypes.default
end

function VisitorAppearances.resolveArchetypeId(input: ResolveInput): string
	if input.uniqueVisitorId and VisitorAppearances.uniqueVisitors[input.uniqueVisitorId] then
		return input.uniqueVisitorId
	end

	if input.visitorKind == "buyer" and input.buyerId then
		local archetypeId = VisitorAppearances.buyerArchetypes[input.buyerId]
		if archetypeId then
			return archetypeId
		end
	end

	if input.visitorKind == "seller" and input.customerId then
		local archetypeId = VisitorAppearances.customerArchetypes[input.customerId]
		if archetypeId then
			return archetypeId
		end
	end

	if input.visitorKind == "seller" then
		return "default"
	end

	return VisitorAppearances.defaultArchetype
end

function VisitorAppearances.resolve(input: ResolveInput): ResolvedAppearance
	local archetypeId = VisitorAppearances.resolveArchetypeId(input)
	local archetype = VisitorAppearances.getArchetype(archetypeId)

	local uniqueEntry = if input.uniqueVisitorId then VisitorAppearances.uniqueVisitors[input.uniqueVisitorId] else nil
	local uniqueModel = if uniqueEntry then uniqueEntry.model else nil

	local appearanceKey
	if uniqueEntry then
		appearanceKey = `unique:{input.uniqueVisitorId}`
	elseif input.visitorKind == "buyer" and input.buyerId then
		appearanceKey = `buyer:{input.buyerId}`
	elseif input.visitorKind == "seller" and input.customerId then
		appearanceKey = `seller:{input.customerId}`
	else
		appearanceKey = `{input.visitorKind}:default`
	end

	local displayName = input.displayName
	if not displayName or displayName == "" then
		displayName = if uniqueEntry then uniqueEntry.label else archetype.label
	end

	local baseRig = archetype.baseRig or "Default"
	local bodyColor, accentColor, limbColor = VisitorAppearances.getColors(archetypeId, uniqueEntry)

	return {
		appearanceKey = appearanceKey,
		archetypeId = archetypeId,
		baseRig = baseRig,
		uniqueModel = uniqueModel,
		displayName = displayName,
		subtitle = input.subtitle,
		label = if uniqueEntry then uniqueEntry.label else archetype.label,
		bodyColor = bodyColor,
		accentColor = accentColor,
		limbColor = limbColor,
	}
end

return VisitorAppearances
