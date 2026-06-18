local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local itemList = {
	-- Scrap
	{
		id = "scrap_bent_pipe",
		displayName = "Bent Rebar",
		category = "Scrap",
		baseValue = 12,
		flavorText = "Rust included free of charge.",
		traits = { "Damaged", "Useful" },
	},
	{
		id = "scrap_hubcap",
		displayName = "Crushed Hubcap",
		category = "Scrap",
		baseValue = 18,
		flavorText = "Still roundish. Mostly.",
		traits = { "Damaged", "Shiny" },
	},
	{
		id = "scrap_wire_bundle",
		displayName = "Copper Wire Bundle",
		category = "Scrap",
		baseValue = 28,
		flavorText = "Someone already stripped half of it.",
		traits = { "Useful", "Damaged" },
	},
	{
		id = "scrap_rusted_gear",
		displayName = "Rusted Gear",
		category = "Scrap",
		baseValue = 22,
		flavorText = "Teeth filed down for... reasons.",
		traits = { "Damaged", "Weird" },
	},
	{
		id = "scrap_empty_can_stack",
		displayName = "Stack of Empty Cans",
		category = "Scrap",
		baseValue = 9,
		flavorText = "Dead-era soup labels faded beyond reading.",
		traits = { "Damaged", "Collectible" },
	},
	{
		id = "scrap_broken_shovel",
		displayName = "Broken Shovel Head",
		category = "Scrap",
		baseValue = 15,
		flavorText = "Handle snapped off. Handle probably worth more.",
		traits = { "Damaged", "Useful", "Military" },
	},

	-- Old World Tech
	{
		id = "tech_handheld_radio",
		displayName = "Handheld Radio",
		category = "Old World Tech",
		baseValue = 55,
		flavorText = "Picks up static and distant ads.",
		traits = { "Useful", "Collectible" },
	},
	{
		id = "tech_solar_cell",
		displayName = "Cracked Solar Cell",
		category = "Old World Tech",
		baseValue = 70,
		flavorText = "Works on sunny days. Today is not sunny.",
		traits = { "Damaged", "Useful", "Shiny" },
	},
	{
		id = "tech_flashlight",
		displayName = "Military Flashlight",
		category = "Old World Tech",
		baseValue = 42,
		flavorText = "Heavy. Reliable. Battery not included.",
		traits = { "Military", "Useful" },
	},
	{
		id = "tech_gps_unit",
		displayName = "Dead GPS Unit",
		category = "Old World Tech",
		baseValue = 88,
		flavorText = "Screen shows one blinking pixel.",
		traits = { "Damaged", "Useful", "Collectible" },
	},
	{
		id = "tech_med_scanner",
		displayName = "Portable Med Scanner",
		category = "Old World Tech",
		baseValue = 120,
		flavorText = "Beeps ominously near rads.",
		traits = { "Useful", "Military", "Weird" },
	},
	{
		id = "tech_drone_wing",
		displayName = "Delivery Drone Wing",
		category = "Old World Tech",
		baseValue = 95,
		flavorText = "Corporate logo half melted off.",
		traits = { "Damaged", "Collectible", "Useful" },
	},

	-- Alien Tech
	{
		id = "alien_glow_orb",
		displayName = "Pulsing Glow Orb",
		category = "Alien Tech",
		baseValue = 140,
		flavorText = "Warm. Hums in C-sharp.",
		traits = { "Alien", "Shiny", "Weird" },
	},
	{
		id = "alien_memory_crystal",
		displayName = "Memory Crystal",
		category = "Alien Tech",
		baseValue = 165,
		flavorText = "Shows flickers of someone else's dream.",
		traits = { "Alien", "Collectible", "Weird" },
	},
	{
		id = "alien_translation_chip",
		displayName = "Translation Chip",
		category = "Alien Tech",
		baseValue = 110,
		flavorText = "Occasionally whispers compliments.",
		traits = { "Alien", "Useful", "Weird" },
	},
	{
		id = "alien_gravity_disk",
		displayName = "Mini Gravity Disk",
		category = "Alien Tech",
		baseValue = 200,
		flavorText = "Makes small objects float. Including coins.",
		traits = { "Alien", "Shiny", "Useful" },
	},
	{
		id = "alien_bio_gel",
		displayName = "Bio-Repair Gel",
		category = "Alien Tech",
		baseValue = 130,
		flavorText = "Smells like rain on metal.",
		traits = { "Alien", "Useful" },
	},
	{
		id = "alien_signal_beacon",
		displayName = "Signal Beacon Fragment",
		category = "Alien Tech",
		baseValue = 175,
		flavorText = "Still pinging something very far away.",
		traits = { "Alien", "Damaged", "Weird" },
	},

	-- Cursed Junk
	{
		id = "cursed_music_box",
		displayName = "Wind-Up Music Box",
		category = "Cursed Junk",
		baseValue = 35,
		flavorText = "Plays a lullaby when nobody is listening.",
		traits = { "Cursed", "Collectible", "Weird" },
	},
	{
		id = "cursed_mirror_shard",
		displayName = "Mirror Shard",
		category = "Cursed Junk",
		baseValue = 48,
		flavorText = "Reflection lags by half a second.",
		traits = { "Cursed", "Shiny", "Damaged" },
	},
	{
		id = "cursed_doll_head",
		displayName = "Porcelain Doll Head",
		category = "Cursed Junk",
		baseValue = 40,
		flavorText = "Eyes follow inventory counts.",
		traits = { "Cursed", "Collectible", "Weird" },
	},
	{
		id = "cursed_ashtray",
		displayName = "Smoking Ashtray",
		category = "Cursed Junk",
		baseValue = 30,
		flavorText = "Ash reappears every morning.",
		traits = { "Cursed", "Useful", "Weird" },
	},
	{
		id = "cursed_pocket_watch",
		displayName = "Stopped Pocket Watch",
		category = "Cursed Junk",
		baseValue = 62,
		flavorText = "Hands twitch at midnight.",
		traits = { "Cursed", "Collectible", "Shiny" },
	},
	{
		id = "cursed_lucky_coin",
		displayName = "Lucky Coin",
		category = "Cursed Junk",
		baseValue = 25,
		flavorText = "Luck is subjective. Mostly bad.",
		traits = { "Cursed", "Shiny", "Fake" },
	},

	-- Collectibles
	{
		id = "collect_bunker_bobblehead",
		displayName = "Bunker Guard Bobblehead",
		category = "Collectibles",
		baseValue = 80,
		flavorText = "Nodding approval not guaranteed.",
		traits = { "Collectible", "Shiny" },
	},
	{
		id = "collect_holo_poster",
		displayName = "Holographic Poster",
		category = "Collectibles",
		baseValue = 90,
		flavorText = "Advertises a city that no longer exists.",
		traits = { "Collectible", "Shiny", "Fake" },
	},
	{
		id = "collect_stamp_book",
		displayName = "Old World Stamp Book",
		category = "Collectibles",
		baseValue = 75,
		flavorText = "One stamp depicts a rocket. It is missing.",
		traits = { "Collectible", "Damaged" },
	},
	{
		id = "collect_gold_lighter",
		displayName = "Gold-Plated Lighter",
		category = "Collectibles",
		baseValue = 110,
		flavorText = "Engraved initials: J.R.",
		traits = { "Collectible", "Shiny", "Useful" },
	},
	{
		id = "collect_model_car",
		displayName = "Die-Cast Model Car",
		category = "Collectibles",
		baseValue = 65,
		flavorText = "Paint chipped. Nostalgia intact.",
		traits = { "Collectible", "Damaged", "Shiny" },
	},
	{
		id = "collect_signed_ball",
		displayName = "Signed Rubber Ball",
		category = "Collectibles",
		baseValue = 50,
		flavorText = "Signature faded to a smudge.",
		traits = { "Collectible", "Fake", "Weird" },
	},
}

local Items = {
	List = itemList,
	ById = TableUtil.indexById(itemList, function(item)
		return item.id
	end),
}

function Items.get(itemId: string)
	return Items.ById[itemId]
end

function Items.getRandom(rng: Random?)
	return TableUtil.pickRandom(Items.List, rng)
end

function Items.pickRandomInCategories(categories: { string }, rng: Random?)
	local wanted = {}
	for _, category in categories do
		wanted[category] = true
	end

	local pool = {}
	for _, item in Items.List do
		if wanted[item.category] then
			table.insert(pool, item)
		end
	end

	return TableUtil.pickRandom(pool, rng)
end

return Items
