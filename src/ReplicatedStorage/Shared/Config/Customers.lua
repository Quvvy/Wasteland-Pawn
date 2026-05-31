local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local customerList = {
	{
		id = "desperate_survivor",
		displayName = "Desperate Survivor",
		patience = 0.55,
		greed = 0.25,
		desperation = 0.9,
		knowledge = 0.2,
		temper = 0.35,
		scamBias = 0,
		openingLine = "Please... I need caps today.",
	},
	{
		id = "shady_scammer",
		displayName = "Shady Scammer",
		patience = 0.7,
		greed = 0.85,
		desperation = 0.35,
		knowledge = 0.75,
		temper = 0.5,
		scamBias = 0.45,
		openingLine = "Trust me, this thing is priceless.",
	},
	{
		id = "rich_collector",
		displayName = "Rich Collector",
		patience = 0.8,
		greed = 0.6,
		desperation = 0.15,
		knowledge = 0.85,
		temper = 0.25,
		scamBias = 0.05,
		openingLine = "I know what I brought. Don't insult me.",
	},
	{
		id = "robot_trader",
		displayName = "Robot Trader",
		patience = 0.9,
		greed = 0.5,
		desperation = 0.1,
		knowledge = 0.95,
		temper = 0.15,
		scamBias = 0,
		openingLine = "QUERY: OFFER AMOUNT IN CAPS.",
	},
	{
		id = "mutant_drifter",
		displayName = "Mutant Drifter",
		patience = 0.45,
		greed = 0.4,
		desperation = 0.55,
		knowledge = 0.3,
		temper = 0.7,
		scamBias = 0.1,
		openingLine = "Trade quick. Sun burns.",
	},
	{
		id = "nervous_kid",
		displayName = "Nervous Kid",
		patience = 0.35,
		greed = 0.2,
		desperation = 0.65,
		knowledge = 0.15,
		temper = 0.55,
		scamBias = 0,
		openingLine = "Is... is this enough?",
	},
	{
		id = "soldier",
		displayName = "Soldier",
		patience = 0.6,
		greed = 0.35,
		desperation = 0.4,
		knowledge = 0.5,
		temper = 0.65,
		scamBias = 0,
		openingLine = "Make it fair. I'm on a clock.",
	},
	{
		id = "junk_dealer",
		displayName = "Junk Dealer",
		patience = 0.75,
		greed = 0.7,
		desperation = 0.3,
		knowledge = 0.6,
		temper = 0.4,
		scamBias = 0.2,
		openingLine = "Bulk price if you buy today.",
	},
	{
		id = "alien_tourist",
		displayName = "Alien Tourist",
		patience = 0.85,
		greed = 0.3,
		desperation = 0.2,
		knowledge = 0.4,
		temper = 0.2,
		scamBias = 0,
		openingLine = "Souvenir exchange? Yes?",
	},
	{
		id = "silent_stranger",
		displayName = "Silent Stranger",
		patience = 0.5,
		greed = 0.55,
		desperation = 0.25,
		knowledge = 0.7,
		temper = 0.45,
		scamBias = 0.15,
		openingLine = "...",
	},
}

local Customers = {
	List = customerList,
	ById = TableUtil.indexById(customerList, function(customer)
		return customer.id
	end),
}

function Customers.get(customerId: string)
	return Customers.ById[customerId]
end

function Customers.getRandom(rng: Random?)
	return TableUtil.pickRandom(Customers.List, rng)
end

return Customers
